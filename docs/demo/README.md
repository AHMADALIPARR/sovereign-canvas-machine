# Demo assets (from real runs)

| File | What |
|---|---|
| `pipeline-live.png` | Full stage poster with live hashes from `braid_relation` |
| `pipeline-demo.gif` | Accept / deny / three-workspace panels |
| `repl-demo.gif` | REPL command walkthrough |

Regenerate after a local accept:

```bash
SCM_TRACE=1 perl perl/scm_supervisor.pl < fixtures/braid_relation.txt
# then rebuild posters with ImageMagick from docs/demo/pipeline_frames/
```

These binaries must be committed with git from a machine that can push blobs:

```bash
git add docs/demo/*.png docs/demo/*.gif
git commit -m "Add live pipeline demo media"
```
