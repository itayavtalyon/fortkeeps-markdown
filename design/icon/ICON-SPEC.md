# FK Scroll — Icon Spec

Sources: `/workspace/fortkeeps/BRAND.md` (locked palette, one keep glyph, flat solid ink on stone rounded square, Plex Sans SemiBold), `brand-app-icon.png`, PR itayavtalyon/fortkeeps-markdown#1 (WAIT-4 = this icon; files .md/.markdown/.txt/.mdown/.mkd). The Remember brand (purple/amber, stroked) is a different family, so it was not used.

## Concepts
- **A: Scroll Keep (chosen).** A vertical scroll whose top roll has the Fortkeeps crenellations (the keep's merlons), a flat ink sheet, and a bottom roll with curled ends. The Markdown down-arrow is cut out of the sheet in stone. `concepts/A-scroll-keep*.svg`
- **B: Keep + Banner.** The Fortkeeps tower glyph with a scroll banner reading "M↓". `concepts/B-keep-banner*.svg`

**Why A:** it reads as Fortkeeps (crenellations, flat ink on stone) and as a *document* (rolled scroll) in one silhouette. It stays legible at 16px: the crenellated outline survives, and the arrow is still visible from 32px up. B's banner and "M" text turn to mush below 64px, and B looks like the main Fortkeeps app with a sticker on it, which confuses the two on a home screen.

## Palette (from BRAND.md)
| Token | Hex | Use |
|---|---|---|
| Ink | `#1C2430` | glyph (light) |
| Stone | `#E8E0D4` | icon background, glyph cut-outs, doc fold |
| Keep blue | `#1B3A5F` | doc "MD" label |
| Paper | `#FAFAF8` | doc page |
| Night | `#11161D` | iOS dark background (glyph turns stone) |
| Mute | `#5C6570` | — |

## Grid
- Master 1024 canvas. The glyph sits in the 250–780 vertical / 270–754 horizontal box, centred on 512, with flat fills and no strokes (matching the Fortkeeps solid glyph).
- macOS: an 824×824 rounded rect at a 100px margin, corner radius 185 (Apple macOS Big Sur+ grid). Soft drop shadow (y+10, blur 12, 28%) and a 1px 8% edge. Glyph scaled to 0.9 inside it.
- iOS: full-bleed 1024 opaque square with no mask (the system applies the mask).
- Dark: Night background with a Stone glyph. Tinted: a grayscale (white glyph on black) the system tints, per iOS 18.
- Accessibility: identity comes from shape (crenellated scroll and arrow cut-out), not colour. High contrast: Ink on Stone ≈ 12:1. The doc label is text ("MD") as well as colour.

## Files
- `FKScroll-AppIcon-master.svg` (iOS full-bleed), `FKScroll-AppIcon-macOS.svg`, `FKScroll-AppIcon-iOS-dark.svg`, `FKScroll-AppIcon-iOS-tinted.svg`
- `macos/icon_{16,32,128,256,512}x{…}[@2x].png`, `icon_64x64.png`, `icon_1024x1024.png`
- `ios/AppIcon-1024.png`, `AppIcon-1024-dark.png`, `AppIcon-1024-tinted.png` (RGB, no alpha)
- `doc/FKScroll-Document.svg`, `doc/macos/doc_{16..512}[@2x].png`
- `AppIcon.appiconset-macOS/`, `AppIcon.appiconset-iOS/` (drop-in, with Contents.json)
- `contact-sheet.png`, `build.py` (regenerates everything: `python3 build.py`)

## Xcode asset catalog
```
Assets.xcassets/
  AppIcon.appiconset/        # iOS/iPadOS target
    Contents.json  AppIcon-1024.png  AppIcon-1024-dark.png  AppIcon-1024-tinted.png
  AppIcon-macOS.appiconset/  # or same name in the macOS target's catalog
    Contents.json  icon_16x16.png … icon_512x512@2x.png
```
iOS Contents.json:
```json
{"images":[
 {"idiom":"universal","platform":"ios","size":"1024x1024","filename":"AppIcon-1024.png"},
 {"idiom":"universal","platform":"ios","size":"1024x1024","filename":"AppIcon-1024-dark.png","appearances":[{"appearance":"luminosity","value":"dark"}]},
 {"idiom":"universal","platform":"ios","size":"1024x1024","filename":"AppIcon-1024-tinted.png","appearances":[{"appearance":"luminosity","value":"tinted"}]}],
 "info":{"author":"xcode","version":1}}
```
macOS Contents.json: 10 entries, `idiom: mac`, sizes 16/32/128/256/512 at 1x and 2x. See `AppIcon.appiconset-macOS/Contents.json`.

## Document types (Info.plist)
The app uses the system `net.daringfireball.markdown` UTI (macOS 13+/iOS 16+ declare it), imported here so older systems and the extra extensions resolve. `.txt` stays `public.plain-text` and keeps the system's icon.
```xml
<key>UTImportedTypeDeclarations</key>
<array><dict>
  <key>UTTypeIdentifier</key><string>net.daringfireball.markdown</string>
  <key>UTTypeDescription</key><string>Markdown Document</string>
  <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
  <key>UTTypeIconFile</key><string>FKScrollDocument</string>
  <key>UTTypeTagSpecification</key><dict>
    <key>public.filename-extension</key>
    <array><string>md</string><string>markdown</string><string>mdown</string><string>mkd</string></array>
    <key>public.mime-type</key><array><string>text/markdown</string></array>
  </dict>
</dict></array>
<key>CFBundleDocumentTypes</key>
<array><dict>
  <key>CFBundleTypeName</key><string>Markdown Document</string>
  <key>CFBundleTypeRole</key><string>Editor</string>
  <key>LSHandlerRank</key><string>Default</string>
  <key>CFBundleTypeIconFile</key><string>FKScrollDocument</string>  <!-- macOS: build FKScrollDocument.icns from doc/macos via iconutil -->
  <key>LSItemContentTypes</key><array><string>net.daringfireball.markdown</string></array>
</dict>
<dict>
  <key>CFBundleTypeName</key><string>Plain Text</string>
  <key>CFBundleTypeRole</key><string>Editor</string>
  <key>LSHandlerRank</key><string>Alternate</string>
  <key>LSItemContentTypes</key><array><string>public.plain-text</string></array>
</dict></array>
```
Make the .icns with: `mkdir FKScrollDocument.iconset && cp doc/macos/doc_*.png` into it, renamed `icon_*`, then run `iconutil -c icns FKScrollDocument.iconset`.

**iOS/iPadOS:** document icons are generated by the system from the app icon (Files shows the app icon on a page). `CFBundleTypeIconFiles` is ignored on modern iOS, so no iOS doc assets are needed.
