# US Civics Ready — build and deploy.
#
# Modelled on the FlockCast Makefile in ../biketalk, which solved the same signing
# problems on this machine. Two stages, in increasing order of consequence:
#
#   make build      simulator build                      — seconds, disposable
#   make publish    TestFlight / App Store Connect       — minutes, real
#
# Run `make` for the full list.

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ------------------------------------------------------------------ identity & versions

APP_NAME    := US Civics Ready
BUNDLE_ID   := com.badriram.citizenready
TEAM_ID     := KY478X48U7
ASC_APP_ID  := 6760734958

# Marketing version is edited by hand in VERSION. The build number is the commit count:
# monotonic, reproducible from any checkout, and impossible to forget to bump — App Store
# Connect rejects a repeated build number and hand-maintained counters get repeated.
MARKETING_VERSION := $(shell cat VERSION)
BUILD_NUMBER      := $(shell git rev-list --count HEAD)
VERSION_ARGS      := MARKETING_VERSION=$(MARKETING_VERSION) CURRENT_PROJECT_VERSION=$(BUILD_NUMBER)

# ------------------------------------------------------------------------------- paths

PROJECT     := CitizenshipTest.xcodeproj
SCHEME      := CitizenshipTest
BUILD_DIR   := build
ARCHIVE     := $(BUILD_DIR)/CitizenshipTest.xcarchive
EXPORT_DIR  := $(BUILD_DIR)/export
IPA         := $(EXPORT_DIR)/$(APP_NAME).ipa
SIM         := platform=iOS Simulator,name=iPhone 17

# --------------------------------------------------------------------------- credentials

# App Store Connect ids. The .p8 lives in ~/.appstoreconnect/private_keys and never here.
-include .release.env
export ASC_KEY_ID ASC_ISSUER_ID

ASC_KEY_PATH = $(HOME)/.appstoreconnect/private_keys/AuthKey_$(ASC_KEY_ID).p8

# Off by default. Passing these makes xcodebuild sign *through the API key* instead of using
# the keychain, and because this key's role is App Manager it cannot reach cloud-managed
# distribution certificates — the result is "Cloud signing permission error", which reads
# like a signing problem and is really a permissions one. Signing is manual instead (see
# ExportOptions.plist). Set ASC_CLOUD_SIGNING=1 only if the key is given Admin access.
ifeq ($(ASC_CLOUD_SIGNING),1)
AUTH_ARGS = -authenticationKeyPath $(ASC_KEY_PATH) \
            -authenticationKeyID $(ASC_KEY_ID) \
            -authenticationKeyIssuerID $(ASC_ISSUER_ID)
else
AUTH_ARGS =
endif

# Manual signing for the archive too, so neither step needs an Apple ID in Xcode.
SIGN_ARGS = CODE_SIGN_STYLE=Manual \
            CODE_SIGN_IDENTITY="Apple Distribution" \
            PROVISIONING_PROFILE_SPECIFIER="CitizenReady AppStore" \
            DEVELOPMENT_TEAM=$(TEAM_ID)

# ------------------------------------------------------------------------------ targets

.PHONY: help generate build archive export validate upload publish inspect-ipa profile status clean require-asc

help:
	@echo "US Civics Ready — $(MARKETING_VERSION) ($(BUILD_NUMBER))"
	@echo
	@echo "    make build       simulator build"
	@echo "    make archive     signed device archive + .ipa"
	@echo "    make validate    check the .ipa against App Store Connect"
	@echo "    make publish     validate, then upload to App Store Connect"
	@echo "    make status      builds already on App Store Connect"
	@echo "    make profile     recreate the App Store provisioning profile"

generate:
	@xcodegen generate

build: generate
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination '$(SIM)' build

archive: generate
	@echo "→ archiving $(MARKETING_VERSION) ($(BUILD_NUMBER))"
	@rm -rf $(ARCHIVE) $(EXPORT_DIR)
	@security find-identity -v -p codesigning | grep -q "Apple Distribution" || { \
	  echo "no Apple Distribution certificate in the keychain."; \
	  echo "Apple stores the certificate but never the private key, so a lost one cannot"; \
	  echo "be re-downloaded — it has to be recreated."; exit 1; }
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
	  -destination 'generic/platform=iOS' -archivePath $(ARCHIVE) \
	  $(VERSION_ARGS) $(SIGN_ARGS) archive -allowProvisioningUpdates $(AUTH_ARGS) >/dev/null
	@xcodebuild -exportArchive -archivePath $(ARCHIVE) \
	  -exportOptionsPlist ExportOptions.plist -exportPath $(EXPORT_DIR) \
	  -allowProvisioningUpdates $(AUTH_ARGS) >/dev/null
	@$(MAKE) --no-print-directory inspect-ipa

# An archive exports happily with no app icon and the wrong version, then fails during
# TestFlight processing — so the artefact is inspected rather than trusted.
inspect-ipa:
	@set -e; cd $(EXPORT_DIR) && rm -rf _inspect && mkdir _inspect && cd _inspect && unzip -q "../$(APP_NAME).ipa"; \
	app="Payload/$(APP_NAME).app"; \
	ls "$$app" | grep -q Assets.car || { echo "FAIL: no asset catalogue — the app icon is missing"; exit 1; }; \
	plutil -p "$$app/Info.plist" | grep -q '"CFBundleIconName"' || { echo "FAIL: no CFBundleIconName"; exit 1; }; \
	codesign -d --verbose=2 "$$app" 2>&1 | grep -q "Apple Distribution" || { echo "FAIL: not distribution-signed"; exit 1; }; \
	echo "→ $$(plutil -p "$$app/Info.plist" | grep -E 'CFBundleShortVersionString|CFBundleVersion' | tr -d ' \"' | tr '\n' ' ')"; \
	echo "→ icon present, distribution-signed"

require-asc:
	@test -n "$(ASC_KEY_ID)" -a -n "$(ASC_ISSUER_ID)" || { \
	  echo "set ASC_KEY_ID and ASC_ISSUER_ID (in .release.env or the environment)"; exit 1; }
	@test -f "$(ASC_KEY_PATH)" || { echo "missing key: $(ASC_KEY_PATH)"; exit 1; }

validate: require-asc
	@xcrun altool --validate-app -f "$(IPA)" -t ios \
	  --apiKey $(ASC_KEY_ID) --apiIssuer $(ASC_ISSUER_ID) 2>&1 | grep -E "VERIFY|ERROR" | head -5

# The build number comes from the IPA, not from HEAD: committing between archive and upload
# would otherwise poll for a build that was never uploaded.
upload: require-asc
	@built=$$(plutil -extract ApplicationProperties.CFBundleVersion raw $(ARCHIVE)/Info.plist); \
	if [ "$$built" != "$(BUILD_NUMBER)" ]; then \
	  echo "→ note: archive is build $$built, HEAD is $(BUILD_NUMBER) — uploading what was built"; \
	fi; \
	xcrun altool --upload-app -f "$(IPA)" -t ios \
	  --apiKey $(ASC_KEY_ID) --apiIssuer $(ASC_ISSUER_ID) 2>&1 | grep -E "UPLOAD|ERROR|Delivery UUID" | head -5
	@echo "→ uploaded; processing takes a few minutes. Watch with: make status"

publish: archive validate upload

status: require-asc
	@python3 Tools/asc/asc.py builds $(ASC_APP_ID)

## Recreate the App Store provisioning profile (needed after an App ID capability change —
## a profile is a snapshot and there is no API to edit one).
profile: require-asc
	@python3 Tools/asc/profile.py list

clean:
	@rm -rf $(BUILD_DIR)
