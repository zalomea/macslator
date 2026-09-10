# macslator

A small, floating translator for macOS. It sits above your other windows, opens from Spotlight, and translates as you type. Everything runs locally — nothing you translate ever leaves your Mac.

## Features

- **Two translation engines**
  - **Apple Translation** (default) — the native macOS translation framework. Fast, offline, good for everyday phrases.
  - **Local LLM** — an MLX model running on your Mac. Useful when you want more context for the translation and prefer to stay fully independent of Apple's engine.
- **Collapsible window** — click the app icon to shrink the whole thing to a small floating icon. Click the icon again to expand. When you expand, whatever is in your clipboard is dropped straight into the input.
- **Copy / paste / swap** — one-click buttons for the common actions.
- **Auto-translate** — starts translating a second after you stop typing, and cancels the moment you type again.
- **No title bar** — just a borderless floating panel you can drag anywhere by its background.
- **Your settings stick** — language pair, translation mode, and model choice are remembered between launches.

## Requirements

- macOS 15 or later
- Swift 6.0+ with Xcode Command Line Tools (or Xcode)
- An Apple Silicon Mac is recommended for local LLM translation (MLX runs best there)

## Install

Grab the latest `macslator-*.dmg`, open it, and drag **macslator** into your Applications folder:

1. Double-click `macslator-1.0.0.dmg` — it mounts as a disk image.
2. Drag the **macslator** app onto the **Applications** shortcut.
3. Press `Cmd + Space`, type **macslator**, and hit Return.

> The app is unsigned, so the first launch is: right-click the app → **Open** → **Open** again. You only do this once.

## Building from source

The project is plain Swift Package Manager — no Xcode project to open.

```bash
# Clone and build the .app bundle and a .dmg
git clone https://github.com/zalomea/macslator.git
cd macslator

./scripts/build_app.sh
open macslator-1.0.0.dmg
```

For quick iteration during development you can just run:

```bash
swift run
```

### Why does the build script exist?

SwiftPM can't compile the Metal shaders that MLX needs at build time. `scripts/build_app.sh` handles that: it compiles the binary, generates the app icon, then pulls a prebuilt `mlx.metallib` from a small Python environment and bundles it into the `.app`. It sets everything up automatically the first time you run it.

## Using a local LLM

Apple Translation handles most quick lookups well. For full sentences you can switch to a local model:

1. Open **Settings** (gear icon in the top-right).
2. Type a Hugging Face model id, or hit **Search** to browse `mlx`-tagged models and filter them by size.
3. Click **Load / Download**. The model is stored in `~/.cache/huggingface/hub` and reused on later launches, so you only download it once.
4. Switch the translator to **Local LLM** using the picker at the bottom.

A sensible starting point is a small instruction model like `mlx-community/Llama-3.2-1B-Instruct-4bit` — it's a good balance of speed and quality on Apple Silicon. You can also tune the max output tokens in Settings.

## Usage notes

- **Translate**: type or paste into the left panel. The result appears on the right.
- **Collapse**: click the app icon (top-left). It shrinks to a floating icon with a small arrow badge.
- **Expand**: click that icon again. The window returns to its previous size and the clipboard contents are inserted automatically.
- **Copy**: use the copy button above the translation panel.
- **Paste**: the paste button above the input does exactly what you'd expect.
- **Logs**: if something fails, the log viewer (magnifying-glass icon) shows what went wrong.

## Project layout

```
macslator/
├── Package.swift                  # SPM manifest (macOS 15+, Swift 6)
├── Resources/
│   ├── Info.plist                 # App metadata
│   └── Assets.xcassets/           # App icon
├── Sources/macslator/
│   ├── macslatorApp.swift         # App entry, floating window & collapse behavior
│   ├── Models/
│   │   ├── Language.swift         # Supported languages
│   │   ├── TranslationMode.swift  # Apple Translation vs Local LLM
│   │   ├── Translator.swift       # Debounce, cancellation, mode routing
│   │   ├── MLXLLMService.swift    # Model loading, download, cache management
│   │   ├── HuggingFaceAPIService.swift  # Model search on the HF hub
│   │   ├── SettingsStore.swift    # User defaults
│   │   ├── AppState.swift         # Window/app state
│   │   └── Logger.swift           # In-app log
│   └── Views/
│       ├── TranslatorView.swift   # Main UI, incl. collapsed icon state
│       ├── SettingsView.swift     # Model picker, search, cache controls
│       ├── LanguagePicker.swift   # Language dropdowns
│       ├── TranslationModePicker.swift  # Engine switcher
│       ├── AboutView.swift        # About dialog
│       ├── UsageView.swift        # In-app "How to use"
│       └── LogView.swift          # Log viewer
├── scripts/
│   ├── build_app.sh               # Builds the .app bundle and a .dmg
│   └── generate_icon.swift        # Regenerates the app icon
├── Tests/
│   └── macslatorTests/            # Unit tests (cleanTranslation, cache detection, HF model decoding)
├── .github/
│   └── workflows/                 # CI (build + test) and release (DMG upload) pipelines
└── README.md
```

## Why no Xcode project?

The whole point is a lightweight translator that's easy to read and tweak. Swift Package Manager plus a small build script keeps the repo small and sidesteps the churn of `.xcodeproj` files. One command produces a working `.app` and a `.dmg`.

## Credits

Developed by **zalomea** — [github.com/zalomea](https://github.com/zalomea).

Local LLM inference is powered by [MLX Swift](https://github.com/ml-explore/mlx-swift-lm) and model access via the [Hugging Face Hub](https://huggingface.co).

## License

Released under the [MIT License](LICENSE).

