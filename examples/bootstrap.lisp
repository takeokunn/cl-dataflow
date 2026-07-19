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
    "src/graph-algorithms.lisp"
    "src/graph-export.lisp"
    "src/graph-builders.lisp"
    "src/graph-paths.lisp"
    "src/graph-metrics.lisp"
    "src/state-machine-analysis.lisp"
    "src/state-machine-execution.lisp"
    "src/state-machine-builders.lisp"
    "src/combinators.lisp"
    "src/streams.lisp"
    "src/stream-extras.lisp"
    "src/stream-ops.lisp"
    "src/observability.lisp"
    "src/effects-ext.lisp"
    "src/pipeline-ext.lisp"
    "src/events-ext.lisp"
    "src/introspection.lisp"
    "src/testing.lisp"))

(defun use-interpreted-loading-when-available ()
  (let* ((package (find-package "SB-EXT"))
         (evaluator-mode (and package (find-symbol "*EVALUATOR-MODE*" package))))
    (when evaluator-mode
      (setf (symbol-value evaluator-mode) :interpret))))

;; The graph runtime reads CL-PROLOG: symbols, so the cl-prolog system must be
;; loaded before any cl-dataflow source file is read. find-symbol avoids a
;; read-time dependency on the ASDF package existing in this bootstrap file.
(defun ensure-dependencies ()
  (require :asdf)
  (funcall (find-symbol "LOAD-SYSTEM" "ASDF") "cl-prolog"))

(progn
  (defun load-cl-dataflow ()
    (use-interpreted-loading-when-available)
    (ensure-dependencies)
    (let ((root (repository-directory)))
      (dolist (source-file *cl-dataflow-source-files*)
        (load (merge-pathnames source-file root)))))
  (load-cl-dataflow))
