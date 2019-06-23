#!/usr/bin/env bash
#
# Filename: compare-update-tables.bash
#
# Copyright (C) 2016-2019 Hartmut Buhrmester
#                         <wsusoffline-scripts-xxyh@hartmut-buhrmester.de>
#
# License
#
#     This file is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published
#     by the Free Software Foundation, either version 3 of the License,
#     or (at your option) any later version.
#
#     This file is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#     General Public License for more details.
#
#     You should have received a copy of the GNU General
#     Public License along with this program.  If not, see
#     <http://www.gnu.org/licenses/>.
#
# Description
#
#     This script is used for development. It compares two directories
#     with office update tables.
#
#     For cross-platform compatibility, trailing carriage returns are
#     deleted and the files are sorted in a generic order. Then they
#     are compared with diff.
#
#     A typical result is shown in the file example-results-ofc.txt.
#
# Usage
#
#     ./compare-update-tables.bash <windows-path> <linux-path>
#
#     The paths are the complete pathnames of the directories
#     wsusoffline/client/ofc on both Windows and Linux, for example:
#
#     /media/${USER}/Windows/wsusoffline/client/ofc
#     /home/${USER}/wsusoffline/client/ofc
#
#     The Windows partition is usually mounted in one of the directories
#     /mnt, /media or "/media/${USER}".

# ========== Shell options ================================================

set -o nounset
set -o errexit
set -o errtrace
set -o pipefail

# ========== Environment variables ========================================

# Use English messages and a generic sort order
export LC_ALL=C

# ========== Configuration ================================================

# Paths to the temporary directories
temp_ofc_windows="/tmp/ofc-windows"
temp_ofc_linux="/tmp/ofc-linux"

# ========== Functions ====================================================

function create_diff_files ()
{
    local source_directory="$1"
    local temp_directory="$2"
    local filename=""

    if [[ -d "${source_directory}" ]]
    then
        printf '%s\n' "Processing source directory: ${source_directory} ..."
    else
        printf '%s\n' "Error: The directory ${source_directory} was not found."
        exit 1
    fi

    mkdir -p "${temp_directory}"
    rm -f "${temp_directory}"/*.csv

    pushd "${source_directory}" > /dev/null
    for filename in ./*.csv
    do
        printf '%s\n' "Processing: ${filename}"
        tr -d '\r' < "${filename}" | sort > "${temp_directory}/${filename}"
        # Remove empty files
        if [[ ! -s "${temp_directory}/${filename}" ]]
        then
            rm -f "${temp_directory}/${filename}"
        fi
    done
    popd > /dev/null
}

# ========== Commands =====================================================

# Resolving the installation path with GNU readlink is very reliable,
# but it may only work in Linux and FreeBSD. Remove the option -f for
# BSD readlink on Mac OS X. If there are problems with resolving the
# installation path, change directly into the installation directory of
# this script and run it script from there.

cd "$(dirname "$(readlink -f "$0")")" || exit 1

# Parse command-line arguments
#
# Print the usage, if not enough arguments are provided
if (( $# < 2 ))
then
    printf '%s\n' "Usage: ./compare-update-tables.bash <windows-path> <linux-path>

<windows-path> and <linux-path> are the complete pathnames of the
directories wsusoffline/client/ofc on Windows and Linux, for example:

/media/${USER}/Windows/wsusoffline/client/ofc
/home/${USER}/wsusoffline/client/ofc"
    exit 1
fi

# Set the pathnames of the directories wsusoffline/client/ofc on Windows
# and Linux
source_ofc_windows="$1"
source_ofc_linux="$2"

echo "Creating diff files..."
create_diff_files "${source_ofc_windows}" "${temp_ofc_windows}"
create_diff_files "${source_ofc_linux}" "${temp_ofc_linux}"

echo "Comparing diff files..."
diff --unified --color=auto --report-identical-files "${temp_ofc_windows}" "${temp_ofc_linux}"

echo "Cleaning up temporary directories..."
rm -rf "${temp_ofc_windows}"
rm -rf "${temp_ofc_linux}"
exit 0
