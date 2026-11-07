# Noboru – PS Vita Manga Reader

**An updated version of NOBORU for PlayStation Vita and PS TV.**

Noboru is a manga and comic reader for the PlayStation Vita. It allows you to browse manga sources, read manga online, download chapters, and manage your personal manga library.

This repository contains an updated version of the original NOBORU project, with additional features, improvements to website compatibility, image loading, reader functionality, and networking.

> **Important:** I am not the original creator of NOBORU. This project is based on the original open-source application, with modifications and additional features.

[Download](https://github.com/limeking614-dev/NOBORU-UPDATE/releases) | [Report a Bug](https://github.com/limeking614-dev/NOBORU-UPDATE/issues) | [Original NOBORU](https://github.com/Creckeryop/NOBORU)

---

## Features

Noboru provides several features designed to make reading manga on the PS Vita easier.

### ✨ UI Refresh (`feature/ui-refresh`)

This branch updates the interface and improves loading, memory use, and storage access.

- Redesigned sidebar navigation, headers, footer panels, cards, dialogs, notifications, and loading indicators with shared UI components.
- Updated Library, History, catalogs, search and filter panels, Settings, Downloads, import screens, update notes, and Cloudflare checks for consistent layouts and controls.
- Improved controller focus, touch targets, scrolling bounds, and empty-library feedback.
- Consistent sentence-case labels and clearer text wrapping and truncation.
- Shared, time-based animations for panels, dialogs, selections, reader overlays, and Webtoon transitions, with scrolling that adapts to frame timing.
- Startup loading messages and progress updates remain visible while fonts and saved chapters are checked.

#### Configurable manga grids

Library, History, and manga catalogs share the same configurable cover layout. In Settings, choose **Display mode** and **Grid columns**:

| Display mode | Title placement |
|---|---|
| Compact grid | Titles overlaid on covers |
| Comfortable grid | Titles below covers |
| Cover-only | Covers without title captions |

Each mode supports **3, 4, or 5 covers per row**. The default is **Compact grid with 4 columns**. Cover sizing, touch targets, controller navigation, and scrolling follow the selected layout.

#### Themes and multilingual fonts

- Added **Midnight**, **Forest**, **Sepia**, and **OLED** themes alongside Light, Dark, Blue, Crimson, and PiCrestOne. Existing saved theme choices remain supported.
- Shared theme colors now cover panels, reader controls, the clock, notifications, selection highlights, and status indicators, with contrasting text for colored surfaces.
- Bundled **Source Sans 3 Regular and SemiBold** for UI text, with the existing multilingual fonts loaded on demand for text containing unsupported glyphs.
- Text drawing and measurement use the same font fallback to keep alignment and wrapping consistent. Startup font warmup focuses on the selected language.

#### Manga details and downloads

- Reworked the details screen with clearer manga information, a scrollable summary, chapter selection, and Start/Continue actions.
- Improved chapter read-state indicators and touch/controller handling for reading, downloading, stopping downloads, and deleting downloaded chapters.
- Clearer download queue states and progress indicators, including preparing, queued, and downloaded chapters.

### 📚 Manga Catalog

- Browse manga and comic sources.
- Search for manga from supported websites.
- Browse available manga chapters.
- Add custom manga websites where supported.
- Refresh and manage your available catalogs.

**Note:** Available sources depend on website compatibility and the installed catalog parsers. Currently, the catalog includes AsuraScans and MangaTown.

### 📖 Manga Reader

- Read manga and comics directly on your PS Vita.
- Vertical reading orientation.
- Webtoon-style continuous scrolling.
- Full touchscreen support.
- Swipe gestures and double-tap controls.
- Custom reading direction and zoom settings.
- Support for long manga pages.
- Download chapters for offline reading.

### ⚡ Performance Improvements

- JPEG image loading for faster image display.
- Smaller JPEG chapter covers.
- Improved handling of manga chapter images.
- Better compatibility with different website layouts.
- Improved handling of lazy-loaded images.
- Cover loading follows the visible grid area and releases images as they leave the loading window.
- Library lists and sorting are cached; external-storage availability is refreshed periodically instead of being checked for every draw.
- Cache and downloaded-chapter folder sizes are calculated in bounded background work to keep Settings responsive.
- Loading library, history, cache, and chapter indexes avoids unnecessary disk rewrites; cache and chapter validation saves repairs when needed.
- The reader prioritizes the current page, limits nearby-page prefetching when GPU memory is low, and releases page textures and pending work when switching chapters.
- Image decoding checks dimensions and estimates texture memory using the actual decode size, including sliced long pages.
- Failed sliced-image loads release partial textures and restart from their own file or download, improving retry and cancellation handling.

### 🕒 Reader Clock

The updated reader includes clock options so you can see the time while reading.

Available settings:

- Enable or disable the reader clock.
- Display the current time.
- Display the current date.
- Choose the clock position.
- Switch between 12-hour and 24-hour time formats.

### 🔊 Interface Sounds

- Added menu sound effects.
- Button sounds when navigating the application.
- Option to enable or disable interface sounds in Settings → Controls.

### 🌐 Website Compatibility

Additional website-reading improvements include:

- Better handling of different website layouts.
- Support for additional manga website engines.
- Improved chapter image detection.
- Handling of websites that use JavaScript-generated chapter data.
- Online website profiles using community source-list information.

---

## ☁️ Cloudflare Support – PC Bridge

Some manga websites use Cloudflare protection, which can prevent the PS Vita from accessing their pages directly.

The optional PC Bridge provides another way to access supported websites.

### How it works

1. Run the PC Bridge application on your Windows computer.
2. Connect your PS Vita and computer to the same network.
3. Configure the bridge using the provided PC server files.
4. Open Noboru and access a website that requires the bridge.
5. Noboru can use the PC connection to help retrieve content from supported websites.

**Important:** The PC Bridge does not guarantee access to every Cloudflare-protected website. Some websites may still block requests.

---

## 📦 Offline Manga Reading

You can also read manga that you already have stored on your PS Vita.

Supported import options:

- Individual CBZ files.
- ZIP archives.
- Folders containing manga images.
- Folders containing multiple manga folders.

Supported image formats:

- JPG / JPEG
- PNG
- BMP
- GIF

**Note:** WebP images are not supported directly. CBR/RAR archives are also currently unsupported.

---

## Installation

### Requirements

- PlayStation Vita or PS TV.
- HENkaku / Ensō.
- VitaShell.
- Internet connection for online reading.
- Approximately 50–60 MB of available memory for online reading.
- More than 100 MB recommended for offline reading.

### Installing Noboru

1. Visit the [GitHub Releases page](https://github.com/limeking614-dev/NOBORU-UPDATE/releases).
2. Download the latest available VPK.
3. Transfer the VPK to your PS Vita.
4. Open VitaShell.
5. Locate the downloaded VPK.
6. Press X to install.
7. Launch Noboru from the LiveArea.

---

## 📁 Application Data

Noboru stores its application data in the following directory:

`ux0:data/noboru/`

| Folder / File | Description |
|---|---|
| `cache/` | Cached manga information and history |
| `chapters/` | Downloaded manga chapters |
| `import/` | Local manga files |
| `parsers/` | Manga catalog parsers |
| `cusettings/` | Individual manga settings |
| `save.dat` | Library information |
| `settings.ini` | Application settings |
| `siteprofiles.lua` | Website profile information |

**Backing up your data:** Make a copy of your Noboru data folder before reinstalling or resetting the application.

---

## ❗ Known Issues

Noboru is still being improved. Some websites may not work correctly.

Possible issues include:

- Some manga sources may fail to load.
- Certain chapters may not display their images.
- Some websites may use Cloudflare protection.
- Some websites may have unsupported layouts.
- Some parsers may stop working when a website changes.
- Image loading can depend on your internet connection.

If you experience a problem, please report it through the [GitHub Issues page](https://github.com/limeking614-dev/NOBORU-UPDATE/issues).

When reporting an issue, include:

- The manga website or source.
- The manga title.
- The chapter that failed.
- A screenshot of the error, if possible.

---

## 🛠️ Building From Source

This project uses Lua and packages the bundled NOBORU PlayStation Vita runtime, assets, and fonts into a VPK.

### Linux / POSIX shell

Install [VitaSDK](https://vitasdk.org/) and ensure `vita-pack-vpk` is on your `PATH`. From the repository root, run:

```sh
./build.sh
```

The default output is `Noboru-UI.vpk`. To choose another output path:

```sh
./build.sh /path/to/Noboru.vpk
```

The package includes Source Sans 3, its license, and the existing multilingual fallback fonts.

### Windows

From the repository root, run [build.bat](./build.bat) with `vita-mksfoex` and `7z` available. This generates `Noboru.vpk` from the contents of [source/](./source/).

### Regression checks

The branch adds standalone Lua checks for UI layout and input, catalog startup, filters, manga details, menus, remaining screens, Cloudflare checks, fonts, theme contrast, grid settings and navigation, animation timing, image retries, and catalog/reader performance.

With Lua 5.2 or later installed, run the branch checks from the repository root, each in its own process:

```sh
for test in spec/*_test.lua; do
  lua "$test" || exit 1
done
```

The existing language checks use LuaJIT and can be run separately with `sh test.sh`. These host-side checks mock Vita APIs; visual rendering, touch feel, and performance on hardware still require a PS Vita or PS TV.

---

## Credits and Original Authors

This project would not exist without the original developers and contributors.

- **[Creckeryop](https://github.com/Creckeryop/NOBORU)** – Original NOBORU application and development.
- **[Rinnegatamante](https://github.com/Rinnegatamante/lpp-vita)** – Lua Player Plus for PS Vita.
- **[VitaSDK](https://github.com/vitasdk)** – PlayStation Vita development tools.
- **[Adobe Source Sans 3](https://github.com/adobe-fonts/source-sans)** – UI typeface, distributed under the [SIL Open Font License 1.1](./source/SourceSans3-LICENSE.md).

Additional contributors and translators are credited in the original project.

---

## About This Project

This is an independently maintained update to the original NOBORU application.

The purpose of this project is to improve the manga-reading experience on the PS Vita, introduce additional features, improve website compatibility, and keep the application useful for the PS Vita homebrew community.

I am not the original author of NOBORU. All original development credit belongs to the original developers.

**Thank you to everyone supporting the PS Vita homebrew community!** ❤️
