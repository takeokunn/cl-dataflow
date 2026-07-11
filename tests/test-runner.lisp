(in-package #:cl-dataflow.test)

(defvar *tests* '())

(defmacro deftest (name &body body)
  `(push (list ',name (lambda () ,@body)) *tests*))

(defun run-tests (&key (start 0) end)
  (let ((tests (subseq (reverse *tests*) start end))
        (failures '()))
    (dolist (test tests)
      (handler-case
          (funcall (second test))
        (error (error)
          (push (list (first test) error) failures))))
    (when failures
      (dolist (failure (reverse failures))
        (format t "~&[FAIL] ~A: ~A~%"
                (first failure)
                (second failure)))
      (error "~D test(s) failed: ~{~A~^, ~}"
             (length failures)
             (mapcar #'car failures)))
    (format t "~&~D test(s) passed.~%" (length tests))
    t))
