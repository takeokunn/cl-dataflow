(in-package #:cl-dataflow)

;;;; More stream operators and terminal collectors on top of the FLOW-STREAM core.
;;;; Operators stay lazy; the map-building consumers (group-by, frequencies,
;;;; index-by) preserve first-seen key order and iterate rather than recurse.

;;; --- Lazy operators ------------------------------------------------------

(defun stream-zip-with (function stream-a stream-b)
  "Return a stream of (FUNCALL FUNCTION A B) for paired elements of STREAM-A and
STREAM-B, stopping when either stream ends."
  (%make-flow-stream
   (lambda ()
     (let ((step-a (%stream-step stream-a))
           (step-b (%stream-step stream-b)))
       (if (or (eq step-a :end) (eq step-b :end))
           :end
           (cons (funcall function (car step-a) (car step-b))
                 (stream-zip-with function (cdr step-a) (cdr step-b))))))))

(defun stream-interleave (stream-a stream-b)
  "Return a stream that alternates elements of STREAM-A and STREAM-B; when one ends
the remaining elements of the other follow."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream-a)))
       (if (eq step :end)
           (%stream-step stream-b)
           (cons (car step) (stream-interleave stream-b (cdr step))))))))

(defun %stream-take-nth (n stream)
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (cons (car step)
                 (%stream-take-nth n (stream-drop (1- n) (cdr step)))))))))

(defun stream-take-nth (n stream)
  "Return a stream of every Nth element of STREAM, starting with the first (indices
0, N, 2N, ...). N must be positive."
  (%positive-size n "STREAM-TAKE-NTH")
  (%stream-take-nth n stream))

(defun %stream-dedupe-after (previous stream test)
  (%make-flow-stream
   (lambda ()
     (let ((current stream))
       (loop
         (let ((step (%stream-step current)))
           (cond ((eq step :end) (return :end))
                 ((funcall test (car step) previous) (setf current (cdr step)))
                 (t (return (cons (car step)
                                  (%stream-dedupe-after (car step) (cdr step) test)))))))))))

(defun stream-dedupe-consecutive (stream &key (test 'equal))
  "Return a stream of STREAM with consecutive duplicate elements (under TEST)
collapsed to a single element. Non-adjacent duplicates are kept."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (cons (car step)
                 (%stream-dedupe-after (car step) (cdr step) test)))))))

(defun %stream-interpose-rest (separator stream)
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (cons separator
                 (%make-flow-stream
                  (lambda ()
                    (cons (car step)
                          (%stream-interpose-rest separator (cdr step)))))))))))

(defun stream-interpose (separator stream)
  "Return a stream with SEPARATOR inserted between consecutive elements of STREAM."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (cons (car step)
                 (%stream-interpose-rest separator (cdr step))))))))

(defun %stream-distinct-by (function stream seen test)
  (%make-flow-stream
   (lambda ()
     (let ((current stream)
           (already seen))
       (loop
         (let ((step (%stream-step current)))
           (cond ((eq step :end) (return :end))
                 ((member (funcall function (car step)) already :test test)
                  (setf current (cdr step)))
                 (t (return (cons (car step)
                                  (%stream-distinct-by function
                                                       (cdr step)
                                                       (cons (funcall function (car step)) already)
                                                       test)))))))))))

(defun stream-distinct-by (function stream &key (test 'equal))
  "Return a stream of the elements of STREAM whose key (FUNCALL FUNCTION ELEMENT) has
not appeared before (under TEST), keeping the first element for each key. The
key-projected analog of STREAM-DISTINCT; O(n^2) in the number of distinct keys."
  (%stream-distinct-by function stream '() test))

;;; --- Terminal collectors -------------------------------------------------

(defun %stream-group-into (stream key-function value-function)
  "Fold STREAM into (VALUES TABLE FIRST-SEEN-KEY-ORDER), applying VALUE-FUNCTION to
accumulate (OLD-OR-NIL, PRESENT-P, ELEMENT) into each key's cell."
  (let ((table (make-hash-table :test #'equal))
        (order '())
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return (values table (nreverse order))))
        (let ((key (funcall key-function (car step))))
          (multiple-value-bind (existing present) (gethash key table)
            (unless present
              (push key order))
            (setf (gethash key table)
                  (funcall value-function existing present (car step)))))
        (setf current (cdr step))))))

(defun stream-group-by (function stream)
  "Return an alist (KEY . ELEMENTS) grouping STREAM's elements by (FUNCALL FUNCTION
ELEMENT). Keys appear in first-seen order and elements in stream order."
  (multiple-value-bind (table order)
      (%stream-group-into stream function
                          (lambda (existing present element)
                            (declare (ignore present))
                            (cons element existing)))
    (mapcar (lambda (key) (cons key (nreverse (gethash key table)))) order)))

(defun stream-frequencies (stream &key (key #'identity))
  "Return an alist (VALUE . COUNT) counting occurrences of (FUNCALL KEY ELEMENT)
over STREAM, in first-seen order."
  (multiple-value-bind (table order)
      (%stream-group-into stream key
                          (lambda (existing present element)
                            (declare (ignore element))
                            (if present (1+ existing) 1)))
    (mapcar (lambda (value) (cons value (gethash value table))) order)))

(defun stream-index-by (function stream)
  "Return an alist (KEY . ELEMENT) indexing STREAM by (FUNCALL FUNCTION ELEMENT),
with the last element for each key winning. Keys appear in first-seen order."
  (multiple-value-bind (table order)
      (%stream-group-into stream function
                          (lambda (existing present element)
                            (declare (ignore existing present))
                            element))
    (mapcar (lambda (key) (cons key (gethash key table))) order)))

(defun stream-partition (predicate stream)
  "Return (VALUES MATCHING NON-MATCHING) splitting STREAM's elements by PREDICATE,
each preserving stream order."
  (let ((matching '())
        (non-matching '())
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end)
          (return (values (nreverse matching) (nreverse non-matching))))
        (if (funcall predicate (car step))
            (push (car step) matching)
            (push (car step) non-matching))
        (setf current (cdr step))))))

(defun stream-split-at (n stream)
  "Return (VALUES FIRST-N-LIST REST-STREAM) splitting STREAM after N elements. When
STREAM has fewer than N elements the first value holds them all and REST-STREAM is
empty."
  (let ((head '())
        (current stream)
        (remaining n))
    (loop
      (when (<= remaining 0) (return))
      (let ((step (%stream-step current)))
        (when (eq step :end) (return))
        (push (car step) head)
        (setf current (cdr step)
              remaining (1- remaining))))
    (values (nreverse head) current)))

(defun stream-average (stream &key (key #'identity))
  "Return the arithmetic mean of (FUNCALL KEY ELEMENT) over STREAM, or NIL when
STREAM is empty."
  (let ((sum 0)
        (count 0)
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end)
          (return (if (zerop count) nil (/ sum count))))
        (incf sum (funcall key (car step)))
        (incf count)
        (setf current (cdr step))))))
