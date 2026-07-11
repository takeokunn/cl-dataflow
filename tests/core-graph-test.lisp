(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("core-graph-structure-test.lisp"
                       "core-graph-api-test.lisp"))
    (%load-fragment test-file)))
