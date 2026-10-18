# Modelship — Home Assistant add-on

Run a fully local [modelship](https://github.com/modelship-ai/modelship) server in Home
Assistant. The add-on exposes modelship's OpenAI-compatible API on port `8000`,
serving whatever models you list in your own `models.yaml` — chat/LLM, embeddings,
speech-to-text, text-to-speech and image generation.

Any Home Assistant integration that speaks the OpenAI API can use it: point it at
`http://<add-on-host>:8000/modelship/v1` with any non-empty API key.

## What's inside

| Capability | modelship endpoint |
|---|---|
| Conversation LLM | `/modelship/v1/chat/completions`, `/modelship/v1/responses` |
| Speech-to-text | `/modelship/v1/audio/transcriptions` |
| Text-to-speech | `/modelship/v1/audio/speech` |

## Install

1. In Home Assistant: **Settings → Add-ons → Add-on store → ⋮ → Repositories**,
   add `https://github.com/modelship-ai/modelship-home-assistant`.
2. Install **Modelship**, then start it. First boot downloads models, so give it a
   few minutes (watch the add-on log).
3. See the add-on's **Documentation** tab for options and wiring Assist
   (`modelship/DOCS.md`).

## Supported architectures

`amd64` and `aarch64` (Raspberry Pi 4/5 and similar). On low-RAM boards, pick
smaller models in your `models.yaml`.

## Repository layout

- [`modelship/`](modelship/) — the add-on (Dockerfile, config, launcher, docs).
