# HallowedGainsWebsite
Code for the website for HallowedGains.com

## Secret games (`/games`)

[hallowedgains.com/games](https://hallowedgains.com/games) is an unlisted menu
of little HTML games. Nothing links to it and it's marked `noindex`, so search
engines leave it alone, but anyone with the link can open it. It's unlisted,
not private.

The games themselves live in
**[Hallowed-Gains-LLC/web-games](https://github.com/Hallowed-Gains-LLC/web-games)**,
one folder per game, except Driftlight, which has its own repo
(**[Hallowed-Gains-LLC/DriftLight](https://github.com/Hallowed-Gains-LLC/DriftLight)**,
which also builds it as a phone app). The web-games README covers adding a
game and the rules games must follow. This repo only pulls them in:

- [`games/sources.json`](games/sources.json) lists the repos to pull games
  from, with the branch to use. A source is one of two kinds:
  - **A repo of games** (`web-games`): every top-level folder with a
    `game.json` is a game, served at `/games/<folder>/`. `"exclude"` lists
    folders to skip, such as a game that has moved to its own repo.
  - **A repo that is one game** (`DriftLight`): `"folder"` is the folder
    holding it (with its `game.json`) and `"slug"` the name it's served
    under, so DriftLight's `www/` is served at `/games/driftlight/`.
- [`scripts/fetch-games.sh`](scripts/fetch-games.sh) copies each game into
  `games/<folder>/`. It writes `games/games.json` (the menu's cards, built from
  the `game.json` files) and `games/versions.json` (the commit deployed from
  each source). All of these are gitignored.
- [`games/index.html`](games/index.html) is the menu. It renders
  `games.json`, so it never needs editing.

### How games go live

The deploy workflow (`.github/workflows/deploy.yml`) runs the fetch script
before every deploy. It also checks every 30 minutes whether any source repo
has new commits and redeploys if so. **Pushing to `web-games` or `DriftLight`
goes live here within about 30 minutes**, with no change needed in this repo. To ship it
sooner, run the workflow by hand from the Actions tab.

GitHub pauses scheduled workflows in a repo with no commits for 60 days. If
game updates stop showing up, check the Actions tab and re-enable it.

Lily's games used to be served at unicorngame.hallowedgains.com. That address
now forwards to `/games/lily/` with a Cloudflare redirect rule (Rules →
Redirect Rules), which keeps the rest of the path, so `/unicorn/` lands on
`/games/lily/unicorn/`. Its DNS record is a proxied placeholder; nothing
serves that hostname any more.

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
`games/sources.json`. Slugs must be unique across all sources: the deploy
fails if two sources serve the same one, so when a game moves repos, exclude
it from the old source in the same change that adds the new one.

### Running it locally

```sh
scripts/fetch-games.sh        # needs git and jq
python3 -m http.server        # then open http://localhost:8000/games/
```

A plain static server doesn't apply `firebase.json` (redirects, headers). To
test those, use the Firebase CLI's hosting emulator
(`firebase emulators:start --only hosting`).

## Apps' privacy policies (`/privacy`)

Early Bloom's section of [hallowedgains.com/privacy](https://hallowedgains.com/privacy#early-bloom)
(the privacy policy URL the stores have) isn't written here. It's written once,
in Early Bloom's own repo (`lib/content/privacy_policy.dart`, the text the app
shows), which publishes it as a web page at
[early-bloom.hallowedgains.com/privacy](https://early-bloom.hallowedgains.com/privacy)
whenever its web app deploys. This site copies it in when it deploys:

- [`policies/sources.json`](policies/sources.json) lists each app's policy:
  its id, the page here it goes in, and the URL to copy it from.
- [`scripts/fetch-policies.py`](scripts/fetch-policies.py) copies what's
  between `<!-- <id>-policy:start -->` and `<!-- <id>-policy:end -->` on that
  page to between the same markers in the page here, so it's plain HTML
  styled like the rest of the page and reads without JavaScript. It only
  allows plain tags (headings, paragraphs, lists, links, bold), and fails the
  deploy if a policy can't be fetched or has anything else, rather than
  publish the page without it. It writes `policies/versions.json` (a hash of
  each), which is gitignored.
- The committed `privacy.html` holds a placeholder between the markers. To
  see the real thing locally, run `python3 scripts/fetch-policies.py` (and
  don't commit the result).

Like the games, the deploy workflow checks every 30 minutes and redeploys
when a policy has changed, so **a change merged in Early Bloom is live here
within about half an hour** of its web app deploying. The rest of the privacy
page (the general sections, Idle Bible, A Simple Way to Pray) is still edited
here, and so is its "Last updated" date; Early Bloom's section carries its
own.

To add another app: publish its policy with those markers, add it to
`sources.json`, and put the markers in its `<section>` here.

## Google Analytics

Every page loads [`analytics.js`](analytics.js), which holds the GA4
measurement ID in one place (`MEASUREMENT_ID`). An empty ID turns analytics
off. Games get the same tag added to each of their pages at deploy by
`scripts/fetch-games.sh`, unless their `game.json` says `"analytics": false`.
Lily's games opt out because they're made for young children; COPPA and
Google's terms rule out analytics on child-directed pages.

It's set up for measurement only, matching `privacy.html`:

- Google signals and ad personalization are off, and ad consent is denied.
- The EEA, the UK and Switzerland default to no analytics cookies (Consent Mode).
- Browsers sending Global Privacy Control load nothing.
- Only hallowedgains.com is measured. Local copies and preview channels load
  nothing.

If you add a page, include `<script src="/analytics.js" async></script>` in
its `<head>`. If you change what's collected, update `privacy.html` too.
