FLUTTER ?= flutter
DART ?= dart
WEB_PORT ?= 8080

.PHONY: get test analyze format-check build run rules-test

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

# Requires Node dependencies in rules-tests and the Firebase CLI. This starts
# isolated Auth/Firestore emulators and verifies the deployed rule contract.
rules-test:
	cd rules-tests && npm ci
	firebase emulators:exec --project dailymettle-rules-test --only auth,firestore "cd rules-tests && npm test"
