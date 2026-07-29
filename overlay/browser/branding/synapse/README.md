# Synapse branding overlay

This directory mirrors `browser/branding/<channel>` in the Gecko source tree.
All visible art, names, colors, and service placeholders are Synapse-owned.

Generate the binary asset matrix from the transparent master:

```powershell
python scripts/generate_assets.py
```

The generator reads `assets/branding/synapse-logo.png` from the Synapse
repository root, writes deterministic Windows/Linux/macOS icon resources, and
records hashes and dimensions in `ASSET-MANIFEST.json`.

Names such as `firefox.ico`, `firefox-wordmark.svg`, and the
`FirefoxBranding()` template call are retained only because Gecko's build
scripts require those internal identifiers. Their contents identify Synapse.

The `.invalid` installer URLs are intentional fail-closed placeholders. Replace
them only when signed Synapse distribution infrastructure exists.

macOS note: the icon resources are present, but `Assets.car` must be compiled
from a Synapse asset catalog on macOS before producing a distributable `.app`.
