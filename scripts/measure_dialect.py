#!/usr/bin/env python3
"""Measure how much of a dialect ARB is verbatim Mandarin (普通话占比).

Usage: python3 scripts/measure_dialect.py [--raw] lib/l10n/app_wuu.arb ...
"""
import json
import re
import sys
from pathlib import Path

BASE = Path("lib/l10n/app_zh.arb")

# Entries where keeping the Mandarin form is legitimate: language endonyms,
# product/brand names, and pure ASCII technical tokens.
INVARIANT_KEYS = {
    "appTitle", "defaultStudentName",
    "simplifiedChinese", "english", "traditionalChineseHK", "traditionalChineseTW",
    "japanese", "spanish", "french", "portuguese", "russian",
    "cantonese", "wuSuzhou", "xiangChangsha", "jianghuaiHefei", "ganNanchang",
    "followSystem",
}
CJK = re.compile(r"[㐀-鿿]")


def load(path):
    with open(path, "r", encoding="utf-8") as f:
        return {k: v for k, v in json.load(f).items() if not k.startswith("@")}


def measure(dialect_path, raw=False):
    zh = load(BASE)
    dl = load(dialect_path)
    considered, verbatim = 0, []
    for k, zv in zh.items():
        if k not in dl:
            continue
        if k in INVARIANT_KEYS:
            continue
        # Skip strings with no Chinese content: pure ASCII tokens, numbers,
        # URLs, placeholders-only.
        if not CJK.search(zv):
            continue
        considered += 1
        if dl[k] == zv:
            verbatim.append((k, zv))
    ratio = len(verbatim) / considered if considered else 0.0
    return ratio, considered, verbatim


def main():
    raw = "--raw" in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith("--")] or [
        "lib/l10n/app_wuu.arb",
        "lib/l10n/app_hsn.arb",
        "lib/l10n/app_gan.arb",
        "lib/l10n/app_zh_hefei.arb",
    ]
    failed = False
    for f in files:
        ratio, n, verbatim = measure(f, raw)
        flag = "✅" if ratio <= 0.30 else "❌"
        if ratio > 0.30:
            failed = True
        print(f"{flag} {Path(f).name:22s} 普通话 {ratio:6.1%}  ({len(verbatim)}/{n} 判定为普通话)")
        if verbatim and (raw or ratio > 0.30):
            for k, v in verbatim[:200]:
                print(f"      {k:32s} {v}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()