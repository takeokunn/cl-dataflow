(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("state-machine-runtime-node-test.lisp"
                       "state-machine-runtime-state-test.lisp"))
    (%load-fragment test-file)))
