# Guest gate

`guest.conf` requires `net=none` and `tools=disabled`. `run-guest.sh` rejects hostfwd, smb, virtfs, and net arguments, then refuses to boot. It does not launch QEMU.
