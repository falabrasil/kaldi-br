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
dir **must** contain two subdirs, one for a male speaker and the second for a
female one, which are expected to come from `inaSpeechSegmenter` (inaSS.) Both
subdirectories must contain a pair of audio-transcription files (namely `.wav`
and `.txt` extensions, the script will sanity-check it.)

In theory, `pyannote-audio` solves the entire diarization problem, but it does
not filter out music nor noise, so inaSS has a point there. A second issues is
that inaSS uses TensorFlow as ML backend while pyannote uses PyTorch. It would
be nice to unify. Third and last, both libs are far from perfect: frequent
misalignments/missegmentations/misclusterings.

The expected format of the subdirs within the input directory is as follows:
two IDs separated by an underscore char, the second ID starting with a gender
ID (`M` of `F`.)

```text
Dir name: <SOME_ID>_<GENDER_ID><SOME_ID>
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

## Requirements

```bash
$ pip install -r requirements.txt
```

- pyannote.audio (includes scipy, numpy, etc.)
- torch
