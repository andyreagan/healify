# Healify

[![CI](https://github.com/andyreagan/healify/actions/workflows/ci.yml/badge.svg)](https://github.com/andyreagan/healify/actions/workflows/ci.yml)

Native iOS app for wound healing tracking. Photograph one or more wounds over time, keep structured notes (pain, symptoms, clinician guidance), and — if you opt in — get an **on-device** healing-progress estimate plus a projected timeline.

Photo journal = core. Everything else builds on it.

## Features

- **Native (Swift/SwiftUI)** — chosen for photo-first work the web can't match:
  `ImageIO` EXIF capture timestamps, on-device **Vision**/**Core Image** analysis
  with no network bridge, first-class **PhotoKit**/camera capture.
- **Multiple wounds**, each with its own journal, notes, type, and healed-goal.
- **Photo journal** grouped by day, with baseline (first) photo and "Day N"
  labels. Take photo or import from library.
- **Adjustable timestamps** — seeded from EXIF, editable per photo, one-tap
  reset to original.
- **Structured notes** — timestamp, optional 0–10 pain, symptom flags (with
  infection warnings), clinician-guidance notes carrying expected
  time-to-heal.
- **Opt-in, on-device healing analysis** (off by default):
  - 0–100 healing score per photo, relative to baseline.
  - "then & now" comparison plus score trend chart.
  - Projected healed-by date blending photo trend with any clinician estimate.
- **Private by design** — all data (wounds, notes, photos) stays on-device: no
  cloud, no analytics. Store survives updates via versioned schema + migration
  plan (`SchemaVersions.swift`); **Settings → Export/Import backup** writes one
  self-contained JSON (data *and* embedded photos) for reinstalls or moving phones.

> Healing scores are a wellness heuristic from photo color and appearance — not
> a medical diagnosis. The app states this explicitly and gates analysis behind
> a one-time disclaimer.

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

Xcode project generated from `project.yml` with
[XcodeGen](https://github.com/yonima/XcodeGen):

```sh
brew install xcodegen   # if needed
xcodegen generate
open Healify.xcodeproj
```

Then select iOS 17+ simulator or device and run. Camera needs real device;
Simulator falls back to library import.

### Running on your own iPhone (free Apple ID works)

1. `xcodegen generate && open Healify.xcodeproj`
2. Select **Healify** target → **Signing & Capabilities** → check
   *Automatically manage signing*, pick your **Personal Team** (free
   Apple ID fine).
3. On bundle-ID clash, change **Bundle Identifier** to something
   unique (e.g. `com.yourname.healify`).
4. Plug in iPhone, select as run destination, press Run.
5. On phone: **Settings → General → VPN & Device Management** → trust your
   developer certificate. (Free-account builds expire after 7 days — re-run
   from Xcode to refresh.)

## How the healing score works

For each photo the analyzer computes two on-device signals:

1. **Inflammation index** — the red channel's share of total color
   (`CIAreaAverage`). Angry/inflamed tissue skews red; a falling value across
   the series is the primary healing signal.
2. **Feature print** — a Vision descriptor of the image's overall appearance;
   measures how much each photo diverges from baseline and how much
   it stabilized vs. the previous photo.

These blend (60% inflammation reduction, 25% divergence-from-baseline,
15% frame-to-frame stabilization) into a 0–100 score. The timeline does an
ordinary-least-squares fit of score vs. time, extrapolates to the wound's
target score, and blends with any clinician-provided expected duration.

Intentionally interpretable, not a black box — and deliberately labeled an
estimate, not medical advice.