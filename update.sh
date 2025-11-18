NAME=RevenueCat.xcframework.zip
REPO=RevenueCat/purchases-ios 
MY_REPO=exception7601/RevenueCat
BUILD_COMMIT=$(git log --oneline --abbrev=16 --pretty=format:"%h" -1)
NEW_NAME=revenuecat-${BUILD_COMMIT}.zip
ROOT_FOLDER=./RevenueCat
FOLDER_FRAMEWORK=./RevenueCat/RevenueCat.xcframework/
VERSION=$(gh release list \
  --repo ${REPO} \
  --exclude-pre-releases \
  --limit 1 \
  --json tagName -q '.[0].tagName'
)

JSON_FILE="Carthage/RevenueCatBinary.json"

set -e  # Saia no primeiro erro

all() {
  download_framework
  make_framework

  # IDENTITY=$(echo $(list_identity) | grep 'Apple Distribution' | awk 'NR==1 {print $2}')
  # echo "boot ${IDENTITY}"
  # resing_framework $IDENTITY $FOLDER_FRAMEWORK

  remove_sing ${ROOT_FOLDER}
  zip_framework
  upload_framework ${NEW_NAME} ${VERSION}
}

zip_framework() {
  echo "- ZIP framework -"
  cd ${ROOT_FOLDER}
  7z a -tzip ../$NEW_NAME RevenueCat.xcframework
  
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
  FRAMEWORK=$1
  NAME_FRAMEWORK=$(basename "$FRAMEWORK")
  SUM=$(swift package compute-checksum ${NEW_NAME} )
  DOWNLOAD_URL="https://github.com/${MY_REPO}/releases/download/${VERSION}/${NAME_FRAMEWORK}"
  BUILD=$(date +%s) 
  NEW_VERSION=$VERSION

  echo $NEW_VERSION > version

  if [ ! -f $JSON_FILE ]; then
    echo "{}" > $JSON_FILE
  fi
  # Make Carthage
  JSON_CARTHAGE="$(jq --arg version "${VERSION}" --arg url "${DOWNLOAD_URL}" '. + { ($version): $url }' $JSON_FILE)" 
  echo $JSON_CARTHAGE > $JSON_FILE
  git add $JSON_FILE version

  git commit -m "new Version ${NEW_VERSION}"
  git tag -s -a ${NEW_VERSION} -m "v${NEW_VERSION}"
  # git checkout -b release-v${VERSION}
  git push origin HEAD --tags
  gh release create ${NEW_VERSION} ${FRAMEWORK} --notes "checksum \`${SUM}\`"

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

merge_build() {
  ./create-xcframeworks.sh
  NEW_NAME=$(realpath .build/xcframeworks/*.zip)
  BUILD=$(date +%s) 
  NEW_VERSION="${VERSION}.${BUILD}"
  upload_framework $NEW_NAME $VERSION
}

# Check if an option was provided
if [ -z "$1" ]; then
  echo "Usage: $0 {upgrade|download|upload|resing|list|merge}"
  exit 1
fi

# Execute the corresponding function based on the provided option
case $1 in
  merge)
    merge_build
    ;;
  upgrade)
    all
    ;;
  download)
    download_framework
    ;;
  upload)
    upload_framework
    ;;
  resing)
    resing_framework "$2" "$3"
    ;;
  list)
    list_identity
    ;;
  *)
    echo "Invalid option. Usage: $0 {download|upload}"
    exit 1
    ;;
esac
