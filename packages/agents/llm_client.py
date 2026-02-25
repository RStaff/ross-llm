from typing import List

def generate(system: str, user: str, context_chunks: List[str]) -> str:
    joined = "\n".join(context_chunks)
    return f"[ROSSLLM_STUB]\nSYSTEM:\n{system}\n\nCONTEXT:\n{joined}\n\nUSER:\n{user}\n"
