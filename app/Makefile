APP = build/PR-21 Manager.app

build:
	./build.sh

run: build
	open "$(APP)"

install: build
	rm -rf "/Applications/PR-21 Manager.app"
	cp -R "$(APP)" /Applications/
	xattr -cr "/Applications/PR-21 Manager.app" 2>/dev/null || true
	codesign --force --deep --sign - "/Applications/PR-21 Manager.app" 2>/dev/null || true
	@echo "установлено в /Applications"

clean:
	rm -rf build

.PHONY: build run install clean
