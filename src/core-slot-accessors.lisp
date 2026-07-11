(in-package #:cl-dataflow)

(defun %read-slot (object slot-name)
  (slot-value object slot-name))

(defun %slot-value-or (object slot-name default)
  (if (slot-boundp object slot-name)
      (slot-value object slot-name)
      default))

(defun (setf %read-slot) (value object slot-name)
  (setf (slot-value object slot-name) value))

(defun %expected-object-detail (expected value)
  (format nil "Expected ~A, got ~S" expected value))

(defun %node-inputs-list (node)
  (%read-slot node 'inputs))

(defun %node-outputs-list (node)
  (%read-slot node 'outputs))

(defun %graph-nodes-table (graph)
  (%read-slot graph 'nodes))

(defun %graph-edges-list (graph)
  (%read-slot graph 'edges))

(defsetf %graph-edges-list (graph) (new-edges)
  `(setf (%read-slot ,graph 'edges) ,new-edges))

(defun %context-values-table (context)
  (%read-slot context 'values))

(defun %context-events-list (context)
  (%read-slot context 'events))

(defsetf %context-events-list (context) (new-events)
  `(setf (%read-slot ,context 'events) ,new-events))

(defun %context-effects-list (context)
  (%read-slot context 'effects))

(defsetf %context-effects-list (context) (new-effects)
  `(setf (%read-slot ,context 'effects) ,new-effects))

(defun %context-trace-list (context)
  (%read-slot context 'trace))

(defsetf %context-trace-list (context) (new-trace)
  `(setf (%read-slot ,context 'trace) ,new-trace))

(defun %context-trace-count (context)
  (length (%context-trace-list context)))

(defun %state-machine-history-list (machine)
  (%read-slot machine 'history))

(defsetf %state-machine-history-list (machine) (new-history)
  `(setf (%read-slot ,machine 'history) ,new-history))

(defun %pipeline-stages-list (pipeline)
  (%read-slot pipeline 'stages))

(defmacro define-type-predicates (&body specs)
  `(progn
     ,@(mapcar (lambda (spec)
                 (destructuring-bind (predicate-name type-name) spec
                   `(defun ,predicate-name (object)
                      (typep object ',type-name))))
               specs)))

(defmacro define-slot-apis (&body specs)
  `(progn
     ,@(mapcan (lambda (spec)
                 (destructuring-bind (name object-name slot-name
                                      &key
                                      (getter `(slot-value ,object-name ',slot-name))
                                      (setter `(setf (slot-value ,object-name ',slot-name) value))
                                      writable)
                     spec
                   (let ((forms `((defun ,name (,object-name)
                                    ,getter))))
                     (if (eq writable :none)
                         forms
                         (append forms
                                 `((defun (setf ,name) (value ,object-name)
                                     ,setter)))))))
               specs)))

(defun %hash-table-keys (table)
  (let (keys)
    (maphash (lambda (key value)
               (declare (ignore value))
               (push key keys))
             table)
    (nreverse keys)))
