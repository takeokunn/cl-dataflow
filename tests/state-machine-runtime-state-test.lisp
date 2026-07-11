(in-package #:cl-dataflow.test)

(deftest state-machine-reset-restores-initial-state
  (let ((machine (make-state-machine
                  :state "running"
                  :initial-state "idle"
                  :transitions (list (make-transition "idle" "start" "running")))))
    (reset-state-machine machine)
    (is (equal (state-machine-state machine) "idle"))))

(deftest state-machine-copy-produces-independent-machine
  (let* ((machine (make-state-machine
                   :state "idle"
                   :metadata '((:kind :original))
                   :transitions (list (make-transition "idle" "start" "running"
                                                       :metadata '((:labels "alpha"))))))
         (copy (copy-state-machine machine)))
    (is (not (eq copy machine)))
    (setf (state-machine-state copy) "running")
    (setf (state-machine-metadata copy) '((:kind :copied)))
    (setf (transition-metadata (first (state-machine-transitions copy)))
          '((:labels "mutated")))
    (is (equal (state-machine-state machine) "idle"))
    (is (equal (state-machine-metadata machine) '((:kind :original))))
    (is (equal (transition-metadata (first (state-machine-transitions machine)))
               '((:labels "alpha"))))))

(deftest state-machine-constructor-copies-transition-objects
  (let* ((transition (make-transition "idle" "start" "running"
                                      :metadata '((:labels "alpha"))))
         (machine (make-state-machine
                   :state "idle"
                   :transitions (list transition)))
         (stored (first (state-machine-transitions machine))))
    (is (not (eq stored transition)))
    (setf (transition-metadata stored) '((:labels "mutated")))
    (is (equal (transition-metadata transition) '((:labels "alpha"))))))

(deftest state-machine-setter-copies-transition-objects
  (let* ((transition (make-transition "idle" "start" "running"
                                      :metadata '((:labels "alpha"))))
         (machine (make-state-machine :state "idle")))
    (setf (state-machine-transitions machine) (list transition))
    (let ((stored (first (state-machine-transitions machine))))
      (is (not (eq stored transition)))
      (setf (transition-metadata stored) '((:labels "mutated")))
      (is (equal (transition-metadata transition) '((:labels "alpha")))))))

(deftest state-machine-rejects-malformed-transition-lists-at-runtime
  (let ((machine (make-state-machine :state "idle")))
    (signals invalid-input-error
      (setf (state-machine-transitions machine)
            (list (list :from "idle" :event "start"))))))

(deftest state-machine-history-captures-transition-trace
  (let* ((machine (make-state-machine
                   :state "idle"
                   :transitions (list (make-transition "idle" "start" "running"
                                                       :action (lambda (machine event context)
                                                                 (declare (ignore machine event context))
                                                                 (values nil :done)))))))
    (multiple-value-bind (updated-machine transition-record)
        (step-state-machine machine "start")
      (is (equal (state-machine-state updated-machine) "running"))
      (assert-transition-record transition-record
        (:from "idle")
        (:event-type "start")
        (:to "running")
        (:state-before "idle")
        (:guard-passed t)
        (:action-result :done))
      (is (equal (state-machine-history updated-machine)
                 (list transition-record))))))

(deftest state-machine-step-defaults-guard-and-action-to-pass-through
  (let ((machine (make-state-machine
                  :state "idle"
                  :transitions (list (make-transition "idle" "start" "running")))))
    (multiple-value-bind (updated-machine transition-record)
        (step-state-machine machine "start")
      (is (equal (state-machine-state updated-machine) "running"))
      (assert-transition-record transition-record
        (:from "idle")
        (:event-type "start")
        (:to "running")
        (:guard-passed t)
        (:action-result nil)))))

(deftest state-machine-history-helpers-return-independent-snapshots
  (let ((machine (make-state-machine
                  :state "idle"
                  :transitions (list (make-transition "idle" "start" "running")))))
    (multiple-value-bind (updated-machine transition-record)
        (step-state-machine machine "start")
      (let ((history (state-machine-history updated-machine))
            (history-copy (state-machine-history updated-machine)))
        (is (not (eq (first history) transition-record)))
        (is (not (eq (first history-copy) transition-record)))
        (set-plist-entry (first history) :action-result :mutated)
        (set-plist-entry (first history-copy) :action-result :mutated)
        (assert-transition-records (list (first (state-machine-history updated-machine))
                                         (first (state-machine-history updated-machine)))
          (:action-result nil))))))

(deftest state-machine-reset-keeps-history
  (let ((machine (make-state-machine
                  :state "idle"
                  :initial-state "idle"
                  :transitions (list (make-transition "idle" "start" "running")))))
    (step-state-machine machine "start")
    (let ((history-before (copy-list (state-machine-history machine))))
      (reset-state-machine machine)
      (is (equal (state-machine-state machine) "idle"))
      (is (equal (state-machine-history machine) history-before)))))
