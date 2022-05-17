# FalaBrasil main recipe for acoustic modelling

- Data: https://github.com/falabrasil/speech-datasets
- Models: https://gitlab.com/fb-resources/kaldi-br

TDNN-F took about 16h to train for 5 epochs on an RTX 3080.
i-Vector train in about a day on 8 parallel jobs (2, 2, 2).
Tests with online decoding + 4-gram carpa rescoring.
Beam was set to 10 and lattice-beam to 6.0 for fast inference.
Some values make sense, others do not, especially CORAA's.
Debugging with tri-sat decoding should be considered before next training.

| dataset 			| fb v0.1.1 | vosk pt v0.3 | odd |
|:-------------:|:---------:|:------------:|:---:|
| coddef 				|  2.48   	|         		 | 		 |
| cetuc 				|  6.39   	|         		 | 		 |
| constituicao 	|  3.18   	|         		 | 		 |
| coraa 				| 52.97   	|         		 | \*\*|
| cv 						| 24.03   	|         		 |  	 |
| lapsbm 				|  9.84   	|         		 | 		 |
| lapsstory 		| 14.06   	|         		 | 		 |
| mls 					| 27.52   	|         		 | \*	 |
| mtedx 				| 31.04   	|         		 | \*	 |
| spoltech 			| 15.83   	|         		 | 		 |
| vf 						| 19.32   	|         		 | 		 |
| westpoint 		|  6.37   	|         		 | 		 |


:warning: Maybe something wrong with CORAA data prep.

:warning: Still need to run tests on vosk pt model.


[![FalaBrasil](https://gitlab.com/falabrasil/avatars/-/raw/main/logo_fb_git_footer.png)](https://ufpafalabrasil.gitlab.io/ "Visite o site do Grupo FalaBrasil") [![UFPA](https://gitlab.com/falabrasil/avatars/-/raw/main/logo_ufpa_git_footer.png)](https://portal.ufpa.br/ "Visite o site da UFPA")

__Grupo FalaBrasil (2022)__ - https://ufpafalabrasil.gitlab.io/      
__Universidade Federal do Pará (UFPA)__ - https://portal.ufpa.br/     
Cassio Batista - https://cassota.gitlab.io/    
