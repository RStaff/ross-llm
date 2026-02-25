import time, os, json, pathlib

LOG_PATH = pathlib.Path(os.getenv("ROSSLLM_LOG", "telemetry/events.log"))

def log_event(event: dict):
    event = dict(event)
    event["ts"] = time.time()
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOG_PATH.open("a") as f:
        f.write(json.dumps(event) + "\n")
