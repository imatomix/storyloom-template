#!/usr/bin/env python3
"""小説原稿の文体を計測する。使い方: prose-stats.py <原稿.md>"""
import re
import sys

SENTENCE_END = re.compile(r"(?<=[。！？])")
DIALOGUE_OPENERS = ("「", "『")
SCENE_BREAK = "◇"
PRESENT_ENDINGS = set("うくすつぬふむゆるぐずづぶぷいだ")
SHORT_MAX = 15
MEDIUM_MAX = 35


def strip_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[end + 5:]
    return text


def split_paragraphs(body):
    blocks = [b.strip() for b in re.split(r"\n\s*\n", body)]
    return [b for b in blocks if b and b != SCENE_BREAK]


def split_sentences(paragraph):
    return [s.strip() for s in SENTENCE_END.split(paragraph) if s.strip()]


def ending_of(sentence):
    core = sentence.rstrip("。！？")
    if core.endswith("た"):
        return "past"
    if core and core[-1] in PRESENT_ENDINGS:
        return "present"
    return "other"


def ratio(part, whole):
    return part / whole if whole else 0.0


def longest_run(items):
    best = run = 0
    previous = None
    for item in items:
        run = run + 1 if item == previous else 1
        best = max(best, run)
        previous = item
    return best


def measure(text):
    paragraphs = split_paragraphs(strip_frontmatter(text))
    dialogue = [p for p in paragraphs if p.startswith(DIALOGUE_OPENERS)]
    narrative = [split_sentences(p) for p in paragraphs if not p.startswith(DIALOGUE_OPENERS)]
    sentences = [s for paragraph in narrative for s in paragraph]
    lengths = [len(s.rstrip("。！？")) for s in sentences]
    endings = [ending_of(s) for s in sentences]
    count = len(sentences)

    return "\n".join([
        f"地の文: {count} 文 / 会話: {len(dialogue)} 行（会話の比率 {ratio(len(dialogue), len(dialogue) + count):.0%}）",
        f"文の長さ: 平均 {ratio(sum(lengths), count):.1f} 字 / 最長 {max(lengths, default=0)} 字"
        f" / 短 {ratio(sum(1 for n in lengths if n <= SHORT_MAX), count):.0%}"
        f" / 中 {ratio(sum(1 for n in lengths if SHORT_MAX < n <= MEDIUM_MAX), count):.0%}"
        f" / 長 {ratio(sum(1 for n in lengths if n > MEDIUM_MAX), count):.0%}",
        f"語尾: た {ratio(endings.count('past'), count):.0%}"
        f" / 現在形 {ratio(endings.count('present'), count):.0%}"
        f" / 体言止め・その他 {ratio(endings.count('other'), count):.0%}"
        f" / 同じ語尾の最大連続 {longest_run(endings)}",
        f"段落: {len(paragraphs)} / 地の文の段落あたり {ratio(count, len(narrative)):.1f} 文"
        f" / 1 文だけの段落 {ratio(sum(1 for p in narrative if len(p) == 1), len(narrative)):.0%}",
    ])


def main(argv):
    if len(argv) != 2:
        print("使い方: prose-stats.py <原稿.md>", file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding="utf-8") as f:
            text = f.read()
    except OSError as error:
        print(f"ファイルを読めません: {error}", file=sys.stderr)
        return 2
    print(measure(text))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
