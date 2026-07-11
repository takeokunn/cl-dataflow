(in-package #:cl-dataflow)

(defun make-event (type &key payload metadata trace-index)
  (make-instance 'event
                 :type (%normalize-name type)
                 :payload (%copy-structured-value payload)
                 :metadata (%normalize-metadata metadata)
                 :trace-index trace-index))

(defun emit-event (context type &key payload metadata)
  (let ((event (make-event type
                           :payload payload
                           :metadata metadata
                           :trace-index (%context-trace-count context))))
    (setf (slot-value context 'events)
          (cons (%copy-event event) (%context-events-list context)))
    (setf (slot-value context 'trace)
          (cons (list :event (event-type event)
                      :payload (event-payload event)
                      :trace-index (event-trace-index event))
                (%context-trace-list context)))
    event))
