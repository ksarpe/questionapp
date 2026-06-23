# iOS home-screen widget — Xcode setup

The Swift/SwiftUI code, `Info.plist`, entitlements and the Anton font are already
in this folder. What can't be done from Windows is **adding the Widget Extension
target and the App Group** — those are Xcode capabilities. Do this once on a Mac.

Bundle id of the app: `com.aknsoftware.questionapp`
App Group used everywhere: `group.com.aknsoftware.questionapp`

## 1. Add the Widget Extension target

1. Open `ios/Runner.xcworkspace` in Xcode (the **workspace**, not the project).
2. **File ▸ New ▸ Target… ▸ Widget Extension**.
3. Product Name: **`DailyQuestionWidget`** (must match the folder + the `kind`
   string in `DailyQuestionWidget.swift`).
   - **Uncheck** "Include Configuration App Intent" / "Include Live Activity".
   - Language: Swift. Embed in: Runner.
4. When prompted "Activate scheme?", click **Activate**.

Xcode generates a `DailyQuestionWidget/` group with template files. **Delete the
generated `.swift`, `Info.plist`, `Assets.xcassets`** from the target (move to
trash) and instead **Add Files…** the ones already in this folder:
`DailyQuestionWidget.swift`, `DailyQuestionWidgetBundle.swift`, `Info.plist`,
`DailyQuestionWidget.entitlements`, `Anton-Regular.ttf`.
- For every added file: in the File Inspector, set **Target Membership =
  DailyQuestionWidget** (the font + plist + both swift files).

## 2. Point the target at our Info.plist + entitlements

In the **DailyQuestionWidget** target ▸ **Build Settings**:
- `INFOPLIST_FILE` → `DailyQuestionWidget/Info.plist`
- `GENERATE_INFOPLIST_FILE` → **No** (so our `UIAppFonts` entry is used)
- `CODE_SIGN_ENTITLEMENTS` → `DailyQuestionWidget/DailyQuestionWidget.entitlements`
- `IPHONEOS_DEPLOYMENT_TARGET` → **14.0** or higher (WidgetKit needs ≥ 14;
  iOS 17 gets the nicer `containerBackground`, handled in code).

## 3. App Group on BOTH targets

Select the project ▸ **Signing & Capabilities**:
- On **Runner**: **+ Capability ▸ App Groups**, then add
  `group.com.aknsoftware.questionapp`.
  (A `Runner.entitlements` already exists in `ios/Runner/` with this group — if
  Xcode created a fresh one, make sure it lists the same group, or set
  `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`.)
- On **DailyQuestionWidget**: **+ Capability ▸ App Groups**, add the **same**
  `group.com.aknsoftware.questionapp`.

Both must show the identical group — that shared container is how the app's
`HomeWidget.saveWidgetData(...)` reaches the widget's `UserDefaults(suiteName:)`.

> The App Group also has to exist on your Apple Developer account (Certificates,
> Identifiers & Profiles ▸ Identifiers ▸ App Groups) and be enabled on both App
> IDs. Xcode's automatic signing usually creates it for you.

## 4. Font

`Anton-Regular.ttf` must be a member of the **DailyQuestionWidget** target (step 1)
and is declared in this folder's `Info.plist` under `UIAppFonts`. The SwiftUI code
references it as `.font(.custom("Anton-Regular", size:))`. (The app target already
bundles the same font via `pubspec.yaml`; the extension needs its own copy.)

## 5. Build & verify

```sh
flutter pub get
cd ios && pod install && cd ..
flutter build ios            # or run the Runner scheme from Xcode on a device
```

Then on the device/simulator:
1. Run the app once (so it writes today's daily into the App Group).
2. Long-press the home screen ▸ **+** ▸ search **Debatly** ▸ add the widget.
3. It should show "PYTANIE DNIA" + today's question on a black card in the Anton
   font. Tapping it opens the app.
4. Switch the app language in Settings, reopen — the label follows (PL/EN).

## Notes / future

- Tap currently just opens the app (which lands on the daily). The widget passes
  `questionapp://daily` via `.widgetURL`; wire scene-based URL handling later if
  you want it to deep-link to a specific screen.
- No background network fetch by design: the widget re-renders the last value the
  app pushed and rolls the timeline at midnight. A true unattended daily refresh
  (BGTask) is the documented iteration-2 follow-up.
