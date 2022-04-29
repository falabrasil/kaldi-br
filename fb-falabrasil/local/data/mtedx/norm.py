#!/usr/bin/env python3
# -*- encoding: utf-8 -*-
#
# Grupo FalaBrasil (2021)
# Universidade Federal do Pará (UFPA)
# License: MIT
#
# adapted from https://github.com/falabrasil/lm-br/blob/main/local/norm_oscar.py
#
# author: july 2021
# cassio batista - https://cassota.gitlab.io


import sys
import os
import re
import logging
import calendar
import locale

from num2words import num2words

locale.setlocale(locale.LC_ALL, 'pt_BR.UTF-8')

MAX_SENT_LEN = 800  # FIXME bunch of song lyrics not being filtered out
MAX_WORD_LEN = 35
MAX_NUM_LEN = 18  # ~1,000,000,000,000 (1 tri)

# TODO eugénio, género, !parabéns
# https://stackoverflow.com/questions/5984633/python-re-sub-group-number-after-number
# FIXME looks safer to add bos and eos, something like ^\s+\w(\s|$)
COMMON_MAPS = {
    r"ü": "u",
    r"§": " parágrafo ",
    r"&": " e ",
    r"e/ou": "e ou",
    r"(^|\s)pq": " por que",   # NOTE check me
    r"(^|\s)vc": " você",   # NOTE check me 
    r"bjs+": "beijos",
    r"sr\.\s": "senhor ",
    r"dr\.\s": "doutor ",
    r"sr[a|ª]\s": "senhora ",
    r"dr[a|ª]\s": "doutora ",
    r"ám": "am",
    r"ón": "ôn",
    r"én([aeiou])": "ên\g<1>",
    r"ém([aeiou])": "êm\g<1>",
    r"acç": "aç",  # acções (pt_EU)
    r"éi": "ei",
    r"sector": "setor",
    r"^á$": "à",
    r"n\.?[°º]": "número ",
    r"(\d+).?[°º]": "\g<1>º",
    r"(\d+).?[ª]": "\g<1>ª",
    r"mp(3|4)": "mp \g<1>",
    r"(2|3|4)d": "\g<1> d",
    r"óm": "ôm",
    r"ãeste": "ão",  # what the actual fuck?
    r"(\d+([.,]\d+)?)(mm|cm|m|km|m2|m²|m³|cm³|km³|km²|hz|mg|g|kg|km/h|[º°]c)": "\g<1> \g<3>",
}

# TODO MB GB KB
UNIT_MAPS = {
    "^mm$": "milímetros",
    "^cm$": "centímetros",
    "^m$": "metros",
    "^km$": "quilômetros",
    "^m²$": "metros quadrados",
    "^m2$": "metros quadrados",
    "^cm³$": "centímetros cúbicos",
    "^km³$": "quilômetros cúbicos",
    "^m³$": "metros cúbicos",
    "^km²$": "quilômetros quadrados",
    "^km/h$": "quilômetros por hora",
    "^mg$": "miligramas",
    "^g$": "gramas",
    "^kg$": "quilos",
    "^hz$": "hertz",
    "^[º°]c$": "graus celsius",
}

NUM_CARD_FEM = {
    "um": "uma",
    "dois": "duas",
    "zentos": "zentas",
    "centos": "centas",
}

logging.basicConfig(format="%(filename)s %(levelname)8s %(message)s")
logger = logging.getLogger(os.path.basename(__file__))
logger.setLevel(logging.ERROR)


def parse_number(curr_str_num, next_str_num=""):

    # regular, cardinal number
    # TODO embrace regular around parethesis, join with thousands' regex via |
    match = re.match(r"^\d+$", curr_str_num)
    if match:
        number = num2words(curr_str_num, lang='pt_BR')
        # here we check whether the following word is female-gendered.
        # uma/umas: casa/casas, rã/rãs, babá/babás, !a, !as
        if next_str_num and re.match(r"^.+[aáã]s?$", next_str_num):
            for k, v in NUM_CARD_FEM.items():
                number = number.replace(k, v)  # NOTE check me
        return number
    # cardinal greater than a thousand whose units are dot-separated
    # 1.000, 22.456, 333.977, 1.000.000, 1.000.000.000, !111.11
    match = re.match(r"^(\d{1,3}(\.\d{3})+)$", curr_str_num)
    if match:
        number = num2words(match.group().replace(".", ""), lang='pt_BR')
        # uma/umas: casa/casas, rã/rãs, babá/babás, !a, !as
        if next_str_num and re.match(r"^.+[aáã]s?$", next_str_num):
            for k, v in NUM_CARD_FEM.items():
                number = number.replace(k, v)  # NOTE check me
        return number
    # FIXME this is not working -- or is it?
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
            number = re.sub(r"o(\s|$)", "a ", number)
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
    # time: HH(:|h)MM?(h|m|ø)
    # 10:40h, 10h40m, 10h40, 10h
    # 10:30 = dez e meia, 12:30 = meio dia e meia, 16:30 = dezesseis e trinta
    match = re.match(r"^([01]*[0-9]|2[0-4])[h:](([0-5][0-9])[mh]?)?$", curr_str_num)
    if match:
        hour, _, mins = match.groups()
        if mins and mins != "00":
            mins = "meia" if mins == "30" and int(hour) < 13 else num2words(mins, lang='pt_BR')
            hour = "meio dia" if hour == "12" else num2words(hour, lang='pt_BR')
            for k, v in NUM_CARD_FEM.items():
                hour = hour.replace(k, v)  # 1:30 = umA e meia, 2:00 = DUAS horas
            return "%s e %s" % (hour, mins)
        hour = num2words(hour, lang='pt_BR')
        for k, v in NUM_CARD_FEM.items():
            hour = hour.replace(k, v)  # 1:30 = umA e meia, 2:00 = DUAS horas
        return "%s horas" % hour
    # percentage: 2,40%, 2.40%, 2%
    match = re.match(r"^(\d+([.,]\d+)?)%$", curr_str_num)
    if match:
        number = match.groups()[0].replace(",", ".")
        return "%s por cento" % num2words(number, lang='pt_BR')
    # currency, thousands e.g. (r$|u$|us$|€|£)(\d+)
    match = re.match(r"^(r\$|u\$|us\$|€|£)(\d+(\.\d{3})*)([,.]\d{1,2})?$", curr_str_num)
    if match:
        currency, value, _, cents = match.groups()
        value = num2words(value.replace(".", ""), lang='pt_BR')
        if currency.startswith("r"):
            currency = "real" if value == "um" else "reais"
        elif currency.startswith("u"):
            currency = "dólar" if value == "um" else "dólares"
        elif currency == "€":
            currency = "euro" if value == "um" else "euros"
        elif currency == "£":
            currency = "libra esterlina" if value == "um" else "libras esterlinas"
        if cents and cents[1:] != "00":
            # comma followed by a single digit.
            if next_str_num.startswith("mi") or next_str_num.startswith("bi"):
                return "%s vírgula %s" % (value, num2words(cents[1:], lang='pt_BR'))
            # e.g.: r$200,4 milhões = duzentos vírgula quatro milhões de reais
            if len(cents) == 2:
                return "%s vírgula %s %s de %s" % (value,
                        num2words(cents[1:], lang='pt_BR'), next_str_num, currency)
            # len cents == 3
            number = "%s %s e %s centavos" % (value, currency,
                      num2words(cents[1:], lang='pt_BR'))
            return  number.replace("zero %s e" % currency, "")
        # from now on, no cents
        if next_str_num.startswith("mi") or next_str_num.startswith("bi"):
            return value
        return "%s %s" % (value, currency)
    # leis e barra, e.g. 1.98989/2008
    match = re.match(r"^(\d+(\.\d+)?)/([0-9]{2}|[12][0-9]{3})$", curr_str_num)
    if match:
        #logger.debug("peguei uma lei: %s" % str(match.groups()))
        value, _, year = match.groups()
        value = value.replace(".", "")
        if int(value) > 100 and len(year) == 2 and (int(year) > 88 or int(year) < 30):
            year = "20" + year if int(year) < 30 else "19" + year
        value = num2words(value, lang='pt_BR')
        year = num2words(year, lang='pt_BR')
        return "%s barra %s" % (value, year)
    # phone number
    match = re.match(r"^([349]\d{3,4}-\d{4})$", curr_str_num)
    if match:
        #logger.debug("peguei um cel: %s" % str(match.groups()))
        cel = match.group().replace("-", "")
        return " ".join([num2words(d, lang='pt_BR').replace("seis", "meia") for d in list(cel)])
    # CEP
    match = re.match(r"^(\d{5})-(\d{3})$", curr_str_num)
    if match:
        #logger.debug("peguei um cep: %s" % str(match.groups()))
        a, b = match.groups()
        return " ".join([num2words(d, lang='pt_BR').replace("seis", "meia") for d in list(a) + list(b)])
    # resolução, e.g. 480x320
    match = re.match(r"^(\d+)x(\d+)$", curr_str_num)
    if match:
        #logger.debug("peguei uma resolução: %s" % str(match.groups()))
        width, height = match.groups()
        width, height = num2words(width, lang='pt_BR'), num2words(height, lang='pt_BR')
        return "%s por %s" % (width, height)

    #logger.error("» ! bad number ! %s" % curr_str_num)
    new_str = []
    for char in " ".join(list(re.sub(r"[\-\.\,]", " ", curr_str_num))):
        if re.match(r"(.*?)\d(.*?)", char):
            new_str.append(parse_number(char, None))
        else:
            new_str.append(char)
    return " ".join(new_str)


def prenorm_word(word):

    # strip commas and quotes, then convert unit measures
    #logger.debug("word in : %s" % word)
    word = re.sub(r"[–―—\+\[\]‰ˆ‡œ˜‹›«»ž]+|\.{3}", "", word)
    word = re.sub(r"^[,“”‘’™\"'({.•-]+|[,“”‘’\"')}.-]+$", "", word)
    word = re.sub(r"í’|’í", "í", word)
    word = re.sub(r"’s", "'s", word)
    word = re.sub(r"[.!?…]+(\s|$)", "", word)
    for k, v in UNIT_MAPS.items():
        word = re.sub(k, v, word)
    #logger.debug("word out: %s" % word.strip())
    return word.strip()


def normalize(old_sent):

    new_sent = []
    words = old_sent.split()
    while len(words):
        curr_word = prenorm_word(words.pop(0))
        # email with no numbers and no special chars but dot and at
        match = re.match(r"^([a-z]+)@([a-z]+)((\.[a-z]+)+)+$", curr_word)
        if match:
            #logger.debug("pegueo um email: %s" % str(match.groups()))
            user, domain, ext, _ = match.groups()
            new_sent.append(user)
            new_sent.append("arroba")
            new_sent.append(domain)
            new_sent.append(" ponto ".join(e for e in ext.split(".")))
            continue
        # website
        match = re.match(r"^([a-z]{2,6}://|www\.)([a-z]{3,20})((\.[a-z]{3,10})+){1,3}([/?&].*)?", curr_word)
        if match:
            #logger.debug("pegueo um saite: %s" % str(match.groups()))
            www_or_protocol, domain, ext, _, _ = match.groups()
            www_or_protocol = www_or_protocol.replace("://", " dois pontos barra barra")
            new_sent.append(" ponto ".join(wp for wp in www_or_protocol.split(".")))  # FIXME one point, no need to loop
            new_sent.append(domain)
            new_sent.append(" ponto ".join(e for e in ext.split(".")))
            continue
        if len(curr_word) > MAX_WORD_LEN:
            logger.error("! word overflow ! %s" % curr_word)
            return None
        if re.match(r"(.*?)\d(.*?)", curr_word):
            if len(curr_word) > MAX_NUM_LEN:
                logger.error("! number overflow ! %s" % curr_word)
                return None
            try:
                next_word = prenorm_word(words[0])  # do not pop!
                word = parse_number(curr_word, next_word).replace(",", "")
            except IndexError:
                word = parse_number(curr_word).replace(",", "")
        else:
            word = curr_word
        new_sent.append(re.sub(r"[/\",:#@\$\?_=\.]", " ", word.replace("%", " por cento ")))
    return re.sub(r"\s\s+", " ", " ".join(new_sent)).strip()

def firewall(line):
    if "♪" in line:
        return True
    return False


for lineno, line in enumerate(sys.stdin):
    line = line.strip()
    if firewall(line):
        logger.error("%d ! bad line ! %s" % (lineno + 1, line))
        continue

    sent = re.sub(r"[.!?…;:|]+(\s|$)", " ", line).strip()
    sent = re.sub(r"\$\s", "$", sent).lower()
    for k, v in COMMON_MAPS.items():
        sent = re.sub(k, v, sent)
    sent = sent.strip()
    if sent:
        if len(sent) > MAX_SENT_LEN:
            logger.error("%d ! sentence overflow ! %s" % (lineno + 1, sent))
            continue
        sent = normalize(sent)
        sent = re.sub(r"<i>|< i>|< i >", " ", sent).strip()
        if sent == "aplausos":
            logger.error("%d ! bad sentence ! %s" % (lineno + 1, sent))
            continue
        if sent and re.match(r"^[a-zàáéíóúâêôãõçèïöñ \-']+$", sent):
            print(sent)
        else:
            if sent:
                logger.error("%d ! bad sentence ! %s" % (lineno + 1, sent))
            else:
                logger.error("%d ! bad line ! %s" % (lineno + 1, line))
