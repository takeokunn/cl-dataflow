(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("core-model-constructor-test.lisp"
                       "core-model-observability-test.lisp"
                       "core-model-internal-test.lisp"))
    (%load-fragment test-file)))
