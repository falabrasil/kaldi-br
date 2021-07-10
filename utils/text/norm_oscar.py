#!/usr/bin/env
# -*- encoding: utf-8 -*-
#
# normalises Portuguese portion of OSCAR dataset
#
# author: july 2021
# cassio batista - ctbatista@cpqd.com.br


import sys
import os
import re
import logging
import argparse
import calendar
import locale

from num2words import num2words

locale.setlocale(locale.LC_ALL, 'pt_BR.UTF-8')

MAX_WORD_LEN = 35

# TODO eugénio, género, !parabéns
# https://stackoverflow.com/questions/5984633/python-re-sub-group-number-after-number
COMMON_MAPS = {
    r"ü": "u",
    r"ám": "am",
    r"ón": "ôn",
    r"n\.?[°º]": "número ",
    r"(\d+).?[°º]": "\g<1>º",
    r"(\d+).?[ª]": "\g<1>ª",
    r"óm": "ôm",
    r"sãeste": "são",  # what the actual fuck?
    r"(\d+([.,]\d+)?)(mm|cm|m|km|m²|m³|km²|mg|g|kg|km/h|[º°]C)": "\g<1> \g<3>",
}

# TODO MB GB KB 
UNIT_MAPS = {
    "^mm$": "milímetros",
    "^cm$": "centímetros",
    "^m$": "metros",
    "^km$": "quilômetros",
    "^m²$": "metros quadrados",
    "^m³$": "metros cúbicos",
    "^km²$": "quilômetros quadrados",
    "^km/h$": "quilômetros por hora",
    "^mg$": "miligramas",
    "^g$": "gramas",
    "^kg$": "quilos",
    "^[º°]c$": "graus celsius",
}

# TODO ordinal: o\s -> a
NUM_CARD_FEM = {
    "um": "uma",
    "dois": "duas",
    "zentos": "zentas",
    "centos": "centas",
}

logging.basicConfig(format="%(filename)s %(levelname)8s %(message)s",
                    filename="sys.stderr", filemode="w")
logger = logging.getLogger(os.path.basename(__file__))
logger.setLevel(logging.DEBUG)

parser = argparse.ArgumentParser(description="Normalize OSCAR corpus Portuguese")
parser.add_argument("corpus_in_file")
parser.add_argument("corpus_out_file")

args = parser.parse_args()


def parse_number(curr_str_num, next_str_num=""):
    
    # regular, cardinal number
    match = re.match(r"^\d+$", curr_str_num)
    if match:
        number = num2words(curr_str_num, lang='pt_BR')
        # here we check whether the following word is feminine.
        # if so, parse the numbers as in NUM_CARD_FEM
        if next_str_num:
            if next_str_num.endswith("a") or next_str_num.endswith("as"):
                for k, v in NUM_CARD_FEM.items():
                    number = number.replace(k, v)
            if next_str_num.endswith("á") or next_str_num.endswith("ás"):
                for k, v in NUM_CARD_FEM.items():
                    number = number.replace(k, v)
        return "%s" % number
    # FIXME this is not working
    # cardinal float or integers separated by either commas or dots
    # https://stackoverflow.com/questions/31675741/regex-to-intercept-integer-and-float-in-python/31675916
    match = re.match(r"^[+-]?(\d+([.,]\d*)?|[.,]\d+)(\d+)?$", curr_str_num)
    if match:
        number = match.group().replace(",", ".")
        number = num2words(number, lang='pt_BR')
        return "%s" % number
    # ordinal number
    match = re.match(r"^(\d+)([ªº°])$", curr_str_num)
    if match:
        number, order = match.groups()
        number = num2words(number, lang='pt_BR', to='ordinal')
        if order == "ª":
            number = re.sub(r"o[\s|$]?", "a ", number)
        return "%s" % number
    # date: DD/MM/(YY)?YY
    match = re.match(r"^(0*[1-9]|[12][0-9]|3[01])/(0*[1-9]|1[0-2])/([0-9]{2}|[12][0-9]{3})$", curr_str_num)
    if match:
        day, month, year = match.groups()
        day = num2words(day, lang='pt_BR')
        month = calendar.month_name[int(month)]
        if len(year) == 2:
            year = "20" + year if int(year) < 30 else "19" + year
        year = num2words(year, lang='pt_BR', to='year')
        return "%s de %s de %s" % (day, month, year)
    # date: DD/MM
    match = re.match(r"^(0*[1-9]|[12][0-9]|3[01])/(0*[1-9]|1[0-2])$", curr_str_num)
    if match:
        day, month = match.groups()
        day = num2words(day, lang='pt_BR')
        month = calendar.month_name[int(month)]
        return "%s de %s" % (day, month)
    # time: HH(:|h)MM(h|m|ø)
    match = re.match(r"^([01]*[0-9]|2[0-4])[h:](([0-5][0-9])[mh]?)?$", curr_str_num)
    if match:
        hour, _, mins = match.groups()
        if mins and mins != "00":
            mins = "meia" if mins == "30" and int(hour) < 13 else num2words(mins, lang='pt_BR')
            hour = "meio dia" if hour == "12" else num2words(hour, lang='pt_BR')
            return "%s e %s" % (hour, mins)
        hour = num2words(hour, lang='pt_BR')
        return "%s horas" % hour
    # percentage
    match = re.match(r"^(\d+([.,]\d+)?)%$", curr_str_num)
    if match:
        number = match.groups()[0].replace(",", ".")
        return "%s porcento" % num2words(number, lang='pt_BR')
    # TODO currency, e.g. (r$|u$|us$|€|£)(\d+)
    # TODO leis, e.g. 1.98989/2008
    # TODO barra, e.g. 1.7676/06
    # TODO resolução, e.g. 480x320

    return curr_str_num


def prenorm_word(word):

    # strip commas and quotes, then convert unit measures
    word = re.sub(r"^[,“”\"(]|[,“”\")]+$", "", word)
    for k, v in UNIT_MAPS.items():
        word = re.sub(k, v, word)
    return word


def normalize(old_sent):

    new_sent = []
    words = old_sent.split()
    while len(words):
        curr_word = prenorm_word(words.pop(0))
        if len(curr_word) > MAX_WORD_LEN:
            continue
        if re.match(r"\d", curr_word):
            try:
                next_word = prenorm_word(words.pop(0))
                word = parse_number(curr_word, next_word)
                words.insert(0, next_word)
            except IndexError:
                word = parse_number(curr_word)
        else:
            word = curr_word
        new_sent.append(word)
    return re.sub(r"\s\s+", " ", " ".join(new_sent)).strip()


if __name__ == "__main__":

    with open(args.corpus_in_file) as f:
        corpus = f.readlines()

    for i, line in enumerate(corpus):
        line = line.strip()
        logger.info("⁋ %s" % line)
        for sent in re.split(r"[.!?…;:]+(\s|$)", line):
            sent = re.sub(r"\$\s", "$", sent)
            for k, v in COMMON_MAPS.items():
                sent = re.sub(k, v, sent)
            sent = sent.strip()
            if sent:
                logger.debug("« %s" % sent)
                sent = normalize(sent.lower())
                logger.debug("» %s" % sent)
        logger.debug("--")
        if i == 100000:
            break
