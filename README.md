# FalaBrasil Scripts for Kaldi :brazil:

This repo contains instructions and scripts to train acoustic models using
Kaldi over the datasets in Brazilian Portuguese (or just "general Portuguese").
You may also find some scripts for forced alignment and speaker diarization.

:speaking_head: :octocat: Looking for speech datasets in Brazilian Portuguese?
Check out our "Speech Datasets" GitHub repo (based on DVC for storage):
https://github.com/falabrasil/speech-datasets

:spiral_notepad: :octocat: :fox_face: Looking for language models (LM)? 
Check out the following GitHub repo 
(notice there's a pair repo on GitLab for LFS storage):
https://github.com/falabrasil/lm-br

:newspaper: :octocat: :fox_face: Looking for phonetic dictionaries? 
Check out the following GitHub repo 
(notice there's a pair repo on GitLab for LFS storage):
https://github.com/falabrasil/dicts-br

:label: :fox_face: :whale: Wanna create your own phonetic dictionary?
Check out our tagger tool GitLab repo (there's also a dockerized version): 
https://gitlab.com/fb-nlp/nlp-generator

:coffee: Looking for Kaldi installation instructions? Check out our install
guide on [`INSTALL.md`](INSTALL.md) file or just go follow Kaldi documentation 
directly: https://github.com/kaldi-asr/kaldi

:footprints: If you're looking for a tutorial on data preparation and a
step-by-step guide on how to train acoustic models from scratch using Kaldi,
the best we can offer is this [written tutorial](TUTORIAL.md).


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

See [`fb-gentle/`](./fb-gentle) dir.
Based on ASpIRE `nnet3` recipe.

```bash
$ ./prep_gentle.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/s5/
$ ./run.sh
```

:warning: it didn't work. See README inside.

## Model training for phonetic alignment (UFPAlign)

See [`fb-ufpalign/`](./fb-ufpalign) dir.
Based on LibriSpeech `nnet3` recipe, in the hopes of future compatibility with
MFA.

```bash
$ ./prep_ufpalign.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/s5/
$ ./run_all.sh
```

## Speaker diarization (CallHome)

See [`fb-callhome/`](./fb-callhome) dir.
Based on CALLHOME v2 recipe. This uses pre-trained models on English data for
inference only rather than training one from scratch.

```bash
$ ./prep_callhome.sh /path/to/kaldi/egs/myproject
$ cd /path/to/kaldi/egs/myproject/v2/
$ ./run.sh
```

Standalone clustering procedure based on `pyannote.audio` lib can also be
found under [`utils/clustering/`](utils/clustering)_diarization dir.


# Citation

If you use these codes or want to mention the paper referred above, please cite 
us as one of the following: 

## [IberSPEECH 2018](https://www.isca-speech.org/archive/iberspeech_2018/batista18_iberspeech.html)

> Batista, C., Dias, A.L., Sampaio Neto, N. (2018) Baseline Acoustic Models for
> Brazilian Portuguese Using Kaldi Tools. Proc. IberSPEECH 2018, 77-81, DOI:
> 10.21437/IberSPEECH.2018-17.

```bibtex
@inproceedings{Batista18,
  author     = {Cassio Batista and Ana Larissa Dias and Nelson {Sampaio Neto}},
  title      = {{Baseline Acoustic Models for Brazilian Portuguese Using Kaldi Tools}},
  year       = {2018},
  booktitle  = {Proc. IberSPEECH 2018},
  pages      = {77--81},
  doi        = {10.21437/IberSPEECH.2018-17},
  url        = {http://dx.doi.org/10.21437/IberSPEECH.2018-17}
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

## [EURASIP 2022](https://asp-eurasipjournals.springeropen.com/articles/10.1186/s13634-022-00844-9)

> Batista, C., Dias, A.L. & Neto, N.
> Free resources for forced phonetic alignment in Brazilian Portuguese based on Kaldi toolkit.
> EURASIP J. Adv. Signal Process. 2022, 11 (2022).
> https://doi.org/10.1186/s13634-022-00844-9

```bibtex
@article{Batista22,
  author     = {Batista, Cassio and Dias, Ana Larissa and Neto, Nelson},
  title      = {Free resources for forced phonetic alignment in Brazilian Portuguese based on Kaldi toolkit},
  journal    = {EURASIP Journal on Advances in Signal Processing},
  year       = {2022},
  month      = {Feb},
  day        = {19},
  volume     = {2022},
  number     = {1},
  pages      = {11},
  issn       = {1687-6180},
  doi        = {10.1186/s13634-022-00844-9},
  url        = {https://doi.org/10.1186/s13634-022-00844-9}
}
```


[![FalaBrasil](https://gitlab.com/falabrasil/avatars/-/raw/main/logo_fb_git_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](https://gitlab.com/falabrasil/avatars/-/raw/main/logo_ufpa_git_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2022)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    
