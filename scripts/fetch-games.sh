#!/usr/bin/env bash
#
# Pull every game listed in games/games.json into games/<slug>/ so Firebase
# Hosting serves it at hallowedgains.com/games/<slug>/.
#
# Each game lives in its own (public) GitHub repo and stays the source of
# truth; this site only copies a snapshot of the configured branch at deploy
# time. The copied folders are gitignored, never committed here.
#
# Usage:
#   scripts/fetch-games.sh             Fetch all games and write
#                                      games/versions.json (slug -> commit SHA).
#   scripts/fetch-games.sh --versions  Print the latest commit SHA of every
#                                      game's branch as JSON, fetching nothing.
#                                      The deploy workflow compares this with
#                                      the live versions.json to decide whether
#                                      a redeploy is needed.
#
# Requires git and jq.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
games_dir="$repo_root/games"
manifest="$games_dir/games.json"

# Emit one "slug<TAB>repo<TAB>branch" line per game, rejecting any slug that
# isn't a plain folder name. The slug becomes a path we rm -rf, so this check
# is what keeps a typo in the manifest from deleting something else.
list_games() {
  jq -r '.games[] | [.slug, .repo, .branch] | @tsv' "$manifest" |
    while IFS=$'\t' read -r slug repo branch; do
      if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        echo "fetch-games: invalid slug '$slug' (use lowercase letters, digits and dashes)" >&2
        exit 1
      fi
      printf '%s\t%s\t%s\n' "$slug" "$repo" "$branch"
    done
}

# Latest commit SHA of a branch, without cloning.
remote_sha() {
  local repo="$1" branch="$2" sha
  sha="$(git ls-remote "https://github.com/$repo.git" "refs/heads/$branch" | cut -f1)"
  if [[ -z "$sha" ]]; then
    echo "fetch-games: branch '$branch' not found in $repo" >&2
    exit 1
  fi
  echo "$sha"
}

print_versions() {
  local versions='{}'
  while IFS=$'\t' read -r slug repo branch; do
    versions="$(jq --arg k "$slug" --arg v "$(remote_sha "$repo" "$branch")" '. + {($k): $v}' <<<"$versions")"
  done < <(list_games)
  echo "$versions"
}

# Game pages must be folders (level-2/index.html, linked as "level-2/"), not
# loose files like level-2.html. The site's cleanUrls setting turns
# /games/x/level-2.html into /games/x/level-2, and firebase.json then adds the
# trailing slash every game folder needs, which 404s for a loose file. Warn
# (without failing the deploy) so a new game's broken links are easy to spot.
warn_on_html_pages() {
  local slug="$1" page
  while IFS= read -r page; do
    echo "::warning::games/$slug/$page will 404 on the site; move it to ${page%.html}/index.html and link to it as a folder"
  done < <(cd "$games_dir/$slug" && find . -name '*.html' ! -name index.html | sed 's|^\./||')
}

fetch_all() {
  local versions='{}'
  # Script-level (not local) so the EXIT trap can still see it after return.
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  while IFS=$'\t' read -r slug repo branch; do
    echo "fetch-games: $repo@$branch -> games/$slug/"
    git clone --quiet --depth 1 --branch "$branch" "https://github.com/$repo.git" "$tmp/$slug"

    # `git archive` copies only tracked files, so the clone's .git folder
    # (and anything else untracked) never reaches the site.
    rm -rf "${games_dir:?}/$slug"
    mkdir -p "$games_dir/$slug"
    git -C "$tmp/$slug" archive HEAD | tar -x -C "$games_dir/$slug"

    warn_on_html_pages "$slug"
    versions="$(jq --arg k "$slug" --arg v "$(git -C "$tmp/$slug" rev-parse HEAD)" '. + {($k): $v}' <<<"$versions")"
  done < <(list_games)

  echo "$versions" >"$games_dir/versions.json"
  echo "fetch-games: wrote games/versions.json"
}

case "${1:-}" in
  --versions) print_versions ;;
  "") fetch_all ;;
  *)
    echo "usage: $0 [--versions]" >&2
    exit 2
    ;;
esac
