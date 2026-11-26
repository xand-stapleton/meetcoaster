APP := build/Meetcoaster.app
APPLICATIONS_DIR ?= $(HOME)/Applications
.PHONY: build run test install
build:
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp img/menu-bar.png "$(APP)/Contents/Resources/"
	cp Info.plist "$(APP)/Contents/Info.plist"
	go build -o "$(APP)/Contents/MacOS/meetcoaster" .
	codesign --force --sign - "$(APP)"

run: build
	open "$(APP)"

test:
	go test ./...
	cd meetlet-lib && go test ./...

install: build
	mkdir -p "$(DESTDIR)$(APPLICATIONS_DIR)"
	ditto "$(APP)" "$(DESTDIR)$(APPLICATIONS_DIR)/Meetcoaster.app"
	codesign --verify --strict "$(DESTDIR)$(APPLICATIONS_DIR)/Meetcoaster.app"
