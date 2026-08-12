#!/usr/bin/env bash
# Drop-in replacement for `mkdocs gh-deploy`: builds the Hugo site in web/ and
# force-pushes it to the root of the gh-pages branch, which is what GitHub
# Pages already serves. No Pages settings change needed.
#
# Usage: scripts/deploy-site.sh [--dry-run]
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
SITE_DIR="$REPO_ROOT/web"
BRANCH="gh-pages"
REMOTE="origin"
WORKTREE="$(mktemp -d)"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

cleanup() {
  git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" 2>/dev/null || true
  rm -rf "$WORKTREE"
}
trap cleanup EXIT

command -v hugo >/dev/null || { echo "hugo not on PATH" >&2; exit 1; }

SHA="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
  echo "warning: working tree is dirty; deploying build of the current files, tagged $SHA" >&2
fi

echo "==> building site"
rm -rf "$SITE_DIR/public"
hugo --source "$SITE_DIR" --minify

echo "==> checking out $BRANCH into a temp worktree"
git -C "$REPO_ROOT" fetch "$REMOTE" "$BRANCH"
git -C "$REPO_ROOT" worktree add --force "$WORKTREE" "$REMOTE/$BRANCH" --detach

echo "==> replacing branch contents with build output"
find "$WORKTREE" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +
cp -a "$SITE_DIR/public/." "$WORKTREE/"
touch "$WORKTREE/.nojekyll"

git -C "$WORKTREE" add --all
if git -C "$WORKTREE" diff --cached --quiet; then
  echo "==> no changes to publish"
  exit 0
fi

git -C "$WORKTREE" commit -m "Deployed $SHA with Hugo $(hugo version | awk '{print $2}')"

if $DRY_RUN; then
  echo "==> dry run; not pushing. Commit built in $WORKTREE:"
  git -C "$WORKTREE" show --stat --oneline HEAD | head -20
  exit 0
fi

echo "==> pushing to $REMOTE/$BRANCH"
git -C "$WORKTREE" push "$REMOTE" "HEAD:$BRANCH"
echo "==> done: https://readme.stansyfert.com/"
