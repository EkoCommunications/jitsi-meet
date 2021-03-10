#!/bin/bash

# 1
# Set bash script to exit immediately if any commands fail.
set -e -u

THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)
PROJECT_REPO=$(realpath "${THIS_DIR}"/../..)

# 2
# Setup some constants for use later on.
OUTPUT_DIR="${PROJECT_REPO}/ios/build"
# 3
# If remnants from a previous build exist, delete them.
if [ -d "${OUTPUT_DIR}" ]; then
rm -rf "${OUTPUT_DIR}"
fi

mkdir "${OUTPUT_DIR}"

# 4
# Build the all archives architectures for device and for simulator
xcodebuild archive -workspace ios/jitsi-meet.xcworkspace -scheme JitsiMeet -configuration Release -arch arm64 only_active_arch=no defines_module=yes -sdk "iphoneos" -archivePath "${OUTPUT_DIR}/JitsiMeet-iphoneos.xcarchive" ENABLE_BITCODE=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode SKIP_INSTALL=NO
xcodebuild archive -workspace ios/jitsi-meet.xcworkspace -scheme JitsiMeet -configuration Release -arch x86_64 only_active_arch=no defines_module=yes -sdk "iphonesimulator" -archivePath "${OUTPUT_DIR}/JitsiMeet-iphonesimulator.xcarchive" ENABLE_BITCODE=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode SKIP_INSTALL=NO

# 5
# Build xcframework
xcodebuild -create-xcframework -framework "${OUTPUT_DIR}/JitsiMeet-iphoneos.xcarchive/Products/Library/Frameworks/JitsiMeet.framework" -framework "${OUTPUT_DIR}/JitsiMeet-iphonesimulator.xcarchive/Products/Library/Frameworks/JitsiMeet.framework" -output "${OUTPUT_DIR}/JitsiMeet.xcframework"

# 6
# Fix swiftinterface https://bugs.swift.org/browse/SR-14195
# Replace all JitsiMeet. with empty string
sed -i '' 's/JitsiMeet.//g' "${OUTPUT_DIR}/JItsiMeet.xcframework/ios-arm64/JitsiMeet.framework/Modules/JitsiMeet.swiftmodule/arm64.swiftinterface"
sed -i '' 's/JitsiMeet.//g' "${OUTPUT_DIR}/JItsiMeet.xcframework/ios-arm64/JitsiMeet.framework/Modules/JitsiMeet.swiftmodule/arm64-apple-ios.swiftinterface"
sed -i '' 's/JitsiMeet.//g' "${OUTPUT_DIR}/JItsiMeet.xcframework/ios-x86_64-simulator/JitsiMeet.framework/Modules/JitsiMeet.swiftmodule/x86_64.swiftinterface"
sed -i '' 's/JitsiMeet.//g' "${OUTPUT_DIR}/JItsiMeet.xcframework/ios-x86_64-simulator/JitsiMeet.framework/Modules/JitsiMeet.swiftmodule/x86_64-apple-ios-simulator.swiftinterface"

# 11
# Download WebRTC.framework
bash "${PROJECT_REPO}/node_modules/react-native-webrtc/tools/downloadBitcode.sh"

# 12
# Create WebRTC.xcframework
mkdir "${OUTPUT_DIR}/WebRTC-iphoneos"
mkdir "${OUTPUT_DIR}/WebRTC-iphonesimulator"
cp -r "${PROJECT_REPO}/node_modules/react-native-webrtc/ios/WebRTC.framework" "${OUTPUT_DIR}/WebRTC-iphoneos/WebRTC.framework"
cp -r "${PROJECT_REPO}/node_modules/react-native-webrtc/ios/WebRTC.framework" "${OUTPUT_DIR}/WebRTC-iphonesimulator/WebRTC.framework"

xcrun lipo -remove i386 -remove x86_64 -remove armv7 "${OUTPUT_DIR}/WebRTC-iphoneos/WebRTC.framework/WebRTC" -o "${OUTPUT_DIR}/WebRTC-iphoneos/WebRTC.framework/WebRTC"
xcrun lipo -remove i386 -remove arm64 -remove armv7 "${OUTPUT_DIR}/WebRTC-iphonesimulator/WebRTC.framework/WebRTC" -o "${OUTPUT_DIR}/WebRTC-iphonesimulator/WebRTC.framework/WebRTC"

xcodebuild -create-xcframework -framework "${OUTPUT_DIR}/WebRTC-iphoneos/WebRTC.framework/" -framework "${OUTPUT_DIR}/WebRTC-iphonesimulator/WebRTC.framework" -output "${OUTPUT_DIR}/WebRTC.xcframework"
