"""Read a fixed prior run's artifact. No model key, network calls or deployment.

The recovery payload exports already existing JSON files through the same private
GitHub run summary when the in-app browser cannot download its ZIP artifact.
"""
import base64
import gzip
import hashlib
import json
import os
from pathlib import Path

root = Path("output/pilot-import")
names = sorted(p for p in root.rglob("*.json") if p.is_file())
assert names, "Missing archived pilot files"
files = {str(p.relative_to(root)): p.read_bytes() for p in names}
assert "measurements.json" in files and "checkpoint.json" in files
measurements = json.loads(files["measurements.json"])
assert measurements["dispatchedCalls"] == 2
assert measurements["limits"] == {"maxCalls": 2, "maxUsd": 0.05}
assert measurements["productionWrites"] == measurements["providerCalls"] == 0

serialized = json.dumps(
    {name: base64.b64encode(body).decode("ascii") for name, body in files.items()},
    separators=(",", ":"),
).encode()
compressed = gzip.compress(serialized, mtime=0)
payload = {
    "format": "lector-archived-pilot-json-gzip-base64-v1",
    "originRunId": 38462876424,
    "paidReadCalls": 0,
    "sha256": hashlib.sha256(compressed).hexdigest(),
    "filesSha256": {n: hashlib.sha256(b).hexdigest() for n, b in files.items()},
    "base64": base64.b64encode(compressed).decode("ascii"),
}

parts = ["# Archived pilot — read only, zero model calls\n"]
for name in ["measurements.json", "mechanical-checks.json", "recovery.json"]:
    parts.append(f"## {name}\n\n```json\n{files[name].decode()}\n```\n")
parts.append(
    "<details><summary>Local recovery payload — existing files only</summary>\n\n"
    + "```json\n" + json.dumps(payload, separators=(",", ":"))
    + "\n```\n\n</details>\n"
)
summary = "\n".join(parts)
assert len(summary.encode()) < 900_000, "GitHub summary size exceeded"
Path(os.environ["GITHUB_STEP_SUMMARY"]).write_text(summary)
print(json.dumps({
    "status": measurements["status"],
    "sourceRunId": 38462876424,
    "paidReadCalls": 0,
    "fileCount": len(files),
    "coverage": measurements["coverage"],
    "usageEstimateUsd": measurements["usageEstimateUsd"],
}))
