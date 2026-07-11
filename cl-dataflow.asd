(asdf:defsystem #:cl-dataflow
  :description "Composable computation graphs, pipelines, events, state machines, and effect boundaries."
  :long-description "cl-dataflow is a small, dependency-light Common Lisp library for
building composable pipelines, event-driven workflows, and stateful computation
graphs. It provides graphs and nodes, sequential and branching pipelines,
event and effect boundaries, guarded state machines, and deterministic testing
helpers, all behind a single public package."
  :author "takeokunn"
  :maintainer "takeokunn"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/takeokunn/cl-dataflow"
  :source-control (:git "https://github.com/takeokunn/cl-dataflow.git")
  :bug-tracker "https://github.com/takeokunn/cl-dataflow/issues"
  :serial t
  :pathname "src/"
  :components ((:file "package")
               (:file "core")
               (:file "protocols")
               (:file "events")
               (:file "effects")
               (:file "state-machine")
               (:file "pipeline")
               (:file "testing"))
  :in-order-to ((test-op (test-op "cl-dataflow/test"))))

(asdf:defsystem #:cl-dataflow/test
  :description "Test system for cl-dataflow."
  :author "takeokunn"
  :maintainer "takeokunn"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/takeokunn/cl-dataflow"
  :depends-on (#:cl-dataflow)
  :serial t
  :pathname "tests/"
  :components ((:file "package")
               (:file "core-test")
               (:file "events-test")
               (:file "state-machine-test")
               (:file "effects-test")
               (:file "pipeline-test"))
  :perform (test-op (o c)
    (uiop:symbol-call '#:cl-dataflow.test '#:run-tests)))
