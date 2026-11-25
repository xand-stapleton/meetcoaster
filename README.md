# Meetcoaster

A macOS menu bar meeting planner. Open **Meetcoaster** in the menu bar to see
the meeting time in every saved location. Choose a city to inspect its clock
changes, make it the source, or remove it. **Edit meeting** changes the date,
local time, title and duration. The menu also supports city search and calendar
file export and deletion.

## Run

On macOS with Go 1.25 or newer and the Xcode Command Line Tools installed:

```sh
make run
```

To install, copy the resulting `build/Meetcoaster.app` to Applications.
Use **Quit Meetcoaster** to close the app.

## Shared backend

Meetcoaster uses native AppKit menus and dialogs through Go's cgo bridge.
The Go packages in the `meetlet-lib/` Git subtree handle scheduling,
daylight-saving changes, geocoding, settings and ICS files. An ordinary clone
contains everything needed from this library.

Meetcoaster and the Meetlet terminal frontend use the same config file
(`~/.config/meetlet/config.yaml` by default, or `MEETLET_CONFIG`).
Locations and the source are saved. Each launch starts a new one-hour meeting
at 15:00 in the source location. IANA zones and custom labels such as
`Home=Europe/London` work offline. Worldwide city lookup uses Open-Meteo
and GeoNames.

Run `make test` to test the app and the library. To update the subtree from
a sibling library checkout, use:

```sh
git subtree pull --prefix=meetlet-lib ../meetlet-lib main --squash
```
