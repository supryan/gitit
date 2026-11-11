# GitIt — each browser lives in its own folder. Targets here forward to safari/ for now.
#
#   make install   build the Safari version and install GitIt.app to ~/Applications
#   make build | icons | clean

.PHONY: build install icons clean

build install icons clean:
	$(MAKE) -C safari $@
