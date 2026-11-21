# Patch index

Applied in name order on top of webOS-ports/chromium151 at the commit in `config.env`.

| Patch | Why |
|---|---|
| `0001-webos-softfp-dynamic-linker.patch` | The TV loads programs with /lib/ld-linux.so.3 (softfp). |
| `0002-webos-shell-no-client-size-changed.patch` | The TV's wl_webos_shell_surface has no client_size_changed event. |
| `0003-webos-text-model-use-extension-header.patch` | wayland-text-client-protocol.h is not generated from the TV's protocols, and the generated wayland-webos-extension-client-protocol.h already defines text_model and text_model_factory. |
| `0004-webos-object-drop-text-include.patch` | Drop the include of wayland-text-client-protocol.h, which is not generated. |
| `0005-rust-std-depfile-first-output.patch` | find_stdlib lists target.json as its first output, but its depfile names libstd.rlib, so ninja re-runs it and 24 copy steps on every build. |
| `0006-run-i386-host-tools-under-qemu.patch` | For a 32-bit ARM target, V8's snapshot and generator tools are i386 binaries. |
| `0007-webos-notification-persistent-signature.patch` | content's PlatformNotificationService::DisplayPersistentNotification takes service_worker_registration_id, but the override in PlatformNotificationServiceImpl lacks it, so the class stays abstract. |
| `0008-chrome-views-delegate-enum-name.patch` | The USE_SINGLE_WINDOW_MODE branch uses the old enum name NATIVE_WIDGET_AURA. |
| `0009-chrome-link-neva-app-runtime.patch` | With use_neva_appruntime, content/ and extensions/ call neva_app_runtime, watchdog and neva_user_agent functions that only app_shell and browser_shell link, so //chrome:chrome fails to link. |
| `0010-webview-guest-null-checks-neva-app-runtime.patch` | The glue from patch 0009 returns nullptr for the app_runtime content client and the neva media capture dispatcher. |
| `0011-webos-shell-surface-set-app-id.patch` | LG's compositor (LSM) only shows windows that carry the webOS appId and _WEBOS_WINDOW_TYPE properties. |
| `0012-arm-float-abi-and-fpu-flags.patch` | This GN-only build does not pass -mfloat-abi/-mfpu, so the arm-linux-gnueabihf triple made hard-float objects while the TV's userland is softfp, and Chrome crashed at start (in frexp()). |
| `0013-browser-window-insets-before-frame-exists.patch` | neva creates the webOS toplevel inside WaylandWindow::Initialize(), so SetSizeConstraints() and TriggerStateChanges() reach CalculateInsetsInDIP() and UpdateFrameHints() before platform_window(), the native widget and the frame view exist, and Chrome crashed on its first window. |
| `0014-webos-wl-shell-surface-configured.patch` | WaylandFrameManager waits for OnSurfaceConfigureEvent() before the first frame, but the webOS wl_shell path never calls it, and LSM only shows a window after its first buffer, so nothing was ever drawn. |
| `0015-webos-activate-on-key-press.patch` | The remote's keys reach Chrome, but the window loses aura activation at wl_keyboard.enter and LSM never sends an "activated" state to restore it. |
| `0016-webos-keyboard-on-any-seat.patch` | WaylandConnection::IsKeyboardAvailable() looks at one wl_seat only. |
| `0017-webos-tv-remote-and-keyboard.patch` | Makes the LG remote and LG's on-screen keyboard work with Chrome's own UI. |
| `0019-tv-libwayland-link.patch` | Chrome must use the TV's libwayland: the TV's EGL driver uses it, and two libwayland copies sharing one wl_display crash at GPU start. use_system_libwayland does not work, because Chrome needs protocol headers newer than the TV's libwayland 1.20. |
| `0023-webos-hwvideo-renderer.patch` | Hardware video, part 1. Clear H.264, HEVC, VP9 and AV1 video (files and MSE) plays on LG's decoder through NDL DirectMedia in the app's launcher (package/launcher/cnrun.c), the only process allowed to use the app's media names. |
| `0024-webos-hwvideo-viz-hole.patch` | Hardware video, part 2. The TV shows the video on a plane below the window, so viz must leave a transparent hole. |
| `0025-webos-hwvideo-video-window.patch` | Hardware video, part 3. LSM shows the video plane only for a video window exported from the app window's own surface. |
| `0026-webos-hwvideo-rgba-output.patch` | Hardware video, part 4. The TV's PowerVR driver reports 0 for GL_ALPHA_BITS (not part of GLES 3) although the EGL config has 8 alpha bits, so viz drew opaque pixels over the hole. |
| `0027-no-sandbox-warning.patch` | Chrome's warning bar for --no-sandbox shows at every start, as in stock Chrome, without the X. |
| `0028-neva-null-webcontents-delegate.patch` | neva's app-runtime code calls web_contents->GetDelegate()->GetAllowLocalResourceLoad() without a null check, which crashes when a tab commits its first navigation before it has a delegate (for example DevTools opening about:blank). |
| `0030-webos-menus-fit-browser-window.patch` | neva builds with USE_SINGLE_WINDOW_MODE, so menus are child windows inside the browser window, but MenuController skips screen fitting on Wayland and uses the display bounds. |
| `0031-glibc-compat-older-tvs.patch` | One build for older TVs (glibc 2.24, libwayland 1.10 and newer). |
| `0032-webos-ui-scale-without-viewporter.patch` | Sharp UI at 1080p. |
| `0033-egl14-platform-display-fallback.patch` | Chrome calls eglGetPlatformDisplay (EGL 1.5) without checking that the driver has it, and crashed at GPU start on TVs with EGL 1.4. |
| `0034-webos-optional-foreign-interfaces.patch` | Some webOS 4 TVs have no wl_webos_foreign and wl_webos_exported interfaces, and the browser did not load because patch 0025 references them. |
| `0035-webos-text-model-input-panel-rect-optional.patch` | Older TVs have a text_model with fewer than 15 requests, without the input panel rect requests. |
| `0036-webos-subcompositor-optional.patch` | webOS 4 TVs have no wl_subcompositor, and CreateSubsurface hit a DCHECK and a null dereference. |
| `0037-webos-data-device-manager-optional.patch` | webOS 4 TVs have no wl_data_device_manager, so the data and window drag controllers are never created, and several callers dereferenced them without a check. |
| `0039-webos-hwvideo-old-ndl-gate.patch` | Hardware video on webOS 4 (NDL API 1, CN_NDL_API=old). |
| `0040-webos-hwvideo-nohw-software-fallback.patch` | Hardware video on webOS 4. When an old-API call fails, the launcher sends NOHW. |
| `0041-glibc224-memfd-seals.patch` | glibc 2.24 (webOS 4) has no memfd_create() and no F_ADD_SEALS/F_SEAL_* constants (added in 2.27). v8 calls memfd_create through the raw syscall, as mojo already does, and mojo defines the kernel's seal values when the headers lack them. |
| `0043-webos-enter-with-keyboard-or-after-arrow.patch` | Enter had to be pressed twice in text fields, because the first OK on a focused field opens LG's keyboard (patch 0017). |
| `0045-webos-root-surface-whole-input-region.patch` | LSM sends pointer events only where a surface's input region contains the pointer, and on some TVs the Magic Remote pointer never reached the window. |
| `0047-webos-luna-no-handle-log-once.patch` | Chrome's media session calls to LG's luna services fail without a luna handle, and each failure logged an error, about once a second during video. |
| `0048-webos-hwvideo-old-ndl-decode-order-pacing.patch` | Hardware video on webOS 4. H.264 B-frames arrive in decode order, and gating each frame on its display time sent them in bursts; the old decoder shows frames as they arrive, so 1080p stuttered. |
| `0049-webos-media-playstate-file.patch` | Chrome's media session calls to com.webos.service.mediacontroller fail without a luna handle, so webOS never knew media was playing and the screen saver came on. |
| `0050-glibc224-sandbox-seals-ptrace.patch` | glibc 2.24 (webOS 4) has no F_ADD_SEALS/F_GET_SEALS/F_SEAL_* constants and, on ARM, no PTRACE_GET_THREAD_AREA/PTRACE_GETVFPREGS. |
| `0052-webos-egl-buffer-scale-without-ui-scale.patch` | Clicks with the pointer landed in the wrong place (at half the pointer's position) with the 1080p window from patch 0032. |
| `0053-webos-no-caption-buttons.patch` | The window is always full screen on webOS, yet the tab strip showed minimise, maximise and close buttons, and minimise left no way back. |
| `0054-neva-vizfmp-swap-needs-compositor.patch` | adblock-tester.com crashed the tab ("Aw, Snap!") in 0.0.66: neva's NotifyVizFMPSwap() used the LayerTreeHost of a WebView that does not composite and has none. |
| `0055-webos-hwvideo-hevc-type-check.patch` | Hardware video. HEVC never reached the NDL renderer: the type check asked for a GPU-process hardware decoder the TV does not have. |
| `0056-armv8-aarch32-fpu-and-tune.patch` | Opt-in (arm_version = 8): a build for ARMv8 TVs gets the ARMv8 FPU and Cortex-A55 scheduling, which GN args cannot set in M151. No change with the default args. |
| `0057-webos-back-and-exit.patch` | The remote's Back and Chrome's Exit behave like a TV app. |
| `0058-wayland-watcher-exit-hang.patch` | Chrome's exit could hang after its window closed (black screen until bin/run killed it, 3 of 5 exits in the twin). |
| `0059-no-google-background-services.patch` | Less talking to Google in the background (apps-repo review, measured with a net log in the twin): no FCM invalidation listeners (cloud policy and remote commands, which a TV never has; they checked in and registered with android.clients.google.com and mtalk.google.com at every start), no requests to accounts.google.com while no OAuth client is set up (ListAccounts at every start; signing in can't work without keys, and with the user's own keys the block steps aside), and no on-device AI models manifest (update.googleapis.com and edgedl.me.gvt1.com at every start). |
| `0060-profile-menu-signin-unavailable.patch` | Without Google API keys, signing in to the browser and sync can't work, but the account menu offered "Sign in to Chromium" anyway. |
| `0061-webos-remote-in-bubbles-and-chrome-pages.patch` | The remote's arrows did nothing in bubbles and dialogs, and on chrome://history neither Up nor Back responded. |
| `0062-wayland-watcher-untimed-wait.patch` | 0058 made the omnibox 4-5x slower to reach the screen on an LG C1 (paint to present 81-136 ms against 19-29 ms): its watcher thread waited in 500 ms steps. It now waits once, untimed, and the exit still does not hang. |
