(in-package #:cl-dataflow.test)

(eval-when (:load-toplevel :execute)
  (dolist (test-file '("core-model-mutation-test.lisp"
                       "core-model-state-machine-test.lisp"
                       "core-model-node-edge-test.lisp"
                       "core-model-context-event-effect-test.lisp"))
    (%load-fragment test-file)))
