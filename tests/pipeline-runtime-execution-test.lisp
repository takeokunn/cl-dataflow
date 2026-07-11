(in-package #:cl-dataflow.test)

(deftest pipeline-copies-mutable-node-results-into-context-and-trace
  (let* ((payload (list 1 2))
         (stage (make-node "source"
                           :outputs '("items")
                           :handler (lambda (input context)
                                      (declare (ignore input context))
                                      payload)))
         (pipeline (make-pipeline :stages (list stage)))
         (context (run-pipeline-with-test-context pipeline :input nil)))
    (setf (cadr payload) 3)
    (is (equal (context-value context "source" "items") '(1 2)))
    (assert-context-first-trace-entry context
      (:output '(("items" . (1 2)))))))
