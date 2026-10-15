# Third-party notices

## Fonts

Lotti bundles the following fonts, each under the **SIL Open Font License 1.1**
(free to use, bundle, and redistribute):

- **Inter Tight** — © The Inter Project Authors (Rasmus Andersson). Main UI sans. License: `licenses/InterTight-OFL.txt`.
- **Lora** — © The Lora Project Authors (Cyreal). Serif used for numerals. SIL OFL 1.1.
- **Instrument Serif** — © The Instrument Serif Project Authors. Display serif for the quote. SIL OFL 1.1.

### A note on Aeonik Pro (not included)

The original private build used **Aeonik Pro** (a commercial font by CoType
Foundry). It is **intentionally not part of this repository** — it is a paid,
licensed font and cannot be redistributed. The open-source build uses **Inter
Tight** instead, which looks close. If you own an Aeonik Pro desktop license and
want that exact look in your own local build, just drop the `AeonikPro-Regular`,
`AeonikPro-Medium`, `AeonikPro-SemiBold`, and `AeonikPro-Bold` `.ttf` files into
`Lotti/Resources/Fonts/` — the app detects them automatically and prefers Aeonik
Pro over Inter Tight. Those files are gitignored, so they are never committed.

## Services

Lotti talks to two third-party APIs using **your own** API keys (stored in your
macOS Keychain, never in this repo):

- **Deepgram** — speech-to-text (required). Free signup credit at deepgram.com.
- **Anthropic (Claude)** — optional AI cleanup / note summaries.
