// Shows Early Bloom's Google Play links once the app is actually on Google
// Play, and "coming soon" until then, so nobody lands on a dead link.
//
// early-bloom-status.json holds the switch. The "Early Bloom Play check"
// workflow (.github/workflows/early-bloom-play-check.yml) checks the Play
// store page every three hours and flips it to true (and redeploys) once the page
// works; nothing else needs to change.
//
// Markup: elements with data-play="live" start hidden (class "hidden") and
// are shown; elements with data-play="soon" are removed. Without the
// script, or if the file can't be read, the page stays on "coming soon".
fetch('/early-bloom-status.json', { cache: 'no-store' })
  .then((response) => (response.ok ? response.json() : null))
  .then((status) => {
    if (!status || status.onGooglePlay !== true) return;
    document.querySelectorAll('[data-play="soon"]').forEach((el) => el.remove());
    document.querySelectorAll('[data-play="live"]').forEach((el) => el.classList.remove('hidden'));
  })
  .catch(() => {});
