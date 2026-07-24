(in-package #:cl-dataflow.test)

(deftest
  pipeline-constructor-and-setter-copy-stage-lists
  (let* ((stage-one (make-node "stage-one"))
          (stage-two (make-node "stage-two"))
          (stages (list stage-one stage-two))
          (pipeline (make-pipeline :stages stages)))
    (setf (car stages) (make-node "mutated"))
    (is
      (equal
        (mapcar #'node-name (pipeline-stages pipeline))
        '("stage-one" "stage-two")))
    (let* ((replacement (list stage-two stage-one))
            (replacement-copy (copy-list replacement)))
      (setf (pipeline-stages pipeline) replacement)
      (setf (car replacement) (make-node "changed"))
      (is
        (equal
          (mapcar #'node-name (pipeline-stages pipeline))
          '("stage-two" "stage-one")))
      (is (not (eq (pipeline-stages pipeline) replacement)))
      (is (equal replacement-copy (list stage-two stage-one))))))

(deftest
  pipeline-constructor-and-setter-copy-graphs
  (with-linear-test-pipeline
    (graph pipeline source sink :source-metadata '((:kind :stage)))
    (add-node graph (make-node "mutated"))
    (setf (node-metadata (find-node graph "source")) '((:kind :mutated)))
    (is (not (eq (pipeline-graph pipeline) graph)))
    (is (= (hash-table-count (graph-nodes (pipeline-graph pipeline))) 2))
    (is (= (length (graph-edges (pipeline-graph pipeline))) 1))
    (is
      (equal
        (node-metadata (find-node (pipeline-graph pipeline) "source"))
        '((:kind :stage))))
    (let* ((replacement (make-graph :metadata '((:kind :replacement))))
            (replacement-source (make-node "source"))
            (replacement-sink (make-node "sink")))
      (add-node replacement replacement-source)
      (add-node replacement replacement-sink)
      (add-edge replacement replacement-source replacement-sink)
      (setf (pipeline-graph pipeline) replacement)
      (is (not (eq (pipeline-graph pipeline) replacement)))
      (is (= (hash-table-count (graph-nodes (pipeline-graph pipeline))) 2))
      (is
        (eq
          (first (pipeline-stages pipeline))
          (find-node (pipeline-graph pipeline) "source")))
      (is
        (eq
          (second (pipeline-stages pipeline))
          (find-node (pipeline-graph pipeline) "sink")))
      (is (equal (graph-metadata (pipeline-graph pipeline)) '((:kind :replacement)))))))

(deftest
  pipeline-graph-setter-preserves-empty-stage-cache
  (let ((pipeline (make-pipeline)))
    (with-linear-test-pipeline
      (graph initialized-pipeline source sink)
      (setf (pipeline-graph pipeline) graph)
      (is (not (eq (pipeline-graph pipeline) graph)))
      (is (null (pipeline-stages pipeline)))
      (is (= (hash-table-count (graph-nodes (pipeline-graph pipeline))) 2))
      (is (not (eq initialized-pipeline pipeline))))))

(deftest
  pipeline-constructor-supports-empty-graph-and-stage-input
  (let ((pipeline (make-pipeline)))
    (is (null (pipeline-stages pipeline)))
    (is (= (hash-table-count (graph-nodes (pipeline-graph pipeline))) 0))
    (is (equal (graph-edges (pipeline-graph pipeline)) '()))))

(deftest
  pipeline-stages-setter-remaps-onto-live-graph
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (let ((replacement (list (make-node "source") (make-node "sink"))))
      (setf (pipeline-stages pipeline) replacement)
      (setf (car replacement) (make-node "mutated"))
      (is
        (eq
          (first (pipeline-stages pipeline))
          (find-node (pipeline-graph pipeline) "source")))
      (is
        (eq
          (second (pipeline-stages pipeline))
          (find-node (pipeline-graph pipeline) "sink")))
      (is (equal (mapcar #'node-name (pipeline-stages pipeline)) '("source" "sink"))))))

(deftest
  pipeline-rejects-stale-stages-when-graph-cannot-resolve-them
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (let ((orphan (make-node "orphan")))
      (with-captured-condition
        (condition node-not-found-error)
        (make-pipeline :graph graph :stages (list orphan))
        (is (not (eq (node-not-found-designator condition) orphan))))
      (with-captured-condition
        (condition node-not-found-error)
        (setf (pipeline-stages pipeline) (list orphan))
        (is (not (eq (node-not-found-designator condition) orphan)))))))

(deftest
  pipeline-constructor-remaps-stages-onto-copied-graph
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (is (not (eq (pipeline-graph pipeline) graph)))
    (is (not (eq (first (pipeline-stages pipeline)) source)))
    (is (not (eq (second (pipeline-stages pipeline)) sink)))
    (is
      (eq
        (first (pipeline-stages pipeline))
        (find-node (pipeline-graph pipeline) "source")))
    (is
      (eq
        (second (pipeline-stages pipeline))
        (find-node (pipeline-graph pipeline) "sink")))))

(deftest
  pipeline-stages-return-independent-snapshots
  (let* ((stage-one (make-node "stage-one"))
          (stage-two (make-node "stage-two"))
          (pipeline (make-pipeline :stages (list stage-one stage-two)))
          (stages-snapshot (pipeline-stages pipeline)))
    (is (not (eq stages-snapshot (pipeline-stages pipeline))))
    (setf (car stages-snapshot) (make-node "mutated"))
    (is
      (equal
        (mapcar #'node-name (pipeline-stages pipeline))
        '("stage-one" "stage-two")))))

(deftest
  copy-pipeline-produces-independent-pipeline
  (with-linear-test-pipeline
    (graph
      pipeline
      source
      sink
      :source-metadata
      '((:kind :source))
      :sink-metadata
      '((:kind :sink))
      :pipeline-metadata
      '((:pipeline :original)))
    (setf (graph-metadata (pipeline-graph pipeline)) '((:kind :original)))
    (let ((copy (copy-pipeline pipeline)))
      (is (not (eq copy pipeline)))
      (is (not (eq (pipeline-graph copy) (pipeline-graph pipeline))))
      (is
        (not (eq (first (pipeline-stages copy)) (first (pipeline-stages pipeline)))))
      (is
        (eq (first (pipeline-stages copy)) (find-node (pipeline-graph copy) "source")))
      (is
        (equal
          (mapcar #'node-name (pipeline-stages copy))
          (mapcar #'node-name (pipeline-stages pipeline))))
      (is (equal (pipeline-metadata copy) (pipeline-metadata pipeline)))
      (is (equal (graph-metadata (pipeline-graph copy)) '((:kind :original))))
      (is
        (equal
          (node-metadata (find-node (pipeline-graph copy) "source"))
          '((:kind :source))))
      (setf (pipeline-metadata copy) '((:pipeline :copy))
            (node-metadata (find-node (pipeline-graph copy) "source")) '((:kind :copy-source)))
      (add-node (pipeline-graph pipeline) (make-node "mutated"))
      (setf (node-metadata (find-node (pipeline-graph pipeline) "source")) '((:kind :mutated)))
      (is (equal (pipeline-metadata pipeline) '((:pipeline :original))))
      (is (equal (graph-metadata (pipeline-graph pipeline)) '((:kind :original))))
      (is
        (equal
          (node-metadata (find-node (pipeline-graph pipeline) "source"))
          '((:kind :mutated))))
      (is (= (hash-table-count (graph-nodes (pipeline-graph copy))) 2))
      (is (equal (graph-metadata (pipeline-graph copy)) '((:kind :original))))
      (is
        (equal
          (node-metadata (find-node (pipeline-graph copy) "source"))
          '((:kind :copy-source))))
      (is (equal (pipeline-metadata copy) '((:pipeline :copy)))))))

(deftest
  pipeline-rebuilds-plan-after-edge-collection-changes
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (let* ((live-graph (pipeline-graph pipeline))
            (extra (make-node "extra")))
      (add-node live-graph extra)
      (let ((plan (cl-dataflow::%pipeline-execution-plan pipeline)))
        (add-edge live-graph sink extra)
        (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
        (is (not (eq plan (cl-dataflow::%pipeline-execution-plan pipeline)))))
      (let ((plan (cl-dataflow::%pipeline-execution-plan pipeline)))
        (remove-edge live-graph sink extra)
        (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
        (is (not (eq plan (cl-dataflow::%pipeline-execution-plan pipeline)))))
      (let ((plan (cl-dataflow::%pipeline-execution-plan pipeline)))
        (setf (graph-edges live-graph) (graph-edges live-graph))
        (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
        (is (not (eq plan (cl-dataflow::%pipeline-execution-plan pipeline))))))))

(deftest
  pipeline-reuses-current-execution-plan
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (let ((plan (cl-dataflow::%pipeline-execution-plan pipeline)))
      (run-pipeline pipeline)
      (is (eq plan (cl-dataflow::%pipeline-execution-plan pipeline)))
      (run-pipeline pipeline)
      (is (eq plan (cl-dataflow::%pipeline-execution-plan pipeline))))))

(deftest
  pipeline-rebuilds-plan-after-live-edge-mutation
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (let* ((live-graph (pipeline-graph pipeline))
            (extra (make-node "extra"))
            (alternate-source (make-node "Source")))
      (add-node live-graph extra)
      (add-node live-graph alternate-source)
      (let ((edge (add-edge live-graph sink extra)))
        (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
        (flet ((assert-rebuilt (mutator)
                  (let ((plan (cl-dataflow::%pipeline-execution-plan pipeline)))
                (funcall mutator)
                (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
                (is (not (eq plan (cl-dataflow::%pipeline-execution-plan pipeline)))))))
          (assert-rebuilt
            (lambda ()
              (setf (edge-from edge) "source")))
          (assert-rebuilt
            (lambda ()
              (setf (edge-from-port edge) "changed-from-port")))
          (assert-rebuilt
            (lambda ()
              (setf (edge-to edge) "source")))
          (assert-rebuilt
            (lambda ()
              (setf (edge-to-port edge) "changed-to-port")))
          (setf (edge-from edge) "Source")
          (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
          (assert-rebuilt
            (lambda ()
              (setf (char (edge-from edge) 0) #\s))))))))

(deftest
  pipeline-detects-renamed-live-stage
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (setf (node-name (first (cl-dataflow::%pipeline-stages-list pipeline))) "renamed")
    (with-captured-condition
      (condition node-not-found-error)
      (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
      (is (string= (node-name (node-not-found-designator condition)) "renamed")))))

(deftest
  pipeline-setter-and-copy-isolate-execution-plans
  (with-linear-test-pipeline
    (graph pipeline source sink)
    (let ((original-plan (cl-dataflow::%pipeline-execution-plan pipeline)))
      (setf (pipeline-stages pipeline) (pipeline-stages pipeline))
      (is (null (cl-dataflow::%pipeline-execution-plan pipeline)))
      (cl-dataflow::%ensure-pipeline-execution-plan pipeline)
      (is (not (eq original-plan (cl-dataflow::%pipeline-execution-plan pipeline))))
      (let ((copy (copy-pipeline pipeline)))
        (is
          (not
            (eq
              (cl-dataflow::%pipeline-execution-plan pipeline)
              (cl-dataflow::%pipeline-execution-plan copy))))
        (is
          (not
            (eq
              (cl-dataflow::%pipeline-execution-plan-graph
                (cl-dataflow::%pipeline-execution-plan pipeline))
              (cl-dataflow::%pipeline-execution-plan-graph
                (cl-dataflow::%pipeline-execution-plan copy)))))))))
