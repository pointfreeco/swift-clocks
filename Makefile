CONFIG = debug
PLATFORM_IOS = iOS Simulator,id=$(call udid_for,iPhone)
PLATFORM_MACOS = macOS
PLATFORM_MAC_CATALYST = macOS,variant=Mac Catalyst
PLATFORM_TVOS = tvOS Simulator,id=$(call udid_for,TV)
PLATFORM_WATCHOS = watchOS Simulator,id=$(call udid_for,Watch)

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
		swift:5.8 \
		bash -c 'make test-swift'

test-swift:
	swift test \
		--enable-test-discovery \
		--parallel

build-for-library-evolution:
	swift build \
		-c release \
		--target Clocks \
		-Xswiftc -emit-module-interface \
		-Xswiftc -enable-library-evolution

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: format test

define udid_for
$(shell xcrun simctl list --json devices available $(1) | jq -r '.devices | to_entries | map(select(.value | add)) | sort_by(.key) | last.value | last.udid')
endef
