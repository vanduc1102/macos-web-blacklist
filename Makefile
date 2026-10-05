.PHONY: all build install run setup test clean

all: build

build:
	@./scripts/build-app.sh

install: build
	@echo "Installing WebBlacklist.app to /Applications..."
	@rm -rf /Applications/WebBlacklist.app
	@cp -R WebBlacklist.app /Applications/
	@echo "✅ Installed to /Applications/WebBlacklist.app"

run: build
	@echo "Launching WebBlacklist.app..."
	@open WebBlacklist.app

setup:
	@echo "Setting up /etc/hosts write permissions for Touch ID..."
	@sudo ./scripts/setup-permissions.sh

test:
	@echo "Running tests..."
	@swiftc -parse-as-library Sources/WebBlacklist/Models/BlockedSite.swift Sources/WebBlacklist/Services/HostsManager.swift Tests/RunTests.swift -o /tmp/run_tests && /tmp/run_tests && rm /tmp/run_tests

clean:
	@rm -rf .build WebBlacklist.app
	@echo "Cleaned build artifacts."
