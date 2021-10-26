#!/usr/bin/env python3
#
# author: dec 2020
# cassio batista - https://cassota.gitlab.io

import sys
import os
import glob

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("usage: %s <phones-file> <ctm-in-dir> <pts-out-dir>" % sys.argv[0])
        sys.exit(1)

    phones_file = sys.argv[1]
    ctm_dir = sys.argv[2]
    pts_dir = sys.argv[3]
    if not os.path.isfile(phones_file):
        print("[%s] error: phones.txt expected to exist: "
              "'%s'" % (sys.argv[0], phones_file))
        sys.exit(1)
    if not os.path.isdir(ctm_dir):
        print("[%s] error: ctm dir expected to exist: "
              "'%s'" % (sys.argv[0], ctm_dir))
        sys.exit(1)
    if not os.path.isdir(pts_dir):
        print("[%s] error: pts dir expected to exist: "
              "'%s'" % (sys.argv[0], pts_dir))
        sys.exit(1)

    print("[%s] mapping file '%s'" % (sys.argv[0], phones_file))
    with open(phones_file) as f:
        phones = f.readlines()
    mapping = {}
    for line in phones:
        phone, phoneid = line.split()
        mapping[phoneid] = phone.split("_")[0]

    for i, ctm_file in enumerate(sorted(glob.glob(os.path.join(ctm_dir, "*.ctm")))):
        #print("\r[%s] processing file %s" % (sys.argv[0], ctm_file),
        #       end=" ", flush=True, file=sys.stderr)
        pts = []
        with open(ctm_file) as ctm:
            for line in ctm:
                uttid, ch, start, dur, phoneid = line.split()
                p, ts = mapping[phoneid], float(start) + float(dur)
                if p != "sil":
                    pts.append("%s\t%.3f" % (p, ts))

        pts_file = os.path.basename(ctm_file.replace(".ctm", ".pts"))
        pts_file = os.path.join(pts_dir, pts_file)
        with open(pts_file, "w") as f:
            for item in pts:
                f.write(item.expandtabs(8) + "\n")
    print()
    try:
        print("[%s] done. %d ctm files processed" % (sys.argv[0], i))
    except NameError:
        print("[%s] error: no ctm files found under "
              "'%s'" % (sys.argv[0], ctm_dir))
        sys.exit(1)
