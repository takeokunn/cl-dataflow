(in-package #:cl-dataflow.test)

(deftest run-pipeline-with-test-context-seeds-runtime-context
  (with-effect-handlers (effect-handlers
                         "audit" (lambda (effect context)
                                   (declare (ignore context))
                                   (list :audited (effect-payload effect))))
    (let* ((stage (make-node "stage"
                             :handler (lambda (input context)
                                        (declare (ignore input))
                                        (perform-effect context "audit" :payload '(:message "ok"))
                                        (list :state (context-state context)
                                              :metadata (context-metadata context)))))
           (context (run-pipeline-with-test-context
                     (make-pipeline :stages (list stage))
                     :input nil
                     :effect-handlers effect-handlers
                     :state "ready"
                     :metadata '((:suite :pipeline)))))
      (is (equal (context-state context) "ready"))
      (is (equal (context-metadata context) '((:suite :pipeline))))
      (is (equal (context-result context)
                 '(:state "ready" :metadata ((:suite :pipeline)))))
      (assert-performed-effects context "audit")
      (is (equal (effect-result (first (context-effects context)))
                 '(:audited (:message "ok")))))))

(deftest run-pipeline-with-test-context-builds-a-default-runtime-context
  (let* ((stage (make-node "stage"
                           :handler (lambda (input context)
                                      (declare (ignore input))
                                      (list :state (context-state context)
                                            :metadata (context-metadata context)
                                            :handlers (context-effect-handlers context)))))
         (context (run-pipeline-with-test-context
                   (make-pipeline :stages (list stage))
                   :input nil)))
    (is (null (context-state context)))
    (is (null (context-metadata context)))
    (assert-hash-table-count (context-effect-handlers context) 0)
    (let ((result (context-result context)))
      (assert-plist-entry result
        (:state nil)
        (:metadata nil))
      (assert-plist-hash-table-count result :handlers 0))))

(deftest testing-helpers-accept-singleton-expectations
  (let* ((machine (make-state-machine
                   :state "idle"
                   :transitions (list (make-transition "idle" "advance" "done")))))
    (with-effect-handlers (effect-handlers
                           "audit" (lambda (effect context)
                                     (declare (ignore context))
                                     (list :audited (effect-payload effect))))
      (let* ((stage (make-node "stage"
                               :handler (lambda (input context)
                                          (emit-event context "advance" :payload (list :value input))
                                          (perform-effect context "audit" :payload (list :value input))
                                          (step-state-machine machine "advance" :context context)
                                          :ok)))
             (context (run-pipeline-with-test-context
                       (make-pipeline :stages (list stage))
                       :input 1
                       :effect-handlers effect-handlers
                       :state "idle")))
        (is (assert-emitted-events context "advance"))
        (is (assert-performed-effects context "audit"))
        (is (assert-pipeline-result context :ok))
        (is (assert-final-state context "done"))
        (is (assert-state-machine-state machine "done"))))))

(deftest testing-helpers-accept-empty-and-list-expectations
  (let* ((machine (make-state-machine :state "idle" :transitions '()))
         (stage (make-node "stage"
                           :handler (lambda (input context)
                                      (declare (ignore input))
                                      (list :state (context-state context)
                                            :metadata (context-metadata context)))))
         (context (run-pipeline-with-test-context
                   (make-pipeline :stages (list stage))
                   :input nil)))
    (is (assert-emitted-events context nil))
    (is (assert-performed-effects context '()))
    (is (assert-pipeline-result context '(:state nil :metadata nil)))
    (is (assert-state-machine-state machine "idle"))))

(deftest sequential-pipeline-integrates-events-effects-and-state-machine
  (let* ((machine (make-state-machine
                   :state "idle"
                   :transitions (list (make-transition "idle" "advance" "done")))))
    (with-effect-handlers (effect-handlers
                           "audit" (lambda (effect context)
                                     (declare (ignore context))
                                     (list :audited (effect-payload effect))))
      (let* ((stage-one (make-node "stage-one"
                                   :handler (lambda (input context)
                                              (emit-event context "advance" :payload input)
                                              (perform-effect context "audit" :payload input)
                                              (step-state-machine machine "advance"
                                                                  :context context)
                                              (1+ input))))
             (stage-two (make-node "stage-two"
                                   :handler (lambda (input context)
                                              (declare (ignore context))
                                              (* input 2))))
             (pipeline (make-pipeline :stages (list stage-one stage-two)))
             (context (run-pipeline-with-test-context pipeline
                                                      :input 10
                                                      :effect-handlers effect-handlers
                                                      :state (state-machine-state machine))))
        (assert-pipeline-result context 22)
        (assert-emitted-events context '("advance"))
        (assert-performed-effects context '("audit"))
        (assert-final-state context "done")))))

(deftest run-pipeline-with-context-returns-result-and-context
  (let* ((stage (make-node "stage"
                           :handler (lambda (input context)
                                      (declare (ignore context))
                                      (1+ input))))
         (pipeline (make-pipeline :stages (list stage))))
    (multiple-value-bind (result context)
        (run-pipeline-with-context pipeline :input 9)
      (is (= result 10))
      (assert-pipeline-result context 10)
      (is (typep context 'context)))))

(deftest run-pipeline-with-context-reuses-provided-context
  (let* ((stage (make-node "stage"
                           :handler (lambda (input context)
                                      (emit-event context "observed" :payload input)
                                      (1+ input))))
         (pipeline (make-pipeline :stages (list stage)))
         (context (make-context :state "idle")))
    (multiple-value-bind (result returned-context)
        (run-pipeline-with-context pipeline :input 9 :context context)
      (is (= result 10))
      (is (eq returned-context context))
      (assert-emitted-events context "observed")
      (assert-pipeline-result context 10))))

(deftest pipeline-normalizes-structured-node-inputs
  (let ((stage (make-node "stage"
                          :inputs '("left" "right")
                          :outputs '("result")
                          :handler (lambda (node-input context)
                                     (declare (ignore node-input context))
                                     :ok)))
        (expected '(("left" . 1) ("right" . 2))))
    (do-structured-value-variants (input expected)
      (let ((context (run-pipeline-with-test-context
                      (make-pipeline :stages (list stage))
                      :input input)))
        (assert-context-first-trace-entry context
          (:input expected))
        (assert-pipeline-result context :ok)))))

(deftest pipeline-normalizes-structured-node-outputs
  (let ((expected '(("left" . 11) ("right" . 22))))
    (do-structured-value-variants (output expected)
      (let ((stage (make-node "stage"
                              :outputs '("left" "right")
                              :handler (lambda (input context)
                                         (declare (ignore input context))
                                         output))))
        (let ((context (run-pipeline-with-test-context
                        (make-pipeline :stages (list stage))
                        :input nil)))
          (is (equal (context-result context) expected))
          (is (equal (context-value context "stage" "left")
                     (cdr (assoc "left" expected :test #'equal))))
          (is (equal (context-value context "stage" "right")
                     (cdr (assoc "right" expected :test #'equal)))))))))
