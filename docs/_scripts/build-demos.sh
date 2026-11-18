#!/usr/bin/env bash
#
# Documentation Demo Build
# Renders the live demo sites that the gallery links to.
#
# @license MIT License
# @copyright 2026 Mickaël Canouil
# @author Mickaël Canouil
#
# Usage: build-demos.sh <output-dir> [<demo-id>...]
#
# Each demo id has a folder in docs/_demos/. Its `source` file names the
# template (`workshop` or `documentation`) that the demo renders, and every
# other file is copied over the template: an optional `_quarto-layout.yml`
# profile with the keys that are unique to the demo and, for the presets, a
# `_brand-demo.yml`. The keys that every demo shares are written into a
# generated `_quarto-demo.yml` profile, and the site renders with both
# profiles. A demo is rendered in a temporary copy of the template, so the
# templates stay untouched.
#
# With no ids, the script builds the ids in ATELIER_DEMO_IDS when that variable
# is set, and otherwise the ids in DEFAULT_IDS: workshop-sidebar,
# workshop-navbar, docs-navbar, and docs-sidebar. The preset demos are built
# only when you name them. The script first removes all of <output-dir>/demos/,
# so a demo that was removed leaves no stale folder.
# With ids, it replaces only the folders of those ids.
# A relative <output-dir> is resolved against docs/.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(dirname "${SCRIPT_DIR}")"
ROOT_DIR="$(dirname "${DOCS_DIR}")"
DEMOS_DIR="${DOCS_DIR}/_demos"
DEFAULT_IDS="workshop-sidebar workshop-navbar docs-navbar docs-sidebar"

if [[ $# -lt 1 ]]; then
	printf 'Usage: %s <output-dir> [<demo-id>...]\n' "$(basename "$0")" >&2
	exit 2
fi

output_dir="$1"
shift
[[ "${output_dir}" == /* ]] || output_dir="${DOCS_DIR}/${output_dir}"
output_dir="${output_dir%/}"

if [[ $# -gt 0 ]]; then
	ids=("$@")
else
	read -r -a ids <<<"${ATELIER_DEMO_IDS:-${DEFAULT_IDS}}"
	rm -rf "${output_dir}/demos"
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

build_demo() {
	local id="$1"
	local demo_dir="${DEMOS_DIR}/${id}"
	local template site profiles

	if [[ ! -f "${demo_dir}/source" ]]; then
		printf '[demos] %s failed: %s/source is missing\n' "${id}" "${demo_dir}" >&2
		return 1
	fi
	template="$(tr -d '[:space:]' <"${demo_dir}/source")"
	if [[ ! -d "${ROOT_DIR}/templates/${template}" ]]; then
		printf '[demos] %s failed: templates/%s does not exist\n' "${id}" "${template}" >&2
		return 1
	fi

	site="${work_dir}/${id}"
	mkdir -p "${site}/_extensions/local" || {
		printf '[demos] %s failed: cannot create %s\n' "${id}" "${site}" >&2
		return 1
	}
	cp -R "${ROOT_DIR}/templates/${template}/." "${site}" || {
		printf '[demos] %s failed: cannot copy templates/%s\n' "${id}" "${template}" >&2
		return 1
	}
	"${SCRIPT_DIR}/sync-extension.sh" "${site}/_extensions/local" >/dev/null || {
		printf '[demos] %s failed: cannot copy the extension\n' "${id}" >&2
		return 1
	}
	for overlay in "${demo_dir}"/*; do
		[[ "$(basename "${overlay}")" == source ]] && continue
		rm -rf "${site:?}/$(basename "${overlay}")"
		cp -R "${overlay}" "${site}" || {
			printf '[demos] %s failed: cannot copy %s\n' "${id}" "${overlay}" >&2
			return 1
		}
	done

	cat >"${site}/_quarto-demo.yml" <<EOF || {
website:
  site-url: https://m.canouil.dev/quarto-atelier/demos/${id}/
  repo-url: https://github.com/mcanouil/quarto-atelier
  repo-subdir: templates/${template}
  announcement:
    icon: info-circle
    dismissable: false
    type: info
    position: below-navbar
    content: "This is a live demo of Atelier. [Back to the gallery](https://m.canouil.dev/quarto-atelier/gallery.html)."
EOF
		printf '[demos] %s failed: cannot write the demo profile\n' "${id}" >&2
		return 1
	}
	profiles="demo"
	[[ -f "${site}/_quarto-layout.yml" ]] && profiles="demo,layout"

	rm -rf "${output_dir}/demos/${id}"
	mkdir -p "${output_dir}/demos" || {
		printf '[demos] %s failed: cannot prepare %s/demos\n' "${id}" "${output_dir}" >&2
		return 1
	}
	printf '[demos] Building %s from templates/%s\n' "${id}" "${template}"
	if ! quarto render "${site}" --profile "${profiles}" \
		--output-dir "${output_dir}/demos/${id}" >"${work_dir}/${id}.log" 2>&1; then
		cat "${work_dir}/${id}.log" >&2
		printf '[demos] %s failed\n' "${id}" >&2
		return 1
	fi
}

for id in "${ids[@]}"; do
	build_demo "${id}" || exit 1
done
