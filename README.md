# iOS Accessibility Pro — website and free skill

Public repository. GitHub Pages serves this folder as the product website.

- `index.html`, `setup.html`, `privacy.html`, `terms.html` — the site (plain HTML/CSS, no build step)
- `skill/ios-dynamic-type/` — the free Dynamic Type skill (source)
- `downloads/ios-dynamic-type.zip` — what people download; rebuild with `./build-zip.sh`

The paid connector lives in the private `ios-a11y-mcp` repository. Nothing from the paid skill belongs here.

## Publish on GitHub Pages

Settings → Pages → Build and deployment → Deploy from a branch → `main`, folder `/ (root)`.

## Before launch, replace the placeholders

- `hello@example.com` (all pages)
- `https://ios-a11y-pro.fly.dev` (index.html pricing button, setup.html) — your server's address
- The price and trial length in `index.html` (must match Stripe)
- `[BRACKETED]` fields in `privacy.html` and `terms.html` (legal notice, SIRET, VAT, licence, withdrawal policy)

## License

Free skill: [choose, e.g. CC BY 4.0]. Font: Atkinson Hyperlegible Next, SIL Open Font License (`fonts/OFL.txt`).
