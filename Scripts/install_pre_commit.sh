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

repo_rootdir=$(git rev-parse --show-toplevel)
hookfile="${repo_rootdir}/.git/hooks/pre-commit"

pre_commit_script="${repo_rootdir}/Scripts/pre_commit.sh"

echo "#!/bin/bash" > "${hookfile}"
echo "pre_commit_script='$pre_commit_script'" >> "${hookfile}"
echo 'if [[ -f $pre_commit_script ]]; then' >> "${hookfile}"
echo '  $pre_commit_script' >> "${hookfile}"
echo 'fi' >> "${hookfile}"

chmod u+x "${hookfile}"
chmod u+x "${pre_commit_script}"
