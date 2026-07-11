(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("core-graph-test.lisp"
                       "core-model-test.lisp"
                       "core-runtime-test.lisp"))
    (%load-fragment test-file)))
