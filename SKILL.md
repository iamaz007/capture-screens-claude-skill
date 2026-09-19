---
name: capture-screens
description: Capture store-ready screenshots of every screen of an app on Android phone, Android tablet, iPhone, iPad and macOS, after first filling the app with realistic data so no screen is empty. Drives emulators/simulators (adb, xcrun simctl, iOS Simulator tools, macOS window capture), cleans the status bar, covers light/dark and localized variants, and saves full-resolution raw captures ready for the store-screenshots skill. Use when the user asks to "take screenshots of every screen/feature", "capture the app for the store", "screenshot the app on Android/iOS/iPad/tablet/Mac", or needs raw captures before designing store tiles.
---

# Capture screens

Raw captures are the material every store tile is built from. A tile can only be
as good as its capture: **an empty screen can never become a good screenshot.**
This skill drives the running app on each platform, fills it with realistic data,
and saves clean full-resolution captures of every feature.

Helper: `scripts/cap.sh` (run with no args for usage). Needs `adb`, Xcode
command-line tools, Python 3 with Pillow (`pip install pillow numpy`).

## Hard rules

1. **Data first, capture second.** Never save a capture of an empty state
   ("No activity yet", "0 streak", blank history, empty chat). Not even "to check".
   Look with a throwaway preview, not a saved file. Run `cap.sh empty shot.png`
   on every capture - it warns on mostly-blank screens.
2. **Realistic, varied, correct data.** Several subjects/categories, real-looking
   titles, sensible numbers. Verify AI outputs are correct before capturing them
   (a wrong answer in a store screenshot is worse than none). Mix content so
   History/Home lists show variety.
3. **Unlock features without paying.** Use the app's own test switch (dummy
   plans, sandbox, debug flag, dev build). Never make a real purchase, never
   enter credentials or payment details.
4. **Clean status bar on every platform** (`cap.sh clean android|ios`): 9:41, full
   battery, full signal, no notifications. Restore afterwards (`cap.sh unclean`).
5. **Tablets and iPads: capture in landscape.** Store tiles for tablets are landscape.
6. **Full resolution, native device.** Capture on a device of the target class
   (iPhone Pro Max sim for 6.9″, iPad Pro 13″ sim, a 1080-wide Android phone, a
   10″ Android tablet). Never upscale; never capture a phone layout for a tablet.
7. **Cover the variants the listing needs:** light + dark of the key screens, and
   one or more localized screens if the app is translated.
8. **Leave the device as you found it:** language back to the original, theme
   back, status bar restored. Tell the user if you couldn't.
9. **Report what you notice.** Bugs, untranslated strings, wrong AI answers,
   layout glitches seen while capturing go to the user as a short list - don't
   silently capture around them.

## Workflow

### 1. Understand the app
Read the routes/screens (router file, feature folders) to build a **screen list**:
every user-facing feature screen, its route, and what data it needs to look full.
Include Home, core feature(s) with a result, chat/assistant, history/library,
saved/favorites, settings/profile, paywall, onboarding - whatever the app has.

### 2. Get the app running on each platform
```bash
scripts/cap.sh devices
```
- Android: running emulator/device. Build with the dev/test flags needed
  (e.g. `flutter build apk --release --dart-define=USE_DUMMY_PLANS=true` then
  `adb install -r`). If install fails for space, build per-ABI (`--split-per-abi`).
- iOS/iPad: `flutter build ios --simulator` (or Xcode build), boot the sim, then
  install/launch (iOS Simulator tool `launch`, or `xcrun simctl install/launch`).
  Open the Simulator panel early so the user can watch.
- macOS: run the app (`flutter run -d macos` / the built .app); capture its window.

### 3. Fill with data (the important part)
Drive the UI like a user - never inject rows into a production database.
- Seed inputs: push sample photos/PDFs (`cap.sh push`, `cap.sh files ios`) with
  realistic content across subjects (generate simple images with Pillow if needed).
- Use each core feature 3-5 times with different content so lists are full.
- Wait for AI/network results before moving on; check each result is correct.
- Type reliably: `cap.sh type ios "…"` (iOS keystrokes via System Events - direct
  simulator text injection drops characters); `cap.sh clear` before re-typing.
- Android taps: from `uiautomator dump` bounds (`adb shell uiautomator dump`),
  or coordinates scaled from a preview.
- iOS taps: the Simulator tool's tap in device points. **iPad landscape quirk:**
  tap coordinates stay in portrait points - for a landscape-view point (X, Y)
  tap `(Y, portraitHeight − X)` (1376 for iPad Pro 13″).
- Accept each app's permission prompts, or pre-grant
  (`xcrun simctl privacy booted grant photos <bundle-id>`).

### 4. Capture every screen
```bash
scripts/cap.sh clean android            # or ios
scripts/cap.sh shot android docs/screenshots/android/01_home.png
scripts/cap.sh shot ios     docs/screenshots/ios/01_home.png
scripts/cap.sh rotate ios right         # iPad → landscape
scripts/cap.sh shot ipad-land docs/screenshots/ipad/01_home.png
scripts/cap.sh shot mac docs/screenshots/macos/01_home.png "AppName"
scripts/cap.sh empty docs/screenshots/ios/01_home.png
```
- Name files `NN_screen[_variant].png` in flow order: `01_home`, `02_scan`,
  `03_answer`, `04_chat`, `05_quiz`, `06_results`, `07_flashcards`,
  `08_history`, `09_saved`, `10_profile`, `11_pro`, plus `_dark`, `_de`, etc.
- Scroll to the most informative part of a screen before capturing (e.g. steps
  of a solution, the filled list), not the top of an empty form.
- Look at each capture (`cap.sh preview`) - check it's the intended screen, has
  data, no keyboard/toast/overlay over the content, no debug text.
- Dark mode and languages: switch in the app's settings, capture Home + one or
  two key screens, then switch back.

### 5. Deliver
- Save under `docs/screenshots/<platform>/` (android, android-tablet, ios, ipad,
  macos), localized ones in a `localized/` subfolder as `<lang>_<screen>.png`.
- Summarise per platform: device and resolution, what data was added, which
  screens were captured, anything you couldn't capture, and the bugs/issues seen.
- Next step is usually the `store-screenshots` skill, which turns these captures
  into designed store tiles.

## Platform notes

| Platform | Device | Resolution | Capture |
|---|---|---|---|
| Android phone | emulator (Pixel) | 1080×2400 | `cap.sh shot android` |
| Android tablet | 10″ emulator, landscape | 2560×1600 | `cap.sh shot android` |
| iPhone 6.9″ | iPhone 17/16 Pro Max sim | 1320×2868 | `cap.sh shot ios` |
| iPad 13″ | iPad Pro 13″ sim, landscape | 2752×2064 | `cap.sh shot ipad-land` |
| macOS | app window | window px (Retina) | `cap.sh shot mac … "App"` |

- A Flutter app can pick a different layout on tablets/desktop - capture the
  tablet layout on a tablet device, not a stretched phone layout.
- Android demo mode survives app switches; `cap.sh unclean android` when done.
- iOS status bar override is per simulator; re-apply after reboots.
- If a simulator tap does nothing, check orientation mapping before retrying.
- If the device loses connection, stop and tell the user rather than guessing.
