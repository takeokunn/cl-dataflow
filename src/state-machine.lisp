(in-package #:cl-dataflow)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (dolist (name '("state-machine-macros.lisp"
                    "state-machine-runtime-core.lisp"
                    "state-machine-runtime-cps.lisp"
                    "state-machine-runtime-api.lisp"))
    (%load-fragment name)))
