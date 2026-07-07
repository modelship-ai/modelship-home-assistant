#!/usr/bin/env bash
# Single-process launcher for the add-on: translate Home Assistant add-on options
# into modelship env vars and exec mship_deploy.py. The OpenAI-compatible API is
# served on :8000; STT/TTS/conversation are consumed by the Modelship Conversation
# HACS integration over that HTTP API (no Wyoming).
set -euo pipefail

MSHIP_PY=/.venv/bin/python          # modelship's interpreter (always present)

# Read one key from the add-on options JSON; empty string if unset/missing.
read_opt() {
    "$MSHIP_PY" - "$1" <<'PY'
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

# --- Cache root (weights + HF cache + default state) --------------------------
# One user-accessible durable root. State nests under it by default (see below).
CACHE_DIR="$(read_opt cache_dir)"; CACHE_DIR="${CACHE_DIR:-/share/modelship}"
export HOME=/data MSHIP_CACHE_DIR="$CACHE_DIR" HF_HOME="$CACHE_DIR/hf"
mkdir -p "$CACHE_DIR" "$CACHE_DIR/hf"

HF_TOKEN_OPT="$(read_opt hf_token)"; [ -n "$HF_TOKEN_OPT" ] && export HF_TOKEN="$HF_TOKEN_OPT"

# --- State store --------------------------------------------------------------
# Default "memory://" → modelship keeps no durable state; the reconcile on every
# start (below) rebuilds the cluster from the config, so a fresh in-memory store
# is the right fit. Override with file:// (state under $MSHIP_CACHE_DIR/state),
# file:///path, or redis://…
STATE_STORE="$(read_opt state_store)"
[ -n "$STATE_STORE" ] && export MSHIP_STATE_STORE="$STATE_STORE"

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

# Reconcile every deploy so the running cluster matches the config exactly: editing
# models.yaml removes/replaces dropped deployments instead of leaving stale ones
# behind (additive, the default, would only ever add).
echo "[run] starting modelship (cache=${CACHE_DIR}, log=${MSHIP_LOG_LEVEL}, state=${MSHIP_STATE_STORE:-memory://})"

cd /modelship
exec uv run --no-sync mship_deploy.py --config "$CONFIG_PATH" --reconcile
