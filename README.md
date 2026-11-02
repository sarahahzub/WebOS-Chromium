<p align="center"><img src="assets/icon.png" width="96" alt="Chromium icon"></p>

<h1 align="center">WebOS Chromium</h1>

<p align="center">The real Chromium browser, with the full Chrome interface, running natively on LG webOS TVs.<br>
GPU rendering and hardware video decoding. No root needed.<br>
<b>Requires webOS 9 (webOS 24) or newer.</b></p>

---

## Highlights

| | |
|---|---|
| **Truly native** | Built for the TV's own ARM processor. It talks straight to the TV's own display server, GPU driver and video decoder. No emulation, no translation layer, no bundled display server, no chroot or container. |
| **GPU rendering** | Pages and the browser UI are drawn on the TV's GPU (PowerVR, OpenGL ES) through the TV's own driver. |
| **Hardware video** | Every `<video>` on every site goes to the TV's hardware decoder (LG NDL DirectMedia), up to 1080p60. YouTube AV1 1080p60 plays with **0 dropped frames**. |
| **Sharp 1080p** | The browser draws at the TV's full 1920x1080 resolution with a 1.5x interface, so text stays big enough for the sofa and sharp (since 0.0.48). |
| **Full Chrome UI** | Tabs, address bar, 3-dot menu, bookmarks, history, downloads, settings, and extensions from the Chrome Web Store. |
| **Light** | ~138 MB RAM when idle, with no extra CPU load. Fast launch with a splash screen. |
| **No root** | Installs as a normal Developer Mode app, or through Homebrew Channel. |

## What "native" means here

Many ways of running a desktop browser on a TV bring their own environment with them: a separate display server,
an X11 layer, a Linux userland in a chroot, or emulation. WebOS Chromium doesn't. It runs as an ordinary webOS app:

- **Processor:** machine code for the TV's 32-bit ARMv7 (softfp) ABI, linked against the TV's own glibc and system
  libraries.
- **Display:** the browser window is a normal webOS app window on LG's own compositor (LSM), the same display server
  every LG app uses, through its webOS shell extensions. Nothing extra runs to show the window.
- **GPU:** the TV's PowerVR driver directly through EGL / OpenGL ES 2, with no ANGLE or software GL in between.
- **Video:** LG's NDL DirectMedia, the same hardware decoding library LG's own apps use.
- **Input:** the remote's keys and pointer arrive as normal input events; typing uses LG's own on-screen keyboard.

The only helper is a small launcher, `bin/run` (written in C). webOS gives media access only to an app's own main
executable, so the launcher starts Chromium and holds the TV's media connection. Chromium hands it compressed video,
and it passes the data unchanged to the hardware decoder. Nothing is converted or re-encoded.

## Built-in TV Tools extension

WebOS Chromium comes with **TV Tools**, an extension made for the TV. Its button is pinned to the toolbar; press it
for quick settings, or open **All settings** for the full page. Everything can be changed or turned off.

| Setting | Options | What it does |
|---|---|---|
| Lite mode | Off, On | Lighter pages: no animations, images and frames load only when you scroll to them, and muted videos don't start by themselves. |
| Website version | TV (default), Desktop, Custom | TV asks every site for its TV layout (YouTube opens its TV interface, made for the remote). Desktop asks for normal desktop pages. Custom sends a user agent you type in. |
| Per-site version | TV / desktop for the current site | Keeps a site on its desktop version while everything else uses the TV version. |
| Maximum video resolution | Auto, 4K, 1080p, 720p, 480p, 360p | Limits the video quality on **every site**, not only YouTube. Lower uses less memory and data. **4K** is opt-in and may stutter or lag, especially when a video starts; go back to Auto or 1080p if it does. |
| Maximum frame rate | Auto, 60 fps, 30 fps | Skips streams above the chosen frame rate. |
| Video codec | Auto, H.264 only | H.264 only is the most compatible choice if a video won't play. |
| Per-site video limits | On / off for the current site | Turns the video limits off on a site where you want the site's own choice. |
| Unload background tabs | Never, 5 min, 15 min, 30 min, 1 hour | Frees memory from tabs you haven't looked at. They reload when you open them. |
| Maximum open tabs | No limit, 3, 5, 8, 10 | Opening one more tab closes the tab you used least recently. |
| Pause videos in background tabs | Off, On | Pauses a video when you switch to another tab. |

Tabs playing sound and pinned tabs are never unloaded or closed.

**Auto** picks what suits the TV: up to 1080p60 in any codec the TV's hardware decoder supports.

How the video limit works on any site:
- It answers "not supported" when a site asks whether the TV can play a stream above the limit (this is how
  YouTube and many other players choose).
- It removes streams above the limit from **HLS** (`.m3u8`) and **DASH** (`.mpd`) playlists before the site's
  player reads them. Most streaming players (hls.js, dash.js, Shaka Player, Video.js) use these formats.
- It always keeps at least the smallest stream, so a video never ends up with nothing to play.
- Plain single-file videos (one `.mp4` with no quality choices) play as they are.

## Install

### Homebrew Channel (recommended)

1. Install [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel) on the TV (no root needed).
2. Open Homebrew Channel, go to **Settings → Add repository**, and enter:
   ```
   https://raw.githubusercontent.com/sarahahzub/WebOS-Chromium/main/webosbrew/apps.json
   ```
3. Go back to the app list, open **Chromium**, and select **Install**.

Updates appear in Homebrew Channel when a new release is published.

### Manual install (Developer Mode)

1. Enable **Developer Mode** on the TV (LG Developer Mode app) and connect your PC with `ares-setup-device`.
2. Download `org.nativechromium.browser_<version>_arm.ipk` from [Releases](https://github.com/sarahahzub/WebOS-Chromium/releases).
3. Install it:
   ```
   ares-install -d <your-tv> org.nativechromium.browser_<version>_arm.ipk
   ```
4. Open **Chromium** from the TV's app list.

Your profile (bookmarks, logins, extensions) is stored in the app's own folder and survives reboots.

## Supported TVs

> **Requires webOS 9 (webOS 24) or newer.**

| webOS version | Typical TVs | Works? |
|---|---|---|
| webOS 9 / 24 and newer | 2024 and newer models, and older models LG has updated to webOS 24 or newer | ✅ Yes |
| webOS 8 / 23 and older (including webOS 4, 5, 6, 7) | Most 2023 and older models | ❌ Not yet |

**How to check:** Settings → Support → TV Information → **webOS TV Version**. Don't use the "Software version"
(for example `05.40.97`); that is the firmware number, not the webOS version.

**Why older TVs don't work:** this Chromium needs glibc 2.35, the system C library LG ships from webOS 9 on.
webOS 5-8 have glibc 2.28-2.31, and webOS 4 and older 2.24 or less, so the TV can't load the browser. On those TVs
the app shows a short message and closes. Support for webOS 5-8 may come later; it needs a separate build and
testers with those TVs.

Tested so far:

| | Tested |
|---|---|
| TV | LG 43UR7500PSC |
| webOS | 10.3.1 |
| CPU | 32-bit ARMv7, 2x Cortex-A75 + 2x Cortex-A55 |
| GPU | PowerVR BXE-4-32 |

If you try it on another TV with webOS 9 or newer, please report it with the **TV compatibility** issue template,
whether it works or not.

## Using it with the remote

| Key | Action |
|---|---|
| Arrows | Move focus on the page; UP from the top of a page goes to the toolbar, UP again to the tabs |
| OK | Click; on a text field it opens LG's keyboard |
| Back | Closes menus and popups, then goes back in history; on a page that keeps the arrows (like a video player) it jumps to the toolbar |
| Magic Remote pointer | Works as a mouse everywhere |

## Known limitations

- **No Chromium sandbox:** the TV's kernel has no user namespaces, and a Developer Mode app can't be setuid, so
  Chromium runs with `--no-sandbox`. It still runs as its own user inside webOS's app jail.
- **No DRM:** Widevine isn't included, so Netflix, Prime Video and similar paid streaming sites won't play.
- **No Google account sync:** Chromium builds have no Google API keys.
- **Memory:** the TV shares about 630 MB of RAM between all running apps, so several heavy tabs at once get slow.

## Building from source

WebOS Chromium is open source. The full sources, patches, build arguments and packaging scripts will be uploaded
to this repository soon; until then, this section outlines the build so you know what to expect.

WebOS Chromium is cross-compiled on a Linux x86-64 host. A first full build takes several hours on 32-64 cores and
needs about 150 GB of disk; later rebuilds with a compile cache take minutes.

1. **Source:** [webOS-ports/chromium151](https://github.com/webOS-ports/chromium151) (Chromium 151 with LG's webOS
   platform layer), commit `0baacb2b1a4b885826fed5493262f759c6a5b469`.
2. **Sysroot:** an ARMv7 softfp sysroot that matches the TV (glibc 2.35, `/lib/ld-linux.so.3`). The browser may only
   link against libraries the TV already has.
3. **Patches:** apply this project's patches in name order. They cover the softfp ABI, webOS windows and remote
   input, the on-screen keyboard, GPU output, menus and popups on the TV's compositor, and the hardware video path.
4. **Build arguments** (`out/tv/args.gn`), the main ones:
   ```gn
   target_os = "linux"
   target_cpu = "arm"
   arm_float_abi = "softfp"
   is_webos = true
   use_ozone = true
   ozone_platform = "wayland"
   use_x11 = false
   is_official_build = true
   optimize_for_size = true
   proprietary_codecs = true
   ffmpeg_branding = "Chrome"
   enable_widevine = false
   symbol_level = 0
   ```
5. **Compile:** `ninja -C out/tv chrome`
6. **Launcher:** build `bin/run` with an ARM softfp GCC (for example Ubuntu's `gcc-arm-linux-gnueabi`) against the
   TV's glibc.
7. **Package:** collect `chrome`, its `.pak` files, `icudtl.dat`, the V8 snapshots and one locale, strip them, and
   pack an IPK with `appinfo.json`, the launcher, the start script and the icons.

## Benchmarks

Measured on the LG 43UR7500PSC (webOS 10.3.1), with Live TV and LG's preloaded apps running in the background as
usual.

**Current release (0.0.39-0.0.42, 2026-11-01)**

| Test | Result |
|---|---|
| Download / installed size | **105 MB / 178 MB** |
| Memory, idle on the New Tab page | **138 MB** (86 MB in RAM + 51 MB in swap) |
| CPU while the browser is idle | No extra load (87% idle) |
| YouTube AV1 1080p60, hardware decoded | **0 dropped of 3,914 frames** |
| YouTube TV interface, 1080p60, hardware decoded (0.0.41) | **0 dropped of 5,299 frames** |

**Dev build 0.0.36 (2026-10-31)**

| Test | Result |
|---|---|
| Memory, idle on the New Tab page | 105 MB (49 MB in RAM + 56 MB in swap) |
| CPU while the browser is idle | No extra load (66% idle without the browser, 65-73% with it) |
| Wikipedia article | 204 MB, loaded in 6.2 s |
| Google search results | 293 MB, loaded in 14.2 s |
| YouTube home page | 315 MB, loaded in 21.2 s |
| BBC News | 333 MB, ready in 24.0 s |
| YouTube AV1 1080p60, hardware decoded | **0 dropped of 9,330 frames**, while LG's background apps kept the CPU busy |
| Memory while playing that video | 292 MB |
| Speedometer 3.0 (1 iteration) | 0.71 |
| Splash screen | 0.8 s after launch |
| Launch to New Tab page | ~3 s; ~12 s when the TV first has to free memory for it (LG's memory manager) |

Page load times and the Speedometer score are limited by the TV's memory: during these tests only 40-110 MB was
free and the TV was swapping heavily. They are best read as "real-world on a busy TV", not as a CPU benchmark.

## Reporting issues

Use the [issue templates](https://github.com/sarahahzub/WebOS-Chromium/issues/new/choose): bug report, TV
compatibility report, or feature request. Please include your TV model, webOS version and the app version
(Homebrew Channel or the TV's app list shows it).

## License

Chromium is under the BSD license; see the Chromium source for its third-party licenses. The license for this
project's own patches and tools is still to be added.
