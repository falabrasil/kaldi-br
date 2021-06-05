# Online decoding

This folder contains scripts that help gather the most important files from
your already-trained model with Kaldi, and use these files into the online
decoder for recognising a single file.

Right now the most common/used/famous API over Kaldi's online decoding
environment is Alpha Cephei's [Vosk API][1]. See `prep_vosk.sh` and
`test_vosk_simple.py` scripts, which by the way should be executed in this very
same order.

There's also a script to run the Portuguese model from Vosk directly into
Kaldi. See `run_vosk_on_kaldi.sh` for that.


[1]: https://github.com/alphacep/vosk-api 


[![FalaBrasil](../../doc/logo_fb_github_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](../../doc/logo_ufpa_github_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2021)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    
