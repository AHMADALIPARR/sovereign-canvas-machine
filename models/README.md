# Models (GGUF)

Local GGUF weights only. Registered through the ingress:

```json
{"op":"register_gguf","name":"my-model.gguf","source":"/absolute/path/to/file.gguf"}
```

Rules:

- Name: `^[A-Za-z0-9._-]{1,128}\.gguf$`
- Source: absolute path to a regular file whose magic is `GGUF`
- Optional allow-list prefix: `SCM_GGUF_ALLOW_PREFIX=/trusted/dir`
- Optional size cap: `SCM_GGUF_MAX_BYTES` (default 8 GiB)
- No HTTP download. No remote URLs. Copy or hard-link into this directory only.

Inference (`op=generate`) requires `llama-cli` on `PATH` or `SCM_LLAMA_BIN`.
The fixed system prompt is `prompting/system_prompt.txt`. Tool-call syntax is
denied. Output must contain one complete `SCM-CANVAS/1.0` … `END` record.

This directory holds runtime state (registered weights). It is not part of the
source of truth for verification — the pipeline still decides.
