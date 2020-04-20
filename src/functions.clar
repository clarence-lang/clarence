; Built-in top-level clar functions
; The compiler embeds them into the compiled program

; Each function MUST NOT enclose any variables. It must be fully self-sufficient when printed with .toString
; Meaning, all utilities in this file must be macros, and nothing must be imported

(= exports.concat (def concat …lists
   (do (= _res `())
       (for lst lists
            (= _res (_res.concat lst)))
       _res)))

(= exports.list (def list …args `(…args)))

; (range <start> <end>)
; (range <end>)  ; start is 0
(= exports.range (def range start end
   (do (if (?! end) (= end start start 0))
       (while true (if (<= start end)
                       (do (= a start) (++ start) a)
                       (break))))))
