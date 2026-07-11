(in-package #:cl-dataflow)

(defun %normalize-name (value)
  (etypecase value
    (string value)
    (symbol (symbol-name value))
    (t (princ-to-string value))))

(defun %normalize-handler-key (value)
  (string-downcase (%normalize-name value)))

(defun %normalize-port-list (ports)
  (cond
    ((null ports) '("value"))
    ((listp ports) (mapcar #'%normalize-name ports))
    (t (list (%normalize-name ports)))))

(defun %normalize-unique-port-list (ports kind)
  (let ((normalized (%normalize-port-list ports))
        (seen (make-hash-table :test #'equal)))
    (dolist (port normalized normalized)
      (when (gethash port seen)
        (error 'invalid-input-error
               :expected 'port-list
               :value normalized
               :detail (format nil "Duplicate ~A port: ~A" kind port)))
      (setf (gethash port seen) t))))

(defun %normalize-metadata (metadata)
  (if metadata (copy-tree metadata) '()))

(defun %plist-value (plist key &optional default)
  (let ((position (position key plist :test #'equal)))
    (if position
        (nth (1+ position) plist)
        default)))

(defun %normalize-structured-input (value ports)
  (let ((port-count (length ports))
        (first-port (first ports)))
    (cond
      ((hash-table-p value)
       (if (= port-count 1)
           (gethash first-port value)
           (loop for port in ports
                 collect (cons port (gethash port value)))))
      ((and (listp value) (every #'consp value))
       (if (= port-count 1)
           (cdr (assoc first-port value :test #'equal))
           (loop for port in ports
                 for cell = (assoc port value :test #'equal)
                 collect (cons port (and cell (cdr cell))))))
      ((and (listp value) (evenp (length value)))
       (if (= port-count 1)
           (%plist-value value first-port)
           (loop for (key val) on value by #'cddr
                 collect (cons (%normalize-name key) val))))
      (t value))))

(defun %normalize-output-structure (value ports)
  (let ((first-port (first ports)))
    (cond
      ((null ports) value)
      ((hash-table-p value)
       (loop for port in ports
             collect (cons port (gethash port value))))
      ((and (listp value) (every #'consp value))
       (loop for port in ports
             for cell = (assoc port value :test #'equal)
             collect (cons port (and cell (cdr cell)))))
      ((and (listp value) (evenp (length value)))
       (loop for (key val) on value by #'cddr
             collect (cons (%normalize-name key) val)))
      (t (list (cons first-port value))))))

(defun %node-designator-name (designator)
  (typecase designator
    (node (node-name designator))
    (t (%normalize-name designator))))
