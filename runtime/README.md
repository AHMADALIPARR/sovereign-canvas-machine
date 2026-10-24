# Resource bounds

Records are at most 512 bytes per line and 4096 bytes total. Braids are at most 12 generators. Circuits have at most 4 qubits and 32 gates. Recurrence order is 1..6, the index is at most 30, and every intermediate value must stay inside ±1e9. Cycles are 1..100000 and memory is 1..1048576. Both decoders enforce these limits.
