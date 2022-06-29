CONFIG = debug
PLATFORM = iOS Simulator,name=iPhone 13 Pro

test:
	xcodebuild test \
		-configuration $(CONFIG) \
		-scheme swift-clocks \
		-destination platform="$(PLATFORM)"

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift ./Sources ./Tests

.PHONY: format test
