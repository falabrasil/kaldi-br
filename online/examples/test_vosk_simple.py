#!/usr/bin/python3
#
# original at https://github.com/alphacep/vosk-api/tree/master/python/example

from vosk import Model, KaldiRecognizer
import sys
import os
import wave

#if not os.path.exists("model-en"):
#    print ("Please download the model from https://github.com/alphacep/kaldi-android-demo/releases and unpack as 'model-en' in the current folder.")
#    exit (1)

wf = wave.open(sys.argv[1], "rb")
if wf.getnchannels() != 1 or wf.getsampwidth() != 2 or wf.getcomptype() != "NONE":
    print ("Audio file must be WAV format mono PCM.")
    exit (1)

model = Model("/home/cassio/vosk-model")
rec = KaldiRecognizer(model, wf.getframerate())

while True:
    data = wf.readframes(1000)
    if len(data) == 0:
        break
    if rec.AcceptWaveform(data):
        print(rec.Result())
        #rec.Result()
    else:
        #print(rec.PartialResult())
        rec.PartialResult()

print(rec.FinalResult())
#with open(sys.argv[1].replace('.wav', '.txt'), 'r') as txt:
#    for line in txt:
#        print('> "text" : "%s" (original)' % line.strip())
