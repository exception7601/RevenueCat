ORIGIN=$(pwd)
ROOT="$(pwd)/.build/xcframeworks"
MODULE_PATH="purchases-ios"
FRAMEWORK_NAME=RevenueCat
ARCHIVE_NAME=revenuecat
FRAMEWORK_PATH="Products/Library/Frameworks/RevenueCat.framework"
PLATAFORMS=("iOS" "iOS Simulator")

main() {
  git submodule update --init --recursive
  cd $MODULE_PATH
  git fetch --tags

  LATEST_TAG=$(git tag --sort=-creatordate | grep -v 'rc\|beta\|alpha' | head -n 1)
  TAG_COMMIT=$(git rev-list -n 1 $LATEST_TAG)

  echo "tag version: ${LATEST_TAG}"
  git checkout -f $TAG_COMMIT

  set -e

  cd $ORIGIN 
  # git add purchases-ios
  # git commit -m "update submodule $LATEST_TAG"
  # git push origin

  rm -rf $ROOT

  cd $MODULE_PATH

  for PLATAFORM in "${PLATAFORMS[@]}"
  do
    xcodebuild archive \
      -project "$FRAMEWORK_NAME.xcodeproj" \
      -scheme "$FRAMEWORK_NAME" \
      -destination "generic/platform=$PLATAFORM"\
      -archivePath "$ROOT/$ARCHIVE_NAME-$PLATAFORM.xcarchive" \
      MERGEABLE_LIBRARY=YES \
      SKIP_INSTALL=NO \
      CODE_SIGN_IDENTITY="Apple Development" \
      DEVELOPMENT_TEAM=PN8K78V28P \
      CODE_SIGN_STYLE=Automatic \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      DEBUG_INFORMATION_FORMAT=DWARF
  done

  xcodebuild -create-xcframework \
    -framework "$ROOT/$ARCHIVE_NAME-iOS.xcarchive/$FRAMEWORK_PATH" \
    -framework "$ROOT/$ARCHIVE_NAME-iOS Simulator.xcarchive/$FRAMEWORK_PATH" \
    -output "$ROOT/$FRAMEWORK_NAME.xcframework"

  BUILD_COMMIT=$(git log --oneline --abbrev=16 --pretty=format:"%h" -1)
  NEW_NAME=revenuecat-${BUILD_COMMIT}.zip

  cd "$ROOT"

  # rm -f "$NEW_NAME"
  zip -rX "$NEW_NAME" "$FRAMEWORK_NAME.xcframework/"
  # mv "$NEW_NAME" "$ORIGIN"
  cd "$ORIGIN"
}

main
