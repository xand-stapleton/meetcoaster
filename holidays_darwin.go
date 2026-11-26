package main

/*
#include "native.h"
*/
import "C"

import (
	"strings"
	"time"

	"github.com/xand-stapleton/meetlet-lib/holidays"
	"github.com/xand-stapleton/meetlet-lib/places"
)

type holidayKey struct {
	place             places.Location
	today, meetingDay string
}

type holidayResult struct {
	key     holidayKey
	summary holidays.Summary
}

type holidayRequest struct {
	key       holidayKey
	requested time.Time
	summary   *holidays.Summary
}

var holidayRequests = make(map[string]holidayRequest)
var holidayResults = make(chan holidayResult, 32)

func requestHolidays(now time.Time) {
	for _, p := range cfg.Locations {
		loc, err := p.Load()
		if err != nil {
			continue
		}
		at := meeting.At
		key := holidayKey{p, now.In(loc).Format(time.DateOnly), at.In(loc).Format(time.DateOnly)}
		request := holidayRequests[p.Name]
		retry := time.Minute
		if request.summary != nil && request.summary.Available {
			retry = 24 * time.Hour
		}
		if request.key == key && now.Sub(request.requested) < retry {
			continue
		}
		holidayRequests[p.Name] = holidayRequest{key: key, requested: now}
		go func() {
			holidayResults <- holidayResult{key, holidays.Lookup(p, now, at)}
			C.finishHolidayLookup()
		}()
	}
}

func holidayLabels(name string) (string, string) {
	request := holidayRequests[name]
	if request.summary == nil {
		return "Looking up public holidays…", ""
	}
	var names []string
	for _, h := range request.summary.OnMeetingDay {
		names = append(names, h.Name)
	}
	warning := ""
	if len(names) > 0 {
		warning = "Public holiday · " + name + " · " + strings.Join(names, ", ")
	}
	return request.summary.NextLabel(), warning
}

//export updateHolidayLabels
func updateHolidayLabels() {
	result := <-holidayResults
	name := result.key.place.Name
	request := holidayRequests[name]
	if request.key != result.key {
		return
	}
	request.summary = &result.summary
	holidayRequests[name] = request
	next, warning := holidayLabels(name)
	var ss nativeStrings
	defer ss.free()
	C.updateHolidayItems(ss.add(name), ss.add(next), ss.add(warning))
}
