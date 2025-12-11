# Bisaya NLP Model Training (TensorFlow Lite)

This directory contains scripts to train a TensorFlow Lite model from the Bisaya dataset for offline use in the Flutter app.

## 🚀 Quick Start: Train in Google Colab (Recommended)

**Easiest way to train the model - no local setup needed!**

1. Open [Google Colab](https://colab.research.google.com/)
2. Install: `!pip install pandas gensim scikit-learn tensorflow`
3. Run `train_tflite_colab.py` (copy the script into Colab)
4. Upload your CSV when prompted
5. Download the zip file with all model files

📖 **See detailed guide**: `COLAB_TRAINING_GUIDE.md`

---

## Local Training (Alternative)

If you prefer to train locally:

### Setup

1. **Install Python dependencies:**
```bash
pip install -r requirements.txt
```

2. **Ensure dataset is in place:**
- The CSV file should be at: `vocdataset/bisaya_dataset.csv`

### Training

Run the TensorFlow Lite training script:
```bash
python train_tflite_model.py
```

This will:
1. Load the CSV dataset
2. Train Word2Vec embeddings on all words
3. Create TensorFlow model with embedding layer
4. Convert to TensorFlow Lite format (.tflite)
5. Export metadata and similarity matrix as JSON

## Output Files

The training will generate three files:

1. **`models/bisaya_model.tflite`** - TensorFlow Lite model
   - Contains word embeddings
   - Optimized for mobile inference
   - Small file size (~50-100 KB)

2. **`models/bisaya_metadata.json`** - Vocabulary and translations
   - Word to index mapping
   - Index to word mapping
   - Metadata (translations, pronunciation, POS)

3. **`models/bisaya_similarity.json`** - Pre-computed similarity matrix
   - Fast lookup for similar words
   - Used for quiz distractor generation

## Integration

After training:
1. Copy all three files to `assets/models/` in Flutter project:
   - `bisaya_model.tflite`
   - `bisaya_metadata.json`
   - `bisaya_similarity.json`
2. Update `pubspec.yaml` to include the model files
3. Add `tflite_flutter: ^0.10.0` to dependencies
4. Use `NLPModelService` in Flutter to load and use the model

## Model Architecture

The TensorFlow Lite model:
- **Input**: Word index (integer)
- **Embedding Layer**: 100-dimensional word embeddings
- **Output**: Word embedding vector (100 floats)

The model is optimized for:
- Fast inference on mobile devices
- Low memory usage
- Offline operation

