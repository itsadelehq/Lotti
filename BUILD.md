# Building Lotti yourself (macOS)

Lotti is a voice-to-text app. Building it on your own Mac signs it with **your** Apple ID, which makes the global push-to-talk key work reliably (a shared/ad-hoc copy can't reliably get the keyboard-tap permission).

## Requirements
- **Xcode** (free, Mac App Store)
- **Homebrew** (https://brew.sh)
- A free **Apple ID** (any Apple ID works for local signing)

## Steps

```bash
# 1. Tools + clone
brew install xcodegen
git clone https://github.com/itsadelehq/Lotti.git
cd Lotti
```

2. **Point it at your own Apple team.** Open `project.yml` and, under the `Lotti` target's `settings.base`:
   - Change `DEVELOPMENT_TEAM: NKB254W4BR` to **your** Team ID — *or* just delete that line and let Xcode manage signing.
   Also change the bundle-id prefix so it's unique to you: in `options`, set `bundleIdPrefix: com.<yourname>` (instead of `com.adele`).

3. Generate and open the project:
```bash
xcodegen generate
open Lotti.xcodeproj
```

4. In Xcode: select the **Lotti** target → **Signing & Capabilities** → tick **Automatically manage signing** → choose **your team** (add your Apple ID under Xcode → Settings → Accounts first). A free personal team is fine.

5. **Product → Archive** (or ⌘R to run). To keep a permanent copy, from the Archive window choose *Distribute App → Copy App*, then drag `Lotti.app` into **/Applications**.

## First launch
1. Open Lotti. Grant **Microphone** and **Accessibility** when asked.
2. **Important:** in **System Settings → Privacy & Security → Accessibility** *and* **Input Monitoring**, make sure **Lotti** is present and turned **ON**. If the key ever stops responding after you rebuild/replace the app, **remove Lotti (−) and re-add it (+)** in both lists — macOS ties the permission to the exact app binary.
3. Go through onboarding and enter **your own** Deepgram key (required, free credit at deepgram.com) and, optionally, an Anthropic key (for AI cleanup / note summaries).
4. Hold your push-to-talk key (default **Right Command ⌘**), speak, release — your words paste at the cursor.

## Notes
- Your API keys live in your Mac's Keychain and never leave your device.
- Fonts: the repo bundles open-source fonts (**Inter**, Lora, Instrument Serif), all under the SIL Open Font License. The original private build used the commercial **Aeonik Pro** font, which is not included — see [NOTICE.md](NOTICE.md) if you own a license and want that exact look locally.
- Cost: only your Deepgram usage (often $0 while the free credit lasts) + pennies for optional AI cleanup. No subscription.
