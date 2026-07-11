(in-package #:cl-dataflow)

(defun %make-result-table ()
  (make-hash-table :test #'equal))

(defun %copy-hash-table (table)
  (let ((copy (make-hash-table :test (hash-table-test table)
                               :size (hash-table-count table))))
    (maphash (lambda (key value)
               (setf (gethash key copy) value))
             table)
    copy))

(defun %copy-structured-value (value)
  (cond
    ((hash-table-p value)
     (%copy-hash-table value))
    ((consp value)
     (copy-tree value))
    ((or (stringp value) (vectorp value))
     (copy-seq value))
    (t value)))

(defun %copy-result-table (table)
  (let ((copy (make-hash-table :test (hash-table-test table)
                               :size (hash-table-count table))))
    (maphash (lambda (key value)
               (setf (gethash key copy) (%copy-structured-value value)))
             table)
    copy))

(defun %copy-effect-handlers (effect-handlers)
  (let ((copy (make-hash-table :test #'equal
                               :size (hash-table-count effect-handlers))))
    (maphash (lambda (key value)
               (setf (gethash (%normalize-handler-key key) copy) value))
             effect-handlers)
    copy))
