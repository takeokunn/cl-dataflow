(in-package #:cl-dataflow)

(defmethod context-effect-handlers ((context context))
  (%copy-effect-handlers (slot-value context 'effect-handlers)))

(defmethod (setf context-effect-handlers) (effect-handlers (context context))
  (setf (slot-value context 'effect-handlers)
        (if effect-handlers
            (%copy-effect-handlers effect-handlers)
            (%make-result-table))))

(defmethod context-state ((context context))
  (slot-value context 'state))

(defmethod (setf context-state) (state (context context))
  (setf (slot-value context 'state) state))

(define-slot-apis
  (event-type event type
              :getter (%read-slot event 'type)
              :writable :none)
  (event-payload event payload
                 :getter (%copy-structured-value (%read-slot event 'payload))
                 :setter (setf (slot-value event 'payload)
                               (%copy-structured-value value)))
  (event-metadata event metadata
                  :getter (copy-tree (%read-slot event 'metadata))
                  :setter (setf (slot-value event 'metadata)
                                (%normalize-metadata value)))
  (event-trace-index event trace-index
                     :getter (%read-slot event 'trace-index)
                     :writable :none)
  (effect-type effect type
               :getter (%read-slot effect 'type)
               :writable :none)
  (effect-payload effect payload
                  :getter (%copy-structured-value (%read-slot effect 'payload))
                  :setter (setf (slot-value effect 'payload)
                                (%copy-structured-value value)))
  (effect-metadata effect metadata
                   :getter (copy-tree (%read-slot effect 'metadata))
                   :setter (setf (slot-value effect 'metadata)
                                 (%normalize-metadata value)))
  (effect-trace-index effect trace-index
                      :getter (%read-slot effect 'trace-index)
                      :writable :none)
  (effect-result effect result
                 :getter (%copy-structured-value (%read-slot effect 'result))
                 :setter (setf (slot-value effect 'result)
                               (%copy-structured-value value)))
  (transition-from transition from
                   :setter (setf (slot-value transition 'from)
                                 (%normalize-name value)))
  (transition-event-type transition event-type
                         :setter (setf (slot-value transition 'event-type)
                                       (%normalize-name value)))
  (transition-to transition to
                 :setter (setf (slot-value transition 'to)
                               (%normalize-name value)))
  (transition-guard transition guard)
  (transition-action transition action)
  (transition-metadata transition metadata
                       :getter (copy-tree (slot-value transition 'metadata))
                       :setter (setf (slot-value transition 'metadata)
                                     (%normalize-metadata value)))
  (state-machine-state machine state
                       :setter (setf (slot-value machine 'state)
                                     (%normalize-name value)))
  (state-machine-initial-state machine initial-state
                               :setter (setf (slot-value machine 'initial-state)
                                             (%normalize-name value)))
  (state-machine-history machine history
                         :getter (copy-tree (slot-value machine 'history))
                         :setter (setf (slot-value machine 'history)
                                       (%copy-transition-history value)))
  (state-machine-metadata machine metadata
                          :getter (copy-tree (slot-value machine 'metadata))
                          :setter (setf (slot-value machine 'metadata)
                                        (%normalize-metadata value)))
  (node-name node name
             :setter (setf (slot-value node 'name)
                           (%normalize-name value)))
  (node-inputs node inputs
               :getter (%normalize-unique-port-list (slot-value node 'inputs) "input")
               :setter (setf (slot-value node 'inputs)
                             (%normalize-unique-port-list value "input")))
  (node-outputs node outputs
                :getter (%normalize-unique-port-list (slot-value node 'outputs) "output")
                :setter (setf (slot-value node 'outputs)
                              (%normalize-unique-port-list value "output")))
  (node-handler node handler)
  (node-metadata node metadata
                 :getter (copy-tree (slot-value node 'metadata))
                 :setter (setf (slot-value node 'metadata)
                               (%normalize-metadata value)))
  (edge-from edge from
             :setter (setf (slot-value edge 'from)
                           (%node-designator-name value)))
  (edge-from-port edge from-port
                  :setter (setf (slot-value edge 'from-port)
                                (%normalize-name (or value "value"))))
  (edge-to edge to
           :setter (setf (slot-value edge 'to)
                         (%node-designator-name value)))
  (edge-to-port edge to-port
                :setter (setf (slot-value edge 'to-port)
                              (%normalize-name (or value "value"))))
  (edge-metadata edge metadata
                 :getter (copy-tree (slot-value edge 'metadata))
                 :setter (setf (slot-value edge 'metadata)
                               (%normalize-metadata value))))
