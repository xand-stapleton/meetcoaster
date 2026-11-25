# Meetcoaster

A macOS menu bar meeting planner. Open **Meetcoaster** in the menu bar to see
the meeting time in every saved location. Choose a city to inspect its clock
changes, make it the source, or remove it. Use **Set time** or **Set date** directly below the meeting time.
**Edit meeting** changes the title and duration. The menu also supports city
search and calendar export.

## Run

On macOS with Go 1.25 or newer and the Xcode Command Line Tools installed:

```sh
make run
```

Run `make install` to install in `~/Applications`, or
`make install APPLICATIONS_DIR=/Applications` for a system-wide install.
Open the installed app and select **Launch at Login** to start it automatically
at sign-in on macOS 13 or later. Select it again to turn it off.
Use **Quit Meetcoaster** to close the app.

## Shared backend

Meetcoaster uses native AppKit menus and dialogs through Go's cgo bridge.
The Go packages in the `meetlet-lib/` Git subtree handle scheduling,
daylight-saving changes, geocoding, settings and ICS files. An ordinary clone
contains everything needed from this library.

Meetcoaster and the Meetlet terminal frontend use the same config file
(`~/.config/meetlet/config.yaml` by default, or `MEETLET_CONFIG`).
Locations and the source are saved. Each launch starts a new one-hour meeting
at the current local time, with the system time zone first in the list. IANA zones and custom labels such as
`Home=Europe/London` work offline. Worldwide city lookup uses Open-Meteo
and GeoNames.

Run `make test` to test the app and the library. To update the subtree from
a sibling library checkout, use:

```sh
git subtree pull --prefix=meetlet-lib ../meetlet-lib main --squash
```
