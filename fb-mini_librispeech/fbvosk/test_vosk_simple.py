#!/usr/bin/python3
#
# original at https://github.com/alphacep/vosk-api/tree/master/python/example

from vosk import Model, KaldiRecognizer
import sys
import os
import wave

if len(sys.argv) != 3:
    print("usage: %s <model-dir> <wav-file>")
    sys.exit(1)

wf = wave.open(sys.argv[2], "rb")
if wf.getnchannels() != 1 or wf.getsampwidth() != 2 or wf.getcomptype() != "NONE":
    print ("Audio file must be WAV format mono PCM.")
    exit (1)

model = Model(sys.argv[1])
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
