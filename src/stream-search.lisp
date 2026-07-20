(in-package #:cl-dataflow)

;;;; Search, predicate, and combinatorial helpers over streams: first-match index,
;;;; a "no element matches" predicate, the most frequent element, and the Cartesian
;;;; product of two streams. Consumers iterate; STREAM-CARTESIAN stays lazy.

(defun stream-find-index (predicate stream &key limit)
  "Return the 0-based index of the first element of STREAM satisfying PREDICATE, or
NIL when none does. LIMIT bounds the number of input elements accepted."
  (%validate-stream-limit limit "STREAM-FIND-INDEX")
  (let ((index 0)
        (current stream))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return nil))
        (when (and limit (= index limit))
          (%signal-stream-limit-exceeded "STREAM-FIND-INDEX" limit))
        (when (funcall predicate (car step)) (return index))
        (incf index)
        (setf current (cdr step))))))

(defun stream-none-p (predicate stream &key limit)
  "Return true when no element of STREAM satisfies PREDICATE (true for an empty
stream). LIMIT bounds the number of input elements accepted."
  (%validate-stream-limit limit "STREAM-NONE-P")
  (let ((current stream)
        (count 0))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return t))
        (when (and limit (= count limit))
          (%signal-stream-limit-exceeded "STREAM-NONE-P" limit))
        (when (funcall predicate (car step)) (return nil))
        (incf count)
        (setf current (cdr step))))))

(defun stream-mode (stream &key (test 'equal) limit)
  "Return the most frequently occurring element of STREAM (the first-seen element
wins ties), or NIL when STREAM is empty. TEST is the hash-table equality used to
group elements. LIMIT bounds the number of input elements accepted."
  (%validate-stream-limit limit "STREAM-MODE")
  (let ((counts (make-hash-table :test test))
        (order '())
        (current stream)
        (count 0))
    (loop
      (let ((step (%stream-step current)))
        (when (eq step :end) (return))
        (when (and limit (= count limit))
          (%signal-stream-limit-exceeded "STREAM-MODE" limit))
        (let ((element (car step)))
          (unless (nth-value 1 (gethash element counts))
            (push element order)
            (setf (gethash element counts) 0))
          (incf (gethash element counts)))
        (incf count)
        (setf current (cdr step))))
    (let ((best nil)
          (best-count -1))
      (dolist (element (nreverse order) best)
        (when (> (gethash element counts) best-count)
          (setf best-count (gethash element counts)
                best element))))))

(defun stream-cartesian (stream-a stream-b)
  "Return a stream of (A . B) conses for every pair drawn from STREAM-A and
STREAM-B, with B varying fastest. STREAM-B is re-consumed once per element of
STREAM-A (streams are pure, so this is safe)."
  (stream-flat-map (lambda (a)
                     (stream-map (lambda (b) (cons a b)) stream-b))
                   stream-a))
