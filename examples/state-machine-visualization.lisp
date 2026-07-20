;;; State-machine introspection and visualization.
;;;
;;; Run with:
;;;   sbcl --script examples/state-machine-visualization.lisp
(load
  (merge-pathnames
    #P"bootstrap.lisp"
    (make-pathname :name nil :type nil :defaults *load-truename*)))

;; An order lifecycle with a dead-end "cancelled" state and an unreachable
;; "archived" state that nothing transitions into.
(defparameter *machine*
  (cl-dataflow:make-state-machine
    :state "draft"
    :transitions (list
                   (cl-dataflow:make-transition "draft" "submit" "review")
                   (cl-dataflow:make-transition "review" "approve" "shipped")
                   (cl-dataflow:make-transition "review" "reject" "cancelled")
                   (cl-dataflow:make-transition "archived" "restore" "draft"))))

(format t "~&States: ~S~%" (cl-dataflow:state-machine-states *machine*))
(format t "~&Events: ~S~%" (cl-dataflow:state-machine-event-types *machine*))
(format t "~&Reachable from draft: ~S~%"
        (cl-dataflow:state-machine-reachable-states *machine*))
(format t "~&Unreachable states: ~S~%"
        (cl-dataflow:state-machine-unreachable-states *machine*))
(format t "~&Terminal states: ~S~%"
        (cl-dataflow:state-machine-terminal-states *machine*))
(format t "~&Deterministic? ~A~%"
        (cl-dataflow:state-machine-deterministic-p *machine*))

(format t "~&--- DOT ---~%~A" (cl-dataflow:state-machine->dot *machine* :name "order"))
(format t "~&--- Mermaid ---~%~A" (cl-dataflow:state-machine->mermaid *machine*))
