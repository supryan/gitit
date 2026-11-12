# The GitIt Mac app — build, install to ~/Applications, and clean. The app embeds the
# Safari extension (../safari, ../shared) and carries the Chrome one (../chrome).
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

.PHONY: build install icons clean open release publish

# Releases for download: signed with a Developer ID by the paid team and notarized, so
# GitIt opens on anyone's Mac without warnings and Safari runs its extension as is.
RELEASE_TEAM := T9MFQS37T8
RELEASE_DIR  := build/release.noindex
ARCHIVE      := $(RELEASE_DIR)/GitIt.xcarchive
RELEASE_ZIP  := $(RELEASE_DIR)/GitIt.zip
# Where `make publish` puts the zip: the portfolio site, which serves public/ from its root.
SITE         := ../../supryan-v2

# -allowProvisioningUpdates lets Xcode create/renew the development certificate and
# profiles for the team in Local.xcconfig (free Personal Team profiles expire after 7 days).
# xcodebuild reports failures on stderr, so both streams go through the filter.
build:
	@# The app carries the built Chrome extension; assemble it before Xcode copies it in.
	../chrome/build.sh
	set -o pipefail; xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) -allowProvisioningUpdates build 2>&1 | scripts/filter-xcodebuild.sh
	@# Xcode registers what it builds with macOS; forget it at once, so a build alone never
	@# adds a second GitIt to Safari or Spotlight.
	@$(LSREGISTER) -u "$(APP)" 2>/dev/null || true

install: build
	mkdir -p "$(HOME)/Applications"
	@if pgrep -xq GitIt; then echo "Quitting the running GitIt…"; osascript -e 'tell application "GitIt" to quit' || true; sleep 1; fi
	rm -rf "$(DEST)"
	ditto "$(APP)" "$(DEST)"
	@# ditto keeps the bundle's dates, so Finder and the Dock would keep the cached icon.
	touch "$(DEST)"
	@# Exactly one GitIt registered with macOS, and so in Safari: the installed copy.
	scripts/keep-one-gitit.sh "$(DEST)"
	@echo "Installed $(DEST)"
	open "$(DEST)"

icons:
	swift scripts/make-icons.swift "$(CURDIR)"

# Archive with the paid team, export as Developer ID (Xcode signs and uploads to Apple's
# notary service with the account it is signed into), wait for the approval, then zip the
# stapled app.
release:
	../chrome/build.sh
	rm -rf "$(RELEASE_DIR)"
	set -o pipefail; xcodebuild archive -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIG) \
		-archivePath "$(ARCHIVE)" -derivedDataPath $(BUILD_DIR) DEVELOPMENT_TEAM=$(RELEASE_TEAM) \
		-allowProvisioningUpdates 2>&1 | scripts/filter-xcodebuild.sh
	set -o pipefail; xcodebuild -exportArchive -archivePath "$(ARCHIVE)" \
		-exportOptionsPlist Config/ExportOptions.plist -exportPath "$(RELEASE_DIR)/upload" \
		-allowProvisioningUpdates 2>&1 | scripts/filter-xcodebuild.sh
	scripts/fetch-notarized.sh "$(ARCHIVE)" "$(RELEASE_DIR)/notarized"
	xcrun stapler validate "$(RELEASE_DIR)/notarized/GitIt.app"
	ditto -c -k --keepParent "$(RELEASE_DIR)/notarized/GitIt.app" "$(RELEASE_ZIP)"
	@$(LSREGISTER) -u "$(RELEASE_DIR)/notarized/GitIt.app" 2>/dev/null || true
	@echo "Release: $(RELEASE_ZIP)"

# Copies the release into the site; commit and deploy the site to put it online.
publish:
	@test -f "$(RELEASE_ZIP)" || { echo "No release yet; run make release first." >&2; exit 1; }
	mkdir -p "$(SITE)/public/downloads"
	cp "$(RELEASE_ZIP)" "$(SITE)/public/downloads/GitIt.zip"
	@echo "Copied to $(SITE)/public/downloads/GitIt.zip"

clean:
	rm -rf build
