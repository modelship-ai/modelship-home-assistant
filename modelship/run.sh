#!/usr/bin/env bash
# Single-process launcher for the add-on: translate Home Assistant add-on options
# into modelship env vars and exec `mship start`. The OpenAI-compatible API is
# served on :8000 under /modelship/v1; STT/TTS/conversation are consumed by the
# Modelship Conversation HACS integration over that HTTP API (no Wyoming).
set -euo pipefail

# Read one key from the add-on options JSON; empty string if unset/missing.
read_opt() {
    python - "$1" <<'PY'
import json, os, sys
key = sys.argv[1]
path = "/data/options.json"
val = ""
if os.path.exists(path):
    with open(path) as f:
        val = json.load(f).get(key, "")
print("" if val is None else val)
PY
}

# --- Logging ------------------------------------------------------------------
LOG_LEVEL="$(read_opt log_level)"; LOG_LEVEL="${LOG_LEVEL:-info}"
export MSHIP_LOG_LEVEL="$(printf '%s' "$LOG_LEVEL" | tr '[:lower:]' '[:upper:]')"

# --- Cache root (weights + HF cache) -------------------------------------------
CACHE_DIR="$(read_opt cache_dir)"; CACHE_DIR="${CACHE_DIR:-/share/modelship}"
export HOME=/data MSHIP_CACHE_DIR="$CACHE_DIR"
mkdir -p "$CACHE_DIR"
# modelship >= 0.8 keeps the Hugging Face cache in huggingface/, not hf/.
[ -d "$CACHE_DIR/hf" ] && [ ! -e "$CACHE_DIR/huggingface" ] && mv "$CACHE_DIR/hf" "$CACHE_DIR/huggingface"

HF_TOKEN_OPT="$(read_opt hf_token)"; [ -n "$HF_TOKEN_OPT" ] && export HF_TOKEN="$HF_TOKEN_OPT"

# --- State store --------------------------------------------------------------
# memory:// (default) or redis://host:port/db. The start below rebuilds the cluster from the
# config, so memory:// is the right fit; redis:// also keeps /v1/responses conversations.
STATE_STORE="$(read_opt state_store)"
[ -n "$STATE_STORE" ] && export MSHIP_STATE_STORE="$STATE_STORE"
REDIS_PASSWORD_OPT="$(read_opt redis_password)"; [ -n "$REDIS_PASSWORD_OPT" ] && export MSHIP_REDIS_PASSWORD="$REDIS_PASSWORD_OPT"

# --- Config: custom models.yaml ------------------------------------------------
# Configs live in the user-visible addon_config mount (/config): a custom
# models.yaml is read from there by absolute or relative path.
CONFIG_FILE="$(read_opt config_file)"
if [ -z "$CONFIG_FILE" ]; then
    echo "[run] config_file is required: set it to a models.yaml in the add-on config folder" >&2
    exit 1
fi
case "$CONFIG_FILE" in
    /*) CONFIG_PATH="$CONFIG_FILE" ;;          # absolute
    *)  CONFIG_PATH="/config/$CONFIG_FILE" ;;  # relative to addon_config
esac
echo "[run] using custom config: $CONFIG_PATH"

# `mship start` always reconciles: the running cluster matches the config exactly, so
# editing models.yaml removes/replaces dropped deployments instead of leaving stale ones.
echo "[run] starting modelship (cache=${CACHE_DIR}, log=${MSHIP_LOG_LEVEL}, state=${MSHIP_STATE_STORE:-memory://})"

exec mship start --config "$CONFIG_PATH"
