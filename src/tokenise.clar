
(= tokens    `()  ;#`
   recode    /^[^]*?(?=;.*[\n\r]?|""|"[^]*?(?:[^\\]")|''|'[^]*?(?:[^\\]')|\/[^\s]+\/[\w]*)/
             ;# ^ matches until first comment, '-string, "-string, or regex
   recomment /^;.*[\n\r]?/                     ; first comment
   redstring /^""|^"[^]*?(?:[^\\]")[^\s):\[\]\{\}]*/   ; first " string + data until delimiter
   resstring /^''|^'[^]*?(?:[^\\]')[^\s):\[\]\{\}]*/   ; first ' string + data until delimiter
   rereg     /^\/[^\s]+\/[\w]*[^\s)]*/)        ; first regex + data until delimiter


(def grate str
     (do str
         (.replace /;.*$/gm         "")       ; drop comments if any
         (.replace /\{/g            "(fn (")  ; desugar lambdas
         (.replace /\}/g            "))")     ; desugar lambdas
         (.replace /\(/g            " ( ")
         (.replace /\)/g            " ) ")
         (.replace /\[$/g           " [ ")
         (.replace /\['/g           " [ '")
         (.replace /\["/g           ' [ "')
         (.replace /'\]/g           "' ] ")
         (.replace /"\]/g           '" ] ')
         (.replace /\[[\s]*\(/g     " [ ( ")
         (.replace /\)[\s]*\]/g     " ) ] ")
         (.replace /([^:]):(?!\:)/g "$1 : ")
         (.replace /`/g             " ` ")
         (.replace /,/g             " , ")
         (.replace /\.\.\./g        " ... ")
         (.replace /…/g             " … ")
         (.trim)
         (.split /\s+/)))

(def concatNewLines str (str.replace /\n|\n\r/g "\\n"))

(def match str re
     (if (and (= mask (str.match re))
              (> (car mask).length 0))
         (car mask)
         null))

(def tokenise str
     (do (= tokens `())
         (while (> (= str (str.trim)).length 0)
                (if (= mask          (match str recode))
                    (do (tokens.push …(grate mask))
                        (= str       (str.replace recode "")))
                    (elif (= mask    (match str recomment))
                          (= str     (str.replace recomment "")))
                    (elif (= mask    (match str redstring))
                          (do (tokens.push (concatNewLines mask))
                              (= str (str.replace redstring ""))))
                    (elif (= mask    (match str resstring))
                          (do (tokens.push (concatNewLines mask))
                              (= str (str.replace resstring ""))))
                    (elif (= mask    (match str rereg))
                          (do (tokens.push mask)
                              (= str (str.replace rereg ""))))
                    (do (tokens.push …(grate str))
                        (= str ""))))
         (tokens.filter (fn x (and (? x) (isnt x "" undefined null))))))
(= module.exports tokenise)
