#!/bin/bash

set -e

REPO=RevenueCat/purchases-ios
MY_REPO=exception7601/RevenueCat
VERSION=$(
  gh release list \
    --repo ${REPO} \
    --exclude-pre-releases \
    --limit 1 \
    --json tagName -q '.[0].tagName'
)

JSON_FILE="Carthage/RevenueCatBinary.json"

ORIGIN=$(pwd)
ROOT="$(pwd)/.build/xcframeworks"
MODULE_PATH="purchases-ios"
FRAMEWORK_NAME=RevenueCat
ARCHIVE_NAME=revenuecat
FRAMEWORK_PATH="Products/Library/Frameworks/RevenueCat.framework"
PLATAFORMS=("iOS" "iOS Simulator")
PATCH="$ORIGIN/revenuecat-api.patch"

create_xcframeworks() {
  git submodule update --init --recursive

  git -C "$MODULE_PATH" fetch --tags

  LATEST_TAG=$(git -C "$MODULE_PATH" tag --sort=-creatordate | grep -v 'rc\|beta\|alpha' | head -n 1)
  TAG_COMMIT=$(git -C "$MODULE_PATH" rev-list -n 1 "$LATEST_TAG")

  echo "tag version: ${LATEST_TAG}"
  git -C "$MODULE_PATH" checkout -f "$TAG_COMMIT"
  git -C "$MODULE_PATH" apply "$PATCH"

  rm -rf "$ROOT"

  for PLATAFORM in "${PLATAFORMS[@]}"
  do
    echo "Building for $PLATAFORM..."
    xcodebuild archive \
      -project "$MODULE_PATH/$FRAMEWORK_NAME.xcodeproj" \
      -scheme "$FRAMEWORK_NAME" \
      -destination "generic/platform=$PLATAFORM" \
      -archivePath "$ROOT/$ARCHIVE_NAME-$PLATAFORM.xcarchive" \
      MERGEABLE_LIBRARY=YES \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      DEBUG_INFORMATION_FORMAT=DWARF \
      MACH_O_TYPE=staticlib \
      ONLY_ACTIVE_ARCH=NO
  done

  xcodebuild -create-xcframework \
    -framework "$ROOT/$ARCHIVE_NAME-iOS.xcarchive/$FRAMEWORK_PATH" \
    -framework "$ROOT/$ARCHIVE_NAME-iOS Simulator.xcarchive/$FRAMEWORK_PATH" \
    -output "$ROOT/$FRAMEWORK_NAME.xcframework"

  BUILD_COMMIT=$(git -C $MODULE_PATH log --oneline --abbrev=16 --pretty=format:"%h" -1)
  NEW_NAME=revenuecat-${BUILD_COMMIT}.zip

  cd "$ROOT"

  zip -rX "$NEW_NAME" "$FRAMEWORK_NAME.xcframework/"
  cd "$ORIGIN"
}

upgrade_framework() {

  if git rev-parse "${VERSION}" >/dev/null 2>&1; then
    echo "Version ${VERSION} already exists. No update needed."
    exit 0
  fi

  create_xcframeworks

  echo "start upload version"
  BUILD=$(date +%s)
  NEW_VERSION="${VERSION}"

  FRAMEWORK=$(realpath .build/xcframeworks/*.zip)
  NAME_FRAMEWORK=$(basename "$FRAMEWORK")
  DOWNLOAD_URL="https://github.com/${MY_REPO}/releases/download/${VERSION}/${NAME_FRAMEWORK}"

  echo "$NEW_VERSION.$BUILD" >version

  if [ ! -f $JSON_FILE ]; then
    echo "{}" >$JSON_FILE
  fi

  JSON_CARTHAGE="$(jq --arg version "${VERSION}" --arg url "${DOWNLOAD_URL}" '. + { ($version): $url }' $JSON_FILE)"
  echo "$JSON_CARTHAGE" >$JSON_FILE

  if ! git diff --quiet purchases-ios; then
    git add purchases-ios
  fi
  
  git add $JSON_FILE version

  git commit -m "new Version ${NEW_VERSION}"
  git tag -a "${NEW_VERSION}" -m "v${NEW_VERSION}"
  git push origin HEAD --tags

  NOTES=$(
    cat <<END
Carthage
\`\`\`
binary "https://raw.githubusercontent.com/${MY_REPO}/main/${JSON_FILE}"
\`\`\`

Install
\`\`\`
carthage bootstrap --use-xcframeworks
\`\`\`
END
  )

  gh release create "${NEW_VERSION}" "${FRAMEWORK}" --notes "${NOTES}"
  echo "${NOTES}"
}

build_framework() {
  create_xcframeworks
  echo "Build completed. XCFramework available at: $ROOT/$FRAMEWORK_NAME.xcframework"
}

# Check if an option was provided
if [ -z "$1" ]; then
  echo "Usage: $0 {upgrade|build}"
  exit 1
fi

case $1 in
upgrade)
  upgrade_framework
  ;;
build)
  build_framework
  ;;
*)
  echo "Invalid option. Usage: $0 {upgrade|build}"
  exit 1
  ;;
esac
