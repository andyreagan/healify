# Healify

[![CI](https://github.com/andyreagan/healify/actions/workflows/ci.yml/badge.svg)](https://github.com/andyreagan/healify/actions/workflows/ci.yml)

Native iOS app for wound healing tracking. Photograph one or more wounds over time, keep structured notes (pain, symptoms, clinician guidance), and — if you opt in — get **on-device** healing-progress estimate plus projected timeline.

Photo journal = core. Everything else build on it.

## Features

- **Native (Swift/SwiftUI)** — chosen for photo-first work web can't match:
  `ImageIO` EXIF capture timestamps, on-device **Vision**/**Core Image** analysis
  with no network bridge, first-class **PhotoKit**/camera capture.
- **Multiple wounds**, each own journal, notes, type, healed-goal.
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

> Healing scores = wellness heuristic from photo color and appearance — not
> medical diagnosis. App states this explicit and gates analysis behind
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

For each photo analyzer computes two on-device signals:

1. **Inflammation index** — red channel's share of total color
   (`CIAreaAverage`). Angry/inflamed tissue skews red; falling value across
   series = primary healing signal.
2. **Feature print** — Vision descriptor of image's overall appearance,
   measures how much each photo diverges from baseline and how much
   it stabilized vs. previous photo.

Blended (60% inflammation reduction, 25% divergence-from-baseline,
15% frame-to-frame stabilization) into 0–100 score. Timeline does
ordinary-least-squares fit of score vs. time, extrapolates to wound's
target score, blends with any clinician-provided expected duration.

Intentionally interpretable, not black box — and intentionally
labeled estimate, not medical advice.