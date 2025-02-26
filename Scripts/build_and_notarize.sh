#!/bin/bash
set -e

echo "Cleaning previous builds..."
xcodebuild clean

echo "Building archive..."
xcodebuild archive \
-scheme PairPods \
-configuration Release \
-archivePath ./build/PairPods.xcarchive

echo "Exporting signed app..."
xcodebuild -exportArchive \
-archivePath ./build/PairPods.xcarchive \
-exportOptionsPlist ./Configs/ExportOptions.plist \
-exportPath ./build/export

echo "Creating ZIP file..."
cd ./build/export
ditto -c -k --keepParent PairPods.app PairPods.app.zip

echo "Submitting for notarization..."
xcrun notarytool submit PairPods.app.zip \
--keychain-profile "AC_PASSWORD" \
--wait

echo "Stapling ticket to app..."
xcrun stapler staple PairPods.app

echo "Creating final ZIP with stapled app..."
ditto -c -k --keepParent PairPods.app PairPods.app.zip

echo "Done! Final app is at ./build/export/PairPods.app.zip"