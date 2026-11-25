SWIFTC ?= swiftc
BINS = adapter/sb3bridge tools/midimon tools/midisend tools/ledscan tools/tonetest

.PHONY: all mappings install clean

all: $(BINS)

%: %.swift
	$(SWIFTC) -O $< -o $@

mappings:
	python3 gen_mapping.py

install: adapter/sb3bridge
	cp adapter/sb3bridge /Applications/.sb3bridge.new
	mv -f /Applications/.sb3bridge.new /Applications/sb3bridge

clean:
	rm -f $(BINS)
