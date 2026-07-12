(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("state-machine-dsl-test.lisp"
                       "state-machine-step-test.lisp"
                       "state-machine-run-test.lisp"
                       "state-machine-runtime-test.lisp"))
    (%load-fragment test-file)))
