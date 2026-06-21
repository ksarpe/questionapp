# Ścieżki użytkownika — co może gość, zalogowany i premium

Dokument opisuje **krok po kroku**, jak aplikacja zachowuje się dla każdego typu
użytkownika: co widzi, co może zrobić, a czego nie. Stan na 2026-06-20 (model
"reveal feed" + pamięć „widziane").

> Słowniczek: „daily" = codzienne pytanie (to samo dla wszystkich). „Reveal /
> odsłonięcie" = pokazanie nowego pytania spoza daily. „Slot" = miejsce w feedzie,
> gdzie pojawia się paywall/odsłonięcie kolejnego pytania. „Seen-memory" =
> tabela `question_seen` zapamiętująca, co użytkownik już widział.

---

## 1. Trzy typy użytkownika

| Typ | Kto to | Sesja Supabase |
|-----|--------|----------------|
| **Gość (niezalogowany)** | Nie założył/nie zalogował się na konto | Anonimowa (`is_anonymous = true`) — aplikacja **sama** loguje anonimowo na starcie, więc gość ma stałe `uuid`, ale to **nie** jest „prawdziwe konto" |
| **Zalogowany (free)** | Konto e-mail lub Google, bez subskrypcji | `is_anonymous = false`, `is_premium = false` |
| **Premium** | Konto z aktywną subskrypcją (RevenueCat) | `is_anonymous = false`, `is_premium = true` |

> ⚠️ **Wymóg konfiguracji:** w Supabase muszą być **włączone Anonymous sign-ins**
> (Authentication → Sign In / Providers). Bez tego gość nie dostaje sesji i cały
> jego tryb pada na `permission denied`.

---

## 2. Tabela: co kto może

| Funkcja | Gość | Zalogowany free | Premium |
|---|---|---|---|
| Czytać dzisiejsze **daily** | ✅ | ✅ | ✅ |
| **Głosować** TAK/NIE na daily | ❌ → przekierowanie do logowania | ✅ | ✅ |
| Widzieć **wyniki %** głosowania | ❌ | ✅ (po oddaniu głosu) | ✅ |
| **Streak** (seria) | ❌ (ukryty) | ✅ | ✅ |
| **1 darmowe** nowe pytanie / dzień (bez reklamy) | ❌ | ✅ (kredyt) | — (nie potrzebuje) |
| Odsłaniać **nowe pytania reklamą** | ✅ | ✅ | — (nie potrzebuje) |
| **Teaser** następnego pytania na paywallu | ✅ | ✅ | — |
| Czytać **cały katalog** bez limitu | ❌ | ❌ | ✅ |
| Wracać do już odsłoniętych pytań | tylko w tej sesji | tylko w tej sesji | ✅ (cały katalog) |
| **Smaczki** — pierwszy | ✅ | ✅ | ✅ |
| **Smaczki** — pozostałe | ❌ (zablokowane) | ❌ (zablokowane) | ✅ |
| Ikona konta / Ustawienia | „Zaloguj" (delikatny) | 👤 → Ustawienia | 👤 → Ustawienia |

---

## 3. Gość (niezalogowany) — krok po kroku

1. **Start aplikacji** → automatyczne anonimowe logowanie → gość dostaje `uuid`.
2. **Ekran główny: dzisiejsze daily.** Czyta je za darmo.
   - U góry: **brak ikony serii** (streak ukryty dla gościa).
   - W prawym górnym rogu: delikatny przycisk **„Zaloguj"** (zamiast ludzika).
3. **Pod pytaniem: przyciski TAK / NIE.**
   - Przyciski **są widoczne**, ale kliknięcie **nie głosuje** — otwiera arkusz
     logowania. Gość **nie widzi** też procentów.
4. **Swipe w lewo (dalej)** → trafia na **slot odsłonięcia**:
   - Gość **nie ma darmowego kredytu**, więc od razu widzi **paywall**:
     - teaser następnego pytania (np. „CZY MILIARDERZY…"),
     - „Odblokuj reklamą" — obejrzenie reklamy odsłania **nowe, niewidziane**
       pytanie (serwer losuje),
     - „Przejdź na PRO".
5. **Po obejrzeniu reklamy** → odsłania się dokładnie to teasowane pytanie, ląduje
   w feedzie sesji i w pamięci „widziane" (nie powtórzy się).
6. **Swipe w prawo** → powrót do wcześniej odsłoniętych pytań **tej sesji**.
7. **Restart aplikacji** → feed znika, zostaje samo daily. Pytania widziane
   wcześniej **nie wracają** (nie powtórzą się) i **nie są** ponownie czytelne.
8. **„Go deeper" (smaczki)** na czytelnym pytaniu → pierwszy smaczek za darmo,
   reszta zablokowana (PRO).

**Czego gość NIE może:** głosować, widzieć wyników, mieć serii, dostać darmowego
pytania bez reklamy, czytać całego katalogu, wracać do pytań po restarcie.

> 🔒 **Anti-farm:** wylogowanie/ponowne wejście jako nowy gość **nie daje** świeżych
> darmowych pytań — darmowy kredyt jest tylko dla prawdziwych kont, a pamięć
> „widziane" i tak jest per `uuid`.

---

## 4. Zalogowany (free) — krok po kroku

1. **Logowanie** (e-mail lub Google). Jeśli wcześniej był gościem i zakłada konto
   **e-mail/hasło**, anonimowe konto jest **ulepszane w miejscu** — to samo `uuid`,
   postęp zachowany. (Logowanie Google tworzy/łączy tożsamość Google.)
2. **Ekran główny: daily.**
   - U góry: **ikona serii (🔥)** + jeśli jest kredyt, **🔓 „1"** (tylko na daily).
   - Prawy górny róg: **ikona konta 👤** → Ustawienia.
3. **Głosowanie TAK/NIE** działa:
   - po oddaniu głosu widzi **wyniki %** społeczności,
   - głos na daily **buduje serię** (raz dziennie, liczone zegarem serwera UTC).
4. **Swipe w lewo (dalej)** → slot odsłonięcia:
   - **Ma kredyt (1/dzień)** → pytanie odsłania się **automatycznie, bez reklamy**
     (kredyt zużyty, brak przycisku). To „pierwsze darmowe dziennie".
   - **Brak kredytu** (już zużyty) → **paywall** z teaserem: reklama lub PRO.
5. **Kolejne pytania** → każde za reklamą (albo PRO). Zawsze **nowe i niewidziane**.
6. **Swipe w prawo** → powrót po feedzie **tej sesji**. Po restarcie feed = samo daily.
7. **Smaczki** → pierwszy za darmo, reszta PRO.
8. **Ranga / seria** → widoczne; ranga wynika z aktualnej serii (spadek serii =
   spadek rangi).

**Czego zalogowany free NIE może:** czytać całego katalogu na raz, wracać do
odsłoniętych pytań po restarcie, czytać dalszych smaczków bez PRO.

---

## 5. Premium — krok po kroku

1. **Zakup PRO** (z paywalla „Przejdź na PRO" albo z Ustawień) → po zakupie sesja
   się odświeża i deck przełącza się na **pełny katalog**.
2. **Czyta wszystko** — każde pytanie z katalogu, łącznie z pytaniami premium-only.
3. **Swipe** → przechodzi przez cały katalog (z zawijaniem), **bez reklam, bez
   paywalla, bez slotu odsłonięcia**.
4. **Brak kredytu** i brak licznika 🔓 — premium go nie potrzebuje.
5. **Głosowanie i seria** działają jak u zalogowanego free.
6. **Smaczki** → wszystkie odblokowane.

---

## 6. Mechanizmy przekrojowe

### Bramka czytania tekstu (`can_read_question_text`)
- **Premium** → wszystko.
- **Każdy** → dzisiejsze daily (lokalna data ±1 dnia od UTC).
- **Free/gość** → poza daily tekst dostają **wyłącznie** przez RPC odsłonięcia
  (zwraca tekst „tu i teraz"), trzymany w pamięci sesji. Bramka **nie** wydaje
  ponownie widzianych pytań → brak ponownego czytania.

### Pamięć „widziane" (`question_seen`)
- To **log konsumpcji**, nie prawo dostępu. Zapisuje, że pytanie zostało już
  pokazane, żeby **nie pokazać go drugi raz**. Nie odblokowuje ponownego odczytu.

### Odsłanianie (reveal)
- `reveal_free_question` — kredytem (tylko realne konto, 1/dzień).
- `reveal_ad_question(p_question_id)` — po reklamie; odsłania teasowane pytanie
  (a jeśli przestało być dostępne — losowe), żeby reklama się nie zmarnowała.
- `peek_next_question` — podgląd `{id, teaser}` następnego pytania **bez**
  odsłaniania (do baitu na paywallu).

### Reklamy (AdMob)
- Reklama odsłania pytanie po stronie klienta; callback SSV (`admob-ssv`) to
  **tylko audyt** nagrody (loguje `ad_reward_events`), nie nadaje konkretnego
  pytania.

### Smaczki
- Pierwszy zawsze za darmo; reszta tylko premium. Dostęp do panelu: daily / pytanie
  z sesji / premium. (Uwaga: treść smaczków jest na razie prawie niezaseedowana.)

### Anti-farm
- Darmowe (kredyt) tylko dla realnych kont → re-rollowanie anonimowej tożsamości
  (logout/login, czyszczenie danych) nic nie daje. To zatrzymuje casualowy farming;
  pełna odporność (reinstalacja/factory reset/wiele urządzeń) wymagałaby
  device-bindingu/atestacji — świadomie odłożone.

---

## 7. Przypadki brzegowe / do dokończenia

- **Koniec pytań:** gdy free/gość odsłoni wszystkie dostępne (niepremium) pytania,
  slot pokazuje **„To wszystkie pytania na teraz"**. Docelowa obsługa (np. reset,
  zaproszenie do PRO) — **do ustalenia**.
- **Pula:** obecnie 20 aktywnych pytań (11 niepremium / 9 premium-only), więc free
  user wyczerpuje pulę po ~10 odsłonięciach.
- **Wylogowanie:** czyści feed sesji i wraca na daily; nowy gość zaczyna od zera
  (bez kredytu, bez historii).

---

## 8. Załącznik techniczny (dla dev)

- **Sesja/tier:** `sessionProvider` → `hasAccount` (realne konto), `isPremium`.
- **Deck:** `questionDeckProvider` — premium = `[daily, ...katalog]` (zawijanie);
  free/gość = `[daily, ...revealedFeedProvider]` + „reveal slot"
  (`isAtRevealSlotProvider`).
- **Widget pytania:** `WindQuestionView` (ma stabilny `key`, by nie tracić stanu
  feedu przy zmianie daily↔nie-daily). Nawigacja: `forwardLinear` / `backLinear`.
- **Stan serwera użytkownika:** `sync_user_state` (seria, kredyt, ranga; top-up
  kredytu raz na dobę UTC, tylko realne konta).
- **Głosowanie:** `cast_daily_vote` / `get_daily_vote_state`; panel
  `DailyVotePanel` (gość → przyciski kierują do logowania).
- **Migracje kluczowe:** `..._reveal_feed_seen_memory`, `..._peek_next_question`,
  `..._real_account_gated_freebies`, `..._smaczki_question_seen_rename`.
