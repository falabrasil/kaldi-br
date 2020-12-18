# Clustering from Speaker Embeddings

:information_source: Based on https://github.com/pyannote/pyannote-audio.

## Usage

```bash
$ python cluster.py $HOME/Downloads/mclip /tmp/outdir
```

## Description

This script mainly extracts speaker embeddings (features) from lots of audio 
files and decides which audios belong to the same speaker. This task is known 
as clustering, as is often applied as the last step of speaker diarization.

The script receives two directories as args. The restriction is that the input
dir **must** contain at least one subdir, either for a male or female speaker,
which are expected to come from `inaSpeechSegmenter` (inaSS.) Subdirectories
must contain a pair of audio-transcription files (namely `.wav` and `.txt`
extensions, the script will sanity-check it.) The output dir will not be wiped
out at each run, so be careful to remove it before execution while debugging.

The expected format of the subdirs within the input directory is as follows:
two IDs separated by an underscore char, the second ID starting with a gender
ID (`M` of `F`.)

```text
<BROADCASTER_ID>_<GENDER_ID><YMD_DATE_TAG>
```

e.g.:

```text
andaiafm_M20201105
andaiafm_F20201105
```

```bash
$ tree $HOME/Downloads/mclip -C | head
$HOME/Downloads/mclip              $HOME/Downloads/mclip
├── andaiafm_F20201105             ├── andaiafm_M20201105
│   ├── mclip-00000003.txt         │   ├── mclip-00000001.txt
│   ├── mclip-00000003.wav         │   ├── mclip-00000001.wav
│   ├── mclip-00000004.txt         │   ├── mclip-00000002.txt
│   ├── mclip-00000004.wav         │   ├── mclip-00000002.wav
│   ├── mclip-00000005.txt         │   ├── mclip-00000012.txt
│   ├── mclip-00000005.wav         │   ├── mclip-00000012.wav
│   ├── mclip-00000006.txt         │   ├── mclip-00000013.txt
│   ├── mclip-00000006.wav         │   ├── mclip-00000013.wav
...                                ...
```

Example output:

```text
$ tree /tmp/outdir
/tmp/outdir                                     /tmp/outdir
└── andaiafm20201105                            └── andaiafm20201105
    ├── andaiafm20201105-F0001                      ├── andaiafm20201105-M0001
    │   ├── andaiafm20201105F0001_000000.txt        │   ├── andaiafm20201105M0001_000000.txt
    │   ├── andaiafm20201105F0001_000000.wav        │   ├── andaiafm20201105M0001_000000.wav
    │   ├── andaiafm20201105F0001_000001.txt        │   ├── andaiafm20201105M0001_000001.txt
    │   ├── andaiafm20201105F0001_000001.wav        │   ├── andaiafm20201105M0001_000001.wav
    │   ├── andaiafm20201105F0001_000002.txt        │   ├── andaiafm20201105M0001_000002.txt
    │   ├── andaiafm20201105F0001_000002.wav        │   ├── andaiafm20201105M0001_000002.wav
    │   ├── andaiafm20201105F0001_000003.txt        │   ├── andaiafm20201105M0001_000003.txt
    │   ├── andaiafm20201105F0001_000003.wav        │   ├── andaiafm20201105M0001_000003.wav
    │   ├── andaiafm20201105F0001_000004.txt        │   ├── andaiafm20201105M0001_000004.txt
    │   ├── andaiafm20201105F0001_000004.wav        │   ├── andaiafm20201105M0001_000004.wav
    │   ├── andaiafm20201105F0001_000005.txt        │   ├── andaiafm20201105M0001_000005.txt
    │   ├── andaiafm20201105F0001_000005.wav        │   ├── andaiafm20201105M0001_000005.wav
    │   ├── andaiafm20201105F0001_000006.txt        │   ├── andaiafm20201105M0001_000006.txt
    │   ├── andaiafm20201105F0001_000006.wav        │   ├── andaiafm20201105M0001_000006.wav
    │   ├── andaiafm20201105F0001_000007.txt        │   ├── andaiafm20201105M0001_000007.txt
    │   ├── andaiafm20201105F0001_000007.wav        │   ├── andaiafm20201105M0001_000007.wav
    │   ├── andaiafm20201105F0001_000008.txt        │   ├── andaiafm20201105M0001_000008.txt
    │   ├── andaiafm20201105F0001_000008.wav        │   ├── andaiafm20201105M0001_000008.wav
    │   ├── andaiafm20201105F0001_000009.txt        │   ├── andaiafm20201105M0001_000009.txt
    │   ├── andaiafm20201105F0001_000009.wav        │   ├── andaiafm20201105M0001_000009.wav
    │   ├── andaiafm20201105F0001_000010.txt        │   ├── andaiafm20201105M0001_000010.txt
    │   ├── andaiafm20201105F0001_000010.wav        │   ├── andaiafm20201105M0001_000010.wav
    │   ├── andaiafm20201105F0001_000011.txt        │   ├── andaiafm20201105M0001_000011.txt
    │   ├── andaiafm20201105F0001_000011.wav        │   ├── andaiafm20201105M0001_000011.wav
    │   ├── andaiafm20201105F0001_000012.txt        │   ├── andaiafm20201105M0001_000012.txt
    │   ├── andaiafm20201105F0001_000012.wav        │   ├── andaiafm20201105M0001_000012.wav
    │   ├── andaiafm20201105F0001_000013.txt        │   ├── andaiafm20201105M0001_000013.txt
    │   ├── andaiafm20201105F0001_000013.wav        │   ├── andaiafm20201105M0001_000013.wav
    │   ├── andaiafm20201105F0001_000014.txt        │   ├── andaiafm20201105M0001_000014.txt
    │   ├── andaiafm20201105F0001_000014.wav        │   ├── andaiafm20201105M0001_000014.wav
    │   ├── andaiafm20201105F0001_000015.txt        │   ├── andaiafm20201105M0001_000015.txt
    │   └── andaiafm20201105F0001_000015.wav        ...
    ├── andaiafm20201105-F0002                      ├── andaiafm20201105-M0002
    │   ├── andaiafm20201105F0002_000016.txt        │   ├── andaiafm20201105M0002_000113.txt
    │   ├── andaiafm20201105F0002_000016.wav        │   └── andaiafm20201105M0002_000113.wav
    │   ├── andaiafm20201105F0002_000017.txt        ├── andaiafm20201105-M0003
    │   ├── andaiafm20201105F0002_000017.wav        │   ├── andaiafm20201105M0003_000114.txt
    │   ├── andaiafm20201105F0002_000018.txt        │   └── andaiafm20201105M0003_000114.wav
    │   ├── andaiafm20201105F0002_000018.wav        ├── andaiafm20201105-M0004
    │   ├── andaiafm20201105F0002_000019.txt        │   ├── andaiafm20201105M0004_000115.txt
    │   ├── andaiafm20201105F0002_000019.wav        │   └── andaiafm20201105M0004_000115.wav
    │   ├── andaiafm20201105F0002_000020.txt        ├── andaiafm20201105-M0005
    │   ├── andaiafm20201105F0002_000020.wav        │   ├── andaiafm20201105M0005_000116.txt
    │   ├── andaiafm20201105F0002_000021.txt        │   └── andaiafm20201105M0005_000116.wav
    │   ├── andaiafm20201105F0002_000021.wav        ├── andaiafm20201105-M0006
    │   ├── andaiafm20201105F0002_000022.txt        │   ├── andaiafm20201105M0006_000117.txt
    │   └── andaiafm20201105F0002_000022.wav        │   └── andaiafm20201105M0006_000117.wav
    ├── andaiafm20201105-F0003                      ├── andaiafm20201105-M0007
    │   ├── andaiafm20201105F0003_000023.txt        │   ├── andaiafm20201105M0007_000118.txt
    │   └── andaiafm20201105F0003_000023.wav        │   └── andaiafm20201105M0007_000118.wav
    ├── andaiafm20201105-F0004                      ├── andaiafm20201105-M0008
    │   ├── andaiafm20201105F0004_000024.txt        │   ├── andaiafm20201105M0008_000119.txt
    │   └── andaiafm20201105F0004_000024.wav        │   └── andaiafm20201105M0008_000119.wav
    ├── andaiafm20201105-F0005                      ├── andaiafm20201105-M0009
    │   ├── andaiafm20201105F0005_000025.txt        │   ├── andaiafm20201105M0009_000120.txt
    │   ├── andaiafm20201105F0005_000025.wav        │   ├── andaiafm20201105M0009_000120.wav
    │   ├── andaiafm20201105F0005_000026.txt        │   ├── andaiafm20201105M0009_000121.txt
    │   ├── andaiafm20201105F0005_000026.wav        │   ├── andaiafm20201105M0009_000121.wav
    │   ├── andaiafm20201105F0005_000027.txt        │   ├── andaiafm20201105M0009_000122.txt
    │   ├── andaiafm20201105F0005_000027.wav        │   ├── andaiafm20201105M0009_000122.wav
    │   ├── andaiafm20201105F0005_000028.txt        │   ├── andaiafm20201105M0009_000123.txt
    │   ├── andaiafm20201105F0005_000028.wav        │   ├── andaiafm20201105M0009_000123.wav
    │   ├── andaiafm20201105F0005_000029.txt        │   ├── andaiafm20201105M0009_000124.txt
    │   ├── andaiafm20201105F0005_000029.wav        │   ├── andaiafm20201105M0009_000124.wav
    │   ├── andaiafm20201105F0005_000030.txt        │   ├── andaiafm20201105M0009_000125.txt
    │   ├── andaiafm20201105F0005_000030.wav        │   ├── andaiafm20201105M0009_000125.wav
    │   ├── andaiafm20201105F0005_000031.txt        │   ├── andaiafm20201105M0009_000126.txt
    │   ├── andaiafm20201105F0005_000031.wav        │   ├── andaiafm20201105M0009_000126.wav
    │   ├── andaiafm20201105F0005_000032.txt        │   ├── andaiafm20201105M0009_000127.txt
    │   ├── andaiafm20201105F0005_000032.wav        │   ├── andaiafm20201105M0009_000127.wav
    │   ├── andaiafm20201105F0005_000033.txt        │   ├── andaiafm20201105M0009_000128.txt
    │   ├── andaiafm20201105F0005_000033.wav        │   ├── andaiafm20201105M0009_000128.wav
    │   ├── andaiafm20201105F0005_000034.txt        │   ├── andaiafm20201105M0009_000129.txt
    │   ├── andaiafm20201105F0005_000034.wav        │   ├── andaiafm20201105M0009_000129.wav
    │   ├── andaiafm20201105F0005_000035.txt        │   ├── andaiafm20201105M0009_000130.txt
    │   └── andaiafm20201105F0005_000035.wav        │   ├── andaiafm20201105M0009_000130.wav
    ├── andaiafm20201105-F0006                      │   ├── andaiafm20201105M0009_000131.txt
    │   ├── andaiafm20201105F0006_000036.txt        │   ├── andaiafm20201105M0009_000131.wav
    │   └── andaiafm20201105F0006_000036.wav        │   ├── andaiafm20201105M0009_000132.txt
    ├── andaiafm20201105-F0007                      │   ├── andaiafm20201105M0009_000132.wav
    │   ├── andaiafm20201105F0007_000037.txt        │   ├── andaiafm20201105M0009_000133.txt
    │   └── andaiafm20201105F0007_000037.wav        │   ├── andaiafm20201105M0009_000133.wav
    ├── andaiafm20201105-F0008                      │   ├── andaiafm20201105M0009_000134.txt
    │   ├── andaiafm20201105F0008_000038.txt        │   ├── andaiafm20201105M0009_000134.wav
    │   ├── andaiafm20201105F0008_000038.wav        │   ├── andaiafm20201105M0009_000135.txt
    │   ├── andaiafm20201105F0008_000039.txt        │   ├── andaiafm20201105M0009_000135.wav
    │   ├── andaiafm20201105F0008_000039.wav        │   ├── andaiafm20201105M0009_000136.txt
    │   ├── andaiafm20201105F0008_000040.txt        │   ├── andaiafm20201105M0009_000136.wav
    │   ├── andaiafm20201105F0008_000040.wav        │   ├── andaiafm20201105M0009_000137.txt
    │   ├── andaiafm20201105F0008_000041.txt        │   ├── andaiafm20201105M0009_000137.wav
    │   ├── andaiafm20201105F0008_000041.wav        │   ├── andaiafm20201105M0009_000138.txt
    │   ├── andaiafm20201105F0008_000042.txt        │   ├── andaiafm20201105M0009_000138.wav
    │   ├── andaiafm20201105F0008_000042.wav        │   ├── andaiafm20201105M0009_000139.txt
    │   ├── andaiafm20201105F0008_000043.txt        │   ├── andaiafm20201105M0009_000139.wav
    │   └── andaiafm20201105F0008_000043.wav        ...
```


### Issues

In theory, `pyannote-audio` solves the entire diarization problem, but it does
not filter out music nor noise, so inaSS has a point there. A second issue is
that inaSS uses TensorFlow as ML backend while pyannote uses PyTorch. It would
be nice to unify. Third and last, both libs are far from perfect: frequent
misalignments/missegmentations/misclusterings occur.


## Requirements

```bash
$ pip install -r requirements.txt
```

- pyannote.audio (includes scipy, numpy, etc.)
- torch
