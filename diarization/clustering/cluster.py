#!/usr/bin/env python3
#
# author: dec 2020
# cassio batista - https://cassota.gitlab.io
#
# sponsored by MidiaClip (Salvador - BA)


import sys
import os
import shutil
import glob
import argparse
import logging
from collections import OrderedDict

import torch
import numpy as np

from pyannote.pipeline.blocks.clustering import (
    HierarchicalAgglomerativeClustering
)


logging.basicConfig(format="[%(filename)s] %(levelname)s: %(message)s",
                    level=logging.INFO)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
            description="Cluster audio files by speaker")
    parser.add_argument("in_dir", help="input dir")
    parser.add_argument("out_dir", help="output dir")

    # parse args and minimally validate input
    args = parser.parse_args()
    if not os.path.isdir(args.in_dir):
        logging.error("input dir does not exist: '%s'" % args.in_dir)
        sys.exit(1)
    if os.path.isdir(args.out_dir):
        logging.warning("output dir '%s' exists and *WILL NOT* "
                        "be overwritten " % args.out_dir)
    else:
        logging.info("creating output dir: '%s'" % args.out_dir)
        os.mkdir(args.out_dir)

    # input dir is expected to contain only two subdirectories,
    # one for a male and another for a female speaker
    subdirs = []
    for d in os.listdir(args.in_dir):
        d = os.path.join(args.in_dir, d)  # readlink -f
        if os.path.isdir(d):
            subdirs.append(d)

    if len(subdirs) < 1:
        logging.warning("expected at least one subdir in '%s'" % args.in_dir)
        sys.exit(1)

    logging.info("loading pyannote's speaker embedding model")
    model = torch.hub.load("pyannote/pyannote-audio", "emb")
    clustering = HierarchicalAgglomerativeClustering()

    for d in subdirs:
        # get broadcaster name and gender tag + transmission date from dir name
        broadcaster, gtx = d.split("/")[-1].split("_")
        gender, txdate = gtx[0].upper(), gtx[1:]

        # sanity check on gender tag
        if gender != "M" and gender != "F":
            logging.error("gender flag expected to be either M or F. "
                          "got '%s' instead" % gender)
            sys.exit(1)

        # scan subdirs looking for wav and txt files
        # later check if the numbers match, abort if it doesn't
        wavlist = sorted(glob.glob(os.path.join(d, "*.wav")))
        txtlist = sorted(glob.glob(os.path.join(d, "*.txt")))
        if len(wavlist) != len(txtlist):
            logging.error("number of audio and transcription files do not "
                          "match: %d vs %d" % (len(wavlist), len(txtlist)))
            sys.exit(1)

        # clustering: check `_turn_level()` method from `SpeechTurnClustering`
        # https://github.com/pyannote/pyannote-audio/blob/master/pyannote/audio/pipeline/speech_turn_clustering.py#L162
        X, labels, num_emb = [], [], 0
        for i, wavfile in enumerate(wavlist):
            # label = re.sub('[/.-]', ' ', wavfile).split()[-2]
            label = os.path.basename(wavfile)

            logging.info("extracting embeddings from '%s'" % wavfile)
            embedding = model(current_file={'audio': wavfile})
            num_emb += 1

            # I'm doing this because I found no way on earth to set a goddamn
            # `speech_turns` variable, which in turn contains a `Timeline`
            # object used for cropping
            # https://github.com/pyannote/pyannote-audio-hub#speaker-embedding
            # https://github.com/pyannote/pyannote-core/blob/develop/pyannote/core/timeline.py#L114
            for window, emb in embedding:
                x = embedding.crop(window)

                # TODO could I ignore this break and add multiple embedding
                # vectors for the same label? I know for a fact the mapping
                # label-cluster would be kept 1:1 if I moved in both `labels`
                # and `X` appends below...
                if len(x) > 0:
                    break

            # FIXME skip labels so small we don't have any embedding for it
            if len(x) < 1:
                logging.warning("well, we'll have to think of something for "
                                "utterances like '%s'" % wavfile)
                continue

            labels.append(label)
            X.append(np.mean(x, axis=0))

        # apply clustering of label embeddings
        logging.info("clustering files from '%s' subdir" % d)
        clusters = clustering(np.vstack(X))  # int indices

        # map each clustered label to its cluster (between 1 and N_CLUSTERS)
        # https://stackoverflow.com/questions/16772071/sort-dict-by-value-python
        mapping = {label: cluster for label, cluster in zip(labels, clusters)}
        mapping = OrderedDict(sorted(mapping.items(), key=lambda x:x[1]))

        # https://stackoverflow.com/questions/600268/mkdir-p-functionality-in-python/11101867#11101867
        for fileid, (label, cluster) in enumerate(mapping.items()):
            # dir names store tag and speaker id information
            tag = "%s%s" % (broadcaster, txdate)        # andaiafm20201105
            spk = "%s-%s%04d" % (tag, gender, cluster)  # andaiafm20201105-F0001

            src = os.path.join(d, label.replace(".wav", ""))
            dst = os.path.join(args.out_dir, tag, spk)
            if not os.path.isdir(dst):
                os.makedirs(dst, exist_ok=True)

            # andaiafm20201105/andaiafm20201105-F0001/andaiafm20201105F0001_000001.{wav,txt}
            dst = os.path.join(dst, "%s_%06d" % (spk.replace("-", ""), fileid))
            logging.info("copy: '%s'.{wav,txt} -> '%s'.{wav,txt}" % (src, dst))
            for ext in ("wav", "txt"):
                f = "%s.%s" % (src, ext)  # from source
                t = "%s.%s" % (dst, ext)  # to destination
                if os.path.isfile(t):
                    logging.warning("dst file '%s' exists, that's odd" % t)
                shutil.copy2(f, t)

        logging.info("done scanning subdir %s: %d embeddings extracted, "
                     "%d embeddings processed" % (d, num_emb, len(X)))
