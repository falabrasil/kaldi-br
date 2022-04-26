#!/usr/bin/env python3
#
# parses coraa *.csv files into Kaldi files.
# this was easier than bash.
#
# author: apr 2022
# cassio batista - https://cassota.gitlab.io

import sys
import os
#import csv

import pandas as pd


def usage():
    print(f"usage: {sys.argv[0]} <csv-file> <data-dir>")
    sys.exit(1)


def path2uttid(path):
    basedir = os.path.basename(os.path.dirname(path))
    basefile = os.path.basename(path.replace(".wav", ""))
    return f"{basedir}_{basefile}"


def soxify_path(basedir, old_path):
    new_path = os.path.join(basedir, old_path)
    return f"sox -G ${new_path} -c1 -b16 -r16k -esigned -t wav - |"


if __name__ == "__main__":
    try:
        csv_file, data_dir = sys.argv[1:]
    except (IndexError, ValueError):
        usage()

    if not os.path.isfile(csv_file):
        print(usage)
    os.makedirs(data_dir, exist_ok=True)

    corpus_dir = os.path.join(os.path.dirname(csv_file), "data")
    df = pd.read_csv(csv_file)
    df['uttid'] = df['file_path'].map(lambda x: path2uttid(x))
    df['file_path'] = df['file_path'].map(lambda x: soxify_path(corpus_dir, x))
    df['text'] = df['text'].map(lambda x: x.lower())

    # FIXME I couldn\'t get rid of the double quotes in white-space-separeted
    # strings when the delimiter (sep) between uttid and value is a white space 
    # https://stackoverflow.com/questions/21147058/pandas-to-csv-output-quoting-issue
    df.sort_values(by=['uttid'], inplace=True)
    df.to_csv(os.path.join(data_dir, "wav.scp"), sep="\t",
              columns=['uttid', 'file_path'], header=False, index=False)
              #quoting=csv.QUOTE_NONE, quotechar="", escapechar=" ")
    # FIXME there may be implicit speaker markers on this dataset. a careful
    # inspection could be done later to find patterns
    df.to_csv(os.path.join(data_dir, "utt2spk"), sep="\t",
              columns=['uttid', 'uttid'], header=False, index=False)
              #quoting=csv.QUOTE_NONE, quotechar="", escapechar=" ")
    df.to_csv(os.path.join(data_dir, "text"), sep="\t", 
              columns=['uttid', 'text'], header=False, index=False)
              #quoting=csv.QUOTE_NONE, quotechar="")
    # FIXME subprocess.Popen wouldn\'t\'ve been that bad
    os.system(f"utils/utt2spk_to_spk2utt.pl {data_dir}/utt2spk > {data_dir}/spk2utt")
    os.system(f"utils/validate_data_dir.sh {data_dir} --no-feats --non-print")
