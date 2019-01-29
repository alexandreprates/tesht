#!/usr/bin/env bash
# Tesht is a microframework to help you to test your bash scripts!
# by Alexandre Prates Oct/2017

# set -x

echo -e "Loading Tesht\n"

function __uuid() {
  if [ -f /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  elif [ -x "$(command -v uuidgen)" ]; then
    uuidgen
  else
    echo Cannot generate UUID!
    exit 1
  fi
}

BROKEN=

function setup() {
  pushd . > /dev/null
  TESTFAILED=
  FAILLOG=/tmp/$(__uuid)
  STDOUT=/tmp/$(__uuid)
  STDERR=/tmp/$(__uuid)
  RETURNCODE=
  COMMAND=
}

function __success() {
  printf "."
}

function __fail() {
  TESTFAILED=true
  BROKEN=true
  MESSAGE="IN ${FUNCNAME[*]: -3:1}:${BASH_LINENO[*]: -3:1}\n"

  if [ $# -eq 0 ]; then
    MESSAGE="$MESSAGE Command: \"$COMMAND\"\n"
    MESSAGE="$MESSAGE \"$(cat $STDERR | cut -d: -f 3-)\""
  else
    MESSAGE="$MESSAGE $1"
  fi
  echo "$MESSAGE" >> $FAILLOG
  printf "f"
}

function test() {
  $@ 1>$STDOUT 2>$STDERR
  RETURNCODE=$?
  COMMAND=$@
}

function assert_equal() {
  if [[ $1 == $2 ]]; then
    __success
  else
    local MESSAGE=$"EXPECTED: \"$1\" \n GOT: \"$2\""
    __fail "$MESSAGE"
  fi
}

function assert_match() {
  if [[ $2 =~ $1 ]]; then
    __success
  else
    local MESSAGE=$"Not match: \"$1\"\n IN: \"$2\""
    __fail "$MESSAGE"
  fi
}

function assert_not_equal() {
  if [[ ! $1 == $2 ]]; then
    __success
  else
    local MESSAGE=$"EXPECTED: \"$1\"\n GOT: \"$2\""
    __fail "$MESSAGE"
  fi
}

function assert_not_match() {
  if [[ ! $2 =~ $1 ]]; then
    __success
  else
    local MESSAGE=$"Not match: \"$1\"\n IN: \"$2\""
    __fail "$MESSAGE"
  fi
}

function assert_stdout() {
  local MESSAGE="`cat $STDOUT`"
  assert_match "$@" "$MESSAGE"
}

function assert_stderr() {
  local MESSAGE=$(cat $STDERR)
  assert_match "$@" "$MESSAGE"
}

function assert_not_stdout() {
  local MESSAGE=$(cat $STDOUT)
  assert_not_match "$@" "$MESSAGE"
}

function assert_not_stderr() {
  local MESSAGE=$(cat $STDERR)
  assert_not_match "$@" "$MESSAGE"
}

function assert_success() {
  [ 0 -eq $RETURNCODE ] && __success || __fail
}

function assert_fail() {
  if [ $# -eq 0 ]; then
    [ $RETURNCODE -ne 0 ] && __success || __fail "Received code $RETURNCODE"
  else
    [ $RETURNCODE -eq $1 ] && __success || __fail "Expect code $1\n Received code $RETURNCODE"
  fi
}

function assert_dir() {
  [[ -d $1 ]] && __success || __fail "Dir '$1' does not exists."
}

function assert_file() {
  [[ -e $1 ]] && __success || __fail "File '$1' does not exists."
}

function report() {
  popd > /dev/null
  echo ""
  if [ $TESTFAILED ]; then
    echo -e "$(cat $FAILLOG)"
  fi
  echo ""
}

for TESTFILE in $@ ; do
  setup
  echo "Running $TESTFILE"
  source $TESTFILE
  report
done

if [ $BROKEN ]; then
  echo "Sorry something is broken"
  exit 1
else
  echo "Congratulations everthing is right!"
  exit 0
fi
