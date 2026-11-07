# Open Play PWA acceptance checks

Run these checks against a deployed non-production preview. A successful build verifies the implementation compiles; it does not prove that browser installation works on a real device.

## iPhone and iPad (Safari)

- Open the preview URL in Safari.
- Open **Share** and choose **Add to Home Screen**.
- Confirm the app name is **Open Play** and the orange OP icon is shown.
- Launch the home-screen icon and confirm the site opens in standalone mode.
- Check the dark status bar treatment and that content respects the device safe areas.
- Navigate to sign-in and Player Hub while online; confirm account pages still load normally.

## Android (Chrome)

- Open the preview URL in Chrome.
- Use the browser's **Install app** action when offered.
- Confirm the name and 192px/512px icon are correct.
- Launch the installed app and confirm standalone display.
- Check that normal sign-in and Supabase-backed pages still work online.

## Desktop (Chrome or Edge)

- Open the preview URL and use the browser's install action.
- Confirm the installed app opens in its own window and uses the Open Play icon.

## Cache and privacy checks

- Visit the public home page once while online, then go offline and reload the root route. The cached public shell should appear.
- While online, visit the sign-in, Player Hub and Admin routes; these private or account-specific routes must not be cached as offline HTML.
- Inspect Cache Storage and confirm it contains only the public root shell and static assets.
- Confirm requests to Supabase Auth, REST and Functions endpoints are not stored in Cache Storage.
- Confirm that offline access does not imply offline account, team, fixture or payment actions.

## Update behaviour

- Change the service-worker cache version when the shell strategy changes.
- Deploy a new preview and confirm the old open-play-shell cache is removed on activation.
- Confirm the new logo and manifest icons are served with the expected dimensions.

**Release gate:** mark PWA acceptance complete only after the iOS/iPadOS and Android/desktop checks have been performed on real devices. The automated tests do not replace these browser checks.
