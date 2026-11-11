# Generate compact CJK pinyin indexes for the app.
# Outputs:
#   assets/pinyin/first_letter.txt  (1 letter/char, 64 per line)
#   assets/pinyin/full_pinyin.txt   (variable-length syllable/char, 32 tokens per line)
#     line 1: "# cjk-full-pinyin v1 base=%d len=%d" % (BASE, LEN)
#     body:   space-separated tokens, token i corresponds to chr(BASE + i)
#             token is a-z+ syllable (first reading) or "?" when unmapped
#
# Why not a Dart package: lpinyin pins sdk >=2.12 <3.0.0 and cannot resolve
# on Dart 3.x, so the table is baked at build time and shipped as an asset.
import os
import sys

from pypinyin import lazy_pinyin, Style

BASE = 0x4E00
END = 0x9FFF  # inclusive, CJK Unified Ideographs block
LEN = END - BASE + 1

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_LETTER = os.path.join(ROOT, "assets", "pinyin", "first_letter.txt")
OUT_FULL = os.path.join(ROOT, "assets", "pinyin", "full_pinyin.txt")


def _safe_single(ch: str, style: int):
    """lazy_pinyin on one char -> single syllable string or None.

    Wraps the call so a per-char failure degrades to None instead of
    aborting the whole table build.
    """
    try:
        py = lazy_pinyin(ch, style=style, errors="ignore")
    except Exception:
        return None
    if not py or not py[0]:
        return None
    s = py[0].lower()
    return s if s else None


def build_letters() -> str:
    """20992-char string: one a-z letter per CJK char, '?' when unmapped."""
    chars = []
    i = 0
    while i < LEN:
        s = _safe_single(chr(BASE + i), Style.FIRST_LETTER)
        letter = s[0] if s else "?"
        if letter < "a" or letter > "z":
            letter = "?"
        chars.append(letter)
        i += 1
    return "".join(chars)


def build_full() -> list:
    """LEN-element list: a-z+ syllable per CJK char, '?' when unmapped.

    Polyphones: lazy_pinyin returns the most common reading first; we keep
    the first one so the table stays deterministic and single-valued.
    """
    out = []
    i = 0
    while i < LEN:
        s = _safe_single(chr(BASE + i), Style.NORMAL)
        if s is None or not ("a" <= s[0] <= "z"):
            s = "?"
        out.append(s)
        i += 1
    return out


def main() -> int:
    os.makedirs(os.path.dirname(OUT_LETTER), exist_ok=True)

    # ---- first-letter table (unchanged format since v1) ----
    body = build_letters()
    assert len(body) == LEN, (len(body), LEN)
    lines = ["# cjk-first-letter v1 base=%d len=%d" % (BASE, LEN)]
    for i in range(0, LEN, 64):
        lines.append(body[i:i + 64])
    text = "\n".join(lines) + "\n"
    with open(OUT_LETTER, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    covered = sum(1 for c in body if c != "?")
    print("wrote %s" % OUT_LETTER)
    print("chars=%d covered=%d (%.1f%%) bytes=%d" % (
        LEN, covered, covered * 100.0 / LEN, len(text.encode("utf-8"))))
    for sample in ["随想随记", "钢结构", "手工", "想法"]:
        got = "".join(
            body[ord(c) - BASE] if BASE <= ord(c) <= END else c for c in sample
        )
        print("  %s -> %s" % (sample, got))

    # ---- full-pinyin table (v2.7.0) ----
    full = build_full()
    assert len(full) == LEN, (len(full), LEN)
    lines = ["# cjk-full-pinyin v1 base=%d len=%d" % (BASE, LEN)]
    for i in range(0, LEN, 32):
        lines.append(" ".join(full[i:i + 32]))
    text = "\n".join(lines) + "\n"
    with open(OUT_FULL, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    covered = sum(1 for c in full if c != "?")
    print("wrote %s" % OUT_FULL)
    print("chars=%d covered=%d (%.1f%%) bytes=%d" % (
        LEN, covered, covered * 100.0 / LEN, len(text.encode("utf-8"))))
    idx = {c: full[ord(c) - BASE] for c in "随手记想法" if BASE <= ord(c) <= END}
    print("  samples: %s" % idx)
    return 0


if __name__ == "__main__":
    sys.exit(main())
