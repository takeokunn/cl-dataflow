(in-package #:cl-dataflow)

(defun make-transition (from event-type to &key guard action metadata)
  (make-instance 'state-transition
                 :from (%normalize-name from)
                 :event-type (%normalize-name event-type)
                 :to (%normalize-name to)
                 :guard guard
                 :action action
                 :metadata (%normalize-metadata metadata)))

(defun %resolve-state-machine-state (state initial-state)
  (cond
    (state
     (let ((resolved-state (%normalize-name state))
           (resolved-initial-state (%normalize-name (or initial-state state))))
       (values resolved-state resolved-initial-state)))
    (initial-state
     (let ((resolved-initial-state (%normalize-name initial-state)))
       (values resolved-initial-state resolved-initial-state)))
    (t
     (error 'invalid-input-error
            :expected '(or state initial-state)
            :value nil
            :detail "State machine requires STATE or INITIAL-STATE."))))

(defun %copy-transition-history (history)
  (copy-tree history))

(defun %copy-state-transition (transition)
  (unless (state-transition-p transition)
    (error 'invalid-input-error
           :expected 'state-transition
           :value transition
           :detail (format nil "Expected STATE-TRANSITION, got ~S" transition)))
  (make-transition (transition-from transition)
                   (transition-event-type transition)
                   (transition-to transition)
                   :guard (transition-guard transition)
                   :action (transition-action transition)
                   :metadata (transition-metadata transition)))

(defun %copy-transition-record (record)
  (copy-tree record))

(defun make-state-machine (&key state initial-state transitions history metadata)
  (multiple-value-bind (resolved-state resolved-initial-state)
      (%resolve-state-machine-state state initial-state)
    (make-instance 'state-machine
                   :state resolved-state
                   :initial-state resolved-initial-state
                   :transitions (mapcar #'%copy-state-transition transitions)
                   :history (%copy-transition-history history)
                   :metadata (%normalize-metadata metadata))))

(defmethod (setf state-machine-transitions) (transitions (machine state-machine))
  (setf (slot-value machine 'transitions)
        (mapcar #'%copy-state-transition transitions)))

(defmethod state-machine-transitions ((machine state-machine))
  (mapcar #'%copy-state-transition
          (slot-value machine 'transitions)))

(defun %state-machine-transitions-list (machine)
  (state-machine-transitions machine))

(defun copy-state-machine (machine)
  (make-state-machine :state (state-machine-state machine)
                      :initial-state (state-machine-initial-state machine)
                      :transitions (%state-machine-transitions-list machine)
                      :history (%copy-transition-history (state-machine-history machine))
                      :metadata (%normalize-metadata (state-machine-metadata machine))))

(defun reset-state-machine (machine)
  (setf (state-machine-state machine)
        (state-machine-initial-state machine))
  machine)

(defun state-machine-last-transition (machine)
  (let ((transition (first (state-machine-history machine))))
    (when transition
      (%copy-transition-record transition))))

(defun %event-type-designator (event)
  (typecase event
    (event (event-type event))
    (t (%normalize-name event))))

(defun %transition-matches-p (transition machine event-type)
  (and (string-equal (transition-from transition) (state-machine-state machine))
       (string-equal (transition-event-type transition) event-type)))

(defun %matching-transitions (machine event-type)
  "Every transition whose FROM state and EVENT-TYPE match MACHINE's current state."
  (remove-if-not (lambda (transition)
                   (%transition-matches-p transition machine event-type))
                 (%state-machine-transitions-list machine)))

(defun %transition-guard-satisfied-p (transition machine event context)
  (let ((guard (transition-guard transition)))
    (or (null guard)
        (funcall guard machine event context))))

(defun %select-transition (machine event context matches)
  "Return the first MATCH whose guard is absent or satisfied, else NIL.

Guards are the mechanism for choosing among transitions that share the same
FROM state and event, so a rejecting guard falls through to the next candidate
instead of aborting the whole step."
  (find-if (lambda (transition)
             (%transition-guard-satisfied-p transition machine event context))
           matches))

(defun %transition-error-detail (machine event-type &optional (detail "No transition"))
  (format nil "~A from ~A on event ~A" detail
          (state-machine-state machine)
          event-type))

(defun %guard-error-detail (machine event-type)
  (%transition-error-detail machine event-type "Guard rejected transition"))
