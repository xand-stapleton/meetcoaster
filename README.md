# Meetcoaster

<img src="img/meetcoaster_logo_filled.svg" alt="Clinking beer mugs" width="160">

A macOS menu bar app for planning meetings across time zones. Pick a date and time, compare cities, and export a calendar event. Meetcoaster shares its settings and scheduling code with [Meetlet](https://github.com/xand-stapleton/meetlet) through [Meetlet Lib](https://github.com/xand-stapleton/meetlet-lib).

With Go 1.25 or later and Xcode Command Line Tools, use `make run` to launch, `make install` to install in `/Applications`, or `make test` to run the tests. For a per-user install, run `make install APPLICATIONS_DIR="$HOME/Applications"`. Launch at Login requires macOS 13 or later.
