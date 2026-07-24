(in-package #:cl-dataflow)

(defun %make-result-table ()
  (make-hash-table :test #'equal))

(defun %copy-hash-table-with-value-transform (table value-transform)
  (let ((copy
        (make-hash-table :test (hash-table-test table) :size (hash-table-count table))))
    (maphash
      (lambda (key value)
        (setf (gethash key copy) (funcall value-transform value)))
      table)
    copy))

(defmacro define-copy-hash-table (name (source element-copy))
  `(defun ,name (,source)
    (%copy-hash-table-with-value-transform ,source ,element-copy)))

(defun %copy-hash-table (table)
  (%copy-hash-table-with-value-transform table #'identity))

(defun %escaped-display-string (value)
  (with-output-to-string (out)
    (loop for char across (princ-to-string value)
          do (case char
        (#\Newline (write-string "\\n" out))
        (#\Return (write-string "\\r" out))
        (#\Tab (write-string "\\t" out))
        (t
          (if (or (< (char-code char) 32) (= (char-code char) 127)) (format out "\\x~2,'0X;" (char-code char))
            (write-char char out)))))))

(defun %copy-structured-value* (value seen)
  (or
    (gethash value seen)
    (cond
      ((hash-table-p value)
        (let ((copy
              (make-hash-table :test (hash-table-test value) :size (hash-table-count value))))
          (setf (gethash value seen) copy)
          (maphash
            (lambda (key table-value)
              (setf (gethash (%copy-structured-value* key seen) copy) (%copy-structured-value* table-value seen)))
            value)
          copy))
      ((stringp value)
        (let ((copy (copy-seq value)))
          (setf (gethash value seen) copy)
          copy))
      ((vectorp value)
        (let ((copy (copy-seq value)))
          (setf (gethash value seen) copy)
          (dotimes (index (length copy) copy)
            (setf (aref copy index) (%copy-structured-value* (aref copy index) seen)))))
      ((consp value)
        (let ((copy (cons nil nil)))
          (setf (gethash value seen) copy)
          (setf (car copy) (%copy-structured-value* (car value) seen)
                (cdr copy) (%copy-structured-value* (cdr value) seen))
          copy))
      (t value))))

(defun %copy-structured-value (value)
  (if (or (consp value) (hash-table-p value) (stringp value) (vectorp value)) (%copy-structured-value* value (make-hash-table :test #'eq))
    value))

(defun %copy-result-table (table)
  (let ((copy
        (make-hash-table :test (hash-table-test table) :size (hash-table-count table))))
    (maphash
      (lambda (key value)
        (setf
          (gethash (%copy-structured-value key) copy)
          (%copy-structured-value value)))
      table)
    copy))

(defun %copy-effect-handlers (effect-handlers)
  (let ((copy (make-hash-table :test #'equal :size (hash-table-count effect-handlers))))
    (maphash
      (lambda (key value)
        (setf (gethash (%normalize-handler-key key) copy) value))
      effect-handlers)
    copy))
