# HallowedGainsWebsite
Code for the website for HallowedGains.com

## Secret games (`/games`)

[hallowedgains.com/games](https://hallowedgains.com/games) is an unlisted menu
of little HTML games. Nothing links to it and it's marked `noindex`, so search
engines leave it alone, but anyone with the link can open it. It's unlisted,
not private.

Each game lives in **its own public GitHub repo** and stays the source of
truth. This repo only lists them:

- [`games/games.json`](games/games.json) is the manifest. Each entry has a
  `slug` (its URL, `/games/<slug>/`), `title`, `description`, an `icon` (a
  path inside the game's repo) or an `emoji`, the `repo` and the `branch`.
- [`games/index.html`](games/index.html) is the menu. It builds its cards
  from the manifest, so it never needs editing.
- [`scripts/fetch-games.sh`](scripts/fetch-games.sh) copies each game's
  branch into `games/<slug>/` (gitignored) and records the commits in
  `games/versions.json`.

### How games go live

The deploy workflow (`.github/workflows/deploy.yml`) runs the fetch script
before every deploy. It also checks every 30 minutes whether any game repo
has new commits and redeploys if so. **Pushing to a game's repo goes live
here within about 30 minutes**, with no change needed in this repo. To ship it
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

1. Add an entry to `games/games.json` and merge it. That's all.
2. The game must work from a sub-folder: use relative links (`img/x.png`,
   not `/img/x.png`).
3. Extra pages must be folders (`level-2/index.html`, linked as `level-2/`),
   not loose `level-2.html` files. The site's clean URLs plus the trailing
   slash that game folders need would 404 a loose file. The fetch script
   prints a warning in the deploy log if it finds one.
4. Saves in `localStorage` are shared by every game on hallowedgains.com, so
   prefix keys per game (Lily's games already do: `uq_*`, `wmh_*`).
5. The repo must be public, or the workflow will need a token to clone it.

### Running it locally

```sh
scripts/fetch-games.sh        # needs git and jq
python3 -m http.server        # then open http://localhost:8000/games/
```

A plain static server doesn't apply `firebase.json` (redirects, headers). To
test those, use the Firebase CLI's hosting emulator
(`firebase emulators:start --only hosting`).
