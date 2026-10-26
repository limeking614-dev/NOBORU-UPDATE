# Changelog

## This version (on top of NOBORU 0.911)
### Sites / network
- **Checking site** screen (`cfcheck.lua`): reads the front page with browser-like headers, then the source's own title list; auto-opens the source on success, shows the reason on failure (Cross retry / Triangle VitaSurf or browser / Circle open anyway / Square cancel)
- **Ad / redirect page skipping** (`adbypass.lua`, hooked into `net.lua`): follows the real link of ad walls, "continue" pages, meta refresh and script redirects (max 4 hops, not counted as a failed try)
- Page requests use a phone-browser user agent and `Accept`, `Accept-Language`, `Referer` headers (`net.lua`)
- **All pictures + covers as JPEG** through the image converter (`rokuru.lua`, `net.lua`); covers are requested smaller than pages
- **Online site profiles** (`siteprofile.lua`): engine fingerprint (Madara / MangaThemesia / Next.js) used to try the right list layouts first; name / language / rating from the Aidoku community source list and optional extra lists in `ux0:data/noboru/profile_sources.txt`; saved in `ux0:data/noboru/siteprofiles.lua`
- **VitaSurf bridge** (`vitasurf.lua`): hands a site to VitaSurf (title id `VSRF00001`) through its `Choices` file and reads its `Cookies` file for the `cf_clearance` cookie; sends it with the same user agent; restores VitaSurf's own options afterwards
- Cloudflare PC bridge (`cfbridge.lua`) for sites the Vita can't open
- Generic site reader (`assets/parsers/DF_PCSite.lua`): pages from reader scripts / Next.js data, header / footer / menu pictures ignored (fixes the logo showing as the only page), more lazy-load attributes, ad images skipped, MangaThemesia style list addresses
### Reader
- **Reader clock** (`rkclock.lua`): time and/or date without the year, top left or top right, 12 / 24 hour; works in the rotated (Vertical) orientation too
- **Webtoon reader** (`webtoon.lua`, `webtoonlang.lua`): continuous vertical scroll of the whole chapter
### Other
- Menu sounds (`uisound.lua`, `assets/sounds`), switchable in Settings > Controls
- New settings: "Check site when opened", "Online site profiles (Aidoku list)", "VitaSurf for Cloudflare sites", "All pages + covers to JPEG", "Clock in reader", "Clock position", "Clock 24 hour time"
- Removed: the MangaDex source (it was added and then deleted again)

### Known limits
- Paywalled / locked / login-only chapters are not unlocked
- The VitaSurf bridge depends on VitaSurf honouring the `homepage_url` and `user_agent` options and on its small JavaScript engine passing the check
- Aidoku sources (WebAssembly) can't run on the Vita; only the published list data is used
- Written and checked without a Vita: the logic was tested on stand-in data, not on every live site
