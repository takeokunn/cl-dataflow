(in-package #:cl-dataflow.test)

(deftest copy-state-machine-produces-independent-machine
  (let* ((transition (make-transition "idle" "start" "running"
                                      :metadata '((:kind :transition))))
         (history (list (list :from "idle"
                              :event-type "start"
                              :to "running"
                              :state-before "idle"
                              :guard-passed t
                              :action-result '(:ok t))))
         (metadata '((:kind :machine)))
         (machine (make-state-machine :state "running"
                                      :initial-state "idle"
                                      :transitions (list transition)
                                      :history history
                                      :metadata metadata))
         (replacement-transition (make-transition "running" "stop" "idle")))
    (with-copy-isolation (copy machine (copy-state-machine machine))
      (is (equal (state-machine-state copy) "running"))
      (is (equal (state-machine-initial-state copy) "idle"))
      (is (equal (state-machine-metadata copy) '((:kind :machine))))
      (is (equal (mapcar #'transition-from (state-machine-transitions copy))
                 '("idle")))
      (is (equal (mapcar #'transition-event-type (state-machine-transitions copy))
                 '("start")))
      (is (equal (mapcar #'transition-to (state-machine-transitions copy))
                 '("running")))
      (is (equal (state-machine-history copy) history))
      (setf (state-machine-state machine) "stopped"
            (state-machine-transitions machine) (list replacement-transition)
            (state-machine-history machine)
            (list (list :from "running"
                        :event-type "stop"
                        :to "idle"
                        :state-before "running"
                        :guard-passed t
                        :action-result '(:ok t))))
      (setf (cadar (slot-value machine 'cl-dataflow::metadata)) :mutated-machine)
      (is (equal (state-machine-state machine) "stopped"))
      (is (equal (state-machine-metadata machine) '((:kind :mutated-machine))))
      (is (equal (mapcar #'transition-event-type (state-machine-transitions machine))
                 '("stop")))
      (is (equal (state-machine-history machine)
                 (list (list :from "running"
                             :event-type "stop"
                             :to "idle"
                             :state-before "running"
                             :guard-passed t
                              :action-result '(:ok t))))))))

(define-snapshot-isolation-test transition-accessors-return-independent-snapshots
  ((transition (make-transition "idle" "start" "running"
                                :metadata '((:kind :transition)))))
  (metadata-snapshot (transition-metadata transition))
  (setf (cadr (first metadata-snapshot)) :changed)
  (is (equal (transition-metadata transition)
             '((:kind :transition)))))
