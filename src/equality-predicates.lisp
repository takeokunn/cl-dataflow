(in-package #:cl-dataflow)

;;;; Structural equality predicates for pipelines, state machines, and contexts,
;;;; plus a state reachability predicate. Equality compares the deterministic plist
;;;; serialisations (GRAPH-EQUAL-P already does this for graphs), so runtime
;;;; closures -- node handlers, guards, actions, effect handlers -- are ignored.

(defun pipeline-equal-p (pipeline-a pipeline-b)
  "Return true when PIPELINE-A and PIPELINE-B have the same structure: identical
graphs, stage order, and metadata. Node handlers are not compared (see
PIPELINE-TO-PLIST)."
  (equal (pipeline-to-plist pipeline-a) (pipeline-to-plist pipeline-b)))

(defun state-machine-equal-p (machine-a machine-b)
  "Return true when MACHINE-A and MACHINE-B have the same structure: identical
state, initial state, metadata, and transitions (by from/event/to/metadata). Guards
and actions are not compared (see STATE-MACHINE-TO-PLIST)."
  (equal (state-machine-to-plist machine-a) (state-machine-to-plist machine-b)))

(defun context-equal-p (context-a context-b)
  "Return true when CONTEXT-A and CONTEXT-B have the same observable state: identical
stored values, events, effects, trace, metadata, state, and result. Effect handlers
are not compared (see CONTEXT-TO-PLIST)."
  (equal (context-to-plist context-a) (context-to-plist context-b)))

(defun state-machine-reachable-p (machine from to)
  "Return true when state TO is reachable from state FROM in MACHINE by following
zero or more transitions (so FROM = TO is trivially reachable). States are compared
case-insensitively."
  (and (member (%normalize-name to)
               (state-machine-reachable-states machine :from from)
               :test #'string-equal)
       t))
