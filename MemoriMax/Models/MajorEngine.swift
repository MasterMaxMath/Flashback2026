import Foundation
import SQLite3

// MARK: - Swift port of tools/major-cooler.py lookups
//
// Reads the bundled major.sqlite (CMUdict phonetics × frequency /
// concreteness ranking, built once on Mac). The database is copied to
// Application Support on first launch because the app bundle is
// read-only and SQLite wants journal files next to the DB.
//
// Public surface for app + future LLM tool use: `MajorTools.to_words`
// and `MajorTools.to_phrases` (same names as the Python tool calls).

struct ScoredWord: Hashable {
    let word: String
    let score: Double
}

struct ScoredPhrase: Hashable {
    let words: [String]
    let score: Double
}

final class MajorEngine {
    static let shared: MajorEngine? = {
        guard let bundled = Bundle.main.url(forResource: "major", withExtension: "sqlite") else { return nil }
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent("major.sqlite")
        if !fm.fileExists(atPath: dest.path) {
            try? fm.copyItem(at: bundled, to: dest)
        }
        return MajorEngine(path: dest.path)
    }()

    private var db: OpaquePointer?
    private let lock = NSLock()
    /// Chunk → full ranked rows (bounded), so tighter limits just prefix.
    private var chunkCache: [String: [(String, Double)]] = [:]
    private static let cacheLimit = 100

    init?(path: String) {
        if sqlite3_open(path, &db) != SQLITE_OK {
            db = nil
            return nil
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Raw query

    private func queryWords(chunk: String, limit: Int) -> [(String, Double)] {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return [] }
        var stmt: OpaquePointer?
        let sql = "SELECT word, score FROM words WHERE digits=? ORDER BY score DESC, word LIMIT ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        _ = chunk.withCString { sqlite3_bind_text(stmt, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        sqlite3_bind_int(stmt, 2, Int32(limit))
        var out: [(String, Double)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cWord = sqlite3_column_text(stmt, 0) else { continue }
            out.append((String(cString: cWord), sqlite3_column_double(stmt, 1)))
        }
        return out
    }

    private func wordsFor(_ chunk: String, limit: Int) -> [(String, Double)] {
        if let hit = chunkCache[chunk], hit.count >= limit { return Array(hit.prefix(limit)) }
        let rows = queryWords(chunk: chunk, limit: max(limit, Self.cacheLimit))
        chunkCache[chunk] = rows
        return Array(rows.prefix(limit))
    }

    // MARK: - to_words

    func singleWords(digits: String, limit: Int = 30) -> [ScoredWord] {
        let target = digits.filter(\.isNumber)
        guard !target.isEmpty, limit > 0 else { return [] }
        return wordsFor(target, limit: limit).map { ScoredWord(word: $0.0, score: $0.1) }
    }

    // MARK: - digits(for:) — real CMU phonetics on-device

    /// Stored digit code for a word, or nil when the word is unknown.
    /// Authoritative over the naive letter encoder for AI validation.
    func digitsFor(word: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return nil }
        let key = word.lowercased()
        guard !key.isEmpty else { return nil }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT digits FROM words WHERE word=? LIMIT 1", -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        _ = key.withCString { sqlite3_bind_text(stmt, 1, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
        guard sqlite3_step(stmt) == SQLITE_ROW,
              let cDigits = sqlite3_column_text(stmt, 0) else { return nil }
        return String(cString: cDigits)
    }

    // MARK: - to_phrases (beam search port)

    func phrases(digits: String, maxWords: Int = 4, limit: Int = 30,
                 perChunk: Int = 8, beam: Int = 40, wordPenalty: Double = 1.0) -> [ScoredPhrase] {
        let target = digits.filter(\.isNumber)
        guard target.count >= 2, maxWords >= 2, limit > 0 else { return [] }
        let chars = Array(target)
        let n = chars.count
        var memo: [String: [(Double, [String])]] = [:]

        func bestFrom(_ i: Int, _ remaining: Int) -> [(Double, [String])] {
            let key = "\(i)#\(remaining)"
            if let hit = memo[key] { return hit }
            let result: [(Double, [String])]
            if i == n {
                result = [(0.0, [])]
            } else if remaining == 0 {
                result = []
            } else {
                var acc: [(Double, [String])] = []
                for j in (i + 1)...n {
                    let chunk = String(chars[i..<j])
                    let cands = wordsFor(chunk, limit: perChunk)
                    if cands.isEmpty { continue }
                    for (w, s) in cands {
                        for (ts, tw) in bestFrom(j, remaining - 1) {
                            acc.append((s - wordPenalty + ts, [w] + tw))
                        }
                    }
                }
                acc.sort { $0.0 > $1.0 }
                result = Array(acc.prefix(beam))
            }
            memo[key] = result
            return result
        }

        var out: [(Double, [String])] = []
        for j in 1..<n {  // first chunk must not span everything (≥2 words)
            let chunk = String(chars[0..<j])
            for (w, s) in wordsFor(chunk, limit: perChunk) {
                for (ts, tw) in bestFrom(j, maxWords - 1) {
                    out.append((s - wordPenalty + ts, [w] + tw))
                }
            }
        }
        out.sort { $0.0 > $1.0 }
        var seen = Set<[String]>()
        var uniq: [ScoredPhrase] = []
        for (s, w) in out where seen.insert(w).inserted {
            uniq.append(ScoredPhrase(words: w, score: s))
            if uniq.count == limit { break }
        }
        return uniq
    }
}

// MARK: - Callable tool API (mirrors the Python to_words / to_phrases)

enum MajorTools {
    static var isAvailable: Bool { MajorEngine.shared != nil }

    /// Ranked single words whose codes equal `digits`. Empty when the
    /// database is missing or no word matches.
    static func to_words(_ digits: String, limit: Int = 30) -> [ScoredWord] {
        MajorEngine.shared?.singleWords(digits: digits, limit: limit) ?? []
    }

    /// Ranked multi-word phrases covering `digits` (always ≥2 words).
    static func to_phrases(_ digits: String, maxWords: Int = 4, limit: Int = 30) -> [ScoredPhrase] {
        MajorEngine.shared?.phrases(digits: digits, maxWords: maxWords, limit: limit) ?? []
    }

    /// Stored CMU digit code for a word, nil when unknown. Use this to
    /// validate AI-proposed words; fall back to the naive encoder only
    /// when it returns nil.
    static func digits(for word: String) -> String? {
        MajorEngine.shared?.digitsFor(word: word)
    }
}
