(in-package #:cl-dataflow)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (%load-fragment #P"core-runtime.lisp")
  (dolist (name '("state-machine-macros.lisp"
                    "state-machine-runtime-core.lisp"
                    "state-machine-runtime-cps.lisp"
                    "state-machine-runtime-api.lisp"))
    (%load-fragment name)))
