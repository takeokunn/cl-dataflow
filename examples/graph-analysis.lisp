;;; Reachability analysis over a dataflow graph.
;;;
;;; Run with:
;;;   sbcl --script examples/graph-analysis.lisp
(load
  (merge-pathnames
    #P"bootstrap.lisp"
    (make-pathname :name nil :type nil :defaults *load-truename*)))

;; A small ingestion pipeline modelled as a dependency graph:
;;
;;   ingest -> parse -> validate -> transform -> load
;;                  \        \-> audit
;;                   \-> metrics
(defparameter *graph* (cl-dataflow:make-graph))

(dolist (name '("ingest" "parse" "validate" "metrics" "transform" "audit" "load"))
  (cl-dataflow:add-node *graph* (cl-dataflow:make-node name)))

(dolist (edge '(("ingest" "parse")
                ("parse" "validate")
                ("parse" "metrics")
                ("validate" "transform")
                ("validate" "audit")
                ("transform" "load")))
  (cl-dataflow:add-edge *graph* (first edge) (second edge)))

(defun names (nodes)
  (mapcar #'cl-dataflow:node-name nodes))

;; Impact analysis: everything downstream of "parse".
(format t "~&Downstream of parse (impact): ~S~%"
        (names (cl-dataflow:graph-descendants *graph* "parse")))

;; Dependency analysis: everything "load" depends on.
(format t "~&Upstream of load (dependencies): ~S~%"
        (names (cl-dataflow:graph-ancestors *graph* "load")))

;; A concrete shortest dataflow path from source to sink.
(format t "~&Shortest path ingest -> load: ~S~%"
        (cl-dataflow:graph-path *graph* "ingest" "load"))

;; A branch that never feeds the loader.
(format t "~&metrics reaches load? ~A~%"
        (cl-dataflow:graph-reachable-p *graph* "metrics" "load"))

;; Structural boundaries.
(format t "~&Sources: ~S  Sinks: ~S~%"
        (names (cl-dataflow:graph-source-nodes *graph*))
        (names (cl-dataflow:graph-sink-nodes *graph*)))
