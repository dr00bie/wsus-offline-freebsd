# This file will be sourced by the shell bash.
#
# Filename: 10-parse-command-line.bash
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


# ========== Global variables =============================================

language_parameter="" # as passed on the command-line

updates_list=()
architectures_list=()
languages_list=()
downloads_list=( "wsus" )

need_localized_ofc="disabled"
include_service_packs="disabled"

# ========== Functions ====================================================

function parse_command_line ()
{
    log_info_message "Parsing command-line..."
    if (( ${#command_line_parameters[@]} < 2 ))
    then
        wrong_parameter "At least two parameters are required."
    else
        parse_first_parameter_as_list "${command_line_parameters[@]}"
        parse_preliminary_update_list
        parse_second_parameter_as_list "${command_line_parameters[@]}"
        parse_remaining_parameters "${command_line_parameters[@]}"
        print_command_line_summary
    fi
    return 0
}


function wrong_parameter ()
{
    log_error_message "$@"
    show_usage
    exit 1
} 1>&2


function parse_first_parameter_as_list ()
{
    local update_parameter="$1"
    local update_name=""

    # The first parameter may be a comma-separated list of update names,
    # which are added to an indexed array. Internal lists are expanded
    # at this step.
    log_info_message "Parsing first parameter..."
    for update_name in ${update_parameter//,/ }
    do
        case "${update_name}" in
            # Internal lists
            all)
                log_info_message "Expanding internal list: All Windows and Office updates, 32-bit and 64-bit"
                updates_list+=( "${list_all[@]}" )
            ;;
            all-x86)
                log_info_message "Expanding internal list: All Windows and Office updates, 32-bit"
                updates_list+=( "${list_all_x86[@]}" )
            ;;
            all-x64)
                log_info_message "Expanding internal list: All Windows and Office updates, 64-bit"
                updates_list+=( "${list_all_x64[@]}" )
            ;;
            all-win)
                log_info_message "Expanding internal list: All Windows updates, 32-bit and 64-bit"
                updates_list+=( "${list_all_win[@]}" )
            ;;
            all-win-x86)
                log_info_message "Expanding internal list: All Windows updates, 32-bit"
                updates_list+=( "${list_all_win_x86[@]}" )
            ;;
            all-win-x64)
                log_info_message "Expanding internal list: All Windows updates, 64-bit"
                updates_list+=( "${list_all_win_x64[@]}" )
            ;;
            all-ofc)
                log_info_message "Expanding internal list: All Office updates, 32-bit and 64-bit"
                updates_list+=( "${list_all_ofc[@]}" )
            ;;
            all-ofc-x86)
                log_info_message "Expanding internal list: All Office updates, 32-bit"
                updates_list+=( "${list_all_ofc_x86[@]}" )
            ;;
            # Single updates
            #
            # This step lists all known updates from all versions of
            # WSUS Offline Update, but the ${updates_table} determines
            # the valid updates for a particular version.
            wxp | w2k3 | w2k3-x64 | w60 | w60-x64 | w61 | w61-x64 | w62 | w62-x64 | w63 | w63-x64 | w100 | w100-x64 | o2k3 | o2k7 | o2k10 | o2k10-x64 | o2k13 | o2k13-x64 | o2k16 | o2k16-x64)
                if name_to_description "${update_name}" "${updates_table}" >/dev/null
                then
                    log_info_message "Adding \"${update_name}\" to the list of updates..."
                    updates_list+=( "${update_name}" )
                else
                    log_warning_message "Update ${update_name} is not supported by this version of WSUS Offline Update."
                fi
            ;;
            # Unknown or unsupported updates
            *)
                wrong_parameter "Update ${update_name} was not found."
            ;;
        esac
    done
    echo ""
}


# Parse the preliminary list of updates to add common updates for Windows
# and Office (win and ofc), and to build a list of needed architectures.
#
# The architectures list is needed for the optional downloads wddefs,
# msse, wddefs8 and dotnet. They must be downloaded in 32-bit, 64-bit,
# or both. The selected Windows versions determine, which architectures
# are needed.

function parse_preliminary_update_list ()
{
    local update_name=""
    local update_description=""
    local need_x86="disabled"
    local need_x64="disabled"
    local need_win="disabled"
    local need_ofc="disabled"

    log_info_message "Parsing preliminary list of updates..."
    for update_name in "${updates_list[@]}"
    do
        # Print the update name and description for reference. The update
        # name was already validated at the previous step.
        if update_description="$(name_to_description "${update_name}" "${updates_table}")"
        then
            log_info_message "Found update: ${update_name}, ${update_description}"
        else
            wrong_parameter "Update ${update_name} was not found."
        fi

        # Determine the common updates to add:
        # - win for all Windows updates
        # - ofc for all Office updates
        case "${update_name}" in
            wxp | w2k3 | w2k3-x64 | w60 | w60-x64 | w61 | w61-x64 | w62 | w62-x64 | w63 | w63-x64 | w100 | w100-x64)
                need_win="enabled"
            ;;
            o2k3 | o2k7 | o2k10 | o2k10-x64 | o2k13 | o2k13-x64)
                need_ofc="enabled"
                need_localized_ofc="enabled"
            ;;
            o2k16 | o2k16-x64)
                need_ofc="enabled"
            ;;
            *)
                fail "Unknown update ${update_name}"
            ;;
        esac

        # Determine the needed architectures for optional updates like
        # .NET Frameworks, Windows Defender virus definitions, and
        # Microsoft Security Essentials. This depends on the Windows
        # updates only.
        case "${update_name}" in
            wxp | w2k3 | w60 | w61 | w62 | w63 | w100)
                # Optional downloads will be downloaded in 32-bit versions
                need_x86="enabled"
            ;;
            w2k3-x64 | w60-x64 | w61-x64 | w62-x64 | w63-x64 | w100-x64)
                # Optional downloads will be downloaded in 64-bit versions
                need_x64="enabled"
            ;;
            o2k3 | o2k7 | o2k10 | o2k10-x64 | o2k13 | o2k13-x64 | o2k16 | o2k16-x64)
                :
            ;;
            *)
                fail "Unknown update ${update_name}"
            ;;
        esac
    done
    echo ""

    # Add common updates to the list of updates
    log_info_message "Adding common updates for all Windows and Office versions..."
    if [[ "${need_win}" == "enabled" ]]
    then
        # In current versions of WSUS Offline Update, the download target
        # "win" only contains two installers for Silverlight. Such
        # browser extensions are rarely used anymore, and they can be
        # disabled in the preferences file.
        if [[ "${include_win_glb}" == "enabled" ]]
        then
            log_info_message "Adding \"win\" to the list of updates..."
            updates_list+=( "win" )
        else
            log_info_message "Processing of \"win glb\" is disabled by preferences settings."
        fi
    fi
    if [[ "${need_ofc}" == "enabled" ]]
    then
        log_info_message "Adding \"ofc\" to the list of updates..."
        updates_list+=( "ofc" )
    fi
    echo ""

    # Create a list of needed architectures
    log_info_message "Building a list of needed architectures for the included downloads. This depends on Windows updates only..."
    if [[ "${need_x86}" == "enabled" ]]
    then
        log_info_message "Adding \"x86\" to the list of architectures..."
        architectures_list+=( "x86" )
    fi
    if [[ "${need_x64}" == "enabled" ]]
    then
        log_info_message "Adding \"x64\" to the list of architectures..."
        architectures_list+=( "x64" )
    fi
    echo ""
    return 0
}


# The languages_table lists 24 languages. Windows Server 2003 only
# supports a few of them. But, if several updates are specified on
# the command-line using a comma-separated list like "wxp,w2k3,w60",
# this can not be validated here, because all languages are valid for
# Windows XP and Vista. The check for supported languages is done in
# the file 60-main-updates.bash instead.

function parse_second_parameter_as_list ()
{
    language_parameter="$2" # globally defined, because it is used for the
                            # timestamp files
    local language_name=""
    local language_description=""

    # The second parameter can be parsed as a comma-separated list of
    # language names.
    log_info_message "Parsing second parameter..."
    for language_name in ${language_parameter//,/ }
    do
        if language_description="$(name_to_description "${language_name}" "${languages_table}")"
        then
            log_info_message "Found language: ${language_name}, ${language_description}"
            languages_list+=( "${language_name}" )
        else
            wrong_parameter "The language ${language_name} was not found."
        fi
    done
    echo ""
    return 0
}


function parse_remaining_parameters ()
{
    local option_name=""
    local option_description=""

    log_info_message "Parsing remaining parameters..."
    shift 2
    while (( $# > 0 ))
    do
        option_name="$1"
        if option_description="$(name_to_description "${option_name}" "${options_table_all}")"
        then
            case "${option_name}" in
                -includesp)
                    log_info_message "Service Packs are included"
                    include_service_packs="enabled"
                ;;
                -includecpp | -includewddefs | -includemsse | -includewddefs8)
                    # Delete the prefix -include and add the download
                    # name to the list of included downloads
                    option_name="${option_name/#-include/}"
                    log_info_message "Found included download: ${option_name}, ${option_description}"
                    downloads_list+=( "${option_name}" )
                ;;
                -includedotnet)
                    log_info_message "Found included download: dotnet, .NET Frameworks"
                    downloads_list+=( "dotnet" ) # statically defined installers
                    updates_list+=( "dotnet" )   # dynamically calculated updates
                ;;
                *)
                    fail "Unknown option ${option_name}"
                ;;
            esac
        else
            log_warning_message "Option $1 is not recognized."
        fi
        shift
    done

    echo ""
    return 0
}


function print_command_line_summary ()
{
    local architectures_list_serialized="-"

    # The list of architectures may be empty, if only Office update
    # are selected. Bash up to version 4.3 will treat empty arrays as
    # "unset", even if the array variables were properly declared and
    # initialized. This is fixed in bash version 4.4.
    if (( ${#architectures_list[@]} > 0 ))
    then
        architectures_list_serialized="${architectures_list[*]}"
    fi
    # This test is not necessary for the other lists, because they should
    # never be empty. One update and language must be specified on the
    # command line, and the list of included updates is initialized with
    # "wsus".

    log_info_message "Final lists after processing command-line arguments. dotnet, if selected, appears twice to handle both installers and dynamic updates.
- Updates:       ${updates_list[*]}
- Architectures: ${architectures_list_serialized} (depends on Windows updates only)
- Languages:     ${languages_list[*]}
- Downloads:     ${downloads_list[*]}
"
    return 0
}

# ========== Commands =====================================================

parse_command_line
return 0
