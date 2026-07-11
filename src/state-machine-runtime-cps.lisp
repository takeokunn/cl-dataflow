(in-package #:cl-dataflow)

(defun %resolve-transition/cps (machine event-type continuation)
  (let ((transition (%find-transition machine event-type)))
    (unless transition
      (error 'invalid-transition-error
             :state (state-machine-state machine)
             :event-type event-type
             :detail (%transition-error-detail machine event-type)))
    (funcall continuation transition)))

(defun %ensure-transition-guard/cps (machine transition event context event-type continuation)
  (let ((guard (transition-guard transition)))
    (when (and guard (not (funcall guard machine event context)))
      (error 'guard-failed-error
             :state (state-machine-state machine)
             :event-type event-type
             :transition (%copy-state-transition transition)
             :detail (%guard-error-detail machine event-type)))
    (funcall continuation transition)))

(defun %run-transition-action/cps (machine transition event context continuation)
  (let ((action (transition-action transition))
        (previous-state (state-machine-state machine))
        (next-state (transition-to transition))
        (action-result nil))
    (when action
      (multiple-value-bind (computed result)
          (funcall action machine event context)
        (when computed
          (setf next-state (%normalize-name computed)))
        (setf action-result result)))
    (funcall continuation previous-state next-state action-result)))

(defun %run-transition/cps (machine transition event context event-type continuation)
  (%run-transition-action/cps
   machine
   transition
   event
   context
   (lambda (previous-state next-state action-result)
     (funcall continuation
              transition
              event-type
              previous-state
              next-state
              action-result))))

(defun %make-transition-record (transition event-type previous-state next-state action-result)
  (list :from (transition-from transition)
        :event-type event-type
        :to next-state
        :state-before previous-state
        :guard-passed t
        :action-result (%copy-structured-value action-result)))

(defun %commit-transition/cps (machine context transition event-type previous-state next-state action-result continuation)
  (let ((transition-record (%make-transition-record transition
                                                   event-type
                                                   previous-state
                                                   next-state
                                                   action-result)))
    (let ((history-record (%copy-transition-record transition-record))
          (trace-record (%copy-transition-record transition-record)))
      (setf (slot-value machine 'history)
            (cons history-record (%state-machine-history-list machine)))
      (setf (state-machine-state machine) next-state)
      (when context
        (setf (context-state context) next-state)
        (setf (slot-value context 'trace)
              (cons trace-record (%context-trace-list context))))
      (funcall continuation machine (%copy-transition-record transition-record)))))

(defun %step-state-machine/cps (machine event context event-type continuation)
  (%resolve-transition/cps
   machine
   event-type
   (lambda (transition)
     (%ensure-transition-guard/cps
      machine
      transition
      event
      context
      event-type
      (lambda (guarded-transition)
        (%run-transition/cps
         machine
         guarded-transition
         event
         context
         event-type
         (lambda (transition event-type previous-state next-state action-result)
           (%commit-transition/cps machine
                                   context
                                   transition
                                   event-type
                                   previous-state
                                   next-state
                                   action-result
                                   continuation))))))))

(defun %run-state-machine-events/cps (machine events context continuation)
  (labels ((advance-events (remaining-events transition-records)
             (if (endp remaining-events)
                 (funcall continuation machine (nreverse transition-records))
                 (multiple-value-bind (updated-machine transition-record)
                     (step-state-machine machine (first remaining-events) :context context)
                   (declare (ignore updated-machine))
                   (advance-events (rest remaining-events)
                                   (cons transition-record transition-records))))))
    (advance-events events '())))
