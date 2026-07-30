# App Review Notes — BarLoop 1.0

BarLoop is a native SwiftUI drum-practice utility. It does not wrap the BarLoop
website. Local playback uses AVFoundation, the metronome uses AVAudioEngine,
practice data uses SwiftData, and MIDI control uses Core MIDI.

## Review path

1. Open **Metronome** and tap the large Play button. Change BPM, subdivision,
   accents, swing, and Gap Click without loading media.
2. Open **Training**, choose a preset, edit sequencer cells, enable Moving
   Accent, and start training.
3. Open **Practice** and import an audio/video file supplied by the reviewer.
   Set A and B, enable looping, and optionally play the metronome with media.
4. For YouTube, paste any embeddable public YouTube URL. The app uses the
   official IFrame Player API and does not download or separate media.
5. Open **History** to see locally recorded sessions.
6. Open **Settings** to test MIDI mappings and JSON backup/export.

## Background audio

Background Audio is used only for user-initiated local media and metronome
practice. Local video supports system Picture in Picture. YouTube background
behavior is not bypassed and remains controlled by the official player.

## Privacy

No account, ads, developer analytics, or developer-operated server are used.
Imported media and practice data remain on device. YouTube is loaded only after
the user explicitly supplies a URL, and its third-party handling is disclosed
in-app and in the privacy policy.

## Demo account

No account is required.

