# Lotti UI Style Guide (match Wispr Flow screenshots)

The screens must look **as close as possible to the provided Wispr Flow screenshots**,
rebranded as Lotti. Below are the exact tokens and per-screen layouts.

## Design Tokens

**Colors**
- `bg` window background: **#F5F4F1** (warm off-white/cream) — user-specified, use verbatim.
- `sidebarBg`: same #F5F4F1 (sidebar is same tone, slightly separated by inset).
- `card`: #FFFFFF for stat/insight cards, corner radius 16–20, very soft shadow
  (`.shadow(color: .black.opacity(0.04), radius: 8, y: 2)`), 1px hairline border `#00000010`.
- `cardMuted`: #F0EFEB for softer inset cards (e.g. Notetaker "no meetings" panel).
- `textPrimary`: #1A1A1A. `textSecondary`: #8A8A82 (warm gray).
- `teal` (primary accent, gauges/bars/active): **#0E5A4F** (dark teal); `tealDeep` #0B463D.
- `greenChip` bg #D8F0DF, text #1B7A4B (the "195% this month" pill).
- `orange` CTA: #F6A93B (the "Create report" button).
- Heatmap green scale (light→dark): `#EBEAE4` (empty), `#CDE8D6`, `#8FD3AB`, `#3FAE77`, `#0E5A4F`.
- `pillBlack`: #1B1B1D (floating pill + dark banner cards).

**Typography** — bundle **Google Sans** (variable fonts in `Branding/Google_Sans/`).
- Register the fonts and expose helpers: `Font.gsBold(_ size)`, `Font.gsMedium(_)`, `Font.gsRegular(_)`.
  If registration fails, fall back to system rounded.
- Large screen titles ("Welcome back, Adele", "Insights", "Notetaker"): Google Sans Bold ~34–40pt.
- Stat big numbers (343.8K, 106, 50,291): Google Sans Bold ~40–48pt, tight tracking.
- Labels/captions: Google Sans Medium/Regular 12–14pt, `textSecondary`, some UPPERCASED with letter-spacing.

**Logo** — use `Branding/Lottilogo.svg` (wordmark) in the sidebar header; if SVG can't render
directly, the mark is `Branding/Icon.svg` (three horizontal sound-wave strokes). Render the sidebar
brand as the icon + "Lotti" in Google Sans Bold, with a small "Pro" pill (`#EDE7FB` bg / `#6C4BD8` text)
matching the screenshot's "Flow Pro".

## Sidebar (all screens)
- Width ~230. Brand header top (icon + "Lotti" + Pro pill).
- Items with SF Symbol + label: Dictation(mic), Notetaker(record.circle), Insights(chart.bar),
  Dictionary(character.book.closed), Snippets(scissors), Style(textformat), Transforms(wand.and.stars),
  Scratchpad(note.text). Active item: rounded-rect highlight `#ECEBE6`, textPrimary; inactive: textSecondary.
- Only Dictation + Insights navigate; others show a "Coming soon" detail.
- Bottom: a small "Get the app" promo card is optional/omit; keep Settings + Help rows at the very bottom.

## Dictation home (screenshot 1)
- Title "Welcome back, Adele" (Google Sans Bold ~38).
- Two-column: main column + right rail (~320 wide).
- **Main:** a rounded dark banner card (image or `pillBlack` gradient), headline "Working around other
  people?" + subtext + light "Show me how" button + an ✕ dismiss. Then a `TODAY` section label, then the
  feed: each row = timestamp (textSecondary, ~70pt wide, left) + dictation text (textPrimary), separated by
  thin dividers `#00000008`.
- **Right rail card:** stacked stats — big value + small label: "{totalWords} total words", "{wpm} wpm",
  "{streak} day streak". Below it a card "Voice Profile Unlocked! / Discover your unique insights" +
  orange "Create report" button + ✕.

## Insights (screenshot 3)
- Title "Insights" + a circular "SHARE • SHARE •" badge top-right (decorative, teal outline).
- Segmented tabs: **Your usage / Your voice / Personal bests** (rename Wispr's "Leaderboard").
- **Your usage** grid (2 rows):
  - Row 1, three cards:
    1. WPM: big "{wpm}" + "WORDS PER MINUTE" + a **half-circle gauge** (teal arc on `#E7E6E0` track)
       with center label "Top {n}%".
    2. "Fixes made by Flow": big "{fixes}" + "FIXES MADE BY FLOW"; two sub-rows "{n} words corrected",
       "{n} dictionary fixes".
    3. "Total words dictated": big "{total}" + green chip "▲ {pct}% this month"; sub "Desktop {total} words"
       + a small "Download on mobile" ghost button.
  - Row 2, two cards:
    - "Desktop usage" — "TOTAL APPS USED | {n}" header; horizontal category bars with % fill in teal and
      a leading SF Symbol per category (AI Tools=cpu/robot, Messaging=message, Documents=doc, Email=envelope,
      Other=infinity), label like "95%  3,565 AI PROMPTS".
    - "{streak} day streak" — "LONGEST STREAK | {n} DAYS" header; a **GitHub-style heatmap**: 7 rows
      (Sun–Sat) × ~16 week columns, cells 12×12 rounded 3, colored by that day's word count using the green
      scale; month labels (Jun/Jul/Aug/Sep) across the top; "More ▢▢▢▢ Less" legend bottom-right.
- **Your voice:** simple cards — avg words/dictation, most active hour, longest dictation (derive from Store).
- **Personal bests:** best day (max words in a day), best week, longest streak (`stats.longestStreak`).

## Settings (screenshot-agnostic, same design system)
- Sections: Trigger key (a key-capture control showing current key; default right-⌘), Transcription engine
  (Deepgram active; Parakeet "coming soon" disabled), Polish (toggle), API keys (two SecureFields →
  Keychain accounts `deepgram_api_key` / `anthropic_api_key`), Permissions (Microphone + Accessibility
  status rows with a Re-check button).

## Data note
All numbers come from `Store.stats(now:)` and `store.all()`. With an empty store the screens must still
render gracefully (zeros, empty feed, empty heatmap) — seed nothing; show real state.
