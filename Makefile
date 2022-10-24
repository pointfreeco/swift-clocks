CONFIG = debug
PLATFORM = iOS Simulator,name=iPhone 13 Pro

test:
	xcodebuild test \
		-configuration $(CONFIG) \
		-scheme Clocks \
		-destination platform="$(PLATFORM)"

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
