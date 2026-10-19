FLUTTER ?= flutter
DART ?= dart
WEB_PORT ?= 8080

.PHONY: get test analyze format-check build run

get:
	$(FLUTTER) pub get

# Dependencies must already be present (run `make get` once when online).
test:
	$(FLUTTER) test --no-pub

analyze:
	$(FLUTTER) analyze --no-fatal-infos

format-check:
	$(DART) format --set-exit-if-changed .

build:
	$(FLUTTER) build web --release

run:
	$(FLUTTER) run -d web-server --web-port $(WEB_PORT)
