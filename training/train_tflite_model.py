"""
Train TensorFlow Lite model for Bisaya language learning app
Generates word embeddings and exports to .tflite format for Flutter
"""

import pandas as pd
import numpy as np
from gensim.models import Word2Vec
from sklearn.metrics.pairwise import cosine_similarity
import json
import os
from pathlib import Path
try:
    import tensorflow as tf
    TENSORFLOW_AVAILABLE = True
except ImportError:
    TENSORFLOW_AVAILABLE = False
    print("⚠️ TensorFlow not available. Will generate JSON model only.")

def load_dataset(csv_path):
    """Load the Bisaya dataset from CSV"""
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} entries from dataset")
    return df

def prepare_training_data(df):
    """Prepare text data for training embeddings"""
    all_texts = []
    
    for _, row in df.iterrows():
        bisaya = str(row['Bisaya']).lower().split()
        tagalog = str(row['Tagalog']).lower().split()
        english = str(row['English']).lower().split()
        
        if bisaya and bisaya[0] != 'nan':
            all_texts.append(bisaya)
        if tagalog and tagalog[0] != 'nan':
            all_texts.append(tagalog)
        if english and english[0] != 'nan':
            all_texts.append(english)
    
    return all_texts

def train_embeddings(training_data):
    """Train Word2Vec embeddings model"""
    print(f"Training Word2Vec model on {len(training_data)} sentences...")
    
    model = Word2Vec(
        sentences=training_data,
        vector_size=100,
        window=5,
        min_count=1,
        workers=4,
        sg=1
    )
    
    print("Model training completed!")
    return model

def create_embedding_model(word2vec_model, df):
    """Create TensorFlow model for embeddings"""
    print("Creating TensorFlow embedding model...")
    
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
    
    # Also create a similarity model
    # Input: two word indices, Output: similarity score
    input1 = tf.keras.layers.Input(shape=(1,), dtype=tf.int32, name='word1_index')
    input2 = tf.keras.layers.Input(shape=(1,), dtype=tf.int32, name='word2_index')
    
    emb1 = embedding_layer(input1)
    emb2 = embedding_layer(input2)
    
    # Flatten embeddings
    flat1 = tf.keras.layers.Flatten()(emb1)
    flat2 = tf.keras.layers.Flatten()(emb2)
    
    # Calculate cosine similarity
    dot_product = tf.keras.layers.Dot(axes=1)([flat1, flat2])
    norm1 = tf.sqrt(tf.reduce_sum(tf.square(flat1), axis=1, keepdims=True))
    norm2 = tf.sqrt(tf.reduce_sum(tf.square(flat2), axis=1, keepdims=True))
    similarity = dot_product / (norm1 * norm2 + 1e-8)
    
    similarity_model = tf.keras.Model(inputs=[input1, input2], outputs=similarity)
    
    return model, similarity_model, word_to_index, index_to_word, metadata_list

def convert_to_tflite(model, output_path):
    """Convert TensorFlow model to TensorFlow Lite format"""
    print("Converting to TensorFlow Lite...")
    
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
    print("Calculating similarity matrix...")
    
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

def main():
    # Paths
    base_dir = Path(__file__).parent.parent  # Go up one level to project root
    csv_path = base_dir / 'lib' / 'vocdataset' / 'bisaya_dataset.csv'
    output_dir = base_dir / 'assets' / 'models'
    output_dir.mkdir(parents=True, exist_ok=True)
    tflite_path = output_dir / 'bisaya_model.tflite'
    metadata_path = output_dir / 'bisaya_metadata.json'
    similarity_path = output_dir / 'bisaya_similarity.json'
    
    # Load dataset
    df = load_dataset(csv_path)
    
    # Prepare training data
    training_data = prepare_training_data(df)
    
    # Train Word2Vec model
    word2vec_model = train_embeddings(training_data)
    
    # Create TensorFlow models
    embedding_model, similarity_model, word_to_index, index_to_word, metadata_list = create_embedding_model(word2vec_model, df)
    
    # Convert to TensorFlow Lite
    convert_to_tflite(embedding_model, tflite_path)
    
    # Save metadata
    save_metadata(word_to_index, index_to_word, metadata_list, metadata_path)
    
    # Calculate and save similarity matrix
    similarity = calculate_similarity_matrix(word2vec_model, df)
    with open(similarity_path, 'w', encoding='utf-8') as f:
        json.dump(similarity, f, ensure_ascii=False, indent=2)
    print(f"✅ Similarity matrix saved: {similarity_path}")
    
    print("\n✅ Model training completed successfully!")
    print(f"📁 TensorFlow Lite model: {tflite_path}")
    print(f"📁 Metadata file: {metadata_path}")
    print(f"📁 Similarity matrix: {similarity_path}")
    print("\n✅ Files are already in assets/models/ - ready to use!")
    print("\nNext steps:")
    print("1. ✅ Model files are in assets/models/")
    print("2. Verify pubspec.yaml includes assets/models/")
    print("3. Run 'flutter clean && flutter pub get' to refresh assets")
    print("4. Test the model in your Flutter app")

if __name__ == '__main__':
    main()

