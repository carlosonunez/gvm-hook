#!/usr/bin/env bash
export IN_LOCAL_GVM=false
export LOCAL_GVM_NAME=""
export LOCAL_GVM_DIRECTORY=""
export USING_DEFAULT_GVM=false
export LOCAL_GVM_VERSION=""
GVM_HOOK_CHECK_SENTINEL_FILE="$HOME/.config/gvm-hook/gvm_hook_installation_in_progress"
DEFAULT_GVM_FILE="$HOME/.config/gvm-hook/default_gvm"

trap 'rm -rf $GVM_HOOK_CHECK_SENTINEL_FILE' INT EXIT

gvm_hook_trigger_file() {
  if test -f "$PWD/.go_version"
  then
    echo "$PWD/.go_version"
  else
    echo "$PWD/.gvm_local"
  fi
}

create_lock_dir_if_needed() {
  dir="$(dirname "$GVM_HOOK_CHECK_SENTINEL_FILE")"
  test -d "$dir" || mkdir -p "$dir"
}

gvm_hook_check_mutex_lock() {
  printf "%s" $$ >> "$GVM_HOOK_CHECK_SENTINEL_FILE"
}

gvm_hook_check_mutex_unlock() {
  rm -f "$GVM_HOOK_CHECK_SENTINEL_FILE"
}

gvm_hook_is_locked() {
  random_wait_time=$(bc -l <<< "scale=4 ; ${RANDOM}/32767")
  sleep "$random_wait_time" && test -e "$GVM_HOOK_CHECK_SENTINEL_FILE"
}

in_subdir_of_local_gvm_dir() {
  test -z "$LOCAL_GVM_DIRECTORY" && return 1
  test "${PWD##"$LOCAL_GVM_DIRECTORY"}" != "$PWD"
}

gvm_trigger_file_in_pwd() {
  test -f "$(gvm_hook_trigger_file)"
}

capture_default_gvm_version() {
  basename "$GOROOT" > "$DEFAULT_GVM_FILE"
}

verify_gvm_installed() {
  ! test -z "$GVM_VERSION" &&
    grep -Eq '.gvm/gos' <<< "$GOROOT"
}

exit_gvm_hook() {
  gvm use "go$GOLANG_VERSION" >/dev/null
  disable_gvm_hook
  export LOCAL_GVM_NAME=""
}

default_version_found() {
  test -s "$DEFAULT_GVM_FILE"
}

already_using_default_version() {
  grep -Eiq '^true$' <<< "$USING_DEFAULT_GVM"
}

revert_to_default_version() {
  already_using_default_version && return 0

  export USING_DEFAULT_GVM=true
  gvm use "$(cat "$DEFAULT_GVM_FILE")"
}

gvm_use_statement() {
  tail -1 "$(gvm_hook_trigger_file)"
}

gvm_version_wanted() {
  awk -F ' ' '{print $NF}' <<< "$(gvm_use_statement)"
}

gvm_local_file_valid() {
  grep -Eq '^gvm use' <<< "$(gvm_use_statement)"
}

enable_gvm_hook() {
  export USING_DEFAULT_GVM=false
  # shellcheck disable=SC2155
  export LOCAL_GVM_VERSION="$(gvm_version_wanted)"
  # gvm doesn't deduplicate these variables, which can slow down shell performance over time
  # as you go in and out of repositories.
  # shellcheck disable=SC2155
  export LD_LIBRARY_PATH="$(tr ':' '\n' <<< "$LD_LIBRARY_PATH" | sort -u)"
  # shellcheck disable=SC2155
  export DYLD_LIBRARY_PATH="$(tr ':' '\n' <<< "$DYLD_LIBRARY_PATH" | sort -u)"
  # shellcheck disable=SC2155
  export PKG_CONFIG_PATH="$(tr ':' '\n' <<< "$PKG_CONFIG_PATH" | sort -u)"
}

disable_gvm_hook() {
  export LOCAL_GVM_VERSION=""
}

gvm_hook() {
  if ! verify_gvm_installed
  then
    >&2 echo "ERROR: gvm-hook needs gvm to work. Please install and load it \
before using gvm-hook."
    return 1
  fi

  create_lock_dir_if_needed
  if ! in_subdir_of_local_gvm_dir && ! gvm_trigger_file_in_pwd
  then
    capture_default_gvm_version
    default_version_found && revert_to_default_version
    exit_gvm_hook
    export LOCAL_GVM_DIRECTORY=""
    return 0
  fi

  in_subdir_of_local_gvm_dir && return 0
 
  if ! gvm_local_file_valid
  then
    >&2 echo "ERROR: A .gvm_local file was detected, but it does not end with a 'gvm use' \
statement. Please ensure that the last line of the file starts with \
'gvm use'."
    return 1
  fi

  if gvm_hook_is_locked
  then
    random_wait_time=$(bc -l <<< "scale=4 ; ${RANDOM}/32767")
    sleep "$random_wait_time"
    gvm_hook
  fi

  gvm_hook_check_mutex_lock
  # shellcheck disable=SC1090
  source "$(gvm_hook_trigger_file)" &&
    enable_gvm_hook || return 1

    test -z "$LOCAL_GVM_DIRECTORY" && export LOCAL_GVM_DIRECTORY="$PWD"
  gvm_hook_check_mutex_unlock
}

gvm_hook
grep -Eiq '^true$' <<< "$IN_LOCAL_GVM" && return 0
