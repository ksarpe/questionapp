# Plan releaseu — Debatly

Praktyczny, **uporządkowany** plan „co muszę zrobić ręcznie, żeby wypuścić apkę”.
To uzupełnienie [`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md) — checklist mówi
*co* jest do zrobienia per temat, ten plik mówi **w jakiej kolejności** i **skąd
brać każdy token**. Po skończeniu zostaje Ci już tylko dodawanie pytań i smaczków.

> Stan na 2026-06-24: kod jest gotowy. `flutter analyze` → 3 kosmetyczne infa,
> `flutter test` → 131/131 przechodzi. Wszystko poniżej to robota **poza kodem**
> (konta, klucze, podpisywanie buildu, treść).

---

## 0. TL;DR — twarde blokery (bez tego store odrzuci build)

| # | Bloker | Gdzie | Status |
|---|--------|-------|--------|
| 1 | **Android release signing** — szkielet gotowy w kodzie (czyta `key.properties`), zostaje **wygenerować keystore + `key.properties`** | `android/app/build.gradle.kts` | 🟡 zostaje keystore |
| 2 | **AdMob App ID** — wstawione realne (Android `~5813725144`, iOS `~6955416427`) | `AndroidManifest.xml:21` + `ios/Runner/Info.plist:10` | ✅ zrobione |
| 3 | **Realne tokeny** — Supabase/Google/rewarded ✅; zostaje **realny RevenueCat public SDK key** (per-platforma) | `env/prod-android.json` + `env/prod-ios.json` | 🟡 RC key |
| 4 | **iOS: pełna lista SKAdNetwork** | `ios/Runner/Info.plist` (1 stub) | ❌ wklej listę Google |
| 5 | **Realne treści pytań** | Supabase (`questions` / `daily_questions`) | ❌ migracja seeduje tylko demo |
| 6 | **Strony prawne live** | `https://debatly.app/{privacy,terms,delete-account}` | ❌ opublikuj |
| 7 | **SSV dla rewarded** — wybrana **opcja 1** (SSV ON); zostaje wkleić callback URL w AdMob | AdMob console → jednostka rewarded | 🟡 wklej URL |

Reszta (deletes konta, consent GDPR/ATT, powiadomienia, share, in-app review,
widget Android) jest **gotowa w kodzie** — wymaga tylko konfiguracji w konsolach.

---

## Część A — Załóż konta / projekty (kolejność ma znaczenie)

Rób w tej kolejności, bo późniejsze kroki potrzebują ID z wcześniejszych.

1. **Supabase** — projekt już istnieje. Zapisz sobie `project-ref` (z URL dashboardu,
   `https://<ref>.supabase.co`). Potrzebny niemal wszędzie niżej.
2. **Google Cloud Console** — projekt OAuth (dla logowania Google na Androidzie).
3. **AdMob** — aplikacja + 2 jednostki reklam (banner, rewarded).
4. **RevenueCat** — projekt + entitlement `premium` + produkty + paywall.
5. **Apple Developer** (jeśli wypuszczasz iOS) — App ID `com.aknsoftware.questionapp`
   + capability *Sign in with Apple*.
6. **Google Play Console** / **App Store Connect** — wpisy aplikacji.

---

## Część B — Inwentarz tokenów (skąd bierzesz → gdzie wkładasz)

To jest sedno „jakie tokeny”. Trzy miejsca docelowe:
- **`env/prod-android.json` / `env/prod-ios.json`** → klucze build-time
  (`--dart-define-from-file`), czytane przez `AppConfig`. **Per-platforma**, bo
  AdMob unit ID **i** RevenueCat public SDK key różnią się między iOS a Androidem
  (oba pliki są już utworzone, w `.gitignore`).
- **Supabase secrets** → sekrety serwerowe dla edge functions (`supabase secrets set`).
- **Pliki natywne / konsole** → wartości, których nie da się wstrzyknąć z Dart.

| Token / sekret | Skąd go bierzesz | Gdzie trafia | Status |
|----------------|------------------|--------------|--------|
| `SUPABASE_URL` | Supabase → Project Settings → API | oba pliki env | ✅ wpisane |
| `SUPABASE_ANON_KEY` | Supabase → API (anon/publishable) | oba pliki env | ✅ wpisane |
| `GOOGLE_SERVER_CLIENT_ID` | Google Cloud → OAuth → **Web** client id | oba pliki env | ✅ wpisane |
| `ADMOB_REWARDED_ID` | AdMob → jednostka rewarded (**osobna na platformę**) | `prod-android` / `prod-ios` | ✅ wpisane |
| `ADMOB_BANNER_ID` | — | (martwe) | ⬜ **nie używane** — banner nie jest renderowany w apce; pomiń |
| `REVENUECAT_API_KEY` | RevenueCat → API keys → **public SDK** (`goog_…` dla Play, `appl_…` dla App Store) | `prod-android` / `prod-ios` | ❌ placeholder — wstaw realny |
| `REVENUECAT_REST_API_KEY` | RevenueCat → API keys → **secret** key (`sk_...`) | `supabase secrets set` | ❌ |
| `REVENUECAT_WEBHOOK_SECRET` | wymyślasz sam (długi losowy string) | `supabase secrets set` **oraz** webhook w RevenueCat | ❌ |
| `PREMIUM_ENTITLEMENT` (opcj.) | nazwa entitlementu, domyślnie `premium` | `supabase secrets set` (tylko jeśli ≠ `premium`) | — |
| **AdMob App ID** (Android `~5813725144`) | AdMob → ustawienia aplikacji | `AndroidManifest.xml:21` | ✅ wstawione |
| **AdMob App ID** (iOS `~6955416427`) | jw., osobne ID dla apki iOS | `ios/Runner/Info.plist:10` | ✅ wstawione |
| **SKAdNetwork list** | [lista Google](https://developers.google.com/admob/ios/3p-skadnetworks) | `ios/Runner/Info.plist` | ❌ |
| **Upload keystore** (Android) | generujesz `keytool` (Krok 1) | `android/key.properties` | ❌ |

> Uwaga na rozróżnienie: **ad UNIT id** (`/` ukośnik, banner/rewarded) idzie przez
> dart-define, ale **AdMob APP id** (`~` tylda) musi być w plikach natywnych —
> dwie różne rzeczy z AdMob, i **każda osobna na platformę**.
> Strony prawne są już zaszyte w `AppConfig` (`https://debatly.app/...`) — w env są
> tylko dla porządku; ważne, żeby strony były **live**.

### Pliki env są już utworzone

`env/prod-android.json` i `env/prod-ios.json` mają wpisane realne: Supabase,
Google client id, oraz rewarded unit per-platforma. **Do uzupełnienia ręcznie
zostaje tylko** `REVENUECAT_API_KEY` (realny `goog_…` / `appl_…`).
`ADMOB_BANNER_ID` jest **nieużywany** (banner nie jest renderowany) — testowe ID
w env jest martwe i bezpieczne; nie twórz jednostki banner.

Build:
```bash
flutter build appbundle --release --dart-define-from-file=env/prod-android.json
flutter build ipa       --release --dart-define-from-file=env/prod-ios.json
```

---

## Część C — Wykonanie krok po kroku

### Krok 1 — Android: keystore + podpisywanie (BLOKER #1)

**Kod już gotowy:** `android/app/build.gradle.kts` czyta `android/key.properties`
i podpisuje release tym keystore, jeśli plik istnieje (a gdy go nie ma — wraca do
debug, żeby `flutter run --release` działał na devie). `key.properties` i `*.jks`
są już w `.gitignore`. Zostaje Ci tylko wygenerować keystore i wpisać hasła:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias upload
```

Utwórz `android/key.properties`:

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/bezwzgledna/sciezka/do/upload-keystore.jks
```

Zachowaj keystore w bezpiecznym miejscu — jego utrata = brak możliwości
aktualizacji apki w Play.

### Krok 2 — Supabase (migracje + sekrety + functions + auth)

```bash
supabase link --project-ref <twój-ref>
supabase db push

supabase secrets set REVENUECAT_WEBHOOK_SECRET="<długi-losowy>"
supabase secrets set REVENUECAT_REST_API_KEY="sk_..."

# functions: 3/4 wg checklisty już wdrożone — domknij delete-account jeśli trzeba
supabase functions deploy revenuecat-webhook --no-verify-jwt
supabase functions deploy admob-ssv          --no-verify-jwt
supabase functions deploy sync-entitlement
supabase functions deploy delete-account
```

W **Dashboard → Authentication**:
- [ ] **Confirm email = ON** (inaczej throwaway-maile dostają darmowe kredyty —
      `is_real_account` wymaga potwierdzonego maila).
- [ ] **Leaked-password protection = ON**.
- [ ] **Apple** provider ON → dodaj bundle id `com.aknsoftware.questionapp` do
      authorized client ids (flow natywny, bez Service ID).
- [ ] **Google** provider ON → dodaj **Web** client id do authorized client ids.

### Krok 3 — AdMob (App ID + SSV + consent)

- [x] ✅ Realne **App ID** wstawione w `AndroidManifest.xml:21` i `Info.plist:10`.
- [x] ✅ Realne **rewarded unit ID** wpisane do `prod-android.json` / `prod-ios.json`.
- [ ] ✅ **Wybrana opcja 1 (SSV ON)** — w AdMob: jednostka rewarded →
      *Server-side verification* → wklej:
      `https://puuukxfrretxhdsptllr.functions.supabase.co/admob-ssv`
      (zrób to na rewarded **Android i iOS**; kontekst w ramce niżej).
- [ ] Utwórz **komunikat zgody GDPR** (i na iOS pre-prompt ATT) w AdMob → Privacy.
- [ ] iOS: wklej pełną listę **SKAdNetwork** (BLOKER #4).
- [x] ⬜ **Banner — nie używasz.** `createBannerAd` istnieje w `ads_service.dart`,
      ale nic go nie renderuje, więc żaden banner się nie ładuje. Nie twórz
      jednostki banner; testowe `ADMOB_BANNER_ID` w env jest martwe. Apka
      monetyzuje się wyłącznie przez rewarded.

> ### ⚠️ SSV jest WYMAGANE przez serwer — ✅ wybrana opcja 1 (włączyć SSV)
>
> Migracja `20260622160000_reveal_ad_question_require_verified_reward.sql`
> hartuje RPC `reveal_ad_question` tak, że reveal jest dozwolony tylko gdy:
> `ad_reveals_used <= zweryfikowane_nagrody_SSV + GRACE` (GRACE = **2**).
>
> Czemu tak: bez tego każdy może w pętli wołać `reveal_ad_question` (REST) i
> wydrenować cały darmowy katalog **bez oglądania reklamy** — re-rollując
> anonimową tożsamość w nieskończoność. To utrata przychodu z reklam + wyciek
> treści. Jedynym niemożliwym do podrobienia dowodem obejrzenia reklamy jest
> podpisany callback SSV od Google (pisze go funkcja `admob-ssv`).
>
> **Konsekwencja, jeśli zostawisz „bez SSV":** każdy user dostaje tylko **2
> odsłonięcia na całe życie konta** (bufor GRACE), potem każdy reveal rzuca
> `ad reward not verified` → toast + paywall. Czyli core loop darmowego usera
> jest zepsuty po 2 reklamach.
>
> **Masz dwie opcje — wybierz:**
> 1. **(Zalecane) Włącz SSV** — to dosłownie wklejenie URL-a w AdMob:
>    jednostka rewarded → *Server-side verification* →
>    `https://puuukxfrretxhdsptllr.functions.supabase.co/admob-ssv`.
>    Funkcja `admob-ssv` jest już wdrożona; **testowe jednostki też wysyłają SSV**,
>    więc cały loop sprawdzisz jeszcze przed launchem. Zero zmian w kodzie.
> 2. **Poluzuj gate** — jeśli świadomie nie chcesz SSV, trzeba podnieść `c_grace`
>    w tej migracji do dużej liczby (np. 100000) i odpalić ją ponownie. To
>    **otwiera z powrotem dziurę** na masowy drenaż katalogu — odradzam.
>
> Opcja 1 jest banalna i zostawia ochronę — dlatego ją rekomenduję.

> ### 🧪 Testowanie reklam na REALNEJ jednostce bez bana
>
> AdMob banuje za generowanie własnych wyświetleń/kliknięć na **live** reklamach.
> Skoro testujesz już na prawdziwym rewarded unit ID — **nie klikaj** w nie,
> dopóki nie zarejestrujesz urządzenia jako testowego. Wtedy AdMob serwuje na
> Twój telefon „**Test Ad**" (bezpieczne, a testowe reklamy **i tak wysyłają
> SSV**, więc zweryfikujesz pełny loop).
>
> Kod jest już podpięty (`AppConfig.admobTestDeviceIds` → `AdsService.initialise`).
> Jak włączyć:
> 1. Odpal apkę raz na telefonie i obejrzyj reklamę. W logu (`flutter run` /
>    logcat) pojawi się linia w stylu:
>    `Use RequestConfiguration.Builder.setTestDeviceIds(["33BE2250B43518CC…"])`.
> 2. Skopiuj ten hash i wklej do env, którym budujesz (`local.json`), pole
>    `ADMOB_TEST_DEVICE_IDS` (kilka urządzeń = po przecinku). ID jest **osobne
>    per fizyczne urządzenie** (inne dla Androida, inne dla iPhone'a).
> 3. Zrestartuj apkę — reklamy będą oznaczone „Test Ad". Od teraz klikanie jest
>    bezpieczne.
>
> ⚠️ W buildach do store zostaw `ADMOB_TEST_DEVICE_IDS` **puste** (pliki
> `prod-android.json` / `prod-ios.json` nie mają tego klucza = realne reklamy).

### Krok 4 — RevenueCat (Premium)

- [ ] Entitlement `premium` + produkty (App Store + Play).
- [ ] Paywall w dashboardzie (apka woła `presentPaywall`).
- [ ] Klucze: public SDK → `prod-android.json` (`goog_…`) / `prod-ios.json`
      (`appl_…`), secret (`sk_…`) → Supabase secret (Krok 2).
- [ ] Webhook → URL `revenuecat-webhook` + `REVENUECAT_WEBHOOK_SECRET`.

> ℹ️ Apka **nie crashuje już** bez prawdziwego klucza RC — `PurchasesService`
> pomija konfigurację dla pustego / placeholderowego (`…REPLACE…` / `test_…`)
> klucza i degraduje do „premium niedostępne" (wcześniej natywny SDK ubijał
> proces: *„app will close now to protect the security"*). Czyli placeholder
> `goog_REPLACE_…` w `prod-android.json` jest bezpieczny do czasu wstawienia
> realnego klucza — ale **premium/paywall ruszy dopiero z realnym** `goog_…`/`appl_…`.

### Krok 5 — iOS only (jeśli wypuszczasz na iOS, wymaga Maca + Xcode)

- [ ] Apple Developer → App ID `com.aknsoftware.questionapp` → capability *Sign in with Apple*.
- [ ] Xcode → Runner → Signing & Capabilities → **+ Sign in with Apple**
      (`Runner.entitlements` już ma klucz).
- [ ] Widget: Widget Extension target + App Group `group.com.aknsoftware.questionapp`
      wg [`ios/DailyQuestionWidget/SETUP.md`](ios/DailyQuestionWidget/SETUP.md).
- [ ] `pod install` po dodaniu pluginów.

### Krok 6 — Tożsamość appki i assets

- [ ] Ikony + splash (nazwa „Debatly” i bundle `com.aknsoftware.questionapp` już ustawione ✅).
- [ ] Wersja w `pubspec.yaml` (teraz `1.0.0+1`).
- [ ] Opublikuj strony prawne na `https://debatly.app/{privacy,terms,delete-account}` (BLOKER #6).
- [ ] Wklej `https://debatly.app/delete-account` do formularza **Data safety** w Play.
- [ ] Screenshoty do store: `QuestionShareCard` renderuje gotowe plakaty 1080×1920
      (patrz test `renderWidgetToPng`).

### Krok 7 — Treść (to, co zostaje „na koniec”)

- [ ] Zaseeduj realne pytania do `questions` / `question_translations`.
- [ ] Wypełnij `daily_questions` (migracja initowa daje tylko 3 demo).
- [ ] Dodaj smaczki / hot-takes.

---

## Część D — Build i wysyłka

```bash
# Android (Play → App Bundle, podpisany realnym keystore)
flutter build appbundle --release --dart-define-from-file=env/prod-android.json

# iOS (na Macu, po pod install i konfiguracji Xcode)
flutter build ipa --release --dart-define-from-file=env/prod-ios.json
```

Przed wysyłką, sanity-check:
- [ ] `flutter analyze` czysty, `flutter test` zielony.
- [ ] Odpal **release** build na fizycznym Androidzie — R8 włącza obfuskację;
      reguły w `proguard-rules.pro` chronią przed crashem WorkManager/Room na starcie.
- [ ] Przejdź pełny flow na realnych kluczach: logowanie (Google/Apple/email),
      zakup premium (sandbox), rewarded-ad reveal (SSV), usunięcie konta.
- [ ] Internal testing track w Play (in-app review pokazuje się dopiero z Play, nie z debug).

---

## Drobiazgi z review — ✅ zrobione w kodzie (2026-06-24)

- ✅ Usunięty martwy klucz `authAppleSoon` z obu ARB + przeregenerowane lokalizacje.
- ✅ Naprawione 3× `curly_braces_in_flow_control_structures` w `wind_question_view.dart`.
- ✅ Szkielet release-signing w `build.gradle.kts` (Krok 1) + `.gitignore` na keystore.

Po tych zmianach: `flutter analyze` czysty (0 issues), `flutter test` 131/131.
