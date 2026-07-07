# iOS Release Checklist — Debatly

Bundle ID: `com.aknsoftware.debatly`. Konto Apple Developer zaakceptowane 2026-07-07.
Kolejność sekcji = zalecana kolejność wykonywania. Sekcja 2 (umowy) blokuje działanie
subskrypcji, więc zrób ją najpierw — reszta może iść równolegle.

Uwaga: build i upload apki wymagają Maca z Xcode (sekcje 11–12). Wszystko wcześniejsze
(portale) da się wyklikać z dowolnej przeglądarki.

---

## 1. developer.apple.com — rejestracja App ID

- [ ] Wejdź na https://developer.apple.com → zaloguj się → kliknij **Account** (prawy górny róg)
- [ ] Kafelek **Certificates, Identifiers & Profiles** → w lewym menu **Identifiers**
- [ ] Kliknij niebieski **+** obok nagłówka "Identifiers"
- [ ] Zaznacz **App IDs** → Continue → typ **App** → Continue
- [ ] Description: `Debatly`; Bundle ID: zaznacz **Explicit** i wpisz `com.aknsoftware.debatly`
- [ ] Na liście Capabilities zaznacz **Sign in with Apple** (In-App Purchase jest włączone domyślnie dla każdego App ID)
- [ ] **Continue** → **Register**

Certyfikatów podpisywania NIE twórz ręcznie — Xcode z "Automatically manage signing" zrobi to sam (sekcja 11).

## 2. App Store Connect — umowy (ZRÓB OD RAZU, weryfikacja trwa)

- [ ] https://appstoreconnect.apple.com → zaloguj się
- [ ] Ze strony głównej wejdź w **Business** (dawna nazwa: Agreements, Tax, and Banking)
- [ ] Zaakceptuj **Paid Apps Agreement**
- [ ] Uzupełnij **Bank Account** (konto do wypłat)
- [ ] Uzupełnij **Tax Forms** — dla osoby z Polski formularz W-8BEN
- [ ] Status umowy musi być **Active**

⚠️ Bez aktywnej umowy Paid Apps produkty subskrypcyjne NIE będą się pobierać w apce — nawet w sandboxie. To najczęstsza przyczyna "pustego paywalla".

## 3. App Store Connect — utworzenie rekordu apki

- [ ] Strona główna → **Apps** → niebieski **+** → **New App**
- [ ] Platform: **iOS**
- [ ] Name: `Debatly` (nazwa musi być unikalna w całym App Store — jak zajęta, dodaj dopisek)
- [ ] Primary Language: np. Polish
- [ ] Bundle ID: wybierz z listy `com.aknsoftware.debatly` (pojawia się po sekcji 1)
- [ ] SKU: np. `debatly-ios` (wewnętrzny identyfikator, użytkownicy go nie widzą)
- [ ] User Access: Full Access → **Create**

## 4. App Store Connect — subskrypcje

- [ ] W apce: lewy sidebar → sekcja **Monetization** → **Subscriptions**
- [ ] **Create** przy Subscription Groups → Reference Name: np. `Premium` → Create
- [ ] W grupie kliknij **Create** (subskrypcja):
  - [ ] Reference Name: np. `Premium Monthly`
  - [ ] **Product ID**: np. `debatly_premium_monthly` — NIE DA SIĘ go potem zmienić; trzymaj ten sam schemat nazw co produkty Google Play w RevenueCat
- [ ] Subscription Duration: np. 1 Month
- [ ] **Subscription Prices** → **+** → wybierz cenę w kraju bazowym, Apple przeliczy pozostałe
- [ ] **Localization** (App Store Localization): nazwa + opis subskrypcji PL i EN
- [ ] **Review Information**: screenshot paywalla (min. 640×920, może być z symulatora) + krótka notatka
- [ ] Powtórz dla subskrypcji rocznej (jeśli jest na Androidzie)
- [ ] Zalecane: na stronie Subscriptions włącz **Billing Grace Period** (webhook RC już obsługuje BILLING_ISSUE grace)
- [ ] Każdy produkt musi dojść do statusu **Ready to Submit** (żółty "Missing Metadata" = czegoś brakuje)

Przy PIERWSZEJ publikacji subskrypcje dołącza się do review razem z wersją apki — w formularzu wersji jest sekcja "In-App Purchases and Subscriptions".

## 5. App Store Connect — klucz In-App Purchase (dla RevenueCat)

- [ ] Górne menu → **Users and Access** → zakładka **Integrations**
- [ ] Lewy panel → **In-App Purchase** → **Generate In-App Purchase Key**
- [ ] Name: `RevenueCat` → Generate
- [ ] **Download API Key** — plik `.p8` da się pobrać TYLKO RAZ; schowaj go bezpiecznie
- [ ] Zanotuj **Key ID** (przy kluczu) i **Issuer ID** (widoczny na zakładce App Store Connect API obok)

## 6. RevenueCat — dodanie apki iOS

- [ ] https://app.revenuecat.com → projekt Debatly → **Project settings → Apps** → **+ New app** → **App Store**
- [ ] App name: `Debatly iOS`; Bundle ID: `com.aknsoftware.debatly`
- [ ] Sekcja **In-App Purchase Key**: wgraj `.p8` + Key ID + Issuer ID (z sekcji 5) → Save
- [ ] Skopiuj **Public API Key** apki — zaczyna się od `appl_` → to jest wartość `REVENUECAT_API_KEY` dla buildów iOS
- [ ] **Product catalog → Products** → **+ New** → wybierz apkę App Store → wpisz Product ID dokładnie jak w App Store Connect
- [ ] **Entitlements** → otwórz istniejący entitlement premium → **Attach** produkty iOS
- [ ] **Offerings** → w bieżącym offeringu upewnij się, że packages mają podpięte produkty iOS obok Google
- [ ] Webhook RC → Supabase jest per-projekt (nie per-store) — nic nie zmieniasz

## 7. App Store Server Notifications → RevenueCat

- [ ] RevenueCat: Project settings → Apps → apka App Store → skopiuj **Apple Server Notification URL**
- [ ] App Store Connect: **Apps → Debatly → App Information** (sekcja General w sidebar) → scroll do **App Store Server Notifications**
- [ ] **Production Server URL**: wklej URL z RC; wybierz **Version 2 Notifications**
- [ ] **Sandbox Server URL**: ten sam URL, Version 2

## 8. AdMob — ad unit iOS

Apka iOS w AdMob już istnieje (app ID `ca-app-pub-7626099438648527~6955416427` siedzi w Info.plist).

- [ ] https://apps.admob.com → **Apps** → apka iOS Debatly
- [ ] **Ad units** → **Add ad unit** → **Rewarded** → nazwa np. `ios_rewarded_unlock` → Create
- [ ] Skopiuj ID ad unita (`ca-app-pub-…/…`) → to wartość `ADMOB_REWARDED_ID` dla buildów iOS
- [ ] Strona ad unita → **Advanced settings → Server-side verification** → wklej TEN SAM callback URL co w unicie androidowym (edge function `admob-ssv`)
- [ ] PO publikacji w App Store: App settings → **App store details** → podlinkuj listing App Store (wymagane do pełnego serwowania i weryfikacji app-ads.txt; plik na debatly.app już obejmuje oba systemy — jeden publisher ID)

## 9. Google Cloud Console — klient OAuth iOS (Google Sign-In)

- [ ] https://console.cloud.google.com → TEN SAM projekt co Android → **APIs & Services → Credentials**
- [ ] **+ Create credentials → OAuth client ID** → Application type: **iOS**
- [ ] Name: `Debatly iOS`; Bundle ID: `com.aknsoftware.debatly` (App Store ID i Team ID można dodać później) → Create
- [ ] Skopiuj **iOS URL scheme** (format `com.googleusercontent.apps.450651345001-xxxxx`)
- [ ] Podmień wpis w `ios/Runner/Info.plist` → `CFBundleURLSchemes` — OBECNY WPIS JEST BŁĘDNY (człony zamienione: hash-numer zamiast numer-hash), logowanie nie wróciłoby do apki
- [ ] Supabase Dashboard → **Authentication → Sign In / Up → Google** → do pola **Authorized Client IDs** dopisz po przecinku pełny iOS client ID (`450651345001-xxxxx.apps.googleusercontent.com`)
- [ ] `GOOGLE_SERVER_CLIENT_ID` (dart-define) zostaje bez zmian — to nadal web client ID

## 10. Sign in with Apple

Kod w apce już jest (`sign_in_with_apple`); Apple WYMAGA tego logowania, skoro jest Google (guideline 4.8).

- [ ] Capability na App ID włączona w sekcji 1 ✅
- [ ] Na Macu w Xcode: otwórz `ios/Runner.xcworkspace` → target **Runner** → **Signing & Capabilities** → **+ Capability** → **Sign in with Apple**
- [ ] Supabase Dashboard → **Authentication → Sign In / Up → Apple** → Enable
- [ ] W polu **Authorized Client IDs** wpisz `com.aknsoftware.debatly` (dla natywnego flow nie trzeba Services ID ani secretu — te są tylko do web OAuth)
- [ ] Sprawdź na urządzeniu/symulatorze, że przycisk Apple faktycznie renderuje się na iOS

## 11. Xcode — podpisywanie i build (Mac)

- [ ] Xcode → **Settings → Accounts** → **+** → zaloguj Apple ID konta developerskiego
- [ ] Otwórz `ios/Runner.xcworkspace` → target Runner → **Signing & Capabilities**
- [ ] Team: wybierz swój team; **Automatically manage signing** ✓
- [ ] **+ Capability** → **In-App Purchase** (obok Sign in with Apple z sekcji 10)
- [ ] `flutter build ipa` z pełnym zestawem dart-define:
  `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY=appl_…` (iOS-owy!),
  `ADMOB_REWARDED_ID` (iOS-owy unit z sekcji 8), `GOOGLE_SERVER_CLIENT_ID`, `SENTRY_DSN`
- [ ] Upload: Xcode → Window → **Organizer** → Distribute App → App Store Connect
  (alternatywnie: aplikacja **Transporter** + plik `.ipa`)

## 12. Testowanie — sandbox + TestFlight

- [ ] App Store Connect → **Users and Access** → zakładka **Sandbox** → **Testers** → **+** → utwórz konto testowe (email, który NIE jest istniejącym Apple ID; alias działa)
- [ ] Na iPhonie: Ustawienia → App Store → sekcja **Sandbox Account** → zaloguj testera
- [ ] TestFlight: App Store Connect → Apps → Debatly → TestFlight → dodaj siebie jako internal testera
- [ ] Kup subskrypcję sandboxowo → premium zapala się w apce; sprawdź `entitlement_sources` / sync w Supabase (eventy sandbox przyjdą przez RC)
- [ ] Rewarded ad (na test unicie), Google sign-in, Apple sign-in, **Restore purchases**
- [ ] Usuwanie konta (Apple review to sprawdza)

## 13. Fiszka App Store — przed wysłaniem do review

- [ ] Screenshoty 6.9"/6.7" (i starsze rozmiary jeśli wymagane) — jest `tool/export_app_screenshots.dart`
- [ ] **App Privacy** (nutrition labels): identyfikatory (IDFA — reklamy), email (konto), historia zakupów; **Tracking = Yes** (AdMob + ATT)
- [ ] Privacy Policy URL: https://debatly.app/privacy
- [ ] Auto-odnawialne subskrypcje: link do **Terms of Use (EULA)** w opisie apki albo w polu EULA — Apple to egzekwuje (https://debatly.app/terms)
- [ ] **App Review Information**: konto demo (email + hasło działającego konta) + notka, że darmowy user widzi 1 pytanie dziennie
- [ ] W formularzu wersji: sekcja **In-App Purchases and Subscriptions** → dołącz subskrypcje do pierwszego review
- [ ] Age rating, kategoria (np. Lifestyle / Social Networking), słowa kluczowe
