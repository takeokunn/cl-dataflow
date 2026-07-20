(in-package #:cl-dataflow)

;;;; A small lazy stream / transducer layer. A FLOW-STREAM is a delayed sequence:
;;;; a STEP thunk that yields either :END or (element . next-stream). Operators
;;;; (map/filter/scan/take/...) build new streams without forcing the source, and
;;;; consumers (collect/reduce/for-each/...) drive evaluation one element at a time.
;;;;
;;;; Two properties are deliberate:
;;;;   * Purity -- pulling never mutates the source, so a stream can be consumed
;;;;     more than once and operators compose freely.
;;;;   * Bounded stack -- every per-pull "skip" loop (filter, drop, distinct,
;;;;     flat-map, concat) is iterative, so discarding a long run of elements does
;;;;     not grow the control stack; consumers iterate rather than recurse.

(defstruct (flow-stream (:constructor %make-flow-stream (step))
                        (:copier nil)
                        (:predicate flow-stream-p))
  ;; STEP: () -> :END | (cons element next-flow-stream)
  step)

(declaim (inline %stream-step))
(defun %stream-step (stream)
  (funcall (flow-stream-step stream)))

(defun empty-stream ()
  "Return a stream with no elements."
  (%make-flow-stream (lambda () :end)))

(defun list->stream (list)
  "Return a stream that yields the elements of LIST in order."
  (if (null list)
      (empty-stream)
      (%make-flow-stream (lambda () (cons (first list) (list->stream (rest list)))))))

(defun stream-of (&rest elements)
  "Return a stream that yields ELEMENTS in order."
  (list->stream elements))

(defun stream-range (start end &key (step 1))
  "Return a stream of numbers from START (inclusive) toward END (exclusive) by
STEP. STEP may be negative for a descending range but must not be zero."
  (when (zerop step)
    (error 'invalid-input-error
           :expected 'nonzero-step
           :value step
           :detail "STREAM-RANGE step must be non-zero."))
  (labels ((generate (n)
             (if (if (plusp step) (>= n end) (<= n end))
                 (empty-stream)
                 (%make-flow-stream (lambda () (cons n (generate (+ n step))))))))
    (generate start)))

;;; --- Operators (stream -> stream) ----------------------------------------

(defun stream-map (function stream)
  "Return a stream of (FUNCALL FUNCTION ELEMENT) for each element of STREAM."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (cons (funcall function (car step))
                 (stream-map function (cdr step))))))))

(defun stream-filter (predicate stream)
  "Return a stream of the elements of STREAM for which PREDICATE is true."
  (%make-flow-stream
   (lambda ()
     (let ((current stream))
       (loop
         (let ((step (%stream-step current)))
           (cond ((eq step :end) (return :end))
                 ((funcall predicate (car step))
                  (return (cons (car step) (stream-filter predicate (cdr step)))))
                 (t (setf current (cdr step))))))))))

(defun %stream-scan-rest (function accumulator stream)
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (let ((next (funcall function accumulator (car step))))
             (cons next (%stream-scan-rest function next (cdr step)))))))))

(defun stream-scan (function seed stream)
  "Return the stream of running accumulations of STREAM under FUNCTION. SEED is
emitted first, then (FUNCTION accumulator element) after each element, so the
result has one more element than STREAM."
  (%make-flow-stream
   (lambda ()
     (cons seed (%stream-scan-rest function seed stream)))))

(defun stream-take (n stream)
  "Return a stream of at most the first N elements of STREAM."
  (%make-flow-stream
   (lambda ()
     (if (<= n 0)
         :end
         (let ((step (%stream-step stream)))
           (if (eq step :end)
               :end
               (cons (car step) (stream-take (1- n) (cdr step)))))))))

(defun stream-drop (n stream)
  "Return a stream of STREAM with its first N elements skipped."
  (%make-flow-stream
   (lambda ()
     (let ((current stream)
           (remaining n))
       (loop
         (if (<= remaining 0)
             (return (%stream-step current))
             (let ((step (%stream-step current)))
               (if (eq step :end)
                   (return :end)
                   (progn (setf current (cdr step))
                          (decf remaining))))))))))

(defun stream-take-while (predicate stream)
  "Return the longest leading run of STREAM whose elements satisfy PREDICATE."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (or (eq step :end) (not (funcall predicate (car step))))
           :end
           (cons (car step) (stream-take-while predicate (cdr step))))))))

(defun stream-drop-while (predicate stream)
  "Return STREAM with its longest leading PREDICATE-satisfying run removed. Once an
element fails PREDICATE, the remainder is emitted unchanged."
  (%make-flow-stream
   (lambda ()
     (let ((current stream))
       (loop
         (let ((step (%stream-step current)))
           (cond ((eq step :end) (return :end))
                 ((funcall predicate (car step)) (setf current (cdr step)))
                 (t (return (cons (car step) (cdr step)))))))))))

(defun %stream-distinct (stream seen test)
  (%make-flow-stream
   (lambda ()
     (let ((current stream)
           (already seen))
       (loop
         (let ((step (%stream-step current)))
           (cond ((eq step :end) (return :end))
                 ((member (car step) already :test test)
                  (setf current (cdr step)))
                 (t (return (cons (car step)
                                  (%stream-distinct (cdr step)
                                                    (cons (car step) already)
                                                    test)))))))))))

(defun stream-distinct (stream &key (test 'equal))
  "Return a stream of the elements of STREAM with duplicates (under TEST) removed,
keeping the first occurrence of each. Runs in O(n^2) in the number of distinct
elements, so it suits small to moderate streams."
  (%stream-distinct stream '() test))

(defun %stream-flat-map-cont (function inner outer)
  (%make-flow-stream
   (lambda ()
     (let ((inner-stream inner)
           (outer-stream outer))
       (loop
         (let ((inner-step (%stream-step inner-stream)))
           (if (eq inner-step :end)
               (let ((outer-step (%stream-step outer-stream)))
                 (if (eq outer-step :end)
                     (return :end)
                     (setf inner-stream (funcall function (car outer-step))
                           outer-stream (cdr outer-step))))
               (return (cons (car inner-step)
                             (%stream-flat-map-cont function
                                                    (cdr inner-step)
                                                    outer-stream))))))))))

(defun stream-flat-map (function stream)
  "Return the concatenation of the streams produced by applying FUNCTION to each
element of STREAM. FUNCTION must return a stream for every element."
  (%stream-flat-map-cont function (empty-stream) stream))

(defun %stream-concat-list (streams)
  (%make-flow-stream
   (lambda ()
     (let ((remaining streams))
       (loop
         (if (null remaining)
             (return :end)
             (let ((step (%stream-step (first remaining))))
               (if (eq step :end)
                   (setf remaining (rest remaining))
                   (return (cons (car step)
                                 (%stream-concat-list
                                  (cons (cdr step) (rest remaining)))))))))))))

(defun stream-concat (&rest streams)
  "Return the concatenation of STREAMS in order."
  (%stream-concat-list streams))

(defun stream-zip (stream-a stream-b)
  "Return a stream of (a . b) conses pairing STREAM-A with STREAM-B element by
element, stopping when either stream ends."
  (%make-flow-stream
   (lambda ()
     (let ((step-a (%stream-step stream-a))
           (step-b (%stream-step stream-b)))
       (if (or (eq step-a :end) (eq step-b :end))
           :end
           (cons (cons (car step-a) (car step-b))
                 (stream-zip (cdr step-a) (cdr step-b))))))))

(defun stream-tap (function stream)
  "Return a stream identical to STREAM, calling FUNCTION on each element for its
side effect as the element passes through."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (progn
             (funcall function (car step))
             (cons (car step) (stream-tap function (cdr step)))))))))

;;; --- Consumers (stream -> value) -----------------------------------------

(defun stream-collect (stream)
  "Force STREAM and return its elements as a fresh list."
  (let ((result '())
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return (nreverse result)))
        (push (car step) result)
        (setf current (cdr step))))))

(defun stream-reduce (function seed stream)
  "Fold STREAM left to right under FUNCTION starting from SEED, returning the final
accumulator."
  (let ((accumulator seed)
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return accumulator))
        (setf accumulator (funcall function accumulator (car step)))
        (setf current (cdr step))))))

(defun stream-for-each (function stream)
  "Call FUNCTION on each element of STREAM for its side effect. Returns no values."
  (let ((current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return (values)))
        (funcall function (car step))
        (setf current (cdr step))))))

(defun stream-count (stream)
  "Return the number of elements in STREAM."
  (let ((count 0)
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return count))
        (incf count)
        (setf current (cdr step))))))

(defun stream-first (stream &optional default)
  "Return the first element of STREAM, or DEFAULT when STREAM is empty."
  (let ((step (%stream-step stream)))
    (if (eq step :end) default (car step))))

(defun stream-empty-p (stream)
  "Return true when STREAM has no elements."
  (eq (%stream-step stream) :end))
