# HWANGTODO — developer entry points.
# Requires: Xcode 26+, xcodegen (brew install xcodegen).
# Optional: swiftlint, swiftformat (brew install swiftlint swiftformat).

SCHEME      := HWANGTODO
PROJECT     := HWANGTODO.xcodeproj
SIMULATOR   ?= iPhone 17 Pro
DESTINATION := platform=iOS Simulator,name=$(SIMULATOR)
BUNDLE_ID   := com.hwangtodo.app

.PHONY: gen build test run lint format icon clean help

help: ## List available targets
	@grep -E '^[a-z]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  make %-8s %s\n", $$1, $$2}'

gen: ## Regenerate the Xcode project from project.yml (source of truth)
	xcodegen generate

build: gen ## Build the app for the simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' build

test: gen ## Run unit tests (Swift Testing) on the simulator
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' test

run: build ## Build, install, and launch on the booted simulator
	xcrun simctl boot "$(SIMULATOR)" 2>/dev/null || true
	xcrun simctl install booted \
		"$$(xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(DESTINATION)' -showBuildSettings 2>/dev/null | awk '/ BUILT_PRODUCTS_DIR/ {print $$3; exit}')/HWANGTODO.app"
	xcrun simctl launch booted $(BUNDLE_ID)

lint: ## SwiftLint (warnings allowed locally; CI uses --strict)
	swiftlint lint --quiet

format: ## Apply SwiftFormat in place
	swiftformat .

icon: ## Re-render the app icon PNG from Scripts/render_appicon.swift
	swift Scripts/render_appicon.swift Sources/App/Assets.xcassets/AppIcon.appiconset/appicon-1024.png

clean: ## Remove local build artifacts
	rm -rf DerivedData .build
