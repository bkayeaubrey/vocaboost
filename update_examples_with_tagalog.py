#!/usr/bin/env python3
"""
Helper script to update all examples in regenerate_dataset.py to include Tagalog translations.
This updates the remaining examples that don't have Tagalog yet.
"""

import re

# Read the file
with open('regenerate_dataset.py', 'r', encoding='utf-8') as f:
    content = f.read()

# Common Tagalog translations for verbs
verb_translations = {
    'eat': 'kumain',
    'sleep': 'matulog',
    'read': 'magbasa',
    'write': 'sumulat',
    'buy': 'bumili',
    'walk': 'maglakad',
    'run': 'tumakbo',
    'go': 'pumunta',
}

# Update verb examples
verb_patterns = [
    (r"beginner = 'Gusto ko mokaon\. -> \"I want to eat\.\"'", 
     "beginner = make_example('Gusto ko mokaon.', 'I want to eat.', 'Gusto kong kumain.')"),
    (r"intermediate = 'Nakaon na ba ka\? -> \"Have you eaten already\?\"'",
     "intermediate = make_example('Nakaon na ba ka?', 'Have you eaten already?', 'Kumain ka na ba?')"),
    (r"advanced = 'Gikaon nako ang tinapay ganina\. -> \"I ate the bread earlier\.\"'",
     "advanced = make_example('Gikaon nako ang tinapay ganina.', 'I ate the bread earlier.', 'Kumain ako ng tinapay kanina.')"),
    
    (r"beginner = 'Gusto ko matulog\. -> \"I want to sleep\.\"'",
     "beginner = make_example('Gusto ko matulog.', 'I want to sleep.', 'Gusto kong matulog.')"),
    (r"intermediate = 'Natulog na ba ka\? -> \"Have you slept already\?\"'",
     "intermediate = make_example('Natulog na ba ka?', 'Have you slept already?', 'Natulog ka na ba?')"),
    (r"advanced = 'Kinahanglan nga matulog ka aron makapahuway\. -> \"You need to sleep to rest\.\"'",
     "advanced = make_example('Kinahanglan nga matulog ka aron makapahuway.', 'You need to sleep to rest.', 'Kailangan mong matulog para makapahinga.')"),
    
    (r"beginner = 'Gusto ko mobasa\. -> \"I want to read\.\"'",
     "beginner = make_example('Gusto ko mobasa.', 'I want to read.', 'Gusto kong magbasa.')"),
    (r"intermediate = 'Nagbasa ko ug libro\. -> \"I am reading a book\.\"'",
     "intermediate = make_example('Nagbasa ko ug libro.', 'I am reading a book.', 'Nagbabasa ako ng libro.')"),
    (r"advanced = 'Gibasa nako ang libro ganina\. -> \"I read the book earlier\.\"'",
     "advanced = make_example('Gibasa nako ang libro ganina.', 'I read the book earlier.', 'Binasa ko ang libro kanina.')"),
    
    (r"beginner = 'Gusto ko mosulat\. -> \"I want to write\.\"'",
     "beginner = make_example('Gusto ko mosulat.', 'I want to write.', 'Gusto kong sumulat.')"),
    (r"intermediate = 'Nagsulat ko ug sulat\. -> \"I am writing a letter\.\"'",
     "intermediate = make_example('Nagsulat ko ug sulat.', 'I am writing a letter.', 'Nagsusulat ako ng sulat.')"),
    (r"advanced = 'Gisulat nako ang sulat kagahapon\. -> \"I wrote the letter yesterday\.\"'",
     "advanced = make_example('Gisulat nako ang sulat kagahapon.', 'I wrote the letter yesterday.', 'Sinulat ko ang sulat kahapon.')"),
    
    (r"beginner = 'Gusto ko mopalit\. -> \"I want to buy\.\"'",
     "beginner = make_example('Gusto ko mopalit.', 'I want to buy.', 'Gusto kong bumili.')"),
    (r"intermediate = 'Mopalit ko ug tinapay\. -> \"I will buy bread\.\"'",
     "intermediate = make_example('Mopalit ko ug tinapay.', 'I will buy bread.', 'Bibili ako ng tinapay.')"),
    (r"advanced = 'Gipalit nako ang tinapay sa tindahan\. -> \"I bought the bread at the store\.\"'",
     "advanced = make_example('Gipalit nako ang tinapay sa tindahan.', 'I bought the bread at the store.', 'Binili ko ang tinapay sa tindahan.')"),
    
    (r"beginner = 'Gusto ko molakaw\. -> \"I want to walk\.\"'",
     "beginner = make_example('Gusto ko molakaw.', 'I want to walk.', 'Gusto kong maglakad.')"),
    (r"intermediate = 'Naglakaw ko sa dalan\. -> \"I am walking on the road\.\"'",
     "intermediate = make_example('Naglakaw ko sa dalan.', 'I am walking on the road.', 'Naglalakad ako sa kalsada.')"),
    (r"advanced = 'Naglakaw ko gikan sa balay padulong sa eskwelahan\. -> \"I walked from home to school\.\"'",
     "advanced = make_example('Naglakaw ko gikan sa balay padulong sa eskwelahan.', 'I walked from home to school.', 'Naglalakad ako mula sa bahay papunta sa paaralan.')"),
    
    (r"beginner = 'Gusto ko modagan\. -> \"I want to run\.\"'",
     "beginner = make_example('Gusto ko modagan.', 'I want to run.', 'Gusto kong tumakbo.')"),
    (r"intermediate = 'Nagdagan ko sa parke\. -> \"I am running in the park\.\"'",
     "intermediate = make_example('Nagdagan ko sa parke.', 'I am running in the park.', 'Tumatakbo ako sa parke.')"),
    (r"advanced = 'Nagdagan ko aron makab-ot ang bus\. -> \"I ran to catch the bus\.\"'",
     "advanced = make_example('Nagdagan ko aron makab-ot ang bus.', 'I ran to catch the bus.', 'Tumakbo ako para mahabol ang bus.')"),
    
    (r"beginner = 'Moadto ko\. -> \"I will go\.\"'",
     "beginner = make_example('Moadto ko.', 'I will go.', 'Pupunta ako.')"),
    (r"intermediate = 'Moadto ko sa balay\. -> \"I will go to the house\.\"'",
     "intermediate = make_example('Moadto ko sa balay.', 'I will go to the house.', 'Pupunta ako sa bahay.')"),
    (r"advanced = 'Moadto ko sa balay sa akong higala\. -> \"I will go to my friend\'s house\.\"'",
     "advanced = make_example('Moadto ko sa balay sa akong higala.', 'I will go to my friend\'s house.', 'Pupunta ako sa bahay ng aking kaibigan.')"),
]

for pattern, replacement in verb_patterns:
    content = re.sub(pattern, replacement, content)

# Write back
with open('regenerate_dataset.py', 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Updated verb examples with Tagalog")

