#!/usr/bin/env python3
"""小説原稿の文体を計測する。使い方: prose-stats.py <原稿.md>"""
import re
import sys

# 「行く。」のように句点の直後に閉じ括弧が来る場合は、括弧の外まで一文とみなす
SENTENCE_END = re.compile(r"(?<=[。！？])(?![」』）])")
DIALOGUE_CLOSERS = {"「": "」", "『": "』"}
SCENE_BREAK = "◇"
PRESENT_ENDINGS = set("うくすつぬふむゆるぐずづぶぷいだ")
U_ROW = set("うくすつぬふむゆるぐずづぶぷ")
# 「行くんだ」「なんだ」「のだ」は現在形。「しゃがみこんだ」「並んだ」は過去形
NOT_PAST_BEFORE_NDA = U_ROW | set("たなの")
SHORT_MAX = 15
MEDIUM_MAX = 35


def strip_frontmatter(text):
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            return text[end + 5:]
    return text


def split_paragraphs(body):
    # 空行で区切る原稿も、空行なしで 1 行 1 段落の原稿も同じに扱えるよう、行を段落とする
    lines = [line.strip() for line in body.splitlines()]
    return [line for line in lines if line and line != SCENE_BREAK]


def split_dialogue(paragraph):
    """会話で始まる段落を、会話と、その後ろに続く地の文に分ける。"""
    closer = DIALOGUE_CLOSERS[paragraph[0]]
    depth = 0
    for i, char in enumerate(paragraph):
        if char == paragraph[0]:
            depth += 1
        elif char == closer:
            depth -= 1
            if depth == 0:
                return paragraph[: i + 1], paragraph[i + 1:].strip()
    return paragraph, ""


def split_sentences(paragraph):
    return [s.strip() for s in SENTENCE_END.split(paragraph) if s.strip()]


def ending_of(sentence):
    core = sentence.rstrip("。！？")
    if core.endswith("た"):
        return "past"
    if core.endswith("んだ") and len(core) >= 3 and core[-3] not in NOT_PAST_BEFORE_NDA:
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
    dialogue = []
    narrative = []
    sentences = []
    for paragraph in paragraphs:
        if paragraph[0] in DIALOGUE_CLOSERS:
            line, rest = split_dialogue(paragraph)
            dialogue.append(line)
            sentences.extend(split_sentences(rest))
        else:
            narrative.append(split_sentences(paragraph))
            sentences.extend(narrative[-1])
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
        f"段落: {len(paragraphs)} / 地の文の段落あたり {ratio(sum(len(p) for p in narrative), len(narrative)):.1f} 文"
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
