"""
Train AI model for Bisaya language learning app
Generates word embeddings and exports to JSON format for Flutter
"""

import pandas as pd
import numpy as np
from gensim.models import Word2Vec, FastText
from sklearn.metrics.pairwise import cosine_similarity
import json
import os
from pathlib import Path

def load_dataset(csv_path):
    """Load the Bisaya dataset from CSV"""
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} entries from dataset")
    return df

def prepare_training_data(df):
    """Prepare text data for training embeddings"""
    # Combine all language versions for richer context
    all_texts = []
    
    for _, row in df.iterrows():
        # Create sentences from each language
        bisaya = str(row['Bisaya']).lower().split()
        tagalog = str(row['Tagalog']).lower().split()
        english = str(row['English']).lower().split()
        
        # Add each as a sentence for training
        if bisaya and bisaya[0] != 'nan':
            all_texts.append(bisaya)
        if tagalog and tagalog[0] != 'nan':
            all_texts.append(tagalog)
        if english and english[0] != 'nan':
            all_texts.append(english)
    
    return all_texts

def train_embeddings(training_data, model_type='word2vec'):
    """Train word embeddings model"""
    print(f"Training {model_type} model on {len(training_data)} sentences...")
    
    if model_type == 'word2vec':
        model = Word2Vec(
            sentences=training_data,
            vector_size=100,  # Embedding dimension
            window=5,  # Context window
            min_count=1,  # Minimum word frequency
            workers=4,
            sg=1  # Skip-gram
        )
    else:  # fasttext
        model = FastText(
            sentences=training_data,
            vector_size=100,
            window=5,
            min_count=1,
            workers=4,
            sg=1
        )
    
    print("Model training completed!")
    return model

def generate_embeddings(model, df):
    """Generate embeddings for all words in dataset"""
    embeddings = {}
    metadata = {}
    
    for _, row in df.iterrows():
        bisaya = str(row['Bisaya']).strip()
        tagalog = str(row['Tagalog']).strip()
        english = str(row['English']).strip()
        pos = str(row['Part of Speech']).strip()
        pronunciation = str(row['Pronunciation']).strip()
        
        # Get embedding for Bisaya word (primary key)
        if bisaya and bisaya != 'nan':
            bisaya_lower = bisaya.lower()
            
            # Try to get embedding, use average if word not found
            if bisaya_lower in model.wv:
                embedding = model.wv[bisaya_lower].tolist()
            else:
                # If word not in vocab, try to get embedding for individual words
                words = bisaya_lower.split()
                word_embeddings = [model.wv[w] for w in words if w in model.wv]
                if word_embeddings:
                    embedding = np.mean(word_embeddings, axis=0).tolist()
                else:
                    # Use zero vector as fallback
                    embedding = [0.0] * model.vector_size
            
            embeddings[bisaya_lower] = embedding
            
            metadata[bisaya_lower] = {
                'bisaya': bisaya,
                'tagalog': tagalog,
                'english': english,
                'pronunciation': pronunciation,
                'pos': pos
            }
    
    return embeddings, metadata

def calculate_similarity_matrix(embeddings):
    """Calculate similarity matrix for all word pairs"""
    print("Calculating similarity matrix...")
    
    words = list(embeddings.keys())
    embedding_matrix = np.array([embeddings[word] for word in words])
    
    # Calculate cosine similarity
    similarity_matrix = cosine_similarity(embedding_matrix)
    
    # Convert to dictionary for easier lookup
    similarity_dict = {}
    for i, word1 in enumerate(words):
        similarity_dict[word1] = {}
        for j, word2 in enumerate(words):
            if i != j:  # Don't include self-similarity
                similarity_dict[word1][word2] = float(similarity_matrix[i][j])
    
    # For each word, get top 10 most similar words
    top_similar = {}
    for word in words:
        similar_words = sorted(
            similarity_dict[word].items(),
            key=lambda x: x[1],
            reverse=True
        )[:10]
        top_similar[word] = {w: s for w, s in similar_words}
    
    return top_similar

def export_to_json(embeddings, metadata, similarity, output_path):
    """Export model to JSON format"""
    model_data = {
        'embeddings': embeddings,
        'metadata': metadata,
        'similarity': similarity,
        'version': '1.0.0',
        'total_words': len(embeddings)
    }
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(model_data, f, ensure_ascii=False, indent=2)
    
    print(f"Model exported to {output_path}")
    print(f"Total words: {len(embeddings)}")
    print(f"File size: {os.path.getsize(output_path) / 1024:.2f} KB")

def main():
    # Paths
    base_dir = Path(__file__).parent
    csv_path = base_dir / 'vocdataset' / 'bisaya_dataset.csv'
    output_dir = base_dir / 'models'
    output_dir.mkdir(exist_ok=True)
    output_path = output_dir / 'bisaya_model.json'
    
    # Load dataset
    df = load_dataset(csv_path)
    
    # Prepare training data
    training_data = prepare_training_data(df)
    
    # Train model
    model = train_embeddings(training_data, model_type='word2vec')
    
    # Generate embeddings
    embeddings, metadata = generate_embeddings(model, df)
    
    # Calculate similarity
    similarity = calculate_similarity_matrix(embeddings)
    
    # Export to JSON
    export_to_json(embeddings, metadata, similarity, output_path)
    
    print("\n✅ Model training completed successfully!")
    print(f"📁 Model saved to: {output_path}")
    print("\nNext steps:")
    print("1. Copy the model file to assets/models/ in your Flutter project")
    print("2. Update pubspec.yaml to include the model in assets")
    print("3. Create NLP model service in Flutter to load and use the model")

if __name__ == '__main__':
    main()

