# Generate a compact CJK -> pinyin-first-letter index for the app.
# Output: assets/pinyin/first_letter.txt
#   line 1: "# cjk-first-letter v1 base=%d len=%d" % (BASE, LEN)
#   lines 2..: 64 letters per line, index i corresponds to chr(BASE + i)
#   '?' means "no letter" (rare chars / symbols inside the block)
#
# Why not a Dart package: lpinyin pins sdk >=2.12 <3.0.0 and cannot resolve
# on Dart 3.x, so the table is baked at build time and shipped as an asset.
import os
import sys

from pypinyin import lazy_pinyin, Style

BASE = 0x4E00
END = 0x9FFF  # inclusive, CJK Unified Ideographs block
LEN = END - BASE + 1

OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "assets", "pinyin", "first_letter.txt",
)


def build() -> str:
    chars = []
    i = 0
    while i < LEN:
        ch = chr(BASE + i)
        # lazy_pinyin on a single char returns a one-element list; style
        # FIRST_LETTER keeps only the initial so the table stays one byte/char.
        try:
            py = lazy_pinyin(ch, style=Style.FIRST_LETTER, errors="ignore")
        except Exception:
            py = []
        letter = py[0][0].lower() if py and py[0] else "?"
        if letter < "a" or letter > "z":
            letter = "?"
        chars.append(letter)
        i += 1
    return "".join(chars)


def main() -> int:
    body = build()
    assert len(body) == LEN, (len(body), LEN)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    lines = ["# cjk-first-letter v1 base=%d len=%d" % (BASE, LEN)]
    for i in range(0, LEN, 64):
        lines.append(body[i:i + 64])
    text = "\n".join(lines) + "\n"
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    covered = sum(1 for c in body if c != "?")
    print("wrote %s" % OUT)
    print("chars=%d covered=%d (%.1f%%) bytes=%d" % (
        LEN, covered, covered * 100.0 / LEN, len(text.encode("utf-8"))))
    for sample in ["随想随记", "钢结构", "手工", "想法"]:
        got = "".join(
            body[ord(c) - BASE] if BASE <= ord(c) <= END else c for c in sample
        )
        print("  %s -> %s" % (sample, got))
    return 0


if __name__ == "__main__":
    sys.exit(main())
