(in-package #:cl-dataflow.test)

(deftest state-machine-transition
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running")))
    (step-state-machine machine "start")
    (is (equal (state-machine-state machine) "running"))))

(deftest state-transition-accessors-and-predicate
  (let ((action (lambda (machine event context)
                  (declare (ignore machine event context))
                  :ok)))
    (with-state-machine-fixture (machine
                                 :state "idle"
                                 :transitions ((transition "idle" "start" "running"
                                                           :action action)))
      (let ((transition (first (state-machine-transitions machine))))
        (is (state-transition-p transition))
        (is (equal (transition-from transition) "idle"))
        (is (eq (transition-action transition) action))))))

(deftest state-machine-guard-failure
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running"
                                                         :guard (lambda (machine event context)
                                                                  (declare (ignore machine event context))
                                                                  nil))))
    (signals guard-failed-error
      (step-state-machine machine "start"))))

(deftest state-machine-guard-failure-exposes-condition-data
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running"
                                                         :guard (lambda (machine event context)
                                                                  (declare (ignore machine event context))
                                                                  nil))))
    (with-captured-condition (captured guard-failed-error)
        (step-state-machine machine "start")
      (is (equal (guard-failed-state captured) "idle"))
      (is (equal (guard-failed-event-type captured) "start"))
      (is (not (eq (guard-failed-transition captured)
                   (first (state-machine-transitions machine)))))
      (is (equal (transition-from (guard-failed-transition captured)) "idle"))
      (is (equal (transition-event-type (guard-failed-transition captured)) "start"))
      (is (equal (guard-failed-detail captured)
                 "Guard rejected transition from idle on event start"))
      (assert-condition-report captured
                               "Guard rejected transition from idle on event start"))))

(deftest state-machine-invalid-transition
  (let ((machine (make-state-machine :state "idle" :transitions '())))
    (signals invalid-transition-error
      (step-state-machine machine "start"))))

(deftest state-machine-invalid-transition-exposes-condition-data
  (let* ((machine (make-state-machine :state "idle" :transitions '()))
         (captured
           (capture-condition (condition invalid-transition-error)
             (step-state-machine machine "start"))))
    (is captured)
    (is (equal (invalid-transition-state captured) "idle"))
    (is (equal (invalid-transition-event-type captured) "start"))
    (is (equal (invalid-transition-detail captured)
               "No transition from idle on event start"))
    (assert-condition-report captured
                             "No transition from idle on event start")))

(deftest state-machine-action-override
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running"
                                                         :action (lambda (machine event context)
                                                                   (declare (ignore machine event context))
                                                                   "completed"))))
    (step-state-machine machine "start")
    (is (equal (state-machine-state machine) "completed"))))

(deftest state-machine-constructor-derives-missing-state
  (let ((machine (make-state-machine :initial-state "idle"
                                     :transitions '())))
    (is (equal (state-machine-state machine) "idle"))
    (is (equal (state-machine-initial-state machine) "idle"))))

(deftest state-machine-constructor-requires-an-explicit-state-designator
  (with-captured-condition (captured invalid-input-error)
      (make-state-machine :transitions '())
    (is (equal (invalid-input-expected captured)
               '(or cl-dataflow::state cl-dataflow::initial-state)))
    (is (null (invalid-input-value captured)))
    (is (equal (invalid-input-detail captured)
               "State machine requires STATE or INITIAL-STATE."))))

(deftest state-machine-action-result-is-captured
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running"
                                                         :action (lambda (machine event context)
                                                                   (declare (ignore machine event context))
                                                                   (values "completed"
                                                                           '(:note "transitioned"))))))
      (multiple-value-bind (updated-machine transition-record)
        (step-state-machine machine "start")
      (declare (ignore updated-machine))
      (is (equal (state-machine-state machine) "completed"))
      (assert-transition-record transition-record
        (:action-result '(:note "transitioned")))
      (is (equal transition-record
                 (state-machine-last-transition machine))))))

(deftest state-machine-step-updates-context-state-and-trace
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running")))
    (let ((context (make-context :state "idle")))
      (with-stepped-state-machine (updated-machine transition-record machine "start"
                                                       :context context
                                                       :history-entry history-entry
                                                       :trace-entry trace-entry)
        (is (eq updated-machine machine))
        (is (equal (context-state context) "running"))
        (assert-transition-records (list transition-record history-entry)
          (:event-type "start"))
        (assert-transition-record trace-entry
          (:from "idle")
          (:event-type "start")
          (:to "running")
          (:state-before "idle")
          (:guard-passed t)
          (:action-result nil))))))

(deftest state-machine-step-with-event-object-preserves-event-for-action-and-normalizes-state
  (let* ((captured-event nil)
         (captured-context nil)
         (event (make-event "start" :payload '(:step 1))))
    (with-state-machine-fixture (machine
                                 :state "idle"
                                 :transitions ((transition "idle" "start" "running"
                                                           :action (lambda (machine action-event action-context)
                                                                     (declare (ignore machine))
                                                                     (setf captured-event action-event
                                                                           captured-context action-context)
                                                                     (values 'completed
                                                                             (list :event-type (event-type action-event)
                                                                                   :payload (event-payload action-event)))))))
      (let ((context (make-context :state "idle")))
        (with-stepped-state-machine (updated-machine transition-record machine event
                                                     :context context
                                                     :history-entry history-entry
                                                     :trace-entry trace-entry)
          (is (eq updated-machine machine))
          (is (eq captured-event event))
          (is (eq captured-context context))
          (is (equal (state-machine-state machine) "COMPLETED"))
          (is (equal (context-state context) "COMPLETED"))
          (assert-transition-records (list transition-record history-entry trace-entry)
            (:from "idle")
            (:event-type "start")
            (:to "COMPLETED")
            (:state-before "idle")
            (:guard-passed t)
            (:action-result '(:event-type "start" :payload (:step 1)))))))))

(deftest state-machine-transition-records-are-copied-across-boundaries
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running")))
    (let ((context (make-context :state "idle")))
      (with-stepped-state-machine (updated-machine transition-record machine "start"
                                                   :context context
                                                   :history-entry history-record
                                                   :trace-entry trace-record)
        (is (eq updated-machine machine))
        (set-plist-entry transition-record :to "mutated")
        (set-plist-entry history-record :event-type "history-mutated")
        (set-plist-entry trace-record :state-before "trace-mutated")
        (assert-transition-record transition-record
          (:to "mutated"))
        (assert-transition-record history-record
          (:event-type "history-mutated")
          (:to "running")
          (:state-before "idle"))
        (assert-transition-record trace-record
          (:state-before "trace-mutated")
          (:to "running")
          (:event-type "start"))
        (assert-transition-record (first (state-machine-history machine))
          (:to "running"))
        (assert-transition-record (first (context-trace context))
          (:to "running"))))))

(deftest state-machine-run-sequence
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((idle-start "idle" "start" "running")
                                             (running-finish "running" "finish" "completed")))
    (multiple-value-bind (updated-machine transition-records)
        (run-state-machine machine '("start" "finish"))
      (declare (ignore updated-machine))
      (assert-event-sequence transition-records '("start" "finish")))
    (assert-state-machine-state machine "completed")))

(deftest state-machine-run-sequence-accepts-event-objects
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((idle-start "idle" "start" "running")
                                             (running-finish "running" "finish" "completed")))
    (let ((events (list (make-event "start" :payload '(:step 1))
                        (make-event "finish" :payload '(:step 2)))))
      (multiple-value-bind (updated-machine transition-records)
          (run-state-machine machine events)
        (declare (ignore updated-machine))
        (assert-event-sequence transition-records '("start" "finish"))
        (is (equal (state-machine-state machine) "completed"))))))

(deftest state-machine-run-with-context-returns-transition-records-and-context
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((idle-start "idle" "start" "running")
                                             (running-finish "running" "finish" "completed")))
    (multiple-value-bind (updated-machine transition-records context)
        (run-state-machine-with-context machine '("start" "finish"))
      (declare (ignore updated-machine))
      (assert-event-sequence transition-records '("start" "finish"))
      (is (equal (context-state context) "completed"))
      (assert-event-sequence (context-trace context) '("finish" "start")))))

(deftest state-machine-run-with-context-reuses-provided-context
  (with-state-machine-fixture (machine
                               :state "idle"
                               :transitions ((transition "idle" "start" "running")))
    (let ((context (make-context :state "idle")))
      (multiple-value-bind (updated-machine transition-records returned-context)
          (run-state-machine-with-context machine '("start") :context context)
        (declare (ignore updated-machine))
        (is (eq returned-context context))
        (assert-event-sequence transition-records '("start"))
        (is (equal (context-state context) "running"))
        (assert-event-sequence (context-trace context) '("start"))))))

(deftest state-machine-run-with-context-creates-default-context
  (let ((machine (make-state-machine :state "idle"
                                     :transitions '())))
    (multiple-value-bind (updated-machine transition-records context)
        (run-state-machine-with-context machine '())
      (declare (ignore updated-machine))
      (is (null transition-records))
      (is (context-p context))
      (is (equal (context-state context) "idle"))
      (is (equal (context-trace context) '())))))
