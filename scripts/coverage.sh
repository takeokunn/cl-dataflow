#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

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

run_sbcl() {
  if command -v sbcl >/dev/null 2>&1; then
    run_with_timeout "${COVERAGE_TIMEOUT_SECONDS:-600}" sbcl "$@"
    return
  fi

  if command -v nix >/dev/null 2>&1; then
    run_with_timeout "${COVERAGE_TIMEOUT_SECONDS:-600}" nix run nixpkgs#sbcl -- "$@"
    return
  fi

  printf '%s\n' "sbcl is required but was not found on PATH." >&2
  exit 1
}

run_step() {
  printf '%s\n' "$1"
  shift
  "$@"
}

REPORT_DIR=${COVERAGE_REPORT_DIR:-coverage/sb-cover}
DATA_DIR=${COVERAGE_DATA_DIR:-coverage/sb-cover-data}
SOURCE_ROOT=$ROOT/src/
TEST_CHUNK_SIZE=${COVERAGE_TEST_CHUNK_SIZE:-1}
load_test_forms='(dolist (file (list #P"src/package.lisp" #P"src/core.lisp" #P"src/protocols.lisp" #P"src/events.lisp" #P"src/effects.lisp" #P"src/state-machine.lisp" #P"src/pipeline.lisp" #P"src/testing.lisp" #P"tests/package.lisp" #P"tests/core-test.lisp" #P"tests/events-test.lisp" #P"tests/effects-test.lisp" #P"tests/state-machine-test.lisp" #P"tests/pipeline-test.lisp")) (load file))'
precompile_forms='(labels ((compile-and-load (file)
                             (format t "[coverage] precompile ~A~%" file)
                             (finish-output)
                             (multiple-value-bind (fasl warnings-p failure-p)
                                 (compile-file file)
                               (declare (ignore warnings-p failure-p))
                               (load fasl)
                               (format t "[coverage] loaded ~A~%" file)
                               (finish-output)))
                           (compile-and-load-list (files)
                             (dolist (file files)
                               (compile-and-load file))))
                      (compile-and-load #P"src/package.lisp")
                      (compile-and-load-list (list
                                              #P"src/core-normalization.lisp"
                                              #P"src/core-copying.lisp"
                                              #P"src/core-slot-accessors.lisp"
                                              #P"src/core-runtime-helpers.lisp"
                                              #P"src/core-conditions.lisp"
                                              #P"src/core-models-classes.lisp"
                                              #P"src/core-models-copying.lisp"
                                              #P"src/core-models-slot-accessors.lisp"
                                              #P"src/core-models-constructors.lisp"
                                              #P"src/core-context-accessors.lisp"
                                              #P"src/graph-runtime-validation.lisp"
                                              #P"src/graph-runtime-topology.lisp"
                                              #P"src/graph-runtime-bindings.lisp"
                                              #P"src/graph-runtime-builders.lisp"
                                              #P"src/protocols.lisp"
                                              #P"src/events.lisp"
                                              #P"src/effects.lisp"
                                              #P"src/pipeline-macros.lisp"
                                              #P"src/pipeline-runtime.lisp"
                                              #P"src/state-machine-macros.lisp"
                                              #P"src/state-machine-runtime-core.lisp"
                                              #P"src/state-machine-runtime-cps.lisp"
                                              #P"src/state-machine-runtime-api.lisp"
                                              #P"src/testing.lisp"))
                      (compile-and-load-list (list
                                              #P"src/core.lisp"
                                              #P"src/core-models.lisp"
                                              #P"src/graph-runtime.lisp"
                                              #P"src/pipeline.lisp"
                                              #P"src/state-machine.lisp"))
                      (compile-and-load #P"tests/package.lisp")
                      (compile-and-load-list (list
                                              #P"tests/test-support-assertions.lisp"
                                              #P"tests/test-support-fixtures.lisp"
                                              #P"tests/test-runner.lisp"))
                      (compile-and-load-list (list
                                              #P"tests/core-graph-test.lisp"
                                              #P"tests/core-model-context-event-effect-test.lisp"
                                              #P"tests/core-model-internal-test.lisp"
                                              #P"tests/core-model-mutation-test.lisp"
                                              #P"tests/core-model-node-edge-test.lisp"
                                              #P"tests/core-model-observability-test.lisp"
                                              #P"tests/core-model-state-machine-test.lisp"
                                              #P"tests/core-runtime-example-test.lisp"
                                              #P"tests/core-runtime-graph-test.lisp"
                                              #P"tests/core-runtime-protocol-test.lisp"
                                              #P"tests/effects-test.lisp"
                                              #P"tests/events-test.lisp"
                                              #P"tests/pipeline-dsl-test.lisp"
                                              #P"tests/pipeline-runtime-branching-test.lisp"
                                              #P"tests/pipeline-runtime-contract-test.lisp"
                                              #P"tests/pipeline-runtime-execution-test.lisp"
                                              #P"tests/pipeline-runtime-structure-test.lisp"
                                              #P"tests/state-machine-dsl-test.lisp"
                                              #P"tests/state-machine-runtime-test.lisp"
                                              #P"tests/state-machine-step-test.lisp"))
                      (compile-and-load-list (list
                                              #P"tests/core-test.lisp"
                                              #P"tests/core-runtime-test.lisp"
                                              #P"tests/core-model-test.lisp"
                                              #P"tests/core-model-constructor-test.lisp"
                                              #P"tests/pipeline-test.lisp"
                                              #P"tests/pipeline-runtime-test.lisp"
                                              #P"tests/state-machine-test.lisp")))'

run_step "Precompiling coverage inputs ..." run_sbcl --noinform --disable-debugger \
  --eval '(require :sb-cover)' \
  --eval '(declaim (optimize (sb-cover:store-coverage-data 3)))' \
  --eval "$precompile_forms" \
  --eval '(sb-ext:exit :code 0)'

test_count_output=$(run_sbcl --noinform --disable-debugger \
  --eval '(require :sb-cover)' \
  --eval '(declaim (optimize (sb-cover:store-coverage-data 3)))' \
  --eval "$load_test_forms" \
  --eval '(format t "~&__TEST_COUNT__=~D~%" (length cl-dataflow.test::*tests*))' \
  --eval '(sb-ext:exit :code 0)')

TEST_COUNT=$(printf '%s\n' "$test_count_output" | perl -ne 'print "$1\n" if /__TEST_COUNT__=(\d+)/')

case ${TEST_COUNT:-} in
  ''|*[!0-9]*)
    printf '%s\n' "Failed to determine test count from SBCL output." >&2
    printf '%s\n' "$test_count_output" >&2
    exit 1
    ;;
esac

rm -rf "$REPORT_DIR"
rm -rf "$DATA_DIR"
mkdir -p "$REPORT_DIR" "$DATA_DIR"

start=0
chunk_index=0
merge_coverage_forms='(progn (sb-cover:clear-coverage)'

while [ "$start" -lt "$TEST_COUNT" ]; do
  end=$((start + TEST_CHUNK_SIZE))
  if [ "$end" -gt "$TEST_COUNT" ]; then
    end=$TEST_COUNT
  fi

  coverage_file=$(printf '%s/chunk-%03d.coverage' "$DATA_DIR" "$chunk_index")
  run_test_forms="(progn
                     (format t \"[coverage] running tests $start..$end~%\")
                     (finish-output)
                     (cl-dataflow.test:run-tests :start $start :end $end)
                     (sb-cover:save-coverage-in-file #P\"$coverage_file\")
                     (format t \"[coverage] saved $coverage_file~%\")
                     (finish-output))"

  run_step "Running coverage chunk $chunk_index ($start..$end) ..." run_sbcl --noinform --disable-debugger \
    --eval '(require :sb-cover)' \
    --eval '(declaim (optimize (sb-cover:store-coverage-data 3)))' \
    --eval '(sb-cover:clear-coverage)' \
    --eval "$load_test_forms" \
    --eval "$run_test_forms" \
    --eval '(sb-ext:exit :code 0)'

  merge_coverage_forms="$merge_coverage_forms (sb-cover:merge-coverage-from-file #P\"$coverage_file\")"
  start=$end
  chunk_index=$((chunk_index + 1))
done

merge_coverage_forms="$merge_coverage_forms
  (let ((report-path #P\"$REPORT_DIR/\")
        (root \"$SOURCE_ROOT\"))
    (format t \"[coverage] starting sb-cover report~%\")
    (finish-output)
    (ensure-directories-exist report-path)
    (sb-cover:report report-path
                     :if-matches (lambda (namestring)
                                   (search root namestring :test #'char-equal)))
    (format t \"[coverage] finished sb-cover report~%\")
    (finish-output)))"

run_step "Running coverage report into $REPORT_DIR ..." run_sbcl --noinform --disable-debugger \
  --eval '(require :sb-cover)' \
  --eval '(declaim (optimize (sb-cover:store-coverage-data 3)))' \
  --eval "$load_test_forms" \
  --eval "$merge_coverage_forms" \
  --eval '(sb-ext:exit :code 0)'
