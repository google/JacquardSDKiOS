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
# limitations under the License.=

VERSION=0.1.0

rootdir=`git rev-parse --show-toplevel`
cd $rootdir

CONFIGURATION=Release
FRAMEWORK_NAME=JacquardSDK

OUTDIR="$rootdir/generated-frameworks"
mkdir -p $OUTDIR

SIM_ARCHIVE="$OUTDIR/JacquardSDK-iphonesimulator.xcarchive"
rm -fr "$SIM_ARCHIVE"

IPHONE_ARCHIVE="$OUTDIR/JacquardSDK-iphoneos.xcarchive"
rm -fr "$IPHONE_ARCHIVE"

XCFRAMEWORK_NAME="JacquardSDK.xcframework"
XCFRAMEWORK="$OUTDIR/$XCFRAMEWORK_NAME"
rm -fr "$XCFRAMEWORK"

PRODUCT_PATH="Products/Library/Frameworks/JacquardSDK.framework"

ZIP_FILE="$OUTDIR/jacquard-sdk-$VERSION-xcframework.zip"
rm -f $ZIP_FILE

xcodebuild archive \
 -scheme JacquardSDK \
 -archivePath "$SIM_ARCHIVE" \
 -configuration "$CONFIGURATION" \
 -sdk iphonesimulator \
 clean install \
 SKIP_INSTALL=NO \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild archive \
 -scheme JacquardSDK \
 -archivePath "$IPHONE_ARCHIVE" \
 -configuration "$CONFIGURATION" \
 -sdk iphoneos \
 install \
 SKIP_INSTALL=NO \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES

xcodebuild -create-xcframework \
 -framework "$SIM_ARCHIVE/$PRODUCT_PATH" \
 -framework "$IPHONE_ARCHIVE/$PRODUCT_PATH" \
 -output "$XCFRAMEWORK" \
 BUILD_LIBRARY_FOR_DISTRIBUTION=YES

cd "$OUTDIR"
zip -r "$ZIP_FILE" "$XCFRAMEWORK_NAME"
cd $rootdir
zip -u "$ZIP_FILE" README.md
zip -u "$ZIP_FILE" LICENSE.md

swift package compute-checksum "$ZIP_FILE"
