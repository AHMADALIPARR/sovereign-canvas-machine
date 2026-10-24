# Native recomputation

`scm_rt.c` is a second implementation of the braid, Clifford, and recurrence invariants, in the C subset CompCert accepts (no VLAs, no setjmp). The bootstrap compiler is `gcc -std=c99 -Wall -Werror`. That is not a CompCert proof. A proposal is accepted only when this binary reprints the Perl invariant.
