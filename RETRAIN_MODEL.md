# Retrain TensorFlow Model with New Dataset

## ⚠️ Important: Python Version Compatibility

**Your Python 3.14 is too new** - TensorFlow and Gensim don't support it yet.

## ✅ Recommended: Use Google Colab (Easiest - No Setup!)

**This is the best option - works immediately!**

1. **Open Google Colab:**
   - Go to [colab.research.google.com](https://colab.research.google.com/)
   - Create a new notebook

2. **Upload and run:**
   ```python
   # Install dependencies (runs automatically in Colab)
   !pip install pandas gensim scikit-learn tensorflow numpy
   
   # Upload your CSV file
   from google.colab import files
   uploaded = files.upload()  # Upload lib/vocdataset/bisaya_dataset.csv
   
   # Run training
   !python train_tflite_colab.py
   ```

3. **Download results:**
   - Model files will be in a zip file
   - Extract to `assets/models/` in your Flutter project

📖 **See detailed guide:** `training/COLAB_TRAINING_GUIDE.md`

---

## Alternative: Use Python 3.11 or 3.12 Locally

If you want to train locally:

1. **Install Python 3.11 or 3.12** (not 3.14)
2. **Create virtual environment:**
   ```bash
   python3.11 -m venv venv
   venv\Scripts\activate  # Windows
   ```

3. **Install dependencies:**
   ```bash
   pip install pandas gensim scikit-learn tensorflow numpy
   ```

4. **Run training:**
   ```bash
   python training/train_tflite_model.py
   ```

## What Gets Generated

After training, you'll get 3 files in `assets/models/`:

1. **`bisaya_model.tflite`** - The TensorFlow Lite model
2. **`bisaya_metadata.json`** - Word mappings and translations
3. **`bisaya_similarity.json`** - Similarity matrix for word matching

## After Training

1. Files are automatically saved to `assets/models/`
2. Run `flutter clean && flutter pub get`
3. Test your app - the model will use the new dataset!

## Troubleshooting

**If dependencies fail to install:**
- Try: `pip install --upgrade pip` first
- Or use a virtual environment: `python -m venv venv` then `venv\Scripts\activate`

**If training fails:**
- Check CSV file exists at `lib/vocdataset/bisaya_dataset.csv`
- Verify CSV has all required columns
- Check Python version (3.8+ recommended)

