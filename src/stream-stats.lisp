(in-package #:cl-dataflow)

;;;; A few more stream operators plus statistical aggregate consumers. The
;;;; statistics force the stream once and fold it in pure Lisp; each returns NIL
;;;; for an empty stream rather than dividing by zero.

(defun stream-flatten (stream)
  "Return a stream that concatenates the elements of each list yielded by STREAM
(one level of flattening). Equivalent to STREAM-FLAT-MAP with LIST->STREAM."
  (stream-flat-map #'list->stream stream))

(defun stream-scan1 (function stream)
  "Return the running accumulations of STREAM using its first element as the seed
(so the result starts with the first element, then each fold). An empty stream
yields the empty stream."
  (%make-flow-stream
   (lambda ()
     (let ((step (%stream-step stream)))
       (if (eq step :end)
           :end
           (%stream-step (stream-scan function (car step) (cdr step))))))))

(defun stream-count-if (predicate stream &key limit)
  "Return the number of elements of STREAM that satisfy PREDICATE. LIMIT bounds
the number of input elements accepted."
  (%validate-stream-limit limit "STREAM-COUNT-IF")
  (let ((count 0)
        (seen 0)
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return count))
        (when (and limit (= seen limit))
          (%signal-stream-limit-exceeded "STREAM-COUNT-IF" limit))
        (when (funcall predicate (car step)) (incf count))
        (incf seen)
        (setf current (cdr step))))))

(defun stream-variance (stream &key (key #'identity) limit)
  "Return the population variance of (FUNCALL KEY ELEMENT) over STREAM, or NIL when
STREAM is empty. LIMIT bounds the number of input elements accepted."
  (%validate-stream-limit limit "STREAM-VARIANCE")
  (let ((current stream)
        (count 0)
        (mean 0)
        (m2 0))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end)
          (return (if (zerop count) nil (/ m2 count))))
        (when (and limit (= count limit))
          (%signal-stream-limit-exceeded "STREAM-VARIANCE" limit))
        (let* ((value (funcall key (car step)))
               (new-count (1+ count))
               (delta (- value mean))
               (new-mean (+ mean (/ delta new-count)))
               (delta2 (- value new-mean)))
          (setf count new-count
                mean new-mean
                m2 (+ m2 (* delta delta2))))
        (setf current (cdr step))))))

(defun stream-stddev (stream &key (key #'identity) limit)
  "Return the population standard deviation of (FUNCALL KEY ELEMENT) over STREAM, or
NIL when STREAM is empty. LIMIT bounds the number of input elements accepted."
  (let ((variance (stream-variance stream :key key :limit limit)))
    (if variance
        (sqrt variance)
        nil)))

(defun stream-median (stream &key (key #'identity) limit)
  "Return the median of (FUNCALL KEY ELEMENT) over STREAM (the mean of the two
middle values for an even count), or NIL when STREAM is empty. LIMIT bounds the
number of input elements accepted."
  (let ((values (sort (mapcar key (stream-collect stream :limit limit)) #'<)))
    (if (null values)
        nil
        (let ((count (length values)))
          (if (oddp count)
              (nth (floor count 2) values)
              (/ (+ (nth (1- (floor count 2)) values)
                    (nth (floor count 2) values))
                 2))))))
