# AI Model Training & Integration Plan

## Model Format Recommendation

### ❌ **NOT Recommended: .pkl (Pickle)**
- Python-specific format
- Not directly usable in Flutter/Dart
- Would require Python runtime (not feasible in mobile app)

### ✅ **Recommended: TensorFlow Lite (.tflite)**
**Best Choice for Flutter:**
- ✅ Native Flutter support via `tflite_flutter` package
- ✅ Optimized for mobile (small file size, fast inference)
- ✅ Cross-platform (Android, iOS, Web)
- ✅ Offline capable
- ✅ Well-documented and maintained

**Alternative: JSON + Embeddings (Hybrid Approach)**
- ✅ Simpler implementation
- ✅ No ML framework needed
- ✅ Fast lookup
- ⚠️ Less "intelligent" but sufficient for basic NLP tasks

---

## Training Strategy

### Option 1: TensorFlow Lite Model (Recommended for Full AI)

**What to Train:**
1. **Word Embeddings Model**
   - Train Word2Vec or FastText on Bisaya dataset
   - Generate embeddings for all 300 words
   - Export as TensorFlow Lite model
   - Use for: similarity matching, quiz generation, vocabulary lookup

2. **Translation Model (Optional)**
   - Small seq2seq model for English↔Bisaya↔Tagalog
   - Can be trained on your 300-entry dataset
   - Export as .tflite

**Training Pipeline:**
```
CSV Dataset → Python Training Script → TensorFlow Model → .tflite → Flutter Assets
```

### Option 2: JSON + Embeddings (Simpler, Recommended for MVP)

**What to Create:**
1. **Word Embeddings (JSON)**
   - Train Word2Vec/FastText in Python
   - Export embeddings as JSON
   - Include metadata (translations, pronunciation, POS)
   - Much simpler to implement in Flutter

2. **Similarity Index**
   - Pre-compute similarity scores
   - Store in JSON for fast lookup

**File Structure:**
```json
{
  "embeddings": {
    "kumusta": [0.123, 0.456, ...],
    "salamat": [0.789, 0.012, ...]
  },
  "metadata": {
    "kumusta": {
      "bisaya": "Kumusta",
      "tagalog": "Kumusta",
      "english": "Hello/How are you",
      "pronunciation": "koo-MOOS-tah",
      "pos": "Greeting"
    }
  },
  "similarity_matrix": {...}
}
```

---

## Implementation Plan

### Phase 1: Model Training (Python)

**Create:** `training/train_model.py`

**Tasks:**
1. Load CSV dataset
2. Train Word2Vec/FastText embeddings
3. Generate similarity matrix
4. Export to format:
   - **Option A:** TensorFlow Lite (.tflite)
   - **Option B:** JSON with embeddings (recommended for MVP)

**Dependencies:**
```python
# training/requirements.txt
pandas==2.0.0
gensim==4.3.0  # For Word2Vec/FastText
tensorflow==2.13.0  # If using TFLite
numpy==1.24.0
scikit-learn==1.3.0  # For similarity calculations
```

### Phase 2: Flutter Integration

**Add Dependencies:**
```yaml
# For TensorFlow Lite (if using .tflite)
tflite_flutter: ^0.10.0

# OR for JSON approach (simpler)
# No additional packages needed - use dart:convert
```

**Create Services:**
1. `lib/services/nlp_model_service.dart` - Load and manage model
2. `lib/services/embedding_service.dart` - Handle embeddings and similarity
3. `lib/services/quiz_generator_service.dart` - Generate questions using model
4. `lib/services/vocabulary_service.dart` - Vocabulary lookup using model

### Phase 3: Feature Integration

**Update Screens:**
- `quiz_screen.dart` - Use model for question generation
- `voice_quiz_screen.dart` - Use model for pronunciation matching
- `word_vocabulary_screen.dart` - Use model for translations and similarity

---

## Model Capabilities

### What the Model Will Enable:

1. **Translation Lookup**
   - Fast bidirectional translation (English↔Bisaya↔Tagalog)
   - Offline, no API needed

2. **Similarity Matching**
   - Find similar words for quiz distractors
   - Suggest related vocabulary
   - Handle typos/misspellings

3. **Quiz Generation**
   - Generate random questions from dataset
   - Create plausible wrong answers using similarity
   - Filter by Part of Speech

4. **Voice Quiz Validation**
   - Match spoken words using embeddings
   - Handle pronunciation variations
   - Provide feedback based on similarity

5. **Vocabulary Search**
   - Semantic search (find words by meaning)
   - Similar word suggestions
   - Context-aware translations

---

## File Structure

```
vocaboost/
├── training/
│   ├── train_model.py          # Training script
│   ├── requirements.txt         # Python dependencies
│   ├── vocdataset/
│   │   └── bisaya_dataset.csv  # Input dataset
│   └── models/
│       ├── bisaya_model.tflite # OR bisaya_model.json
│       └── embeddings.json     # Word embeddings
├── assets/
│   └── models/
│       └── bisaya_model.tflite # OR bisaya_model.json
└── lib/
    └── services/
        ├── nlp_model_service.dart
        ├── embedding_service.dart
        ├── quiz_generator_service.dart
        └── vocabulary_service.dart
```

---

## Recommendation

**For MVP/Quick Implementation: JSON + Embeddings**
- ✅ Faster to implement
- ✅ Easier to debug
- ✅ Sufficient for your use case
- ✅ No ML framework overhead
- ✅ Smaller file size

**For Advanced Features: TensorFlow Lite**
- ✅ More "AI-like" capabilities
- ✅ Can add neural translation
- ✅ Better for future expansion
- ⚠️ More complex implementation
- ⚠️ Larger file size

**My Recommendation: Start with JSON + Embeddings, upgrade to TFLite later if needed.**

