(in-package #:cl-dataflow.test)

(deftest
  pipeline-copies-mutable-node-results-into-context-and-trace
  (let* ((payload (list 1 2))
          (stage
        (make-node
          "source"
          :outputs
          '("items")
          :handler
          (lambda (input context)
            (declare (ignore input context))
            payload)))
          (pipeline (make-pipeline :stages (list stage)))
          (context (run-pipeline-with-test-context pipeline :input nil)))
    (setf (cadr payload) 3)
    (is (equal (context-value context "source" "items") '(1 2)))
    (assert-context-first-trace-entry context (:output '(("items" . (1 2)))))))

(deftest
  pipeline-plan-preserves-newest-producer-wins
  (let* ((graph (make-graph))
          (older
        (make-node
          "older"
          :outputs
          (list "value")
          :handler
          (lambda (input context)
            (declare (ignore input context))
            1)))
          (newer
        (make-node
          "newer"
          :outputs
          (list "value")
          :handler
          (lambda (input context)
            (declare (ignore input context))
            2)))
          (sink
        (make-node
          "sink"
          :inputs
          (list "value")
          :outputs
          (list "value")
          :handler
          (lambda (input context)
            (declare (ignore context))
            input))))
    (dolist (node (list older newer sink))
      (add-node graph node))
    (add-edge graph older sink)
    (add-edge graph newer sink)
    (is (= (run-pipeline (make-pipeline :graph graph)) 2))))

(deftest
  pipeline-interleaves-node-event-and-effect-trace-indices
  (let (emitted
        performed)
    (with-effect-handlers
      (handlers
        "audit"
        (lambda (effect context)
          (declare (ignore effect context))
          :handled))
      (let* ((source
            (make-node
              "source"
              :outputs
              (list "value")
              :handler
              (lambda (input context)
                (declare (ignore input context))
                :value)))
              (sink
            (make-node
              "sink"
              :inputs
              (list "value")
              :outputs
              (list "result")
              :handler
              (lambda (input context)
                (declare (ignore input))
                (setf emitted (emit-event context "observed"))
                (setf performed (perform-effect context "audit"))
                :done)))
              (pipeline (make-pipeline :stages (list source sink)))
              (context (make-context :effect-handlers handlers)))
        (run-pipeline pipeline :context context)
        (let ((trace (context-trace-in-order context)))
          (is
            (equal
              (mapcar (function cl-dataflow::%trace-entry-kind) trace)
              (quote (:node :event :effect :node))))
          (is (= (event-trace-index emitted) 1))
          (is (= (effect-trace-index performed) 2))
          (is (= (getf (second trace) :trace-index) 1))
          (is (= (getf (third trace) :trace-index) 2))
          (is (= (cl-dataflow::%context-trace-count context) 4))
          (is (= (length (cl-dataflow::%context-trace-list context)) 4)))
        (run-pipeline pipeline :context context)
        (is (= (event-trace-index emitted) 5))
        (is (= (effect-trace-index performed) 6))
        (is (= (cl-dataflow::%context-trace-count context) 8))
        (is (= (length (cl-dataflow::%context-trace-list context)) 8))))))

(deftest
  pipeline-runs-deep-stage-order-without-cps-continuations
  (let* ((stage-count 2000)
          (seen nil)
          (stages
        (loop for index below stage-count
              collect (let ((captured-index index))
            (make-node
              (format nil "stage-~D" captured-index)
              :handler
              (lambda (input context)
                (declare (ignore input context))
                (push captured-index seen))))))
          (pipeline (make-pipeline :stages stages)))
    (run-pipeline pipeline)
    (is
      (equal
        (nreverse seen)
        (loop for index below stage-count
              collect index)))))

(deftest
  pipeline-error-skips-later-stages-and-finalization
  (let* ((seen nil)
          (context (make-context :result :not-finalized))
          (first
        (make-node
          "first"
          :handler
          (lambda (input context)
            (declare (ignore input context))
            (push :first seen))))
          (failing
        (make-node
          "failing"
          :handler
          (lambda (input context)
            (declare (ignore input context))
            (push :failing seen)
            (error "expected failure"))))
          (later
        (make-node
          "later"
          :handler
          (lambda (input context)
            (declare (ignore input context))
            (push :later seen))))
          (pipeline (make-pipeline :stages (list first failing later))))
    (signals simple-error (run-pipeline pipeline :context context))
    (is (equal (nreverse seen) (quote (:first :failing))))
    (is (eq (context-result context) :not-finalized))
    (is (= (length (context-trace-in-order context)) 1))))
