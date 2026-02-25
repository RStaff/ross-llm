import os
from typing import List

_MODEL = None

def _get_model():
    global _MODEL
    if _MODEL is None:
        from sentence_transformers import SentenceTransformer
        name = os.getenv("HF_EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")
        _MODEL = SentenceTransformer(name)
    return _MODEL

def embed_texts(texts: List[str]) -> List[List[float]]:
    m = _get_model()
    vecs = m.encode(texts, normalize_embeddings=True)
    return [v.tolist() for v in vecs]

def embedding_dim() -> int:
    m = _get_model()
    return int(m.get_sentence_embedding_dimension())
