# Model wrapper (deprecated)

**Deprecated.** Use `ingress/` (PHP Unix-domain socket) instead.

`Modelfile` and `wrap.pl` remain only as fail-closed references and for the
legacy suite checks that tool-call syntax is denied and that a model is not
started by this bootstrap path.

Production proposal path:

```bash
php ingress/server.php
php ingress/client.php --file fixtures/braid_valid.txt
```

GGUF registration and constrained generation: see `ingress/README.md` and
`models/README.md`.
