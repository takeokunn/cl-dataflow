(in-package #:cl-dataflow)

;;;; Rendering and serialisation for graphs. Every renderer walks a deterministic
;;;; snapshot -- nodes name-sorted, edges sorted by their endpoints and ports -- so
;;;; the output of GRAPH->DOT / GRAPH->MERMAID / GRAPH-TO-PLIST is stable across
;;;; runs and safe to diff or golden-test.

(defun %sorted-edge-snapshots (graph)
  "Edge copies of GRAPH ordered by (from, from-port, to, to-port) for stable output."
  (sort (mapcar #'%copy-edge-snapshot (%graph-edges-list graph))
        (lambda (left right)
          (let ((left-key (list (edge-from left) (edge-from-port left)
                                (edge-to left) (edge-to-port left)))
                (right-key (list (edge-from right) (edge-from-port right)
                                 (edge-to right) (edge-to-port right))))
            (loop for l in left-key
                  for r in right-key
                  do (cond ((string< l r) (return t))
                           ((string> l r) (return nil)))
                  finally (return nil))))))

(defun %replace-substring (string old new)
  (with-output-to-string (out)
    (let ((start 0)
          (old-length (length old)))
      (loop for position = (search old string :start2 start)
            while position
            do (write-string string out :start start :end position)
               (write-string new out)
               (setf start (+ position old-length)))
      (write-string string out :start start))))

(defun %dot-escape (string)
  "Escape STRING for use inside a DOT double-quoted identifier."
  (%replace-substring (%replace-substring string "\\" "\\\\") "\"" "\\\""))

(defun graph->dot (graph &key (name "G"))
  "Render GRAPH as a Graphviz DOT digraph string.

Nodes are emitted in name order and edges in endpoint order, so the text is
deterministic. Each edge is labelled with its from-port -> to-port so parallel
edges across different ports stay distinguishable."
  (with-output-to-string (out)
    (format out "digraph ~A {~%" (%dot-escape name))
    (dolist (node-name (%graph-node-name-set graph))
      (format out "  \"~A\";~%" (%dot-escape node-name)))
    (dolist (edge (%sorted-edge-snapshots graph))
      (format out "  \"~A\" -> \"~A\" [label=\"~A -> ~A\"];~%"
              (%dot-escape (edge-from edge))
              (%dot-escape (edge-to edge))
              (%dot-escape (edge-from-port edge))
              (%dot-escape (edge-to-port edge))))
    (format out "}~%")))

(defun %mermaid-escape (string)
  "Escape STRING for use inside a Mermaid bracketed label."
  (%replace-substring string "\"" "&quot;"))

(defun %mermaid-node-ids (node-names)
  "Alist mapping each node name to a syntactically safe Mermaid id (n0, n1, ...)."
  (loop for name in node-names
        for index from 0
        collect (cons name (format nil "n~D" index))))

(defun graph->mermaid (graph &key (direction "TD"))
  "Render GRAPH as a Mermaid flowchart string with the given DIRECTION (\"TD\",
\"LR\", ...). Node names become quoted labels on generated ids, so names with
spaces or punctuation render cleanly; edges carry their from-port -> to-port."
  (let* ((names (%graph-node-name-set graph))
         (ids (%mermaid-node-ids names)))
    (flet ((id-for (name) (cdr (assoc name ids :test #'equal))))
      (with-output-to-string (out)
        (format out "flowchart ~A~%" direction)
        (dolist (name names)
          (format out "  ~A[\"~A\"]~%" (id-for name) (%mermaid-escape name)))
        (dolist (edge (%sorted-edge-snapshots graph))
          (format out "  ~A -->|~A -> ~A| ~A~%"
                  (id-for (edge-from edge))
                  (%mermaid-escape (edge-from-port edge))
                  (%mermaid-escape (edge-to-port edge))
                  (id-for (edge-to edge))))))))

(defun %node-to-plist (node)
  (list :name (node-name node)
        :inputs (node-inputs node)
        :outputs (node-outputs node)
        :metadata (node-metadata node)))

(defun %edge-to-plist (edge)
  (list :from (edge-from edge)
        :from-port (edge-from-port edge)
        :to (edge-to edge)
        :to-port (edge-to-port edge)
        :metadata (edge-metadata edge)))

(defun graph-to-plist (graph)
  "Serialise GRAPH's structure to a plist of the form
  (:metadata ... :nodes (node-plist ...) :edges (edge-plist ...)).

Nodes are name-ordered and edges endpoint-ordered. Node handlers are runtime
closures and are deliberately NOT serialised; PLIST-TO-GRAPH rebuilds nodes with
the default identity handler. The round trip therefore preserves topology, ports
and metadata -- everything needed to persist, diff, or transmit a graph's shape."
  (let ((nodes (%graph-nodes-table graph)))
    (list :metadata (graph-metadata graph)
          :nodes (mapcar (lambda (name)
                           (%node-to-plist (gethash name nodes)))
                         (%graph-node-name-set graph))
          :edges (mapcar #'%edge-to-plist (%sorted-edge-snapshots graph)))))

(defun plist-to-graph (plist)
  "Rebuild a graph from a plist produced by GRAPH-TO-PLIST. Reconstructed nodes
use the default identity handler (see GRAPH-TO-PLIST for why handlers are not
serialised)."
  (let ((graph (make-graph :metadata (getf plist :metadata))))
    (dolist (node-plist (getf plist :nodes))
      (add-node graph
                (make-node (getf node-plist :name)
                           :inputs (getf node-plist :inputs)
                           :outputs (getf node-plist :outputs)
                           :metadata (getf node-plist :metadata))))
    (dolist (edge-plist (getf plist :edges))
      (let ((edge (add-edge graph
                            (getf edge-plist :from)
                            (getf edge-plist :to)
                            :from-port (getf edge-plist :from-port)
                            :to-port (getf edge-plist :to-port))))
        (setf (edge-metadata edge) (getf edge-plist :metadata))))
    graph))
