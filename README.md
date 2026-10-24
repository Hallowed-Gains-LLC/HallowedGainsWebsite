# HallowedGainsWebsite
Code for the website for HallowedGains.com

## Secret games (`/games`)

[hallowedgains.com/games](https://hallowedgains.com/games) is an unlisted menu
of little HTML games. Nothing links to it and it's marked `noindex`, so search
engines leave it alone, but anyone with the link can open it. It's unlisted,
not private.

The games themselves live in
**[Hallowed-Gains-LLC/web-games](https://github.com/Hallowed-Gains-LLC/web-games)**,
one folder per game. Its README covers adding a game and the rules games must
follow. This repo only pulls them in:

- [`games/sources.json`](games/sources.json) lists the repos to pull games
  from, with the branch to use. Today that's just `web-games`. In each source,
  every top-level folder with a `game.json` is a game, served at
  `/games/<folder>/`.
- [`scripts/fetch-games.sh`](scripts/fetch-games.sh) copies each game into
  `games/<folder>/`. It writes `games/games.json` (the menu's cards, built from
  the `game.json` files) and `games/versions.json` (the commit deployed from
  each source). All of these are gitignored.
- [`games/index.html`](games/index.html) is the menu. It renders
  `games.json`, so it never needs editing.

### How games go live

The deploy workflow (`.github/workflows/deploy.yml`) runs the fetch script
before every deploy. It also checks every 30 minutes whether any source repo
has new commits and redeploys if so. **Pushing to `web-games` goes live here
within about 30 minutes**, with no change needed in this repo. To ship it
sooner, run the workflow by hand from the Actions tab.

GitHub pauses scheduled workflows in a repo with no commits for 60 days. If
game updates stop showing up, check the Actions tab and re-enable it.

Lily's games used to be served at unicorngame.hallowedgains.com. That address
now forwards to `/games/lily/`. GitHub Pages serves the redirect from the
`pages-redirect` branch of
[brandonadamprice/lily](https://github.com/brandonadamprice/lily/tree/pages-redirect).

### Trailing slashes (`firebase.json`)

Game folders need a trailing slash (`/games/lily/`), or their relative links
resolve one level up. With `cleanUrls` on, Firebase won't add that slash by
itself, and the old `"trailingSlash": false` actively stripped it. So that
setting is gone, replaced by two redirects:

- `^/games/…` paths whose last part has no `.` get a slash added.
- Top-level `/page/` loses its slash, the same as before (`/contact/` goes to
  `/contact`).

### Adding a game

Add a folder with a `game.json` to `web-games`, as its README describes. Nothing
changes here. To pull games from another repo too, add it to
`games/sources.json`. Folder names must be unique across all sources.

### Running it locally

```sh
scripts/fetch-games.sh        # needs git and jq
python3 -m http.server        # then open http://localhost:8000/games/
```

A plain static server doesn't apply `firebase.json` (redirects, headers). To
test those, use the Firebase CLI's hosting emulator
(`firebase emulators:start --only hosting`).
