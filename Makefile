# GitIt
#
#   app/      the Mac app (Xcode project); it builds the Safari extension and carries the Chrome one
#   safari/   the Safari extension's own files
#   chrome/   the Chrome extension's own files
#   shared/   the popup, dashboard, theme and icons both extensions use
#
#   make install   build the app and install it to ~/Applications
#   make chrome    build the Chrome extension into chrome/build and register GitIt with Chrome
#   make release   build a signed, notarized GitIt.zip for download (app/build/release.noindex)
#   make github-release   publish that zip as a GitHub release, tagged with the app's version
#   make publish   copy that zip into the portfolio site's public/downloads
#   make build | icons | clean

.PHONY: build install icons clean chrome release publish github-release

build install icons clean release publish github-release:
	$(MAKE) -C app $@

chrome:
	$(MAKE) -C chrome install
