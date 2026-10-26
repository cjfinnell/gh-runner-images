#!/bin/sh
# Builder loop for the memory-vault viewer (cjfinnell/homelab#124).
#
# Polls main of the vault repo every POLL_SECONDS. On a new commit: fresh
# single-branch clone (never mem/* branches), quartz build into
# /site/builds/<sha>, then an atomic /site/current symlink swap. Notes with
# unparseable frontmatter are skipped (logged) rather than failing the build. A
# failed build leaves the previous site up; the error goes to the logs.
#
# Required env (set by the chart):
#   VAULT_REPO     git URL over in-cluster Gitea SSH
#   GIT_SSH_COMMAND pins the deploy key and the Gitea host key
set -eu

REPO="${VAULT_REPO:?VAULT_REPO must be set}"
BRANCH="${VAULT_BRANCH:-main}"
POLL_SECONDS="${POLL_SECONDS:-300}"
KEEP_BUILDS="${KEEP_BUILDS:-3}"

SITE="${VAULT_SITE:-/site}"
SRC="$SITE/src"
BUILDS="$SITE/builds"
last=""

mkdir -p "$BUILDS"

while true; do
  if ! sha=$(git ls-remote "$REPO" "refs/heads/$BRANCH" | cut -f1); then
    echo "ls-remote failed; retrying in ${POLL_SECONDS}s"
    sleep "$POLL_SECONDS"
    continue
  fi

  if [ -n "$sha" ] && [ "$sha" != "$last" ]; then
    echo "new $BRANCH commit $sha; building"
    rm -rf "$SRC"
    if ! git clone --quiet --single-branch --branch "$BRANCH" "$REPO" "$SRC"; then
      echo "clone failed; keeping previous site"
      sleep "$POLL_SECONDS"
      continue
    fi

    node drop-bad-frontmatter.mjs "$SRC" || echo "frontmatter check failed; building anyway"

    out="$BUILDS/$sha"
    rm -rf "$out"
    # Not `npx quartz`: npx links this package into its cache and chmods the
    # bin, which fails under readOnlyRootFilesystem (EROFS).
    if node quartz/bootstrap-cli.mjs build -d "$SRC" -o "$out"; then
      # Swap current atomically: build the symlink elsewhere, rename over.
      ln -sfn "$out" "$SITE/current.next"
      mv -Tf "$SITE/current.next" "$SITE/current"
      last="$sha"
      # Keep only the newest builds.
      ls -1dt "$BUILDS"/*/ 2>/dev/null | tail -n "+$((KEEP_BUILDS + 1))" | xargs -r rm -rf
      echo "now serving $sha"
    else
      echo "build failed for $sha; keeping previous site"
      rm -rf "$out"
    fi
  fi

  sleep "$POLL_SECONDS"
done
