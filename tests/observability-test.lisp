(in-package #:cl-dataflow.test)

(deftest pipeline-introspection-reports-structure
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c)))
    (let ((pipeline (make-pipeline :graph graph)))
      (is (equal (pipeline-node-names pipeline) '("a" "b" "c")))
      (is (equal (pipeline-stage-names pipeline) '("a" "b" "c")))
      (is (equal (pipeline-source-names pipeline) '("a")))
      (is (equal (pipeline-sink-names pipeline) '("c")))
      (is (search "digraph flow {" (pipeline->dot pipeline :name "flow")))
      (is (search "flowchart LR" (pipeline->mermaid pipeline :direction "LR"))))))

(defun %observability-workflow-context ()
  "Run a one-node pipeline whose handler emits an event, performs an effect, and
steps a state machine so the resulting context's trace holds all four entry kinds."
  (let* ((machine (make-state-machine
                   :state "idle"
                   :transitions (list (make-transition "idle" "go" "running"))))
         (handlers (make-test-effect-handlers
                    "log" (lambda (effect context)
                            (declare (ignore effect context))
                            :logged)))
         (context (make-context :effect-handlers handlers))
         (graph (make-graph)))
    (add-node graph
              (make-node "worker"
                         :handler (lambda (input context)
                                    (emit-event context "started")
                                    (perform-effect context "log")
                                    (step-state-machine machine "go" :context context)
                                    input)))
    (run-pipeline (make-pipeline :graph graph) :input 1 :context context)
    context))

(deftest trace-summary-counts-every-entry-kind
  (let ((summary (trace-summary (%observability-workflow-context))))
    (assert-plist-entry summary
                        (:total 4) (:nodes 1) (:events 1) (:effects 1) (:transitions 1))))

(deftest format-trace-renders-each-entry-kind
  (let ((text (format-trace (%observability-workflow-context))))
    (is (search "event started" text))
    (is (search "effect log" text))
    (is (search "transition idle --go--> running" text))
    (is (search "node worker" text))
    ;; Entries are numbered chronologically from zero.
    (is (search "0. " text))))

(deftest format-trace-of-empty-context-is-blank
  (is (string= (format-trace (make-context)) "")))

(deftest context-summary-rolls-up-context-state
  (let ((summary (context-summary (%observability-workflow-context))))
    (assert-plist-entry summary (:events 1) (:effects 1) (:trace 4))
    (is (>= (getf summary :values) 1))))
