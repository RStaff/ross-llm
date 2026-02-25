
# === StaffordOS Memory Injection Add-On ===
from state import ROSS_STATE

def add_persona_memory(user_text):
    persona = ROSS_STATE.get("persona_memory", {})
    if not persona:
        return user_text

    memory_block = "\n[PERSONA MEMORY]\n" + str(persona) + "\n[/PERSONA MEMORY]\n"
    return memory_block + "\n" + user_text
