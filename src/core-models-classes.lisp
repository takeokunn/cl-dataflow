(in-package #:cl-dataflow)

(defclass node ()
  ((name :initarg :name)
   (inputs :initarg :inputs)
   (outputs :initarg :outputs)
   (handler :initarg :handler)
   (metadata :initarg :metadata :initform '())))

(defclass edge ()
  ((from :initarg :from)
   (from-port :initarg :from-port)
   (to :initarg :to)
   (to-port :initarg :to-port)
   (metadata :initarg :metadata :initform '())))

(defclass graph ()
  ((nodes :initform (%make-result-table))
   (edges :initform '())
   (metadata :initarg :metadata :initform '())))

(defclass context ()
  ((values :initform (%make-result-table))
   (events :initform '())
   (effects :initform '())
   (trace :initform '())
   ;; Mirrors (length trace); kept in sync by %PUSH-CONTEXT-TRACE-ENTRY and the
   ;; CONTEXT-TRACE setter so TRACE-INDEX allocation doesn't re-walk the whole
   ;; trace history on every event/effect.
   (trace-count :initform 0)
   (metadata :initarg :metadata :initform '())
   (effect-handlers :initform (%make-result-table))
   (result :initarg :result :initform nil)
   (state :initarg :state :initform nil)))

(defclass event ()
  ((type :initarg :type)
   (payload :initarg :payload :initform nil)
   (metadata :initarg :metadata :initform '())
   (trace-index :initarg :trace-index :initform nil)))

(defclass effect ()
  ((type :initarg :type)
   (payload :initarg :payload :initform nil)
   (metadata :initarg :metadata :initform '())
   (trace-index :initarg :trace-index :initform nil)
   (result :initarg :result :initform nil)))

(defclass state-transition ()
  ((from :initarg :from)
   (event-type :initarg :event-type)
   (to :initarg :to)
   (guard :initarg :guard :initform nil)
   (action :initarg :action :initform nil)
   (metadata :initarg :metadata :initform '())))

(defclass state-machine ()
  ((state :initarg :state)
   (initial-state :initarg :initial-state)
   (transitions :initarg :transitions :initform '())
   (history :initarg :history :initform '())
   (history-limit :initarg :history-limit :initform nil)
   (metadata :initarg :metadata :initform '())))

(defclass pipeline ()
  ((graph :initarg :graph)
   (stages :initarg :stages :initform '())
   (metadata :initarg :metadata :initform '())))

(defmethod print-object ((node node) stream)
  (print-unreadable-object (node stream :type t)
    (format stream "~A" (%escaped-display-string (node-name node)))))

(defmethod print-object ((edge edge) stream)
  (print-unreadable-object (edge stream :type t)
    (format stream "~A:~A -> ~A:~A"
            (%escaped-display-string (edge-from edge))
            (%escaped-display-string (edge-from-port edge))
            (%escaped-display-string (edge-to edge))
            (%escaped-display-string (edge-to-port edge)))))

(defmethod print-object ((graph graph) stream)
  (let ((node-count (hash-table-count (%graph-nodes-table graph)))
        (edge-count (length (%graph-edges-list graph))))
    (print-unreadable-object (graph stream :type t)
      (format stream "~D nodes ~D edges" node-count edge-count))))

(defmethod print-object ((context context) stream)
  (print-unreadable-object (context stream :type t)
    (format stream "events=~D effects=~D"
            (length (context-events context))
            (length (context-effects context)))))

(defmethod print-object ((transition state-transition) stream)
  (print-unreadable-object (transition stream :type t)
    (format stream "~A --~A--> ~A"
            (%escaped-display-string (transition-from transition))
            (%escaped-display-string (transition-event-type transition))
            (%escaped-display-string (transition-to transition)))))

(defmethod print-object ((machine state-machine) stream)
  (print-unreadable-object (machine stream :type t)
    (format stream "~A transitions=~D"
            (%escaped-display-string (state-machine-state machine))
            (length (state-machine-transitions machine)))))

(define-type-predicates
  (node-p node)
  (edge-p edge)
  (graph-p graph)
  (context-p context)
  (event-p event)
  (effect-p effect)
  (state-transition-p state-transition)
  (state-machine-p state-machine)
  (pipeline-p pipeline))
