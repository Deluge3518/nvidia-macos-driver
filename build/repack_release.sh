#!/bin/bash
# repack_release.sh <base.tar.gz> <kexts-dir> <version> <out-dir>
# Takes the base package (nullmoth's release, its install.sh / uninstall.sh / runtime checks / NVRM / NVRMAGDC),
# replaces the kexts this tree builds (NVAccel for macOS 15 and 26, NVRMFB) with the ones CI built, regenerates
# SHA256SUMS (install.sh verifies it with `shasum --strict -c`), and writes nullmoth-nvidia-<version>.tar.gz.
# Layout install.sh reads: accelerators from Library/NullMoth/kexts/<major>/NVAccel.kext, the other kexts from
# Library/Extensions/<name>.kext. BASELINE-IDENTITY.json's paired_kexts hashes are metadata only (install.sh does
# not verify them), but they are updated so the file does not lie.
set -euo pipefail
BASE=$1; KX=$2; VER=$3; OUT=$4
[ -f "$BASE" ] || { echo "no base package at $BASE"; exit 1; }
for k in "$KX/15/NVAccel.kext" "$KX/26/NVAccel.kext" "$KX/NVRMFB.kext"; do
  [ -d "$k" ] || { echo "missing $k"; exit 1; }
done
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
tar -xzf "$BASE" -C "$WORK"
PKG="$WORK/pkgroot"
[ -f "$PKG/install.sh" ] || { echo "the base package has no pkgroot/install.sh"; exit 1; }

replace_kext() {  # replace_kext <src.kext> <dest.kext>
  rm -rf "$2" && cp -R "$1" "$2"
}
replace_kext "$KX/15/NVAccel.kext" "$PKG/Library/NullMoth/kexts/15/NVAccel.kext"
replace_kext "$KX/26/NVAccel.kext" "$PKG/Library/NullMoth/kexts/26/NVAccel.kext"
replace_kext "$KX/NVRMFB.kext"     "$PKG/Library/Extensions/NVRMFB.kext"
# older package layouts also carry NVAccel in Extensions; keep the pair consistent wherever it exists
[ -d "$PKG/Library/Extensions/NVAccel.kext" ] && replace_kext "$KX/15/NVAccel.kext" "$PKG/Library/Extensions/NVAccel.kext"

sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
python3 - "$PKG" "$VER" "$(sha "$KX/NVRMFB.kext/Contents/MacOS/NVRMFB")" "$(sha "$KX/15/NVAccel.kext/Contents/MacOS/NVAccel")" <<'EOF'
import json, sys
pkg, ver, fb_sha, accel_sha = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
p = pkg + "/BASELINE-IDENTITY.json"
d = json.load(open(p))
d["package_version"] = ver
if "paired_kexts" in d:
    if "NVRMFB" in d["paired_kexts"]: d["paired_kexts"]["NVRMFB"]["sha256"] = fb_sha
    if "NVAccel" in d["paired_kexts"]: d["paired_kexts"]["NVAccel"]["sha256"] = accel_sha
d["scope"] = d.get("scope", "") + f" Rebuilt NVAccel (macOS 15 and 26) and NVRMFB from the {ver} source tree by CI; NVRM, NVRMAGDC and the Metal userland are the base package's."
json.dump(d, open(p, "w"), indent=2)
EOF

(cd "$PKG" && find . -type f ! -name SHA256SUMS -print | sed 's|^\./||' | sort | xargs shasum -a 256 > SHA256SUMS)
(cd "$PKG" && shasum -a 256 --strict -c SHA256SUMS --quiet)

mkdir -p "$OUT"
TAR="$OUT/nullmoth-nvidia-$VER.tar.gz"
tar -czf "$TAR" -C "$WORK" pkgroot
echo "repacked: $TAR ($(du -sh "$TAR" | cut -f1))"
