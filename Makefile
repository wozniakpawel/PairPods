# Local equivalents of what CI runs. The signing flags matter: without them a plain
# `xcodebuild test` fails on any machine that lacks the team's Mac Development
# certificate, which is every contributor's machine.

SCHEME := PairPods
CONFIG := Debug
DD := ./DerivedData
XCODEBUILD := xcodebuild
UNSIGNED := CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
DEST := -destination 'platform=macOS'

# SwiftLint and Periphery both load sourcekitd from a full Xcode, not Command Line Tools.
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer

.PHONY: all build test test-asan test-tsan lint format format-check deadcode deadcode-baseline analyze clean

all: format-check lint build test ## Run the same gates as CI

build: ## Build the app
	$(XCODEBUILD) build -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(DD) $(UNSIGNED) ONLY_ACTIVE_ARCH=YES

test: ## Run the test suite
	$(XCODEBUILD) test -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(DD) $(UNSIGNED) ONLY_ACTIVE_ARCH=YES $(DEST) -enableCodeCoverage YES

test-asan: ## Run tests under AddressSanitizer (use-after-free, overflows)
	$(XCODEBUILD) test -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(DD)-asan $(UNSIGNED) ONLY_ACTIVE_ARCH=YES $(DEST) \
		-enableAddressSanitizer YES -enableUndefinedBehaviorSanitizer YES

test-tsan: ## Run tests under ThreadSanitizer (data races). Mutually exclusive with ASan.
	$(XCODEBUILD) test -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(DD)-tsan $(UNSIGNED) ONLY_ACTIVE_ARCH=YES $(DEST) \
		-enableThreadSanitizer YES

lint: ## SwiftLint, failing on any violation
	swiftlint lint --strict

format: ## Rewrite sources with SwiftFormat
	swiftformat .

format-check: ## Fail if SwiftFormat would change anything
	swiftformat --lint .

deadcode: ## Report dead code introduced since the committed baseline
	periphery scan --baseline periphery-baseline.json --strict

deadcode-baseline: ## Re-record the dead code baseline after a deliberate cleanup
	periphery scan --write-baseline periphery-baseline.json

analyze: ## Clang static analyzer
	$(XCODEBUILD) analyze -scheme $(SCHEME) -configuration $(CONFIG) -derivedDataPath $(DD)-analyze $(UNSIGNED) ONLY_ACTIVE_ARCH=YES

clean:
	rm -rf $(DD) $(DD)-asan $(DD)-tsan $(DD)-analyze
