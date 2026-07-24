(in-package #:cl-dataflow)

(progn
  (defun %store-value-by-key (context key value)
    (setf (gethash key (%context-values-table context)) (%copy-structured-value value)))
  (defun %store-value (context node-name port value)
    (%store-value-by-key context (list node-name port) value)))

(progn
  (defun %read-value-by-key (context key)
    (gethash key (%context-values-table context)))
  (defun %read-value (context node-name port)
    (%read-value-by-key context (list node-name port))))

(defun %make-runtime-context (&key state metadata effect-handlers)
  (make-context :state state :metadata metadata :effect-handlers effect-handlers))

(defmacro %with-plist-bindings ((plist bindings) &body body)
  (let ((plist-name (gensym "PLIST")))
    `(let ((,plist-name ,plist))
        (let ,(mapcar (lambda (binding)
                        (destructuring-bind (name key) binding
                          `(,name (getf ,plist-name ,key))))
                      bindings)
          ,@body))))
