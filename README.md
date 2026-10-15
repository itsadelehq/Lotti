# Lotti

A native macOS voice-to-text app — press-and-hold a key, speak, release, and your
words are cleaned up and pasted into whatever app is focused. It's a personal,
open-source take on apps like Wispr Flow, built in Swift + SwiftUI.

- **Push-to-talk dictation** anywhere on your Mac (global hotkey, default Right ⌘)
- **Live transcription** via Deepgram (nova-3) with your own vocabulary boosting
- **Optional AI cleanup** via Claude Haiku — fixes punctuation, filler, homophones
- **Snippets** (voice text-expansion) and **Insights** (WPM, streaks, total words, per-app usage)
- Everything stays on your Mac; only audio (→ Deepgram) and transcript text (→ Claude) ever leave it

> ## 🔑 You bring your own API key
> Lotti does **not** come with any API keys, and there is no shared/hosted backend.
> Before it can transcribe anything you must **create your own free Deepgram
> account** and paste **your own** Deepgram API key into the app during onboarding.
> Your keys are stored in your **macOS Keychain** and never leave your device.
>
> 1. Sign up free at **[deepgram.com](https://deepgram.com)** (comes with signup credit).
> 2. Create an API key in the Deepgram dashboard.
> 3. Paste it into Lotti's onboarding screen (or Settings → Keys).
>
> An **Anthropic (Claude) API key is optional** — only needed if you want the AI
> cleanup / note-summary features. Without it, Lotti pastes Deepgram's text directly.

## Install

Lotti isn't notarized/distributed as a signed binary, so you build it yourself —
which also makes the global hotkey permission work reliably (it's signed with
*your* Apple ID). Full step-by-step guide: **[BUILD.md](BUILD.md)**.

Short version:

```bash
brew install xcodegen
git clone https://github.com/itsadelehq/Lotti.git
cd Lotti
xcodegen generate
open Lotti.xcodeproj   # then set your own signing team and Run (⌘R)
```

## Permissions (macOS)

On first launch, grant these in **System Settings → Privacy & Security**:

- **Microphone** — to capture your voice.
- **Accessibility** — for the global push-to-talk hotkey *and* pasting into other apps.
- **Input Monitoring** — for the hotkey.

> If the hotkey ever stops working after you rebuild/replace the app, **remove Lotti
> (−) and re-add it (+)** in both Accessibility and Input Monitoring — macOS ties
> the grant to the exact app binary.

## Cost

- **Deepgram** nova-3 streaming: ~$0.0077/min (often $0 while your free signup credit lasts).
- **Claude Haiku** cleanup (optional): roughly ~$1–4/mo at typical usage.
- Everything else is local and free. No subscription.

## Tech

Swift 6 + SwiftUI + AppKit, XcodeGen project, SwiftData for local history/stats,
Deepgram nova-3 over WebSocket, Claude Haiku for polish, CGEventTap for the global
hotkey, AVAudioEngine for capture, NSPasteboard + ⌘V for injection.

## License

Source code: **MIT** (see [LICENSE](LICENSE)).
Bundled fonts (Inter Tight, Lora, Instrument Serif) are under the SIL Open Font License —
see [NOTICE.md](NOTICE.md). The commercial Aeonik Pro font used in the original
private build is **not** included; the open build uses Inter Tight instead.
