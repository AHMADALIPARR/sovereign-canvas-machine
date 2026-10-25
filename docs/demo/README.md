# REPL demo assets

- `repl-demo.gif` — animated terminal capture of the Read–Eval–Print loop
- Regenerate:

```bash
# from repo root (needs ImageMagick convert)
mkdir -p docs/demo/frames
# … write frame_*.txt then:
convert docs/demo/frames/frame_*.png -resize 560x -delay 120 -loop 0 -layers Optimize docs/demo/repl-demo.gif
```

The GIF is referenced from the top-level README.
