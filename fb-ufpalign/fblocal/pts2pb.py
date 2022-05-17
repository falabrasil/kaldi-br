#!/usr/bin/env python3
#
# author: nov 2020
# cassio batista - https://cassota.gitlab.io

import sys
import os
import glob

from termcolor import colored

TAG = sys.argv[0]
N = 200


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print('usage: %s <ground-truth-pts-dir> <predicted-pts-dir> '
              '<gender-tag> <pb-out-file>' % TAG)
        print('  e.g.: %s {ds2fb,21_csl_mfa_gentle/mfa2fb}/workspace/pts_out/fb/ M /tmp/out.pb' % TAG)
        print('  NOTE: scripts under ds2fb/ and mfa2fb/ dirs should have been '
              'executed beforehand, obviously')
        sys.exit(1)

    truth_dir = sys.argv[1]
    predict_dir = sys.argv[2]
    gender_tag = sys.argv[3]
    pb_file = sys.argv[4]
    for d in (truth_dir, predict_dir):
        if not os.path.isdir(d):
            print('%s: error: dir should exist: "%s"' % (TAG, d))
            sys.exit(1)
    if gender_tag != 'M' and gender_tag != 'F':
        print('%s: error: gender tag should be either "M" of "F"' % TAG)
        sys.exit(1)

    truth_pts_filelist = []
    predict_pts_filelist = []
    for i in range(1, N + 1):
        basefile = '%s-%03d.pts' % (gender_tag, i)
        #print('\r[%s] processing file %s' % (TAG, basefile),
        #       end=' ', flush=True, file=sys.stderr)
        truth_pts = os.path.join(truth_dir, basefile)
        predict_pts = os.path.join(predict_dir, basefile)
        if os.path.isfile(truth_pts) and os.path.isfile(predict_pts):
            truth_pts_filelist.append(truth_pts)
            predict_pts_filelist.append(predict_pts)

    phonetic_boundaries = []
    for truth_pts, predicted_pts in zip(truth_pts_filelist,
                                        predict_pts_filelist):
        basefile = os.path.basename(truth_pts)
        with open(truth_pts) as f, open(predicted_pts) as g:
            truth, predicted = f.readlines(), g.readlines()
        if len(truth) != len(predicted):
            print()
            print(colored('%s: file sizes differ: %d vs %d. this should not '
                          'be happening' % (TAG, len(truth), len(predicted)),
                          'yellow'))
            continue
        phonetic_boundaries.append('#%s' % basefile)
        for t, p in zip(truth, predicted):
            pb = abs(float(t.split()[1]) - float(p.split()[1]))
            phonetic_boundaries.append('%.4f' % pb)

    with open(pb_file, 'w') as f:
        for item in phonetic_boundaries:
            f.write(item + '\n')
    print('ok\toutput written to %s' % pb_file)
