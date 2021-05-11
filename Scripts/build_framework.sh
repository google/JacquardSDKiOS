#!/bin/bash
#
# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

VERSION=0.1.0

CONFIGURATION=Release
FRAMEWORK_NAME="JacquardSDK"
BUILD_DIR="generated-framework/build"
OUTPUT_DIR="generated-framework"

SIMULATOR_LIBRARY_PATH="${BUILD_DIR}/Products/${CONFIGURATION}-iphonesimulator/${FRAMEWORK_NAME}/${FRAMEWORK_NAME}.framework"
DEVICE_LIBRARY_PATH="${BUILD_DIR}/Products/${CONFIGURATION}-iphoneos/${FRAMEWORK_NAME}/${FRAMEWORK_NAME}.framework"

DEVICE_BCSYMBOLMAP_PATH="${BUILD_DIR}/${CONFIGURATION}-iphoneos"

DEVICE_DSYM_PATH="${BUILD_DIR}/Products/${CONFIGURATION}-iphoneos/$FRAMEWORK_NAME/${FRAMEWORK_NAME}.framework.dSYM"
SIMULATOR_DSYM_PATH="${BUILD_DIR}/Products/${CONFIGURATION}-iphonesimulator/$FRAMEWORK_NAME/${FRAMEWORK_NAME}.framework.dSYM"

UNIVERSAL_LIBRARY_DIR="${BUILD_DIR}/${CONFIGURATION}-iphoneuniversal"

FRAMEWORK="${UNIVERSAL_LIBRARY_DIR}/${FRAMEWORK_NAME}.framework"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

xcodebuild -scheme ${FRAMEWORK_NAME} -sdk iphoneos -configuration ${CONFIGURATION} -xcconfig Scripts/command-line-build.xcconfig clean install BUILD_LIBRARY_FOR_DISTRIBUTION=YES
xcodebuild -scheme ${FRAMEWORK_NAME} -sdk iphonesimulator -configuration ${CONFIGURATION} -arch x86_64 only_active_arch=no -xcconfig Scripts/command-line-build.xcconfig install BUILD_LIBRARY_FOR_DISTRIBUTION=YES

rm -rf "${UNIVERSAL_LIBRARY_DIR}"

mkdir "${UNIVERSAL_LIBRARY_DIR}"

mkdir "${FRAMEWORK}"

cp -r "${DEVICE_LIBRARY_PATH}/." "${FRAMEWORK}"
cp -r "${SIMULATOR_LIBRARY_PATH}/." "${FRAMEWORK}"

lipo "${SIMULATOR_LIBRARY_PATH}/${FRAMEWORK_NAME}" "${DEVICE_LIBRARY_PATH}/${FRAMEWORK_NAME}" -create -output "${FRAMEWORK}/${FRAMEWORK_NAME}" | echo
cp -r "${FRAMEWORK}" "$OUTPUT_DIR"

cp LICENSE.md "$OUTPUT_DIR"
cp README.md "$OUTPUT_DIR"

xcodebuild archive -scheme JacquardSDK -archivePath

cp -r "${DEVICE_DSYM_PATH}" "$OUTPUT_DIR"
lipo -create -output "$OUTPUT_DIR/${FRAMEWORK_NAME}.framework.dSYM/Contents/Resources/DWARF/${FRAMEWORK_NAME}" \
"${DEVICE_DSYM_PATH}/Contents/Resources/DWARF/${FRAMEWORK_NAME}" \
"${SIMULATOR_DSYM_PATH}/Contents/Resources/DWARF/${FRAMEWORK_NAME}" || exit 1

cd $OUTPUT_DIR
zip -r jacquard-sdk-$VERSION-framework.zip  "${FRAMEWORK_NAME}.framework" LICENSE.md README.md
cd -

UUIDs=$(dwarfdump --uuid "${DEVICE_DSYM_PATH}" | cut -d ' ' -f2)
for file in `find "${DEVICE_BCSYMBOLMAP_PATH}" -name "*.bcsymbolmap" -type f`; do
    fileName=$(basename "$file" ".bcsymbolmap")
    for UUID in $UUIDs; do
        if [[ "$UUID" = "$fileName" ]]; then
            cp -R "$file" "$OUTPUT_DIR"
            dsymutil --symbol-map "$OUTPUT_DIR"/"$fileName".bcsymbolmap "$OUTPUT_DIR/${FRAMEWORK_NAME}.framework.dSYM"
        fi
    done
done
