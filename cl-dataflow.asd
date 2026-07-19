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
  :depends-on (#:cl-prolog)
  :serial t
  :pathname "src/"
  :components ((:file "package")
                (:file "core")
                (:file "protocols")
                (:file "events")
                (:file "effects")
                (:file "state-machine")
                (:file "pipeline")
                (:file "graph-algorithms")
                (:file "graph-export")
                (:file "graph-builders")
                (:file "graph-paths")
                (:file "graph-metrics")
                (:file "graph-connectivity")
                (:file "graph-algebra")
                (:file "state-machine-analysis")
                (:file "state-machine-execution")
                (:file "state-machine-builders")
                (:file "combinators")
                (:file "contracts")
                (:file "streams")
                (:file "stream-extras")
                (:file "stream-ops")
                (:file "stream-stats")
                (:file "stream-search")
                (:file "observability")
                (:file "effects-ext")
                (:file "pipeline-ext")
                (:file "events-ext")
                (:file "introspection")
                (:file "context-serialization")
                (:file "testing"))
  :in-order-to ((test-op (test-op "cl-dataflow/test"))))

(asdf:defsystem #:cl-dataflow/test
  :description "Test system for cl-dataflow."
  :author "takeokunn"
  :maintainer "takeokunn"
  :license "MIT"
  :version "0.1.0"
  :homepage "https://github.com/takeokunn/cl-dataflow"
  :depends-on (#:cl-dataflow
                #:cl-weave)
  :serial t
  :pathname "tests/"
  :components ((:file "package")
                (:file "core-test")
                (:file "events-test")
                (:file "state-machine-test")
                (:file "state-machine-guard-selection-test")
                (:file "state-machine-model-property-test")
                (:file "effects-test")
                (:file "pipeline-test")
                (:file "cl-weave-advanced-test")
                (:file "graph-advanced-property-test")
                (:file "graph-algorithms-test")
                (:file "graph-export-test")
                (:file "graph-builders-test")
                (:file "graph-paths-test")
                (:file "graph-metrics-test")
                (:file "graph-connectivity-test")
                (:file "graph-algebra-test")
                (:file "state-machine-analysis-test")
                (:file "state-machine-execution-test")
                (:file "state-machine-builders-test")
                (:file "combinators-test")
                (:file "contracts-test")
                (:file "streams-test")
                (:file "stream-extras-test")
                (:file "stream-ops-test")
                (:file "stream-stats-test")
                (:file "stream-search-test")
                (:file "observability-test")
                (:file "effects-ext-test")
                (:file "pipeline-ext-test")
                (:file "events-ext-test")
                (:file "introspection-test")
                (:file "context-serialization-test"))
  :perform (test-op (o c)
    (uiop:symbol-call '#:cl-dataflow.test '#:run-tests)))
