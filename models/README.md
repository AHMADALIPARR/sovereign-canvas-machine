# Models (GGUF)

Local GGUF weights only. Registered through the ingress:

```json
{"op":"register_gguf","name":"snapkitty-merged.Q4_K_M.gguf","source":"/absolute/path/to/file.gguf"}
```

## Default model — Snapkitty/snapkitty-merged

| Property | Value |
|---|---|
| Repo | [Snapkitty/snapkitty-merged](https://huggingface.co/Snapkitty/snapkitty-merged) |
| File | `snapkitty-merged.Q4_K_M.gguf` (~2.71 GiB) |
| Format | GGUF v3, Q4_K_M |
| Params | 4.2B (Nemotron / Minitron merge) |
| SHA-256 | `4d959da2985affc363c02784307ac135a69e77768d8d5475c6f15bb99560c59f` |
| License | NVIDIA Community Model License |

Download **outside** the trust boundary, verify the hash, then register:

```bash
# fetch + SHA-256 check
./models/fetch_snapkitty_merged.sh

# with ingress already listening:
php ingress/server.php &
./models/fetch_snapkitty_merged.sh --register

# propose via the model (requires llama-cli / SCM_LLAMA_BIN)
php ingress/client.php --json '{"op":"generate","model":"snapkitty-merged.Q4_K_M.gguf"}'
```

Or with llama.cpp’s HF helper (still outside ingress):

```bash
llama-cli -hf Snapkitty/snapkitty-merged:Q4_K_M -c 4096
# then copy the cached GGUF into models/ and register via ingress
```

## Rules

- Name: `^[A-Za-z0-9._-]{1,128}\.gguf$`
- Source: absolute path to a regular file whose magic is `GGUF`
- Optional allow-list prefix: `SCM_GGUF_ALLOW_PREFIX=/trusted/dir`
- Optional size cap: `SCM_GGUF_MAX_BYTES` (default 8 GiB)
- **No HTTP download inside the ingress.** Fetch is a separate, auditable step.
- Inference (`op=generate`) requires `llama-cli` on `PATH` or `SCM_LLAMA_BIN`
- Fixed system prompt: `prompting/system_prompt.txt`
- Tool-call syntax is denied; output must contain one complete `SCM-CANVAS/1.0` … `END` record

This directory holds runtime state (registered weights). It is not part of the
source of truth for verification — the pipeline still decides.
