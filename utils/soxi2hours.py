#!/usr/bin/env python3
#
# receives a timelist from stdin genereated in `soxi -d` format and sums the
# times up to give total duration in hours
#
# author: mar 2021
# cassio batista - https://cassota.gitlab.io

import sys
import os
from datetime import timedelta

# FIXME not sure what condition to check in order to print this usage message
def usage():
    print("usage: %s <duration-list>" % sys.argv[0])
    print("  <duration-list> is a list of duration that comes from soxi")
    print("  e.g.: find DATA_DIR -name '*.wav' | xargs soxi -d | utils/soxi2hours.py")
    sys.exit(1)


if __name__ == "__main__":

    i, t = 0, timedelta(seconds=0)
    try:
        for line in iter(sys.stdin):
            h, m, s = line.split(":")
            t += timedelta(seconds=int(h) * 3600 + int(m) * 60 + float(s))
            total_hours = t.total_seconds() / 3600.0
            i += 1
            print("\r[%s] %d files, ~%05.2fh" % (sys.argv[0], i, total_hours),
                  end="", flush=True)
    except KeyboardInterrupt:
        print(" **kbd interrupted")
        pass

    print()
