NAME=RevenueCat.xcframework.zip
REPO=RevenueCat/purchases-ios 
NEW_NAME=revenuecat-xcframeworks.zip
FOLDER_FRAMEWORK=./xcframeworks/RevenueCat.xcframework/
VERSION=$(gh release list \
  --repo ${REPO} \
  --exclude-pre-releases \
  --limit 1 \
  --json tagName -q '.[0].tagName'
)

all() {
  download_framework
  make_framework

  IDENTITY=$(echo $(list_identity) | grep 'Apple Distribution' | awk 'NR==1 {print $2}')
  echo "boot ${IDENTITY}"

  resing_framework $IDENTITY $FOLDER_FRAMEWORK
  zip_framework
  upload_framework
}

zip_framework() {
  echo "- ZIP framework -"
  cd ./xcframeworks/
  7z a -tzip ../$NEW_NAME RevenueCat.xcframework
  
  # problem for symbolic link
  # zip -r $NEW_NAME *.xcframework
  # rm -rf *.xcframework
  # volda pro diretorio raiz
  cd -
}

make_framework() {
  echo "- make framework -"
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

  echo ${VERSION}

  gh release download \
    ${VERSION} \
    --repo ${REPO} \
    -p ${NAME} \
    -D . \
    -O ${NAME} --clobber

  unzip -o ${NAME}

}

upload_framework() {
  SUM=$(swift package compute-checksum ${NEW_NAME} )

  echo ${VERSION} > version

  git add version
  git commit -m "new Version ${VERSION}"
  # git tag -s -a ${VERSION} -m "v${VERSION}"
  git checkout -b release-v${VERSION}
  git push origin HEAD --tags
  gh release create ${VERSION} ${NEW_NAME} --notes "checksum \`${SUM}\`"

  URL=$(gh release view ${VERSION} \
    --repo exception7601/RevenueCat \
    --json assets \
    -q '.assets[0].apiUrl'
  )

NOTES=$(cat <<END
SPM binaryTarget

\`\`\`
.binaryTarget(
  name: "RevenueCat",
  url: "${URL}.zip",
  checksum: "${SUM}"
)
\`\`\`
END
)

  gh release edit ${VERSION} --notes  "${NOTES}"
  echo "${NOTES}"
}

resing_framework() {
  if [ -z "$2" ] || [ -z "$1" ]; then
    echo "Usage: $0 <name-identity> <path-framework>"
    exit 1
  fi
  codesign --force --timestamp -s "$1" "$2"
}

list_identity() {
  security find-identity -p codesigning -v
}

# Check if an option was provided
if [ -z "$1" ]; then
  echo "Usage: $0 {upgrade|download|upload|resing|list}"
  exit 1
fi

# Execute the corresponding function based on the provided option
case $1 in
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

