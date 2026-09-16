# Grammar Llama

Select text in any Mac app, press **⇧⌘E**, get three polished variants streamed in under a second, tweak or edit, then **Replace** or **Copy**. A menu bar utility in the CleanShot mould: no Dock icon, no account, your own Anthropic or OpenAI API key.

This repository holds the Mac app (`Sources/`, Swift + SwiftUI) and the landing page (`website/`, Next.js).

## Install

1. Download the latest `Grammar-Llama-x.y.z.zip` from [Releases](https://github.com/mukul13/grammar-llama/releases/latest).
2. Unzip and drag **Grammar Llama.app** to Applications.
3. First launch: right-click the app and choose **Open**. The build is signed but not yet notarized, so macOS asks once. If macOS still refuses, go to System Settings → Privacy & Security and click **Open Anyway**.
4. Follow the two-step onboarding: allow Accessibility, then paste an API key (Anthropic or OpenAI).
5. Select text anywhere and press ⇧⌘E. Grammar Llama lives in the menu bar as 🦙.

Requires macOS 14 or later on Apple silicon.

## Build from source

```bash
./scripts/build-app.sh --run
```

This builds `"build/Grammar Llama.app"` and launches it. First launch opens a two-step onboarding:

1. **Accessibility** access. Grammar Llama needs it to read the selection and put the rewrite back.
2. **Anthropic API key**, stored in your login Keychain.

Then select some text anywhere and press ⇧⌘E.

## Using the panel

| Key | Action |
| --- | --- |
| `1` `2` `3` | Select a variant |
| `↩` or `⌘↩` | Replace the selection with the chosen variant |
| `C` or `⌘C` | Copy the chosen variant |
| `E` | Edit the chosen variant in place (Esc when done) |
| `R` / `⌘R` | Regenerate one variant / all variants |
| `D` | Toggle the change highlighting |
| `Esc` | Close |

Type in the **Change something…** box, or click a chip like *Casual* or *Shorter*, to layer an instruction on top of the polite default. Tweaks stack and each one can be removed from the breadcrumb.

## Settings

Menu bar icon → **Settings…** (or ⌘,):

- **General**: shortcut recorder, number of variants (1 to 5), diff by default, force paste instead of Accessibility insert, launch at login.
- **Model**: API key, model (Opus 5 default, Sonnet 5, Haiku 4.5), effort level.
- **Prompt**: the default instructions and the quick tweak chips.
- **History**: last 50 rewrites with one-click copy.

## How it works

- `Sources/GrammarLlama/HotKey.swift` registers a system-wide Carbon hotkey.
- `TextCapture.swift` reads the selection through the Accessibility API, falling back to a simulated ⌘C that restores your clipboard afterwards.
- `PanelController.swift` shows a non-activating `NSPanel` anchored under the selection. The source app keeps focus.
- `ClaudeClient.swift` streams from the Messages API over raw HTTP with server-sent events. Variants run in parallel.
- `TextInsert.swift` writes the result back through Accessibility, verifying the write, and falls back to a clipboard paste.

## Release

```bash
./scripts/release.sh 0.1.0
```

Bumps the version, builds, zips the app and publishes a GitHub Release with the `gh` CLI.

## Landing page

```bash
cd website && npm install && npm run dev
```

Deploy on Vercel with **Root Directory** set to `website`. The download button points at the latest GitHub Release.

## Notes

- Distribution outside the App Store is the only option: the Accessibility API is not available to sandboxed apps.
- The build script signs with your Apple Development identity when present. With ad-hoc signing, macOS may ask you to re-grant Accessibility after each rebuild.
- Electron apps and terminals often hide the selection from Accessibility. The clipboard fallback covers them.
