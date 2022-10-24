CONFIG = debug
PLATFORM_IOS = iOS Simulator,name=iPhone 13 Pro
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,name=Apple TV
PLATFORM_WATCHOS = watchOS Simulator,name=Apple Watch Series 7 (45mm)

CONFIG = debug

test-all: test build

test:
	xcodebuild test \
		-configuration $(CONFIG) \
		-scheme Clocks \
		-destination platform="$(PLATFORM_IOS)"

build:
	for platform in "$(PLATFORM_IOS)" "$(PLATFORM_MACOS)" "$(PLATFORM_MAC_CATALYST)" "$(PLATFORM_TVOS)" "$(PLATFORM_WATCHOS)"; do \
		xcodebuild \
			-configuration $(CONFIG) \
			-workspace Clocks.xcworkspace \
			-scheme Clocks \
			-destination platform="$$platform" || exit 1; \
	done;

test-linux:
	docker run \
		--rm \
		-v "$(PWD):$(PWD)" \
		-w "$(PWD)" \
		swift:5.3 \
		bash -c 'make test-swift'

test-swift:
	swift test \
		--enable-test-discovery \
		--parallel

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: format test
