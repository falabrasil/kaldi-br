# Online decoding

This folder contains scripts that help gather the most important files from
your already-trained model with Kaldi, and use these files into the online
decoder for recognising a single file.

Right now the two most common APIs over the Kaldi online decoding environment
are the Alumäe's [GStreamer server API][1], and the Alpha Cephei's 
[Vosk API][2]. See scripts `prep_gst.sh` and `prep_vosk.sh`, respectively.

[1]: https://github.com/alumae/kaldi-gstreamer-server
[2]: https://github.com/alphacep/vosk-api 

[![FalaBrasil](../doc/logo_fb_github_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](../doc/logo_ufpa_github_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2020)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    
