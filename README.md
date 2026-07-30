# BarLoop for iOS

BarLoop is a native SwiftUI practice companion for drummers. It combines local
audio/video and YouTube loop practice, a low-latency metronome, drum-pattern
training, MIDI control, and local-first practice history.

## Requirements

- Xcode 26 or newer
- iOS/iPadOS 17 or newer
- XcodeGen 2.46 or newer (`brew install xcodegen`)

## Generate and open the project

```bash
xcodegen generate
open BarLoop.xcodeproj
```

The checked-in `BarLoop.xcodeproj` is generated from `project.yml`. Regenerate it
after changing targets, build settings, or resources.

## Tests

The domain layer is a standalone Swift package so its regression suite can run
without an iOS simulator:

```bash
swift test --package-path Packages/BarLoopCore
```

If only the standalone Command Line Tools are installed and SwiftPM reports a
manifest-library mismatch, the same core can still be compiled and exercised:

```bash
swiftc Packages/BarLoopCore/Sources/BarLoopCore/*.swift \
  Scripts/CoreSmokeTests.swift \
  -o /tmp/barloop-core-smoke
/tmp/barloop-core-smoke
```

With Xcode installed, run the complete app suite:

```bash
xcodebuild test \
  -project BarLoop.xcodeproj \
  -scheme BarLoop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Privacy

Media and practice data stay on the device. YouTube playback uses the official
embedded player and requires a network connection. See `docs/privacy.html`.
