# GitIt — build, install to ~/Applications, and clean.
#
#   make install   build Release and copy GitIt.app into ~/Applications, then open it
#   make build     build Release into ./build
#   make icons     regenerate the PNG icons from scripts/make-icons.swift
#   make clean     remove ./build

PROJECT   := GitIt.xcodeproj
SCHEME    := GitIt
CONFIG    := Release
# Spotlight skips folders named *.noindex, so the built copy never shows up as a second GitIt.
BUILD_DIR := build/xcode.noindex
APP       := $(BUILD_DIR)/Build/Products/$(CONFIG)/GitIt.app
DEST      := $(HOME)/Applications/GitIt.app
LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

.PHONY: build install icons clean open

# -allowProvisioningUpdates lets Xcode create/renew the development certificate and
# profiles for the team in Local.xcconfig (free Personal Team profiles expire after 7 days).
# xcodebuild reports failures on stderr, so both streams go through the filter.
build:
	set -o pipefail; xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) -allowProvisioningUpdates build 2>&1 | scripts/filter-xcodebuild.sh

install: build
	mkdir -p "$(HOME)/Applications"
	@if pgrep -xq GitIt; then echo "Quitting the running GitIt…"; osascript -e 'tell application "GitIt" to quit' || true; sleep 1; fi
	rm -rf "$(DEST)"
	ditto "$(APP)" "$(DEST)"
	@# ditto keeps the bundle's dates, so Finder and the Dock would keep the cached icon.
	touch "$(DEST)"
	@# Forget the copy in ./build so Safari lists only the installed extension.
	$(LSREGISTER) -u "$(APP)" || true
	@echo "Installed $(DEST)"
	open "$(DEST)"

icons:
	swift scripts/make-icons.swift "$(CURDIR)"

clean:
	rm -rf build
