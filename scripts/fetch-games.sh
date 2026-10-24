#!/usr/bin/env bash
#
# Pull the games into games/<slug>/ so Firebase Hosting serves them at
# hallowedgains.com/games/<slug>/.
#
# The games live in the repos listed in games/sources.json, today just
# Hallowed-Gains-LLC/web-games. In each source repo, every top-level folder
# that has a game.json is a game, and the folder name is its slug. Those
# repos stay the source of truth; this site copies a snapshot of each one's
# branch at deploy time. Nothing fetched is committed here (see .gitignore).
#
# Usage:
#   scripts/fetch-games.sh             Fetch every game, then write
#                                      games/games.json (the menu's card list)
#                                      and games/versions.json (repo -> SHA).
#   scripts/fetch-games.sh --versions  Print the latest commit SHA of every
#                                      source's branch as JSON, fetching
#                                      nothing. The deploy workflow compares
#                                      this with the live versions.json to
#                                      decide whether to redeploy.
#
# Requires git and jq.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
games_dir="$repo_root/games"
sources="$games_dir/sources.json"

# One "repo<TAB>branch" line per source repo.
list_sources() {
  jq -r '.sources[] | [.repo, .branch] | @tsv' "$sources"
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
  while IFS=$'\t' read -r repo branch; do
    versions="$(jq --arg k "$repo" --arg v "$(remote_sha "$repo" "$branch")" '. + {($k): $v}' <<<"$versions")"
  done < <(list_sources)
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
  local versions='{}' cards='[]' checkout slug
  # Script-level (not local) so the EXIT trap can still see it after return.
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # Start clean so a game deleted from its repo disappears from the site.
  find "$games_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

  while IFS=$'\t' read -r repo branch; do
    checkout="$tmp/${repo//\//__}"
    echo "fetch-games: $repo@$branch"
    git clone --quiet --depth 1 --branch "$branch" "https://github.com/$repo.git" "$checkout"

    for manifest in "$checkout"/*/game.json; do
      [[ -e "$manifest" ]] || continue
      slug="$(basename "$(dirname "$manifest")")"

      # The slug becomes a URL and a folder name, and two sources must not
      # claim the same one.
      if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        echo "fetch-games: skipping '$slug' in $repo: folder names must be lowercase letters, digits and dashes" >&2
        continue
      fi
      if [[ -e "$games_dir/$slug" ]]; then
        echo "fetch-games: '$slug' exists in more than one source repo" >&2
        exit 1
      fi
      if ! jq -e '.title and .description' "$manifest" >/dev/null; then
        echo "fetch-games: $repo/$slug/game.json needs a title and a description" >&2
        exit 1
      fi

      echo "fetch-games:   $slug/ -> games/$slug/"
      # `git archive` copies only tracked files, so the clone's .git folder
      # and anything untracked never reach the site.
      mkdir -p "$games_dir/$slug"
      git -C "$checkout" archive "HEAD:$slug" | tar -x -C "$games_dir/$slug"
      warn_on_html_pages "$slug"

      cards="$(jq --arg slug "$slug" --slurpfile game "$manifest" '. + [{slug: $slug} + $game[0]]' <<<"$cards")"
    done

    versions="$(jq --arg k "$repo" --arg v "$(git -C "$checkout" rev-parse HEAD)" '. + {($k): $v}' <<<"$versions")"
  done < <(list_sources)

  jq '{games: sort_by(.title)}' <<<"$cards" >"$games_dir/games.json"
  echo "$versions" >"$games_dir/versions.json"
  echo "fetch-games: wrote games/games.json ($(jq '.games | length' "$games_dir/games.json") games) and games/versions.json"
}

case "${1:-}" in
  --versions) print_versions ;;
  "") fetch_all ;;
  *)
    echo "usage: $0 [--versions]" >&2
    exit 2
    ;;
esac
