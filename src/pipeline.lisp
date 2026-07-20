(in-package #:cl-dataflow)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (dolist (name '("pipeline-macros.lisp"
                    "pipeline-runtime.lisp"))
    (%load-fragment name)))
