#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

run_sbcl() {
  if command -v sbcl >/dev/null 2>&1; then
    run_with_timeout "${VERIFY_TIMEOUT_SECONDS:-120}" sbcl "$@"
    return
  fi

  if command -v nix >/dev/null 2>&1; then
    run_with_timeout "${VERIFY_TIMEOUT_SECONDS:-120}" nix run nixpkgs#sbcl -- "$@"
    return
  fi

  printf '%s\n' "sbcl is required but was not found on PATH." >&2
  exit 1
}

run_with_timeout() {
  seconds=$1
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
    return
  fi

  perl -MPOSIX=:sys_wait_h -e 'my $seconds = shift @ARGV;
           my $pid = fork();
           die "fork failed: $!" unless defined $pid;
           if ($pid == 0) {
             POSIX::setpgid(0, 0) or die "setpgid failed: $!";
             exec @ARGV or die "exec failed: $!";
           }

           my $deadline = time + $seconds;
           while (1) {
             my $done = waitpid($pid, WNOHANG);
             if ($done == $pid) {
               exit(($? >> 8) || (($? & 127) ? 128 + ($? & 127) : 0));
             }
             if (time >= $deadline) {
               kill "TERM", -$pid;
               sleep 2;
               $done = waitpid($pid, WNOHANG);
               if ($done != $pid) {
                 kill "KILL", -$pid;
                 waitpid($pid, 0);
               }
               exit 124;
             }
             select undef, undef, undef, 0.1;
           }' "$seconds" "$@"
}

run_step() {
  printf '%s\n' "$1"
  shift
  "$@"
}

load_test_forms='(dolist (file (list #P"src/package.lisp" #P"src/core.lisp" #P"src/protocols.lisp" #P"src/events.lisp" #P"src/effects.lisp" #P"src/state-machine.lisp" #P"src/pipeline.lisp" #P"src/testing.lisp" #P"tests/package.lisp" #P"tests/core-test.lisp" #P"tests/events-test.lisp" #P"tests/state-machine-test.lisp" #P"tests/effects-test.lisp" #P"tests/pipeline-test.lisp")) (load file))'

test_count=$(
  run_sbcl --noinform --disable-debugger \
    --eval '(require :asdf)' \
    --eval '(setf sb-ext:*evaluator-mode* :interpret)' \
    --eval "$load_test_forms" \
    --eval '(format t "~D~%" (length cl-dataflow.test::*tests*))' \
    --eval '(sb-ext:quit)'
)

run_test_chunk() {
  start=$1
  end=$2
  run_sbcl --noinform --disable-debugger \
    --eval '(require :asdf)' \
    --eval '(setf sb-ext:*evaluator-mode* :interpret)' \
    --eval "$load_test_forms" \
    --eval "(cl-dataflow.test:run-tests :start $start :end $end)" \
    --eval '(sb-ext:quit)'
}

run_step 'Running test suite...' printf 'Found %s test(s).\n' "$test_count"
chunk_size=${VERIFY_TEST_CHUNK_SIZE:-1}
start=0
while [ "$start" -lt "$test_count" ]; do
  end=$((start + chunk_size))
  if [ "$end" -gt "$test_count" ]; then
    end=$test_count
  fi
  run_step "Running tests $((start + 1))-$end..." run_test_chunk "$start" "$end"
  start=$end
done

run_step 'Running example: simple-pipeline.lisp' run_sbcl --disable-debugger --script examples/simple-pipeline.lisp
run_step 'Running example: event-workflow.lisp' run_sbcl --disable-debugger --script examples/event-workflow.lisp
run_step 'Running example: state-machine.lisp' run_sbcl --disable-debugger --script examples/state-machine.lisp
