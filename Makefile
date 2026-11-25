APP := build/Meetcoaster.app
.PHONY: build run test
build:
	mkdir -p "$(APP)/Contents/MacOS"
	cp Info.plist "$(APP)/Contents/Info.plist"
	go build -o "$(APP)/Contents/MacOS/meetcoaster" .
	codesign --force --sign - "$(APP)"

run: build
	open "$(APP)"

test:
	go test ./...
	cd meetlet-lib && go test ./...
