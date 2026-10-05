.PHONY: all build install run setup test clean

all: build

build:
	@./scripts/build-app.sh

install: build
	@echo "Installing WebBlacklist.app to /Applications..."
	@rm -rf /Applications/WebBlacklist.app
	@cp -R WebBlacklist.app /Applications/
	@echo "Registering auto-start on login / restart..."
	@osascript -e 'tell application "System Events" to delete (every login item whose name is "Web Blacklist")' 2>/dev/null || true
	@osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/WebBlacklist.app", hidden:false, name:"Web Blacklist"}' 2>/dev/null || true
	@echo "✅ Installed to /Applications/WebBlacklist.app and configured to auto-start on login/restart"

run: build
	@echo "Launching WebBlacklist.app..."
	@open WebBlacklist.app

setup:
	@echo "Setting up app permissions and auto-start on login / restart..."
	@sudo ./scripts/setup-permissions.sh

test:
	@echo "Running tests..."
	@swiftc -parse-as-library Sources/WebBlacklist/Models/BlockedSite.swift Sources/WebBlacklist/Services/HostsManager.swift Tests/RunTests.swift -o /tmp/run_tests && /tmp/run_tests && rm /tmp/run_tests

clean:
	@rm -rf .build WebBlacklist.app
	@echo "Cleaned build artifacts."
