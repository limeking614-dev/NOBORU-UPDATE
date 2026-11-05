# Noboru – PS Vita Manga Reader

**An updated version of NOBORU for PlayStation Vita and PS TV.**

Noboru is a manga and comic reader for the PlayStation Vita. It allows you to browse manga sources, read manga online, download chapters, and manage your personal manga library.

This repository contains an updated version of the original NOBORU project, with additional features, improvements to website compatibility, image loading, reader functionality, and networking.

> **Important:** I am not the original creator of NOBORU. This project is based on the original open-source application, with modifications and additional features.

[Download](https://github.com/limeking614-dev/NOBORU-UPDATE/releases) | [Report a Bug](https://github.com/limeking614-dev/NOBORU-UPDATE/issues) | [Original NOBORU](https://github.com/Creckeryop/NOBORU)

---

## Features

Noboru provides several features designed to make reading manga on the PS Vita easier.

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

This project uses Lua and the NOBORU PlayStation Vita runtime.

To build the VPK:

1. Download or clone this repository.
2. Make sure the required build tools are installed.
3. Open the project folder.
4. Execute `build.bat`.
5. Wait for the build process to finish.
6. Locate the generated VPK.

---

## Credits and Original Authors

This project would not exist without the original developers and contributors.

- **[Creckeryop](https://github.com/Creckeryop/NOBORU)** – Original NOBORU application and development.
- **[Rinnegatamante](https://github.com/Rinnegatamante/lpp-vita)** – Lua Player Plus for PS Vita.
- **[VitaSDK](https://github.com/vitasdk)** – PlayStation Vita development tools.

Additional contributors and translators are credited in the original project.

---

## About This Project

This is an independently maintained update to the original NOBORU application.

The purpose of this project is to improve the manga-reading experience on the PS Vita, introduce additional features, improve website compatibility, and keep the application useful for the PS Vita homebrew community.

I am not the original author of NOBORU. All original development credit belongs to the original developers.

**Thank you to everyone supporting the PS Vita homebrew community!** ❤️
