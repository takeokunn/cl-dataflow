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
