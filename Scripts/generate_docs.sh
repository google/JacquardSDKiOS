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
#
# Will only format or check swift files which are uncommited.

rootdir=`git rev-parse --show-toplevel`
cd $rootdir

codeofconduct_path="docs/Code of Conduct.md"
contributing_path=docs/Contributing.md
license_path=docs/License.md

cp CODE_OF_CONDUCT.md "$codeofconduct_path"
cp CONTRIBUTING.md $contributing_path

echo "#License" > $license_path
echo "" >> $license_path
echo '```' >> $license_path
cat LICENSE >> $license_path
echo "" >> $license_path
echo '```' >> $license_path

if ! ${JAZZY:-jazzy} --config jazzy.yaml
then
    echo "Failed to generate documentation"
    exit 1
fi

mkdir -p generated-docs/assets
rm -f generaged-docs/assets/*
cp docs/assets/* generated-docs/assets
cp docs/theme/updated.css generated-docs/css/jazzy.css

rm "$codeofconduct_path"
rm $license_path
rm $contributing_path
