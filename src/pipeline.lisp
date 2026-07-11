(in-package #:cl-dataflow)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (%load-fragment #P"core-runtime.lisp")
  (%load-fragment #P"state-machine.lisp")
  (%load-fragment #P"graph-runtime.lisp")
  (dolist (name '("pipeline-macros.lisp"
                    "pipeline-runtime.lisp"))
    (%load-fragment name)))
