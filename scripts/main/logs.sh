#!/bin/bash
#
#  Copyright (c) 2025 Sameer Al Sahab
#  Licensed under the MIT License. See LICENSE file for details.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#

# [
LOG_LINE_WIDTH=80
LOG_BASE_INDENT=2
LOG_INDENT_STEP=2

# Colors
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_WHITE='\033[1;37m'
COLOR_GRAY='\033[0;90m'
COLOR_RESET='\033[0m'

# Text formatting
TEXT_BOLD='\033[1m'
TEXT_DIM='\033[2m'

LOG_BEGIN()
{
    local MESSAGE_TITLE="$1"
    printf "%*s${COLOR_BLUE}→ %b${COLOR_RESET}\n\n" "$LOG_BASE_INDENT" "" "$MESSAGE_TITLE"
}

LOG_END()
{
    local MESSAGE_INDEX=0
    local MESSAGE_INDENT

    echo
    for MESSAGE_TITLE in "$@"; do
        MESSAGE_INDENT=$((LOG_BASE_INDENT + (MESSAGE_INDEX * LOG_INDENT_STEP)))
        printf "%*s${COLOR_GREEN}✓ %b${COLOR_RESET}\n" "$MESSAGE_INDENT" "" "$MESSAGE_TITLE"
        ((MESSAGE_INDEX++))
    done
    echo
}

ERROR_EXIT()
{
    local ERROR_MESSAGE="$1"

    printf "${COLOR_RED}X %b${COLOR_RESET}\n" "$ERROR_MESSAGE"
    exit 1
}

COMMAND_EXISTS()
{
    command -v "$1" >/dev/null 2>&1
}

GET_TIMESTAMP()
{
    date '+%H:%M:%S'
}

GET_DURATION()
{
    local START_TIME=$1
    local END_TIME=$2
    local DELTA_TIME=$((END_TIME - START_TIME))
    local SECONDS=$((DELTA_TIME % 60))
    local MINUTES=$(((DELTA_TIME / 60) % 60))
    local HOURS=$((DELTA_TIME / 3600))

    if [ $HOURS -gt 0 ]; then
        printf "%02d:%02d:%02d" $HOURS $MINUTES $SECONDS
    else
        printf "%02d:%02d" $MINUTES $SECONDS
    fi
}

PRINT_DIVIDER()
{
    local DIVIDER_CHAR="${1:--}"
    printf "${COLOR_GRAY}%*s${COLOR_RESET}\n" "$LOG_LINE_WIDTH" "" | tr ' ' "$DIVIDER_CHAR"
}

LOG_INFO()
{
    printf "    ${COLOR_CYAN}▪ %b${COLOR_RESET}\n" "$*"
}

LOG_WARN()
{
    printf "    ${COLOR_YELLOW}⚠ %b${COLOR_RESET}\n" "$*"
}

LOG()
{
    printf "%b\n" "$1"
}


RUN_CMD()
{
    local COMMAND_DESCRIPTION="$1"
    shift
    local COMMAND_STRING="$*"

    local TEMP_LOG_FILE SPINNER_CHARS SPINNER_INDEX COMMAND_PID
    SPINNER_CHARS='-\|/'
    SPINNER_INDEX=0

    TEMP_LOG_FILE=$(mktemp)

    printf "    ${COLOR_BLUE}▸${COLOR_RESET} %b... " "$COMMAND_DESCRIPTION"

    eval "$COMMAND_STRING" >"$TEMP_LOG_FILE" 2>&1 &
    COMMAND_PID=$!

    if IS_INTERACTIVE; then
        tput civis 2>/dev/null
        while kill -0 "$COMMAND_PID" 2>/dev/null; do
            SPINNER_INDEX=$(( (SPINNER_INDEX + 1) % 4 ))
            printf "\b${COLOR_CYAN}%b${COLOR_RESET}" "${SPINNER_CHARS:$SPINNER_INDEX:1}"
            sleep 0.1
        done
        tput cnorm 2>/dev/null
    fi

    wait "$COMMAND_PID"
    local COMMAND_EXIT_CODE=$?

    if (( COMMAND_EXIT_CODE == 0 )); then
        printf "\b${COLOR_GREEN}[OK]${COLOR_RESET}\n"
        rm -f "$TEMP_LOG_FILE"
    else
        printf "\b${COLOR_RED}[FAIL]${COLOR_RESET}\n\n"

        printf "    ${COLOR_RED}└─ ERROR OUTPUT:${COLOR_RESET}\n"
        PRINT_DIVIDER "="
        sed 's/^/    | /' "$TEMP_LOG_FILE"
        PRINT_DIVIDER "="

        rm -f "$TEMP_LOG_FILE"
        ERROR_EXIT "Failed during: $COMMAND_DESCRIPTION"
    fi
}

SILENT()
{
    "$@" > /dev/null 2>&1
}

CONFIRM_ACTION()
{
    local PROMPT_MESSAGE="$1"
    local DEFAULT_ANSWER="${2:-false}"

    if IS_GITHUB_ACTIONS; then
        [[ "$DEFAULT_ANSWER" == "true" ]] && return 0 || return 1
    fi

    local PROMPT_SUFFIX="[y/N]"
    [[ "$DEFAULT_ANSWER" == "true" ]] && PROMPT_SUFFIX="[Y/n]"

    echo -ne "${COLOR_CYAN}?${COLOR_RESET} $PROMPT_MESSAGE $PROMPT_SUFFIX: "
    read -r USER_RESPONSE
    [[ -z "$USER_RESPONSE" ]] && [[ "$DEFAULT_ANSWER" == "true" ]] && return 0

    case "${USER_RESPONSE,,}" in
        y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

PROMPT_CHOICE()
{
    local PROMPT_MESSAGE="$1"
    shift
    local CHOICE_OPTIONS=("$@")
    local SELECTED_INDEX

    echo >&2
    printf "${TEXT_BOLD}${COLOR_WHITE}%b${COLOR_RESET}\n" "$PROMPT_MESSAGE" >&2
    for OPTION_INDEX in "${!CHOICE_OPTIONS[@]}"; do
        printf "  ${COLOR_CYAN}[%d]${COLOR_RESET} %b\n" $((OPTION_INDEX + 1)) "${CHOICE_OPTIONS[$OPTION_INDEX]}" >&2
    done

    while true; do
        printf "${COLOR_GREEN}▸${COLOR_RESET} Select (1-${#CHOICE_OPTIONS[@]}): " >&2
        read -r SELECTED_INDEX
        if [[ "$SELECTED_INDEX" =~ ^[0-9]+$ ]] && [ "$SELECTED_INDEX" -ge 1 ] && [ "$SELECTED_INDEX" -le ${#CHOICE_OPTIONS[@]} ]; then
            echo "$SELECTED_INDEX"
            return 0
        fi
    done
}

UPDATE_LOG_LINE()
{
    local LOG_MESSAGE="$1"
    local COMPLETION_FLAG="$2"

    printf "\r\e[2K${COLOR_WHITE}%b${COLOR_RESET}" "$LOG_MESSAGE"

    if [[ "$COMPLETION_FLAG" == "DONE" || "$COMPLETION_FLAG" == "END" ]]; then
        echo ""
    fi
}

IS_INTERACTIVE()
{
    [[ -t 1 && -t 2 ]] && ! IS_GITHUB_ACTIONS
}
# ]
