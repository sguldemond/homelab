# web

The blog / site at `readme.stansyfert.com`, built with [Hugo](https://gohugo.io)
and the [PaperModX](https://github.com/reorx/hugo-PaperModX) theme.

## Local preview

```sh
cd web
hugo server -D --renderToMemory     # http://localhost:1313
```

`--renderToMemory` matters: without it the dev server serves whatever is on
disk in `public/`, so a plain `hugo` build run alongside it leaves you clicking
absolute `https://readme.stansyfert.com/...` links instead of localhost.

Build the static site into `web/public` (do this with the server stopped):

```sh
hugo
```

Hugo (extended) is installed at `~/.local/bin/hugo`. To get it elsewhere:

```sh
curl -sSL https://github.com/gohugoio/hugo/releases/download/v0.164.0/hugo_extended_0.164.0_linux-amd64.tar.gz \
  | tar xz -C ~/.local/bin hugo
```

## Layout

- `content/posts/` — blog posts (front matter: `title`, `date`, `tags`)
- `content/homelab.md`, `content/journal.md` — standalone pages
- `static/images/` — images, referenced as `/images/foo.png`
- `static/CNAME` — GitHub Pages custom domain
- `layouts/` — local overrides of theme templates (see notes in each file;
  PaperModX is a bit behind current Hugo and needs a few patches)
- `themes/PaperModX` — git submodule; clone with `git submodule update --init`

## Logo & favicons

The goblin logo lives in `assets/images/goblin-logo.png` (source of truth,
512x512). Hugo resizes it for the header and the home page.

The favicons in `static/` are pre-generated. If the logo changes, regenerate
them from `web/`:

```sh
uv run --with pillow python - <<'PY'
from PIL import Image
src = Image.open("assets/images/goblin-logo.png").convert("RGBA")
src.save("static/favicon.ico", sizes=[(16,16),(32,32),(48,48)])
for size, name in [(16,"favicon-16x16.png"),(32,"favicon-32x32.png"),
                   (180,"apple-touch-icon.png"),(512,"images/goblin-logo.png")]:
    src.resize((size,size), Image.LANCZOS).save(f"static/{name}")
PY
```

`static/images/goblin-logo.png` is the link-preview (og:image) copy.

## New post

```sh
hugo new content posts/my-post.md
```
