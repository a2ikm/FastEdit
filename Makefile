SCHEME = FastEdit
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData
APP_NAME = FastEdit.app
INSTALL_DIR = /Applications

.PHONY: build test release install uninstall clean

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
