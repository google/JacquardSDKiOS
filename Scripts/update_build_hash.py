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

def which_git():
  result, out, err = exec_cmd("xcrun which git")
  assert result == 0, "Couldn't find git"
  return out.rstrip()  

def git_sha(git):
  result, out, err = exec_cmd(f"{git} rev-parse --short HEAD")
  assert result == 0, "Getting git sha failed"
  sha = out.rstrip()
  return sha

def git_date(git):
  result, out, err = exec_cmd(f"{git} show -s --format=%ci HEAD")
  assert result == 0, "Getting git commit datetime failed"
  sha = out.rstrip()
  return sha

git = which_git()
sha = git_sha(git)
date = git_date(git)

cd_to_git_root()

file = open("Example/JacquardSDK/BuildHash.json", "w")
assert file, "Couldn't open Example/JacquardSDK/BuildHash.json for writing"
file.write(f"""{{
  "buildHash": "{sha}",
  "buildDate": "{date}"
}}
""")
