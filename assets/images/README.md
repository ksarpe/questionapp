## Files to provide

| File       | Size              | Background    | Used for                                    |
| ---------- | ----------------- | ------------- | ------------------------------------------- |
| `icon.png` | 1024×1024 square  | opaque (full) | App launcher icon (Android + iOS)           |
| `logo.png` | wordmark, trimmed | transparent   | In-app logo (splash + onboarding) and native splash |

Tips for converting from another format (SVG/JPG/etc.):
- `icon.png` — export a perfect square at 1024×1024. Keep the important part of
  the mark inside the centre ~66% (Android crops the adaptive icon to a circle
  / rounded square, so edges get clipped).
- `logo.png` — your wordmark on a **transparent** background, tightly trimmed
  (no extra padding). A height around 400–600px is plenty; it's scaled down.

## Generate the platform assets

```bash
dart run flutter_launcher_icons        # overwrites the default Flutter launcher icons
dart run flutter_native_splash:create  # writes the native splash for Android + iOS
```

Re-run these whenever you change `icon.png` / `logo.png`.
