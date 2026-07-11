(in-package #:cl-dataflow.test)

(deftest define-pipeline-builds-a-graph-backed-pipeline
  (let* ((pipeline (define-pipeline (:metadata '((:kind :pipeline))
                                    :stages '("source" "sink"))
                     (:node "source"
                      :outputs '("value")
                      :handler (lambda (input context)
                                 (declare (ignore context))
                                 input))
                     (:node "sink"
                      :inputs '("value")
                      :handler (lambda (input context)
                                 (declare (ignore context))
                                 (1+ input)))
                     (:edge "source" "sink" :metadata '((:edge-kind :flow)))))
         (graph (pipeline-graph pipeline))
         (edges (graph-edges graph)))
    (is (equal (mapcar #'node-name (pipeline-stages pipeline))
               '("source" "sink")))
    (is (= (length edges) 1))
    (is (equal (edge-metadata (first edges))
               '((:edge-kind :flow))))))

(define-invalid-dsl-test define-pipeline-rejects-unknown-clauses-at-macroexpand-time
  (define-pipeline ()
    (:stage "source"))
  :stage
  "Unsupported DEFINE-PIPELINE clause")

(define-invalid-dsl-test define-pipeline-rejects-non-list-clauses-at-macroexpand-time
  (define-pipeline ()
    :node)
  :node
  "DEFINE-PIPELINE clauses must start with :NODE or :EDGE")

(define-invalid-dsl-test define-pipeline-rejects-non-plist-node-options-at-macroexpand-time
  (define-pipeline ()
    (:node "source" :handler))
  '(:handler)
  "DEFINE-PIPELINE node options must be a property list")

(define-invalid-dsl-option-test define-pipeline-rejects-invalid-top-level-options-at-macroexpand-time
  (define-pipeline (:history t)
    (:node "source"))
  :history
  "Unsupported DEFINE-PIPELINE option")

(define-invalid-dsl-test define-pipeline-rejects-non-plist-top-level-options-at-macroexpand-time
  (define-pipeline (:metadata)
    (:node "source"))
  '(:metadata)
  "DEFINE-PIPELINE options must be a property list")

(define-invalid-dsl-option-test define-pipeline-rejects-invalid-edge-options-at-macroexpand-time
  (define-pipeline ()
    (:edge "source" "sink" :handler #'identity))
  :handler
  "Unsupported DEFINE-PIPELINE edge option")

(deftest define-workflow-builds-machine-and-pipeline-from-unified-dsl
  (with-defined-workflow (pipeline machine)
      (define-workflow (:initial-state "idle"
                        :machine-metadata '((:kind :workflow))
                        :pipeline-metadata '((:layer :integration))
                        :stages '("source" "machine-step"))
        (:transition "idle" "start" "running"
         :metadata '((:transition :start)))
        (:node "source"
         :handler (lambda (input context)
                    (declare (ignore input context))
                    "start"))
        (:edge "source" "machine-step")
        (:machine-node :name "machine-step"))
    (is (equal (state-machine-state machine) "idle"))
    (is (equal (state-machine-metadata machine) '((:kind :workflow))))
    (is (equal (graph-metadata (pipeline-graph pipeline))
               '((:layer :integration))))
    (is (equal (mapcar #'node-name (pipeline-stages pipeline))
               '("source" "machine-step")))
    (is (equal (transition-metadata
                (first (state-machine-transitions machine)))
               '((:transition :start))))
    (with-workflow-context (context pipeline
                                    :input nil
                                    :state (state-machine-state machine))
      (assert-final-state context "running")
      (assert-pipeline-result context "running")
      (assert-state-machine-state machine "running"))))

(deftest define-workflow-resolves-machine-nodes-before-edges
  (with-defined-workflow (pipeline machine)
      (define-workflow (:initial-state "idle"
                        :stages '("source" "machine-step"))
        (:transition "idle" "start" "running")
        (:edge "source" "machine-step")
        (:machine-node :name "machine-step")
        (:node "source"
         :handler (lambda (input context)
                    (declare (ignore input context))
                    "start")))
    (with-workflow-context (context pipeline
                                    :input nil
                                    :state (state-machine-state machine))
      (assert-final-state context "running")
      (assert-pipeline-result context "running")
      (assert-state-machine-state machine "running"))))

(define-invalid-dsl-test define-workflow-rejects-unknown-clauses-at-macroexpand-time
  (define-workflow (:initial-state "idle")
    (:stage "source"))
  :stage
  "Unsupported DEFINE-WORKFLOW clause")

(define-invalid-dsl-test define-workflow-rejects-non-list-clauses-at-macroexpand-time
  (define-workflow (:initial-state "idle")
    :transition)
  :transition
  "DEFINE-WORKFLOW clauses must start with :TRANSITION, :NODE, :EDGE, or :MACHINE-NODE")

(define-invalid-dsl-test define-workflow-rejects-invalid-options-at-macroexpand-time
  (define-workflow (:initial-state "idle"
                    :metadata '((:mode :strict)))
    (:machine-node :name "machine-step"))
  :metadata
  "Unsupported DEFINE-WORKFLOW option")

(define-invalid-dsl-test define-workflow-rejects-non-plist-machine-node-options-at-macroexpand-time
  (define-workflow (:initial-state "idle")
    (:machine-node :name "machine-step" :metadata))
  '(:name "machine-step" :metadata)
  "DEFINE-WORKFLOW machine node options must be a property list")

(define-invalid-dsl-test define-workflow-rejects-non-plist-top-level-options-at-macroexpand-time
  (define-workflow (:initial-state "idle" :pipeline-metadata)
    (:machine-node :name "machine-step"))
  '(:initial-state "idle" :pipeline-metadata)
  "DEFINE-WORKFLOW options must be a property list")

(define-invalid-dsl-option-test define-workflow-rejects-invalid-transition-options-at-macroexpand-time
  (define-workflow (:initial-state "idle")
    (:transition "idle" "start" "running" :handler #'identity)
    (:machine-node :name "machine-step"))
  :handler
  "Unsupported DEFINE-WORKFLOW transition option")

(define-invalid-dsl-option-test define-workflow-rejects-invalid-edge-options-at-macroexpand-time
  (define-workflow (:initial-state "idle")
    (:node "source")
    (:machine-node :name "machine-step")
    (:edge "source" "machine-step" :handler #'identity))
  :handler
  "Unsupported DEFINE-PIPELINE edge option")

(define-invalid-dsl-option-test define-workflow-rejects-invalid-machine-node-options-at-macroexpand-time
  (define-workflow (:initial-state "idle")
    (:machine-node :name "machine-step" :handler #'identity))
  :handler
  "Unsupported DEFINE-WORKFLOW machine node option")
