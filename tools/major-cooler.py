#!/usr/bin/env python3
"""
Major System: number -> words, and words -> number.

Setup (once):
    pip install cmudict wordfreq nltk

Usage:
    python major-cooler.py 404                 # lookup
    python major-cooler.py 404 --limit 20      # more results
    python major-cooler.py 8675309             # long number -> phrases
    python major-cooler.py cat dog             # words -> possible numbers
    python major-cooler.py "hello world"       # phrase -> possible numbers
    python major-cooler.py                     # interactive prompt
    python major-cooler.py --rebuild           # force rebuild of the index

First run builds major.sqlite next to this script (takes ~10-60 seconds,
mostly WordNet scoring). Later runs reuse it and are instant.

wordfreq and nltk are optional: without them the script still works, but
ranking is worse (no frequency pruning, no concreteness/noun boost).
"""

import argparse
import re
import sqlite3
import sys
from functools import lru_cache
from pathlib import Path

DB_DEFAULT = Path(__file__).with_name("major.sqlite")

# ---------------------------------------------------------------- mapping --

PHONEME_TO_DIGIT = {
    "S": "0", "Z": "0",
    "T": "1", "D": "1", "TH": "1", "DH": "1",
    "N": "2",
    "M": "3",
    "R": "4", "ER": "4",
    "L": "5",
    "CH": "6", "JH": "6", "SH": "6", "ZH": "6",
    "K": "7", "G": "7",
    "F": "8", "V": "8",
    "P": "9", "B": "9",
    "NG": "27",          # n + k, traditional rule
}
# Everything else (vowels, HH, W, Y) is ignored.


def phones_to_digits(phones):
    out = []
    for p in phones:
        p = re.sub(r"\d", "", p)  # strip stress marker: EY1 -> EY
        d = PHONEME_TO_DIGIT.get(p)
        if d:
            out.append(d)
    return "".join(out)


def normalize_word(word):
    """Lowercase and keep only letters/apostrophes."""
    w = re.sub(r"[^A-Za-z']", "", word)
    return w.lower()


# ---------------------------------------------------------------- scoring --

CONCRETE_LEX = {
    "noun.animal", "noun.artifact", "noun.food", "noun.body", "noun.plant",
    "noun.object", "noun.substance", "noun.person",
}
ABSTRACT_LEX = {
    "noun.cognition", "noun.communication", "noun.attribute", "noun.feeling",
    "noun.state", "noun.act", "noun.event", "noun.process", "noun.relation",
    "noun.motive", "noun.time", "noun.quantity",
}
ABBREV_BLOCKLIST = {
    "etc", "mr", "mrs", "ms", "dr", "jr", "sr", "vs", "inc", "ltd", "co",
    "corp", "st", "ave", "blvd", "gov", "sen", "rep", "gen", "col", "lt",
    "sgt", "capt", "prof", "rev", "hon", "mt", "ft", "tv", "pc", "dj",
}
W_CONCRETE, W_NOUN, W_FREQ, W_LEN = 0.45, 0.20, 0.25, 0.10
MIN_ZIPF = 2.0  # prune obscure words when wordfreq is available


def load_optional_libs():
    zipf = None
    wn = None
    try:
        from wordfreq import zipf_frequency
        zipf = lambda w: zipf_frequency(w, "en")
    except ImportError:
        print("note: wordfreq not installed; no frequency ranking/pruning "
              "(pip install wordfreq)", file=sys.stderr)
    try:
        import nltk
        from nltk.corpus import wordnet
        try:
            wordnet.synsets("dog")
        except LookupError:
            print("downloading WordNet...", file=sys.stderr)
            nltk.download("wordnet", quiet=True)
        wordnet.synsets("dog")
        wn = wordnet
    except Exception:
        print("note: nltk/WordNet unavailable; no concreteness/noun boost "
              "(pip install nltk)", file=sys.stderr)
    return zipf, wn


def concreteness_and_noun(word, wn):
    if wn is None:
        return 0.5, 0.0
    syns = wn.synsets(word, pos="n")
    if not syns:
        return 0.2, 0.0
    lex = syns[0].lexname()  # most common noun sense
    if lex in CONCRETE_LEX:
        return 1.0, 1.0
    if lex in ABSTRACT_LEX:
        return 0.1, 1.0
    return 0.5, 1.0


def score_word(word, zipf, wn):
    conc, noun = concreteness_and_noun(word, wn)
    freq = 0.5 if zipf is None else max(0.0, min(zipf(word) / 8.0, 1.0))
    len_pen = max(0.0, min((len(word) - 3) / 10.0, 1.0))
    return W_CONCRETE * conc + W_NOUN * noun + W_FREQ * freq - W_LEN * len_pen


def is_acceptable(word, zipf):
    if not re.fullmatch(r"[a-z]+", word):      # drops "a.b.c.", apostrophes
        return False
    if len(word) == 1 and word not in ("a", "i"):  # spelled-out letters
        return False
    if word in ABBREV_BLOCKLIST:
        return False
    if not re.search(r"[aeiouy]", word):       # mr, fbi, ...
        return False
    if zipf is not None and zipf(word) < MIN_ZIPF:
        return False
    return True


# ------------------------------------------------------------------ build --

def build_index(db_path):
    try:
        import cmudict
    except ImportError:
        sys.exit("Missing dependency. Run:  pip install cmudict wordfreq nltk")

    zipf, wn = load_optional_libs()
    print("loading CMUdict...", file=sys.stderr)
    entries = cmudict.dict()  # word -> [[phones], ...]

    best = {}  # (word, digits) -> score
    kept = 0
    for word, prons in entries.items():
        if not is_acceptable(word, zipf):
            continue
        digits_variants = {phones_to_digits(p) for p in prons}
        digits_variants.discard("")  # pure-vowel words carry no digits
        if not digits_variants:
            continue
        s = score_word(word, zipf, wn)
        for d in digits_variants:
            best[(word, d)] = s
        kept += 1
        if kept % 10000 == 0:
            print(f"  scored {kept} words...", file=sys.stderr)

    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.execute("CREATE TABLE words (word TEXT, digits TEXT, score REAL)")
    con.executemany("INSERT INTO words VALUES (?,?,?)",
                    ((w, d, s) for (w, d), s in best.items()))
    con.execute("CREATE INDEX idx_digits ON words(digits, score DESC)")
    con.commit()
    con.close()
    size_mb = db_path.stat().st_size / 1e6
    print(f"built {db_path} with {kept} words, {len(best)} rows, "
          f"{size_mb:.1f} MB", file=sys.stderr)


# ----------------------------------------------------------------- lookup --

class MajorEngine:
    def __init__(self, db_path):
        self.con = sqlite3.connect(db_path)
        self._words_for = lru_cache(maxsize=None)(self._words_for_uncached)

    def _words_for_uncached(self, digits, limit):
        rows = self.con.execute(
            "SELECT word, score FROM words WHERE digits=? "
            "ORDER BY score DESC, word LIMIT ?", (digits, limit)).fetchall()
        return tuple(rows)

    def single_words(self, digits, limit=30):
        return list(self._words_for(digits, limit))

    def phrases(self, digits, max_words=4, limit=30,
                per_chunk=8, beam=40, word_penalty=1.0):
        n = len(digits)

        @lru_cache(maxsize=None)
        def best_from(i, remaining):
            """k-best (score, words) covering digits[i:]."""
            if i == n:
                return ((0.0, ()),)
            if remaining == 0:
                return ()
            results = []
            for j in range(i + 1, n + 1):
                cands = self._words_for(digits[i:j], per_chunk)
                if not cands:
                    continue
                tails = best_from(j, remaining - 1)
                for word, s in cands:
                    for ts, tw in tails:
                        results.append((s - word_penalty + ts,
                                        (word,) + tw))
            results.sort(key=lambda r: -r[0])
            return tuple(results[:beam])

        out = []
        # force at least two words: first chunk must not span everything
        for j in range(1, n):
            cands = self._words_for(digits[:j], per_chunk)
            if not cands:
                continue
            tails = best_from(j, max_words - 1)
            for word, s in cands:
                for ts, tw in tails:
                    out.append((s - word_penalty + ts, (word,) + tw))
        out.sort(key=lambda r: -r[0])
        seen, uniq = set(), []
        for s, w in out:
            if w not in seen:
                seen.add(w)
                uniq.append((s, w))
        return uniq[:limit]


# ------------------------------------------------------------- reverse --

_CMU_LOOKUP = None


def get_cmudict_lookup():
    """
    Load CMUdict once and build a normalized lookup table.

    Returns: dict mapping normalized word -> list of pronunciation lists.
    """
    global _CMU_LOOKUP
    if _CMU_LOOKUP is not None:
        return _CMU_LOOKUP

    try:
        import cmudict
    except ImportError:
        sys.exit("Missing dependency. Run:  pip install cmudict wordfreq nltk")

    raw = cmudict.dict()
    lookup = {}

    for word, prons in raw.items():
        key = normalize_word(word)
        if not key:
            continue

        # Prefer the first pronunciation list found for a normalized key.
        if key not in lookup:
            lookup[key] = prons

        # Also index without apostrophes, e.g. "don't" -> "dont".
        key2 = re.sub(r"'", "", key)
        if key2 and key2 != key and key2 not in lookup:
            lookup[key2] = prons

    _CMU_LOOKUP = lookup
    return _CMU_LOOKUP


def word_digit_info(raw_word):
    """
    Return (known, variants).

    known   : True if the word was found in CMUdict.
    variants: possible Major System digit strings for that word.
              May be empty for words with no consonants/digits.
    """
    lookup = get_cmudict_lookup()
    key = normalize_word(raw_word)

    if not key:
        return False, []

    prons = lookup.get(key)

    # Fallback: try without apostrophes.
    if prons is None:
        key2 = re.sub(r"'", "", key)
        if key2 and key2 != key:
            prons = lookup.get(key2)

    if prons is None:
        return False, []

    variants = {phones_to_digits(p) for p in prons}
    variants.discard("")  # pure-vowel words carry no digits

    # Prefer shorter digit strings first, then lexicographic order.
    return True, sorted(variants, key=lambda s: (len(s), s))


def text_to_numbers(raw_text, max_results=50):
    """
    Convert a phrase or sentence into possible Major System numbers.

    Returns:
        (numbers, missing, ignored)

    Example:
        "cat dog" -> ["2836"]
        "lead ball" may produce multiple possibilities if words have
        multiple pronunciations.
    """
    # Extract alphabetic tokens, including contractions like don't.
    tokens = re.findall(r"[A-Za-z]+(?:'[a-zA-Z]+)?", raw_text)

    if not tokens:
        return [], [], []

    per_word_variants = []
    missing = []
    ignored = []

    for token in tokens:
        known, variants = word_digit_info(token)

        if not known:
            missing.append(token)
        elif variants:
            per_word_variants.append(variants)
        else:
            # Known word, but it contributes no Major System digits.
            ignored.append(token)

    if not per_word_variants:
        return [], missing, ignored

    # Combine all pronunciation possibilities.
    results = [""]
    for variants in per_word_variants:
        next_results = []
        for prefix in results:
            for v in variants:
                candidate = prefix + v
                if len(candidate) <= 20:  # keep within your CLI limit
                    next_results.append(candidate)

        # Cap growth to avoid explosion on long phrases.
        seen = set()
        unique_next = []
        for r in next_results:
            if r not in seen:
                seen.add(r)
                unique_next.append(r)
        results = unique_next[:max_results * 10]

    # Final dedupe, preserving order.
    seen = set()
    out = []
    for r in results:
        if r and r not in seen:
            seen.add(r)
            out.append(r)

    return out[:max_results], missing, ignored


# -------------------------------------------------------------------- cli --

def clean_digits(raw):
    d = re.sub(r"[\s,.\-_]", "", raw)
    if not d.isdigit():
        raise ValueError(f"not a number: {raw!r}")
    if not 1 <= len(d) <= 20:
        raise ValueError("input must be 1 to 20 digits")
    return d


def try_clean_digits(raw):
    """Return cleaned digits if raw is purely numeric, otherwise None."""
    d = re.sub(r"[\s,.\-_]", "", raw)
    if not d:
        return None
    if not d.isdigit():
        return None
    if not 1 <= len(d) <= 20:
        raise ValueError("input must be 1 to 20 digits")
    return d


def run_query(engine, raw, limit, max_words):
    digits = clean_digits(raw)
    singles = engine.single_words(digits, limit)
    phrases = engine.phrases(digits, max_words=max_words, limit=limit)

    print(f"\n{digits}")
    print("-" * len(digits))
    if singles:
        print("Words:")
        for w, s in singles:
            print(f"  {w:<18} {s:.2f}")
    else:
        print("Words: (no single word matches)")
    if phrases:
        print("Phrases:")
        for s, ws in phrases:
            avg = (s + 1.0 * len(ws)) / len(ws)  # undo per-word penalty
            print(f"  {' '.join(ws):<30} {avg:.2f}")
    else:
        print("Phrases: (none found)")
    print()


def run_reverse(raw, limit):
    numbers, missing, ignored = text_to_numbers(raw, max_results=limit)

    print(f"\nInput: {raw.strip()}")

    if missing:
        print(f"Note: no pronunciation found for: {', '.join(missing)}")
    if ignored:
        print(f"Ignored (no Major System digits): {', '.join(ignored)}")

    if not numbers:
        print("Numbers: (none found)")
    else:
        print("Possible number(s):")
        for n in numbers:
            print(f"  {n}")
    print()


def main():
    ap = argparse.ArgumentParser(description="Major System number <-> words")
    ap.add_argument(
        "number",
        nargs="?",
        help="digits or words, e.g. 404 / cat dog"
    )
    ap.add_argument("--limit", type=int, default=15)
    ap.add_argument("--max-words", type=int, default=4,
                    help="max words per phrase")
    ap.add_argument("--db", type=Path, default=DB_DEFAULT)
    ap.add_argument("--rebuild", action="store_true")
    args = ap.parse_args()

    engine = None

    def ensure_engine():
        nonlocal engine
        if engine is None:
            if args.rebuild or not args.db.exists():
                build_index(args.db)
            engine = MajorEngine(args.db)
        return engine

    try:
        if args.number:
            digits = try_clean_digits(args.number)
            if digits is not None:
                run_query(ensure_engine(), args.number, args.limit, args.max_words)
            else:
                run_reverse(args.number, args.limit)
        else:
            print("Enter a number or words (blank to quit).")
            while True:
                raw = input("> ").strip()
                if not raw:
                    break

                digits = try_clean_digits(raw)
                if digits is not None:
                    run_query(ensure_engine(), raw, args.limit, args.max_words)
                else:
                    run_reverse(raw, args.limit)

    except ValueError as e:
        sys.exit(str(e))


if __name__ == "__main__":
    main()
