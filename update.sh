#!/bin/sh

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

upload_framework() {

  if git rev-parse "${VERSION}" >/dev/null 2>&1; then
    echo "Version ${VERSION} already exists. No update needed."
    exit 0
  fi

  fastlane build_and_sign_xcframework

  BUILD=$(date +%s)
  NEW_VERSION="${VERSION}.${BUILD}"

  FRAMEWORK=$(realpath .build/xcframeworks/*.zip)
  NAME_FRAMEWORK=$(basename "$FRAMEWORK")
  DOWNLOAD_URL="https://github.com/${MY_REPO}/releases/download/${VERSION}/${NAME_FRAMEWORK}"

  echo "$NEW_VERSION" >version

  if [ ! -f $JSON_FILE ]; then
    echo "{}" >$JSON_FILE
  fi

  JSON_CARTHAGE="$(jq --arg version "${VERSION}" --arg url "${DOWNLOAD_URL}" '. + { ($version): $url }' $JSON_FILE)"
  echo "$JSON_CARTHAGE" >$JSON_FILE
  git add $JSON_FILE version

  git commit -m "new Version ${NEW_VERSION}"
  git tag -a "${NEW_VERSION}" -m "v${NEW_VERSION}"
  # git push origin HEAD --tags

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

  # gh release create "${NEW_VERSION}" "${FRAMEWORK}" --notes "${NOTES}"
  echo "${NOTES}"
}

# Check if an option was provided
if [ -z "$1" ]; then
  echo "Usage: $0 {upgrade|download|upload|resing|list|merge}"
  exit 1
fi

case $1 in
upload)
  upload_framework
  ;;
*)
  echo "Invalid option. Usage: $0 {download|upload}"
  exit 1
  ;;
esac
