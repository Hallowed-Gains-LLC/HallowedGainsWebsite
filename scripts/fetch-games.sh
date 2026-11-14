#!/usr/bin/env bash
#
# Pull the games into games/<slug>/ so Firebase Hosting serves them at
# hallowedgains.com/games/<slug>/.
#
# The games live in the repos listed in games/sources.json. A source is one
# of two kinds:
#
#   A repo of games (web-games): every top-level folder that has a game.json
#   is a game, and the folder name is its slug. "exclude" lists folders to
#   skip, e.g. a game that has moved to its own repo.
#
#   A repo that is one game (DriftLight): "folder" names the folder holding
#   it (with its game.json) and "slug" the name it's served under.
#
# Those repos stay the source of truth; this site copies a snapshot of each
# one's branch at deploy time. Nothing fetched is committed here (see
# .gitignore).
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
# Private source repos (DriftLight) need a GitHub token in GAMES_REPO_TOKEN:
# a fine-grained personal access token with read-only "Contents" on those
# repos. The deploy workflow passes it from the repo secret of the same
# name; see the README. Public repos need nothing.
#
# Requires git and jq.

set -euo pipefail

# Fail rather than wait for a password nobody will type.
export GIT_TERMINAL_PROMPT=0

# git, logged in to github.com with GAMES_REPO_TOKEN if there is one. The
# token goes in a header for this one command only: it's never written to
# disk or into a URL that could end up in a log.
git_gh() {
  if [[ -n "${GAMES_REPO_TOKEN:-}" ]]; then
    local auth
    auth="$(printf 'x-access-token:%s' "$GAMES_REPO_TOKEN" | base64 -w0)"
    git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $auth" "$@"
  else
    git "$@"
  fi
}

# Say what to do when a repo can't be reached, the usual cause being a
# private repo and a missing or expired token.
unreachable() {
  echo "fetch-games: can't reach $1. If it's private, GAMES_REPO_TOKEN must be set and able to read it (see the README)." >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
games_dir="$repo_root/games"
sources="$games_dir/sources.json"

# One "repo<TAB>branch<TAB>folder<TAB>slug<TAB>exclude" line per source.
# Missing fields are "-", because `read` would merge empty tab-separated
# fields; exclude is comma-separated.
list_sources() {
  jq -r '.sources[] | [.repo, .branch, (.folder // "-"), (.slug // "-"), ((.exclude // []) | join(",") | if . == "" then "-" else . end)] | @tsv' "$sources"
}

# Latest commit SHA of a branch, without cloning.
remote_sha() {
  local repo="$1" branch="$2" sha
  sha="$(git_gh ls-remote "https://github.com/$repo.git" "refs/heads/$branch" | cut -f1)" || unreachable "$repo"
  if [[ -z "$sha" ]]; then
    echo "fetch-games: branch '$branch' not found in $repo" >&2
    exit 1
  fi
  echo "$sha"
}

print_versions() {
  local versions='{}'
  local sha
  while IFS=$'\t' read -r repo branch _; do
    # remote_sha's own `exit` only leaves the $(...) subshell, so pass its
    # failure on, or a repo it can't reach would quietly read as "".
    sha="$(remote_sha "$repo" "$branch")" || exit 1
    versions="$(jq --arg k "$repo" --arg v "$sha" '. + {($k): $v}' <<<"$versions")"
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

# Add the site's Google Analytics tag (/analytics.js) to every page of a game,
# just before </head>. Done here at deploy so the games themselves stay
# standalone. A game opts out with "analytics": false in its game.json, which
# any game made for young children must do (COPPA and Google's terms rule out
# analytics on child-directed pages).
add_analytics() {
  local slug="$1" page
  while IFS= read -r page; do
    grep -q 'src="/analytics.js"' "$page" && continue
    if ! grep -q '</head>' "$page"; then
      echo "::warning::${page#"$repo_root/"} has no </head>; analytics not added"
      continue
    fi
    # GNU sed: replace only the first </head>.
    sed -i '0,/<\/head>/s##<script src="/analytics.js" async></script>\n</head>#' "$page"
  done < <(cd "$games_dir/$slug" && find . -name '*.html' | sed "s|^\.|$games_dir/$slug|")
}

# Copy one game, the folder `dir` of the clone at `checkout`, to
# games/<slug>/, and add its card to `cards`.
add_game() {
  local repo="$1" checkout="$2" dir="$3" slug="$4" manifest="$2/$3/game.json"

  # The slug becomes a URL and a folder name, and two sources must not
  # claim the same one.
  if [[ ! "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "fetch-games: skipping '$slug' in $repo: slugs must be lowercase letters, digits and dashes" >&2
    return
  fi
  if [[ -e "$games_dir/$slug" ]]; then
    echo "fetch-games: '$slug' exists in more than one source repo (exclude it from one in games/sources.json)" >&2
    exit 1
  fi
  if [[ ! -e "$manifest" ]] || ! jq -e '.title and .description' "$manifest" >/dev/null; then
    echo "fetch-games: $repo/$dir/game.json is missing or needs a title and a description" >&2
    exit 1
  fi

  echo "fetch-games:   $dir/ -> games/$slug/"
  # `git archive` copies only tracked files, so the clone's .git folder
  # and anything untracked never reach the site.
  mkdir -p "$games_dir/$slug"
  git -C "$checkout" archive "HEAD:$dir" | tar -x -C "$games_dir/$slug"
  warn_on_html_pages "$slug"
  if [[ "$(jq -r '.analytics' "$manifest")" == "false" ]]; then
    echo "fetch-games:   (analytics off for $slug)"
  else
    add_analytics "$slug"
  fi

  cards="$(jq --arg slug "$slug" --slurpfile game "$manifest" '. + [{slug: $slug} + $game[0]]' <<<"$cards")"
}

fetch_all() {
  local versions='{}' checkout slug
  cards='[]'                    # script-level: add_game appends to it
  # Script-level (not local) so the EXIT trap can still see it after return.
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # Start clean so a game deleted from its repo disappears from the site.
  find "$games_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

  while IFS=$'\t' read -r repo branch folder one exclude; do
    checkout="$tmp/${repo//\//__}"
    echo "fetch-games: $repo@$branch"
    git_gh clone --quiet --depth 1 --branch "$branch" "https://github.com/$repo.git" "$checkout" || unreachable "$repo"

    if [[ "$folder" != "-" ]]; then
      # A repo that is one game.
      add_game "$repo" "$checkout" "$folder" "$one"
    else
      # A repo of games: every top-level folder with a game.json.
      for manifest in "$checkout"/*/game.json; do
        [[ -e "$manifest" ]] || continue
        slug="$(basename "$(dirname "$manifest")")"
        if [[ ",$exclude," == *",$slug,"* ]]; then
          echo "fetch-games:   (skipping $slug: excluded in games/sources.json)"
          continue
        fi
        add_game "$repo" "$checkout" "$slug" "$slug"
      done
    fi

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
