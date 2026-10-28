# RaVqnat design language — modern, minimal, monochrome

Closer to Instagram / TikTok / Threads than to a "designed" app: the content is the colour.

## Principles
- **Monochrome UI.** Pure white / true black canvas, soft grey surfaces, near-black ink.
- **One accent, used tiny.** Pink (`accent`, #FF2E9A) is reserved for small signals only:
  the verified check, unread dots, the active-filter dot, the wordmark dot and event times
  (`accentText`, AA-safe). Never for large fills or buttons.
- **System type, tight and bold.** SF Pro throughout; large headings are bold with slightly
  negative tracking (`rvHero`). No serif or monospaced display faces.
- **Capsules and soft corners.** Capsule buttons and chips, 20 pt continuous-corner cards,
  no borders, no hard shadows. Elevation only where something floats (map pins, toasts).
- **Custom chrome.** Icon-only tab bar with a centre "+" (host) and the user's avatar as the
  Profile tab; hidden on pushed screens. Wordmark + round icon buttons as the Explore top bar;
  floating round back/share/more buttons over the activity cover.
- **Profiles like social apps.** Centred avatar, stats row, Edit / Verify buttons, bio,
  interest chips, icon tabs with an underline, 3-column portrait grid; settings behind ☰.

## Tokens (`Core/DesignSystem/Theme.swift`)
| Token | Light | Dark |
|---|---|---|
| canvas | #FFFFFF | #000000 |
| surfaceMuted | #F2F2F4 | #1C1C1F |
| ink | #0A0A0A | #FAFAFA |
| inkSecondary | #6B6B70 | #9A9AA0 |
| accent | #FF2E9A | #FF4FAE |

## Components
`PrimaryButtonStyle` (ink capsule), `SecondaryButtonStyle` (grey capsule), `PillButtonStyle`,
`IconButtonStyle` (round, grey or material over media), `FilterChip`, `StatusPill`,
`CategoryTag` (material capsule over covers), `OptionList` (grouped single choice),
`ProfileHeader` / `ProfileGrid`, `ActivityCoverArt` (faint oversized watermark + crisp symbol),
`Wordmark`.

Reduce Motion stops the welcome marquee, press-scale animations and skeleton shimmer.
