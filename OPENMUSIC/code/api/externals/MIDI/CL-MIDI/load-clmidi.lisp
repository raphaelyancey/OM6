
(in-package :om-api)

(compile&load (make-pathname :directory (append *externals-directory* (list "MIDI" "CL-MIDI" "midi-20070618")) :name "midi")) 
(compile&load (make-pathname :directory (append *externals-directory* (list "MIDI" "CL-MIDI")) :name "clmidi-api"))

;(compile&load (make-pathname :directory (append *externals-directory* (list "MIDI" "CL-MIDI")) :name "midi-types"))
;(compile&load (make-pathname :directory (append *externals-directory* (list "MIDI" "CL-MIDI")) :name "midimsg2evt"))
