import sys, requests

URL = "http://127.0.0.1:8080/chat"

print("--- KAYDEN CORE INTERFACE v4.8 ---")
while True:
    q = input("\nSIGNAL > ")
    if q.lower() in ['exit', 'quit']: break
    try:
        r = requests.get(URL, params={"q": q})
        print(f"\nKAYDEN: {r.text}")
    except Exception as e:
        print(f"\nERROR: Could not reach engine. ({e})")