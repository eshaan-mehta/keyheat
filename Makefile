APP       := KeyHeat
BUNDLE_ID := com.eshaan.keyheat
BIN       := .build/release/$(APP)
OUT       := build/$(APP).app

# Command Line Tools 27.0 default to the macOS 27 SDK, where SwiftUI's @State is
# a macro. The CLT do not ship the SwiftUIMacros plugin, so that SDK cannot build
# this app ("plugin for module 'SwiftUIMacros' not found"). Use the 26.5 SDK
# while it is still installed; SDKROOT set in the environment wins.
SDK26     := /Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk
ifneq ($(wildcard $(SDK26)),)
SDKROOT   ?= $(SDK26)
export SDKROOT
endif

.PHONY: all build bundle run install clean

all: bundle

build:
	swift build -c release

bundle: build
	rm -rf $(OUT)
	mkdir -p $(OUT)/Contents/MacOS $(OUT)/Contents/Resources
	cp $(BIN) $(OUT)/Contents/MacOS/$(APP)
	cp Resources/Info.plist $(OUT)/Contents/Info.plist
	# Ad-hoc sign with a fixed identifier and designated requirement so the
	# Input Monitoring grant is keyed to the identifier, not to one build's hash.
	codesign --force --sign - --identifier $(BUNDLE_ID) \
	  --requirements '=designated => identifier "$(BUNDLE_ID)"' $(OUT)
	@echo "Built $(OUT)"

run: bundle
	open $(OUT)

install: bundle
	rm -rf /Applications/$(APP).app
	cp -R $(OUT) /Applications/$(APP).app
	@echo "Installed /Applications/$(APP).app"

clean:
	rm -rf .build build
