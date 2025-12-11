# AI Model Integration Guide

## Overview

This guide explains how to train and integrate an AI model for offline NLP capabilities in the VocaBoost app.

## Model Format: TensorFlow Lite (.tflite)

**Why TensorFlow Lite?**
- ✅ **Native Flutter Support**: `tflite_flutter` package
- ✅ **Optimized for Mobile**: Small file size, fast inference
- ✅ **Cross-platform**: Works on Android, iOS, Web
- ✅ **Future-proof**: Easy to expand with more advanced models
- ✅ **Production-ready**: Industry standard for mobile ML

**Model Components:**
- **bisaya_model.tflite**: TensorFlow Lite model with embeddings
- **bisaya_metadata.json**: Vocabulary, translations, pronunciation
- **bisaya_similarity.json**: Pre-computed similarity matrix

---

## Training Process

You have two options for training:

### Option A: Train in Google Colab (Recommended) ⭐

**Why Colab?**
- ✅ Free GPU access
- ✅ No local setup needed
- ✅ Pre-installed libraries
- ✅ Easy file upload/download

**Quick Start:**
1. Upload `bisaya_dataset.csv` to Google Drive folder named `AAA`
2. Open [Google Colab](https://colab.research.google.com/)
3. Install dependencies: `!pip install pandas gensim scikit-learn tensorflow`
4. Copy and run `training/train_tflite_colab.py`
5. Run `main('AAA')` - it will read from and save to your Drive folder
6. Download the 3 model files from Google Drive `AAA` folder
7. Copy files to `assets/models/` in your Flutter project

📖 **See detailed instructions**: `training/COLAB_TRAINING_GUIDE.md`

### Option B: Train Locally

**Step 1: Setup Python Environment**

```bash
cd training
pip install -r requirements.txt
```

**Step 2: Train the TensorFlow Lite Model**

```bash
python train_tflite_model.py
```

This will:
1. Load `vocdataset/bisaya_dataset.csv`
2. Train Word2Vec embeddings
3. Create TensorFlow model with embedding layer
4. Convert to TensorFlow Lite (.tflite)
5. Export metadata and similarity matrix

**Step 3: Copy to Flutter Assets**

```bash
# Copy all model files to Flutter assets
cp training/models/bisaya_model.tflite assets/models/
cp training/models/bisaya_metadata.json assets/models/
cp training/models/bisaya_similarity.json assets/models/
```

---

## Flutter Integration

### Step 1: Initialize Model in App

Update `lib/main.dart`:

```dart
import 'package:vocaboost/services/nlp_model_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load NLP model for offline features
  try {
    await NLPModelService.instance.loadModel();
  } catch (e) {
    debugPrint('Warning: Could not load NLP model: $e');
  }
  
  // ... rest of main()
}
```

### Step 2: Use in Features

**Quiz Generation:**
```dart
final nlpService = NLPModelService.instance;
final randomWords = nlpService.getRandomWords(count: 10);
// Generate questions from randomWords
```

**Vocabulary Lookup:**
```dart
final translation = nlpService.getTranslation('water', 'English', 'Bisaya');
// Returns: "Tubig"
```

**Voice Quiz Matching:**
```dart
final match = nlpService.matchPronunciation(spokenText);
if (match != null && match['similarity'] > 0.7) {
  // Correct pronunciation
}
```

**Similar Words (for quiz distractors):**
```dart
final similar = nlpService.getSimilarWords('kumusta', count: 3);
// Returns similar words for wrong answer options
```

---

## Model Structure

The trained model consists of three files:

### 1. bisaya_model.tflite
TensorFlow Lite model containing:
- Embedding layer (100 dimensions)
- Optimized for mobile inference
- ~50-100 KB file size

### 2. bisaya_metadata.json
```json
{
  "word_to_index": {
    "kumusta": 0,
    "salamat": 1,
    ...
  },
  "index_to_word": {
    "0": "kumusta",
    "1": "salamat",
    ...
  },
  "metadata": [
    {
      "bisaya": "Kumusta",
      "tagalog": "Kumusta",
      "english": "Hello/How are you",
      "pronunciation": "koo-MOOS-tah",
      "pos": "Greeting"
    },
    ...
  ]
}
```

### 3. bisaya_similarity.json
Pre-computed similarity scores for fast lookup:
```json
{
  "kumusta": {
    "salamat": 0.85,
    "maayo": 0.72,
    ...
  }
}
```

---

## Features Enabled by Model

### ✅ Random Quiz
- Generate questions from all 300 words
- Create plausible wrong answers using similarity
- Filter by Part of Speech

### ✅ Voice Quiz
- Match spoken words using embeddings
- Handle pronunciation variations
- Provide similarity-based feedback

### ✅ Word Vocabulary
- Fast bidirectional translation
- Semantic search
- Similar word suggestions

### ✅ Offline Support
- No API calls needed
- Works without internet
- Fast in-memory access

---

## Next Steps

1. **Train the model**: Run `python training/train_model.py`
2. **Copy to assets**: Move model to `assets/models/`
3. **Initialize in app**: Load model in `main.dart`
4. **Update features**: Replace hardcoded data with model calls
5. **Test offline**: Verify all features work without internet

---

## File Locations

- **Training Script**: `training/train_model.py`
- **Trained Model**: `assets/models/bisaya_model.json` (after training)
- **Flutter Service**: `lib/services/nlp_model_service.dart`
- **Dataset**: `vocdataset/bisaya_dataset.csv`

---

## Troubleshooting

**Model not loading?**
- Check file path: `assets/models/bisaya_model.json`
- Verify `pubspec.yaml` includes `assets/models/`
- Run `flutter pub get` after updating assets

**Training errors?**
- Ensure CSV file exists at `training/vocdataset/bisaya_dataset.csv`
- Install all Python dependencies: `pip install -r requirements.txt`
- Check Python version (3.8+ recommended)

**Low similarity scores?**
- Normal for small dataset (300 words)
- Adjust `minSimilarity` threshold in code
- Consider expanding dataset for better embeddings

