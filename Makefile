SCHEME = FastEdit
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
APP_NAME = FastEdit.app
INSTALL_DIR = /Applications

NEXT_VERSION = $(shell git tag --list 'v[0-9]*' --sort=-version:refname | head -1 | sed 's/^v//' | awk '{print $$1 + 1}')

.PHONY: build test release install uninstall clean tag-release

build:
	xcodebuild -scheme $(SCHEME) -configuration Debug build

test:
	xcodebuild test -scheme $(SCHEME) -destination 'platform=macOS'

release:
	xcodebuild -scheme $(SCHEME) -configuration Release build

install: release
	cp -r $(DERIVED_DATA)/$(SCHEME)-*/Build/Products/Release/$(APP_NAME) $(INSTALL_DIR)/

uninstall:
	rm -rf $(INSTALL_DIR)/$(APP_NAME)

clean:
	xcodebuild -scheme $(SCHEME) clean

tag-release:
	@echo "Creating release v$(NEXT_VERSION)..."
	git tag "v$(NEXT_VERSION)"
	git push origin "v$(NEXT_VERSION)"
