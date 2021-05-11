#!/usr/bin/python3
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

import subprocess
import os
import sys
import re
import json

assert sys.version_info >= (3, 8), "Python 3.8 or higher required"

# Global used to report failing release readiness.
release_ready = True

# Code coverage constants.
minimum_code_coverage = 0.8
# Some files are untestable (eg. wrappers designed to make CoreBluetooth code testable).
untestable_files = [
  "JacquardSDK/Classes/CentralManagerImplementation.swift",
  "JacquardSDK/Classes/Internal/Transport/PeripheralImplementation.swift",
  "JacquardSDK/Classes/Internal/Transport/Peripheral.swift",
  "JacquardSDK/Protobuf/jacquard.pb.swift",
  "JacquardSDK/Protobuf/publicSdk.pb.swift"
]


def exec_cmd(cmd):
  proc = subprocess.Popen(
      cmd,
      stdout=subprocess.PIPE,
      stderr=subprocess.PIPE,
      shell=True,
      universal_newlines=True)
  std_out, std_err = proc.communicate()
  return proc.returncode, std_out, std_err


def cd_to_git_root():
  exit_code, stdout, stderr = exec_cmd("git rev-parse --show-toplevel")
  assert exit_code == 0, ("ERROR: You don't seem to be in a subdirectory of the"
                          " repository (%r)\n%r") % (exit_code, stderr)
  os.chdir(stdout.rstrip())


def check_documentation_percentage():
  print("Documentation coverage: ", end="", flush=True)
  cd_to_git_root()
  exit_code, stdout, stderr = exec_cmd("jazzy --config jazzy.yaml")
  assert exit_code == 0, "ERROR: jazzy returned non-zero exit code (%r)\n%r" % (
      exit_code, stderr)
  # TODO: Might need a different regex to match 100%.
  percentage_re = re.compile(r"^([0-9]+)% documentation coverage")
  for line in stdout.splitlines():
    if match := percentage_re.search(line):
      percentage = match.group(1)
      if percentage != "100":
        print("ERROR: Documentation incomplete: %r" % line)
        global release_ready
        release_ready = False
      else:
        print("ok")
      return
  assert False, ("ERROR: Documentation percentage could not be found in jazzy "
                 "output: %r") % stdout


def check_swift_format():
  print("Checking swift-format lint: ", end="", flush=True)
  cd_to_git_root()
  exit_code, stdout, stderr = exec_cmd(
      "swift-format lint --recursive JacquardSDK/Classes")
  # swift-format doesn't set exit_code for warnings.
  swift_format_success = True
  if stderr:
    path_re = re.compile(r"JacquardSDK/.*")
    ignore_re = re.compile(r"NoBlockComments")
    for line in stderr.splitlines():
      if ignore_re.search(line):
        continue
      match = path_re.search(line)
      assert match, "Unexpected swift-format output: %r" % stderr
      print(f" * {match.group(0)}")
      swift_format_success = False
  if swift_format_success:
    print("ok")
  else:
    global release_ready
    release_ready = False
    print("swift-format lint failed")


def pod_install():
  print("Pod update: ", end="", flush=True)
  cd_to_git_root()
  os.chdir("Example")
  exit_code, stdout, stderr = exec_cmd("pod install")
  assert exit_code == 0, "Failed to pod install %r" % stderr
  print("ok")


def check_code_coverage():
  print("Code coverage: ", end="", flush=True)
  cd_to_git_root()
  os.chdir("Example")
  exit_code, stdout, stderr = exec_cmd(
      "xcodebuild -workspace JacquardSDK.xcworkspace -scheme JacquardSDK-Unit-Tests -enableCodeCoverage YES clean build test CODE_SIGN_IDENTITY="
      " CODE_SIGNING_REQUIRED=NO |grep .xcresult")
  assert exit_code == 0, "xcodebuild failed: %r" % stderr
  if match := re.search(r"/.*\.xcresult", stdout, re.MULTILINE):
    xcresult = match.group(0)
    exit_code, stdout, stderr = exec_cmd(
        "xcrun xccov view --report --files-for-target JacquardSDK.framework --json %r"
        % xcresult)
    report = json.loads(stdout)
    assert len(
        report) == 1, "Expecting only one product in coverage report json"
    files = report[0]["files"]
    assert len(files) > 5, "Expecting some files in coverage report json"
    bad_files = []
    path_re = re.compile(r"JacquardSDK/.*")
    for file in files:
      match = path_re.search(file["path"])
      assert match, "Unexpected file path: %r" % file["path"]
      path = match.group(0)
      if path in untestable_files:
        continue
      if file["lineCoverage"] < minimum_code_coverage:
        bad_files.append((path, file["lineCoverage"]))
    if len(bad_files) > 0:
      print("Minimum code coverage of %r not met by the following files:" %
            minimum_code_coverage)
      for file in bad_files:
        print(f" * {file[0]} : {file[1]}")
        global release_ready
        release_ready = False
  else:
    assert False, ("ERROR: Couldn't find .xcresult archive path in xcodebuild "
                   "output")


def check_pre_commit():
  print("Pre_commit check: ", end="", flush=True)
  cd_to_git_root()
  exit_code, stdout, stderr = exec_cmd("./Scripts/pre_commit.sh")
  if exit_code != 0:
    print("pre_commit.sh failed")
    print(stdout)
    global release_ready
    release_ready = False
  else:
    print("ok")


def check_todo_count(pattern):
  print("TODO count (%r): " % pattern, end="", flush=True)
  cd_to_git_root()
  print("find . -name %r -type f -print0|xargs -0 grep -i TODO|egrep -v 'b/'|wc -l"
      % pattern)
  exit_code, stdout, stderr = exec_cmd(
      "find . -name %r -type f -print0|xargs -0 grep -i TODO|egrep -v 'b/'|wc -l"
      % pattern)
  print(f"without bug: {stdout.strip()}", end="", flush=True)
  exit_code, stdout, stderr = exec_cmd(
      "find . -name %r -type f -print0|xargs -0 grep -i TODO|egrep 'b/'|wc -l"
      % pattern)
  print(f"; with bug: {stdout.strip()}")


check_pre_commit()
check_swift_format()
pod_install()
check_documentation_percentage()
check_code_coverage()
check_todo_count("*.swift")
check_todo_count("*.md")

if release_ready:
  print("Congratulations, the repository is release ready!")
else:
  print("The repository is not release ready. See errors above.")
  exit(1)
