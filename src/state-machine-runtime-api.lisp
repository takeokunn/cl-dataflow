(in-package #:cl-dataflow)

(defun state-machine-available-transitions (machine &key (state (state-machine-state machine)))
  (let ((normalized-state (%normalize-name state)))
    (mapcar #'%copy-state-transition
            (remove-if-not (lambda (transition)
                             (string-equal (transition-from transition) normalized-state))
                           (%state-machine-transitions-list machine)))))

(defun state-machine-can-step-p (machine event &key context)
  (let* ((event-type (%event-type-designator event))
         (transition (%find-transition machine event-type)))
    (and transition
         (let ((guard (transition-guard transition)))
           (or (null guard)
               (funcall guard machine event context))))))

(defun step-state-machine (machine event &key context)
  (let ((event-type (%event-type-designator event)))
    (%step-state-machine/cps
     machine
     event
     context
     event-type
     (lambda (updated-machine transition-record)
       (values updated-machine transition-record)))))

(defun run-state-machine (machine events &key context)
  (%run-state-machine-events/cps machine events context
                                 (lambda (updated-machine transition-records)
                                   (values updated-machine transition-records))))

(defun run-state-machine-with-context (machine events &key context)
  (let ((ctx (or context (%make-runtime-context :state (state-machine-state machine)))))
    (multiple-value-bind (updated-machine transition-records)
        (run-state-machine machine events :context ctx)
      (setf (context-state ctx) (state-machine-state updated-machine))
      (values updated-machine transition-records ctx))))

(defun %make-state-machine-node-handler (machine event-fn result-fn)
  (lambda (input context)
    (let* ((event (if event-fn
                      (funcall event-fn input context)
                      input))
           (runtime-context (and (context-p context) context))
           (updated-machine (step-state-machine machine event
                                                :context runtime-context))
           (current-state (state-machine-state updated-machine)))
      (if result-fn
          (funcall result-fn updated-machine event input context)
          current-state))))

(defun make-state-machine-node (machine &key name event-fn result-fn metadata)
  (make-node (or name "state-machine")
             :outputs '("value")
             :metadata metadata
             :handler (%make-state-machine-node-handler machine event-fn result-fn)))
