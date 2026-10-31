# Changelog

## Unreleased

- Fixed a leak that grew memory by about 40 MB a day after the popover or window had been
  opened once: hidden SwiftUI views kept re-rendering on every system tick.
- Disk scan no longer holds about 1 KB per file until it finishes (2 GB peak on a large home
  folder).

## 0.2.0

- Native redesign: system controls, typography and materials (Liquid Glass on macOS 26), and a
  unified window toolbar with search.
  - Context menus and keyboard shortcuts: ⌘⌫ quit or delete, ⌘R rescan, ⌥⌘R reveal in Finder.
  - Replaced the custom theme and bundled fonts.
- Gear menu in the popover and window: launch at login, scan interval, quit.
- Memory shown in binary units, matching Activity Monitor.
- Files table split into name and location columns, and is now sortable by name, location, size and date.
- Selecting a folder and a file inside it deletes only the folder.
- App icon.
- `scripts/install.sh` picks your Apple Development identity automatically. The project builds
  ad-hoc signed out of the box, and CI builds and tests on every push.

## 0.1.0

- Menu-bar memory and disk indicator, popover with top-5 processes and disk items.
- Processes: quit, force quit, relaunch; files: reveal, permanent delete behind path validation.
- Background scan of `~` with cache, launch at login.
