
(in-package :om)

(defclass! bpf-control (simple-container BPF) 
   ((c-action :initform nil :accessor c-action :initarg :c-action)
    (faust-control :initform nil :accessor faust-control :initarg :faust-control :documentation "A list of a Faust Effect (or Synth) and a name of a parameter (e.g : (<faust-synth-console> \"freq\"))")))

(defmethod make-one-instance ((self bpf-control) &rest slots-vals)
  (let ((bpf (call-next-method))
        infos)
    (setf (c-action bpf) (nth 3 slots-vals))
    (setf (faust-control bpf) (nth 4 slots-vals))
    (if (faust-control bpf)
        (progn
          (setf infos (get-infos-from-faust-control (faust-control bpf)))
          (if infos
              (progn
                (if (<= (- (nth 2 infos) (nth 1 infos)) 10)
                    (setf (decimals bpf) 1))
                (if (and (equal '(0 100) (nth 1 slots-vals)) (equal '(0 100) (nth 0 slots-vals)))
                    (progn
                      (setf (y-points bpf) (list (nth 1 infos) (nth 3 infos) (nth 3 infos) (nth 2 infos)))
                      (setf (x-points bpf) (list 0 500 9500 10000)))))
            (print "I cannot build a bpf-control with these parameters"))
          bpf))))

(defmethod omng-copy ((self bpf-control))
  (let ((bpf (eval (call-next-method))))
    (setf (c-action bpf) (c-action self)
          (faust-control bpf) (faust-control self)
          (decimals bpf) (decimals self)
          (x-points bpf) (x-points self)
          (y-points bpf) (y-points self))
    bpf))

(defmethod copy-container ((self bpf-control) &optional (pere ()))
   "Builds a copy of a bpf control"
   (let ((bpf (eval (call-next-method))))
    (setf (c-action bpf) (c-action self)
          (faust-control bpf) (faust-control self)
          (decimals bpf) (decimals self)
          (x-points bpf) (x-points self)
          (y-points bpf) (y-points self))
    bpf))

(defmethod print-object ((self bpf-control) stream)
  (call-next-method))
;  (format stream "BPF-CONTROL: ~A ~D" (c-action self) (slot-value self 'offset)))

(defmethod play-obj? ((self bpf-control)) t)
(defmethod allowed-in-maq-p ((self bpf-control)) t)
(defmethod get-obj-dur ((self bpf-control)) (last-elem (x-points self)))
;(defclass bpf-player (omplayer) ())
;(defmethod class-from-player-type ((type (eql :bpfplayer))) 'bpf-player)

(defmethod prepare-to-play ((self (eql :bpfplayer)) (player omplayer) (object bpf-control) at interval)
  ;(player-unschedule-all self)
  (let ((faustfun (if (faust-control object)
                      (get-function-from-faust-control (faust-control object)))))
    (print faustfun)
    (when (or (c-action object) (faust-control object))
      (if interval
          (mapcar #'(lambda (point) 
                      (if (and (>= (car point) (car interval)) (<= (car point) (cadr interval)))
                          (progn
                            (if (c-action object) 
                                (schedule-task player 
                                               #'(lambda () (funcall (c-action object) (cadr point))) 
                                               (+ at (car point))))
                            (if (faust-control object) 
                                (schedule-task player
                                               #'(lambda () (funcall faustfun (cadr point))) 
                                               (+ at (car point)))))))
                  (point-pairs object))
        (mapcar #'(lambda (point)
                    (if (c-action object)
                        (schedule-task player 
                                       #'(lambda () (funcall (c-action object) (cadr point))) 
                                       (+ at (car point))))
                    (if (faust-control object) 
                        (schedule-task player
                                       #'(lambda () (funcall faustfun (cadr point))) 
                                       (+ at (car point)))))
                (point-pairs object))))))

;(defmethod player-stop ((player bpf-player) &optional object)
;  (call-next-method)
;  (player-unschedule-all player))

(defmethod default-edition-params ((self bpf-control)) 
  (pairlis '(player) '(:bpfplayer) (call-next-method)))


;;;=======================================================

(defmethod get-editor-class ((self bpf-control)) 'bpfcontroleditor)

(defclass bpfcontroleditor (bpfeditor play-editor-mixin) ())
;;(defmethod get-score-player ((self bpfcontroleditor)) :bpfplayer)
;(defmethod get-edit-param ((self bpfcontroleditor) (param (eql 'player))) :bpfplayer)
(defmethod cursor-panes ((self bpfcontroleditor)) (list (panel self)))

(defclass bpfcontrolpanel (bpfpanel cursor-play-view-mixin) ())
(defmethod view-turn-pages-p ((self bpfcontrolpanel)) nil)
(defmethod get-panel-class ((Self bpfcontroleditor)) 'bpfcontrolpanel)

(defmethod get-x-range ((self bpfcontrolpanel))
  (let ((range (real-bpf-range (object (editor self))))
        x)
    (setf x (list (nth 0 range) (nth 1 range)))
    x))

(defmethod time2pixel ((self bpfcontrolpanel) time)
  (call-next-method self (* time (expt 10 (decimals (object (editor self)))))))

(defmethod handle-key-event ((Self bpfcontrolpanel) Char)
  (cond ((equal char #\SPACE) (editor-play/stop (editor self)))
        (t (call-next-method))))

(defun get-function-from-faust-control (faust-control)
  (let* ((name (cadr faust-control))
         (console (car faust-control))
         (ptr (if (typep console 'faust-effect-console) (effect-ptr console) (synth-ptr console)))
         (maxnum (las-faust-get-control-count ptr))
         infos minval maxval range found text-to-up display graph-to-up paramtype)
    (loop for i from 0 to (- maxnum 1) do
          (if (string= name (car (las-faust-get-control-params ptr i)))
              (setf found i)))
    (setf infos (las-faust-get-control-params ptr found))
    (setf minval (nth 1 infos))
    (setf maxval (nth 2 infos))
    (if (= minval maxval) (setf minval 0
                                maxval 1))
    (setf range (- maxval minval))
    (setf display (display (nth found (params-ctrl console))))
    (setf text-to-up (paramval display))
    (setf graph-to-up (paramgraph display))
    (setf paramtype (param-type (nth found (params-ctrl console))))
    (if graph-to-up
        #'(lambda (val)
            (if (< val minval) (setf val minval))
            (if (> val maxval) (setf val maxval))
            (las-faust-set-control-value ptr found (float val))
            (cond ((string= paramtype "checkbox")
                   (om-set-check-box graph-to-up (if (>= val 1) t)))
                  ((string= paramtype "numentry")
                   (progn
                     (om-set-dialog-item-text text-to-up (number-to-string (float val)))
                     (set-value graph-to-up (* 100 (/ (- val minval) range)))))
                  (t 
                   (progn
                     (om-set-dialog-item-text text-to-up (number-to-string (float val)))
                     (om-set-slider-value graph-to-up (* 100 (/ (- val minval) range)))))))
      #'(lambda (val) 
          (las-faust-set-control-value ptr found (float val))))))

(defun get-infos-from-faust-control (faust-control)
  (let* ((name (cadr faust-control))
         (console (car faust-control))
         (ptr (if (typep console 'faust-effect-console) (effect-ptr console) (synth-ptr console)))
         (maxnum (las-faust-get-control-count ptr))
         found
         listing)
    (loop for i from 0 to (- maxnum 1) do
          (if (string= name (car (las-faust-get-control-params ptr i)))
              (setf found i)))
    (if found
        (las-faust-get-control-params ptr found)
      (let ((param-n (make-param-select-window 
                      (loop for i from 0 to (- maxnum 1) collect
                            (car (las-faust-get-control-params ptr i))))))
        (if param-n 
            (las-faust-get-control-params ptr param-n)
          nil)))))




(defun make-param-select-window (listing)
  (let ((win (om-make-window 'om-dialog
                             :window-title "Parameter selection" 
                             :size (om-make-point 400 210) 
                             :scrollbars nil
                             :position (om-make-point 100 50))))

    (setf panel (om-make-view 'om-view
                              :owner win
                              :position (om-make-point 0 0) 
                              :scrollbars nil
                              :retain-scrollbars nil
                              :bg-color *om-dark-gray-color*
                              :field-size  (om-make-point 400 200)
                              :size (om-make-point (w win) (h win))))
    (setf text1 (om-make-dialog-item 'om-static-text 
                                     (om-make-point 90 5) 
                                     (om-make-point 340 20)
                                     (format nil "Your parameter slot is empty or invalid.")
                                     :font *om-default-font1* 
                                     :fg-color *om-white-color*))
    (setf text2 (om-make-dialog-item 'om-static-text 
                                     (om-make-point 30 25) 
                                     (om-make-point 390 20)
                                     (format nil "Please select the parameter you want to automate in this list :")
                                     :font *om-default-font1* 
                                     :fg-color *om-white-color*))
    (setf paramlist (om-make-dialog-item  'om-single-item-list 
                                          (om-make-point 50 55) 
                                          (om-make-point 300 100) 
                                          "Available parameters"  
                                          :scrollbars :v
                                          :bg-color *om-white-color*
                                          :after-action (om-dialog-item-act item 
                                                          (om-return-from-modal-dialog win (om-get-selected-item-index item)))
                                          :range listing))
    (setf ok (om-make-dialog-item 'om-button 
                                  (om-make-point 105 163) 
                                  (om-make-point 70 24)  "OK"
                                  :di-action (om-dialog-item-act item 
                                               (if (om-get-selected-item-index paramlist)
                                                   (om-return-from-modal-dialog win (om-get-selected-item-index paramlist))))))
    (setf cancel (om-make-dialog-item 'om-button 
                                      (om-make-point 225 163) 
                                      (om-make-point 70 24)  "Cancel"
                                      :di-action (om-dialog-item-act item (om-return-from-modal-dialog win nil))))
    (om-add-subviews panel text1 text2 paramlist ok cancel)
    (om-add-subviews win panel)
    (om-modal-dialog win)))
