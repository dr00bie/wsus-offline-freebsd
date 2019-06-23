# This file will be sourced by the shell bash.
#
# Filename: ini-files.bash
#
# Copyright (C) 2019 Hartmut Buhrmester
#                    <wsusoffline-scripts-xxyh@hartmut-buhrmester.de>
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
#     Settings are pairs of keys and values. The general format is:
#
#     key=value
#
#     Settings files can be written and maintained using two different
#     approaches:
#
#     1. Preferences files can be written as bash scripts, which are
#        directly imported (sourced) by the shell. This implies, that
#        settings must be valid variable assignments according to the
#        bash syntax:
#
#        - The keys must be valid parameter names, consisting of
#          alphanumerical characters and underscores only.
#        - The values must be quoted as needed, using single or double
#          quotation marks.
#        - The file can be thoroughly commented to explain all settings.
#
#        Preferences files are usually provided as templates, which must
#        be copied before use. They can only be edited manually. Such
#        preferences files are used for permanent settings. A typical
#        example would be the preferences file of the bash itself,
#        ~/.bashrc. The template /etc/skel/.bashrc is copied to the home
#        directory, when a new user is created.
#
#     2. Settings files can also be written as ini files, which are only
#        read and written with special functions. Then these files don't
#        necessarily need to adhere to the bash syntax:
#
#        - Strings like "w60-x64" can be used as keys, although they
#          would not be valid parameter names.
#        - The values are not quoted, even if they consist of several
#          words. Everything from the equals sign "=" to the end of the
#          line will be the value.
#        - Typically, there are no comments in the file.
#
#        Ini files are automatically created on the first run. They are
#        typically used to keep settings between runs.
#
#     In both cases, settings files should be optional, and they may be
#     deleted at any point to start from scratch. Then the application
#     must provide default values for all settings.
#
#     In the Linux download scripts, both approaches are used:
#
#     - The file preferences-template.bash is the template for the
#       file preferences.bash. The template must be copied or renamed
#       to preferences.bash, before it can be used. This is meant as a
#       simple way to protect customized settings from being overwritten
#       on each update. It can then be edited to set some permanent
#       settings like proxy servers or to enable and disable parts of
#       the Linux download scripts.
#
#     - The script update-generator.bash now uses the file
#       update-generator.ini, to keep the current settings between
#       runs. It is created and maintained automatically.
#
#     This file provides two functions for the handling of ini files. It
#     does not implement sections [...] within the file. New settings
#     are always appended to the end of the file.

# ========== Functions ====================================================

# The function read_setting reads a single setting from a settings
# file. If the key was found, its value will be printed to standard
# output, and the function return with success. If the settings file
# does not exist yet, or if the key could not be found, an empty string
# is returned, and the result code is set to "1".

function read_setting ()
{
    local settings_file="$1"
    local key="$2"
    local value=""
    local -i result_code="0"

    if [[ -f "${settings_file}" ]]
    then
        # Search for "${key}=" at the beginning of the line
        if value="$(grep -- "^${key}=" "${settings_file}")"
        then
            # Delete "${key}=" from the beginning of the string
            value="${value/#${key}=/}"
        else
            log_debug_message "The key ${key} was not found in ${settings_file}."
            result_code="1"
        fi
    else
        log_debug_message "The file ${settings_file} does not exist yet."
        result_code="1"
    fi

    # Print the value to standard output
    printf '%s\n' "${value}"
    return "${result_code}"
}


# The function write_setting writes a single setting to the settings
# file. If the settings file does not exist yet, it will be created at
# this point. The setting is only written, if the key is new or if the
# value has changed.

function write_setting ()
{
    local settings_file="$1"
    local key="$2"
    local new_value="$3"
    local old_value=""

    # Create settings file, if it does not exist yet.
    if [[ ! -f "${settings_file}" ]]
    then
        printf '%s\n' "This is an automatically generated file. Do not edit it." > "${settings_file}"
    fi

    # Search for ${key}= at the beginning of the line
    if old_value="$(grep -- "^${key}=" "${settings_file}")"
    then
        # Delete ${key}= from the beginning of the string
        old_value="${old_value/#${key}=/}"

        if [[ "${old_value}" == "${new_value}" ]]
        then
            log_debug_message "No changes for ${key} ..."
        else
            log_debug_message "Changing ${key} from \"${old_value}\" to \"${new_value}\" ..."
            # This pattern assumes, that values are NOT quoted. The
            # search pattern always matches a complete line, because it
            # is enclosed in the regular expressions for the beginning
            # (^) and end of line ($).
            sed -i "s/^${key}=${old_value}$/${key}=${new_value}/" "${settings_file}"
        fi
    else
        # If the key was NOT found in the settings file, then the setting
        # is appended to the end of the file. This is normal for newly
        # created files, but it also allows to add new settings to
        # existing files in newer versions of the Linux download scripts.
        log_debug_message "Appending \"${key}=${new_value}\" to ${settings_file} ..."
        printf '%s\n' "${key}=${new_value}" >> "${settings_file}"
    fi

    return 0
}

# ========== Commands =====================================================

return 0
