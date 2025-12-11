#!/usr/bin/env python3
"""
Script to regenerate bisaya_dataset.csv with beginner, intermediate, and advanced sentence examples.
Reads from bisaya_metadata.json and generates appropriate examples for each word.
"""

import json
import csv
import os
import re
from typing import Dict, List, Tuple

def load_metadata(json_path: str) -> List[Dict]:
    """Load word metadata from JSON file."""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    return data.get('metadata', [])

def get_base_form(word: str) -> str:
    """Get base form of verb by removing common prefixes."""
    prefixes = ['mo', 'nag', 'gi', 'mag', 'na', 'ka', 'maka', 'maka-']
    word_lower = word.lower()
    for prefix in prefixes:
        if word_lower.startswith(prefix):
            return word_lower[len(prefix):]
    return word_lower

def generate_examples(bisaya: str, tagalog: str, english: str, pos: str, category: str = '') -> Tuple[Tuple[str, str, str], Tuple[str, str, str], Tuple[str, str, str]]:
    """
    Generate beginner, intermediate, and advanced sentence examples with Tagalog translations.
    Returns tuple: ((beginner_bisaya, beginner_english, beginner_tagalog), 
                    (intermediate_bisaya, intermediate_english, intermediate_tagalog),
                    (advanced_bisaya, advanced_english, advanced_tagalog))
    """
    bisaya_lower = bisaya.lower()
    english_lower = english.lower()
    pos_lower = pos.lower()
    tagalog_lower = tagalog.lower() if tagalog else ''
    
    # Handle multi-word phrases
    is_phrase = ' ' in bisaya
    
    # Helper function to create example with translations - returns tuple
    def make_example(bisaya_sent: str, english_sent: str, tagalog_sent: str) -> Tuple[str, str, str]:
        """Create example with separate translations.
        Returns: (bisaya_sentence, english_translation, tagalog_translation)
        """
        return (bisaya_sent, english_sent, tagalog_sent if tagalog_sent else '')
    
    # Greetings and Expressions
    if pos_lower in ['greeting', 'expression', 'response']:
        if 'kumusta' in bisaya_lower:
            beginner = make_example('Kumusta ka?', 'How are you?', 'Kumusta ka?')
            intermediate = make_example('Kumusta na ka karon?', 'How are you now?', 'Kumusta ka na ngayon?')
            advanced = make_example('Kumusta na ka? Maayo ra ba?', 'How are you? Are you doing well?', 'Kumusta ka na? Mabuti ba?')
        elif 'maayong' in bisaya_lower:
            eng_clean = english.split('/')[0].strip()
            tag_clean = tagalog if tagalog else ''
            beginner = make_example(f'{bisaya}.', f'{eng_clean}.', f'{tag_clean}.' if tag_clean else '')
            intermediate = make_example(
                f'Maayong {bisaya.split()[-1] if len(bisaya.split()) > 1 else ""} sa tanan!',
                f'Good {eng_clean.split()[-1] if len(eng_clean.split()) > 1 else ""} to everyone!',
                f'{tag_clean} sa lahat!' if tag_clean else ''
            )
            advanced = make_example(
                f'Maayong {bisaya.split()[-1] if len(bisaya.split()) > 1 else ""}! Kumusta ang imong adlaw?',
                f'Good {eng_clean.split()[-1] if len(eng_clean.split()) > 1 else ""}! How is your day?',
                f'{tag_clean}! Kumusta ang iyong araw?' if tag_clean else ''
            )
        elif 'salamat' in bisaya_lower:
            beginner = make_example('Salamat.', 'Thank you.', 'Salamat.')
            intermediate = make_example('Daghang salamat sa imong tabang.', 'Thank you very much for your help.', 'Maraming salamat sa iyong tulong.')
            advanced = make_example('Daghang salamat kaayo sa tanan nga imong nahimo.', 'Thank you very much for everything you did.', 'Maraming salamat sa lahat ng iyong ginawa.')
        elif 'palihug' in bisaya_lower:
            beginner = make_example('Palihug.', 'Please.', 'Pakiusap.')
            intermediate = make_example('Palihug, tabangi ko.', 'Please, help me.', 'Pakiusap, tulungan mo ako.')
            advanced = make_example('Palihug, mahimo ba nimo ko tabangan karon?', 'Please, can you help me now?', 'Pakiusap, maaari mo ba akong tulungan ngayon?')
        elif 'pasaylo' in bisaya_lower:
            beginner = make_example('Pasaylo.', 'Sorry.', 'Paumanhin.')
            intermediate = make_example('Pasaylo sa akong nahimo.', 'Sorry for what I did.', 'Paumanhin sa aking ginawa.')
            advanced = make_example('Pasaylo kaayo sa tanan nga kasaypanan.', 'I am very sorry for all the mistakes.', 'Paumanhin sa lahat ng pagkakamali.')
        elif bisaya_lower in ['oo', 'yes']:
            beginner = make_example('Oo.', 'Yes.', 'Oo.')
            intermediate = make_example('Oo, gusto ko.', 'Yes, I want to.', 'Oo, gusto ko.')
            advanced = make_example('Oo, sigurado ko nga gusto ko.', 'Yes, I am sure I want to.', 'Oo, sigurado ako na gusto ko.')
        elif bisaya_lower in ['dili', 'no']:
            beginner = make_example('Dili.', 'No.', 'Hindi.')
            intermediate = make_example('Dili ko gusto.', 'I don\'t want to.', 'Ayaw ko.')
            advanced = make_example('Dili ko gusto nga moadto didto.', 'I don\'t want to go there.', 'Ayaw kong pumunta doon.')
        else:
            eng_clean = english.split('/')[0].split('(')[0].strip()
            tag_clean = tagalog if tagalog else ''
            beginner = make_example(f'{bisaya}.', f'{eng_clean}.', f'{tag_clean}.' if tag_clean else '')
            intermediate = make_example(f'{bisaya}, mahimo ba?', f'{eng_clean}, is it possible?', f'{tag_clean}, posible ba?' if tag_clean else '')
            advanced = make_example(f'{bisaya}, mahimo ba nimo ko tabangan?', f'{eng_clean}, can you help me?', f'{tag_clean}, maaari mo ba akong tulungan?' if tag_clean else '')
    
    # Verbs
    elif 'verb' in pos_lower or any(v in bisaya_lower for v in ['mokaon', 'matulog', 'mobasa', 'mosulat', 'mopalit']):
        base = get_base_form(bisaya)
        if 'kaon' in bisaya_lower or 'eat' in english_lower:
            beginner = make_example('Gusto ko mokaon.', 'I want to eat.', 'Gusto kong kumain.')
            intermediate = make_example('Nakaon na ba ka?', 'Have you eaten already?', 'Kumain ka na ba?')
            advanced = make_example('Gikaon nako ang tinapay ganina.', 'I ate the bread earlier.', 'Kumain ako ng tinapay kanina.')
        elif 'tulog' in bisaya_lower or 'sleep' in english_lower:
            beginner = make_example('Gusto ko matulog.', 'I want to sleep.', 'Gusto kong matulog.')
            intermediate = make_example('Natulog na ba ka?', 'Have you slept already?', 'Natulog ka na ba?')
            advanced = make_example('Kinahanglan nga matulog ka aron makapahuway.', 'You need to sleep to rest.', 'Kailangan mong matulog para makapahinga.')
        elif 'basa' in bisaya_lower or 'read' in english_lower:
            beginner = make_example('Gusto ko mobasa.', 'I want to read.', 'Gusto kong magbasa.')
            intermediate = make_example('Nagbasa ko ug libro.', 'I am reading a book.', 'Nagbabasa ako ng libro.')
            advanced = make_example('Gibasa nako ang libro ganina.', 'I read the book earlier.', 'Binasa ko ang libro kanina.')
        elif 'sulat' in bisaya_lower or 'write' in english_lower:
            beginner = make_example('Gusto ko mosulat.', 'I want to write.', 'Gusto kong sumulat.')
            intermediate = make_example('Nagsulat ko ug sulat.', 'I am writing a letter.', 'Nagsusulat ako ng sulat.')
            advanced = make_example('Gisulat nako ang sulat kagahapon.', 'I wrote the letter yesterday.', 'Sinulat ko ang sulat kahapon.')
        elif 'palit' in bisaya_lower or 'buy' in english_lower:
            beginner = make_example('Gusto ko mopalit.', 'I want to buy.', 'Gusto kong bumili.')
            intermediate = make_example('Mopalit ko ug tinapay.', 'I will buy bread.', 'Bibili ako ng tinapay.')
            advanced = make_example('Gipalit nako ang tinapay sa tindahan.', 'I bought the bread at the store.', 'Binili ko ang tinapay sa tindahan.')
        elif 'lakaw' in bisaya_lower or 'walk' in english_lower:
            beginner = make_example('Gusto ko molakaw.', 'I want to walk.', 'Gusto kong maglakad.')
            intermediate = make_example('Naglakaw ko sa dalan.', 'I am walking on the road.', 'Naglalakad ako sa kalsada.')
            advanced = make_example('Naglakaw ko gikan sa balay padulong sa eskwelahan.', 'I walked from home to school.', 'Naglalakad ako mula sa bahay papunta sa paaralan.')
        elif 'dagan' in bisaya_lower or 'run' in english_lower:
            beginner = make_example('Gusto ko modagan.', 'I want to run.', 'Gusto kong tumakbo.')
            intermediate = make_example('Nagdagan ko sa parke.', 'I am running in the park.', 'Tumatakbo ako sa parke.')
            advanced = make_example('Nagdagan ko aron makab-ot ang bus.', 'I ran to catch the bus.', 'Tumakbo ako para mahabol ang bus.')
        elif 'adto' in bisaya_lower or 'go' in english_lower:
            beginner = make_example('Moadto ko.', 'I will go.', 'Pupunta ako.')
            intermediate = make_example('Moadto ko sa balay.', 'I will go to the house.', 'Pupunta ako sa bahay.')
            advanced = make_example('Moadto ko sa balay sa akong higala.', 'I will go to my friend\'s house.', 'Pupunta ako sa bahay ng aking kaibigan.')
        else:
            # Generic verb patterns
            base_verb = base if base != bisaya_lower else bisaya_lower.replace('mo', '').replace('mag', '').replace('nag', '').replace('gi', '')
            english_verb = english.split('/')[0].split('(')[0].strip().lower()
            # Get past tense - simple approach (not perfect but better than adding -ed to everything)
            past_tense = english_verb
            if english_verb.endswith('e'):
                past_tense = english_verb + 'd'
            elif english_verb.endswith('y'):
                past_tense = english_verb[:-1] + 'ied'
            elif len(english_verb) > 1 and english_verb[-1] not in 'aeiou' and english_verb[-2] in 'aeiou':
                past_tense = english_verb + english_verb[-1] + 'ed'
            else:
                past_tense = english_verb + 'ed'
            
            # Try to get Tagalog verb form (simplified - use base tagalog word if available)
            tag_verb = tagalog.lower() if tagalog else ''
            beginner = make_example(f'Gusto ko mo{base_verb}.', f'I want to {english_verb}.', f'Gusto kong {tag_verb}.' if tag_verb else '')
            intermediate = make_example(f'Mo{base_verb} ko karon.', f'I will {english_verb} now.', f'{tag_verb.capitalize()} ako ngayon.' if tag_verb else '')
            advanced = make_example(f'Gi{base_verb} nako ang tanan ganina.', f'I {past_tense} everything earlier.', f'{tag_verb.capitalize()} ko ang lahat kanina.' if tag_verb else '')
    
    # Nouns
    elif 'noun' in pos_lower:
        if 'tubig' in bisaya_lower or 'water' in english_lower:
            beginner = make_example('Gusto ko ug tubig.', 'I want water.', 'Gusto ko ng tubig.')
            intermediate = make_example('Naa koy tubig sa balay.', 'I have water at home.', 'May tubig ako sa bahay.')
            advanced = make_example('Gipalit nako ang tubig sa tindahan.', 'I bought the water at the store.', 'Binili ko ang tubig sa tindahan.')
        elif 'pagkaon' in bisaya_lower or 'food' in english_lower:
            beginner = make_example('Gusto ko ug pagkaon.', 'I want food.', 'Gusto ko ng pagkain.')
            intermediate = make_example('Naa koy pagkaon sa lamesa.', 'I have food on the table.', 'May pagkain ako sa mesa.')
            advanced = make_example('Gipangandam nako ang pagkaon para sa tanan.', 'I prepared the food for everyone.', 'Inihanda ko ang pagkain para sa lahat.')
        elif 'balay' in bisaya_lower or 'house' in english_lower:
            beginner = make_example('Naa koy balay.', 'I have a house.', 'May bahay ako.')
            intermediate = make_example('Ang balay kay dako.', 'The house is big.', 'Malaki ang bahay.')
            advanced = make_example('Ang balay nga gipalit nako kay nindot kaayo.', 'The house I bought is very beautiful.', 'Ang bahay na binili ko ay napakaganda.')
        elif 'libro' in bisaya_lower or 'book' in english_lower:
            beginner = make_example('Naa koy libro.', 'I have a book.', 'May libro ako.')
            intermediate = make_example('Nagbasa ko ug libro.', 'I am reading a book.', 'Nagbabasa ako ng libro.')
            advanced = make_example('Ang libro nga gibasa nako kay nindot kaayo.', 'The book I read is very beautiful.', 'Ang libro na binasa ko ay napakaganda.')
        elif 'amahan' in bisaya_lower or 'father' in english_lower:
            beginner = make_example('Siya ang akong amahan.', 'He is my father.', 'Siya ang aking ama.')
            intermediate = make_example('Ang akong amahan kay maayo kaayo.', 'My father is very good.', 'Ang aking ama ay napakabuti.')
            advanced = make_example('Ang akong amahan nga nagtrabaho sa opisina kay kusgan kaayo.', 'My father who works at the office is very strong.', 'Ang aking ama na nagtatrabaho sa opisina ay napakalakas.')
        elif 'inahan' in bisaya_lower or 'mother' in english_lower:
            beginner = make_example('Siya ang akong inahan.', 'She is my mother.', 'Siya ang aking ina.')
            intermediate = make_example('Ang akong inahan kay gwapa kaayo.', 'My mother is very beautiful.', 'Ang aking ina ay napakaganda.')
            advanced = make_example('Ang akong inahan nga nagluto sa kusina kay maayo kaayo.', 'My mother who cooks in the kitchen is very good.', 'Ang aking ina na nagluluto sa kusina ay napakabuti.')
        else:
            # Generic noun patterns - handle special cases
            english_lower_check = english.lower()
            english_clean = english.split('/')[0].split('(')[0].strip().lower()
            if 'adlaw' in bisaya_lower or ('day' in english_lower_check and 'sun' in english_lower_check):
                beginner = make_example('Maayong adlaw.', 'Good day.', 'Magandang araw.')
                intermediate = make_example('Init kaayo ang adlaw karon.', 'The sun is very hot today.', 'Napakainit ng araw ngayon.')
                advanced = make_example('Ang adlaw nga nag-init sa balay kay init kaayo.', 'The sun that heats the house is very hot.', 'Ang araw na nagpapainit sa bahay ay napakainit.')
            elif 'bulan' in bisaya_lower or ('month' in english_lower_check and 'moon' in english_lower_check):
                beginner = make_example('Maayong bulan.', 'Good month.', 'Magandang buwan.')
                intermediate = make_example('Nindot kaayo ang bulan karon.', 'The moon is very beautiful tonight.', 'Napakaganda ng buwan ngayon.')
                advanced = make_example('Ang bulan nga nagdan-ag sa dalan kay nindot kaayo.', 'The moon that lights the road is very beautiful.', 'Ang buwan na nagliliwanag sa kalsada ay napakaganda.')
            else:
                tag_clean = tagalog.lower() if tagalog else ''
                beginner = make_example(f'Gusto ko ug {bisaya}.', f'I want {english_clean}.', f'Gusto ko ng {tag_clean}.' if tag_clean else '')
                intermediate = make_example(f'Naa koy {bisaya} sa balay.', f'I have {english_clean} at home.', f'May {tag_clean} ako sa bahay.' if tag_clean else '')
                advanced = make_example(f'Ang {bisaya} nga gipalit nako kay nindot kaayo.', f'The {english_clean} I bought is very beautiful.', f'Ang {tag_clean} na binili ko ay napakaganda.' if tag_clean else '')
    
    # Adjectives
    elif 'adjective' in pos_lower or 'adj' in pos_lower:
        if 'wala' in bisaya_lower or 'none' in english_lower or 'nothing' in english_lower:
            beginner = make_example('Wala ko.', 'I have nothing.', 'Wala ako.')
            intermediate = make_example('Wala koy kwarta.', 'I have no money.', 'Wala akong pera.')
            advanced = make_example('Wala koy kwarta nga magasto karon.', 'I have no money to spend now.', 'Wala akong pera na magagastos ngayon.')
        elif 'daghan' in bisaya_lower or 'many' in english_lower or 'much' in english_lower:
            beginner = make_example('Daghan kaayo.', 'A lot.', 'Marami.')
            intermediate = make_example('Daghan kaayo ang tawo.', 'There are many people.', 'Maraming tao.')
            advanced = make_example('Daghan kaayo ang tawo nga nakaon sa restaurant.', 'There are many people eating at the restaurant.', 'Maraming tao na kumakain sa restaurant.')
        elif 'maayo' in bisaya_lower or 'good' in english_lower:
            beginner = make_example('Maayo kaayo.', 'Very good.', 'Napakabuti.')
            intermediate = make_example('Ang pagkaon kay maayo kaayo.', 'The food is very good.', 'Napakasarap ng pagkain.')
            advanced = make_example('Ang pagkaon nga gipangandam nako kay maayo kaayo sa tanan.', 'The food I prepared is very good for everyone.', 'Ang pagkain na inihanda ko ay napakasarap para sa lahat.')
        elif 'gwapa' in bisaya_lower or ('beautiful' in english_lower and 'female' in english_lower):
            beginner = make_example('Gwapa kaayo.', 'Very beautiful.', 'Napakaganda.')
            intermediate = make_example('Ang babaye kay gwapa kaayo.', 'The woman is very beautiful.', 'Napakaganda ng babae.')
            advanced = make_example('Ang babaye nga naglakaw sa dalan kay gwapa kaayo.', 'The woman walking on the road is very beautiful.', 'Ang babae na naglalakad sa kalsada ay napakaganda.')
        elif 'gwapo' in bisaya_lower or 'handsome' in english_lower:
            beginner = make_example('Gwapo kaayo.', 'Very handsome.', 'Napakagwapo.')
            intermediate = make_example('Ang lalaki kay gwapo kaayo.', 'The man is very handsome.', 'Napakagwapo ng lalaki.')
            advanced = make_example('Ang lalaki nga naglakaw sa dalan kay gwapo kaayo.', 'The man walking on the road is very handsome.', 'Ang lalaki na naglalakad sa kalsada ay napakagwapo.')
        elif 'dako' in bisaya_lower or 'big' in english_lower:
            beginner = make_example('Dako kaayo.', 'Very big.', 'Napakalaki.')
            intermediate = make_example('Ang balay kay dako kaayo.', 'The house is very big.', 'Napakalaki ng bahay.')
            advanced = make_example('Ang balay nga gipalit nako kay dako kaayo ug nindot.', 'The house I bought is very big and beautiful.', 'Ang bahay na binili ko ay napakalaki at napakaganda.')
        elif 'gamay' in bisaya_lower or 'small' in english_lower:
            beginner = make_example('Gamay kaayo.', 'Very small.', 'Napakaliit.')
            intermediate = make_example('Ang bata kay gamay kaayo.', 'The child is very small.', 'Napakaliit ng bata.')
            advanced = make_example('Ang bata nga nagdula sa parke kay gamay kaayo.', 'The child playing in the park is very small.', 'Ang bata na naglalaro sa parke ay napakaliit.')
        elif 'init' in bisaya_lower or 'hot' in english_lower:
            beginner = make_example('Init kaayo.', 'Very hot.', 'Napakainit.')
            intermediate = make_example('Ang tubig kay init kaayo.', 'The water is very hot.', 'Napakainit ng tubig.')
            advanced = make_example('Ang tubig nga gipainit nako kay init kaayo karon.', 'The water I heated is very hot now.', 'Ang tubig na pinainit ko ay napakainit ngayon.')
        elif 'bugnaw' in bisaya_lower or 'cold' in english_lower:
            beginner = make_example('Bugnaw kaayo.', 'Very cold.', 'Napakalamig.')
            intermediate = make_example('Ang tubig kay bugnaw kaayo.', 'The water is very cold.', 'Napakalamig ng tubig.')
            advanced = make_example('Ang tubig nga gikan sa gripo kay bugnaw kaayo.', 'The water from the faucet is very cold.', 'Ang tubig na galing sa gripo ay napakalamig.')
        elif 'tibuok' in bisaya_lower or 'whole' in english_lower or 'complete' in english_lower:
            beginner = make_example('Tibuok ang libro.', 'The whole book.', 'Buong libro.')
            intermediate = make_example('Gibasa nako ang tibuok nga libro.', 'I read the whole book.', 'Binasa ko ang buong libro.')
            advanced = make_example('Gibasa nako ang tibuok nga libro sulod sa usa ka adlaw.', 'I read the whole book within one day.', 'Binasa ko ang buong libro sa loob ng isang araw.')
        elif 'bahin' in bisaya_lower or 'part' in english_lower:
            beginner = make_example('Bahin lang.', 'Just a part.', 'Bahagi lang.')
            intermediate = make_example('Gibasa nako ang bahin sa libro.', 'I read part of the book.', 'Binasa ko ang bahagi ng libro.')
            advanced = make_example('Gibasa nako ang bahin sa libro nga importante.', 'I read the important part of the book.', 'Binasa ko ang mahalagang bahagi ng libro.')
        elif 'bag-o' in bisaya_lower or 'new' in english_lower:
            beginner = make_example('Bag-o kaayo.', 'Very new.', 'Napakabago.')
            intermediate = make_example('Ang libro kay bag-o kaayo.', 'The book is very new.', 'Napakabago ng libro.')
            advanced = make_example('Ang libro nga gipalit nako kay bag-o kaayo ug nindot.', 'The book I bought is very new and beautiful.', 'Ang libro na binili ko ay napakabago at napakaganda.')
        elif 'karaan' in bisaya_lower or 'old' in english_lower:
            beginner = make_example('Karaan kaayo.', 'Very old.', 'Napakaluma.')
            intermediate = make_example('Ang libro kay karaan kaayo.', 'The book is very old.', 'Napakaluma ng libro.')
            advanced = make_example('Ang libro nga gikan sa library kay karaan kaayo.', 'The book from the library is very old.', 'Ang libro na galing sa library ay napakaluma.')
        elif 'taas' in bisaya_lower or 'tall' in english_lower or 'high' in english_lower:
            beginner = make_example('Taas kaayo.', 'Very tall.', 'Napakataas.')
            intermediate = make_example('Ang tawo kay taas kaayo.', 'The person is very tall.', 'Napakataas ng tao.')
            advanced = make_example('Ang tawo nga naglakaw sa dalan kay taas kaayo.', 'The person walking on the road is very tall.', 'Ang tao na naglalakad sa kalsada ay napakataas.')
        elif 'mubo' in bisaya_lower or 'short' in english_lower or 'low' in english_lower:
            beginner = make_example('Mubo kaayo.', 'Very short.', 'Napakababa.')
            intermediate = make_example('Ang tawo kay mubo kaayo.', 'The person is very short.', 'Napakababa ng tao.')
            advanced = make_example('Ang tawo nga naglakaw sa dalan kay mubo kaayo.', 'The person walking on the road is very short.', 'Ang tao na naglalakad sa kalsada ay napakababa.')
        elif 'lapad' in bisaya_lower or 'wide' in english_lower:
            beginner = make_example('Lapad kaayo.', 'Very wide.', 'Napakalapad.')
            intermediate = make_example('Ang dalan kay lapad kaayo.', 'The road is very wide.', 'Napakalapad ng kalsada.')
            advanced = make_example('Ang dalan nga gipangita nako kay lapad kaayo.', 'The road I am looking for is very wide.', 'Ang kalsada na hinahanap ko ay napakalapad.')
        else:
            # Generic adjective patterns - use appropriate context
            english_clean = english.split('/')[0].split('(')[0].strip().lower()
            tag_clean = tagalog.lower() if tagalog else ''
            beginner = make_example(f'{bisaya} kaayo.', f'Very {english_clean}.', f'Napaka{tag_clean}.' if tag_clean else '')
            intermediate = make_example(f'Ang balay kay {bisaya} kaayo.', f'The house is very {english_clean}.', f'Napaka{tag_clean} ng bahay.' if tag_clean else '')
            advanced = make_example(f'Ang balay nga gipalit nako kay {bisaya} kaayo.', f'The house I bought is very {english_clean}.', f'Ang bahay na binili ko ay napaka{tag_clean}.' if tag_clean else '')
    
    # Numbers
    elif 'number' in pos_lower or any(n in bisaya_lower for n in ['usa', 'duha', 'tulo', 'upat', 'lima']):
        if bisaya_lower == 'usa' or 'one' in english_lower:
            beginner = make_example('Naa koy usa ka libro.', 'I have one book.', 'May isang libro ako.')
            intermediate = make_example('Gusto ko ug usa ka libro.', 'I want one book.', 'Gusto ko ng isang libro.')
            advanced = make_example('Gipalit nako ang usa ka libro sa tindahan.', 'I bought one book at the store.', 'Binili ko ang isang libro sa tindahan.')
        elif bisaya_lower == 'duha' or 'two' in english_lower:
            beginner = make_example('Naa koy duha ka libro.', 'I have two books.', 'May dalawang libro ako.')
            intermediate = make_example('Gusto ko ug duha ka libro.', 'I want two books.', 'Gusto ko ng dalawang libro.')
            advanced = make_example('Gipalit nako ang duha ka libro sa tindahan.', 'I bought two books at the store.', 'Binili ko ang dalawang libro sa tindahan.')
        else:
            english_clean = english.split('/')[0].split('(')[0].strip().lower()
            tag_clean = tagalog.lower() if tagalog else ''
            beginner = make_example(f'Naa koy {bisaya} ka libro.', f'I have {english_clean} books.', f'May {tag_clean} libro ako.' if tag_clean else '')
            intermediate = make_example(f'Gusto ko ug {bisaya} ka libro.', f'I want {english_clean} books.', f'Gusto ko ng {tag_clean} libro.' if tag_clean else '')
            advanced = make_example(f'Gipalit nako ang {bisaya} ka libro sa tindahan.', f'I bought {english_clean} books at the store.', f'Binili ko ang {tag_clean} libro sa tindahan.' if tag_clean else '')
    
    # Time expressions
    elif 'time' in pos_lower or any(t in bisaya_lower for t in ['karon', 'ugma', 'gahapon', 'adlaw']):
        if 'karon' in bisaya_lower or 'now' in english_lower:
            beginner = make_example('Karon ko moadto.', 'I will go now.', 'Pupunta ako ngayon.')
            intermediate = make_example('Karon nga adlaw, moadto ko.', 'Today, I will go.', 'Ngayon, pupunta ako.')
            advanced = make_example('Karon nga adlaw, moadto ko sa balay sa akong higala.', 'Today, I will go to my friend\'s house.', 'Ngayon, pupunta ako sa bahay ng aking kaibigan.')
        elif 'ugma' in bisaya_lower or 'tomorrow' in english_lower:
            beginner = make_example('Ugma ko moadto.', 'I will go tomorrow.', 'Pupunta ako bukas.')
            intermediate = make_example('Ugma, moadto ko sa balay.', 'Tomorrow, I will go to the house.', 'Bukas, pupunta ako sa bahay.')
            advanced = make_example('Ugma, moadto ko sa balay sa akong higala aron magdula.', 'Tomorrow, I will go to my friend\'s house to play.', 'Bukas, pupunta ako sa bahay ng aking kaibigan para maglaro.')
        elif 'gahapon' in bisaya_lower or 'yesterday' in english_lower:
            beginner = make_example('Gahapon ko moadto.', 'I went yesterday.', 'Pumunta ako kahapon.')
            intermediate = make_example('Gahapon, nakaon ko sa balay.', 'Yesterday, I ate at home.', 'Kahapon, kumain ako sa bahay.')
            advanced = make_example('Gahapon, nakaon ko sa balay sa akong higala ug nagdula mi.', 'Yesterday, I ate at my friend\'s house and we played.', 'Kahapon, kumain ako sa bahay ng aking kaibigan at naglaro kami.')
        else:
            english_clean = english.split('/')[0].split('(')[0].strip().lower()
            tag_clean = tagalog.lower() if tagalog else ''
            beginner = make_example(f'{bisaya} ko moadto.', f'I will go {english_clean}.', f'Pupunta ako {tag_clean}.' if tag_clean else '')
            intermediate = make_example(f'{bisaya}, moadto ko sa balay.', f'{english_clean.capitalize()}, I will go to the house.', f'{tag_clean.capitalize()}, pupunta ako sa bahay.' if tag_clean else '')
            advanced = make_example(f'{bisaya}, moadto ko sa balay sa akong higala.', f'{english_clean.capitalize()}, I will go to my friend\'s house.', f'{tag_clean.capitalize()}, pupunta ako sa bahay ng aking kaibigan.' if tag_clean else '')
    
    # Questions
    elif 'question' in pos_lower or any(q in bisaya_lower for q in ['asa', 'unsa', 'kamus-a', 'ngano']):
        if 'asa' in bisaya_lower or 'where' in english_lower:
            beginner = make_example('Asa ka?', 'Where are you?', 'Nasaan ka?')
            intermediate = make_example('Asa ka moadto?', 'Where are you going?', 'Saan ka pupunta?')
            advanced = make_example('Asa ka moadto karon nga adlaw?', 'Where are you going today?', 'Saan ka pupunta ngayon?')
        elif 'unsa' in bisaya_lower or 'what' in english_lower:
            beginner = make_example('Unsa ni?', 'What is this?', 'Ano ito?')
            intermediate = make_example('Unsa ang imong gusto?', 'What do you want?', 'Ano ang gusto mo?')
            advanced = make_example('Unsa ang imong gusto nga mokaon karon?', 'What do you want to eat now?', 'Ano ang gusto mong kainin ngayon?')
        elif 'kanus-a' in bisaya_lower or 'when' in english_lower:
            beginner = make_example('Kanus-a ka moadto?', 'When will you go?', 'Kailan ka pupunta?')
            intermediate = make_example('Kanus-a ka moadto sa balay?', 'When will you go to the house?', 'Kailan ka pupunta sa bahay?')
            advanced = make_example('Kanus-a ka moadto sa balay sa akong higala?', 'When will you go to my friend\'s house?', 'Kailan ka pupunta sa bahay ng aking kaibigan?')
        elif 'ngano' in bisaya_lower or 'why' in english_lower:
            beginner = make_example('Ngano ka moadto?', 'Why are you going?', 'Bakit ka pupunta?')
            intermediate = make_example('Ngano ka moadto sa balay?', 'Why are you going to the house?', 'Bakit ka pupunta sa bahay?')
            advanced = make_example('Ngano ka moadto sa balay sa akong higala karon?', 'Why are you going to my friend\'s house now?', 'Bakit ka pupunta sa bahay ng aking kaibigan ngayon?')
        else:
            english_clean = english.split('/')[0].split('(')[0].strip()
            tag_clean = tagalog if tagalog else ''
            beginner = make_example(f'{bisaya}?', f'{english_clean}?', f'{tag_clean}?' if tag_clean else '')
            intermediate = make_example(f'{bisaya} ka moadto?', f'{english_clean} are you going?', f'{tag_clean} ka pupunta?' if tag_clean else '')
            advanced = make_example(f'{bisaya} ka moadto sa balay?', f'{english_clean} are you going to the house?', f'{tag_clean} ka pupunta sa bahay?' if tag_clean else '')
    
    # Default/Generic patterns
    else:
        english_clean = english.split('/')[0].split('(')[0].strip()
        tag_clean = tagalog if tagalog else ''
        if is_phrase:
            beginner = make_example(f'{bisaya}.', f'{english_clean}.', f'{tag_clean}.' if tag_clean else '')
            intermediate = make_example(f'{bisaya}, mahimo ba?', f'{english_clean}, is it possible?', f'{tag_clean}, posible ba?' if tag_clean else '')
            advanced = make_example(f'{bisaya}, mahimo ba nimo ko tabangan?', f'{english_clean}, can you help me?', f'{tag_clean}, maaari mo ba akong tulungan?' if tag_clean else '')
        else:
            beginner = make_example(f'{bisaya} na.', f'{english_clean} now.', f'{tag_clean} ngayon.' if tag_clean else '')
            intermediate = make_example(f'Gusto ko ug {bisaya}.', f'I want {english_clean.lower()}.', f'Gusto ko ng {tag_clean.lower()}.' if tag_clean else '')
            advanced = make_example(f'Gipalit nako ang {bisaya} sa tindahan.', f'I bought the {english_clean.lower()} at the store.', f'Binili ko ang {tag_clean.lower()} sa tindahan.' if tag_clean else '')
    
    return beginner, intermediate, advanced

def determine_category(pos: str, english: str) -> str:
    """Determine category based on part of speech and meaning."""
    pos_lower = pos.lower()
    english_lower = english.lower()
    
    if 'greeting' in pos_lower:
        return 'Greetings'
    elif 'expression' in pos_lower or 'response' in pos_lower:
        return 'Common Phrases'
    elif 'number' in pos_lower:
        return 'Numbers'
    elif 'verb' in pos_lower:
        if any(f in english_lower for f in ['eat', 'drink', 'cook', 'food']):
            return 'Food & Dining'
        elif any(f in english_lower for f in ['buy', 'sell', 'market', 'shop']):
            return 'Market/Shopping'
        else:
            return 'Actions'
    elif 'noun' in pos_lower:
        if any(f in english_lower for f in ['father', 'mother', 'family', 'brother', 'sister']):
            return 'Family'
        elif any(f in english_lower for f in ['food', 'water', 'rice', 'bread', 'fruit']):
            return 'Food & Dining'
        elif any(f in english_lower for f in ['house', 'room', 'door', 'window']):
            return 'Home & Living'
        elif any(f in english_lower for f in ['book', 'school', 'student', 'teacher']):
            return 'Education'
        else:
            return 'Common Nouns'
    elif 'adjective' in pos_lower:
        return 'Descriptions'
    elif 'time' in pos_lower or any(t in english_lower for t in ['now', 'today', 'tomorrow', 'yesterday', 'day', 'month', 'year']):
        return 'Time'
    elif 'question' in pos_lower:
        return 'Questions'
    else:
        return 'Uncategorized'

def main():
    # Paths
    metadata_path = 'assets/models/bisaya_metadata.json'
    output_path = 'lib/vocdataset/bisaya_dataset.csv'
    import time
    temp_path = f'lib/vocdataset/bisaya_dataset_{int(time.time())}.csv'
    
    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    print(f'📖 Loading metadata from {metadata_path}...')
    metadata = load_metadata(metadata_path)
    print(f'✅ Loaded {len(metadata)} words')
    
    # Prepare CSV data
    csv_data = []
    csv_data.append([
        'Bisaya',
        'Tagalog',
        'English',
        'Part of Speech',
        'Pronunciation',
        'Category',
        'Beginner Example (Bisaya)',
        'Beginner English Translation',
        'Beginner Tagalog Translation',
        'Intermediate Example (Bisaya)',
        'Intermediate English Translation',
        'Intermediate Tagalog Translation',
        'Advanced Example (Bisaya)',
        'Advanced English Translation',
        'Advanced Tagalog Translation'
    ])
    
    print('📝 Generating examples for each word...')
    for i, word_data in enumerate(metadata):
        bisaya = word_data.get('bisaya', '')
        tagalog = word_data.get('tagalog', '')
        english = word_data.get('english', '')
        pronunciation = word_data.get('pronunciation', '')
        pos = word_data.get('pos', 'Unknown')
        
        if not bisaya or not english:
            continue
        
        # Determine category
        category = determine_category(pos, english)
        
        # Generate examples
        try:
            beginner_tuple, intermediate_tuple, advanced_tuple = generate_examples(bisaya, tagalog, english, pos, category)
        except Exception as e:
            print(f'⚠️ Error generating examples for {bisaya}: {e}')
            eng_clean = english.split('/')[0].split('(')[0].strip()
            tag_clean = tagalog if tagalog else ''
            beginner_tuple = make_example(f'{bisaya}.', f'{eng_clean}.', f'{tag_clean}.' if tag_clean else '')
            intermediate_tuple = make_example(f'{bisaya}, mahimo ba?', f'{eng_clean}, is it possible?', f'{tag_clean}, posible ba?' if tag_clean else '')
            advanced_tuple = make_example(f'{bisaya}, mahimo ba nimo ko tabangan?', f'{eng_clean}, can you help me?', f'{tag_clean}, maaari mo ba akong tulungan?' if tag_clean else '')
        
        # Unpack tuples
        beginner_bisaya, beginner_english, beginner_tagalog = beginner_tuple
        intermediate_bisaya, intermediate_english, intermediate_tagalog = intermediate_tuple
        advanced_bisaya, advanced_english, advanced_tagalog = advanced_tuple
        
        csv_data.append([
            bisaya,
            tagalog,
            english,
            pos,
            pronunciation,
            category,
            beginner_bisaya,
            beginner_english,
            beginner_tagalog,
            intermediate_bisaya,
            intermediate_english,
            intermediate_tagalog,
            advanced_bisaya,
            advanced_english,
            advanced_tagalog
        ])
        
        if (i + 1) % 50 == 0:
            print(f'  Processed {i + 1}/{len(metadata)} words...')
    
    # Write CSV file to temp location first
    print(f'💾 Writing CSV to {temp_path}...')
    with open(temp_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerows(csv_data)
    
    # Try to replace the original file
    import shutil
    try:
        if os.path.exists(output_path):
            # Backup original
            backup_path = output_path + '.backup'
            if os.path.exists(backup_path):
                os.remove(backup_path)
            shutil.copy2(output_path, backup_path)
            print(f'📦 Created backup: {backup_path}')
        
        # Replace with new file
        shutil.move(temp_path, output_path)
        print(f'✅ Successfully generated {output_path} with {len(csv_data) - 1} entries!')
    except PermissionError:
        print(f'⚠️  Could not replace {output_path} (file may be open in another program)')
        print(f'✅ New file saved as: {temp_path}')
        print(f'   Please close {output_path} and manually replace it with {temp_path}')
    
    print(f'📊 Columns: Bisaya, Tagalog, English, Part of Speech, Pronunciation, Category,')
    print(f'           Beginner Example (Bisaya), Beginner English, Beginner Tagalog,')
    print(f'           Intermediate Example (Bisaya), Intermediate English, Intermediate Tagalog,')
    print(f'           Advanced Example (Bisaya), Advanced English, Advanced Tagalog')

if __name__ == '__main__':
    main()

