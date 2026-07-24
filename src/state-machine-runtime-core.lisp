(in-package #:cl-dataflow)

(defun make-transition (from event-type to &key guard action metadata)
  (make-instance
    'state-transition
    :from
    (%normalize-name from)
    :event-type
    (%normalize-name event-type)
    :to
    (%normalize-name to)
    :guard
    guard
    :action
    action
    :metadata
    (%normalize-metadata metadata)))

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
      (error
        'invalid-input-error
        :expected
        '(or state initial-state)
        :value
        nil
        :detail
        "State machine requires STATE or INITIAL-STATE."))))

(defun %copy-transition-history (history)
  (mapcar #'%copy-transition-record history))

(defun %validate-state-machine-history-limit (limit)
  (unless (or (null limit) (and (integerp limit) (not (minusp limit))))
    (error
      'invalid-input-error
      :expected
      '(or null unsigned-integer)
      :value
      limit
      :detail
      "STATE-MACHINE-HISTORY-LIMIT limit must be NIL or a non-negative integer."))
  limit)

(defun %trim-transition-history (history limit)
  (if (and limit (< limit (length history))) (subseq history 0 limit)
    history))

(defun %copy-state-transition (transition)
  (unless (state-transition-p transition)
    (error
      (quote invalid-input-error)
      :expected
      (quote state-transition)
      :value
      transition
      :detail
      (format nil "Expected STATE-TRANSITION, got ~S" transition)))
  (make-transition
    (copy-seq (%normalize-name (transition-from transition)))
    (copy-seq (%normalize-name (transition-event-type transition)))
    (transition-to transition)
    :guard
    (transition-guard transition)
    :action
    (transition-action transition)
    :metadata
    (transition-metadata transition)))

(defun %copy-transition-record (record)
  (%copy-structured-value record))

(defun make-state-machine (&key state initial-state transitions history history-limit metadata)
  (multiple-value-bind (resolved-state resolved-initial-state) (%resolve-state-machine-state state initial-state)
    (let ((resolved-history-limit (%validate-state-machine-history-limit history-limit)))
      (make-instance
        (quote state-machine)
        :state
        resolved-state
        :initial-state
        resolved-initial-state
        :transitions
        transitions
        :history
        (%trim-transition-history
          (%copy-transition-history history)
          resolved-history-limit)
        :history-limit
        resolved-history-limit
        :metadata
        (%normalize-metadata metadata)))))

(defmethod (setf state-machine-transitions) (transitions (machine state-machine))
  (let ((copied-transitions (mapcar (function %copy-state-transition) transitions)))
    (setf (slot-value machine (quote transitions)) copied-transitions
          (slot-value machine (quote transition-index)) (%make-state-machine-transition-index copied-transitions))))

(defmethod state-machine-transitions ((machine state-machine))
  (mapcar #'%copy-state-transition (slot-value machine 'transitions)))

(defun %state-machine-transitions-list (machine)
  (slot-value machine 'transitions))

(defun copy-state-machine (machine)
  (make-state-machine
    :state
    (state-machine-state machine)
    :initial-state
    (state-machine-initial-state machine)
    :transitions
    (%state-machine-transitions-list machine)
    :history
    (%copy-transition-history (state-machine-history machine))
    :history-limit
    (state-machine-history-limit machine)
    :metadata
    (%normalize-metadata (state-machine-metadata machine))))

(defun reset-state-machine (machine)
  (setf (state-machine-state machine) (state-machine-initial-state machine))
  machine)

(defun state-machine-last-transition (machine)
  (let ((transition (first (state-machine-history machine))))
    (when transition
      (%copy-transition-record transition))))

(defun %event-type-designator (event)
  (typecase event
    (event (event-type event))
    (t (%normalize-name event))))

(progn
  (defun %make-state-machine-transition-index (transitions)
    (let ((index (make-hash-table :test (function equalp))))
      (dolist (transition transitions)
        (let* ((from-key (copy-seq (string (transition-from transition))))
              (event-key (copy-seq (string (transition-event-type transition))))
              (event-index
                (or
                  (gethash from-key index)
                  (setf (gethash from-key index)
                        (make-hash-table :test (function equalp))))))
          (push transition (gethash event-key event-index))))
      (maphash
        (lambda (from-key event-index)
          (declare (ignore from-key))
          (maphash
            (lambda (event-key candidates)
              (setf (gethash event-key event-index) (nreverse candidates)))
            event-index))
        index)
      index))
  (defmethod initialize-instance :after ((machine state-machine) &key)
    (let ((copied-transitions
          (mapcar
            (function %copy-state-transition)
            (slot-value machine (quote transitions)))))
      (setf (slot-value machine (quote transitions)) copied-transitions
            (slot-value machine (quote transition-index)) (%make-state-machine-transition-index copied-transitions)))))

(defun %indexed-matching-transitions (machine event-type)
  (let ((event-index
        (gethash
          (string (state-machine-state machine))
          (slot-value machine (quote transition-index)))))
    (when event-index
      (gethash (string event-type) event-index))))

(defun %transition-guard-satisfied-p (transition machine event context)
  (let ((guard (transition-guard transition)))
    (or (null guard) (funcall guard machine event context))))

(defun %find-transition-selection (machine event context event-type)
  "Return selected transition and the first matching transition, if any."
  (loop with first-match = nil
        for transition in (%indexed-matching-transitions machine event-type)
        do (when (%transition-guard-satisfied-p transition machine event context)
      (return (values transition transition))) (unless first-match
      (setf first-match transition))
        finally (return (values nil first-match))))

(defun %select-transition (machine event context matches)
  "Return the first MATCH whose guard is absent or satisfied, else NIL.

Guards are the mechanism for choosing among transitions that share the same
FROM state and event, so a rejecting guard falls through to the next candidate
instead of aborting the whole step."
  (find-if
    (lambda (transition)
      (%transition-guard-satisfied-p transition machine event context))
    matches))

(defun %transition-error-detail (machine event-type &optional (detail "No transition"))
  (format
    nil
    "~A from ~A on event ~A"
    detail
    (%escaped-display-string (state-machine-state machine))
    (%escaped-display-string event-type)))

(defun %guard-error-detail (machine event-type)
  (%transition-error-detail machine event-type "Guard rejected transition"))
