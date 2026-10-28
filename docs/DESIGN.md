# RaVqnat design language — modern, minimal, monochrome

Closer to Instagram / TikTok / Threads than to a "designed" app: the content is the colour.

## Principles
- **Monochrome UI.** Pure white / true black canvas, soft grey surfaces, near-black ink.
- **Brand pink is a signature, not a theme.** Pink (`accent`, #FF2E9A) marks the wordmark dot,
  unread badges and the active-filter dot. Never large fills or buttons.
- **Colour lives in imagery.** Each category has a soft background and a deep tone
  (`ActivityCategory.softTint` / `.tint`) used for covers, story rings, map pins, chat icons,
  welcome chips and chip icons. Text always stays ink, so contrast is never at risk.
- **Trust is blue.** The verified badge uses `trust` (#2F6BFF), distinct from the brand.
- **System type, tight and bold.** SF Pro throughout; large headings are bold with slightly
  negative tracking (`rvHero`). No serif or monospaced display faces.
- **Capsules and soft corners.** Capsule buttons and chips, 20 pt continuous-corner cards,
  no borders, no hard shadows. Elevation only where something floats (map pins, toasts).
- **Custom chrome.** A floating tab bar: Home (grid), Map (location arrow), Messages (bubble)
  and Profile (avatar) share one frosted capsule. The current page widens into a pill showing
  its icon and name; the others are outline icons; the round ink "+" (host/create) sits on its
  own at the far right. Hold the current tab and drag sideways to scrub between pages (live
  switching with selection haptics, snaps on release). Hidden on pushed screens. Wordmark + round icon buttons as the Explore top bar;
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
| trust | #2F6BFF | #6FA0FF |

Category tones (light, deep / soft): music #6D4AFF / #EEE9FF · sports #12A150 / #E3F6E9 ·
learning #2F6BFF / #E6EEFF · tech #3B4A63 / #ECEFF4 · food #E8730C / #FFEEDF ·
arts #E0287D / #FFE7F2 · outdoors #2F7D4F / #E7F2EA · games #C28A00 / #FFF5D6 · other #5F6068 / #F0F0F2.

## Feed posts
Full-bleed: the cover spans the screen width with 32 pt continuous top corners and a straight
bottom edge; text below keeps the 20 pt screen margin.

## Tab bar icons
Custom icons are template images in Assets.xcassets named `tab-explore`, `tab-map`,
`tab-create` (the + button), `tab-chats` (plus optional `-selected` variants). Missing assets fall back to
SF Symbols.

## Components
`PrimaryButtonStyle` (ink capsule), `SecondaryButtonStyle` (grey capsule), `PillButtonStyle`,
`IconButtonStyle` (round, grey or material over media), `FilterChip`, `StatusPill`,
`CategoryTag` (material capsule over covers), `OptionList` (grouped single choice),
`ProfileHeader` / `ProfileGrid`, `ActivityCoverArt` (faint oversized watermark + crisp symbol),
`Wordmark`.

Reduce Motion stops the welcome marquee, press-scale animations and skeleton shimmer.
