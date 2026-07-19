(in-package #:cl-dataflow.test)

(defun %names (nodes)
  (mapcar #'node-name nodes))

(defun %weighted-graph (node-names edges)
  "EDGES: list of (from to weight &optional from-port to-port)."
  (let ((graph (make-graph)))
    (dolist (name node-names)
      (add-node graph (make-node name)))
    (dolist (spec edges)
      (destructuring-bind (from to weight &optional (from-port "value") (to-port "value"))
          spec
        (let ((edge (add-edge graph from to :from-port from-port :to-port to-port)))
          (setf (edge-metadata edge) (list :weight weight)))))
    graph))

(deftest graph-transitive-closure-connects-all-reachable-pairs
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c)))
    (let ((closure (graph-transitive-closure graph)))
      (is (equal (%names (graph-successors closure "a")) '("b" "c")))
      (is (= (graph-size closure) 3))))
  ;; A cycle gives every member a self-edge.
  (with-graph-fixture (graph
                       ((a "a") (b "b"))
                       :edges ((a b) (b a)))
    (let ((closure (graph-transitive-closure graph)))
      (is (equal (%names (graph-successors closure "a")) '("a" "b")))
      (is (= (graph-size closure) 4)))))

(deftest graph-transitive-reduction-drops-redundant-edges
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c) (a c)))
    (let ((reduced (graph-transitive-reduction graph)))
      ;; a -> c is implied by a -> b -> c and is removed.
      (is (= (graph-size reduced) 2))
      (is (equal (%names (graph-successors reduced "a")) '("b")))
      ;; Reachability is preserved.
      (is (graph-reachable-p reduced "a" "c"))))
  (with-graph-fixture (graph ((a "a") (b "b")) :edges ((a b) (b a)))
    (signals graph-cycle-error (graph-transitive-reduction graph))))

(deftest graph-topological-rank-measures-longest-source-distance
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c") (d "d"))
                       :edges ((a b) (a c) (b d) (c d)))
    (is (equal (graph-topological-rank graph)
               '(("a" . 0) ("b" . 1) ("c" . 1) ("d" . 2)))))
  (with-graph-fixture (graph ((a "a") (b "b")) :edges ((a b) (b a)))
    (signals graph-cycle-error (graph-topological-rank graph))))

(deftest graph-longest-path-finds-the-critical-path
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c") (d "d"))
                       :edges ((a b) (a c) (b d) (c d)))
    ;; Both a-b-d and a-c-d have length 2; b sorts first, so b is chosen.
    (is (equal (graph-longest-path graph) '("a" "b" "d"))))
  (with-graph-fixture (graph ((a "a") (b "b") (c "c")) :edges ((a b) (b c)))
    (is (equal (graph-longest-path graph) '("a" "b" "c"))))
  (is (null (graph-longest-path (make-graph))))
  (with-graph-fixture (graph ((solo "solo")))
    (is (equal (graph-longest-path graph) '("solo"))))
  (with-graph-fixture (graph ((a "a") (b "b")) :edges ((a b) (b a)))
    (signals graph-cycle-error (graph-longest-path graph))))

(deftest graph-all-paths-enumerates-simple-paths
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c") (d "d"))
                       :edges ((a b) (a c) (b d) (c d)))
    (is (equal (graph-all-paths graph "a" "d")
               '(("a" "b" "d") ("a" "c" "d")))))
  ;; FROM = TO is the trivial path.
  (with-graph-fixture (graph ((a "a")))
    (is (equal (graph-all-paths graph "a" "a") '(("a")))))
  ;; b -> a is a back-edge to an already-visited node; exploring it (while a is on
  ;; the path and is not the target) exercises the visited-node skip.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (a c) (b a)))
    (is (equal (graph-all-paths graph "a" "c") '(("a" "c")))))
  (with-graph-fixture (graph ((a "a")))
    (signals node-not-found-error (graph-all-paths graph "a" "missing"))))

(deftest graph-find-cycle-returns-a-cycle-or-nil
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c) (c a)))
    (let ((cycle (graph-find-cycle graph)))
      (is (equal (first cycle) (car (last cycle))))
      (is (>= (length cycle) 4))))
  ;; A self-loop is a length-1 cycle.
  (with-graph-fixture (graph ((x "x")) :edges ((x x)))
    (is (equal (graph-find-cycle graph) '("x" "x"))))
  ;; Acyclic graphs have no cycle.
  (with-graph-fixture (graph ((a "a") (b "b")) :edges ((a b)))
    (is (null (graph-find-cycle graph)))))

(deftest graph-weighted-distance-runs-dijkstra
  (let ((graph (%weighted-graph '("a" "b" "c" "d")
                                '(("a" "b" 2) ("a" "c" 5) ("a" "d" 1)
                                  ("b" "c" 1) ("b" "d" 10) ("c" "d" 1)))))
    ;; a -> b -> c costs 3, cheaper than the direct a -> c of 5.
    (is (= (graph-weighted-distance graph "a" "c") 3))
    ;; The direct a -> d of 1 beats every longer route.
    (is (= (graph-weighted-distance graph "a" "d") 1))
    ;; d is a sink, so nothing is reachable from it.
    (is (null (graph-weighted-distance graph "d" "a"))))
  ;; b (cost 1) settles before c (cost 2), so when c later relaxes d it offers a
  ;; longer route that must be rejected -- exercising the not-shorter relaxation.
  (let ((graph (%weighted-graph '("a" "b" "c" "d")
                                '(("a" "b" 1) ("a" "c" 2) ("b" "d" 1) ("c" "d" 1)))))
    (is (= (graph-weighted-distance graph "a" "d") 2))))

(deftest graph-weighted-distance-defaults-and-parallel-edges
  ;; With no weights every edge costs the default, so distance is hop count.
  (with-graph-fixture (graph ((a "a") (b "b") (c "c")) :edges ((a b) (b c)))
    (is (= (graph-weighted-distance graph "a" "c") 2)))
  ;; Parallel edges collapse to the cheapest. Three of them (added dear, cheap,
  ;; mid) drive both the "cheaper than existing" and "not cheaper" comparisons as
  ;; the newest-first edge list is folded.
  (let ((graph (make-graph)))
    (add-node graph (make-node "a" :outputs '("p1" "p2" "p3")))
    (add-node graph (make-node "b"))
    (let ((dear (add-edge graph "a" "b" :from-port "p1"))
          (cheap (add-edge graph "a" "b" :from-port "p2"))
          (mid (add-edge graph "a" "b" :from-port "p3")))
      (setf (edge-metadata dear) '(:weight 5)
            (edge-metadata cheap) '(:weight 2)
            (edge-metadata mid) '(:weight 8)))
    (is (= (graph-weighted-distance graph "a" "b") 2)))
  ;; FROM = TO resolves only through a cycle.
  (let ((graph (%weighted-graph '("a" "b") '(("a" "b" 1) ("b" "a" 1)))))
    (is (= (graph-weighted-distance graph "a" "a") 2))))

(deftest graph-weighted-path-returns-the-cheapest-route
  (let ((graph (%weighted-graph '("a" "b" "c" "d")
                                '(("a" "b" 2) ("a" "c" 5) ("b" "c" 1) ("c" "d" 1)))))
    ;; a -> b -> c -> d (2+1+1=4) beats a -> c -> d (5+1=6).
    (is (equal (graph-weighted-path graph "a" "d") '("a" "b" "c" "d")))
    (is (null (graph-weighted-path graph "d" "a"))))
  ;; FROM = TO returns the cycle.
  (let ((graph (%weighted-graph '("a" "b") '(("a" "b" 1) ("b" "a" 1)))))
    (is (equal (graph-weighted-path graph "a" "a") '("a" "b" "a"))))
  ;; A custom weight key with a default for unlabelled edges.
  (let ((graph (make-graph)))
    (dolist (name '("a" "b" "c")) (add-node graph (make-node name)))
    (add-edge graph "b" "c")
    (setf (edge-metadata (add-edge graph "a" "b")) '(:cost 3))
    (is (equal (graph-weighted-path graph "a" "c" :weight-key :cost :default-weight 10)
               '("a" "b" "c"))))
  ;; b (cost 1) settles before c (cost 2); c's later relaxation of d is longer and
  ;; must be rejected, exercising the not-shorter relaxation with previous tracking.
  (let ((graph (%weighted-graph '("a" "b" "c" "d")
                                '(("a" "b" 1) ("a" "c" 2) ("b" "d" 1) ("c" "d" 1)))))
    (is (equal (graph-weighted-path graph "a" "d") '("a" "b" "d")))))

(deftest graph-weighted-distance-honours-custom-weight-key-and-default
  (let ((graph (make-graph)))
    (dolist (name '("a" "b" "c"))
      (add-node graph (make-node name)))
    ;; a -> b carries an explicit :cost of 7; b -> c has no :cost and falls back
    ;; to the supplied default of 10.
    (add-edge graph "b" "c")
    (setf (edge-metadata (add-edge graph "a" "b")) '(:cost 7))
    (is (= (graph-weighted-distance graph "a" "b" :weight-key :cost :default-weight 10) 7))
    (is (= (graph-weighted-distance graph "a" "c" :weight-key :cost :default-weight 10) 17))))

(deftest graph-weighted-distances-from-runs-dijkstra-to-all
  ;; From a: b costs 2 directly; c is cheaper via b (2+3=5) than the direct a->c
  ;; edge of 10, so Dijkstra must relax it down. Ordered by name; a itself is
  ;; absent because no path returns to it. Uses the default :weight key.
  (let ((graph (%weighted-graph '("a" "b" "c")
                                '(("a" "b" 2) ("b" "c" 3) ("a" "c" 10)))))
    (is (equal (graph-weighted-distances-from graph "a") '(("b" . 2) ("c" . 5))))
    ;; A sink reaches nothing, so the alist is empty.
    (is (null (graph-weighted-distances-from graph "c"))))
  ;; A custom weight key with an explicit default exercises the supplied-argument
  ;; branches: a->b carries :cost 7, b->c has none and falls back to 10.
  (let ((graph (make-graph)))
    (dolist (name '("a" "b" "c"))
      (add-node graph (make-node name)))
    (add-edge graph "b" "c")
    (setf (edge-metadata (add-edge graph "a" "b")) '(:cost 7))
    (is (equal (graph-weighted-distances-from graph "a" :weight-key :cost :default-weight 10)
               '(("b" . 7) ("c" . 17))))))

(deftest graph-max-flow-computes-edmonds-karp
  ;; The classic CLRS max-flow network: the maximum s->t flow is 23. Capacities
  ;; live under :weight here, exercising the supplied capacity-key argument and
  ;; the anti-parallel v1<->v2 edges (distinct directed capacities).
  (let ((graph (%weighted-graph
                '("s" "v1" "v2" "v3" "v4" "t")
                '(("s" "v1" 16) ("s" "v2" 13) ("v1" "v2" 10) ("v2" "v1" 4)
                  ("v1" "v3" 12) ("v3" "v2" 9) ("v2" "v4" 14) ("v4" "v3" 7)
                  ("v3" "t" 20) ("v4" "t" 4)))))
    (is (= (graph-max-flow graph "s" "t" :capacity-key :weight) 23))
    ;; A node can send no flow to itself.
    (is (= (graph-max-flow graph "s" "s" :capacity-key :weight) 0)))
  ;; Diamond s->{a,b}->c->t with unit side edges and a width-2 sink edge: the
  ;; first augmentation saturates one side, so a later search must skip the now
  ;; zero-residual edge to an as-yet-unvisited node. Maximum flow is 2.
  (let ((graph (%weighted-graph '("s" "a" "b" "c" "t")
                                '(("s" "a" 1) ("s" "b" 1)
                                  ("a" "c" 1) ("b" "c" 1) ("c" "t" 2)))))
    (is (= (graph-max-flow graph "s" "t" :capacity-key :weight) 2)))
  ;; An unreachable sink yields zero flow.
  (let ((graph (%weighted-graph '("s" "a" "t") '(("s" "a" 5)))))
    (is (= (graph-max-flow graph "s" "t" :capacity-key :weight) 0))))

(deftest graph-max-flow-capacity-defaults-and-parallel-edges
  ;; With no :capacity metadata every edge falls back to the default capacity;
  ;; left at its own default of 1, the s->a->t path carries a single unit.
  (let ((graph (make-graph)))
    (dolist (name '("s" "a" "t"))
      (add-node graph (make-node name)))
    (add-edge graph "s" "a")
    (add-edge graph "a" "t")
    (is (= (graph-max-flow graph "s" "t") 1))
    ;; A supplied default lifts every capacity uniformly.
    (is (= (graph-max-flow graph "s" "t" :default-capacity 5) 5)))
  ;; Parallel edges' capacities add: two s->a edges of capacity 3 push 6 units
  ;; into a, matched by a width-6 a->t edge. Distinct ports keep the two s->a
  ;; edges from collapsing under add-edge's port-level de-duplication.
  (let ((graph (make-graph)))
    (add-node graph (make-node "s" :outputs '("p1" "p2")))
    (add-node graph (make-node "a" :inputs '("q1" "q2")))
    (add-node graph (make-node "t"))
    (setf (edge-metadata (add-edge graph "s" "a" :from-port "p1" :to-port "q1"))
          '(:capacity 3))
    (setf (edge-metadata (add-edge graph "s" "a" :from-port "p2" :to-port "q2"))
          '(:capacity 3))
    (setf (edge-metadata (add-edge graph "a" "t")) '(:capacity 6))
    (is (= (graph-max-flow graph "s" "t") 6))))

(deftest graph-min-cut-finds-the-bottleneck-edges
  ;; s->a->b->t with a unit middle edge: the max-flow min-cut theorem places
  ;; a and s on the source side (s->a still has slack) but leaves b and t on the
  ;; sink side, so the single cut edge is a->b, matching the max flow of 1. This
  ;; graph exercises every cut-scan case: an interior edge (s->a), the crossing
  ;; edge (a->b), and a sink-side edge (b->t).
  (let ((graph (%weighted-graph '("s" "a" "b" "t")
                                '(("s" "a" 5) ("a" "b" 1) ("b" "t" 5)))))
    (is (equal (graph-min-cut graph "s" "t" :capacity-key :weight) '(("a" "b"))))
    (is (= (graph-max-flow graph "s" "t" :capacity-key :weight) 1))
    ;; A node has no cut to itself.
    (is (null (graph-min-cut graph "s" "s" :capacity-key :weight))))
  ;; An unreachable sink leaves nothing crossing to the sink side.
  (let ((graph (%weighted-graph '("s" "a" "t") '(("s" "a" 5)))))
    (is (null (graph-min-cut graph "s" "t" :capacity-key :weight))))
  ;; The default :capacity key with a supplied default: s->a saturates at
  ;; capacity 1 while the capacity-less a->t rides the default of 5, so the cut
  ;; is the saturated s->a edge.
  (let ((graph (make-graph)))
    (dolist (name '("s" "a" "t"))
      (add-node graph (make-node name)))
    (setf (edge-metadata (add-edge graph "s" "a")) '(:capacity 1))
    (add-edge graph "a" "t")
    (is (equal (graph-min-cut graph "s" "t" :default-capacity 5) '(("s" "a")))))
  ;; On the CLRS network the cut capacity must equal the max flow of 23.
  (let ((graph (%weighted-graph
                '("s" "v1" "v2" "v3" "v4" "t")
                '(("s" "v1" 16) ("s" "v2" 13) ("v1" "v2" 10) ("v2" "v1" 4)
                  ("v1" "v3" 12) ("v3" "v2" 9) ("v2" "v4" 14) ("v4" "v3" 7)
                  ("v3" "t" 20) ("v4" "t" 4)))))
    (is (= (loop for (from to) in (graph-min-cut graph "s" "t" :capacity-key :weight)
                 sum (loop for edge in (graph-edges graph)
                           when (and (equal (edge-from edge) from)
                                     (equal (edge-to edge) to))
                           sum (getf (edge-metadata edge) :weight)))
           23))))
