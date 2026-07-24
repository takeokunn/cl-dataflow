(in-package #:cl-user)

(defparameter *bootstrap-pathname* (or *load-truename* *load-pathname* *default-pathname-defaults*))

(defun bootstrap-directory ()
  (make-pathname :name nil :type nil :defaults *bootstrap-pathname*))

(defun repository-directory ()
  (merge-pathnames #P"../" (bootstrap-directory)))

(defparameter *cl-dataflow-source-files* '("src/package.lisp"
    "src/core-normalization.lisp"
    "src/core-copying.lisp"
    "src/core-slot-accessors.lisp"
    "src/core-runtime-helpers.lisp"
    "src/core-conditions.lisp"
    "src/core-models-classes.lisp"
    "src/core-models-copying.lisp"
    "src/core-models-slot-accessors.lisp"
    "src/core-models-constructors.lisp"
    "src/core-context-accessors.lisp"
    "src/graph-runtime-validation.lisp"
    "src/graph-runtime-prolog.lisp"
    "src/graph-runtime-topology.lisp"
    "src/graph-runtime-bindings.lisp"
    "src/graph-runtime-builders.lisp"
    "src/protocols.lisp"
    "src/events.lisp"
    "src/effects.lisp"
    "src/state-machine-macros.lisp"
    "src/state-machine-runtime-core.lisp"
    "src/state-machine-runtime-cps.lisp"
    "src/state-machine-runtime-api.lisp"
    "src/pipeline-macros.lisp"
    "src/pipeline-runtime.lisp"
    "src/graph-algorithms.lisp"
    "src/graph-export.lisp"
    "src/graph-builders.lisp"
    "src/graph-closure.lisp"
    "src/graph-paths.lisp"
    "src/graph-shortest-path.lisp"
    "src/graph-flow.lisp"
    "src/graph-eulerian.lisp"
    "src/graph-metrics.lisp"
    "src/graph-connectivity.lisp"
    "src/graph-algebra.lisp"
    "src/graph-criticality.lisp"
    "src/state-machine-analysis.lisp"
    "src/state-machine-execution.lisp"
    "src/state-machine-builders.lisp"
    "src/combinators.lisp"
    "src/contracts.lisp"
    "src/streams.lisp"
    "src/stream-extras.lisp"
    "src/stream-ops.lisp"
    "src/stream-stats.lisp"
    "src/stream-search.lisp"
    "src/observability.lisp"
    "src/effects-ext.lisp"
    "src/pipeline-ext.lisp"
    "src/pipeline-iteration.lisp"
    "src/events-ext.lisp"
    "src/introspection.lisp"
    "src/context-serialization.lisp"
    "src/equality-predicates.lisp"
    "src/reactive.lisp"
    "src/reactive-ops.lisp"
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
