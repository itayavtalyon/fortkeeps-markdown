# Fonts and licence

The package ships these files unchanged. `Sources/MarkdownViews/Resources/Fonts/` holds the shipped copy. This folder holds the reference copy. `FontFilesTests` checks both copies against the SHA-256 values below.

| File | Release tag | SHA-256 |
|---|---|---|
| `IBMPlexSans-Regular.ttf` | `@ibm/plex-sans@1.1.0` | `975dcda37d80f038dcd143c22e33ca2d97a0cc5a929aace1c749153b0fe1afa5` |
| `IBMPlexSans-Medium.ttf` | `@ibm/plex-sans@1.1.0` | `331c8639d7598b2cde62a911a71db195e30cb655cd6bdf2e324a7e984955f907` |
| `IBMPlexSans-SemiBold.ttf` | `@ibm/plex-sans@1.1.0` | `a20caf8286023a6a7a85e40b1d2a4ae9fc3e3b1f9eda8f4c542dd4986af67bb1` |
| `IBMPlexSans-Italic.ttf` | `@ibm/plex-sans@1.1.0` | `a9c6ef9942c49e49d11e11a6dacc0b3a087978757e9b22a06b8ac22a6400fb15` |
| `IBMPlexMono-Regular.ttf` | `@ibm/plex-mono@1.1.0` | `fe11304a5fe956d5744e9b6a246cc83d90425245e75a62230044966ca96a7f50` |
| `IBMPlexMono-Medium.ttf` | `@ibm/plex-mono@1.1.0` | `0bede3debdea8488bbb927f8f0650d915073209734a67fe8cd5a3320b572511c` |
| `IBMPlexMono-SemiBold.ttf` | `@ibm/plex-mono@1.1.0` | `c9417148ce13f8fa7d2d5c9180bbc141f72aa0d814ffeb280f6904dc2b1bbd7a` |
| `OFL.txt` | copied from remember-mac `design/fonts/OFL.txt` | `7e6b2818edbd8f6a01ae80641cc8f16a51080d08fb4e532be3a0b6f74adb07da` |

- Source: `github.com/IBM/plex`, file `packages/plex-sans/fonts/complete/ttf/<file>` (or `plex-mono`) at the tag above.
- Licence: SIL Open Font License 1.1. Full text: `OFL.txt`.
- "Plex" is a Reserved Font Name. A subset or modified font must be renamed.
- The Acknowledgements screen lists "IBM Plex (SIL OFL 1.1)".
- Body text uses the system font. Plex has no Hebrew glyphs; the system font renders them.
- The remember-mac Plex Mono files are not used. Their bytes match no IBM release, so no tag can be recorded for them.
