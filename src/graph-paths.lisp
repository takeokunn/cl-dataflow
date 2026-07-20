(in-package #:cl-dataflow)

;;;; Path- and order-oriented graph algorithms: transitive closure/reduction,
;;;; topological rank, longest (critical) path, all simple paths, an ordered
;;;; cycle witness, and weighted shortest distance. Structural traversals reuse
;;;; the one-shot adjacency snapshot and stay iterative; GRAPH-FIND-CYCLE reuses
;;;; the (iterative) SCC + subgraph + GRAPH-PATH machinery so it is safe on deep
;;;; graphs, and GRAPH-ALL-PATHS is an explicitly exponential enumerator for
;;;; small graphs.

(defun %closure-edge-ports (from-node to-node)
  "Default (from-port to-port) for a synthesised edge between two nodes: their
first output/input ports, which always exist. Synthesised edges therefore stay
valid even when nodes use non-default port names."
  (values (first (%node-outputs-list from-node))
          (first (%node-inputs-list to-node))))

(defun %add-derived-edge (result from-name to-name from-node to-node)
  (multiple-value-bind (from-port to-port) (%closure-edge-ports from-node to-node)
    (add-edge result from-name to-name :from-port from-port :to-port to-port)))

(defun graph-transitive-closure (graph)
  "Return a new graph with the same nodes as GRAPH and an edge A -> B for every
ordered pair where B is reachable from A through one or more edges (so a node on a
cycle gains a self-edge). Synthesised edges use each node's first ports; GRAPH is
not modified."
  (let ((names (%graph-node-name-set graph))
        (adjacency (%graph-adjacency-snapshot graph :successors))
        (nodes (%graph-nodes-table graph))
        (result (make-graph :metadata (graph-metadata graph))))
    (dolist (name names)
      (add-node result (%copy-node-snapshot (gethash name nodes))))
    (dolist (name names)
      (dolist (reached (%reachable-closure adjacency name))
        (%add-derived-edge result name reached
                           (gethash name nodes) (gethash reached nodes))))
    result))

(defun %reachable-through-successors-p (successors from to)
  "Whether TO is reachable from FROM through SUCCESSORS, with early exit."
  (let ((visited (%make-result-table))
        (worklist (copy-list (gethash from successors))))
    (loop while worklist do
      (let ((name (pop worklist)))
        (when (equal name to)
          (return-from %reachable-through-successors-p t))
        (unless (gethash name visited)
          (setf (gethash name visited) t)
          (dolist (successor (gethash name successors))
            (unless (gethash successor visited)
              (push successor worklist)))))))
  nil)

(defun graph-transitive-reduction (graph)
  "Return the transitive reduction of the (acyclic) GRAPH: the minimal edge set
with the same reachability. An edge U -> V is dropped when V is still reachable
from U through some other direct successor. Signals GRAPH-CYCLE-ERROR when GRAPH
is cyclic (the reduction is only unique on a DAG). GRAPH is not modified."
  (topological-sort graph)
  (let ((names (%graph-node-name-set graph))
        (successors (%graph-adjacency-snapshot graph :successors))
        (reachable (make-hash-table :test #'equal))
        (nodes (%graph-nodes-table graph))
        (result (make-graph :metadata (graph-metadata graph))))
    (dolist (name names)
      (add-node result (%copy-node-snapshot (gethash name nodes))))
    (labels ((reachable-p (from to)
               (let ((key (cons from to)))
                 (multiple-value-bind (cached present-p) (gethash key reachable)
                   (if present-p
                       cached
                       (setf (gethash key reachable)
                             (%reachable-through-successors-p successors from to)))))))
      (dolist (u names)
        (dolist (v (gethash u successors))
          (unless (some (lambda (w)
                          (and (not (equal w v))
                               (reachable-p w v)))
                        (gethash u successors))
            (%add-derived-edge result u v (gethash u nodes) (gethash v nodes))))))
    result))

(defun graph-topological-rank (graph)
  "Return an alist (NAME . RANK) where RANK is the length of the longest path from
any source (indegree-0 node) to NAME; sources have rank 0. Signals
GRAPH-CYCLE-ERROR when GRAPH is cyclic. Ordered by name."
  (let ((order (topological-sort graph))
        (rank (%make-result-table))
        (successors (%graph-adjacency-snapshot graph :successors)))
    (dolist (node order)
      (setf (gethash (node-name node) rank) 0))
    (dolist (node order)
      (let ((distance (gethash (node-name node) rank)))
        (dolist (successor (gethash (node-name node) successors))
          (setf (gethash successor rank)
                (max (gethash successor rank) (1+ distance))))))
    (sort (loop for name being the hash-keys of rank using (hash-value value)
                collect (cons name value))
          #'string< :key #'car)))

(defun %longest-path-dp (order successors)
  "Return (VALUES DISTANCE-TABLE PREV-TABLE) for the longest path ending at each
node, over nodes in topological ORDER."
  (let ((distance (%make-result-table))
        (previous (%make-result-table)))
    (dolist (node order)
      (setf (gethash (node-name node) distance) 0))
    (dolist (node order)
      (let ((name (node-name node)))
        (dolist (successor (gethash name successors))
          (when (> (1+ (gethash name distance)) (gethash successor distance))
            (setf (gethash successor distance) (1+ (gethash name distance))
                  (gethash successor previous) name)))))
    (values distance previous)))

(defun %longest-path-endpoint (order distance)
  (let ((best-name nil)
        (best-distance -1))
    (dolist (node order best-name)
      (let ((name (node-name node)))
        (when (> (gethash name distance) best-distance)
          (setf best-distance (gethash name distance)
                best-name name))))))

(defun graph-longest-path (graph)
  "Return the node names of a longest path in the (acyclic) GRAPH, from a source to
the deepest reachable node. Returns NIL for an empty graph and a single-element
list for a graph with no edges. Signals GRAPH-CYCLE-ERROR when GRAPH is cyclic."
  (let ((order (topological-sort graph)))
    (multiple-value-bind (distance previous)
        (%longest-path-dp order (%graph-adjacency-snapshot graph :successors))
      (let ((endpoint (%longest-path-endpoint order distance)))
        (when endpoint
          (let ((path (list endpoint))
                (cursor endpoint))
            (loop for prior = (gethash cursor previous)
                  while prior
                  do (push prior path)
                     (setf cursor prior))
            path))))))

(defun %path-sort-key (path)
  (format nil "~{~A~}"
          (loop for name in path
                collect name
                collect #\Nul)))

(defun %validate-non-negative-limit (name value)
  (when (and value (or (not (integerp value)) (minusp value)))
    (error 'invalid-input-error
           :expected '(or null (integer 0 *))
           :value value
           :detail (format nil "~A must be NIL or a non-negative integer." name))))

(defun %signal-path-limit-exceeded (limit)
  (error 'invalid-input-error
         :expected 'path-count-within-max-paths
         :value limit
         :detail (format nil "GRAPH-ALL-PATHS exceeded MAX-PATHS (~D)." limit)))

(defun graph-all-paths (graph from to &key (max-paths 10000) max-depth)
  "Return every simple path (no repeated node) from FROM to TO as a list of
name-lists, ordered deterministically. FROM = TO yields the single trivial path
(FROM). Enumeration is exponential in the worst case and intended for small graphs;
MAX-PATHS bounds the number of returned paths (NIL disables the bound) and
MAX-DEPTH bounds the number of edges in a path. Signals NODE-NOT-FOUND-ERROR for
unknown endpoints."
  (%validate-non-negative-limit :max-paths max-paths)
  (%validate-non-negative-limit :max-depth max-depth)
  (let ((from-name (%node-designator-name from))
        (to-name (%node-designator-name to)))
    (%ensure-graph-node graph from-name)
    (%ensure-graph-node graph to-name)
    (when (eql max-paths 0)
      (return-from graph-all-paths '()))
    (let ((successors (%graph-adjacency-snapshot graph :successors))
          (visited (make-hash-table :test #'equal))
          (results '())
          (path-count 0))
      (labels ((record-path (path)
                 (when (and max-paths (>= path-count max-paths))
                   (%signal-path-limit-exceeded max-paths))
                 (incf path-count)
                 (push (reverse path) results))
               (walk (current path depth)
                 (cond ((equal current to-name)
                        (record-path path))
                       ((and max-depth (>= depth max-depth))
                        nil)
                       (t
                        (dolist (next (gethash current successors))
                          (unless (gethash next visited)
                            (setf (gethash next visited) t)
                            (walk next (cons next path) (1+ depth))
                            (remhash next visited)))))))
        (setf (gethash from-name visited) t)
        (walk from-name (list from-name) 0))
      (sort (nreverse results) #'string< :key #'%path-sort-key))))

(defun %component-cyclic-p (graph component)
  (or (> (length component) 1)
      (graph-reachable-p graph (first component) (first component))))

(defun graph-find-cycle (graph)
  "Return the node names of one directed cycle in GRAPH (an ordered list whose last
element repeats the first), or NIL when GRAPH is acyclic. Uses the strongly
connected components and a shortest self-returning path within the first cyclic
component, so it is safe on deep graphs."
  (dolist (component (graph-strongly-connected-components graph) nil)
    (when (%component-cyclic-p graph component)
      (let ((start (first component)))
        (return (graph-path (graph-subgraph graph component) start start))))))

(defun %validate-non-negative-edge-value (caller key value)
  (unless (and (realp value) (not (minusp value)))
    (error 'invalid-input-error
           :expected 'non-negative-real
           :value value
           :detail (format nil "~A ~A must be a non-negative real number."
                           caller
                           (%escaped-display-string key))))
  value)

(defun %edge-weight (edge weight-key default-weight caller)
  (let ((weight (getf (edge-metadata edge) weight-key default-weight)))
    (%validate-non-negative-edge-value caller weight-key weight)))

(defun %weighted-adjacency (graph weight-key default-weight)
  "Name -> list of (TO-NAME . COST). Parallel edges collapse to their cheapest."
  (let ((adjacency (%make-result-table)))
    (dolist (name (%graph-node-name-set graph))
      (setf (gethash name adjacency) (make-hash-table :test #'equal)))
    (dolist (edge (%graph-edges-list graph))
      (let* ((bucket (gethash (edge-from edge) adjacency))
             (cost (%edge-weight edge weight-key default-weight "GRAPH-WEIGHTED"))
             (existing (gethash (edge-to edge) bucket)))
        (when (or (null existing) (< cost existing))
          (setf (gethash (edge-to edge) bucket) cost))))
    (let ((result (%make-result-table)))
      (maphash (lambda (name bucket)
                 (setf (gethash name result)
                       (loop for to being the hash-keys of bucket using (hash-value cost)
                             collect (cons to cost))))
               adjacency)
      result)))

(defun %dijkstra-pick (distance settled)
  "The unsettled node in DISTANCE with the smallest tentative cost, or NIL."
  (let ((chosen nil)
        (best nil))
    (maphash (lambda (name cost)
               (unless (gethash name settled)
                 (when (or (null best) (< cost best))
                   (setf best cost chosen name))))
             distance)
    chosen))

(defun %dijkstra-relax (distance name-cost neighbors settled)
  (dolist (edge neighbors)
    (let ((to (car edge))
          (candidate (+ name-cost (cdr edge))))
      (unless (gethash to settled)
        (let ((existing (gethash to distance)))
          (when (or (null existing) (< candidate existing))
            (setf (gethash to distance) candidate)))))))

(defun graph-weighted-distance (graph from to &key weight-key default-weight)
  "Return the minimum total edge weight of a path from FROM to TO (traversing at
least one edge), or NIL when TO is unreachable. Each edge's weight is
(GETF (EDGE-METADATA EDGE) WEIGHT-KEY DEFAULT-WEIGHT); WEIGHT-KEY defaults to
:WEIGHT and DEFAULT-WEIGHT to 1, and weights must be non-negative. FROM = TO
resolves only through a cycle, matching GRAPH-DISTANCE."
  (let ((weight-key (or weight-key :weight))
        (default-weight (or default-weight 1))
        (from-name (%node-designator-name from))
        (to-name (%node-designator-name to)))
    (%ensure-graph-node graph from-name)
    (%ensure-graph-node graph to-name)
    (let ((neighbors (%weighted-adjacency graph weight-key default-weight))
          (distance (make-hash-table :test #'equal))
          (settled (make-hash-table :test #'equal)))
      (%dijkstra-relax distance 0 (gethash from-name neighbors) settled)
      (loop for name = (%dijkstra-pick distance settled)
            while name
            do (setf (gethash name settled) t)
               (%dijkstra-relax distance (gethash name distance)
                                (gethash name neighbors) settled))
      (gethash to-name distance))))

(defun graph-weighted-distances-from (graph from &key weight-key default-weight)
  "Return an alist (NAME . COST) of the minimum total edge weight from FROM to every
node reachable from it (weights from edge metadata exactly as in
GRAPH-WEIGHTED-DISTANCE). FROM appears only if a cycle returns to it. This is
Dijkstra to all targets -- the weighted, all-destinations companion to
GRAPH-DISTANCES-FROM. Ordered by name."
  (let ((weight-key (or weight-key :weight))
        (default-weight (or default-weight 1))
        (from-name (%node-designator-name from)))
    (%ensure-graph-node graph from-name)
    (let ((neighbors (%weighted-adjacency graph weight-key default-weight))
          (distance (make-hash-table :test #'equal))
          (settled (make-hash-table :test #'equal)))
      (%dijkstra-relax distance 0 (gethash from-name neighbors) settled)
      (loop for name = (%dijkstra-pick distance settled)
            while name
            do (setf (gethash name settled) t)
               (%dijkstra-relax distance (gethash name distance)
                                (gethash name neighbors) settled))
      (sort (loop for name being the hash-keys of distance using (hash-value cost)
                  collect (cons name cost))
            #'string< :key #'car))))

(defun %dijkstra-relax-with-previous (distance previous name name-cost neighbors settled)
  (dolist (edge neighbors)
    (let ((to (car edge))
          (candidate (+ name-cost (cdr edge))))
      (unless (gethash to settled)
        (let ((existing (gethash to distance)))
          (when (or (null existing) (< candidate existing))
            (setf (gethash to distance) candidate
                  (gethash to previous) name)))))))

(defun %reconstruct-weighted-path (previous from to)
  "Rebuild the FROM ... TO node sequence from a Dijkstra PREVIOUS table, taking the
first step through PREVIOUS so a FROM = TO cycle yields the whole loop."
  (let ((path (list to))
        (cursor (gethash to previous)))
    (loop
      (push cursor path)
      (when (string= cursor from) (return))
      (setf cursor (gethash cursor previous)))
    path))

(defun graph-weighted-path (graph from to &key weight-key default-weight)
  "Return the node names of a minimum-weight path from FROM to TO (FROM first, TO
last), or NIL when TO is unreachable. Weights come from edge metadata exactly as in
GRAPH-WEIGHTED-DISTANCE, and FROM = TO resolves only through a cycle."
  (let ((weight-key (or weight-key :weight))
        (default-weight (or default-weight 1))
        (from-name (%node-designator-name from))
        (to-name (%node-designator-name to)))
    (%ensure-graph-node graph from-name)
    (%ensure-graph-node graph to-name)
    (let ((neighbors (%weighted-adjacency graph weight-key default-weight))
          (distance (make-hash-table :test #'equal))
          (previous (make-hash-table :test #'equal))
          (settled (make-hash-table :test #'equal)))
      (%dijkstra-relax-with-previous distance previous from-name 0
                                     (gethash from-name neighbors) settled)
      (loop for name = (%dijkstra-pick distance settled)
            while name
            do (setf (gethash name settled) t)
               (%dijkstra-relax-with-previous distance previous name
                                              (gethash name distance)
                                              (gethash name neighbors) settled))
      (when (nth-value 1 (gethash to-name distance))
        (%reconstruct-weighted-path previous from-name to-name)))))

(defun %capacity-network (graph capacity-key default-capacity)
  "Return (values RESIDUAL NEIGHBORS).  RESIDUAL maps a (FROM . TO) cons to its
summed edge capacity; NEIGHBORS maps each node to the list of nodes adjacent to
it in either direction, so a breadth-first search can also push flow back along
a saturated forward edge."
  (let ((residual (%make-result-table))
        (adjacency (%make-result-table)))
    (dolist (name (%graph-node-name-set graph))
      (setf (gethash name adjacency) (%make-result-table)))
    (dolist (edge (%graph-edges-list graph))
      (let ((from (edge-from edge))
            (to (edge-to edge))
            (capacity (%edge-weight edge capacity-key default-capacity "GRAPH-FLOW")))
        (incf (gethash (cons from to) residual 0) capacity)
        (setf (gethash to (gethash from adjacency)) t)
        (setf (gethash from (gethash to adjacency)) t)))
    (let ((neighbors (%make-result-table)))
      (maphash (lambda (name bucket)
                 (setf (gethash name neighbors)
                       (loop for other being the hash-keys of bucket
                             collect other)))
               adjacency)
      (values residual neighbors))))

(defun %augmenting-path (residual neighbors source sink)
  "Breadth-first search for a shortest augmenting path in the residual graph.
Return the predecessor map when SINK is reached, otherwise NIL."
  (let* ((parent (%make-result-table))
         (queue (list source))
         (tail queue))
    (labels ((enqueue (value)
               (let ((cell (list value)))
                 (if queue
                     (setf (cdr tail) cell
                           tail cell)
                     (setf queue cell
                           tail cell)))))
      (setf (gethash source parent) source)
      (loop while queue
            do (let ((node (pop queue)))
                 (dolist (next (gethash node neighbors))
                   (when (and (not (nth-value 1 (gethash next parent)))
                              (> (gethash (cons node next) residual 0) 0))
                     (setf (gethash next parent) node)
                     (enqueue next)))))
      (when (nth-value 1 (gethash sink parent))
        parent))))

(defun %augment-bottleneck (residual parent source sink)
  "The minimum residual capacity along the SOURCE->SINK path recorded in PARENT."
  (let ((bottleneck nil)
        (node sink))
    (loop until (equal node source)
          do (let* ((previous (gethash node parent))
                    (capacity (gethash (cons previous node) residual 0)))
               (setf bottleneck (if bottleneck (min bottleneck capacity) capacity))
               (setf node previous)))
    bottleneck))

(defun %augment-apply (residual parent source sink amount)
  "Push AMOUNT of flow along the SOURCE->SINK path in PARENT, decreasing forward
residuals and increasing the matching reverse residuals."
  (let ((node sink))
    (loop until (equal node source)
          do (let ((previous (gethash node parent)))
               (decf (gethash (cons previous node) residual 0) amount)
               (incf (gethash (cons node previous) residual 0) amount)
               (setf node previous)))))

(defun %max-flow-search (graph source-name sink-name capacity-key default-capacity)
  "Run Edmonds-Karp over GRAPH's capacity network and return
(values TOTAL RESIDUAL NEIGHBORS): the maximum flow value together with the
saturated residual capacities and adjacency, which callers such as the minimum
cut inspect after the search converges."
  (multiple-value-bind (residual neighbors)
      (%capacity-network graph capacity-key default-capacity)
    (let ((total 0))
      (loop for parent = (%augmenting-path residual neighbors
                                           source-name sink-name)
            while parent
            do (let ((bottleneck (%augment-bottleneck residual parent
                                                      source-name sink-name)))
                 (%augment-apply residual parent source-name sink-name
                                 bottleneck)
                 (incf total bottleneck)))
      (values total residual neighbors))))

(defun %residual-reachable (residual neighbors source)
  "The hash set of nodes reachable from SOURCE along positive-residual edges --
the source side of the minimum cut once Edmonds-Karp has saturated the network."
  (let* ((seen (%make-result-table))
         (queue (list source))
         (tail queue))
    (labels ((enqueue (value)
               (let ((cell (list value)))
                 (if queue
                     (setf (cdr tail) cell
                           tail cell)
                     (setf queue cell
                           tail cell)))))
      (setf (gethash source seen) t)
      (loop while queue
            do (let ((node (pop queue)))
                 (dolist (next (gethash node neighbors))
                   (when (and (not (nth-value 1 (gethash next seen)))
                              (> (gethash (cons node next) residual 0) 0))
                     (setf (gethash next seen) t)
                     (enqueue next)))))
      seen)))

(defun graph-max-flow (graph source sink &key capacity-key default-capacity)
  "The maximum flow value from SOURCE to SINK over edge-metadata capacities
(CAPACITY-KEY defaults to :capacity; a capacity-less edge contributes
DEFAULT-CAPACITY, itself defaulting to 1), computed by Edmonds-Karp -- the
breadth-first-augmenting form of Ford-Fulkerson.  Parallel edges' capacities
add.  Returns 0 when SINK is unreachable from SOURCE or when the two coincide.
Signals when either node is absent.  Runs in polynomial time and terminates on
cyclic graphs because every augmentation strictly saturates an edge."
  (let ((capacity-key (or capacity-key :capacity))
        (default-capacity (or default-capacity 1))
        (source-name (%node-designator-name source))
        (sink-name (%node-designator-name sink)))
    (%ensure-graph-node graph source-name)
    (%ensure-graph-node graph sink-name)
    (if (equal source-name sink-name)
        0
        (values (%max-flow-search graph source-name sink-name
                                  capacity-key default-capacity)))))

(defun graph-min-cut (graph source sink &key capacity-key default-capacity)
  "The minimum SOURCE-to-SINK cut as a list of directed (FROM TO) edge pairs
whose removal disconnects SINK from SOURCE and whose total capacity equals
GRAPH-MAX-FLOW.  Found by the max-flow min-cut theorem: after Edmonds-Karp
saturates the network, the cut is exactly the edges leaving the set of nodes
still reachable from SOURCE in the residual graph.  Parallel edges collapse to
one pair.  Empty when SINK is unreachable from SOURCE or the two coincide.
Capacity arguments match GRAPH-MAX-FLOW.  Ordered lexicographically."
  (let ((capacity-key (or capacity-key :capacity))
        (default-capacity (or default-capacity 1))
        (source-name (%node-designator-name source))
        (sink-name (%node-designator-name sink)))
    (%ensure-graph-node graph source-name)
    (%ensure-graph-node graph sink-name)
    (if (equal source-name sink-name)
        '()
        (multiple-value-bind (total residual neighbors)
            (%max-flow-search graph source-name sink-name
                              capacity-key default-capacity)
          (declare (ignore total))
          (let ((reachable (%residual-reachable residual neighbors source-name))
                (crossings (%make-result-table)))
            (dolist (edge (%graph-edges-list graph))
              (let ((from (edge-from edge))
                    (to (edge-to edge)))
                (when (and (nth-value 1 (gethash from reachable))
                           (not (nth-value 1 (gethash to reachable))))
                  (setf (gethash (cons from to) crossings) t))))
            (sort (loop for pair being the hash-keys of crossings
                        collect (list (car pair) (cdr pair)))
                  #'string<
                  :key (lambda (pair)
                         (format nil "~A~C~A" (first pair) #\Nul (second pair)))))))))

(defun %eulerian-start (graph out-degree in-degree)
  "Return the node an Eulerian trail must start from given the OUT-DEGREE and
IN-DEGREE tables, or NIL when the degree balance rules out any trail. A closed
trail (every node balanced) may start at any node with an outgoing edge; an open
trail needs exactly one node with one more out- than in-edge (the start) and one
with the reverse (the end)."
  (let ((surplus '())
        (deficit '())
        (unbalanced 0))
    (dolist (name (graph-node-names graph))
      (let ((difference (- (gethash name out-degree) (gethash name in-degree))))
        (cond ((= difference 1) (push name surplus))
              ((= difference -1) (push name deficit))
              ((/= difference 0) (incf unbalanced)))))
    (cond
      ((plusp unbalanced) nil)
      ((and (null surplus) (null deficit))
       (find-if (lambda (name) (plusp (gethash name out-degree)))
                (graph-node-names graph)))
      ((and (= (length surplus) 1) (= (length deficit) 1))
       (first surplus))
      (t nil))))

(defun %hierholzer-trail (adjacency start)
  "Trace an Eulerian trail from START through ADJACENCY, a node -> mutable list of
successor names consumed one edge at a time. Returns the node sequence in order.
Iterative (explicit stack), so long trails never grow the control stack."
  (let ((stack (list start))
        (trail '()))
    (loop while stack
          do (let ((node (car stack)))
               (if (gethash node adjacency)
                   (push (pop (gethash node adjacency)) stack)
                   (push (pop stack) trail))))
    trail))

(defun graph-eulerian-path (graph)
  "Return an Eulerian trail of GRAPH -- a sequence of node names traversing every
edge exactly once -- or NIL when none exists. Works on the directed multigraph, so
parallel edges are each used once; among the choices the name-least successor is
taken first, making the result deterministic. Uses Hierholzer's algorithm after
checking the in/out-degree balance, and confirms every edge was reached (a
disconnected edge set has no trail), so it stays linear and stack-safe."
  (let ((edges (%graph-edges-list graph))
        (adjacency (%make-result-table))
        (out-degree (%make-result-table))
        (in-degree (%make-result-table)))
    (dolist (name (graph-node-names graph))
      (setf (gethash name adjacency) '()
            (gethash name out-degree) 0
            (gethash name in-degree) 0))
    (dolist (edge edges)
      (let ((from (edge-from edge))
            (to (edge-to edge)))
        (push to (gethash from adjacency))
        (incf (gethash from out-degree))
        (incf (gethash to in-degree))))
    (dolist (name (graph-node-names graph))
      (setf (gethash name adjacency) (sort (gethash name adjacency) #'string<)))
    (let ((start (%eulerian-start graph out-degree in-degree)))
      (if (null start)
          nil
          (let ((trail (%hierholzer-trail adjacency start)))
            (if (= (length trail) (1+ (length edges)))
                trail
                nil))))))
