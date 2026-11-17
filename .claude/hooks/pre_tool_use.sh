
#!/usr/bin/env bash
# ==============================================================================
# PreToolUse Hook: 安全ガード（破壊的操作 &amp; 機密情報流出の抑止）
# ==============================================================================
set -euo pipefail

PAYLOAD=$(cat || true)
if [ -z "$PAYLOAD" ]; then
  exit 0
fi

python3 - &lt;&lt; 'EOF' "$PAYLOAD"
import sys, json, re

raw_input = sys.argv[1]
try:
    data = json.loads(raw_input)
except Exception:
    sys.exit(0)

tool_input = data.get("tool_input", {})
content_to_check = []

if isinstance(tool_input, dict):
    for v in tool_input.values():
        if isinstance(v, str):
            content_to_check.append(v)
elif isinstance(tool_input, str):
    content_to_check.append(tool_input)

text = " ".join(content_to_check)

# 1. 破壊的コマンドの検知
destructive_patterns = [
    r"rm\s+-[rf]{1,2}\s+(/|\*|~|\$HOME)",
    r"git\s+reset\s+--hard",
    r"git\s+clean\s+-[fdx]{1,3}",
    r"mkfs",
    r":\\(\\)\s*\{\s*:\s*\|\s*:\s*&amp;\s*\}\s*;",
    r"&gt;\s*/dev/sd[a-z]",
    r"chmod\s+-R\s+777\s+/"
]

for pat in destructive_patterns:
    if re.search(pat, text, re.IGNORECASE):
        print(f"[BLOCKED] 破壊的コマンドの実行が検知されました: {pat}", file=sys.stderr)
        sys.exit(1)

# 2. 機密情報の流出・書き込み検知
secret_patterns = [
    r"BEGIN\s+(RSA|OPENSSH|DSA|EC)?\s*PRIVATE\s+KEY",
    r"ghp_[A-Za-z0-9_]{36,}",
    r"sk-ant-[A-Za-z0-9_\-]{30,}",
    r"sk-[A-Za-z0-9]{32,}",
    r"aws_secret_access_key\s*=",
    r"\.env\b",
]

for pat in secret_patterns:
    if re.search(pat, text, re.IGNORECASE):
        print(f"[BLOCKED] 機密情報または環境設定ファイルへの危険なアクセスが検知されました: {pat}", file=sys.stderr)
        sys.exit(1)

sys.exit(0)
EOF
