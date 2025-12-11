"""
Train TensorFlow Lite model for Bisaya language learning app
Optimized for Google Colab - reads from and saves to Google Drive
"""

import pandas as pd
import numpy as np
from gensim.models import Word2Vec
from sklearn.metrics.pairwise import cosine_similarity
import json
import os
from pathlib import Path
import tensorflow as tf
from google.colab import drive

def mount_google_drive():
    """Mount Google Drive to access files"""
    print("🔗 Mounting Google Drive...")
    drive.mount('/content/drive')
    print("✅ Google Drive mounted!")

def load_dataset_from_drive(folder_name='AAA'):
    """Load the Bisaya dataset from Google Drive folder"""
    drive_path = f'/content/drive/MyDrive/{folder_name}'
    csv_path = f'{drive_path}/bisaya_dataset.csv'
    
    if not os.path.exists(csv_path):
        raise FileNotFoundError(
            f"❌ File not found: {csv_path}\n"
            f"Please make sure:\n"
            f"1. Google Drive is mounted\n"
            f"2. The folder '{folder_name}' exists in your Drive\n"
            f"3. bisaya_dataset.csv is in that folder"
        )
    
    # Try different encodings to handle various CSV formats
    encodings = ['utf-8', 'utf-8-sig', 'latin-1', 'iso-8859-1', 'cp1252', 'windows-1252']
    df = None
    
    for encoding in encodings:
        try:
            df = pd.read_csv(csv_path, encoding=encoding)
            print(f"✅ Loaded {len(df)} entries from {csv_path} (encoding: {encoding})")
            break
        except UnicodeDecodeError:
            continue
        except Exception as e:
            print(f"⚠️ Error with encoding {encoding}: {e}")
            continue
    
    if df is None:
        raise ValueError(
            f"❌ Could not read CSV file with any encoding.\n"
            f"Tried: {', '.join(encodings)}\n"
            f"Please check the CSV file format."
        )
    
    return df, drive_path


def prepare_training_data(df):
    """Prepare text data for training embeddings"""
    all_texts = []
    
    for _, row in df.iterrows():
        # Handle NaN values safely and convert to list of words
        bisaya = str(row.get('Bisaya', '')).lower().strip()
        tagalog = str(row.get('Tagalog', '')).lower().strip() if pd.notna(row.get('Tagalog')) else ''
        english = str(row.get('English', '')).lower().strip()
        
        # Split into words and filter out empty/nan values
        if bisaya and bisaya != 'nan' and bisaya:
            bisaya_words = bisaya.split()
            if bisaya_words:
                all_texts.append(bisaya_words)
        
        if tagalog and tagalog != 'nan' and tagalog:
            tagalog_words = tagalog.split()
            if tagalog_words:
                all_texts.append(tagalog_words)
        
        if english and english != 'nan' and english:
            english_words = english.split()
            if english_words:
                all_texts.append(english_words)
    
    return all_texts

def train_embeddings(training_data):
    """Train Word2Vec embeddings model"""
    print(f"🔄 Training Word2Vec model on {len(training_data)} sentences...")
    
    model = Word2Vec(
        sentences=training_data,
        vector_size=100,
        window=5,
        min_count=1,
        workers=4,
        sg=1
    )
    
    print("✅ Model training completed!")
    return model

def create_embedding_model(word2vec_model, df):
    """Create TensorFlow model for embeddings"""
    print("🔄 Creating TensorFlow embedding model...")
    
    # Build vocabulary mapping
    word_to_index = {}
    index_to_word = {}
    embeddings_list = []
    metadata_list = []
    
    for idx, (_, row) in enumerate(df.iterrows()):
        bisaya = str(row['Bisaya']).strip()
        if bisaya and bisaya != 'nan':
            bisaya_lower = bisaya.lower()
            
            # Get or create embedding
            if bisaya_lower in word2vec_model.wv:
                embedding = word2vec_model.wv[bisaya_lower]
            else:
                words = bisaya_lower.split()
                word_embeddings = [word2vec_model.wv[w] for w in words if w in word2vec_model.wv]
                if word_embeddings:
                    embedding = np.mean(word_embeddings, axis=0)
                else:
                    embedding = np.zeros(100)
            
            word_to_index[bisaya_lower] = idx
            index_to_word[idx] = bisaya_lower
            embeddings_list.append(embedding)
            
            # Include example columns if available
            metadata_entry = {
                'bisaya': bisaya,
                'tagalog': str(row.get('Tagalog', '')).strip() if pd.notna(row.get('Tagalog', '')) else '',
                'english': str(row.get('English', '')).strip(),
                'pronunciation': str(row.get('Pronunciation', '')).strip() if pd.notna(row.get('Pronunciation', '')) else '',
                'pos': str(row.get('Part of Speech', '')).strip() if pd.notna(row.get('Part of Speech', '')) else '',
            }
            
            # Add example columns if they exist in the dataset
            try:
                if 'Beginner Example (Bisaya)' in df.columns:
                    val = row.get('Beginner Example (Bisaya)', '')
                    metadata_entry['beginnerExample'] = str(val).strip() if pd.notna(val) else ''
                    val = row.get('Beginner English Translation', '')
                    metadata_entry['beginnerEnglish'] = str(val).strip() if pd.notna(val) else ''
                    val = row.get('Beginner Tagalog Translation', '')
                    metadata_entry['beginnerTagalog'] = str(val).strip() if pd.notna(val) else ''
                
                if 'Intermediate Example (Bisaya)' in df.columns:
                    val = row.get('Intermediate Example (Bisaya)', '')
                    metadata_entry['intermediateExample'] = str(val).strip() if pd.notna(val) else ''
                    val = row.get('Intermediate English Translation', '')
                    metadata_entry['intermediateEnglish'] = str(val).strip() if pd.notna(val) else ''
                    val = row.get('Intermediate Tagalog Translation', '')
                    metadata_entry['intermediateTagalog'] = str(val).strip() if pd.notna(val) else ''
                
                if 'Advanced Example (Bisaya)' in df.columns:
                    val = row.get('Advanced Example (Bisaya)', '')
                    metadata_entry['advancedExample'] = str(val).strip() if pd.notna(val) else ''
                    val = row.get('Advanced English Translation', '')
                    metadata_entry['advancedEnglish'] = str(val).strip() if pd.notna(val) else ''
                    val = row.get('Advanced Tagalog Translation', '')
                    metadata_entry['advancedTagalog'] = str(val).strip() if pd.notna(val) else ''
            except Exception:
                # If columns don't exist, just skip adding example fields
                pass
            
            metadata_list.append(metadata_entry)
    
    # Create TensorFlow model
    vocab_size = len(embeddings_list)
    embedding_dim = 100
    
    # Create embedding layer
    embedding_matrix = np.array(embeddings_list)
    
    # Simple model: Input word index -> Output embedding
    input_layer = tf.keras.layers.Input(shape=(1,), dtype=tf.int32, name='word_index')
    embedding_layer = tf.keras.layers.Embedding(
        vocab_size,
        embedding_dim,
        weights=[embedding_matrix],
        trainable=False,
        name='word_embeddings'
    )(input_layer)
    output = tf.keras.layers.Flatten()(embedding_layer)
    
    model = tf.keras.Model(inputs=input_layer, outputs=output)
    
    return model, word_to_index, index_to_word, metadata_list

def convert_to_tflite(model, output_path):
    """Convert TensorFlow model to TensorFlow Lite format"""
    print("🔄 Converting to TensorFlow Lite...")
    
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    file_size_kb = os.path.getsize(output_path) / 1024
    print(f"✅ TensorFlow Lite model saved: {output_path}")
    print(f"📦 File size: {file_size_kb:.2f} KB")

def save_metadata(word_to_index, index_to_word, metadata_list, output_path):
    """Save metadata (vocabulary, translations, etc.) as JSON"""
    metadata = {
        'word_to_index': word_to_index,
        'index_to_word': index_to_word,
        'metadata': metadata_list,
        'vocab_size': len(word_to_index),
        'embedding_dim': 100,
        'version': '1.0.0'
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, ensure_ascii=False, indent=2)
    
    print(f"✅ Metadata saved: {output_path}")

def calculate_similarity_matrix(word2vec_model, df):
    """Pre-compute similarity matrix for fast lookup"""
    print("🔄 Calculating similarity matrix...")
    
    words = []
    embeddings = []
    
    for _, row in df.iterrows():
        bisaya = str(row['Bisaya']).strip()
        if bisaya and bisaya != 'nan':
            bisaya_lower = bisaya.lower()
            if bisaya_lower in word2vec_model.wv:
                words.append(bisaya_lower)
                embeddings.append(word2vec_model.wv[bisaya_lower])
    
    if not embeddings:
        return {}
    
    embedding_matrix = np.array(embeddings)
    similarity_matrix = cosine_similarity(embedding_matrix)
    
    # Create top similar words dictionary
    top_similar = {}
    for i, word in enumerate(words):
        similarities = []
        for j, other_word in enumerate(words):
            if i != j:
                similarities.append((other_word, float(similarity_matrix[i][j])))
        similarities.sort(key=lambda x: x[1], reverse=True)
        top_similar[word] = {w: s for w, s in similarities[:10]}
    
    return top_similar

def save_files_to_drive(tflite_path, metadata_path, similarity_path, drive_folder_path):
    """Save all model files to Google Drive folder"""
    print(f"\n💾 Saving model files to Google Drive folder: {drive_folder_path}")
    
    # Copy files to Drive folder
    import shutil
    
    files_to_save = {
        'bisaya_model.tflite': tflite_path,
        'bisaya_metadata.json': metadata_path,
        'bisaya_similarity.json': similarity_path,
    }
    
    for filename, source_path in files_to_save.items():
        dest_path = f'{drive_folder_path}/{filename}'
        shutil.copy2(source_path, dest_path)
        file_size_kb = os.path.getsize(dest_path) / 1024
        print(f"✅ Saved {filename} ({file_size_kb:.2f} KB) to {drive_folder_path}")
    
    print(f"\n✅ All files saved to Google Drive!")
    print(f"📁 Location: {drive_folder_path}")
    print("\n📋 Next steps:")
    print("1. Open Google Drive and navigate to the 'AAA' folder")
    print("2. Download the 3 model files to your computer")
    print("3. Copy them to: assets/models/ in your Flutter project")
    print("4. Make sure pubspec.yaml includes: assets/models/")

def main(folder_name='AAA'):
    """
    Main training function
    
    Args:
        folder_name: Name of the Google Drive folder containing the CSV
                    (default: 'AAA')
    """
    print("=" * 60)
    print("🚀 Bisaya NLP Model Training for TensorFlow Lite")
    print("=" * 60)
    print()
    
    # Step 1: Mount Google Drive
    print("Step 1: Mounting Google Drive...")
    try:
        mount_google_drive()
    except Exception as e:
        print(f"⚠️ Drive mount failed: {e}")
        print("💡 Make sure you authorize access when prompted")
        return
    
    # Step 2: Load dataset from Drive
    print(f"\nStep 2: Loading dataset from Drive folder '{folder_name}'...")
    try:
        df, drive_folder_path = load_dataset_from_drive(folder_name)
    except Exception as e:
        print(f"❌ Error: {e}")
        return
    
    # Step 3: Prepare training data
    print("\nStep 3: Preparing training data...")
    training_data = prepare_training_data(df)
    print(f"✅ Prepared {len(training_data)} training sentences")
    
    # Step 4: Train Word2Vec
    print("\nStep 4: Training Word2Vec embeddings...")
    word2vec_model = train_embeddings(training_data)
    
    # Step 5: Create TensorFlow model
    print("\nStep 5: Creating TensorFlow model...")
    embedding_model, word_to_index, index_to_word, metadata_list = create_embedding_model(word2vec_model, df)
    
    # Step 6: Convert to TensorFlow Lite (save to temp location first)
    print("\nStep 6: Converting to TensorFlow Lite...")
    temp_tflite_path = '/content/bisaya_model.tflite'
    convert_to_tflite(embedding_model, temp_tflite_path)
    
    # Step 7: Save metadata (save to temp location first)
    print("\nStep 7: Saving metadata...")
    temp_metadata_path = '/content/bisaya_metadata.json'
    save_metadata(word_to_index, index_to_word, metadata_list, temp_metadata_path)
    
    # Step 8: Calculate similarity matrix (save to temp location first)
    print("\nStep 8: Calculating similarity matrix...")
    similarity = calculate_similarity_matrix(word2vec_model, df)
    temp_similarity_path = '/content/bisaya_similarity.json'
    with open(temp_similarity_path, 'w', encoding='utf-8') as f:
        json.dump(similarity, f, ensure_ascii=False, indent=2)
    print(f"✅ Similarity matrix saved: {temp_similarity_path}")
    
    # Step 9: Save files to Google Drive
    print("\n" + "=" * 60)
    save_files_to_drive(temp_tflite_path, temp_metadata_path, temp_similarity_path, drive_folder_path)
    
    print("\n" + "=" * 60)
    print("✅ Model training completed successfully!")
    print("=" * 60)

if __name__ == '__main__':
    main()

