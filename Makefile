PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin

SWIFT_FLAGS = -O

.PHONY: build install uninstall clean

build: cookie-reader

cookie-reader: cookie-reader.swift
	swiftc $(SWIFT_FLAGS) -o cookie-reader cookie-reader.swift -lsqlite3
	codesign -s - -i com.naufalafif.mmsso.cookie-reader cookie-reader

install: build
	install -d $(BINDIR)
	install -m 755 cookie-reader $(BINDIR)/cookie-reader
	install -m 755 mmsso $(BINDIR)/mmsso

uninstall:
	rm -f $(BINDIR)/mmsso $(BINDIR)/cookie-reader

clean:
	rm -f cookie-reader
