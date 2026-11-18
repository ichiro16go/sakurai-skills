#!/usr/bin/env bash
# UserPromptSubmit: trigger に当たる rule だけを stdout へ注入し、発火を計測する。
# rule 読み込み: ${CLAUDE_PLUGIN_ROOT}/rules.jsonl（同梱）+ ${DATA}/rules.local.jsonl（record-rule で追記）
# 計測先: ${DATA}/rule_metrics.json（プラグイン更新で消えないよう DATA 側に置く）
set -euo pipefail

ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DATA="${CLAUDE_PLUGIN_DATA:-$ROOT}"
mkdir -p "$DATA"

PAYLOAD=$(cat || true)
[ -z "$PAYLOAD" ] && exit 0

python3 -I - "$PAYLOAD" "$ROOT/rules.jsonl" "$DATA/rules.local.jsonl" "$DATA/rule_metrics.json" <<'PY'
import sys, os, json, datetime

raw, *rule_files, metrics_path = sys.argv[1:]
try:
    data = json.loads(raw)
    prompt = data.get("prompt", raw)
    session_id = data.get("session_id", "sess_default")
except Exception:
    prompt, session_id = raw, "sess_default"

rules = []
for path in rule_files:
    if not os.path.exists(path):
        continue
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                r = json.loads(line)
            except Exception:
                continue
            if r.get("status", "active") == "active":
                rules.append(r)

low = prompt.lower()
matched = []
for r in rules:
    trig = r.get("trigger", [])
    if isinstance(trig, str):
        trig = [trig]
    if any(t.lower() in low for t in trig):
        matched.append(r)
if not matched:
    sys.exit(0)

metrics = {"rules": {}}
try:
    with open(metrics_path, encoding="utf-8") as f:
        metrics = json.load(f)
except Exception:
    pass
stats = metrics.setdefault("rules", {})
now = datetime.datetime.now().isoformat(timespec="seconds")
for r in matched:
    s = stats.setdefault(r["id"], {"hit_count": 0, "session_hits": [], "last_triggered": None})
    s["hit_count"] += 1
    if session_id not in s["session_hits"]:
        s["session_hits"].append(session_id)
    s["last_triggered"] = now
try:
    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2, ensure_ascii=False)
except Exception:
    pass

print("[自律成長ルール注入 (桜井哲学 x Instinct)] 以下の学習済みルールを最優先で適用してください:")
for r in matched:
    print(f"- [{r['id']}] {r['directive']}")
PY
