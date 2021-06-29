#!/usr/bin/env python3
#
# this scripts reads phone boundary *.pb files from a dir (the files must be in
# the same dir) in order to extract statists like mean, standard deviation,
# accuracy percentage (<ms), etc from the distribution.
#
# authors: nov 2020
# cassio batista - https://cassota.gitlab.io/
# joão canavarro - EMAIL
#
# ref.: Montreal Forced Aligner: trainable text-speech alignment using Kaldi
# https://montrealcorpustools.github.io/Montreal-Forced-Aligner/images/MFA_paper_Interspeech2017.pdf


import sys
import os
import numpy as np
from collections import OrderedDict

EPS = 1e-15  # offset to avoid log(0) = -oo, same as sklearn.metrics.log_loss
BUCKETS_TEMPLATE = {10: 0, 25: 0, 50: 0, 100: 0}  # NOTE: MFA"s paper Table 1

def div():
    print("-------------------------------------------", end="")
    print("-------------------------------------------")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: %s <pb-file> [<pb-file>, ...]" % sys.argv[0])
        print("  <pb-file> is the the phone boundary log file")
        sys.exit(1)

    pb_list = []
    for pb_file in sys.argv[1:]:
        if not os.path.isfile(pb_file) or not pb_file.endswith(".pb"):
            print("%s: error: file '%s' does not exist or has invalid "
                  "format." % (sys.argv[0], pb_file))
            sys.exit(1)
        pb_list.append(pb_file)

    pb_stats = OrderedDict()
    pb_buckets_cdf = {}  # cummulative
    pb_buckets_pdf = {}  # non-cummulative
    for filename in pb_list:
        key = os.path.basename(filename).replace(".pb", "")
        with open(filename) as f:
            pb_contents = f.readlines()
        values = []
        for line in pb_contents:
            if line[0] == "#":
                continue
            values.append(float(line) * 1000.0)
        # create a bucket from template and iterate over each value to see in
        # which bucket it fits in
        pb_buckets_cdf[key] = dict(BUCKETS_TEMPLATE)
        for val in values:
            for buck in pb_buckets_cdf[key].keys():
                if val < buck:
                    pb_buckets_cdf[key][buck] += 1
        pb_buckets_pdf[key] = dict(BUCKETS_TEMPLATE)
        for val in values:
            for buck in pb_buckets_pdf[key].keys():
                if val < buck:
                    pb_buckets_pdf[key][buck] += 1
                    break
        pb_stats[key] = np.array(values)

    div()
    print("%-30s\t%-6s\t%-6s\t%-7s| " % ("dataset", "μ", "med", "σ"), end="")
    print("%-6s\t%-6s\t%-6s\t%-6s" % ("<10ms", "<25ms", "<50ms", "<100ms"))
    div()
    for i, (key, val) in enumerate(pb_stats.items()):
        print("%-30s\t%.3f\t%.3f\t%.3f |" % (key, val.mean(), np.median(val),
                                             val.std()), end=" ")
        for acc_cdf, acc_pdf in zip(pb_buckets_cdf[key].values(),
                                    pb_buckets_pdf[key].values()):
            percent_cdf = 100.0 * acc_cdf / float(val.size)
            percent_pdf = 100.0 * acc_pdf / float(val.size)
            print("%5.2f%%\t" % percent_cdf, end="")
        print()
    div()
    sys.stdout.flush()
