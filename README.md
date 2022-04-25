# FalaBrasil Scripts for Kaldi :brazil:

This repo contains instructions and scripts to train acoustic models using
Kaldi over the datasets in Brazilian Portuguese (or just "general Portuguese").

:fox_face: Looking for speech datasets in Brazilian Portuguese?
Check out our "Speech Datasets" GitHub repo (based on DVC for storage):
https://github.com/falabrasil/speech-datasets

:fox_face: Looking for language models or phonetic dictionaries?
Check out either of the following (notice there's a pair repo on GitLab for LFS
storage):

- https://github.com/falabrasil/lm-br
- https://github.com/falabrasil/dicts-br

:coffee: Looking for Kaldi installation instructions? Check out our install
guide on [`INSTALL.md`](INSTALL.md) file or just go follow Kaldi documentation 
directly: https://github.com/kaldi-asr/kaldi


## Model training for speech recognition (Vosk + LapsBM)

See [`fb-lapsbm/`](./fb-lapsbm) dir.
Based on Mini-librispeech `nnet3` recipe (`local/chain/tuning/run_tdnn_1j.sh`),
adapted for a quick train exec over LapsBenchmark.

```bash
$ ./prep_lapsbm.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/s5/
$ ./run.sh
```

For online decoding, please check
[`fb-lapsbm/local/vosk/`](./fb-lapsbm/local/vosk) dir.


## Model training for speech recognition (Vosk + Datasets)

See [`fb-falabrasil/`](./fb-falabrasil) dir.
This is expected to become the main recipe for Brazilian Portuguese, as we are
planning on releasing the acoustic models as well.

Also based on Mini-librispeech recipe, same as above, but now it runs over all
public speech datasets in Portugese (NOTE: not only "Brazilian" Portuguese!) we
are aware of, which have been gathered here:
https://github.com/falabrasil/speech-datasets

```bash
$ ./prep_falabrasil.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/s5/
$ ./run.sh
```

For online decoding, please check
[`fb-falabrasil/local/vosk/`](./fb-falabrasil/local/vosk) dir.


## Model training for phonetic alignment (Gentle)

See [`fb-aspire/`](./fb-aspire) dir.
Based on ASpIRE `nnet3` recipe.

```bash
$ ./prep_aspire.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/s5/
$ ./run.sh
```

## Model training for phonetic alignment (LibriSpeech)

See [`fb-librispeech/`](./fb-librispeech) dir.
Based on LibriSpeech `nnet3` recipe.

```bash
$ ./prep_libri.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/s5/
$ ./run_all.sh
```

:warning: These scripts are experimental for forced phonetic alignment. For
transcription you may stick with Mini-libri recipe.

## Speaker diarization

See [`fb-callhome_diarization/`](./fb-callhome_diarization) dir.
Based on CALLHOME v2 recipe.

```bash
$ ./prep_callhome.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/v2/
$ ./run.sh
```

Standalone clustering procedure based on pyanote-audio lib can also be found
under [`utils/clustering/`](utils/clustering) dir.


# Citation

If you use these codes or want to mention the paper referred above, please cite 
us as one of the following: 

## [IberSPEECH 2018](https://www.isca-speech.org/archive/iberspeech_2018/batista18_iberspeech.html)

> Batista, C., Dias, A.L., Sampaio Neto, N. (2018) Baseline Acoustic Models for
> Brazilian Portuguese Using Kaldi Tools. Proc. IberSPEECH 2018, 77-81, DOI:
> 10.21437/IberSPEECH.2018-17.

```bibtex
@inproceedings{Batista2018,
  author    = {Cassio Batista and Ana Larissa Dias and Nelson {Sampaio Neto}},
  title     = {{Baseline Acoustic Models for Brazilian Portuguese Using Kaldi Tools}},
  year      = {2018},
  booktitle = {Proc. IberSPEECH 2018},
  pages     = {77--81},
  doi       = {10.21437/IberSPEECH.2018-17},
  url       = {http://dx.doi.org/10.21437/IberSPEECH.2018-17}
}
```

:warning: This paper uses the outdated nnet2 recipes, while this repo has been
updated to the chain models' recipe via nnet3 scripts. If you really want nnet2
scripts, you may find them on tag `nnet2`. Try running `git tag`.

## [BRACIS 2020](https://link.springer.com/chapter/10.1007/978-3-030-61377-8_44)

> Dias A.L., Batista C., Santana D., Neto N. (2020)
> Towards a Free, Forced Phonetic Aligner for Brazilian Portuguese Using Kaldi Tools.
> In: Cerri R., Prati R.C. (eds) Intelligent Systems. BRACIS 2020. 
> Lecture Notes in Computer Science, vol 12319. Springer, Cham.
> https://doi.org/10.1007/978-3-030-61377-8_44

```bibtex
@inproceedings{Dias20,
  author     = {Dias, Ana Larissa and Batista, Cassio and Santana, Daniel and Neto, Nelson},
  editor     = {Cerri, Ricardo and Prati, Ronaldo C.},
  title      = {Towards a Free, Forced Phonetic Aligner for Brazilian Portuguese Using Kaldi Tools},
  booktitle  = {Intelligent Systems},
  year       = {2020},
  publisher  = {Springer International Publishing},
  address    = {Cham},
  pages      = {621--635},
  isbn       = {978-3-030-61377-8}
}
```

## EURASIP 2021

Coming soon.


[![FalaBrasil](https://gitlab.com/falabrasil/avatars/-/raw/main/logo_fb_git_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](https://gitlab.com/falabrasil/avatars/-/raw/main/logo_ufpa_git_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2021)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    
