(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("pipeline-runtime-structure-test.lisp"
                       "pipeline-runtime-execution-test.lisp"
                       "pipeline-runtime-branching-test.lisp"))
    (%load-fragment test-file)))
