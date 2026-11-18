#!/usr/bin/env bash
# PreToolUse: 破壊的操作・機密情報の混入を検知したら exit 2 でツール実行をブロックする。
set -euo pipefail

PAYLOAD=$(cat || true)
[ -z "$PAYLOAD" ] && exit 0

python3 -I - "$PAYLOAD" <<'PY'
import sys, json, re

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

ti = data.get("tool_input", {})
vals = ti.values() if isinstance(ti, dict) else [ti]
text = " ".join(v for v in vals if isinstance(v, str))

destructive = [
    r"rm\s+-[rf]{1,2}\s+(/|\*|~|\$HOME)",
    r"git\s+reset\s+--hard",
    r"git\s+clean\s+-[fdx]{1,3}",
    r"\bmkfs",
    r":\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;",
    r">\s*/dev/sd[a-z]",
    r"chmod\s+-R\s+777\s+/",
]
secrets = [
    r"BEGIN\s+(RSA|OPENSSH|DSA|EC)?\s*PRIVATE\s+KEY",
    r"ghp_[A-Za-z0-9_]{36,}",
    r"sk-ant-[A-Za-z0-9_\-]{30,}",
    r"sk-[A-Za-z0-9]{32,}",
    r"aws_secret_access_key\s*=",
    r"\.env\b",
]
for label, pats in (("破壊的コマンドの実行", destructive), ("機密情報または環境設定ファイルへの危険なアクセス", secrets)):
    for p in pats:
        if re.search(p, text, re.IGNORECASE):
            print(f"[BLOCKED] {label}が検知されました: {p}", file=sys.stderr)
            sys.exit(2)
sys.exit(0)
PY
