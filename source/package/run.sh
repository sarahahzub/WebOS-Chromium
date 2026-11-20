#!/bin/sh
# bin/run.sh: starts the browser. bin/run (the launcher, package/launcher/cnrun.c) runs it inside webOS's Developer Mode
# jail as the app's own user: no root, /tmp is RAM, the app folder is writable flash. It must exec the browser, because
# LSM only shows windows from the launched app's process tree. busybox sh only.
D=$(cd "$(dirname "$0")/.." && pwd)
ID=$(basename "$D")
T=/tmp/$ID
mkdir -p "$T/tmp"
chmod 700 "$T"
# Storage: profile (bookmarks, logins, extensions) and the 32 MB disk cache go on flash. The app folder itself is
# root's, but the package ships $D/data writable (mkipk.py); older installs may have the profile in
# /media/developer/$ID (writable on some webOS versions only). So: the folder that already has a profile, else $D/data,
# else /media/developer/$ID, else /tmp (RAM, wiped at reboot). Logs, shared memory ($TMPDIR, used with
# --disable-dev-shm-usage) and option files always stay in /tmp.
S=
w() { mkdir -p "$1/profile" "$1/cache" 2>/dev/null && touch "$1/profile/.w" 2>/dev/null && rm -f "$1/profile/.w"; }
for c in "$D/data" "/media/developer/$ID"; do
	[ -d "$c/profile/Default" ] && w "$c" && { S=$c; break; }
done
[ -n "$S" ] || for c in "$D/data" "/media/developer/$ID"; do w "$c" && { S=$c; break; }; done
[ -n "$S" ] || S=$T
mkdir -p "$S/profile" "$S/cache"
# one-time move of a profile made by older versions in /tmp
[ "$S" != "$T" ] && [ -d "$T/profile/Default" ] && [ ! -d "$S/profile/Default" ] && cp -a "$T/profile/." "$S/profile/" && rm -rf "$T/profile"
# after the move: cp -a copies the RAM profile's own mode (755) onto the folder
chmod 700 "$S/profile" "$S/cache" 2>/dev/null
# Native apps get neither XDG_RUNTIME_DIR nor EGL_PLATFORM from SAM (webos-native-app-kit WEBOS-PLATFORM.md).
export XDG_RUNTIME_DIR=/tmp/xdg EGL_PLATFORM=wayland
export HOME=$S TMPDIR=$T/tmp XDG_CACHE_HOME=$S/cache XDG_CONFIG_HOME=$S
export LANG=${LANG:-en_US.UTF-8}
# Chrome uses the TV's fontconfig, whose rules turn every family into LG Display with full hinting (fonts.conf).
export FONTCONFIG_FILE=$D/fonts.conf
# No Google API keys in a Chromium build: "no" hides the "Google API keys are missing" bar (Chromium's documented
# opt-out), and patch 0059 then sends nothing to accounts.google.com. For trying Google sign-in and sync with your own
# keys (see the README): $S/google-keys with the three lines GOOGLE_API_KEY=..., GOOGLE_DEFAULT_CLIENT_ID=... and
# GOOGLE_DEFAULT_CLIENT_SECRET=... (owned by the app's user, mode 600). Then sync is not turned off either.
GK=no GC=no GS=no SYNC_OFF=--disable-sync
if [ -f "$S/google-keys" ]; then
	k() { sed -n "s/^$1=\([A-Za-z0-9._-]*\)[[:space:]]*\$/\1/p" "$S/google-keys" | head -1; }
	a=$(k GOOGLE_API_KEY) b=$(k GOOGLE_DEFAULT_CLIENT_ID) c=$(k GOOGLE_DEFAULT_CLIENT_SECRET)
	[ -n "$a" ] && [ -n "$b" ] && [ -n "$c" ] && GK=$a GC=$b GS=$c SYNC_OFF=
fi
export GOOGLE_API_KEY=$GK GOOGLE_DEFAULT_CLIENT_ID=$GC GOOGLE_DEFAULT_CLIENT_SECRET=$GS
# Chrome's --class becomes the Wayland app id; patch 0011 sends it as the webOS "appId" window property (LSM only
# shows windows with the launched app's id).
APPID_FLAGS="--class=$ID"
B=$D/browser
# Extra flags, one per line, '#' comments: $D/browser.flags (shipped) and $T/browser.flags (for troubleshooting).
EXTRA=$(cat "$D/browser.flags" "$T/browser.flags" 2>/dev/null | grep -v '^\s*#' | tr '\n' ' ')
rm -f "$S/profile/Singleton"*
# No core dumps: the TV writes them into the working directory, and a few hundred MB fill the small app partition so
# that the next install fails. Crash reports still go to $T.
ulimit -c 0
cd "$T"
# after a kill: no "restore pages?" bubble
P=$S/profile/Default/Preferences
NEWPROF=; [ -f "$P" ] || NEWPROF=1   # Chrome has never run with this profile (used by the handover below)
[ -f "$P" ] && sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/; s/"exited_cleanly":false/"exited_cleanly":true/' "$P"
# Start page: Chrome's own New Tab page. The bookmarks bar is on: a new profile starts with that preference, an
# existing profile gets it once if it never had a bookmark_bar setting.
mkdir -p "$S/profile/Default"
# TV Tools (ext/tvtools, id fixed by the "key" in its manifest) is pinned to the toolbar once, so the remote reaches
# it without the puzzle menu; if the user unpins it later, that choice stays.
TVT=ikkplgnegbekkbamfelhaeahnaddgnma
if [ ! -f "$P" ]; then
	echo '{"bookmark_bar":{"show_on_all_tabs":true},"extensions":{"pinned_extensions":["'$TVT'"]}}' > "$P"
else
	grep -q '"bookmark_bar"' "$P" || sed -i '1s/^{/{"bookmark_bar":{"show_on_all_tabs":true},/' "$P"
	if ! grep -q '"pinned_extensions"' "$P"; then
		if grep -q '"extensions":{' "$P"; then
			sed -i '1s/"extensions":{/"extensions":{"pinned_extensions":["'$TVT'"],/' "$P"
		else
			sed -i '1s/^{/{"extensions":{"pinned_extensions":["'$TVT'"]},/' "$P"
		fi
	fi
fi
# Fresh start: webOS ends Chrome with a kill, and Chrome would restore every old tab on the next launch, until a dozen
# pages shared the one renderer and the TV was swapping. Each launch starts with only the start page.
rm -rf "$S/profile/Default/Sessions" "$S/profile/Default/Current Session" "$S/profile/Default/Current Tabs" \
	"$S/profile/Default/Last Session" "$S/profile/Default/Last Tabs"
# New app id (0.0.67): Chromium moved from org.nativechromium.browser to io.github.sarahahzub.chromium. The new app
# runs as another user and can't read the old profile (700), so the old id's last release (it has bin/moved-to) leaves
# copies of the bookmarks, history and their icons in <old app>/data/handover at every start and opens moved.html.
# The new app copies them into its profile once (for the files it doesn't have yet; see "Order" below for users who
# open the new app first). Only bookmarks and history move (owner's decision, 2026-11-19). Saved passwords and cookies
# don't move. Other apps can read the copies until the old app is removed (the page says so).
HF="Bookmarks History History-journal History-wal Favicons Favicons-journal Favicons-wal"
MOVED_URL=
if [ -f "$D/bin/moved-to" ]; then
	for HO in "$D/data/handover" "/media/developer/$ID/handover"; do
		rm -rf "$HO.new" && mkdir -p "$HO.new" 2>/dev/null || continue
		for f in $HF; do [ -f "$S/profile/Default/$f" ] && cp "$S/profile/Default/$f" "$HO.new/"; done
		chmod 755 "$HO.new"; chmod 644 "$HO.new"/* 2>/dev/null
		rm -rf "$HO" && mv "$HO.new" "$HO" && break
	done
	MOVED_URL=file://$D/moved.html
fi
case "$ID" in io.github.sarahahzub.chromium) OLD=org.nativechromium.browser ;; *) OLD= ;; esac
# Order: users may open the new app before the old one has left its copy. Chrome then makes its own (empty) History
# and Favicons, which a fill-only import would never replace. So when a new profile starts while the old app is
# installed without a copy, .handover-wait records the time, and for 14 days the copy replaces those files when it
# turns up. After 14 days History and Favicons are only filled in when missing, so weeks of use in the new app are
# never overwritten. Bookmarks come over whenever the new app has no bookmarks of its own.
HWAIT=$S/profile/.handover-wait
if [ -n "$OLD" ] && [ ! -f "$S/profile/.handover-done" ]; then
	WAIT=
	if [ -f "$HWAIT" ]; then
		t=$(cat "$HWAIT" 2>/dev/null); now=$(date +%s)
		case "$t" in ''|*[!0-9]*) t=0 ;; esac
		if [ $((now - t)) -lt 1209600 ]; then WAIT=1; else rm -f "$HWAIT"; fi
	fi
	HAVE=
	for HO in "/media/developer/apps/usr/palm/applications/$OLD/data/handover" "/media/developer/$OLD/handover"; do
		[ -f "$HO/Bookmarks" ] || [ -f "$HO/History" ] || continue
		HAVE=1
		for f in Bookmarks History Favicons; do
			[ -f "$HO/$f" ] || continue
			if [ "$f" = Bookmarks ]; then   # never over bookmarks the user made in the new app
				grep -q '"type": *"url"' "$S/profile/Default/$f" 2>/dev/null && continue
			elif [ -s "$S/profile/Default/$f" ]; then
				[ -n "$WAIT" ] || continue
			fi
			cp "$HO/$f" "$S/profile/Default/$f"
			rm -f "$S/profile/Default/$f-journal" "$S/profile/Default/$f-wal" "$S/profile/Default/$f-shm"
			for x in journal wal; do   # SQLite's log of that file (History is in WAL mode): newer rows may be only there
				[ -f "$HO/$f-$x" ] && cp "$HO/$f-$x" "$S/profile/Default/"
			done
		done
		echo "$(date) from $HO" > "$S/profile/.handover-done"
		rm -f "$HWAIT"
		break
	done
	# no copy yet, a new profile, and the old app is installed: wait for its copy (see above)
	[ -z "$HAVE" ] && [ -n "$NEWPROF" ] && [ -f "/media/developer/apps/usr/palm/applications/$OLD/appinfo.json" ] &&
		date +%s > "$HWAIT"
fi

if [ -x "$B/chrome" ]; then
	# UI scale: a 1920x1080 window at the panel's resolution with the UI laid out at 1.5x (1280x720 DIP), so text is
	# sharp (patch 0032). --window-size is in pixels.
	# Memory (the app gets roughly 700 MB on a TV):
	#   --disable-rgba-4444-textures   low-end mode rasters into 16-bit tiles, and light greys turned white with GPU
	#                                  raster (the New Tab search box vanished)
	#   --disable-dev-shm-usage        the TV's /dev/shm is a 64 MB tmpfs; with 2+ renderers it filled up and the
	#                                  renderer died ("Aw, Snap!"). Shared memory lives in /tmp instead.
	#   --in-process-gpu               no separate GPU process
	#   --disable-site-isolation-trials, IsolateOrigins/site-per-process off   one renderer for all sites
	#   --isolate-origins=https://challenges.cloudflare.com   except Cloudflare's challenge frame, which gets its own
	#                                  renderer as in normal Chrome. In the page's renderer the check passed the click,
	#                                  then the site refused the pass and challenged again (issue #11, 2026-11-14).
	#   --disable-component-extensions-with-background-pages, --disable-sync   fewer background processes
	#   NetworkServiceInProcess2 on, AudioServiceOutOfProcess off               two utility processes fewer
	#   WebUIToolbar*, WebUIReloadButton, WebUILocationBar, WebUIOmnibox*Popup off   native toolbar and omnibox
	#                                  popups, no extra hidden renderers
	#   JS heap 192 MB: all tabs share one renderer, so this cap is for all tabs together.
	#   --mse-*-buffer-size-limit-mb   caps how much video a page buffers (YouTube kept ~90 s)
	# GPU: the TV's PowerVR/Mali GLES drivers (patch 0019, validating command decoder); the flags follow LG's own web
	#   app manager with a smaller GPU memory budget.
	#   --use-cmd-decoder=validating   the passthrough decoder needs ANGLE extensions the TV drivers lack (no WebGL)
	#   WebGPUService, WebGPUBlobCache off   Dawn on the TV's GLES driver killed the GPU thread, and with
	#                                  --in-process-gpu the whole browser; pages fall back to WebGL/canvas
	# HardwareMediaKeyHandling off: Chrome sends media keys over D-Bus (MPRIS), which the TV lacks; off, they reach the
	#   page as keydown and TV Tools plays/pauses.
	# Priority: webOS gives the foreground app nice -8 and every Chrome thread inherits it, so Chrome starved LG's own
	#   services (volume OSD, input). This loop puts Chrome's threads back to nice 0 (no root needed), except the
	#   threads that pace video and frames (compositor, GPU, media, audio): at nice 0 they were preempted and video
	#   froze for ~0.5 s every few seconds. It ends with Chrome.
	( while sleep 3; do
		n=0
		for c in /proc/[0-9]*; do
			[ "$c/exe" -ef "$B/chrome" ] || continue   # shell builtin, no fork per process
			n=1
			for t in $c/task/*; do
				read -r s < "$t/stat" 2>/dev/null || continue
				read -r nm < "$t/comm" 2>/dev/null
				case "$nm" in Compositor*|VizCompositor*|CrGpuMain|Chrome_InProcGp*|Media*|Audio*|Video*) continue ;; esac
				set -- ${s##*) }
				[ "${17:-0}" -lt 0 ] 2>/dev/null && renice 0 -p "${t##*/}" >/dev/null 2>&1
			done
		done
		[ $n = 0 ] && [ -f "$T/.started" ] && exit 0
		[ $n = 1 ] && touch "$T/.started"
	done ) </dev/null >/dev/null 2>&1 &
	rm -f "$T/.started"
	# Hardware video (patch 0023): the launcher exports CN_MEDIA_SOCK when LG's NDL is usable. The built-in TV Tools
	# extension reads hw.json: its "Auto" video limit is any codec up to 1080p60 with hardware decoding, H.264 up to
	# 720p30 without. The installed ext/ is read-only, so TV Tools runs from a copy in the data folder (refreshed when the
	# app version changes); the manifest "key" keeps its extension id.
	EXT=$S/ext/tvtools
	# refreshed when the app version changes or the shipped extension differs from the copy (e.g. a patched ext/)
	V=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$D/appinfo.json")
	X=$(ls -lnR "$D/ext/tvtools" 2>/dev/null | tr -s ' ' | tr '\n' ';')   # sizes and times (no md5sum in the jail)
	if [ "$(cat "$S/ext/.version" 2>/dev/null)" != "$V $X" ] || [ ! -f "$EXT/manifest.json" ]; then
		# A new TV Tools version needs a new service worker registration. Chrome keeps the worker it registered
		# first (registering the same script URL again returns the old registration), so a changed bg.js never ran.
		# Without a registration Chrome registers the shipped bg.js. Sites' service workers register again on their
		# next visit.
		TVO=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$EXT/manifest.json" 2>/dev/null)
		TVN=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$D/ext/tvtools/manifest.json" 2>/dev/null)
		[ "$TVO" != "$TVN" ] && rm -rf "$S/profile/Default/Service Worker"
		rm -rf "$S/ext" && mkdir -p "$S/ext" && cp -r "$D/ext/tvtools" "$EXT" && echo "$V $X" > "$S/ext/.version" ||
			EXT=$D/ext/tvtools
	fi
	# GPU check: the launcher sets CN_GPU=off on TVs where its GPU check fails; Chrome then draws in software.
	GPU_OFF=; [ "$CN_GPU" = off ] && GPU_OFF=--disable-gpu
	# WebGPU is off by default (see above); media.opts "webgpu=on" turns it on.
	WEBGPU_OFF=,WebGPUService,WebGPUBlobCache
	grep -q 'webgpu=on' "$T/media.opts" 2>/dev/null && WEBGPU_OFF=
	# Omnibox for a TV, opt-in with media.opts "omnibox=lite": about 160 -> 90 ms from a key to the screen on an LG C1.
	# Fewer autocomplete providers (no calculator, @bookmarks/@history/@tabs or recently closed tabs; HistoryFuzzy stays,
	# typo matching over history costs nothing measurable), 5 rows, suggest requests after a 400 ms pause, and no ML
	# scoring, AI Mode or preconnect. Without it the omnibox is Chrome's own.
	OMNI_OFF= OMNI_ON= OMNI_TRIAL=
	if grep -q 'omnibox=lite' "$T/media.opts" 2>/dev/null; then
		OMNI_OFF=,OmniboxDynamicMaxAutocomplete,OmniboxRichAutocompletion,MlUrlScoring,UrlScoringModel,MlUrlScoreCaching,AimEnabled,AllowAiModeMatches,OmniboxMiaZPS,PreconnectNonSearchOmniboxSuggestions
		OMNI_ON=,OmniboxUIExperimentMaxAutocompleteMatches:UIMaxAutocompleteMatches/5
		OMNI_TRIAL="--force-fieldtrials=OmniboxBundledExperimentV1/TV/ --force-fieldtrial-params=OmniboxBundledExperimentV1.TV:DisableProviders/201221632/SuggestPollingDelayMs/400/MeasureSuggestPollingDelayFromLastKeystroke/true"
	fi
	# Launch parameters arrive as one JSON argument, e.g. {"target": "https://...", "fullscreen": true} (LG's own browser
	# reads "target"). Only http(s) targets are opened; "fullscreen": true adds --start-fullscreen.
	URL= FULL=
	case "$1" in
	\{*)
		URL=$(printf '%s' "$1" | sed -n 's/.*"target"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g')
		case "$URL" in http://*|https://*) ;; *) URL= ;; esac
		printf '%s' "$1" | grep -q '"fullscreen"[[:space:]]*:[[:space:]]*true' && FULL=--start-fullscreen
		shift ;;
	esac
	[ -n "$URL" ] || URL=$MOVED_URL
	# Last log on flash, so logs survive a forced restart and users without root can read them: a memory line
	# (MemAvailable, SwapFree, RSS of all chrome processes) once a minute in RAM ($T/mem.txt); every 5 minutes and when
	# the browser ends, the tail of browser.log, media.log and mem.txt go to $S/lastlog. Each start moves the previous
	# session's copy to $S/lastlog.prev.
	CL=$S/lastlog
	if [ "$S" != "$T" ]; then
		rm -rf "$CL.prev"; [ -d "$CL" ] && mv "$CL" "$CL.prev"; mkdir -p "$CL"
		( save() {
			tail -n 400 "$T/browser.log" > "$CL/browser.log" 2>/dev/null; cp -f "$T/media.log" "$CL/media.log" 2>/dev/null
			cp -f "$T/mem.txt" "$CL/mem.txt" 2>/dev/null
		  }
		  : > "$T/mem.txt"; m=0
		  while sleep 60; do
			kill -0 $$ 2>/dev/null || break
			rss=0
			for c in /proc/[0-9]*; do
				[ "$c/exe" -ef "$B/chrome" ] || continue
				while read -r k v _; do [ "$k" = VmRSS: ] && rss=$((rss + v)); done < "$c/status"
			done
			echo "$(date '+%F %T') chrome_rss_kb=$rss $(awk '/^(MemAvailable|SwapFree):/{printf "%s%s ", $1, $2}' /proc/meminfo)" >> "$T/mem.txt"
			[ "$(wc -l < "$T/mem.txt")" -gt 1500 ] && { tail -n 1000 "$T/mem.txt" > "$T/mem.tmp"; mv -f "$T/mem.tmp" "$T/mem.txt"; }
			m=$((m + 1)); [ $((m % 5)) -eq 0 ] && save
		  done
		  echo "$(date '+%F %T') browser ended" >> "$T/mem.txt"; save ) </dev/null >/dev/null 2>&1 &
	fi
	# webOS 4 (CN_NDL_API=old, NDL API 1): the hardware decoder takes only H.264, so "h264": true makes TV Tools offer
	# sites only H.264 (Auto = 1080p30); VP9/AV1 in software would run a small TV out of memory. After a failed API 1
	# call the launcher writes "bad" to $T/hw.state, and TV Tools gets hardware false (H.264 720p30).
	HW=false; H264=false; [ -n "$CN_MEDIA_SOCK" ] && HW=true
	if [ "$CN_NDL_API" = old ]; then
		H264=true; grep -q '^bad' "$T/hw.state" 2>/dev/null && HW=false
	fi
	HWJ="{\"hardware\": $HW, \"h264\": $H264}"
	[ "$(cat "$EXT/hw.json" 2>/dev/null)" = "$HWJ" ] || echo "$HWJ" > "$EXT/hw.json" 2>/dev/null
	# A failure during this session: switch hw.json to software too (TV Tools reads it when its worker starts again).
	# $$ becomes Chrome's pid after the exec below, so the watcher ends with Chrome.
	if [ "$CN_NDL_API" = old ] && [ "$HW" = true ]; then
		( while sleep 5; do
			kill -0 $$ 2>/dev/null || exit 0
			grep -q '^bad' "$T/hw.state" 2>/dev/null && { echo '{"hardware": false, "h264": true}' > "$EXT/hw.json"; exit 0; }
		done ) </dev/null >/dev/null 2>&1 &
	fi
	# NSS ships in <app>/lib (webOS 4 has none). Say so in start-check.log when it is missing (the exec below truncates
	# browser.log).
	rm -f "$T/start-check.log"
	if [ ! -f "$D/lib/libnss3.so" ] && [ ! -f /usr/lib/libnss3.so ]; then
		echo "libnss3.so not found in $D/lib or /usr/lib" > "$T/start-check.log"
	fi
	# chrome has no RUNPATH, so the shipped NSS/NSPR is found through LD_LIBRARY_PATH. It comes first on every TV: one
	# tested set (libnss3 dlopens libsoftokn3/libfreebl3 from its own folder) instead of the TV's own, which differs per
	# model.
	[ -f "$D/lib/libnss3.so" ] && export LD_LIBRARY_PATH="$D/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
	# Sound Chrome plays itself (WebRTC, WebAudio, page audio) goes to the TV's system PulseAudio; libpulse would look
	# in $XDG_RUNTIME_DIR/pulse and find nothing. Hardware video has its own audio path.
	if [ -S /var/run/pulse/native ]; then
		mkdir -p "$T/pulse"
		export PULSE_SERVER=unix:/var/run/pulse/native PULSE_RUNTIME_PATH=$T/pulse
	fi
	# Screen saver: patch 0049 writes the number of playing media sessions to $CN_PLAYSTATE_FILE; the launcher's screen
	# saver guard answers webOS's screen saver requests from it.
	export CN_PLAYSTATE_FILE=$T/playstate
	echo 0 > "$CN_PLAYSTATE_FILE"
	# NetworkTimeServiceQuerying off: Chrome asked clients2.google.com for the time at every start (the TV keeps its
	# own clock). Patch 0059 stops the other background requests to Google.
	exec "$B/chrome" \
		--load-extension="$EXT" \
		--mse-video-buffer-size-limit-mb=40 --mse-audio-buffer-size-limit-mb=6 \
		--ozone-platform=wayland --no-sandbox --no-zygote $APPID_FLAGS \
		--user-data-dir="$S/profile" --disk-cache-dir="$S/cache" --disk-cache-size=33554432 \
		--enable-low-end-device-mode --disable-rgba-4444-textures --renderer-process-limit=1 --process-per-site \
		--disable-dev-shm-usage --in-process-gpu --disable-site-isolation-trials \
		--isolate-origins=https://challenges.cloudflare.com \
		--use-gl=egl --use-cmd-decoder=validating --ignore-gpu-blocklist --enable-gpu-rasterization --disable-oop-rasterization \
		--enable-threaded-compositing --force-gpu-mem-available-mb=128 --gpu-program-cache-size-kb=2048 \
		--mem-pressure-gpu-cache-size-reduction-factor=4 \
		--disable-component-extensions-with-background-pages --disable-background-networking --num-raster-threads=1 \
		--enable-features=NetworkServiceInProcess2$OMNI_ON $OMNI_TRIAL \
		--disable-features=Translate,OptimizationHints,MediaRouter,BackForwardCache,Vulkan,ContextualTasks,ContextualTasksContext,ContextualTasksSidePanel,PreloadTopChromeWebUI,SpareRendererForSitePerProcess,SpareRenderer,OptimizationGuideModelDownloading,IsolateOrigins,site-per-process,WebUIToolbar,WebUIToolbarWebView,WebUIToolbarInternalWebView,WebUIReloadButton,WebUILocationBar,AudioServiceOutOfProcess,WebUIOmniboxPopup,WebUIOmniboxAimPopup,WebUIOmniboxFullPopup,DisableLoadExtensionCommandLineSwitch,HardwareMediaKeyHandling,NetworkTimeServiceQuerying$OMNI_OFF$WEBGPU_OFF $SYNC_OFF \
		--js-flags="--max-old-space-size=192 --optimize-for-size" \
		--no-first-run --no-default-browser-check --disable-component-update --disable-breakpad \
		--password-store=basic --autoplay-policy=no-user-gesture-required \
		--enable-neva-ime --enable-spatial-navigation --hide-crash-restore-bubble --start-maximized --lang=en-US \
		--force-device-scale-factor=1.5 --window-size=1920,1080 --window-position=0,0 \
		$GPU_OFF $FULL $EXTRA "$@" ${URL:+"$URL"} > "$T/browser.log" 2>&1
fi
echo "browser/chrome is missing or not executable" > "$T/start-check.log"
exit 1
