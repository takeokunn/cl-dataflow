(in-package #:cl-dataflow)

(defun %store-value (context node-name port value)
  (setf (gethash (list node-name port) (%context-values-table context))
        (%copy-structured-value value)))

(defun %read-value (context node-name port)
  (gethash (list node-name port) (%context-values-table context)))

(defun %make-runtime-context (&key state metadata effect-handlers)
  (make-context :state state
                :metadata metadata
                :effect-handlers effect-handlers))

(defmacro %with-plist-bindings ((plist bindings) &body body)
  (let ((plist-name (gensym "PLIST")))
    `(let ((,plist-name ,plist))
       (let ,(mapcar (lambda (binding)
                       (destructuring-bind (name key) binding
                         `(,name (getf ,plist-name ,key))))
                     bindings)
         ,@body))))
