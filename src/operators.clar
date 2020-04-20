
(= utils        (require "./utils")
   pr           utils.pr
   spr          utils.spr
   render       utils.render
   isIdentifier utils.isIdentifier
   assertForm   utils.assertForm)

(def makeop op zv (min 0) (max Infinity) (drop no)
; <operator> <zero value> <min args> <max args>
     (fn args innerType
         (if (assertForm args min max)
             (if (is args.length 0)
                 (pr zv)
                 (elif (and (is args.length 1) (? zv))
                       (do (= res (+ zv op (spr args)))
                           ; extra parens for precedence if more operators await
                           (if (and innerType (isnt innerType "parens"))
                               (= res (+ "(" res ")")))
                           res))
                 (elif (and (is args.length 1) drop)
                       (spr args))
                 (elif (is args.length 1)
                       (+ op (spr args)))
                 (do (for arg i args (= args[i] (pr arg)))
                     (= res (args.join (+ " " op " ")))
                     ; extra parens for precedence if more operators await
                     (if (and innerType (isnt innerType "parens"))
                         (= res (+ "(" res ")")))
                     res)))))

(def makesing op
     (fn args innerType
         (if (assertForm args 1 1)
             (+ op " " (spr args)))))

(def reserved word (throw (Error (+ "keyword " word " is reserved"))))

(def makestate op (min 0) (max Infinity)
; For 'pure statement' keywords that give an error when trying to assign
     (fn args innerType
         (if (assertForm args min max)
             (+ op " " (spr args)) "undefined")))


(= operators (
; Replacing clar functions with JS operators and keywords
; ToDo infinite arguments where possible
  ; (not a b c)  ->  (and (not a) (not b) (not c))

  ; arithmetic
  "++": (fn args innerType
    (if (assertForm args 1 1)
        (if (not (isIdentifier args[0]))
            (throw (Error "expecting identifier, got " (spr args)))
        (+ "++" (spr args)))))
  "--": (fn args innerType
    (if (assertForm args 1 1)
        (if (not (isIdentifier args[0]))
            (throw (Error "expecting identifier, got " (spr args)))
            (+ "--" (spr args)))))
  ; logical
  "is": (fn args innerType
    (if (is args.length 0)
        true
        (elif (is args.length 1)
              (+ "!!" (spr args)))
        (do (= subj (args.shift))
            (= res (do (for arg args (+ (pr subj) " === " (pr arg)))
                       (.join " || ")))
            (if (and innerType (isnt innerType "parens"))
              (= res (+ "(" res ")")))
            res)))
  "isnt": (fn args innerType
    (if (is args.length 0)
        false
        (elif (is args.length 1)
              (+ "!" (spr args)))
        (do (= subj (args.shift))
            (= res (do (for arg args (+ (pr subj) " !== " (pr arg)))
                       (.join " && ")))
            (if (and innerType (isnt innerType "parens"))
              (= res (+ "(" res ")")))
            res)))
  "or":  (makeop "||" undefined 1 Infinity yes) ; single arg returns itself
  "and": (makeop "&&" undefined 1 Infinity yes) ; single arg returns itself
  ; keywords
  "in": (fn args innerType
    ; todo more than 2 args (concat / spread?)
    (if (assertForm args 2 2)
        (do (= res (+ "[].indexOf.call(" (pr args[1]) ", " (pr (car args)) ") >= 0"))
            (if (and innerType (isnt innerType "parens"))
                (= res (+ "(" res ")")))
            res)))
  "of": (makeop "in" undefined 2 2)
  "new": (fn args innerType
    (if (assertForm args 1)
        (+ "new " (pr (args.shift)) "(" (spr args) ")")))
  ; reserved
    ; "var" -- throws compile error without var, todo fix
    ; "class"
  "function": (fn (reserved "function"))
  "with":     (fn (reserved "with"))
))

(= singops `(
  ("not" "!") ("~" "~") ("delete" "delete") ("typeof" "typeof") ("!!" "!!")
))

(for op singops (= operators[op[0]] (makesing op[1])))

(= ops `(
; todo un-retardify chained comparisons
; in JS, 3 < 2 < 1 produces true (facepalm)
; todo ops like += should take multiple ars and compile into one += and multiple +
  ; arithmetic
  ("+" undefined 1 Infinity yes) ("-" undefined 1) ("*" 1) ("/" 1) ("%" undefined 1)
  ; logical
  ("==" "is")      ("===" "is")  ("!=" "isnt")
  ("!==" "isnt")   ("&&" "and")  ("||"  "or")      ("!"  "not")
  ; comparison
  (">"   undefined 2) ("<"    undefined 2)
  (">="  undefined 2) ("<="   undefined 2)
  ; bitwise
  ("&"   undefined 2) ("|"    undefined 2) ("^"   undefined 2)
  ("<<"  undefined 2) (">>"   undefined 2) (">>>" undefined 2)
  ; assignment
  ("+="  undefined 2) ("-="   undefined 2) ("*="  undefined 2)
  ("/="  undefined 2) ("%="   undefined 2) ("<<=" undefined 2)
  (">>=" undefined 2) (">>>=" undefined 2) ("&="  undefined 2)
  ("^="  undefined 2) ("|="   undefined 2)
  ; words and keywords
  ("instanceof" undefined 2 2)
  ; other
  ("," undefined 2 2)  ; bugs out due to lexer dropping empty cells
))

(for op ops
     (if (is (typeof op[1]) "string")
         (= operators[op[0]] operators[op[1]])
         (= operators[op[0]] (makeop ...op))))

(= stateops `(
  ("return" 0 1) ("break" 0 1) ("continue" 0 0) ("throw" 1 1)
))

(for op stateops (= operators[op[0]] (makestate op[0])))
(= exports.operators operators)


(mac macMakeOp name operator zeroValue
; <func-name> <operator> <zero-value>
  `(def ,name ...args (do
    ; included if zeroValue was passed
    ,(if (? zeroValue)
      `(args.unshift ,zeroValue))
    ; included always
    (if (is args.length 0)
      ,zeroValue  ; defaults to undefined
      (args.reduce {,operator #0 #1})))))

(= opFuncs (:))

; Before we start putting these into opFuncs, main compiler needs to
; learn to only check for opFuncs when operator is not first in list

(macMakeOp add + 0)
(macMakeOp sub - 0)
(macMakeOp mul * 1)
(macMakeOp div / 1)

; (console.log (div 10))
; (console.log (add.toString))


(= exports.opFuncs opFuncs)
