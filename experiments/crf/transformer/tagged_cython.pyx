import re
from os.path import join, dirname
from languageflow.transformer.text import Text
from languageflow.reader.dictionary_loader import DictionaryLoader
from transformer.path import get_dictionary_path

words = DictionaryLoader(get_dictionary_path()).words
lower_words = set([word.lower() for word in words])

cdef text_lower(str word):
    return word.lower()


cdef text_isdigit(word):
    return str(word.isdigit())

cdef text_isallcap(word):
    word = Text(word)
    for letter in word:
        if not letter.istitle():
            return False
    return True


cdef text_istitle(word):
    word = Text(word)
    if len(word) == 0:
        return False
    try:
        titles = [s[0] for s in word.split(" ")]
        for token in titles:
            if token[0].istitle() is False:
                return False
        return True
    except:
        return False


def text_is_in_dict(word):
    return str(word.lower() in lower_words)


def apply_function(name, word):
    functions = {
        "lower": text_lower,
        "istitle": text_istitle,
        "isallcap": text_isallcap,
        "isdigit": text_isdigit,
        "is_in_dict": text_is_in_dict
    }
    return functions[name](word)


cdef template2features(sent, int i, str token_syntax, debug=True):
    """
    :type token: object
    """
    columns = []
    for j in range(len(sent[0])):
        columns.append([t[j] for t in sent])
    matched = re.match(
        "T\[(?P<index1>\-?\d+)(\,(?P<index2>\-?\d+))?\](\[(?P<column>.*)\])?(\.(?P<function>.*))?",
        token_syntax)
    cdef int index1
    column = matched.group("column")
    column = int(column) if column else 0
    index1 = int(matched.group("index1"))
    index2 = matched.group("index2")
    index2 = int(index2) if index2 else None
    func = matched.group("function")
    if debug:
        prefix = "%s=" % token_syntax
    else:
        prefix = ""
    if i + index1 < 0:
        return ["%sBOS" % prefix]
    if i + index1 >= len(sent):
        return ["%sEOS" % prefix]
    if index2 is not None:
        if i + index2 >= len(sent):
            return ["%sEOS" % prefix]
        word = " ".join(columns[column][i + index1: i + index2 + 1])
    else:
        word = sent[i + index1][column]
    if func is not None:
        result = apply_function(func, word)
    else:
        result = word
    return ["%s%s" % (prefix, result)]


cdef word2features(sent, int i, str* template):
    features = []
    for token_syntax in template:
        features.extend(template2features(sent, i, token_syntax))
    return features


class TaggedTransformer:
    def __init__(self, template=None):
        self.template = template

    def transform(self, sentences):
        X = [self.sentence2features(s) for s in sentences]
        y = [self.sentence2labels(s) for s in sentences]
        return X, y

    def sentence2features(self, s):
        return [word2features(s, i, self.template) for i in range(len(s))]

    def sentence2labels(self, s):
        return [row[-1] for row in s]