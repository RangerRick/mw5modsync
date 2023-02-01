#!/bin/bash

if [ -z "$2" ]; then
	echo "usage: $0 <mw5-directory> <download-directory>"
	exit 1
fi

UNPACKED_DIR="$(mktemp -d -t unpacked.XXXXXX)"

finish() {
	rm -rf "${UNPACKED_DIR}"
}
trap finish EXIT

set -euo pipefail
IFS=$'\n\t'

MW5_DIR="$1"
DOWNLOAD_DIR="$2"

rm -rf "${UNPACKED_DIR}"
mkdir -p "${DOWNLOAD_DIR}" "${UNPACKED_DIR}"

if [ ! -d "${MW5_DIR}/MW5Mercs" ]; then
	echo 'Mechwarrior 5 directory does not contain an MW5Mercs folder!'
	exit 1
fi

DOWNLOAD_DIR="$(readlink -f "${DOWNLOAD_DIR}")"
MW5_DIR="$(readlink -f "${MW5_DIR}")"

UNPACK_DIRS=(
	"Rise of Rasalhague"
	"MW2"
)

MOD_DIR="${MW5_DIR}/MW5Mercs/mods"

if [ -e "${MOD_DIR}/modlist.json" ]; then
	cp "${MOD_DIR}/modlist.json" "${UNPACKED_DIR}/"
fi

do_quietly() {
	local _text="$1"; shift
	local _output;

	echo -e "* ${_text}... \c"

	_output="$(mktemp -t unpack.output.XXXXXX)"
	if "$@" >"${_output}" 2>&1; then
		echo "done"
		rm -f "${_output}" || :
	else
		echo "failed"
		cat "${_output}"
		rm -f "${_output}" || :
		exit 1
	fi
}

do_quietly "syncing mod archive" rsync -avr --partial --progress --delete --exclude=Depricated --exclude=Deprecated ln1.raccoonfink.com::mw5/ "${DOWNLOAD_DIR}/"

get_mod_filename_from_archive() {
	local _source_file="$1"

	case "${_source_file}" in
		*.zip)
			unzip -l "${_source_file}" | grep -E '/mod\.json$' | awk '{ $1=$2=$3=""; print $0}' | sed -e 's,^ *,,' | grep -E '^[^/]*/mod.json$'
			;;
		*.rar)
			unrar l "${_source_file}" | grep -E '/mod\.json$' | awk '{ $1=$2=$3=$4=""; print $0}' | sed -e 's,^ *,,' | grep -E '^[^/]*/mod.json$'
			;;
		*.7z)
			7zr l "${_source_file}" | grep -E '[0-9][0-9]*   *[^/][^/]*/mod.json' | sed -e 's,^.*[0-9],,' -e 's,^ *,,' | grep -E '^[^/]*/mod.json$'
			;;
		*)
			echo "unknown type: ${_source_file}"
			exit 1
			;;
	esac
}

get_mod_json_from_archive() {
	local _source_file="$1"
	local _mod_filename

	_mod_filename="$(get_mod_filename_from_archive "${_source_file}")"

	case "${_source_file}" in
		*.zip)
			unzip -q -c "${_source_file}" "${_mod_filename}"
			;;
		*.rar)
			unrar p "${_source_file}" "${_mod_filename}"
			;;
		*.7z)
			7zr e -so "${_source_file}" "${_mod_filename}"
			;;
		*)
			echo "unknown type: ${_source_file}"
			exit 1
			;;
	esac
}

unpack_files() {
	local _from_dir="$1"

	local _from_dir_pretty;
	local _mod_json;
	local _old_mod_file;

	cd "${_from_dir}" || exit 1
	for FILE in *.*; do
		_mod_json="$(get_mod_json_from_archive "${FILE}")"

		_display_name="$(echo "${_mod_json}" | jq -r '.displayName')"
		_dir_name="$(get_mod_filename_from_archive "${FILE}" | sed -e 's,/mod.json$,,')"
		_new_version="$(echo "${_mod_json}" | jq -r '.version')"
		_new_build_number="$(echo "${_mod_json}" | jq -r '.buildNumber')"

		if [ -d "${MOD_DIR}/${_dir_name}" ]; then
			_old_mod_file="${MOD_DIR}/${_dir_name}/mod.json"
			_old_version="$(jq -r '.version' < "${_old_mod_file}")"
			_old_build_number="$(jq -r '.buildNumber' < "${_old_mod_file}")"

			if [ "${_old_version}" = "${_new_version}" ] && \
				[ -n "${_old_build_number}" ] && [ -n "${_new_build_number}" ] && \
				[ "${_old_build_number}" = "${_new_build_number}" ]
			then
				do_quietly "reusing existing ${_display_name} version ${_new_version} build ${_new_build_number}" rsync -avr --delete --link-dest="${MOD_DIR}/${_dir_name}/" "${MOD_DIR}/${_dir_name}/" "${UNPACKED_DIR}/${_dir_name}/"
				continue
			fi
		fi

		cd "${UNPACKED_DIR}" || exit 1
		_from_dir_pretty="$(basename "${_from_dir}")"

		case "${FILE}" in
			*.zip)
				do_quietly "unpacking ${FILE} from ${_from_dir_pretty}" unzip "${_from_dir}/${FILE}"
				;;
			*.rar)
				do_quietly "unpacking ${FILE} from ${_from_dir_pretty}" unrar x "${_from_dir}/${FILE}"
				;;
			*.7z)
				do_quietly "unpacking ${FILE} from ${_from_dir_pretty} " 7zr x "${_from_dir}/${FILE}"
				;;
			*)
				echo "unknown type: ${FILE}"
				exit 1;
				;;
		esac

		cd - >/dev/null 2>&1 || exit 1
	done
	cd - >/dev/null 2>&1 || exit 1
}


for DIR in "${UNPACK_DIRS[@]}"; do
	unpack_files "${DOWNLOAD_DIR}/${DIR}"
done

do_quietly "updating MW5 with unpacked mods" rsync -avr --delete --link-dest="${UNPACKED_DIR}/" "${UNPACKED_DIR}/" "${MOD_DIR}/"
