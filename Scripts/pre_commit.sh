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

# Lint Swift.
echo "Linting"
lint_out=$(Scripts/swift-format.sh lint 2>&1)
if [[ -n "$lint_out" ]]; then
    echo "swift-format linting failed:"
    echo ""
    echo $lint_out
    echo ""
    echo "Fix with:"
    echo "./Scripts/swift-format.sh format"
    exit 1
fi

licenses_ok=true

# Rough check of licenses.
echo "Checking licenses"
IFS=$'\n'
for file in $(find . -path './Example/Pods' -prune -false -or -path './.build' -prune -false -or -type f -name '*.swift' -or -name '*.sh' -or -name '*.py')
do
    if head "$file" | grep "Copyright 2021 Google LLC" > /dev/null; then
        # Found copyright line.
        :
    else
        echo "File missing license: $file"
        licenses_ok=false
    fi
    if head "$file" | grep "http://www.apache.org/licenses/LICENSE-2.0" > /dev/null; then
        # Found Apache license URL.
        :
    else
        echo "File missing or incorrect license: $file"
        licenses_ok=false
    fi
done

if [[ $licenses_ok == false ]]; then
    echo "The correct license can be seen at go/releas#Apache-header"
    exit 2
fi

exit 0
