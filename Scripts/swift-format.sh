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
#
# Will only format or check swift files which are uncommited.

if [[ "arg:$1" == "arg:format" ]]; then
    mode=format
    mode_flag=-i
elif [[ "arg:$1" == "arg:lint" ]]; then
    mode=lint
    mode_flag=""
else
    echo "Usage: swift-format.sh [lint|format]"
    exit 1
fi

if which swift-format >/dev/null; then
  # format unstaged files.
  git diff --diff-filter=d --name-only | grep -e '\(.*\).swift$' | while read line;
  do
    swift-format -m $mode $mode_flag "${line}";
  done
  # format already staged files.
  git diff --diff-filter=d --staged --name-only | grep -e '\(.*\).swift$' | while read line;
  do
    swift-format -m $mode $mode_flag "${line}";
    git add "$line";
  done
else
    echo "warning: swift-format not installed"
    exit 2
fi
