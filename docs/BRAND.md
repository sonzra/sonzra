# Sonzra brand system

## Positioning
Sonzra is a self-hosted, open-source audio player for Jellyfin libraries: music, podcasts, and audiobooks. The identity should feel private, community-built, technically elegant, and alive.

## Logo
The core mark is an **S constructed from waveform bars**. Preserve generous clear space and never distort or rotate the static master mark. Use the monochrome asset when gradients are unavailable.

## Dynamic states
The shape remains recognizable while motion communicates application state:
- `idle`: static master mark
- `playing`: gentle pulse
- `loading`: continuous rotation or sequential bar sweep
- `buffering`: intermittent wave/flicker
- `connecting`: cyan-biased glow
- `paused`: muted/desaturated
- `error`: red-biased treatment and brief shake

Respect `prefers-reduced-motion` in production.

## Palette
| Token | Hex | Use |
|---|---|---|
| Primary | `#7A5AF8` | Main actions, active navigation |
| Primary dark | `#5C3FD6` | Gradients, pressed states |
| Accent | `#43D7C6` | Live/connected states |
| Background | `#0C0C16` | Main canvas |
| Surface | `#171725` | Cards and navigation |
| Surface raised | `#252538` | Elevated controls |
| Text | `#F6F6FA` | Primary text |
| Danger | `#FF4568` | Error state |

## Typography
Use Inter or the operating system sans-serif stack. The lowercase wordmark is bold, compact, and friendly.

## Included assets
- `public/brand/sonzra-mark.svg`
- `public/brand/sonzra-wordmark-dark.svg`
- `public/brand/sonzra-mark-monochrome.svg`
- browser favicons from 16–128 px
- Apple touch icon
- PWA icons at 192, 512, and 1024 px
- original concept board in `docs/sonzra-brand-board.png`
