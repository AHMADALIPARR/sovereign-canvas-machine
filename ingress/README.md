# Ingress — Unix-domain socket proposal gate

Production entry point for Sovereign Canvas Machine. Replaces the refuse-only
Ollama wrapper. A client sends **one** proposal; the server returns one
accept/reject line and (on accept) appends a ledger record. There is no agent
loop, no tool protocol, and no shell interpolation.

## Protocols

### Raw text

Body is a complete `SCM-CANVAS/1.0` record (same as fixtures). Terminated by
client close or by a line containing only `.` after `END`.

### JSON

```json
{"op":"propose","format":"canvas","body":"SCM-CANVAS/1.0\nINTENT ...\nEND\n"}
```

```json
{"op":"propose","format":"canvas","path":"fixtures/braid_valid.txt"}
```

`path` must be relative to the repo root, must not contain `..`, and must not
be absolute. Absolute paths and `..` are rejected.

### GGUF generate (optional local model)

Default weights: **[Snapkitty/snapkitty-merged](https://huggingface.co/Snapkitty/snapkitty-merged)**
(`snapkitty-merged.Q4_K_M.gguf`). Fetch with `models/fetch_snapkitty_merged.sh`, then:

```json
{"op":"generate","model":"snapkitty-merged.Q4_K_M.gguf","prompt":"optional extra hint"}
```

Requires `llama-cli` (or `SCM_LLAMA_BIN`) and a registered GGUF under
`models/`. The model is forced through `prompting/system_prompt.txt`, temperature
0, and a hard output budget. The first complete canvas record in the output is
extracted and passed to the same pipeline as a direct propose. Tool-call
syntax in model output is denied before decode.

### Register GGUF

```json
{"op":"register_gguf","name":"my-model.gguf","source":"/absolute/path/to/file.gguf"}
```

Copies (or hard-links when possible) a `.gguf` file into `models/`. Name must
match `^[A-Za-z0-9._-]{1,128}\.gguf$`. Source must be a regular file readable
by the server user. No remote download — upload is local path only.

### Health / list

```json
{"op":"ping"}
{"op":"list_models"}
```

## Socket

Default path: `$SCM_ROOT/run/scm.sock` (override with `SCM_SOCK`). Falls back
to `/tmp/scm-<uid>.sock` when needed.

```bash
# start
php ingress/server.php

# raw propose
printf '%s' "$(cat fixtures/braid_valid.txt)" | php ingress/client.php --raw

# JSON propose
php ingress/client.php --json '{"op":"propose","format":"canvas","path":"fixtures/braid_valid.txt"}'

# default model: fetch, register, generate
./models/fetch_snapkitty_merged.sh --register
php ingress/client.php --json '{"op":"generate","model":"snapkitty-merged.Q4_K_M.gguf"}'
```

## Security bounds (deny by default)

- Max request body: 64 KiB
- Canvas record: still ≤ 4096 bytes (decoder)
- Socket is filesystem-local; set directory mode `0700`
- Child processes started with argument vectors only (no shell)
- GGUF inference: no network flags, no tool grammar, fixed system prompt
- STATUS other than `UNVERIFIED` still rejected by the pipeline

## Response shape

Plain text line (same as the supervisor):

```
ACCEPT: AUTHORIZED
REJECT: POLICY:no_trusted_equivalence
REJECT: INGRESS:bad_json
REJECT: GGUF:no_llama
REJECT: GGUF:tool_syntax
```

JSON mode wraps that in `{"ok":true|false,"line":"...","trace":[...]}` when
the client sends `"reply":"json"`.
