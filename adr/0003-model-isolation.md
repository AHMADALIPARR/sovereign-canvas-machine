# ADR 0003 — Model isolation

A model may submit one canvas record. It has no tool call, no shell, and
no path that escapes the fixture root. The QEMU wrapper refuses network
and tool devices and does not boot a guest. The Ollama wrapper refuses
tool-call syntax and does not start a model. Untrusted bytes are never
interpolated into a shell command. Child processes are exec'd from
argument vectors.
