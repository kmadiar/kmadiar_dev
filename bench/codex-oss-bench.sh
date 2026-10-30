#!/bin/bash
# Benchmark gpt-oss:20b under Ollama the way `codex --oss` would use it, and
# write a markdown result file next to this script.
#
#   CTXS="32768 65536" ./bench/codex-oss-bench.sh
#
# Uses a private Ollama server on port 11435 so an already-running Ollama
# (app or brew service) doesn't override the context length.
set -euo pipefail

CTXS=${CTXS:-32768}
MODEL=${MODEL:-gpt-oss:20b}
PORT=${PORT:-11435}
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
export OLLAMA_HOST=127.0.0.1:$PORT

for bin in ollama swift python3; do
    command -v "$bin" >/dev/null || { echo "missing: $bin (brew install ollama / xcode-select --install)"; exit 1; }
done

chip=$(sysctl -n machdep.cpu.brand_string)
mem_gib=$(( $(sysctl -n hw.memsize) / 1073741824 ))
macos=$(sw_vers -productVersion)
wired=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo n/a)

cat > "$WORK/ws.swift" <<'EOF'
import Metal
let d = MTLCreateSystemDefaultDevice()!
print(String(format: "%.2f", Double(d.recommendedMaxWorkingSetSize) / 1073741824))
EOF
ws_gib=$(swift "$WORK/ws.swift")

slug=$(echo "$chip-${mem_gib}gb" | tr 'A-Z ' 'a-z-')
out="$HERE/results-$slug-$(date +%Y-%m-%d).md"

{
    echo "# $MODEL on $chip, $mem_gib GB"
    echo
    echo "- macOS $macos, Ollama $(ollama --version 2>/dev/null | awk '{print $NF}' | tail -1)"
    echo "- iogpu.wired_limit_mb: $wired"
    echo "- recommendedMaxWorkingSetSize: $ws_gib GiB"
    echo
} > "$out"

server_pid=""
stop_server() {
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null && wait "$server_pid" 2>/dev/null || true
    server_pid=""
}
trap 'stop_server; rm -rf "$WORK"' EXIT

gen() {
    curl -s "http://$OLLAMA_HOST/api/generate" -d "{\"model\":\"$MODEL\",\"prompt\":\"$1\",\"stream\":false,\"options\":{\"num_predict\":64}}" |
        python3 -c '
import json, sys
d = json.load(sys.stdin)
load = d["load_duration"] / 1e9
pn, gn = d["prompt_eval_count"], d["eval_count"]
pp = pn / (d["prompt_eval_duration"] / 1e9)
tg = gn / (d["eval_duration"] / 1e9)
print("| %.1f s | %d | %.1f | %d | %.1f |" % (load, pn, pp, gn, tg))'
}

for ctx in $CTXS; do
    log="$WORK/ollama-$ctx.log"
    OLLAMA_CONTEXT_LENGTH=$ctx ollama serve > "$log" 2>&1 &
    server_pid=$!
    until curl -s "http://$OLLAMA_HOST/api/version" >/dev/null; do sleep 1; done

    ollama pull "$MODEL" >/dev/null

    {
        echo "## OLLAMA_CONTEXT_LENGTH=$ctx"
        echo
        echo '```'
        grep -E 'msg="inference compute"|default_num_ctx' "$log" | sed 's/.*msg=/msg=/' || true
        echo '```'
        echo
        echo "| run | load | prompt tok | prefill tok/s | gen tok | decode tok/s |"
        echo "|---|---|---|---|---|---|"
        echo "| cold $(gen 'Reply with one short sentence: what is unified memory?')"
        echo "| warm $(gen 'Name three Apple GPU families in one line.')"
        echo
        echo '```'
        ollama ps
        grep -E 'KV buffer size|llama_kv_cache: size' "$log" || true
        memory_pressure | tail -1
        sysctl vm.swapusage
        echo '```'
        echo
    } >> "$out"

    ollama stop "$MODEL" >/dev/null 2>&1 || true
    stop_server
done

echo "wrote $out"
cat "$out"
