# App Store release checklist

Everything here needs your Apple Developer account. Nothing in the repo uploads or submits on its
own. Version `1.0.0` is set in `project.yml`; `Scripts/release.sh` stamps the build number.

## Before the first upload

1. **GitHub Pages:** repo Settings -> Pages -> Deploy from branch `main`, folder `/docs`.
   This publishes `https://exzellenzschmiede.github.io/guitarro/` (support) and
   `.../privacy.html` (privacy policy), which the paywall links to.
2. **Contact address:** the support and privacy pages use `guitarro@kaniut.de`; make sure that
   mailbox exists before submitting, App Review may write to it.
3. **App Store Connect -> Apps -> New App:** iOS, name "Guitarro", primary language German,
   bundle id `de.kaniut.guitarro`, SKU `guitarro-ios`.
4. **In-app purchases** (Monetization): subscription group "Guitarro Pro" with
   `de.kaniut.guitarro.pro.monthly` (1 month, 4,99 €) and `de.kaniut.guitarro.pro.yearly`
   (1 year, 29,99 €, optional 7-day trial); non-consumable `de.kaniut.guitarro.pro.lifetime`
   (39,99 €). Each needs a localized display name, a description and a review screenshot of
   the paywall. Attach all three to the version under "In-App Purchases and Subscriptions".
   The subscription group also needs a localized group name.
5. **Upload a build:** `Scripts/release.sh` (see `docs/TESTFLIGHT.md`), then test it once via
   TestFlight on a real device — especially microphone detection with a real guitar.

## App information

- **Category:** Music (secondary: Education)
- **Age rating:** answer everything "None" -> 4+
- **Copyright:** 2026 Mathias Kaniut
- **Privacy policy URL:** https://exzellenzschmiede.github.io/guitarro/privacy.html
- **Support URL:** https://exzellenzschmiede.github.io/guitarro/
- **App privacy (nutrition labels):** "Data Not Collected". Justification: microphone, camera
  and music library are processed on device; the optional AI coach sends chat text to Anthropic
  only when the user enters their own API key, which is not collection by the developer.
- **Export compliance:** `ITSAppUsesNonExemptEncryption` is `false` in the Info.plist, so no
  yearly self-classification report is needed.
- **Content rights:** all songs are traditional / public domain; story, tutorials and code are
  your own.

## Listing (German, primary)

**Name:** Guitarro
**Subtitle (30):** Gitarre lernen, die zuhört
**Promotional text (170):** Stimmgerät, lebendiges Griffbrett, Akkordwechsel-Trainer, Kamera-Coach, KI-Coach, Songs und drei spielbare Stories – Guitarro hört dir zu und sagt dir, was besser geht.
**Keywords (100):** gitarre,gitarre lernen,akkorde,stimmgerät,griffbrett,tuner,chords,üben,songs,e-gitarre,akustik

**Description:**

Guitarro ist der Gitarrenlehrer, der wirklich zuhört. Spiel eine Saite, einen Akkord oder einen ganzen Song – die App erkennt auf dem Gerät, was du spielst, und gibt dir sofort Rückmeldung. Für Einsteiger und Fortgeschrittene, für Akustik- und E-Gitarre.

STORY-MODUS
Lerne Gitarre in einer Geschichte: „Die verlorene Melodie“ führt dich von der ersten gestimmten Saite bis zum ersten Auftritt. Zwei weitere Stories – „Roadtrip“ und „Das Haus am Hügel“ – bringen dich zu Akkordwechseln, Riffs und ganzen Songs. Jede Herausforderung wird über das Mikrofon geprüft.

LEBENDIGES GRIFFBRETT
Sieh, was du spielst: Töne leuchten auf, während du sie greifst. Akkorde, Tonleitern und Stimmungen für Rechts- und Linkshänder, mit deutschen oder internationalen Notennamen.

STIMMGERÄT
Präzise, schnell und ehrlich – mit Pegelanzeige, Auto-Saitenerkennung, chromatischem Modus und Kammerton-Einstellung.

AKKORDWECHSEL-TRAINER
Die Ein-Minuten-Challenge mit intelligenter Wiederholung: Guitarro merkt sich, welche Wechsel dir schwerfallen, und plant sie neu ein.

TUTORIALS
Animierte Lektionen aus den Bausteinen der App: Finger, die nacheinander auf dem Griffbrett landen, Schlagmuster zum Mithören, Barré-Technik – und am Ende immer ein echter Übungscheck.

SONGS
Traditionelle Songs mit Begleitung, Metronom, Tempo-Regler und Rückmeldung pro Takt. Mit Guitarro Pro: eigene Songs aus deiner Musikbibliothek analysieren – Akkorde, Tonart und Tempo automatisch – und Apple-Music-Titel über den Systemplayer mitspielen.

KAMERA-COACH (Pro)
Die Kamera sieht deine Greifhand und sagt dir, welcher Finger flach liegt oder wo der Daumen hingehört. Alles auf dem Gerät, nichts wird gespeichert.

KI-COACH (Pro)
Ein Coach, der deinen Fortschritt kennt. Läuft mit Apple Intelligence auf dem Gerät oder – wenn du möchtest – mit deinem eigenen Claude-API-Schlüssel.

Guitarro sammelt keine Daten. Kein Konto, kein Tracking, keine Werbung.

Guitarro Pro gibt es als Monats- oder Jahresabo oder als einmaligen Kauf. Abos verlängern sich automatisch, wenn sie nicht mindestens 24 Stunden vor Ablauf gekündigt werden, und lassen sich in den Einstellungen deines Apple-Kontos verwalten.
Datenschutz: https://exzellenzschmiede.github.io/guitarro/privacy.html
Nutzungsbedingungen: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

**What's new (1.0.0):** Erste Version.

## Listing (English)

**Subtitle:** Guitar lessons that listen
**Promotional text:** Tuner, living fretboard, chord-change trainer, camera coach, AI coach, songs and three playable stories – Guitarro listens to you and tells you what to fix.
**Keywords:** guitar,learn guitar,chords,tuner,fretboard,practice,songs,electric,acoustic,lessons

**Description:**

Guitarro is the guitar teacher that actually listens. Play a string, a chord or a whole song and the app recognises it on your device and gives you feedback right away. For beginners and intermediate players, acoustic and electric.

STORY MODE
Learn guitar inside a story: "The Lost Melody" takes you from the first tuned string to your first gig. Two more stories, "Roadtrip" and "The House on the Hill", lead you to chord changes, riffs and full songs. Every challenge is checked through the microphone.

LIVING FRETBOARD
See what you play: notes light up as you fret them. Chords, scales and tunings for right- and left-handed players, with international or German note names.

TUNER
Precise, fast and honest, with a level meter, automatic string detection, chromatic mode and adjustable reference pitch.

CHORD-CHANGE TRAINER
The one-minute challenge with spaced repetition: Guitarro remembers which changes are hard for you and schedules them again.

TUTORIALS
Animated lessons built from the app itself: fingers landing on the fretboard one by one, strumming patterns you can hear, barre technique, and a real practice check at the end of each.

SONGS
Traditional songs with backing, metronome, tempo control and per-bar feedback. With Guitarro Pro: analyse your own songs from your music library (chords, key and tempo detected automatically) and play along to Apple Music tracks through the system player.

CAMERA COACH (Pro)
The camera watches your fretting hand and tells you which finger is flat or where your thumb belongs. Everything on device, nothing is stored.

AI COACH (Pro)
A coach that knows your progress. Runs with Apple Intelligence on device or, if you like, with your own Claude API key.

Guitarro collects no data. No account, no tracking, no ads.

Guitarro Pro is available as a monthly or yearly subscription or a one-time purchase. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the period and can be managed in your Apple account settings.
Privacy policy: https://exzellenzschmiede.github.io/guitarro/privacy.html
Terms of use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

## Screenshots

Required: 6.9" iPhone (1320×2868) and 13" iPad (2064×2752). Raw simulator screenshots are
accepted; `build/screenshots/` holds a set captured from iPhone 17 Pro Max and iPad Pro 13".
Suggested order: story hub, tuner (in tune), fretboard with chord, tutorial lesson, practice hub,
songs. Regenerate with the simulator after UI changes.

## Notes for App Review

Paste into "Notes":

> Guitarro listens to a guitar through the microphone; all analysis runs on device. To test without
> a guitar, play any sustained tone (e.g. a YouTube guitar tuner video) near the microphone on the
> Tuner tab. The camera coach needs a real hand in front of the camera. The AI coach works on device
> where Apple Intelligence is available; the Claude option only activates when a user enters their
> own API key. Guitarro Pro can be tested with the sandbox account; "Restore purchases" is on the
> paywall. No login is required anywhere in the app.

## Submission

1. Version page: upload screenshots, fill texts above, attach the build and the in-app purchases.
2. Set pricing (Free) and availability (all countries or your choice).
3. Choose "Manually release this version" so you decide when it goes live.
4. Submit for review. Typical turnaround is one to three days.
