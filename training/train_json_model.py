#!/usr/bin/env python3
"""
Train JSON-based model for Bisaya language learning app
Generates word embeddings and exports to JSON format (no TensorFlow required)
This is a lightweight alternative that works with any Python version
"""

import pandas as pd
import numpy as np
from gensim.models import Word2Vec
from sklearn.metrics.pairwise import cosine_similarity
import json
import os
from pathlib import Path

def load_dataset(csv_path):
    """Load the Bisaya dataset from CSV"""
    df = pd.read_csv(csv_path)
    print(f"✅ Loaded {len(df)} entries from dataset")
    return df

def prepare_training_data(df):
    """Prepare text data for training embeddings"""
    all_texts = []
    
    for _, row in df.iterrows():
        bisaya = str(row['Bisaya']).lower().split()
        tagalog = str(row['Tagalog']).lower().split() if pd.notna(row.get('Tagalog')) else []
        english = str(row['English']).lower().split()
        
        if bisaya and bisaya[0] != 'nan':
            all_texts.append(bisaya)
        if tagalog and tagalog and tagalog[0] != 'nan':
            all_texts.append(tagalog)
        if english and english[0] != 'nan':
            all_texts.append(english)
    
    return all_texts

def train_embeddings(training_data):
    """Train Word2Vec embeddings model"""
    print(f"📚 Training Word2Vec model on {len(training_data)} sentences...")
    
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

def generate_embeddings(word2vec_model, df):
    """Generate embeddings for all words in dataset"""
    print("🔍 Generating embeddings...")
    
    embeddings = {}
    metadata_list = []
    
    for idx, (_, row) in enumerate(df.iterrows()):
        bisaya = str(row['Bisaya']).strip()
        if not bisaya or bisaya == 'nan':
            continue
            
        bisaya_lower = bisaya.lower()
        
        # Get or create embedding
        if bisaya_lower in word2vec_model.wv:
            embedding = word2vec_model.wv[bisaya_lower].tolist()
        else:
            # For multi-word phrases, average word embeddings
            words = bisaya_lower.split()
            word_embeddings = [word2vec_model.wv[w] for w in words if w in word2vec_model.wv]
            if word_embeddings:
                embedding = np.mean(word_embeddings, axis=0).tolist()
            else:
                embedding = [0.0] * 100
        
        embeddings[bisaya_lower] = embedding
        
        metadata_list.append({
            'bisaya': bisaya,
            'tagalog': str(row['Tagalog']).strip() if pd.notna(row.get('Tagalog')) else '',
            'english': str(row['English']).strip(),
            'pronunciation': str(row['Pronunciation']).strip() if pd.notna(row.get('Pronunciation')) else '',
            'pos': str(row['Part of Speech']).strip() if pd.notna(row.get('Part of Speech')) else 'Unknown',
            'category': str(row['Category']).strip() if pd.notna(row.get('Category')) else 'Uncategorized',
        })
    
    print(f"✅ Generated embeddings for {len(embeddings)} words")
    return embeddings, metadata_list

def calculate_similarity_matrix(embeddings_dict):
    """Pre-compute similarity matrix for fast lookup"""
    print("📊 Calculating similarity matrix...")
    
    words = list(embeddings_dict.keys())
    embeddings = np.array([embeddings_dict[w] for w in words])
    
    if len(embeddings) == 0:
        return {}
    
    similarity_matrix = cosine_similarity(embeddings)
    
    # Create top similar words dictionary
    top_similar = {}
    for i, word in enumerate(words):
        similarities = []
        for j, other_word in enumerate(words):
            if i != j:
                similarities.append((other_word, float(similarity_matrix[i][j])))
        similarities.sort(key=lambda x: x[1], reverse=True)
        top_similar[word] = {w: s for w, s in similarities[:10]}
    
    print(f"✅ Calculated similarities for {len(top_similar)} words")
    return top_similar

def save_model(embeddings, metadata_list, similarity, output_path):
    """Save complete model as JSON"""
    print(f"💾 Saving model to {output_path}...")
    
    model_data = {
        'embeddings': embeddings,
        'metadata': metadata_list,
        'similarity': similarity,
        'vocab_size': len(embeddings),
        'embedding_dim': 100,
        'version': '2.0.0',
        'format': 'json'
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(model_data, f, ensure_ascii=False, indent=2)
    
    file_size_kb = os.path.getsize(output_path) / 1024
    print(f"✅ Model saved: {output_path}")
    print(f"📦 File size: {file_size_kb:.2f} KB")

def main():
    # Paths
    base_dir = Path(__file__).parent.parent  # Go up one level to project root
    csv_path = base_dir / 'lib' / 'vocdataset' / 'bisaya_dataset.csv'
    output_dir = base_dir / 'assets' / 'models'
    output_dir.mkdir(parents=True, exist_ok=True)
    model_path = output_dir / 'bisaya_model.json'
    
    print("🚀 Starting Bisaya NLP Model Training (JSON Format)")
    print("=" * 60)
    
    # Check if CSV exists
    if not csv_path.exists():
        print(f"❌ Error: Dataset not found at {csv_path}")
        print("   Please ensure the CSV file exists at lib/vocdataset/bisaya_dataset.csv")
        return
    
    # Load dataset
    df = load_dataset(csv_path)
    
    # Prepare training data
    training_data = prepare_training_data(df)
    
    # Train Word2Vec model
    word2vec_model = train_embeddings(training_data)
    
    # Generate embeddings
    embeddings, metadata_list = generate_embeddings(word2vec_model, df)
    
    # Calculate similarity matrix
    similarity = calculate_similarity_matrix(embeddings)
    
    # Save model
    save_model(embeddings, metadata_list, similarity, model_path)
    
    print("\n" + "=" * 60)
    print("✅ Model training completed successfully!")
    print(f"📁 Model file: {model_path}")
    print("\n📝 Next steps:")
    print("1. ✅ Model is already in assets/models/")
    print("2. Run 'flutter clean && flutter pub get'")
    print("3. Update NLPModelService to load from bisaya_model.json")
    print("4. Test your app!")

if __name__ == '__main__':
    main()

