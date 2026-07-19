(in-package #:cl-dataflow)

;;;; Graph mutation and composition. The base graph API is append-only (ADD-NODE /
;;;; ADD-EDGE); these fill in removal, induced subgraphs, disjoint merge, and node
;;;; relabelling. In-place removals mutate GRAPH and mirror the add-* return
;;;; conventions; the derivations (subgraph, merge, relabel) return fresh graphs
;;;; and never alter their inputs.

(defun %edge-touches-node-p (edge name)
  (or (equal (edge-from edge) name)
      (equal (edge-to edge) name)))

(defun remove-node (graph node)
  "Remove NODE and every edge incident to it from GRAPH, in place, and return
GRAPH. Signals NODE-NOT-FOUND-ERROR when NODE is absent."
  (let ((name (%node-designator-name node)))
    (%ensure-graph-node graph name)
    (remhash name (%graph-nodes-table graph))
    (setf (%graph-edges-list graph)
          (remove-if (lambda (edge) (%edge-touches-node-p edge name))
                     (%graph-edges-list graph)))
    graph))

(defun remove-edge (graph from to &key (from-port "value") (to-port "value"))
  "Remove the edge FROM:FROM-PORT -> TO:TO-PORT from GRAPH, in place. Ports default
to \"value\", matching ADD-EDGE. Returns T when a matching edge was removed and NIL
when none existed."
  (let ((target (%edge-identity-key (%node-designator-name from)
                                    (%normalize-name from-port)
                                    (%node-designator-name to)
                                    (%normalize-name to-port)))
        (edges (%graph-edges-list graph)))
    (let ((remaining (remove-if (lambda (edge)
                                  (equal (%edge-sort-key edge) target))
                                edges)))
      (setf (%graph-edges-list graph) remaining)
      (< (length remaining) (length edges)))))

(defun %wanted-node-set (graph node-names)
  "A name -> t table of the members of NODE-NAMES that actually exist in GRAPH."
  (let ((wanted (make-hash-table :test #'equal))
        (nodes (%graph-nodes-table graph)))
    (dolist (name node-names wanted)
      (let ((normalized (%node-designator-name name)))
        (when (gethash normalized nodes)
          (setf (gethash normalized wanted) t))))))

(defun %readd-edge (result edge)
  "Re-create EDGE (endpoints, ports, metadata) inside RESULT."
  (let ((added (add-edge result (edge-from edge) (edge-to edge)
                         :from-port (edge-from-port edge)
                         :to-port (edge-to-port edge))))
    (setf (edge-metadata added) (edge-metadata edge))
    added))

(defun graph-subgraph (graph node-names)
  "Return the subgraph of GRAPH induced by NODE-NAMES: copies of those nodes that
exist in GRAPH, plus every edge whose endpoints are both in the set (ports and
metadata preserved). GRAPH's metadata is copied; names not present in GRAPH are
ignored. GRAPH is not modified."
  (let ((wanted (%wanted-node-set graph node-names))
        (nodes (%graph-nodes-table graph))
        (result (make-graph :metadata (graph-metadata graph))))
    (dolist (name (sort (%hash-table-keys wanted) #'string<))
      (add-node result (%copy-node-snapshot (gethash name nodes))))
    (dolist (edge (reverse (%graph-edges-list graph)))
      (when (and (gethash (edge-from edge) wanted)
                 (gethash (edge-to edge) wanted))
        (%readd-edge result edge)))
    result))

(defun graph-merge (graph-a graph-b &key metadata)
  "Return a new graph containing every node and edge of GRAPH-A and GRAPH-B, with
ports and metadata preserved. Node names must be disjoint; a name present in both
signals GRAPH-ERROR. METADATA sets the merged graph's metadata (default: a copy of
GRAPH-A's). Neither input is modified."
  (let ((result (make-graph :metadata (if metadata metadata (graph-metadata graph-a)))))
    (dolist (source (list graph-a graph-b))
      (let ((nodes (%graph-nodes-table source)))
        (dolist (name (sort (%hash-table-keys nodes) #'string<))
          (when (find-node result name)
            (%signal-graph-error
             result
             (format nil "Cannot merge graphs: duplicate node name ~A" name)))
          (add-node result (%copy-node-snapshot (gethash name nodes))))))
    (dolist (source (list graph-a graph-b))
      (dolist (edge (reverse (%graph-edges-list source)))
        (%readd-edge result edge)))
    result))

(defun %relabel-name (name old new)
  (if (equal name old) new name))

(defun graph-relabel-node (graph old-name new-name)
  "Return a new graph identical to GRAPH but with node OLD-NAME renamed to
NEW-NAME, updating every incident edge. Signals NODE-NOT-FOUND-ERROR when OLD-NAME
is absent and GRAPH-ERROR when NEW-NAME already names a different node. GRAPH is
not modified."
  (let ((old (%node-designator-name old-name))
        (new (%node-designator-name new-name))
        (nodes (%graph-nodes-table graph)))
    (%ensure-graph-node graph old)
    (when (gethash new nodes)
      (%signal-graph-error
       graph
       (format nil "Cannot relabel to existing node name ~A" new)))
    (let ((result (make-graph :metadata (graph-metadata graph))))
      (dolist (name (%graph-node-name-set graph))
        (let ((snapshot (%copy-node-snapshot (gethash name nodes))))
          (when (equal name old)
            (setf (node-name snapshot) new))
          (add-node result snapshot)))
      (dolist (edge (reverse (%graph-edges-list graph)))
        (let ((added (add-edge result
                               (%relabel-name (edge-from edge) old new)
                               (%relabel-name (edge-to edge) old new)
                               :from-port (edge-from-port edge)
                               :to-port (edge-to-port edge))))
          (setf (edge-metadata added) (edge-metadata edge))))
      result)))
