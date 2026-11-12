# GitIt
#
#   app/      the Mac app (Xcode project); it builds the Safari extension and carries the Chrome one
#   safari/   the Safari extension's own files
#   chrome/   the Chrome extension's own files
#   shared/   the popup, dashboard, theme and icons both extensions use
#
#   make install   build the app and install it to ~/Applications
#   make chrome    build the Chrome extension into chrome/build and register GitIt with Chrome
#   make build | icons | clean

.PHONY: build install icons clean chrome

build install icons clean:
	$(MAKE) -C app $@

chrome:
	$(MAKE) -C chrome install
