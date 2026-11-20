#!/usr/bin/env python3
"""mkipk.py: build the browser IPK (stdlib only, reproducible: fixed times and owners). Runs on the build host.

  python3 package/mkipk.py --browser dl/artifacts/<id>/browser.tar.zst --version 0.0.1 \
      --launcher package/launcher/out/cnrun --lib-dir <nss lib dir> --out dl/ipk
  -> dl/ipk/<APP_ID>_<version>_arm.ipk  (+ .sha256)

IPK = ar archive with members debian-binary, control.tar.gz, data.tar.gz (bare member names; GNU ar's trailing '/'
breaks installs). data.tar.gz holds usr/palm/applications/<APP_ID>/... and usr/palm/packages/<APP_ID>/packageinfo.json,
as LG's ares-package writes them (no "./" prefix): webosbrew's apps-repo checks read the package that way. The
directory name must equal the appinfo id.
APP_ID, APP_TITLE come from config.env. Never put anything from the TV rootfs into the IPK.
"""
import argparse
import gzip
import hashlib
import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MTIME = 1760000000


def config():
    c = {}
    for line in open(os.path.join(ROOT, "config.env")):
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            c[k] = v.strip().strip('"')  # the shell scripts source this file, so values with spaces are quoted
    return c


def tgz(entries):
    """entries: list of (path, bytes or None for a directory, mode)"""
    b = io.BytesIO()
    with gzip.GzipFile(fileobj=b, mode="wb", mtime=MTIME, compresslevel=9) as gz, \
            tarfile.open(fileobj=gz, mode="w", format=tarfile.GNU_FORMAT) as t:
        for path, data, mode in entries:
            ti = tarfile.TarInfo(path)
            ti.mtime, ti.mode, ti.uid, ti.gid, ti.uname, ti.gname = MTIME, mode, 0, 0, "root", "root"
            if data is None:
                ti.type = tarfile.DIRTYPE
                t.addfile(ti)
            else:
                ti.size = len(data)
                t.addfile(ti, io.BytesIO(data))
    return b.getvalue()


def ar(members):
    out = io.BytesIO(b"!<arch>\n")
    out.seek(0, 2)
    for name, data in members:
        out.write(("%-16s%-12d%-6d%-6d%-8o%-10d`\n" % (name, MTIME, 0, 0, 0o100644, len(data))).encode())
        out.write(data)
        if len(data) % 2:
            out.write(b"\n")
    return out.getvalue()


def tree(src, prefix):
    """{relative path: (bytes, mode)} for every file under src, stored under prefix/."""
    files = {}
    for r, _, fs in os.walk(src):
        for f in fs:
            p = os.path.join(r, f)
            rel = os.path.join(prefix, os.path.relpath(p, src))
            mode = 0o755 if os.access(p, os.X_OK) else 0o644
            files[rel] = (open(p, "rb").read(), mode)
    return files


def shipped_libs(libdir):
    """{lib/<name>: (bytes, mode)} for the names in container/nss/ship-list.txt. Fails if one is missing from libdir."""
    names = [n.strip() for n in open(os.path.join(ROOT, "container", "nss", "ship-list.txt")) if n.strip()]
    files = {}
    for n in names:
        p = os.path.join(libdir, n)
        if not os.path.isfile(p):
            raise SystemExit("--lib-dir: %s is missing from %s" % (n, libdir))
        mode = 0o755 if os.access(p, os.X_OK) else 0o644
        files["lib/" + n] = (open(p, "rb").read(), mode)
    return files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--browser", required=True, help="browser.tar.zst from a build (artifacts/<id>/)")
    ap.add_argument("--start", default="", help="optional extra start page directory (old test page; not shipped)")
    ap.add_argument("--ui", help="browser_shell web UI directory (fallback MY only)")
    ap.add_argument("--version", required=True, help="x.y.z (three integers)")
    ap.add_argument("--out", default=os.path.join(ROOT, "dl", "ipk"))
    ap.add_argument("--launcher", default=os.path.join(HERE, "launcher", "out", "cnrun"),
                    help="cnrun binary (launcher/build.sh); becomes bin/run, run.sh becomes bin/run.sh. "
                         "'none' = old layout (run.sh as bin/run, no hardware video)")
    ap.add_argument("--requires", default="",
                    help="minimum TV for bin/requires (launcher check), e.g. 'glibc=2.24,webos=webOS 4.4'")
    ap.add_argument("--lib-dir", default="",
                    help="folder with the NSS and NSPR libraries listed in container/nss/ship-list.txt; shipped as lib/<name>")
    ap.add_argument("--locales", default="en-US", help="UI locales to ship, comma separated (run.sh uses --lang=en-US)")
    ap.add_argument("--app-id", default="", help="app id instead of APP_ID from config.env")
    ap.add_argument("--title", default="", help="app title instead of APP_TITLE from config.env")
    ap.add_argument("--badge", default="",
                    help="small label on the launcher icons, e.g. OLD for the old app id's last release (needs Pillow)")
    ap.add_argument("--moved-to", default="",
                    help="last release under an old app id: the app id it moved to. Adds bin/moved-to (run.sh then hands "
                         "bookmarks and history over and opens moved.html)")
    a = ap.parse_args()
    c = config()
    app_id, title = a.app_id or c["APP_ID"], a.title or c["APP_TITLE"]
    assert all(p.isdigit() for p in a.version.split(".")) and a.version.count(".") == 2, "version must be x.y.z"
    files = {}
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(f"zstd -dc '{a.browser}' | tar -C '{tmp}' -xf -", shell=True, check=True)
        files.update(tree(os.path.join(tmp, "browser"), "browser"))
    # SIZE (2026-10-29): the TV's appstore partition had 33 MB free. Like the Firefox port, ship one UI locale
    # (114 locales were 121 MB installed) and drop files this build never uses: Vulkan SwiftShader (Vulkan and the GPU
    # are disabled in run.sh), headless resources.
    # chrome_200_percent.pak has to stay: the UI is drawn at 1.5x, which loads the 2x icons. Without it Chromium
    # paints its yellow "missing image" square in Settings and elsewhere (seen on the TV with 0.0.65).
    keep = {"browser/locales/%s.pak" % l for l in a.locales.split(",")}
    # (2026-10-31) also: about_credits.html (18.8 MB build output; chrome://credits is served from resources.pak),
    # and the Vulkan loader (Vulkan is off).
    drop = {"browser/libvk_swiftshader.so", "browser/vk_swiftshader_icd.json",
            "browser/headless_command_resources.pak", "browser/about_credits.html", "browser/libvulkan.so.1"}
    # Chromium's credits (every third-party licence, as chrome://credits) ship compressed in licenses/ (2 MB, not 19 MB)
    credits = files.get("browser/about_credits.html")
    if credits:
        files["licenses/chromium-credits.html.gz"] = (gzip.compress(credits[0], 9, mtime=0), 0o644)
    for rel in list(files):
        if (rel.startswith("browser/locales/") and rel not in keep) or rel in drop:
            del files[rel]
    assert "licenses/chromium-credits.html.gz" in files, "browser.tar.zst has no about_credits.html"
    assert keep <= set(files), "locale pak missing: %s" % (keep - set(files))
    if a.start:
        files.update(tree(a.start, "start"))
    files.update(tree(os.path.join(HERE, "ext"), "ext"))  # built-in extensions (run.sh --load-extension)
    files["fonts.conf"] = (open(os.path.join(HERE, "fonts.conf"), "rb").read(), 0o644)  # run.sh FONTCONFIG_FILE
    if a.ui:
        files.update(tree(a.ui, "ui"))
    if a.lib_dir:
        files.update(shipped_libs(a.lib_dir))
    lic = os.path.join(ROOT, "package", "licenses")
    if os.path.isdir(lic):
        files.update(tree(lic, "licenses"))
    if a.moved_to:
        files["bin/moved-to"] = (a.moved_to.encode() + b"\n", 0o644)
        files["moved.html"] = (open(os.path.join(HERE, "moved.html"), "rb").read(), 0o644)
    info = open(os.path.join(HERE, "appinfo.json.in")).read()
    info = info.replace("@APP_ID@", app_id).replace("@VERSION@", a.version).replace("@APP_TITLE@", title)
    json.loads(info)
    files["appinfo.json"] = (info.encode(), 0o644)
    run_sh = open(os.path.join(HERE, "run.sh"), "rb").read()
    if a.launcher != "none":
        # hardware video: luna-service2 lets only the role's exe (bin/run) use the app's media bus names
        files["bin/run"] = (open(a.launcher, "rb").read(), 0o755)
        files["bin/run.sh"] = (run_sh, 0o755)
        if a.requires:
            files["bin/requires"] = ("\n".join(x.strip() for x in a.requires.split(",")).encode() + b"\n", 0o644)
    else:
        files["bin/run"] = (run_sh, 0o755)
    for name in ("icon.png", "largeIcon.png", "splash.png"):  # Chromium logo (chrome/app/theme/chromium/product_logo_256.png)
        icon = os.path.join(HERE, name)
        if os.path.isfile(icon):
            files[name] = (open(icon, "rb").read(), 0o644)
    if a.badge:  # small grey label on the launcher icons (tools/beta/badge.py, needs Pillow)
        with tempfile.TemporaryDirectory() as tmp:
            for name in ("icon.png", "largeIcon.png"):
                out = os.path.join(tmp, name)
                subprocess.run([sys.executable, os.path.join(ROOT, "tools", "beta", "badge.py"), os.path.join(HERE, name),
                                out, a.badge, "small"], check=True)
                files[name] = (open(out, "rb").read(), 0o644)
    base = "usr/palm/applications/" + app_id
    # data/: the browser profile, cache and lastlog (bin/run.sh). The installer extracts the app folder as root with
    # the modes in this archive, so the app's own user can only write to a folder that comes writable from here.
    # run.sh keeps the profile and cache themselves private (mode 700, owned by the app's user).
    ents = [("usr", None, 0o755), ("usr/palm", None, 0o755), ("usr/palm/applications", None, 0o755),
            (base, None, 0o755), (base + "/data", None, 0o1777)]
    dirs = set()
    for rel in sorted(files):
        parts = rel.split("/")[:-1]
        for i in range(1, len(parts) + 1):
            d = "/".join(parts[:i])
            if d not in dirs:
                dirs.add(d)
                ents.append((base + "/" + d, None, 0o755))
        data, mode = files[rel]
        ents.append((base + "/" + rel, data, mode))
    # packageinfo.json: which app (and services) the package holds, as ares-package writes it. webosbrew-ipk-verify
    # (apps-repo PR check) opens a package through this file.
    pkg = "usr/palm/packages/" + app_id
    pinfo = json.dumps({"id": app_id, "version": a.version, "app": app_id, "services": []}, indent=2).encode() + b"\n"
    ents += [("usr/palm/packages", None, 0o755), (pkg, None, 0o755), (pkg + "/packageinfo.json", pinfo, 0o644)]
    kib = sum(len(d) for d, _ in files.values()) // 1024 + 1
    control = (f"Package: {app_id}\nVersion: {a.version}\nSection: misc\nPriority: optional\nArchitecture: arm\n"
               f"Installed-Size: {kib}\nMaintainer: chromium-native\nDescription: {title} (native webOS Chromium)\n"
               "webOS-Package-Format-Version: 2\nwebOS-Packager-Version: x.y.x\n")
    data = ar([("debian-binary", b"2.0\n"), ("control.tar.gz", tgz([("control", control.encode(), 0o644)])),
               ("data.tar.gz", tgz(ents))])
    os.makedirs(a.out, exist_ok=True)
    out = os.path.join(a.out, f"{app_id}_{a.version}_arm.ipk")
    with open(out, "wb") as f:
        f.write(data)
    h = hashlib.sha256(data).hexdigest()
    with open(out + ".sha256", "w") as f:
        f.write(f"{h}  {os.path.basename(out)}\n")
    print(f"{out}: {len(data) / 1e6:.1f} MB, installed {kib / 1024:.0f} MB, sha256 {h}")


if __name__ == "__main__":
    main()
