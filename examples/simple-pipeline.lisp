;;; Run with:
;;;   sbcl --script examples/simple-pipeline.lisp
(load
  (merge-pathnames
    #P"bootstrap.lisp"
    (make-pathname :name nil :type nil :defaults *load-truename*)))

(let* ((parse
      (cl-dataflow:make-node
        "parse"
        :handler
        (lambda (input context)
          (declare (ignore context))
          (parse-integer input))))
       (validate
      (cl-dataflow:make-node
        "validate"
        :handler
        (lambda (input context)
          (declare (ignore context))
          (unless (plusp input)
            (error "Input must be positive"))
          input)))
       (transform
      (cl-dataflow:make-node
        "transform"
        :handler
        (lambda (input context)
          (declare (ignore context))
          (* input 10))))
       (render
      (cl-dataflow:make-node
        "render"
        :handler
        (lambda (input context)
          (declare (ignore context))
          (format nil "rendered: ~A" input))))
       (pipeline
      (cl-dataflow:make-pipeline :stages (list parse validate transform render))))
  (format
    t
    "~&Simple pipeline result: ~A~%"
    (cl-dataflow:run-pipeline pipeline :input "7")))
