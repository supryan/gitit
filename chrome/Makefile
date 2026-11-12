# GitIt for Chrome.
#
#   make install   build the extension into "build/GitIt for Chrome" and register GitIt's native host
#   make build     build the extension only
#   make clean     remove build/
#
# The GitIt app must be installed first (make install from the repo root).

.PHONY: build install clean

build:
	./build.sh

install: build
	./install-host.sh "$(HOME)/Applications/GitIt.app"

clean:
	rm -rf build
