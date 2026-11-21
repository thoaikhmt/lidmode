#!/usr/bin/env bash
# Install (or remove) Lid Mode in the current user's ~/.local tree.
#
#   ./install.sh              install / refresh from this checkout
#   ./install.sh --uninstall  remove shortcuts (leaves the repo alone)
set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PREFIX=${PREFIX:-$HOME/.local}
BIN_DIR=$PREFIX/bin
APP_DIR=$PREFIX/share/applications
ICON_DIR=$PREFIX/share/icons/hicolor/scalable/apps
META_DIR=$PREFIX/share/metainfo
APP_ID=io.github.thoaikhmt.LidMode

clean_caches() {
    command -v update-desktop-database >/dev/null && update-desktop-database "$APP_DIR" 2>/dev/null || true
    command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$PREFIX/share/icons/hicolor" >/dev/null 2>&1 || true
}

uninstall() {
    rm -f "$BIN_DIR/lidmode" "$BIN_DIR/lidmode-app" \
        "$APP_DIR/$APP_ID.desktop" "$APP_DIR/dev.thoai.Lidmode.desktop" "$APP_DIR/lidmode.desktop" \
        "$ICON_DIR/$APP_ID.svg" "$ICON_DIR/lidmode.svg" \
        "$META_DIR/$APP_ID.metainfo.xml"
    clean_caches
    printf 'Removed Lid Mode from %s\n' "$PREFIX"
    printf 'Server mode state is untouched; turn it off with: lidmode off\n'
}

if [[ ${1:-} == --uninstall || ${1:-} == -u ]]; then
    uninstall
    exit 0
fi

chmod +x "$REPO/bin/lidmode" "$REPO/bin/lidmode-app"

mkdir -p "$BIN_DIR" "$APP_DIR" "$ICON_DIR" "$META_DIR"
ln -sfn "$REPO/bin/lidmode" "$BIN_DIR/lidmode"
ln -sfn "$REPO/bin/lidmode-app" "$BIN_DIR/lidmode-app"
install -m 0644 "$REPO/data/icons/hicolor/scalable/apps/$APP_ID.svg" "$ICON_DIR/$APP_ID.svg"
install -m 0644 "$REPO/data/$APP_ID.metainfo.xml" "$META_DIR/$APP_ID.metainfo.xml"

sed -e "s|^Exec=lidmode-app$|Exec=$BIN_DIR/lidmode-app|" \
    -e "s|^Exec=lidmode-app --toggle$|Exec=$BIN_DIR/lidmode-app --toggle|" \
    "$REPO/data/$APP_ID.desktop" >"$APP_DIR/$APP_ID.desktop"
chmod 0644 "$APP_DIR/$APP_ID.desktop"

# Clean up entries from older versions of this project.
rm -f "$APP_DIR/lidmode.desktop" "$APP_DIR/dev.thoai.Lidmode.desktop" "$ICON_DIR/lidmode.svg"

if command -v desktop-file-validate >/dev/null; then
    desktop-file-validate "$APP_DIR/$APP_ID.desktop" || true
fi
if command -v appstreamcli >/dev/null; then
    appstreamcli validate --no-net "$META_DIR/$APP_ID.metainfo.xml" >/dev/null || true
fi
clean_caches

missing=()
if ! python3 -c 'import gi; gi.require_version("Gtk", "4.0"); from gi.repository import Gtk' 2>/dev/null; then
    missing+=("gtk4")
fi
if ! python3 -c 'import gi; gi.require_version("Adw", "1"); from gi.repository import Adw' 2>/dev/null; then
    missing+=("libadwaita")
fi
if ((${#missing[@]})); then
    printf 'warning: missing Python GI modules: %s (the GUI will not start)\n' "${missing[*]}" >&2
fi

cat <<EOF
Installed:
  $BIN_DIR/lidmode
  $BIN_DIR/lidmode-app
  $APP_DIR/$APP_ID.desktop
  $ICON_DIR/$APP_ID.svg

Open "Lid Mode" from the app grid, or run:
  lidmode status
  lidmode on          # until you turn it off
  lidmode on 8h       # optionally with a timer
  lidmode off

Optional: bind a keyboard shortcut to "lidmode-app --toggle"
  Settings → Keyboard → Custom Shortcuts
EOF
