import Foundation

// MARK: - Major System core model
// Standard Major System: consonant sounds -> digits. Vowels (a e i o u)
// and w, h, y carry no value.

struct MajorMapping: Identifiable, Hashable {
    let digit: String
    let sounds: String
    let examples: String
    let tip: String
    var id: String { digit }
}

enum MajorSystem {

    // MARK: Cheatsheet (standard Major System)
    static let mappings: [MajorMapping] = [
        MajorMapping(digit: "0", sounds: "S, Z  (soft C)", examples: "zoo, sea, sauce", tip: "\"Zoo\" starts with a Z — zero starts with Z."),
        MajorMapping(digit: "1", sounds: "T, D, TH", examples: "tea, toad, thigh", tip: "T and D both need 1 downward stroke to write."),
        MajorMapping(digit: "2", sounds: "N", examples: "Noah, nun, sun", tip: "Lowercase n has 2 humps."),
        MajorMapping(digit: "3", sounds: "M", examples: "Ma, sumo, moon", tip: "Lowercase m has 3 humps."),
        MajorMapping(digit: "4", sounds: "R", examples: "rye, sore, tire", tip: "R is the last letter of fouR."),
        MajorMapping(digit: "5", sounds: "L", examples: "law, sail, tail", tip: "Hold up 5 fingers: thumb + index make an L."),
        MajorMapping(digit: "6", sounds: "SH, CH, soft G, J", examples: "shoe, dish, jam", tip: "A written 6 curls like a J; 6 looks like a CH hook."),
        MajorMapping(digit: "7", sounds: "K, hard C, hard G, Q", examples: "cow, sack, rock", tip: "K is made of two 7s stuck together."),
        MajorMapping(digit: "8", sounds: "F, V  (incl. PH)", examples: "fee, sofa, navy", tip: "Written f has two loops, like an 8."),
        MajorMapping(digit: "9", sounds: "P, B", examples: "bee, soup, map", tip: "A 9 is a P flipped upside-down; P and B look alike.")
    ]

    // Single-digit peg words (for chunking odd leftovers).
    static let singlePegs: [String: String] = [
        "0": "zoo", "1": "tea", "2": "Noah", "3": "Ma", "4": "rye",
        "5": "law", "6": "shoe", "7": "cow", "8": "fee", "9": "bee"
    ]

    // Two-digit peg words (00-99), chosen to be visual nouns.
    // Pedagogical list — does not depend on the naive encoder.
    static let doublePegs: [String: String] = [
        "00": "sauce", "01": "suit", "02": "sun", "03": "sumo", "04": "sore",
        "05": "sail", "06": "sage", "07": "sack", "08": "sofa", "09": "soup",
        "10": "dice", "11": "toad", "12": "tuna", "13": "dime", "14": "tire",
        "15": "towel", "16": "touch", "17": "dog", "18": "dove", "19": "tub",
        "20": "nose", "21": "net", "22": "nun", "23": "gnome", "24": "narrow",
        "25": "nail", "26": "notch", "27": "neck", "28": "navy", "29": "nap",
        "30": "mouse", "31": "mat", "32": "moon", "33": "mime", "34": "mare",
        "35": "mail", "36": "match", "37": "mug", "38": "movie", "39": "map",
        "40": "rose", "41": "rat", "42": "rain", "43": "ram", "44": "rower",
        "45": "rail", "46": "roach", "47": "rock", "48": "roof", "49": "rope",
        "50": "lace", "51": "lad", "52": "lion", "53": "lamb", "54": "lure",
        "55": "lily", "56": "latch", "57": "lake", "58": "leaf", "59": "lip",
        "60": "cheese", "61": "sheet", "62": "chain", "63": "jam", "64": "jar",
        "65": "jail", "66": "judge", "67": "joke", "68": "chief", "69": "jeep",
        "70": "case", "71": "cat", "72": "coin", "73": "comb", "74": "car",
        "75": "coal", "76": "cage", "77": "cake", "78": "cave", "79": "cap",
        "80": "face", "81": "fat", "82": "fan", "83": "foam", "84": "fur",
        "85": "fool", "86": "fish", "87": "fig", "88": "fife", "89": "fib",
        "90": "base", "91": "bat", "92": "bun", "93": "bum", "94": "bear",
        "95": "ball", "96": "peach", "97": "bike", "98": "puff", "99": "poppy"
    ]

    // MARK: - Encoder (word -> digits, approximate phonetics)

    /// Converts a word to its Major System digit code.
    /// Handles digraphs th/sh/ch/ph, soft c/g before e,i,y, and x = 70 (ks).
    /// Vowels + w,h,y are ignored.
    static func digits(for word: String) -> String {
        let lower = word.lowercased()
        let chars = Array(lower)
        var out = ""
        var i = 0
        while i < chars.count {
            let c = chars[i]
            let next: Character? = (i + 1 < chars.count) ? chars[i + 1] : nil

            // Digraphs first
            if let n = next {
                let pair = String([c, n])
                if pair == "th" { out += "1"; i += 2; continue }
                if pair == "sh" || pair == "ch" { out += "6"; i += 2; continue }
                if pair == "ph" { out += "8"; i += 2; continue }
                if pair == "ng" {
                    // "ng" is just n (2); g is nasal, skip g
                    out += "2"; i += 2; continue
                }
            }

            switch c {
            case "s", "z":
                out += "0"
            case "d", "t":
                out += "1"
            case "n":
                out += "2"
            case "m":
                out += "3"
            case "r":
                out += "4"
            case "l":
                out += "5"
            case "j":
                out += "6"
            case "k", "q":
                out += "7"
            case "c":
                if let n = next, n == "e" || n == "i" || n == "y" {
                    out += "0" // soft c: cell, city
                } else {
                    out += "7" // hard c: cat, coal
                }
            case "g":
                if let n = next, n == "e" || n == "i" || n == "y" {
                    out += "6" // soft g: sage, cage
                } else {
                    out += "7" // hard g: dog, mug
                }
            case "f", "v":
                out += "8"
            case "p", "b":
                out += "9"
            case "x":
                out += "70" // ks: box = 970
            case "a", "e", "i", "o", "u", "w", "h", "y", "'", "-", " ":
                break // ignored
            default:
                break
            }
            i += 1
        }
        return out
    }

    static func sanitizedDigits(_ raw: String) -> String {
        raw.filter { $0.isNumber }
    }

    // MARK: - Searchable vocabulary (curated, imagery-friendly)

    static let vocabulary: [String] = [
        // 1-2 digits
        "zoo", "sea", "tea", "toe", "day", "net", "knee", "gnome", "Noah", "Ma",
        "rye", "law", "owl", "shoe", "jaw", "cow", "key", "fee", "ivy", "bee", "pie",
        // 2 digits (peg overlap + extras)
        "sauce", "suit", "sun", "sumo", "sore", "sail", "sage", "sack", "sofa", "soup",
        "dice", "toad", "tuna", "dime", "tire", "towel", "touch", "dog", "dove", "tub",
        "nose", "nun", "nail", "notch", "neck", "navy", "nap",
        "mouse", "mat", "moon", "mime", "mare", "mail", "match", "mug", "movie", "map",
        "rose", "rat", "rain", "ram", "rail", "roach", "rock", "roof", "rope",
        "lace", "lad", "lion", "lamb", "lure", "lily", "latch", "lake", "leaf", "lip",
        "cheese", "sheet", "chain", "jam", "jar", "jail", "judge", "joke", "chief", "jeep",
        "case", "cat", "coin", "comb", "car", "coal", "cage", "cake", "cave", "cap",
        "face", "fat", "fan", "foam", "fur", "fool", "fish", "fig", "fife", "fib",
        "base", "bat", "bun", "bum", "bear", "ball", "peach", "bike", "puff", "poppy",
        // 3 digits — the stars of the show
        "remote", "razor", "tomato", "lemon", "hammer", "melon", "rocket", "pocket", "bucket",
        "planet", "blanket", "cabin", "piano", "bacon", "magnet", "carpet", "forest",
        "wallet", "pillow", "window", "candle", "tunnel", "castle", "puzzle", "bottle",
        "ladder", "letter", "butter", "summit", "salmon", "melody", "family", "vanilla",
        "garden", "cannon", "ribbon", "balloon", "pill", "dolphin", "wolf", "elephant",
        "giraffe", "monkey", "donkey", "turkey", "turtle", "apple", "banana", "cherry",
        "orange", "grapes", "cheese", "pizza", "slice", "honey", "candy", "cookie",
        "guitar", "piano", "trumpet", "drum", "castle", "bridge", "tower", "train",
        "plane", "ship", "anchor", "compass", "lantern", "torch", "knife", "spoon",
        "tiger", "eagle", "shark", "whale", "snake", "spider", "rabbit", "panda",
        "robot", "rocket", "alien", "pirate", "ninja", "wizard", "dragon", "castle",
        "beach", "desert", "island", "volcano", "waterfall", "rainbow", "thunder", "snowman",
        // 4+ digits
        "telephone", "telescope", "watermelon", "pineapple", "strawberry", "chocolate",
        "laptop", "remote", "microwave", "refrigerator", "suitcase", "backpack",
        "motorcycle", "helicopter", "submarine", "skyscraper", "lighthouse", "treasure",
        "vampire", "mermaid", "unicorn", "superhero", "basketball", "football", "tennis",
        "sunflower", "butterfly", "caterpillar", "crocodile", "kangaroo", "penguin",
        "library", "museum", "pyramid", "sphinx", "samurai", "astronaut", "detective",
        "magician", "juggler", "clown", "balloon", "fireworks", "parachute", "compass"
    ]

    // MARK: - Algorithm search

    struct SearchResult {
        let digits: String
        let exact: [String]
        let combos: [String]
        let chunkedStory: [String]
        let chunkCodes: [String]
    }

    /// Offline mnemonic search:
    /// - exact: single words whose code == digits
    /// - combos: two-word phrases covering digits at every split point
    /// - chunkedStory: peg word per 2-digit chunk (always succeeds)
    static func search(_ rawInput: String) -> SearchResult {
        let target = sanitizedDigits(rawInput)
        guard !target.isEmpty else {
            return SearchResult(digits: "", exact: [], combos: [], chunkedStory: [], chunkCodes: [])
        }

        // Precompute code for each vocab word once.
        let coded = vocabulary.map { ($0, Self.digits(for: $0)) }
        var byCode: [String: [String]] = [:]
        for (word, code) in coded where !code.isEmpty {
            byCode[code, default: []].append(word)
        }

        // Exact matches (dedupe, cap 12).
        var exact = Array(Set(byCode[target] ?? [])).sorted()
        if exact.count > 12 { exact = Array(exact.prefix(12)) }

        // Two-word combos across every split.
        var combos: [String] = []
        let chars = Array(target)
        if chars.count >= 2 && chars.count <= 8 {
            for split in 1..<chars.count {
                let left = String(chars[0..<split])
                let right = String(chars[split...])
                guard let lefts = byCode[left], let rights = byCode[right] else { continue }
                for l in lefts.prefix(3) {
                    for r in rights.prefix(3) {
                        combos.append("\(l) \(r)")
                        if combos.count >= 12 { break }
                    }
                    if combos.count >= 12 { break }
                }
                if combos.count >= 12 { break }
            }
        }

        // Chunked story: greedy 2-digit chunks (leading single if odd length).
        var chunks: [String] = []
        var idx = target.startIndex
        if target.count % 2 == 1 {
            chunks.append(String(target[idx]))
            idx = target.index(after: idx)
        }
        while idx < target.endIndex {
            let end = target.index(idx, offsetBy: 2, limitedBy: target.endIndex) ?? target.endIndex
            chunks.append(String(target[idx..<end]))
            idx = end
        }
        let story = chunks.map { chunk in
            if chunk.count == 1 { return singlePegs[chunk] ?? "?" }
            return doublePegs[chunk] ?? "?"
        }

        return SearchResult(digits: target, exact: exact, combos: combos,
                            chunkedStory: story, chunkCodes: chunks)
    }

    /// Builds a copy-paste prompt for external LLMs (ChatGPT, Claude, …).
    static func aiPrompt(for digits: String) -> String {
        """
        I am learning the Major System for memorizing numbers. \
        Convert the number \(digits) into a short, vivid, funny mnemonic phrase using valid Major System words. \
        Rules: 0=S/Z, 1=T/D/TH, 2=N, 3=M, 4=R, 5=L, 6=SH/CH/J/soft-G, 7=K/hard-C/hard-G/Q, 8=F/V/PH, 9=P/B; vowels and W/H/Y are free. \
        The consonant codes of the phrase, in order, must equal \(digits). \
        Reply with: 1) the phrase in bold, 2) a word-by-word code breakdown, 3) one sentence visualizing the scene.
        """
    }
}
