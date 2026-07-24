(in-package #:cl-dataflow)

;;;; The effect boundary's core: constructing an EFFECT and PERFORM-EFFECT,
;;;; which looks up the type's registered handler, runs it, and records the
;;;; result into the context's effect list and trace.

(defun make-effect (type &key payload metadata trace-index result)
  (make-instance 'effect
                 :type (%normalize-name type)
                 :payload (%copy-structured-value payload)
                 :metadata (%normalize-metadata metadata)
                 :trace-index trace-index
                 :result (%copy-structured-value result)))

(defun perform-effect (context type &key payload metadata)
  (let* ((effect (make-effect type
                              :payload payload
                              :metadata metadata
                              :trace-index (%context-trace-count context)))
         (handler (gethash (%normalize-handler-key type) (context-effect-handlers context))))
    (unless handler
      (error 'effect-handler-missing-error
             :effect-type (effect-type effect)
             :effect (%copy-effect effect)
             :detail (format nil "No effect handler registered for ~A"
                             (%escaped-display-string (effect-type effect)))))
    (let ((result (funcall handler effect context)))
      (setf (effect-result effect) result)
      (setf (slot-value context 'effects)
            (cons (%copy-effect effect) (%context-effects-list context)))
      (%push-context-trace-entry context
                                  (list :effect (effect-type effect)
                                        :payload (effect-payload effect)
                                        :result (effect-result effect)
                                        :trace-index (effect-trace-index effect)))
      effect)))
