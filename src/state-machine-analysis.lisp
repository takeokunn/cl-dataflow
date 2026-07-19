(in-package #:cl-dataflow)

;;;; Structural analysis and rendering for state machines. A state machine is a
;;;; labelled directed graph over states, so these mirror the graph analysis and
;;;; export helpers: deterministic, name-sorted output and pure work-list traversal.

(defun %sorted-unique-strings (strings)
  (let ((seen (make-hash-table :test #'equal))
        (result '()))
    (dolist (string strings)
      (unless (gethash string seen)
        (setf (gethash string seen) t)
        (push string result)))
    (sort result #'string<)))

(defun state-machine-states (machine)
  "Return every distinct state of MACHINE -- its initial state, current state, and
every FROM/TO mentioned by a transition -- ordered lexicographically."
  (%sorted-unique-strings
   (list* (state-machine-state machine)
          (state-machine-initial-state machine)
          (loop for transition in (%state-machine-transitions-list machine)
                collect (transition-from transition)
                collect (transition-to transition)))))

(defun state-machine-event-types (machine)
  "Return every distinct event type MACHINE reacts to, ordered lexicographically."
  (%sorted-unique-strings
   (mapcar #'transition-event-type (%state-machine-transitions-list machine))))

(defun %state-machine-successor-table (machine)
  "State -> sorted list of directly reachable states (following transitions)."
  (let ((table (%make-result-table)))
    (dolist (state (state-machine-states machine))
      (setf (gethash state table) '()))
    (let ((seen (make-hash-table :test #'equal)))
      (dolist (transition (%state-machine-transitions-list machine))
        (let ((pair (cons (transition-from transition) (transition-to transition))))
          (unless (gethash pair seen)
            (setf (gethash pair seen) t)
            (push (transition-to transition)
                  (gethash (transition-from transition) table))))))
    (maphash (lambda (state tos)
               (setf (gethash state table) (sort tos #'string<)))
             table)
    table))

(defun state-machine-reachable-states
    (machine &key (from (state-machine-initial-state machine)))
  "Return the states reachable from FROM (default: the initial state) by following
zero or more transitions, ordered lexicographically. FROM is always included."
  (let ((start (%normalize-name from))
        (successors (%state-machine-successor-table machine))
        (visited (make-hash-table :test #'equal))
        (stack '()))
    (setf (gethash start visited) t)
    (push start stack)
    (loop while stack do
      (let ((state (pop stack)))
        (dolist (next (gethash state successors))
          (unless (gethash next visited)
            (setf (gethash next visited) t)
            (push next stack)))))
    (sort (%hash-table-keys visited) #'string<)))

(defun state-machine-unreachable-states (machine)
  "Return the states that cannot be reached from MACHINE's initial state, ordered
lexicographically. An empty result means every state is reachable."
  (let ((reachable (make-hash-table :test #'equal)))
    (dolist (state (state-machine-reachable-states machine))
      (setf (gethash state reachable) t))
    (remove-if (lambda (state) (gethash state reachable))
               (state-machine-states machine))))

(defun state-machine-terminal-states (machine)
  "Return the states that have no outgoing transition (dead ends), ordered
lexicographically."
  (let ((has-outgoing (make-hash-table :test #'equal)))
    (dolist (transition (%state-machine-transitions-list machine))
      (setf (gethash (transition-from transition) has-outgoing) t))
    (remove-if (lambda (state) (gethash state has-outgoing))
               (state-machine-states machine))))

(defun state-machine-deterministic-p (machine)
  "Return true when no two transitions share the same FROM state and event type.

This is structural determinism and ignores guards: because guards let several
transitions legitimately share a (state, event) pair and be chosen at runtime, a
NIL result does not mean the machine is ill-formed -- it means resolution depends
on guards rather than on the (state, event) pair alone."
  (let ((seen (make-hash-table :test #'equal)))
    (dolist (transition (%state-machine-transitions-list machine) t)
      (let ((key (cons (transition-from transition)
                       (transition-event-type transition))))
        (when (gethash key seen)
          (return nil))
        (setf (gethash key seen) t)))))

(defun %sorted-transition-snapshots (machine)
  "Transition copies ordered by (from, event-type, to) for stable rendering."
  (sort (%state-machine-transitions-list machine)
        (lambda (left right)
          (let ((left-key (list (transition-from left) (transition-event-type left)
                                (transition-to left)))
                (right-key (list (transition-from right) (transition-event-type right)
                                 (transition-to right))))
            (loop for l in left-key
                  for r in right-key
                  do (cond ((string< l r) (return t))
                           ((string> l r) (return nil)))
                  finally (return nil))))))

(defun state-machine->dot (machine &key (name "S"))
  "Render MACHINE as a Graphviz DOT digraph. States are nodes, transitions are
edges labelled with their event type, and a point-shaped source marks the initial
state. Output is deterministic (states name-sorted, transitions endpoint-sorted)."
  (with-output-to-string (out)
    (format out "digraph ~A {~%" (%dot-escape name))
    (format out "  __start [shape=point];~%")
    (format out "  __start -> \"~A\";~%"
            (%dot-escape (state-machine-initial-state machine)))
    (dolist (state (state-machine-states machine))
      (format out "  \"~A\";~%" (%dot-escape state)))
    (dolist (transition (%sorted-transition-snapshots machine))
      (format out "  \"~A\" -> \"~A\" [label=\"~A\"];~%"
              (%dot-escape (transition-from transition))
              (%dot-escape (transition-to transition))
              (%dot-escape (transition-event-type transition))))
    (format out "}~%")))

(defun %state-machine-ids (states)
  (loop for state in states
        for index from 0
        collect (cons state (format nil "s~D" index))))

(defun state-machine->mermaid (machine)
  "Render MACHINE as a Mermaid stateDiagram-v2 string. State names become quoted
labels on generated ids, so names with spaces or punctuation render cleanly; the
initial state is linked from Mermaid's [*] start marker."
  (let* ((states (state-machine-states machine))
         (ids (%state-machine-ids states)))
    (flet ((id-for (state) (cdr (assoc state ids :test #'equal))))
      (with-output-to-string (out)
        (format out "stateDiagram-v2~%")
        (dolist (state states)
          (format out "  state \"~A\" as ~A~%" (%mermaid-escape state) (id-for state)))
        (format out "  [*] --> ~A~%"
                (id-for (state-machine-initial-state machine)))
        (dolist (transition (%sorted-transition-snapshots machine))
          (format out "  ~A --> ~A: ~A~%"
                  (id-for (transition-from transition))
                  (id-for (transition-to transition))
                  (%mermaid-escape (transition-event-type transition))))))))
