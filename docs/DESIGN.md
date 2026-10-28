# RaVqnat design language — "ink on paper, with a pink echo"

A middle ground between brutalist-editorial (black on white, big uppercase serif, monospaced
body, thick borders, invert-on-select) and a softer, illustrated iOS feel (warm dot-grid paper,
halftone screentone, hot pink used sparingly as an "afterimage").

## Principles
- **Ink first.** Almost everything is ink (#111) on warm paper (#F5F4F0). Colour is earned.
- **Pink is an echo, not a fill.** `accent` (#FF2E9A) appears as offset afterimages behind
  primary buttons, selected chips and symbols, the current onboarding step and the active tab.
  `accentText` (#C2126C) is the only pink allowed for text (AA contrast), used for times.
- **Editorial type.** New York serif for headlines (uppercase for Latin scripts via
  `rvHero`), SF Mono for small labels (`rvLabelStyle`), SF Pro for reading text.
  Georgian is never uppercased (that would turn Mkhedruli into Mtavruli).
- **Near-square geometry.** Radii of 3–6 pt, 1–2 pt ink borders, hard offset shadows
  (`echoShadow`) instead of blurred drop shadows.
- **Invert to select.** Selected rows, tags and checkboxes flip to solid ink with paper text.
- **Restraint.** No gradients as decoration, no glows, no chrome — this is not Y2K.

## Tokens (`Core/DesignSystem/Theme.swift`)
| Token | Light | Dark |
|---|---|---|
| canvas (paper) | #F5F4F0 | #121110 |
| surface | #FFFFFF | #1B1A18 |
| ink | #111111 | #F3F1EC |
| accent | #FF2E9A | #FF4FAE |
| accentText | #C2126C | #FF7AC0 |

## Components
- `PrimaryButtonStyle` — ink block with pink echo; pressing moves the face onto its echo.
- `SecondaryButtonStyle` — paper with ink border; inverts while pressed.
- `FilterChip`, `StatusPill`, `CategoryTag` — monospaced tags; selected chips invert + echo.
- `EditorialList` — numbered rows with serif titles, inverted when selected.
- `EchoText` / `EchoSymbol` — content with two trailing pink afterimages.
- `ActivityCoverArt` — screentone (dots / diagonal / grid per category) + echoed symbol.
- `DotPaper` — the dot-grid canvas behind every screen.

Reduce Motion disables the welcome ticker, button press animation and skeleton shimmer.
