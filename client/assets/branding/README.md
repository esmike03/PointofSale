# App branding

`app_icon.png` is the source image for the Android home-screen (launcher) icon.
`login_mascot.png` is the transparent pixel-art chick used on the sign-in screen.

## Change the app icon

1. Replace `app_icon.png` with your logo — a **square PNG**, ideally **1024×1024**.
   Keep the important part centered; Android's adaptive icon crops the edges to a
   circle/rounded-square on newer phones.
2. From the `client/` folder, run:

   ```
   dart run flutter_launcher_icons
   ```

3. Rebuild and reinstall the app (`flutter run`, or `flutter build apk`). The icon
   won't change on hot reload/restart — Android only picks up a new launcher icon
   on a fresh install.

Configuration lives under `flutter_launcher_icons:` in `../../pubspec.yaml`
(adaptive background colour, min SDK, etc.).

Both current images are official Chirpy POS artwork.
