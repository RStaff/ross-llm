#!/usr/bin/env python
import requests, sys

BASE = "http://localhost:8000"

def main():
    if len(sys.argv) > 1:
        msg = " ".join(sys.argv[1:])
    else:
        msg = input("Ross-LLM> ")

    payload = {"message": msg, "topic": "manual", "mode": "auto"}
    r = requests.post(f"{BASE}/chat", json=payload, timeout=120)
    r.raise_for_status()
    data = r.json()
    print(f"\n[mode: {data['mode']} | memories: {data['memories_used']}]\n")
    print(data["reply"])

if __name__ == "__main__":
    main()
