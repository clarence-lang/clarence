; yanked at macro parse
(mac makeReduce name operator
  `(def ,name ...args
    (if (isnt args.length 0)
        (args.reduce {,operator #0 #1}))))

; yanked at macroexpand
(makeReduce mul *)

; code put back at macroexpand
; (def mul ...args
;   (if (isnt args.length 0)
;     (args.reduce {* #0 #1})))

; add your own macro call here
; try a non-operator
(mul 2 3 )
