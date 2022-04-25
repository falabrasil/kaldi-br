#!/usr/bin/env python
#
# author: mar 2021
# cassio batista - https://cassota.gitlab.io


import sys
import os
import re
from datetime import datetime


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('usage: %s <start-time> <end-time>')
        print('  <*-time> is a string in the format %Y-%m-%d_%H:%M:%S')
        sys.exit(1)

    s, e = sys.argv[1:3]
    s_year, s_month, s_day, s_hour, s_min, s_sec = re.split('[:_-]', s)
    e_year, e_month, e_day, e_hour, e_min, e_sec = re.split('[:_-]', e)

    st = datetime(int(s_year), int(s_month), int(s_day),
                  int(s_hour), int(s_min), int(s_sec))
    et = datetime(int(e_year), int(e_month), int(e_day),
                  int(e_hour), int(e_min), int(e_sec))

    elapsed, unit = (et - st).total_seconds(), 's'
    if elapsed > 59.9:
        elapsed, unit = elapsed / 60.0, 'm'
    if elapsed > 59.9:
        elapsed, unit = elapsed / 60.0, 'h'

    print('~%05.2f%s' % (elapsed, unit))
