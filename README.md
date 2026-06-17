# Healify

[![CI](https://github.com/andyreagan/healify/actions/workflows/ci.yml/badge.svg)](https://github.com/andyreagan/healify/actions/workflows/ci.yml)

A native iOS app for tracking wound healing. Photograph one or more wounds over
time, keep structured notes (pain, symptoms, clinician guidance), and — if you
opt in — get an **on-device** estimate of healing progress and a projected
timeline.

The photo journal is the core. Everything else builds on it.

## Features

- **Native (Swift/SwiftUI)** — chosen for photo-first work the web can't match:
  `ImageIO` EXIF capture timestamps, on-device **Vision**/**Core Image** analysis
  with no network bridge, and first-class **PhotoKit**/camera capture.
- **Multiple wounds**, each with its own journal, notes, type, and healed-goal.
- **Photo journal** grouped by day, with a baseline (first) photo and "Day N"
  labels. Take a photo or import from the library.
- **Adjustable timestamps** — seeded from EXIF, editable per photo, with a
  one-tap reset to the original.
- **Structured notes** — timestamp, optional 0–10 pain, symptom flags (with
  infection warnings), and clinician-guidance notes that carry an expected
  time-to-heal.
- **Opt-in, on-device healing analysis** (off by default):
  - A 0–100 healing score per photo, relative to the baseline.
  - A "then & now" comparison and a score trend chart.
  - A projected healed-by date that blends your photo trend with any
    clinician estimate.

> Healing scores are a wellness heuristic from photo color and appearance — not
> a medical diagnosis. The app makes this explicit and gates analysis behind a
> one-time disclaimer.

## Project layout

```
Healify/
  HealifyApp.swift            App entry + SwiftData container
  Models/                     Wound, WoundPhoto, JournalNote (SwiftData @Model)
  Storage/ImageStore.swift    On-disk image storage + thumbnails
  Imaging/
    ExifReader.swift          Reads original capture date from metadata
    HealingAnalyzer.swift     Core Image redness + Vision feature print
    HealingScoring.swift      Per-photo 0–100 score vs. baseline
    HealingTimeline.swift     Projected healed-by date (trend + clinician)
  Services/                   HealingService, PhotoImporter, AppSettings
  Views/                      SwiftUI screens + components
  Resources/                  Info.plist, Assets
```

## Building

Requires **Xcode 15+** (iOS 17 deployment target).

The Xcode project is generated from `project.yml` with
[XcodeGen](https://github.com/yonima/XcodeGen):

```sh
brew install xcodegen   # if needed
xcodegen generate
open Healify.xcodeproj
```

Then select an iOS 17+ simulator or device and run. The camera requires a real
device; the Simulator falls back to library import.

### Running on your own iPhone (free Apple ID works)

1. `xcodegen generate && open Healify.xcodeproj`
2. Select the **Healify** target → **Signing & Capabilities** → check
   *Automatically manage signing* and pick your **Personal Team** (a free
   Apple ID is fine).
3. If you hit a bundle-ID clash, change **Bundle Identifier** to something
   unique (e.g. `com.yourname.healify`).
4. Plug in your iPhone, select it as the run destination, and press Run.
5. On the phone: **Settings → General → VPN & Device Management** → trust your
   developer certificate. (Free-account builds expire after 7 days — just
   re-run from Xcode to refresh.)

## Your data & safety

- **Where it lives:** structured data (wounds, notes, photo metadata, scores) in
  a local SwiftData/SQLite store under Application Support; photo JPEGs as files
  in `Application Support/WoundImages`; preferences in UserDefaults. No cloud,
  no analytics, all on-device. Included in iCloud/Finder device backups; wiped
  only if you delete the app.
- **Surviving app updates:** the store is driven by a **versioned schema +
  migration plan** (`SchemaVersions.swift`). Additive changes (new optional
  fields, new models) migrate automatically with no data loss. Structural
  changes get an explicit `MigrationStage` so existing data is preserved — the
  app never silently wipes the store.
- **Backups:** **Settings → Export backup…** writes a single self-contained
  JSON file (all structured data *and* every photo, embedded) you can save to
  Files or iCloud. **Settings → Import backup…** restores it — merging in
  anything not already present (idempotent; existing entries are skipped). This
  survives a full delete/reinstall or a move to a new phone, so it's the real
  safety net. Do an export before any risky update.

## Privacy

All photos and notes are stored on-device. There is no cloud sync and no
analytics. The image analysis runs entirely on-device.

## How the healing score works

For each photo the analyzer computes two on-device signals:

1. **Inflammation index** — the red channel's share of total color
   (`CIAreaAverage`). Angry/inflamed tissue skews red; a falling value across
   the series is the primary healing signal.
2. **Feature print** — a Vision descriptor of the image's overall appearance,
   used to measure how much each photo diverges from the baseline and how much
   it has stabilized vs. the previous photo.

These are blended (60% inflammation reduction, 25% divergence-from-baseline,
15% frame-to-frame stabilization) into a 0–100 score. The timeline does an
ordinary-least-squares fit of score vs. time, extrapolates to the wound's
target score, and blends that with any clinician-provided expected duration.

It is intentionally interpretable rather than a black box — and intentionally
labeled as an estimate, not medical advice.
