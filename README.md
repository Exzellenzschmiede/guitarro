# Guitarro

Guitar learning app for iPhone and iPad. Native Swift 6 / SwiftUI, iOS 26+.

## Setup

```bash
brew install xcodegen
xcodegen generate
open Guitarro.xcodeproj
```

The Xcode project is generated from `project.yml`. Do not edit the project file by hand.

## Structure

- `Guitarro/` – the app target (SwiftUI, localization, features)
- `Packages/GuitarroKit/` – local Swift package with the core modules
  - `MusicTheory` – pitches, note names, intervals, chords, voicings, tunings
  - `AudioEngine` – microphone capture, pitch detection (YIN), chord detection (harmonic-corrected chroma
    + template matching), plucked-string synthesis (Karplus-Strong)
  - `Training` – chord-change curriculum and SM-2 style spaced-repetition scheduler
  - `HandCoach` – Vision hand-pose detection, fretting-hand posture analysis, camera session
  - `Songs` – song model, traditional song library, playback timeline
  - `AICoach` – coach providers: on-device (FoundationModels) and Claude (Messages API, streaming)
  - `Story` – campaign model, "The Lost Melody" content and progress/XP logic
  - `Fretboard` – interactive fretboard view and layout
  - `DesignSystem` – colors, typography, spacing

## Features so far

- Tuner: auto (nearest string) and chromatic mode, six tuning presets, adjustable reference pitch
- Living fretboard: note / interval / finger labels, chord library with explanations, tap to hear,
  listen mode that lights up the note you play
- Chord change trainer: one-minute changes counted by ear (or manually), scheduled with spaced
  repetition and stored with SwiftData
- Camera coach: watches the fretting hand, colour-codes each finger's arch and comments on flat
  fingers and a thumb wrapped over the neck (needs a real device; the simulator shows a demo hand)
- Songs: traditional songs with backing strums, metronome, count-in, tempo 50–120 %, section loops,
  and per-bar chord feedback by ear (with headphones or with the backing off)
- AI coach: chat that knows the player's progress; runs on-device where Apple Intelligence is
  available, otherwise via Claude with the player's own API key (stored in the Keychain)
- Story mode: "The Lost Melody", six chapters with dialogue, choices and playable challenges
  (tuning, notes, chords, one-minute changes, a song) that gate progress; XP and levels

## Design

Dark stage look defined in `DesignSystem`: ink gradient background with a warm glow and string
lines (`guitarroScreen`), glass cards (`guitarroCard`), gradient hero cards, amber primary
buttons (`.guitarroPrimary`), icon badges and palettes per feature. The app forces dark mode.

## Tests

```bash
cd Packages/GuitarroKit && swift test
```
