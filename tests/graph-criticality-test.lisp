(in-package #:cl-dataflow.test)

(deftest graph-articulation-points-finds-cut-vertices
  ;; In the path a -> b -> c, b is the cut vertex; the endpoints are not.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c)))
    (is (equal (graph-articulation-points graph) '("b"))))
  ;; A cycle has no articulation points.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c) (c a)))
    (is (null (graph-articulation-points graph))))
  ;; A hub connecting two leaves is a cut vertex.
  (with-graph-fixture (graph
                       ((hub "hub") (l "left") (r "right"))
                       :edges ((hub l) (hub r)))
    (is (equal (graph-articulation-points graph) '("hub")))))

(deftest graph-bridges-finds-critical-connections
  ;; Every edge of a path is a bridge.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c)))
    (is (equal (graph-bridges graph) '(("a" "b") ("b" "c")))))
  ;; A cycle has no bridges.
  (with-graph-fixture (graph
                       ((a "a") (b "b") (c "c"))
                       :edges ((a b) (b c) (c a)))
    (is (null (graph-bridges graph)))))

(deftest graph-bridges-handles-self-loops-and-antiparallel-edges
  ;; Self-loops are ignored; anti-parallel a<->b collapse to one undirected
  ;; connection, and that single connection to the isolated cycle {a,b} is not a
  ;; bridge to the rest because there is none -- but the a<->b pair, if it is the
  ;; only link, is critical. Here d hangs off b by a single edge (a bridge).
  (with-graph-fixture (graph
                       ((a "a") (b "b") (d "d"))
                       :edges ((a b) (b a) (a a) (b d)))
    ;; a<->b has two edges; removing both disconnects them only if there's no other
    ;; path -- there isn't, so it is a critical connection. b->d is a lone bridge.
    (is (equal (graph-bridges graph) '(("a" "b") ("b" "d"))))
    ;; b is a cut vertex (it links d to the a<->b pair).
    (is (equal (graph-articulation-points graph) '("b")))))
