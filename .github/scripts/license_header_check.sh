#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
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

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

missing=()

while IFS= read -r -d '' file; do
  case "${file}" in
    src/integration/rtl/generated/usb_ocp_recovery_reg.sv | \
    src/integration/rtl/generated/usb_ocp_recovery_reg_pkg.sv)
      continue
      ;;
  esac

  case "${file}" in
    *.sv | *.svh | *.v | *.vh | *.vhd | *.vhdl | \
    *.py | *.sh | *.csh | *.tcl | *.f | *.rdl | \
    *.yml | *.yaml | *.txt | \
    tools/scripts/synopsys_sim.setup | tools/scripts/ucli_script)
      header="$(head -n 20 "${file}")"
      if ! grep -Eq \
          '^[[:space:]]*(#|//|--)[[:space:]]*SPDX-License-Identifier:[[:space:]]*Apache-2\.0[[:space:]]*$' \
          <<< "${header}"; then
        missing+=("${file}")
      fi
      ;;
  esac
done < <(git ls-files -z)

if ((${#missing[@]} != 0)); then
  echo "The following tracked files are missing an Apache-2.0 SPDX header:"
  printf '  %s\n' "${missing[@]}"
  exit 1
fi

echo "Apache-2.0 license header check completed successfully"
