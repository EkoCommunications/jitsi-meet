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
# 4
# Build the framework for device and for simulator (using
# all needed architectures).

xcodebuild -workspace ios/jitsi-meet.xcworkspace -scheme JitsiMeet -configuration Release -arch arm64 only_active_arch=no defines_module=yes -sdk "iphoneos" -derivedDataPath "${OUTPUT_DIR}" ENABLE_BITCODE=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode
xcodebuild -workspace ios/jitsi-meet.xcworkspace -scheme JitsiMeet -configuration Release -arch x86_64 only_active_arch=no defines_module=yes -sdk "iphonesimulator" -derivedDataPath "${OUTPUT_DIR}" ENABLE_BITCODE=YES OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE=bitcode

# 5
# Remove .framework file if exists from previous run.
if [ -d "${OUTPUT_DIR}/JitsiMeet.framework" ]; then
rm -rf "${OUTPUT_DIR}/JitsiMeet.framework"
fi
# 6
# Copy the device version of framework.
cp -r "${OUTPUT_DIR}/Build/Products/Release-iphoneos/JitsiMeet.framework" "${OUTPUT_DIR}/JitsiMeet.framework"
# 7
# Replace the framework executable within the framework with
# a new version created by merging the device and simulator
# frameworks' executables with lipo.
lipo -create -output "${OUTPUT_DIR}/JitsiMeet.framework/JitsiMeet" "${OUTPUT_DIR}/Build/Products/Release-iphoneos/JitsiMeet.framework/JitsiMeet" "${OUTPUT_DIR}/Build/Products/Release-iphonesimulator/JitsiMeet.framework/JitsiMeet"
# 8
# Copy the Swift module mappings for the simulator into the
# framework. The device mappings already exist from step 6.
cp -r "${OUTPUT_DIR}/Build/Products/Release-iphonesimulator/JitsiMeet.framework/Modules/JitsiMeet.swiftmodule/" "${OUTPUT_DIR}/JitsiMeet.framework/Modules/JitsiMeet.swiftmodule"
# 9
# Embedded strip-framework.sh into the framework
echo "${THIS_DIR}"
cp -r "${THIS_DIR}/strip-framework.sh" "${OUTPUT_DIR}/JitsiMeet.framework"
