NAME=RevenueCat.xcframework.zip
REPO=RevenueCat/purchases-ios 
MY_REPO=exception7601/RevenueCat
ROOT_FOLDER=./RevenueCat
FOLDER_FRAMEWORK=./RevenueCat/RevenueCat.xcframework/
VERSION=$(gh release list \
  --repo ${REPO} \
  --exclude-pre-releases \
  --limit 1 \
  --json tagName -q '.[0].tagName'
)

MODULE_PATH=purchases-ios
FILE_VERSION=$(cat version)
PLATAFORMS=("iOS" "iOS Simulator")
JSON_FILE="Carthage/RevenueCatBinary.json"
FRAMEWORK_NAME=RevenueCat
ARCHIVE_NAME=revenuecat
FRAMEWORK_PATH="Products/Library/Frameworks/RevenueCat.framework"
ROOT="$(pwd)/.build/xcframeworks"
ORIGIN=$(pwd)

set -e 

all() {

  if [[ "$VERSION" == "$FILE_VERSION" ]]; then
    echo "❌ Nenhuma release nova. Lançamento atual: $VERSION"
    exit 1
  fi

  download_framework
  make_framework

  IDENTITY=$(echo $(list_identity) | grep 'Apple Distribution' | awk 'NR==1 {print $2}')
  echo "boot ${IDENTITY}"

  BUILD_COMMIT=$(git log --oneline --abbrev=16 --pretty=format:"%h" -1)
  NEW_NAME=revenuecat-${BUILD_COMMIT}.zip

  # resing_framework $IDENTITY $FOLDER_FRAMEWORK
  remove_sing $FOLDER_FRAMEWORK
  zip_framework $NEW_NAME 
  upload_framework $NEW_NAME
}

zip_framework() {
  NAME_ZIP="$1"

  echo "- ZIP framework -"
  cd ${ROOT_FOLDER}
  7z a -tzip ../$NAME_ZIP RevenueCat.xcframework
  # zip -yr ../$NEW_NAME *.xcframework
  # problem for symbolic link
  # zip -r $NEW_NAME *.xcframework
  # rm -rf *.xcframework
  # volda pro diretorio raiz
  cd -
}

make_framework() {
  echo "- Make framework -"
  rm -rf  \
    "$FOLDER_FRAMEWORK/tvos-arm64" \
    "$FOLDER_FRAMEWORK/tvos-arm64_x86_64-simulator" \
    "$FOLDER_FRAMEWORK/watchos-arm64_arm64_32_armv7k" \
    "$FOLDER_FRAMEWORK/watchos-arm64_i386_x86_64-simulator" \
    "$FOLDER_FRAMEWORK/xros-arm64" \
    "$FOLDER_FRAMEWORK/xros-arm64_x86_64-simulator"

  cp Info.plist $FOLDER_FRAMEWORK/Info.plist
}

download_framework() {

  echo "Download ${VERSION}"

  if [ ! -d "${FOLDER_FRAMEWORK}" ]; then 
    gh release download \
      ${VERSION} \
      --repo ${REPO} \
      -p ${NAME} \
      -D . \
      -O ${NAME} --clobber

    unzip -qqo ${NAME}
  fi
}

upload_framework() {
  NAME_ZIP="$1"

  SUM=$(swift package compute-checksum ${NAME_ZIP} )
  DOWNLOAD_URL="https://github.com/${MY_REPO}/releases/download/${VERSION}/${NAME_ZIP}"
  BUILD=$(date +%s) 
  NEW_VERSION=${VERSION}
  echo $NEW_VERSION > version

  if [ ! -f $JSON_FILE ]; then
    echo "{}" > $JSON_FILE
  fi

  # Make Carthage
  JSON_CARTHAGE="$(jq --arg version "${VERSION}" --arg url "${DOWNLOAD_URL}" '. + { ($version): $url }' $JSON_FILE)"
  echo $JSON_CARTHAGE > $JSON_FILE

  git add $JSON_FILE
  git add version
  git commit -m "new Version ${NEW_VERSION}"
  git tag -a ${NEW_VERSION} -m "v${NEW_VERSION}"
  # git checkout -b release-v${VERSION}
  git push origin HEAD --tags
  gh release create ${NEW_VERSION} ${NAME_ZIP} --notes "checksum \`${SUM}\`"

NOTES=$(cat <<END
Carthage
\`\`\`
binary "https://raw.githubusercontent.com/${MY_REPO}/main/${JSON_FILE}"
\`\`\`

Install
\`\`\`
carthage bootstrap --use-xcframeworks
\`\`\`

SPM binaryTarget

\`\`\`
.binaryTarget(
  name: "RevenueCat",
  url: "${DOWNLOAD_URL}",
  checksum: "${SUM}"
)
\`\`\`
END
)

  gh release edit ${NEW_VERSION} --notes  "${NOTES}"
  echo "${NOTES}"
}

resing_framework() {
  echo "- Resing framework ${1} ${2} ${$?}"
  if [ -z "$2" ] || [ -z "$1" ]; then
    echo "Usage: $0 <name-identity> <path-framework>"
    exit 1
  fi
  codesign --force --timestamp -s "$1" "$2"
}

list_identity() {
  security find-identity -p codesigning -v
}

remove_sing() {
  echo "- Remove framework ${1} ${$?}"
  if [ -z "$1" ]; then
    echo "Usage: $0 <name-identity> <path-framework>"
    exit 1
  fi
  find ${1} -name "_CodeSignature" -type d -exec rm -rf {} +
  # codesign --remove-signature "$1"
  # codesign -dv "$1"
}

clean_version() {
  echo "Clean version ${1}"
  if [ -z "$1" ]; then
    echo "Usage: $0 <version>"
    exit 1
  fi

  LAST_VERSION=$1
  # echo "" > version
  JSON_CARTHAGE="$(jq --arg version "${LAST_VERSION}" 'del(.[$version])' $JSON_FILE)"
  echo $JSON_CARTHAGE > $JSON_FILE

  git tag -d $LAST_VERSION
  gh release delete $LAST_VERSION --yes
  git push origin --delete $LAST_VERSION
}

update_sub_module() {
  git submodule update --init --recursive

  cd $MODULE_PATH
  git fetch --tags
  LATEST_TAG=$(git tag --sort=-creatordate | grep -v 'rc\|beta\|alpha' | head -n 1)
  TAG_COMMIT=$(git rev-list -n 1 $LATEST_TAG)

  echo "tag version: ${LATEST_TAG}"
  git checkout -f $TAG_COMMIT

  cd $ORIGIN 
  # git add purchases-ios
  # git commit -m "update submodule $LATEST_TAG"
  # git push origin
}

build_framework() {

  if [[ "$VERSION" == "$FILE_VERSION" ]]; then
    echo "❌ Nenhuma release nova. Lançamento atual: $VERSION"
    exit 1
  fi

  update_sub_module

  rm -rf $ROOT

  cd $MODULE_PATH

  git apply ${ORIGIN}/purchases.patch

  for PLATAFORM in "${PLATAFORMS[@]}"
  do
    xcodebuild archive \
      -project "$FRAMEWORK_NAME.xcodeproj" \
      -scheme "$FRAMEWORK_NAME" \
      -destination "generic/platform=$PLATAFORM"\
      -archivePath "$ROOT/$ARCHIVE_NAME-$PLATAFORM.xcarchive" \
      SKIP_INSTALL=NO \
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

  # Crie o arquivo zip
  rm -f "$NEW_NAME"
  zip -rX "$NEW_NAME" "$FRAMEWORK_NAME.xcframework/"
  mv "$NEW_NAME" "$ORIGIN"
  cd "$ORIGIN"

  upload_framework $NEW_NAME
}

# Check if an option was provided
if [ -z "$1" ]; then
  echo "Usage: $0 {upgrade|clean|submodule|build}"
  exit 1
fi

# Execute the corresponding function based on the provided option
case $1 in
  upgrade)
    build_framework
    ;;
  clean)
    clean_version "$2"
    ;;
  submodule)
    update_sub_module
    ;;
  build)
    build_framework
    ;;
  *)
    echo "Invalid option. Usage: $0 {download|upload}"
    exit 1
    ;;
esac

