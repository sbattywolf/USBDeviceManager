#!/usr/bin/env bash
set -euo pipefail
out=${1:-env-check.json}

env_ok=true
reasons=()
declare -A checks

# dotnet
if command -v dotnet >/dev/null 2>&1; then
  checks[dotnet]=true
else
  checks[dotnet]=false
  reasons+=("dotnet-missing")
  env_ok=false
fi

# python3
if command -v python3 >/dev/null 2>&1; then
  checks[python]=true
else
  checks[python]=false
  reasons+=("python-missing")
  env_ok=false
fi

# node (optional)
if command -v node >/dev/null 2>&1; then
  checks[node]=true
else
  checks[node]=false
  reasons+=("node-missing")
fi

# filesystem write check
tmp_dir="$(pwd)/scripts/tmp"
mkdir -p "$tmp_dir" || true
tmpfile="$tmp_dir/env-check-$$.txt"
if printf 'ok' > "$tmpfile" 2>/dev/null; then
  checks[fs]=true
  rm -f "$tmpfile" || true
else
  checks[fs]=false
  reasons+=("fs-write-failed")
  env_ok=false
fi

# Join reasons
if [ ${#reasons[@]} -eq 0 ]; then
  reason_str=""
else
  IFS=';'
  reason_str="${reasons[*]}"
  unset IFS
fi

# Build JSON (avoid requiring jq)
cat > "$out" <<JSON
{
  "env_ok": ${env_ok},
  "reason": "${reason_str}",
  "checks": {
    "dotnet": ${checks[dotnet]},
    "python": ${checks[python]},
    "node": ${checks[node]},
    "fs": ${checks[fs]}
  }
}
JSON

# Always exit 0; workflow will inspect the JSON
exit 0
