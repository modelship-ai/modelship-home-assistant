# Modelship

Run a local [modelship](https://github.com/modelship-ai/modelship) server on your Home
Assistant box. It exposes an OpenAI-compatible API on port `8000` serving the
models you select (chat/LLM, embeddings, speech-to-text, text-to-speech, image
generation).

Any Home Assistant integration that speaks the OpenAI API can use it (see
[Connecting Home Assistant](#connecting-home-assistant)).

## How it works

The add-on runs a single modelship server, serving whatever models you list in
your own `models.yaml` (set via `config_file`).

## Configuration

| Option | Default | Description |
|---|---|---|
| `config_file` | _(unset, required)_ | Your `models.yaml`. Relative names resolve under the add-on config folder (e.g. `models.yaml`); absolute paths are used as-is. |
| `log_level` | `info` | `trace`/`debug` log full detail; `info` is normal. |
| `state_store` | `memory://` | Where modelship keeps its deployment state and stored `/v1/responses` conversations. `memory://` (default) keeps nothing across a restart — the start rebuilds the cluster from your config. Use `redis://host:6379/0` (or `rediss://` for TLS) to keep them. |
| `redis_password` | _(unset)_ | Password for a `redis://` `state_store`. It cannot go in the URI. |
| `cache_dir` | `/share/modelship` | Durable root for model weights (the Hugging Face cache lives in `<cache_dir>/huggingface`). Lives under `/share` so it's reachable from the Samba/File-editor add-ons and can be cleared. |
| `hf_token` | _(unset)_ | Hugging Face token, only needed for gated models. |

The add-on **reconciles** on every start: the running models are made to match your
`models.yaml` exactly, so editing the config removes or replaces the old
deployments instead of leaving stale ones running.

### Choosing models

The add-on runs modelship's CPU image, so use the loaders that run on CPU:
`llama_server` (GGUF chat/embeddings), `whispercpp` (speech-to-text), `sherpa_onnx`
(text-to-speech), `stable_diffusion_cpp` (images) and `vllm` with a quantized
(AWQ/GPTQ) model. GGUF does not work on the `vllm` loader.

Start from the low-resource stack in
[`mini-pc.yaml`](https://github.com/modelship-ai/modelship/blob/main/config/examples/mini-pc.yaml)
(llama-server chat + Kokoro TTS + whisper.cpp STT), or pick other examples from
[`config/examples/`](https://github.com/modelship-ai/modelship/tree/main/config/examples).
The full `models.yaml` reference is in modelship's
[model configuration docs](https://github.com/modelship-ai/modelship/blob/main/docs/model-configuration.md).

The API is served at `http://<add-on-host>:8000/modelship/v1`, and
`/modelship/health` answers once the gateway is up, before the models have loaded.

### Files you can see and edit

- **Configs** live in this add-on's config folder (the `addon_config` mount). Put
  your `models.yaml` there and set `config_file: models.yaml`.
- **Weights / cache** live under `cache_dir` (default `/share/modelship`),
  accessible via the Samba share or File editor add-ons. Delete the folder to reclaim
  disk; it re-downloads on next start.

## Connecting Home Assistant

Point an OpenAI-compatible integration at the add-on:

- **Base URL:** `http://<add-on-host>:8000/modelship/v1`
- **API key:** any non-empty value (modelship doesn't check it)
- **Model:** the `name` of a model in your `models.yaml`

The chat, embeddings, speech-to-text, text-to-speech and image endpoints are all
under that base URL.

## Troubleshooting

- **Slow first start**: the first boot downloads models into `cache_dir`. Watch the
  log; subsequent starts reuse the cache.
- **No models served / startup error**: check the modelship log for a `models.yaml`
  error.
- **Out-of-memory / killed**: run on hardware with more memory, or pick smaller
  models in `models.yaml`.
