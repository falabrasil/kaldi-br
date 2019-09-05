# Kaldi - tutorial for training acoustic models

[Paper](https://www.isca-speech.org/archive/IberSPEECH_2018/abstracts/IberS18_P1-13_Batista.html): **Baseline Acoustic Models for Brazilian Portuguese Using Kaldi Tools**    
A comparison between Kaldi and CMU Sphinx for Brazilian Portuguese was
performed. Resources for both toolkits were developed and made publicly 
available to the community.
    
# Requirements
* **Git**: is needed to download Kaldi and this recipe.
* **Kaldi**: is the toolkit for speech recognition that we use.
* **G2P**: is a grapheme-to-phoneme converter for Brazilian Portuguese. This software is available at https://gitlab.com/fb-nlp/nlp-generator.git

# Tutorial
The tutorial is composed mainly by two big steps:

```mermaid
graph LR;
    DataGraph --> TrainGraph
    subgraph "AM Train"
    TrainGraph("util/run.sh")
    end
    
    subgraph "Preparing directories"
    A[fb_00*.sh] --> B[fb_01*.sh]
    B --> DataGraph[fb_02*.sh]
    end
```


## Preparing directories
According to Kaldi's [tutorial for dummies](http://kaldi-asr.org/doc/kaldi_for_dummies.html),
the directory tree for new projects must follow the structure below:

```text
           path/to/kaldi/egs/YOUR_PROJECT_NAME/
                                 ├─ path.sh
                                 ├─ cmd.sh
                                 ├─ run.sh
                                 │ 
  .--------------.-------.-------:------.------.-------------.
  |              |       |       |      |      |             |
 MFCC/         data/   utils/  steps/  exp/  local/        conf/
  └─ make_mfcc   |                             └─ score.sh   ├─ decode.config
  .--------------:--------------.                            └─ mfcc.conf
  │              │              │
train/          test/         local/
  ├─ spkTR_1/    ├─ spkTE_1/    └─ dict/
  ├─ spkTR_2/    ├─ spkTE_2/        ├─ lexicon.txt
  ├─ spkTR_3/    ├─ spkTE_3/        ├─ non_silence_phones.txt
  ├─ spkTR_n/    ├─ spkTE_n/        ├─ optional_silence.txt
  │              │                  ├─ silence_phones.txt
  ├─ spk2gender  ├─ spk2gender      └─ extra_questions.txt
  ├─ wav.scp     ├─ wav.scp            
  ├─ text        ├─ text               
  ├─ utt2spk     ├─ utt2spk            
  └─ corpus.txt  └─ corpus.txt         
```     

* __fb\_00\_create\_envtree.sh__ :
This script creates the directory structure shown above, except the `spkXX_n`
inside the `data/train` and `data/test` folders. Notice that the data-dependent
files (inside the `data` dir), although created, they __DO NOT__ have any
content yet. IOW, they're only initialized as empty files. A stupid choice of
ours.    

* __fb\_01\_split\_train\_test.sh__:
This script fulfills the `data/train` and `data/test` directories. The data is
divided as training set and test set (90% for training and 10% for testing), and
the files within the dirs are data-dependent. The folders `train/spkTR_n` and
`test/spkTE_n` contain symbolic links to the actual wav-transcription base dir.   

* __fb\_02\_define\_localdict.sh__:
This script specially fulfills the files inside `local/dict` dir. A dependency of this script
is the `g2p` software.   

Below you can see the proper way to execute the scripts. Executing the scripts
with no params will also prompt a usage help.

```bash
$ ./fb_00_create_envtree.sh   path/to/kaldi/egs/YOUR_PROJECT_NAME
$ ./fb_01_split_train_test.sh path/to/audio/dataset/dir    path/to/kaldi/egs/YOUR_PROJECT_NAME
$ ./fb_02_define_localdict.sh path/to/kaldi/egs/YOUR_PROJECT_NAME    path/to/g2p/dir
```   
   
## Training Acoustic Models

After running the above scripts, your project directory will be ready and you can start training acoustic models with Kaldi. 
The `run.sh` is a shell script recipe for training a hybrid HMM_DNN acoustic model and it will be located at `path/to/kaldi/egs/YOUR_PROJECT_NAME/`.
Below you can see the proper way to execute the training script.
```bash
$ cd path/to/kaldi/egs/YOUR_PROJECT_NAME
$ ./run.sh        
```        

The Figure below shows the pipeline to training a HMM-DNN acoustic model
using Kaldi (for more details read our paper.

![alt text](doc/kaldiflowchart.png)    

# Demo Corpora
If you are using our 
[demo corpora](https://gitlab.com/fb-asr/fb-am-tutorial/demo-corpora) dataset or 
another similar small audio corpora, you will
need to change the value of the `num_utts_subset` parameter in the file
`path/to/kaldi/egs/YOUR_PROJECT_NAME/steps/nnet2/get_egs.sh`, from 300 to 20 in
order to the [DNN script work properly][2].    

* __util/RESULTS__:
This file contains the results of the acoustic models obtained using the demo
corpora. The demo corpora is available at
[https://gitlab.com/fb-asr/fb-am-tutorial/demo-corpora.git][1].   

# Language Model
A language model is available at
[https://gitlab.com/fb-asr/fb-asr-resources/kaldi-resources.git][3]. It is downloaded and used by default by the `run.sh` script. If you want to train your own language model look at the commented section `MAKING lm.arpa` in `run.sh` script for a example of how to do it.   

A nice tutorial by [Eleanor Chodroff](https://www.eleanorchodroff.com/tutorial/kaldi/kaldi-training.html) 
might also be worthy taking a look at.

[1]:https://gitlab.com/fb-asr/fb-am-tutorial/demo-corpora.git
[2]:https://groups.google.com/forum/#!msg/kaldi-help/e2EHVCQGE_Y/0uwBkGm9BQAJ
[3]:https://gitlab.com/fb-asr/fb-asr-resources/kaldi-resources.git

# Citation

If you use these codes or want to mention the paper referred above, please cite 
us as one of the following: 

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

[![FalaBrasil](doc/logo_fb_github_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](doc/logo_ufpa_github_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2019)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    
Larissa Dias - larissa.engcomp@gmail.com
