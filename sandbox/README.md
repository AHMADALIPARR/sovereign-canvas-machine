# Sandbox profile (optional local generator)

When a GGUF generator runs on the same host, wrap `llama-cli` with OS
isolation. SCM itself does not require this: external proposers may only talk
to the Unix socket.

## bubblewrap example

```bash
bwrap --ro-bind /usr /usr --ro-bind /lib /lib --ro-bind /lib64 /lib64 \
  --ro-bind /bin /bin --ro-bind "$SCM_ROOT/models" /models \
  --ro-bind "$SCM_ROOT/prompting" /prompting \
  --tmpfs /tmp --proc /proc --dev /dev \
  --unshare-net --die-with-parent \
  "$SCM_LLAMA_BIN" -m /models/my-model.gguf --temp 0 -n 256 ...
```

`net=none` equivalent: `--unshare-net`. No virtfs, no hostfwd. Tools stay
disabled by never mounting a writable project tree into the sandbox.

Firecracker / Cloud Hypervisor can replace bwrap for stronger isolation; keep
the same contract: no network, no tool devices, read-only model weights.
