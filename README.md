# Noboru – PS Vita Manga Reader

Noboru is a manga and comic reader for the PlayStation Vita and PS TV.

This repository contains an updated version of the original Noboru project, with additional reader features, website compatibility improvements, and network options.

> **Disclaimer:** I am not the original creator of Noboru. This project is an update based on the original open-source application by [Creckeryop](https://github.com/Creckeryop/NOBORU). Please see the credits below for the original project and other contributors.

## Features

- Browse supported manga and comic websites.
- Read manga online or offline.
- Download chapters for offline reading.
- Vertical reading orientation and touch controls.
- Continuous vertical scrolling for webtoon-style chapters.
- Manga tracking and reading history.
- Import local manga and comic files.
- Custom reading settings, including zoom and reading direction.
- Reader clock with time and date options.
- Optional menu sound effects.
- Improved image loading and website compatibility.
- Optional PC bridge for websites the PS Vita cannot access directly.

## What's new in this version?

This version adds site-loading, reader, and network improvements on top of the original Noboru project. More details are available in [CHANGELOG.md](CHANGELOG.md).

### JPEG image loading

Manga pages and chapter covers can be converted to JPEG to help reduce image sizes and improve loading performance.

Change this option under:

`Settings → Network → All pages + covers to JPEG`

### Improved website compatibility

The generic site reader has been improved to support more website layouts and ways of loading chapter images. This includes support for reader scripts and Next.js data, additional lazy-loading attributes, and layouts used by Madara and MangaThemesia sites.

### Online site profiles

Noboru can identify supported website engines and use online source-list information to help recognize a site's name, language, and other details.

**Important:** Aidoku's executable extensions cannot run in Noboru. This feature uses the published source-list data only.

Additional source-list URLs can be added, one per line, in:

`ux0:data/noboru/profile_sources.txt`

### Reader clock

Display the time, date, or both while reading manga.

Available settings:
- Off
- Time
- Date
- Time + Date
- 12-hour or 24-hour time
- Top-left or top-right position

Find these options under:

`Settings → Reader`

### Webtoon reader

Read a complete chapter using continuous vertical scrolling instead of moving between individual pages. This mode is also available when using vertical orientation.

### Optional PC Cloudflare bridge

Some websites use Cloudflare or other protections that the PS Vita cannot handle by itself. Noboru includes an optional PC bridge using `vitaserver.py` or `CFBridge.exe` to handle supported requests through a computer.

**Note:** The bridge does not guarantee that every website will work. Some sites may still require VitaSurf or may remain incompatible.

### Menu sounds

Short interface sounds provide feedback when navigating menus. They can be switched on or off under:

`Settings → Controls`

## Installation

1. Open the [Noboru Update GitHub repository](https://github.com/limeking614-dev/NOBORU-UPDATE).
2. Download an available VPK from the [Releases page](https://github.com/limeking614-dev/NOBORU-UPDATE/releases).
3. Transfer the VPK to your PS Vita or PS TV.
4. Open VitaShell and locate the VPK.
5. Press **X** to install it.
6. Launch Noboru from the LiveArea.

## Importing manga for offline reading

You can import your own manga and comics into Noboru in these ways:

- Import a folder containing images.
- Import a folder containing multiple folders of images.
- Import a `.CBZ` or `.ZIP` archive.
- Import an individual `.CBZ` or `.ZIP` file.

Supported image formats inside archives:
- JPG
- JPEG
- PNG
- BMP
- GIF

**Not currently supported:** WebP images and CBR/RAR archives.

Folders being imported should contain image files only.

## Requirements

The original README lists these approximate memory requirements:

- 50–60 MB for online reading.
- More than 100 MB for offline reading.

Actual memory use may vary depending on the manga, chapter, and device.

## Data and storage

Noboru stores its application data in:

`ux0:data/noboru/`

This folder contains cached manga information, downloaded chapters, imported files, catalog parsers, custom manga settings, and application settings.

Deleting the `noboru` folder resets the application's stored data and settings. Back up anything important before deleting it.

## Backup

The original project stores different information in separate files and folders. Important items to back up include:

| File or folder | What it contains |
|---|---|
| `save.dat` | Library list |
| `settings.ini` | Application settings |
| `history.dat` and `info.txt` | History information |
| `info.txt` and cache folders | Bookmarks and covers |
| `c.c` and chapter folders | Saved chapter information and chapters |
| `cusettings/*.ini` | Custom manga settings |

If you want to keep downloaded chapters that you may not be able to find online again, back up the history information as well as the chapter files.

## Troubleshooting and FAQ

### The catalog is empty

Open the Catalog tab and press **Triangle** to refresh the catalog list.

### A website shows "Couldn't read the site"

The message below the title should explain the reason, such as a connection problem, Cloudflare protection, an empty page, or an unsupported layout.

- Press **Cross** to check the site again.
- Press **Triangle** to open the site in VitaSurf, or the Vita browser if VitaSurf is not installed.
- Press **Circle** to open the source anyway.

Some websites may still be incompatible.

### A chapter only displays one image

The website may have caused its logo or a loading image to be detected as the chapter page. If this continues, report the website and chapter so the issue can be investigated.

### Some images do not load

Check that the image format is supported. If the problem continues, include the website, manga title, chapter, and page when reporting the issue.

### How do I show the clock while reading?

Go to `Settings → Reader` and change **Clock in reader** to Time, Date, or Time + Date. You can also change the clock position and 24-hour option.

### How do I turn off site checks, online profiles, or JPEG conversion?

Open `Settings → Network` and adjust the relevant options:
- Check site when opened
- Online site profiles (Aidoku list)
- All pages + covers to JPEG

### How do I open the debug console?

Press **DPAD_LEFT + START**.

### How do I configure a proxy?

The original application supports proxy addresses and proxy types such as HTTP, HTTPS, SOCKS4a, SOCKS5, and SOCKS5h. Enter the appropriate address and type in the network settings.

## Known limitations

- Not every manga website is supported.
- Some websites require the optional PC bridge or VitaSurf.
- Paywalled, locked, or login-only chapters are not unlocked.
- Aidoku executable extensions cannot run in Noboru; only source-list data is used for site profiles.
- WebP images and CBR/RAR archives are not supported for local imports.

## Building from source

To build the application:

1. Download or clone this repository.
2. Set up the required PS Vita development environment.
3. Run `build.bat`.
4. The build process should create the VPK.

## Credits

- **Creckeryop** – Original Noboru project: [NOBORU](https://github.com/Creckeryop/NOBORU).
- **VitaSurf / NetSurf** – Browser used by the Cloudflare bridge.
- **Aidoku Community** – Public source-list data used for site profiles.
- **wsrv.nl** – Image conversion service used by the JPEG option.
- **Rinnegatamante** – [LuaPlayerPlus Vita](https://github.com/Rinnegatamante/lpp-vita).
- **VitaSDK** – PlayStation Vita development tools.
- **xerpi** – [libvita2d](https://github.com/xerpi/libvita2d).
- **theFloW** – [VitaShell](https://github.com/TheOfficialFlow/VitaShell) and related contributions.
- **Translation contributors** – Thank you to everyone who contributed translations to the original project.

This repository contains modifications and additional features built on top of the original Noboru project.

## Links

- [Noboru Update – GitHub](https://github.com/limeking614-dev/NOBORU-UPDATE)
- [Original Noboru – GitHub](https://github.com/Creckeryop/NOBORU)
- [Original Noboru Parser Repository](https://github.com/Creckeryop/NOBORU-parsers)
