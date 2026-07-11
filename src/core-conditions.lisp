(in-package #:cl-dataflow)

(define-condition cl-dataflow-error (error) ())

(defun %write-condition-detail-report (condition stream detail-reader)
  (format stream "~A: ~A"
          (type-of condition)
          (funcall detail-reader condition)))

(defun %write-graph-cycle-report (condition stream)
  (%write-condition-detail-report
   condition
   stream
   (lambda (graph-condition)
     (let ((detail (graph-error-detail graph-condition))
           (cycle-nodes (mapcar #'node-name
                                (graph-cycle-nodes graph-condition))))
       (if cycle-nodes
           (format nil "~A Cyclic nodes: ~{~A~^, ~}" detail cycle-nodes)
           detail)))))

(define-condition invalid-input-error (cl-dataflow-error)
  ((expected :initarg :expected :reader invalid-input-expected)
   (value :initarg :value :reader invalid-input-value)
   (detail :initarg :detail :reader invalid-input-detail))
  (:report (lambda (condition stream)
             (%write-condition-detail-report condition
                                             stream
                                             #'invalid-input-detail))))

(define-condition graph-error (cl-dataflow-error)
  ((graph :initarg :graph :reader graph-error-graph)
   (detail :initarg :detail :reader graph-error-detail))
  (:report (lambda (condition stream)
             (%write-condition-detail-report condition
                                             stream
                                             #'graph-error-detail))))

(define-condition node-not-found-error (graph-error)
  ((designator :initarg :designator :reader node-not-found-designator))
  (:report (lambda (condition stream)
             (%write-condition-detail-report condition
                                             stream
                                             #'graph-error-detail))))

(define-condition graph-cycle-error (graph-error)
  ((nodes :initarg :nodes :reader graph-cycle-nodes))
  (:report (lambda (condition stream)
             (%write-graph-cycle-report condition stream))))

(define-condition effect-handler-missing-error (cl-dataflow-error)
  ((effect-type :initarg :effect-type :reader missing-effect-type)
   (effect :initarg :effect :reader effect-handler-missing-effect)
   (detail :initarg :detail :reader effect-handler-missing-detail))
  (:report (lambda (condition stream)
             (%write-condition-detail-report condition
                                             stream
                                             #'effect-handler-missing-detail))))

(define-condition invalid-transition-error (cl-dataflow-error)
  ((state :initarg :state :reader invalid-transition-state)
   (event-type :initarg :event-type :reader invalid-transition-event-type)
   (detail :initarg :detail :reader invalid-transition-detail))
  (:report (lambda (condition stream)
             (%write-condition-detail-report condition
                                             stream
                                             #'invalid-transition-detail))))

(define-condition guard-failed-error (cl-dataflow-error)
  ((state :initarg :state :reader guard-failed-state)
   (event-type :initarg :event-type :reader guard-failed-event-type)
   (transition :initarg :transition :reader guard-failed-transition)
   (detail :initarg :detail :reader guard-failed-detail))
  (:report (lambda (condition stream)
             (%write-condition-detail-report condition
                                             stream
                                             #'guard-failed-detail))))
