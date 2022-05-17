#!/usr/bin/env python3
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

import sys
import os
import re


def usage():
    print(f"usage: {sys.argv[0]} <text> <segments> <utt2spk> <log-file>")
    sys.exit(1)


if __name__ == "__main__":
    try:
        text_file, seg_file, utt2spk_file, log_file = sys.argv[1:]
    except (ValueError, IndexError):
        usage()

    with open(text_file) as f:
        text = f.read().split('\n')
        text.pop(-1)
    with open(seg_file) as f:
        segments = f.read().split('\n')
        segments.pop(-1)
    with open(log_file) as f:
        log = f.read()

    # norm.py    ERROR 5434 ! bad line ! ♪ ♪ Será que Deus ♪ ♪ pode me ouvir?
    badlines = [int(i) for i in re.findall(r"norm.py\s+ERROR\s(\d+)\s.*", log)]
    for lineno in badlines:
        segments[lineno - 1] = None
    
    m, n = len(segments) - len(badlines), len(text)
    assert m == n, f" number of entries do not match: {m} vs. {n}"
    with open(text_file, 'w') as tf, open(seg_file, 'w') as sf, \
            open(utt2spk_file, 'w') as uf:
        for txt, seg in zip(text, [x for x in segments if x is not None]):
            uttid, spkid = seg.split()[0:2]
            uf.write(f"{uttid} {spkid}\n")
            tf.write(f"{uttid} {txt}\n")
            sf.write(f"{seg}\n")
