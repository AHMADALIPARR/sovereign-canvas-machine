# Guest gate (deprecated)

**Deprecated.** Full-system QEMU is not the production isolation boundary.

`run-guest.sh` still refuses network and tool devices and does not boot a
guest. That behaviour is retained for the suite. For production isolation of
a local generator, see `sandbox/README.md` (bubblewrap / Firecracker with
`net=none`).

Proposal ingress is `ingress/` (Unix socket), not a VM console.
