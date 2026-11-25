// Meetcoaster is the native macOS menu bar frontend to meetlet-lib.
package main

/*
#cgo CFLAGS: -fobjc-arc
#cgo LDFLAGS: -framework Cocoa -framework UniformTypeIdentifiers -framework ServiceManagement
#include "native.h"
*/
import "C"

import (
	"context"
	"errors"
	"fmt"
	"os"
	"runtime"
	"strings"
	"time"
	"unsafe"

	"github.com/xand-stapleton/meetlet-lib/calendar"
	"github.com/xand-stapleton/meetlet-lib/places"
	"github.com/xand-stapleton/meetlet-lib/planner"
	"github.com/xand-stapleton/meetlet-lib/settings"
)

var (
	cfg        settings.Config
	path       string
	meeting    planner.Meeting
	startupErr error
	actions    []func() error
	searching  bool
	results    = make(chan searchResult, 1)
)

func main() {
	runtime.LockOSThread()
	path, startupErr = settings.Path()
	if startupErr == nil {
		cfg, startupErr = settings.Load(path)
	}
	if startupErr == nil {
		cfg = cfg.WithLocalSource()
		meeting, startupErr = planner.NewMeeting(cfg, time.Now())
	}
	C.runApp()
}

// Every native string argument is borrowed for the duration of one call.
type nativeStrings []*C.char

func (ss *nativeStrings) add(s string) *C.char {
	p := C.CString(s)
	*ss = append(*ss, p)
	return p
}
func (ss *nativeStrings) free() {
	for _, p := range *ss {
		C.free(unsafe.Pointer(p))
	}
}
func take(p *C.char) (string, bool) {
	if p == nil {
		return "", false
	}
	defer C.free(unsafe.Pointer(p))
	return C.GoString(p), true
}
func notice(title, detail string) {
	var ss nativeStrings
	defer ss.free()
	C.notice(ss.add(title), ss.add(detail))
}
func ask(title, initial string) (string, bool) {
	var ss nativeStrings
	defer ss.free()
	return take(C.askText(ss.add(title), ss.add(initial)))
}
func choose(title, detail string, options []string) int {
	var ss nativeStrings
	defer ss.free()
	values := make([]*C.char, len(options))
	for i, option := range options {
		values[i] = ss.add(option)
	}
	return int(C.choose(ss.add(title), ss.add(detail), &values[0], C.int(len(values))))
}
func item(title string, action func() error) {
	var ss nativeStrings
	defer ss.free()
	id := -1
	if action != nil {
		id = len(actions)
		actions = append(actions, action)
	}
	C.item(ss.add(title), C.int(id))
}

//export performMenuAction
func performMenuAction(id C.int) {
	if err := actions[int(id)](); err != nil {
		notice("Meetcoaster", err.Error())
	}
}

//export buildMenu
func buildMenu() {
	actions = nil
	if startupErr != nil {
		item("Configuration error…", func() error { return startupErr })
	} else {
		plannerItems()
	}
	C.separator()
	C.loginItem()
	item("Quit Meetcoaster", func() error { os.Exit(0); return nil })
}

func plannerItems() {
	item(meeting.Title+" · "+meeting.Duration.String(), nil)
	item(meeting.At.Format("Mon 02 Jan 2006 · 15:04 MST")+" · "+cfg.Source, nil)
	item("Set time…", func() error {
		if clock, ok := ask("Time in "+cfg.Source, meeting.At.Format("15:04")); ok {
			return setWall(meeting.At.Format(time.DateOnly), clock)
		}
		return nil
	})
	item("Set date…", func() error {
		var ss nativeStrings
		defer ss.free()
		if date, ok := take(C.askDate(ss.add(meeting.At.Format(time.DateOnly)))); ok {
			return setWall(date, meeting.At.Format("15:04"))
		}
		return nil
	})
	C.separator()
	now := time.Now()
	for _, p := range cfg.Locations {
		locationMenu(p, now)
	}
	if searching {
		item("Searching for cities…", nil)
	} else {
		item("Add location…", search)
	}
	C.separator()
	submenu("Edit meeting", editItems)

	C.separator()
	item("Export calendar event…", export)
}

func submenu(label string, populate func()) {
	var ss nativeStrings
	defer ss.free()
	C.beginSubmenu(ss.add(label))
	defer C.endSubmenu()
	populate()
}

func editItems() {
	item("Previous day", func() error { return shiftDay(-1) })
	item("Next day", func() error { return shiftDay(1) })
	item("Back 15 minutes", func() error { meeting.At = meeting.At.Add(-15 * time.Minute); return nil })
	item("Forward 15 minutes", func() error { meeting.At = meeting.At.Add(15 * time.Minute); return nil })
	item("Edit title…", func() error {
		if s, ok := ask("Meeting title", meeting.Title); ok {
			return meeting.SetTitle(s)
		}
		return nil
	})
	item("Edit duration…", func() error {
		if s, ok := ask("Duration (e.g. 45m or 1h30m)", meeting.Duration.String()); ok {
			return meeting.SetDuration(s)
		}
		return nil
	})
}

func locationMenu(p places.Location, now time.Time) {
	loc, _ := p.Load()
	at := meeting.At.In(loc)
	label := p.Name + "  ·  " + at.Format("15:04  Mon 02 Jan")
	if p.Name == cfg.Source {
		label += "  ✓"
	}
	changes := planner.Changes(loc, now, meeting.At)
	if len(changes) > 0 {
		label += "  ·  clock change"
	}
	var ss nativeStrings
	defer ss.free()
	C.beginSubmenu(ss.add(label))
	defer C.endSubmenu()
	abbr, offset := at.Zone()
	item(p.Zone+" · "+abbr+" · "+planner.Offset(offset), nil)
	if len(changes) == 0 {
		item("No clock change between now and the meeting", nil)
	} else {
		item(fmt.Sprintf("%d clock change(s) before or since meeting", len(changes)), nil)
		item(changes[0].String(), nil)
	}
	if next := planner.NextChange(loc, meeting.At); next != nil {
		item("Next after meeting · "+next.String(), nil)
	} else {
		item("No clock change in the following year", nil)
	}
	if p.Name != cfg.Source {
		C.separator()
		item("Use as source", func() error { next := cfg; next.Source = p.Name; return save(next) })
		if cfg.IsLocalSource(p.Name) {
			return
		}
		item("Remove location", func() error {
			next := cfg
			if err := next.RemoveLocation(p.Name); err != nil {
				return err
			}
			return save(next)
		})
	}
}
func shiftDay(days int) error { return setWall(meeting.ShiftedDate(days), meeting.At.Format("15:04")) }
func setWall(date, clock string) error {
	loc, _ := meeting.Origin.Load()
	at, err := planner.WallTime(date, clock, loc, "")
	var fold *planner.AmbiguousError
	if errors.As(err, &fold) {
		const format = "15:04 MST (Z07:00)"
		i := choose("This time occurs twice", "Choose the occurrence in "+cfg.Source,
			[]string{fold.Earlier.Format(format), fold.Later.Format(format)})
		if i < 0 {
			return nil
		}
		at = []time.Time{fold.Earlier, fold.Later}[i]
	} else if err != nil {
		return err
	}
	meeting.At = at
	return nil
}
func save(next settings.Config) error {
	if err := meeting.SaveLocations(path, next); err != nil {
		return err
	}
	cfg = next
	return nil
}
func add(p places.Location) error {
	next := cfg
	if err := next.AddLocation(p); err != nil {
		return err
	}
	return save(next)
}

type searchResult struct {
	matches []places.Location
	err     error
}

func search() error {
	query, ok := ask("City, IANA zone or Name=Area/City", "")
	query = strings.TrimSpace(query)
	if !ok || query == "" {
		return nil
	}
	if strings.ContainsAny(query, "/=") {
		p, err := places.Resolve(query, cfg.Locations)
		if err != nil {
			return err
		}
		return add(p)
	}
	searching = true
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		defer cancel()
		matches, err := places.Find(ctx, query, 20)
		results <- searchResult{matches, err}
		C.finishSearchOnMain()
	}()
	return nil
}

//export showResults
func showResults() {
	result := <-results
	searching = false
	detail := places.CityAttribution
	if result.err != nil {
		detail = "Worldwide lookup unavailable. Showing offline matches.\n" + detail
	}
	if len(result.matches) == 0 {
		notice("No matching locations", detail)
		return
	}
	options := make([]string, len(result.matches))
	for i, p := range result.matches {
		options[i] = p.Name + " · " + p.Zone
	}
	if i := choose("Add location", detail, options); i >= 0 {
		if err := add(result.matches[i]); err != nil {
			notice("Add location", err.Error())
		}
	}
}
func export() error {
	var ss nativeStrings
	defer ss.free()
	file, ok := take(C.saveFile(ss.add("meetlet-" + meeting.At.Format("20060102-1504") + ".ics")))
	if !ok {
		return nil
	}
	return calendar.Write(file, meeting, time.Now())
}
