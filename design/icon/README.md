# App icon sources

- `icon.png` is the 1024×1024 master used for the app icon.
- `pairpods-icon-v2-*` are the working files the master was made from.

Regenerate the sized PNGs and `favicon.ico` next to the master with:

    python3 scripts/generate_icons.py design/icon

(requires Pillow). The generated files are not tracked.
