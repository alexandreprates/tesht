#!/usr/bin/env bash
# teSHT: a small functional test runner for Bash.
# Assertions are invoked by dynamically sourced files; traps call helpers indirectly.
# shellcheck disable=SC2317

function __tesht_location() {
  local __tesht_index
  for ((__tesht_index = 1; __tesht_index < ${#BASH_SOURCE[@]}; __tesht_index++)); do
    if [[ ${BASH_SOURCE[$__tesht_index]} != "${BASH_SOURCE[0]}" ]]; then
      printf '%s:%s' "${BASH_SOURCE[$__tesht_index]}" "${BASH_LINENO[$((__tesht_index - 1))]}"
      return
    fi
  done
  printf '%s' "$__TESHT_FILE"
}

function __tesht_pass() {
  __TESHT_PASSED=$((__TESHT_PASSED + 1))
  printf '.'
}

function __tesht_fail() {
  __TESHT_FAILED=$((__TESHT_FAILED + 1))
  printf '\nFAIL %s: %s\n' "$(__tesht_location)" "$1"
  if [[ $# -eq 3 ]]; then
    printf '  expected: %q\n  received: %q\n' "$2" "$3"
  fi
  if [[ -n $__TESHT_COMMAND ]]; then
    printf '  command: %s\n' "$__TESHT_COMMAND"
  fi
}

function __tesht_error() {
  __TESHT_ERRORS=$((__TESHT_ERRORS + 1))
  printf '\nERROR %s: %s\n' "$(__tesht_location)" "$1" >&2
}

function __tesht_arity() {
  if [[ $1 -ne $2 ]]; then
    __tesht_fail "${FUNCNAME[1]} expects $1 argument(s), received $2"
    return 1
  fi
}

function test() {
  if [[ $# -eq 0 ]]; then
    __tesht_error 'test requires a command'
    __TESHT_STATUS=
    return 0
  fi
  printf -v __TESHT_COMMAND '%q ' "$@"
  # A conditional captures failures even when the test file enables errexit.
  if "$@" > "$__TESHT_STDOUT" 2> "$__TESHT_STDERR"; then
    __TESHT_STATUS=0
  else
    __TESHT_STATUS=$?
  fi
  return 0
}

function assert_equal() {
  __tesht_arity 2 "$#" || return 0
  if [[ $1 == "$2" ]]; then __tesht_pass; else __tesht_fail 'values differ' "$1" "$2"; fi
}

function assert_not_equal() {
  __tesht_arity 2 "$#" || return 0
  if [[ $1 != "$2" ]]; then __tesht_pass; else __tesht_fail 'values must differ' "$1" "$2"; fi
}

function __tesht_match() {
  local __tesht_result
  if [[ $3 =~ $2 ]]; then __tesht_result=0; else __tesht_result=$?; fi
  if [[ $__tesht_result -eq 2 ]]; then
    __tesht_fail 'invalid regular expression' "$2" "$3"
  elif [[ $__tesht_result -eq $1 ]]; then
    __tesht_pass
  elif [[ $1 -eq 0 ]]; then
    __tesht_fail 'regular expression did not match' "$2" "$3"
  else
    __tesht_fail 'regular expression unexpectedly matched' "$2" "$3"
  fi
}

function assert_match() {
  __tesht_arity 2 "$#" || return 0
  __tesht_match 0 "$1" "$2"
}

function assert_not_match() {
  __tesht_arity 2 "$#" || return 0
  __tesht_match 1 "$1" "$2"
}

function __tesht_output() {
  local __tesht_comparator=$1 __tesht_stream=$2 __tesht_value
  shift 2
  __tesht_arity 1 "$#" || return 0
  if [[ -z $__TESHT_STATUS ]]; then
    __tesht_fail 'run test before asserting its output'
    return 0
  fi
  case $__tesht_comparator in
    *equal)
      # The sentinel prevents command substitution from removing trailing newlines.
      __tesht_value=$(cat -- "$__tesht_stream"; printf '.')
      __tesht_value=${__tesht_value%.}
      ;;
    *) __tesht_value=$(cat -- "$__tesht_stream") ;;
  esac
  "$__tesht_comparator" "$1" "$__tesht_value"
}

# Legacy output assertions keep their regex and trailing-newline semantics.
function assert_stdout() { __tesht_output assert_match "$__TESHT_STDOUT" "$@"; }
function assert_stderr() { __tesht_output assert_match "$__TESHT_STDERR" "$@"; }
function assert_not_stdout() { __tesht_output assert_not_match "$__TESHT_STDOUT" "$@"; }
function assert_not_stderr() { __tesht_output assert_not_match "$__TESHT_STDERR" "$@"; }
function assert_stdout_match() { assert_stdout "$@"; }
function assert_stderr_match() { assert_stderr "$@"; }
function assert_not_stdout_match() { assert_not_stdout "$@"; }
function assert_not_stderr_match() { assert_not_stderr "$@"; }
function assert_stdout_equal() { __tesht_output assert_equal "$__TESHT_STDOUT" "$@"; }
function assert_stderr_equal() { __tesht_output assert_equal "$__TESHT_STDERR" "$@"; }
function assert_not_stdout_equal() { __tesht_output assert_not_equal "$__TESHT_STDOUT" "$@"; }
function assert_not_stderr_equal() { __tesht_output assert_not_equal "$__TESHT_STDERR" "$@"; }

function assert_success() {
  __tesht_arity 0 "$#" || return 0
  if [[ $__TESHT_STATUS == 0 ]]; then
    __tesht_pass
  else
    __tesht_fail 'command did not succeed' 'exit status 0' "${__TESHT_STATUS:-no command executed}"
  fi
}

function assert_fail() {
  if [[ $# -gt 1 ]] || { [[ $# -eq 1 ]] && [[ ! $1 =~ ^[0-9]+$ || ${#1} -gt 3 ]] ; }; then
    __tesht_fail 'assert_fail expects an optional exit status from 1 to 255'
    return 0
  fi
  if [[ $# -eq 1 ]] && ((10#$1 < 1 || 10#$1 > 255)); then
    __tesht_fail 'assert_fail expects an optional exit status from 1 to 255'
  elif [[ -z $__TESHT_STATUS || $__TESHT_STATUS == 0 ]]; then
    __tesht_fail 'command did not fail' "${1:-nonzero exit status}" "${__TESHT_STATUS:-no command executed}"
  elif [[ $# -eq 0 ]] || ((__TESHT_STATUS == 10#$1)); then
    __tesht_pass
  else
    __tesht_fail 'unexpected exit status' "$1" "$__TESHT_STATUS"
  fi
}

function assert_dir() {
  __tesht_arity 1 "$#" || return 0
  if [[ -d $1 ]]; then __tesht_pass; else __tesht_fail 'directory does not exist' "$1" 'not a directory'; fi
}

function assert_file() {
  __tesht_arity 1 "$#" || return 0
  if [[ -f $1 ]]; then __tesht_pass; else __tesht_fail 'regular file does not exist' "$1" 'not a regular file'; fi
}

function __tesht_finish_file() {
  local __tesht_exit_status=$1
  # Test files may enable strict options; reporting must still finish.
  set +e +u
  if [[ $__TESHT_COMPLETED -eq 0 ]]; then
    __tesht_error "test file exited before completion (status $__tesht_exit_status)"
  fi
  if [[ $((__TESHT_PASSED + __TESHT_FAILED)) -eq 0 ]]; then
    __tesht_error 'test file executed no assertions'
  fi
  printf '\n'
  printf '%s %s %s\n' "$__TESHT_PASSED" "$__TESHT_FAILED" "$__TESHT_ERRORS" > "$__TESHT_RESULT"
}

# Each file gets isolated variables, functions, options, traps, and working directory.
function __tesht_run_file() (
  readonly __TESHT_FILE=$1 __TESHT_RESULT=$2/result
  readonly __TESHT_STDOUT=$2/stdout __TESHT_STDERR=$2/stderr
  # Public scratch space, removed together with all captures when the runner exits.
  readonly TESHT_TMPDIR=$2/work
  __TESHT_PASSED=0 __TESHT_FAILED=0 __TESHT_ERRORS=0
  __TESHT_STATUS='' __TESHT_COMMAND='' __TESHT_COMPLETED=0
  trap '__tesht_finish_file "$?"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  trap '__tesht_error "unexpected command failure (status $?): $BASH_COMMAND"' ERR
  set -eE
  mkdir -p -- "$TESHT_TMPDIR" || exit 1
  : > "$__TESHT_STDOUT"
  : > "$__TESHT_STDERR"
  printf '\nRunning %s\n' "$__TESHT_FILE"
  # shellcheck disable=SC1090
  source "$__TESHT_FILE"
  __tesht_source_status=$?
  if [[ $__tesht_source_status -ne 0 ]]; then
    __tesht_error "test file returned status $__tesht_source_status"
  fi
  __TESHT_COMPLETED=1
)

function __tesht_usage() {
  printf "Usage: %s [--] FILE_OR_GLOB...\nExample: %s 'tests/*.tsh'\n" "${0##*/}" "${0##*/}"
}

function __tesht_main() {
  local __tesht_argument __tesht_file __tesht_index=0 __tesht_invalid=0
  local __tesht_files=() __tesht_matches=()
  local __tesht_passed=0 __tesht_failed=0 __tesht_errors=0 __tesht_failed_files=0
  local __tesht_file_passed __tesht_file_failed __tesht_file_errors __tesht_status
  local __tesht_temp_root
  if [[ ${1:-} == --help ]]; then __tesht_usage; return 0; fi
  if [[ ${1:-} == -- ]]; then shift; fi
  if [[ $# -eq 0 ]]; then __tesht_usage >&2; return 2; fi
  shopt -s nullglob
  shopt -u failglob
  for __tesht_argument in "$@"; do
    if [[ -e $__tesht_argument ]]; then
      __tesht_matches=("$__tesht_argument")
    else
      # Disable word splitting while deliberately expanding the supplied glob.
      local IFS=''
      # shellcheck disable=SC2206
      __tesht_matches=($__tesht_argument)
      unset IFS
    fi
    if [[ ${#__tesht_matches[@]} -eq 0 ]]; then
      printf 'ERROR: no test files match %q\n' "$__tesht_argument" >&2
      __tesht_invalid=1
    fi
    for __tesht_file in "${__tesht_matches[@]}"; do
      if [[ ! -f $__tesht_file || ! -r $__tesht_file ]]; then
        printf 'ERROR: test file is not a readable regular file: %q\n' "$__tesht_file" >&2
        __tesht_invalid=1
        continue
      fi
      [[ $__tesht_file == /* ]] || __tesht_file=$PWD/$__tesht_file
      if ! "$BASH" -n -- "$__tesht_file"; then
        printf 'ERROR: invalid Bash syntax in %q\n' "$__tesht_file" >&2
        __tesht_invalid=1
      fi
      __tesht_files+=("$__tesht_file")
    done
  done
  [[ $__tesht_invalid -eq 0 ]] || return 2
  shopt -u nullglob
  __tesht_temp_root=${TMPDIR:-/tmp}
  [[ $__tesht_temp_root == /* ]] || __tesht_temp_root=$PWD/$__tesht_temp_root
  __TESHT_TEMP_DIR=$(mktemp -d "$__tesht_temp_root/tesht.XXXXXXXX") || return 2
  readonly __TESHT_TEMP_DIR
  trap 'rm -rf -- "$__TESHT_TEMP_DIR"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  printf 'Loading teSHT\n'
  for __tesht_file in "${__tesht_files[@]}"; do
    __tesht_index=$((__tesht_index + 1))
    __tesht_run_file "$__tesht_file" "$__TESHT_TEMP_DIR/$__tesht_index"
    __tesht_status=$?
    if read -r __tesht_file_passed __tesht_file_failed __tesht_file_errors < "$__TESHT_TEMP_DIR/$__tesht_index/result"; then
      __tesht_passed=$((__tesht_passed + __tesht_file_passed))
      __tesht_failed=$((__tesht_failed + __tesht_file_failed))
      __tesht_errors=$((__tesht_errors + __tesht_file_errors))
      if [[ $__tesht_file_failed -gt 0 || $__tesht_file_errors -gt 0 || $__tesht_status -ne 0 ]]; then
        __tesht_failed_files=$((__tesht_failed_files + 1))
      fi
    else
      printf 'ERROR: test file did not produce a result: %s\n' "$__tesht_file" >&2
      __tesht_errors=$((__tesht_errors + 1))
      __tesht_failed_files=$((__tesht_failed_files + 1))
    fi
  done
  printf '\nSummary: %s files, %s failed; %s assertions, %s passed, %s failed; %s errors.\n' \
    "${#__tesht_files[@]}" "$__tesht_failed_files" "$((__tesht_passed + __tesht_failed))" \
    "$__tesht_passed" "$__tesht_failed" "$__tesht_errors"
  [[ $__tesht_failed_files -eq 0 ]]
}

# Assertion failures are recorded rather than relying on shell errexit.
set +e +u
__tesht_main "$@"
exit $?
