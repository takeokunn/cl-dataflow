(in-package #:cl-user)

(defparameter *bootstrap-pathname* (or *load-truename* *load-pathname* *default-pathname-defaults*))

(defun bootstrap-directory ()
  (make-pathname :name nil :type nil :defaults *bootstrap-pathname*))

(defun repository-directory ()
  (merge-pathnames #P"../" (bootstrap-directory)))

(defparameter *cl-dataflow-source-files* '("src/package.lisp"
    "src/core.lisp"
    "src/protocols.lisp"
    "src/events.lisp"
    "src/effects.lisp"
    "src/state-machine.lisp"
    "src/pipeline.lisp"
    "src/testing.lisp"))

(defun use-interpreted-loading-when-available ()
  (let* ((package (find-package "SB-EXT"))
         (evaluator-mode (and package (find-symbol "*EVALUATOR-MODE*" package))))
    (when evaluator-mode
      (setf (symbol-value evaluator-mode) :interpret))))

(progn
  (defun load-cl-dataflow ()
    (use-interpreted-loading-when-available)
    (let ((root (repository-directory)))
      (dolist (source-file *cl-dataflow-source-files*)
        (load (merge-pathnames source-file root)))))
  (load-cl-dataflow))
