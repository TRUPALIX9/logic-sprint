# LogicSprint: Brain Games — development shortcuts
# Usage: make help

.DEFAULT_GOAL := help

SHELL := /bin/bash

PROJECT_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
EMULATOR_ID    ?= Medium_Phone_API_36.0
ADMOB_CONFIG   ?= $(PROJECT_DIR)config/admob.json

.PHONY: help setup doctor devices emulator run run-android analyze test check clean \
        hooks-install icons build-apk build-aab build-ios android-licenses require-admob-config

help: ## Show available commands
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: ## Install Flutter dependencies
	cd "$(PROJECT_DIR)" && flutter pub get

hooks-install: ## Install git pre-push hook (analyze + test before push)
	chmod +x "$(PROJECT_DIR).githooks/pre-push"
	git -C "$(PROJECT_DIR)" config core.hooksPath .githooks
	@echo "Git hooks installed: pre-push runs 'make check' (same as CI)."

doctor: ## Run flutter doctor
	cd "$(PROJECT_DIR)" && flutter doctor -v

devices: ## List connected devices and emulators
	cd "$(PROJECT_DIR)" && flutter devices

emulator: ## Start the default Android emulator
	flutter emulators --launch $(EMULATOR_ID)

run: setup ## Run app on the default device (emulator if running)
	cd "$(PROJECT_DIR)" && flutter run

run-android: setup ## Run app on Android emulator (starts emulator if needed)
	@flutter devices | grep -q emulator || flutter emulators --launch $(EMULATOR_ID)
	@sleep 3
	cd "$(PROJECT_DIR)" && flutter run -d android

analyze: ## Static analysis
	cd "$(PROJECT_DIR)" && flutter analyze

test: ## Unit tests
	cd "$(PROJECT_DIR)" && flutter test

check: analyze test ## Analyze + test (same as CI)

clean: ## Remove build artifacts
	cd "$(PROJECT_DIR)" && flutter clean

icons: setup ## Regenerate launcher icons from brand assets
	cd "$(PROJECT_DIR)" && dart run flutter_launcher_icons

require-admob-config:
	@if [[ ! -f "$(ADMOB_CONFIG)" ]]; then \
		echo "Missing: $(ADMOB_CONFIG)"; \
		echo "Copy config/admob.example.json to config/admob.json and fill in your AdMob IDs."; \
		exit 1; \
	fi

build-apk: setup require-admob-config ## Release APK (local testing)
	cd "$(PROJECT_DIR)" && flutter build apk --release --dart-define-from-file="$(ADMOB_CONFIG)"

build-aab: setup require-admob-config ## Release App Bundle for Google Play
	cd "$(PROJECT_DIR)" && flutter build appbundle --release --dart-define-from-file="$(ADMOB_CONFIG)"

build-ios: setup ## Release IPA for App Store (requires Xcode)
	cd "$(PROJECT_DIR)" && flutter build ipa --release

android-licenses: ## Accept Android SDK licenses (one-time)
	flutter doctor --android-licenses
