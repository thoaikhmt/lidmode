# Lid Mode

Turn a Linux laptop into a small always-on machine: with **server mode** on,
closing the lid switches the screen off but the computer keeps running — no
suspend, no idle sleep — so SSH sessions, downloads, builds and background
servers stay alive.

- **On** — holds a logind block inhibitor (`handle-lid-switch`, `idle`, `sleep`)
  for as long as you want, then releases it.
- **Off** — normal laptop behaviour: lid close suspends, the idle timer
  suspends.
- No root, no daemon, no boot-time service. Nothing about the machine is
  permanently changed.

![Server mode on](data/screenshots/on.png)

## Install

### Flatpak (development build)

```bash
flatpak install flathub org.flatpak.Builder org.gnome.Platform//51 org.gnome.Sdk//51
flatpak run --command=flatpak-builder org.flatpak.Builder \
  --user --install --force-clean build-dir \
  flatpak/io.github.thoaikhmt.LidMode.yml
```

(Once the Flathub submission is merged: `flatpak install flathub io.github.thoaikhmt.LidMode`.)

### From source

```bash
git clone https://github.com/thoaikhmt/lidmode.git
cd lidmode
./install.sh
```

This symlinks `lidmode` and `lidmode-app` into `~/.local/bin` and installs the
desktop entry, icon and AppStream metadata for the current user. Remove the
shortcuts with `./install.sh --uninstall`.

## Use the app

Launch **Lid Mode** from the app grid:

- **Server mode** — switch "Keep running with the lid closed", plus a duration
  picker (1 h / 4 h / 8 h / 24 h / **Forever**, the default).
- **Status** — expiry, when it was enabled, power source/battery state and lid
  state.
- A banner when it's on, and a battery warning when it's on and unplugged.

In the Flatpak build the app holds the inhibitor itself, so **closing the window
keeps it running in the background** while server mode is on; quitting the app
(reopening it, then menu → Quit) turns server mode off.

## Use the CLI (source installs)

```bash
lidmode on            # until you turn it off
lidmode on 8h         # optional timer: 90m, 1d, 1h30m, 3600
lidmode status
lidmode status --json # machine-readable
lidmode off
lidmode toggle
```

Example:

```
● Server mode ON — until you turn it off
  power     AC · battery 79% (holding 80% limit)
  lid       open
  since     Sat 21 Nov 19:30
  unit      lidmode-awake.service
```

Keybindings:

```bash
lidmode-app --toggle   # flip state
```

Suggested shortcut: Settings → Keyboard → Custom Shortcuts →
`lidmode-app --toggle` on e.g. `Super+F12`.

## How it works

- **Source installs:** `lidmode on` starts a transient `systemd --user` unit
  running `systemd-inhibit --what=handle-lid-switch:idle:sleep --mode=block
  sleep infinity`. The unit is not enabled at boot and disappears when you turn
  server mode off.
- **Flatpak:** the app calls `org.freedesktop.login1.Manager.Inhibit()` on the
  system bus and keeps the returned file descriptor open (the same mechanism
  `systemd-inhibit` uses). The sandbox needs
  `--system-talk-name=org.freedesktop.login1` for this.

In both cases the screen is untouched: Mutter switches the panel off on lid
close and GNOME still locks/blanks on idle. The CPU, network and your processes
keep running.

### Why the Flatpak needs system bus access

`--system-talk-name=org.freedesktop.login1` exists solely to call
`Manager.Inhibit("handle-lid-switch:idle:sleep", "block")`. There is no portal
that can prevent a lid-close suspend: `org.freedesktop.portal.Inhibit` with the
`suspend` flag produces a **weak** logind inhibitor (`block-weak`), which logind
ignores when it performs the lid action. The app requests no filesystem,
network, device or session-bus access beyond Wayland/X11, IPC and DRI for
rendering, and it makes no other logind calls.

Power state is read from sysfs, including vendor charge thresholds, so a
ThinkPad sitting at its 80% charge limit shows `holding 80% limit` rather than
a misleading `Not charging`, and USB-C ports are not mistaken for mains power.

## Caveats

- **Heat.** A closed laptop still vents. Keep it on a hard surface with the
  vents clear; don't leave it running closed inside a bag.
- **Battery.** Server mode does not stop the battery from draining; the app
  warns when you enable it on battery.
- **Session lifetime.** Source installs: the inhibitor lives in your user
  systemd manager, so it ends on logout/reboot. Flatpak: it ends when the app
  quits.
- **Reboot.** Not persistent by design — turn server mode on again after
  rebooting.
- Manual suspend is blocked while server mode is on.

## Packaging (Flathub)

Layout:

```
bin/lidmode                        CLI + logind/systemd logic (source installs)
bin/lidmode-app                    GTK4/libadwaita GUI (both backends)
data/io.github.thoaikhmt.LidMode.desktop
data/io.github.thoaikhmt.LidMode.metainfo.xml
data/icons/hicolor/scalable/apps/io.github.thoaikhmt.LidMode.svg
data/screenshots/{on,off}.png
flatpak/io.github.thoaikhmt.LidMode.yml
install.sh
```

Checks:

```bash
appstreamcli validate --no-net data/io.github.thoaikhmt.LidMode.metainfo.xml
desktop-file-validate data/io.github.thoaikhmt.LidMode.desktop
python3 -m py_compile bin/lidmode-app
bash -n bin/lidmode
```

Submitting to Flathub (after pushing a release tag):

1. Fork `flathub/flathub` and create a branch from `new-pr`:
   `git checkout -b lidmode new-pr`.
2. Copy `flatpak/io.github.thoaikhmt.LidMode.yml` into the fork's root.
3. Commit, push, and open a PR against `flathub/flathub:new-pr`.
4. Answer the review bot: the app ID is verified via GitHub (`io.github.thoaikhmt`),
   the source tag must exist, and the build must pass `flatpak-builder`.
   Flathub builds with `org.gnome.Platform//51`; no extra modules are needed
   because PyGObject/GTK/libadwaita come from the runtime.

## License

MIT — see [LICENSE](LICENSE).
