# Lotti — Design Spec

**Date:** 2026-09-20
**Status:** Approved (design), pending implementation plan
**Author:** Adele + Claude

## 1. Goals

Lotti is a native macOS voice-to-text app — a personal replacement for Wispr Flow.
It must feel **as fast or faster** than Wispr and match its core experience, while
cutting the cost from $15/mo to ~$1–4/mo.

Success criteria:
- Press-and-hold a configurable key → speak → release → polished text is pasted
  into whatever app is focused, with sub-second perceived latency.
- Insights that mirror Wispr: WPM, streaks, total words, fixes made, per-app usage.
- Runs entirely on the user's Mac; only audio (to Deepgram) and transcript text
  (to Claude Haiku) leave the device.

## 2. Non-Goals (v1)

Notetaker, Dictionary, Snippets, Style, Transforms, Scratchpad, mobile, and a
social leaderboard are **out of scope for v1**. The sidebar shell will show them
so they can be added later without restructuring.

## 3. Platform & Stack

- **OS:** macOS 26+ (Apple Silicon, arm64).
- **Language/UI:** Swift + SwiftUI, built in Xcode.
- **Local storage:** SwiftData (fallback SQLite) for dictation history + stats.
- **Secrets:** Deepgram + Anthropic API keys stored in the macOS **Keychain**.
- **Permissions required:** Microphone (audio capture), Accessibility (global
  hotkey monitoring + pasting into other apps).

## 4. The Dictation Interaction

The central feature. Three behaviors:

1. **Hold-to-talk:** press & hold the trigger key → **pop sound** + floating pill
   appears showing a live waveform → speak → **release key** → **end sound** →
   transcript is polished and pasted into the focused app.
2. **Hands-free lock:** press trigger key **+ spacebar** → pill stays on screen
   (locked), user speaks hands-free → press trigger key again to stop.
3. **Cancel:** the pill's **✕** discards; the **✓** confirms/stops (same as
   releasing the key).
4. **Configurable trigger key:** chosen in Settings, changeable anytime. Default
   candidate: right-`⌘` or `Fn`.

## 5. Components

Each component is isolated behind a clear interface so it can be tested and
swapped independently.

| Component | Responsibility | Key dependencies |
|---|---|---|
| `HotkeyManager` | Global key monitoring; emits start/stop/lock/cancel events for push-to-talk and the key+space lock gesture. | Accessibility permission, `CGEventTap`/`NSEvent` monitor |
| `AudioCapture` | Captures mic audio as 16kHz linear16 PCM; streams buffers to the engine; drives the waveform. | Microphone permission, `AVAudioEngine` |
| `TranscriptionEngine` (protocol) | Streams audio → interim + final transcripts. | — |
| ↳ `DeepgramEngine` | Deepgram Nova streaming over WebSocket (interim results on). Default engine. | Deepgram API key, `URLSessionWebSocketTask` |
| ↳ `ParakeetEngine` (future) | On-device fallback; drops in behind the same protocol. | (later) |
| `PolishService` | Raw transcript → Claude Haiku → cleaned/formatted text. Toggleable; tracks the diff for "fixes made". | Anthropic API key |
| `TextInjector` | Pastes final text into the focused app (pasteboard + ⌘V); records the frontmost app for per-app usage. | Accessibility permission, `NSWorkspace`, `NSPasteboard` |
| `FloatingPill` | Borderless, always-on-top, non-activating `NSPanel`; waveform + ✕/✓; plays pop/end sounds. | `NSPanel`, `NSSound` |
| `DictationCoordinator` | Orchestrates: hotkey → capture → engine → polish → inject → persist. | all of the above |
| `Store` | Persists each dictation (raw, polished, app, timestamp, duration, word count) and computes stats. | SwiftData |
| `Settings` | Trigger-key config, engine toggle, polish on/off, API keys, permission status. | Keychain |

## 6. Data Flow (one dictation)

```
key down ──► HotkeyManager ──► DictationCoordinator
                                  │  pop sound + show pill
                                  ▼
                            AudioCapture (16k PCM) ──► DeepgramEngine (WS)
                                  │                         │ interim text
                                  │◄────────────────────────┘
key up ──► stop ──► final transcript ──► PolishService (Haiku)
                                  │
                                  ▼
                          TextInjector (paste) + end sound
                                  │
                                  ▼
                              Store.save(dictation)  ──► Insights update
```

## 7. Screens

- **Dictation home:** "Welcome back, Adele" header; stats card (total words / WPM /
  day streak); voice-profile card; **TODAY** feed of past dictations with
  timestamps and the dictated text.
- **Insights:** tabs *Your usage / Your voice / Personal bests*.
  - Your usage: WPM gauge, "Fixes made" (words corrected by polish), total words
    dictated (with % change), **Desktop usage** by app category, GitHub-style
    streak heatmap (longest streak shown).
  - Your voice: voice-profile stats derived from the user's dictation history.
  - Personal bests: best day/week/streak (replaces Wispr's social leaderboard).
- **Settings:** trigger key, transcription engine, polish toggle, API keys,
  permissions status + prompts.
- **Sidebar shell:** Dictation, Notetaker, Insights, Dictionary, Snippets, Style,
  Transforms, Scratchpad — only Dictation/Insights/Settings active in v1.

## 8. Insights Definitions (v1)

- **WPM:** words in a dictation ÷ speaking duration; rolling display value.
- **Streak:** consecutive calendar days with ≥1 dictation; heatmap intensity by
  daily word count.
- **Total words dictated:** sum of final word counts; % change vs previous month.
- **Fixes made:** token/word-level diff between raw transcript and polished text.
- **Desktop usage:** frontmost app at inject time, bucketed into categories
  (AI tools, messaging, docs, email, other).

## 9. Cost Model

- **Deepgram Nova streaming:** ~$0.0077/min (~$0.46/hr); covered by signup credit
  initially. Engine is swappable to free on-device Parakeet if the credit runs out.
- **Claude Haiku polish:** $1/M input, $5/M output ≈ ~$1–4/mo at typical usage.
- **Everything else:** local, free.

## 10. Risks / Open Items

- **Latency budget:** target < ~700ms end-to-end (Wispr parity). Deepgram interim
  results + immediate paste on final. Measure early.
- **Paste vs. type:** pasteboard + ⌘V is fast and Unicode-safe but clobbers the
  clipboard — save/restore the previous clipboard contents.
- **Accessibility permission** is required for both hotkey and paste; app must
  guide the user through granting it on first run.
- **Deepgram credit amount** (user to confirm $20 vs $200) determines "free for a
  year" vs. ongoing cost; does not change the build.
