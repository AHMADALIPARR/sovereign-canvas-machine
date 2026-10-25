# Braided causal hypergraph

`perl/SCM/HyperDAG.pm` builds the candidate diagram: one node per crossing or gate, continuity edges along each strand, and a hyperedge for each crossing. The semantic invariant is stored beside the diagram. Equivalent words share an invariant and not necessarily a diagram.

## Canonical XML tree

`canon_xml` serializes the diagram as a deterministic XML tree rooted at `<scm v="1">`, carrying intent, workspace, invariant, and the full diagram (nodes, hyperedges, continuity, anyons). Element order is construction order; attribute order is id first, then remaining keys sorted. The same diagram always serializes to the same bytes. The pipeline (`perl/SCM/Pipeline.pm`) verifies the tree from its own bytes before trusting it, runs the stylesheet `xslt/canonicalize.xsl` through `xsltproc` on it, and records the hashes of the tree and of the certificate xsltproc produced. If xsltproc is absent or fails, the proposal is rejected with `XSLT_FAIL`; no Perl re-implementation stands in for the stylesheet.

## Merkle DAG

Every element carries a leaf hash; every section carries the hash of its children's leaf hashes in order; the root commits to intent, workspace, invariant, and all four section hashes. Leaf preimage: the record's keys sorted, `k=v` pairs joined by `,` (array values comma-joined). Section hash: sha256 of the concatenation of child leaf hashes in order; an empty section hashes sha256 of the empty string. Root preimage: intent, workspace, invariant, nodes hash, hyperedges hash, continuity hash, anyons hash, joined by newline (which no field value can contain). The XML tree carries every hash, so the tree alone verifies: recompute each leaf from its non-hash attributes, fold each section, compare with the `<merkle>` root. `verify_xml_hashes` implements that check, and the suite proves a tampered attribute breaks the root.

## Braid anyons

In the BRAID workspace each strand is an anyon worldline in 2+1 dimensions and each crossing is a braiding event between the two anyons on the adjacent positions. Convention, the standard one: a positive generator (s1, s2) braids the left strand OVER the right strand; a negative generator (s1_inv, s2_inv) braids the right strand OVER the left. Each `<anyon>` records its trajectory: the crossings it participates in, its role (over/under) at each, and its partner. Equivalent words share an invariant and not necessarily a diagram or trajectories: the diagram is a witness, and the invariant is what the pipeline trusts.
