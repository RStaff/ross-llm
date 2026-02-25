import json, time, sys, statistics as stats, requests

GATEWAY="http://localhost:8000/chat"
cases=[json.loads(l) for l in open("tests.jsonl")]
results=[]
for c in cases:
    t0=time.time()
    r=requests.post(GATEWAY, json={"user_id":"eval","text":c["input"]}, timeout=20)
    dt=int((time.time()-t0)*1000)
    try:
        reply=r.json().get("reply","")
    except Exception:
        reply=r.text
    passcase = r.ok and (c["expect_contains"].lower() in reply.lower())
    results.append({"name":c["name"],"ok":r.ok,"pass":passcase,"latency_ms":dt,"reply":reply[:200]})

passed=[x for x in results if x["pass"]]
lat=[x["latency_ms"] for x in results if x["ok"]]
print("EVAL RESULTS")
print(f"  total: {len(results)}  pass: {len(passed)}/{len(results)}")
if lat:
    print(f"  p50: {int(stats.median(lat))}ms  p95: {int(sorted(lat)[max(0,int(len(lat)*0.95)-1)])}ms")
print("\nDETAILS")
for x in results:
    mark="✅" if x["pass"] else "❌"
    print(f" {mark} {x['name']} | ok={x['ok']} | {x['latency_ms']}ms | {x['reply']}")
