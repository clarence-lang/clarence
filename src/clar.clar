; Version
(= exports.version "0.2.1")

; External dependencies
(= vm             (require "vm")
   fs             (require "fs")
   path           (require "path")
   beautify       (require "js-beautify"))

; clar dependencies
(= utils          (require "./utils")
   ops            (require "./operators")
   operators      ops.operators
   opFuncs        ops.opFuncs
   tokenise       (require "./tokenise")
   lex            (require "./lex")
   parse          (require "./parse")
   Uniq           (require "./uniq"))

; Util
(= pr             utils.pr   ; this must be applied to EVERY form we render or print to console
   spr            utils.spr  ; or this, depending on task
   render         utils.render
   isAtom         utils.isAtom
   isHash         utils.isHash
   isList         utils.isList
   isVarName      utils.isVarName
   isIdentifier   utils.isIdentifier
   isService      utils.isService
   getServicePart utils.getServicePart
   assertExp      utils.assertExp
   plusname       utils.plusname)

; This file has gotten insanely big and repetitive, todo rearchitect and deduplicate
; ToDo move exports to a `clar` object and export just that object
; Lists of built-in functions whose names have been overridden by an early `=` or `def`
(= functionsRedeclare `()
   functionsRedefine  `())

; Checks if user-defined name in scope, puts name in declaration if not, otherwise drops it
(def declareVar name scope
     (if (in name scope.hoist)
         scope
         (do (scope.hoist.push name)
             scope)))
; Usage when declaring variable:
; (= scope (declareVar name scope))

; Checks if service name in scope, modifies name until it's not, puts into scope service
(def declareService name scope (do
     (while (or (in name scope.hoist)
                (in name scope.service))
            (= name (plusname name)))
     (scope.service.push name)
     `(name scope)))
; Usage when declaring service variable:
; (= (name scope) (declareService candidate scope))

; Checks list of args, returns true if any of them are "spread" forms
(def hasSpread form
  (and (isList form) (is (car form) "spread")))

; Compiles form, resolves naming conflicts, returns compiled, buffer, and modified scope
(def compileResolve form buffer scope opts nested (do
  ; Compile new form and modify scope
  (= (compiled scope) (compileForm form scope opts nested))
  ; Check if newly hoisted vars overlap service vars in scope + buffer and rename accordingly
  (over name i scope.service
    (if (in name scope.hoist) (do
      (= newname name)
      (while (in newname scope.hoist)
        (= newname (plusname newname)))
      (= scope.service[i] newname
         re (RegExp (+ "(?=(?:[^$#_A-Za-z0-9]{1}|^)" name "(?:[^$#_A-Za-z0-9]{1}|$))([^$#_A-Za-z0-9]|^)" name) "g")  ; matches old name; probably also inside strings and regexes, todo check and fix
         subst (+ "$1" newname))
      (for str i buffer
           (if (and (? str) (is (typeof str) "string")) (= buffer[i] (str.replace re subst)))))))
  `(compiled buffer scope)))

; Compiles form and adds result to passed buffer and scope
(def compileAdd form buffer scope opts nested (do
  (= (compiled buffer scope) (compileResolve form buffer scope opts nested))
  (buffer.push ...compiled)
  `(buffer scope)))

; Compiles given form, modifying buffer and scope, and splits off last expression
(def compileGetLast form buffer scope opts nested
     (do (= (buffer scope) (compileAdd form buffer scope opts nested)
            lastItem       (buffer.pop))
         `(lastItem buffer scope)))

; Prepends `return` to expression or form
(def returnify form
     (if (or (isAtom form) (isHash form))
         `("return" form)
         (elif (and (isList form) (utils.isBlankObject form))  ; []
               form)
         (elif (and (isList form) (is form.length 1) (utils.isBlankObject (car form)))  ; [[]]
               (car form))
         (elif (and (isList form) (isnt (car form) "return"))
               `("return" form))
         form))

(def getArgNames args
  (do (= arr `())
      (for arg args
         (if (and (isAtom arg) (isVarName arg))
             (arr.push arg)
             (elif (and (isList arg) (isVarName (car arg))
                        (not (in (car arg) (Object.keys specials)))
                        (not (in (car arg) (Object.keys macros)))
                        (not (is (car arg) "mac")))
                   (arr.push (car arg)))))
      arr))

; Checks if a functions built-in name has been redefined
(def notRedefined name
  (and (not (in name functionsRedeclare))
       (not (in name functionsRedefine))))

; Checks if a form begins with a property reference (for chaining)
(def isPropertyExp form
  (and (isList form)
       (or (and (isList (car form))
                (is (car form).length 2)
                (is (car (car form)) "get"))
           (utils.isPropSyntax (car form)))))

; Shorter version of compileAdd
(mac macCompileAdd form (nested "nested")
   `(= (buffer scope) (compileAdd ,form buffer scope opts ,nested)))

; Shorter version of compileGetLast
(mac macCompileGetLast form name (nested "nested")
  `(= (,name buffer scope) (compileGetLast ,form buffer scope opts ,nested)))

; Shorter version of compileResolve
(mac macCompileResolve form container (nested "nested")
  `(= (,container buffer scope) (compileResolve ,form buffer scope opts ,nested)))

; Wrapper for declareVar with checks to override built-in functions where relevant
(mac macDeclareVar name (override yes) (declare yes)
  `(if (isService ,name)  ; if service name like #ref, compile it; this declares it in service scope
    (macCompileGetLast ,name ,name)
    (do (assertExp ,name isVarName "valid identifier")
      ,(if override
        `(if (and opts.topScope
               (in ,name (Object.keys functions))
               (not (in ,name scope.hoist))
               (notRedefined ,name))
          ,(if declare
            `(functionsRedeclare.push ,name)
            `(functionsRedefine.push  ,name))))
      ,(if declare
        `(= scope (declareVar ,name scope))))))

; Shorter version of declareService
(mac macDeclareService name candidate
  `(= (,name scope) (declareService ,candidate scope (if opts.function args))))

(mac macForkScope
; If this form declares variables, fork scope
  `(do (= outerScope scope
          scope      (JSON.parse (JSON.stringify outerScope)))
       (delete opts.topScope)))

(mac macDeclareOrHoist (dest "buffer") (do
; Declare vars and funcs or hoist funcs as appropriate
  `(do
    (= vars  ``()
       funcs ``()
       dec   "var ")
    ; Deal with new names: declare, drop, or bubble up if funcs
    (if (?! args) (= args ``()))
    (for name scope.hoist
      (if (and (not (in name outerScope.hoist))
               (not (in name args)))
        (if (in name (Object.keys functions))
          (if (and opts.topScope (in name functionsRedeclare))
              (vars.push name)
            (if (notRedefined name)
              (funcs.push name)))
          (elif (or (in name (Object.keys opFuncs))
                    (in name (Object.keys macros)))
            (funcs.push name))
          (if (not (is name "this"))
              (vars.push name)))))
    (for name scope.service
      (if (not (in name outerScope.service))
        (vars.push name)))
    ; Declare vars
    (while (> vars.length 0) (do
      (= name (vars.shift))
      (if (in name vars)
          (throw (Error (+ "compiler error: duplicate var in declarations:" name))))  ; no pr, expecting string
      (+= dec (+ name ", "))))
    (if (> dec.length 4)
        (do (= dec (dec.slice 0 (- dec.length 2)))
            (do ,dest (.unshift dec))))
    ; Declare funcs if functions, otherwise bubble all the way up
    (if (and (? isTopLevel) isTopLevel)
      (while (> funcs.length 0) (do
        (= func (funcs.pop))
        (if (in func funcs)
          (throw (Error (+ "compiler error: duplicate func in declarations:" func))))  ; no pr, expecting string
        (if (in func (Object.keys functions))
          ; embed only if not redeclared or redefined
          (if (notRedefined func)
              (if (and (? functions[func].name) (isnt functions[func].name ""))
                  ; embed like named function
                  (do ,dest (.unshift (functions[func].toString)))
                  ; embed like lambda
                  (if (isVarName func)
                      (do ,dest (.unshift (+ "var " func " = " (functions[func].toString) ";"))))))
          (elif (and (in func (Object.keys macros)) (isVarName func))
            (do ,dest (.unshift (+ "var " func " = " (macros[func].toString) ";"))))
            ; ToDo embedding of opFuncs with .toString and renaming of references in code when not first in list
          (elif (and (in func (Object.keys opFuncs)) (isVarName func))
            (do ,dest (.unshift (+ "var " opFuncs[func].name " = " (opFuncs[func].func.toString) ";"))))  ; no pr, expecting strings
          (throw (Error (+ "unrecognised func: " (pr func)))))))
        (for func funcs
          (if (not (in func outerScope.hoist))
            (outerScope.hoist.push func))))
      ; Will return outer scope: nothing gets out except for funcs
    (= scope outerScope))  ; / macro output
))  ; /macro

(mac macCompileSpecial opts (do
  `(fn form scope (opts (:)) nested (do
    (= buffer   ``()
       form     (form.slice)  ; duplicate object to avoid changing it for callers
       formName (form.shift))
    ; Check args number if relevant
    ,(if opts.argsMin
         `(if (< form.length ,opts.argsMin)
              (throw (Error (+ (pr formName) " expects no less than " (pr ,opts.argsMin) " arguments")))))
    ,(if opts.argsMax
         `(if (> form.length ,opts.argsMax)
              (throw (Error (+ (pr formName) " expects no more than " (pr ,opts.argsMax) " arguments")))))
    ; Unset nested if passed, move value under another name to avoid propagating it further (compile macros pass it automatically)
    (= nestedLocal (if (? nested) nested true)
       nested      undefined)
    ; Put in code from caller
    ,opts.code
    ; Return compiled
    (Array buffer scope)
  ))  ; /lambda
))  ; /macro

(mac macMacroCheck form
; Check if a form is a macro call and expand it
  `(if (and (isList ,form) (in (car ,form) (Object.keys macros)))
    (macCompileGetLast ,form ,form)))


; Compiles form, switching between types
; Takes: <form to compile> <scope> <options>
; Returns: <array of compiled strings> <modified scope>
(def compileForm form scope (opts (:)) nested (do
  ; Switch between form types and compile accordingly
  (if (and (isList form) (utils.isBlankObject form))
    `(("") scope)
    (elif (isAtom form) (do
      ; ToDo: check for reserved and forbidden words right here
      ; If name of toprange clar func, hoist if not redefined earlier
      ; If name of operator, hoist appropriate func and replace atom with func name
      (if (or (and (in form (Object.keys functions))
                   (notRedefined form))
              (in form (Object.keys macros)))
        (macDeclareVar form no)
        ; ToDo only do this when not first element in list
        (elif (in form (Object.keys opFuncs))
          (do
            (macDeclareVar form no)
            (= form opFuncs[form].name))))
      ; If name is a service name like #ref, declare it as a service var and replace the name
      (if (isService form) (do
        ; Get service part of name
        (= serv (getServicePart form)
           re   (RegExp (+ "^" serv)))
        ; Define corresponding service var, get replacement name
        (if (not (in serv (Object.keys scope.replace)))
            (macDeclareService scope.replace[serv] (cdr serv)))
        ; Replace service part of this name
        (= form (form.replace re scope.replace[serv]))))
      `((form) scope)))
    (elif (isHash form) (do
      (= buffer `())
      ; Unset nested
      (= nested undefined)
      (over val key form
        (macCompileGetLast val form[key]))
      (buffer.push form)
      `(buffer scope)))
    (do  ; Assume list, either special form or function call
      (if (not (isList form)) (throw (Error (+ "expecting list, got: " (pr form)))))
      (= buffer `())
      (= form (form.slice))  ; duplicate object to avoid changing it for callers
      (if (in (car form) (Object.keys specials))  ; special forms have their own rules
        (= (buffer scope) (specials[(car form)] form scope opts nested))
        ; if a macro definition, define it and revise the result
        (elif (is (car form) "mac")
          (macCompileAdd (parseMacros form)))
        ; if a known macro, expand it and revise the result
        (elif (in (car form) (Object.keys macros))
          (do
            ; fork the `replace` part of the scope to trigger new service declarations
            ; this ensures no overlaps in service names like #res between outer and inner code
            (= oldReplace    scope.replace
               scope.replace (:))
            (macCompileAdd (expandMacros form))
            ; revert to the outer `replace` store, dropping the inner store (which should be no longer relevant)
            (= scope.replace oldReplace)))
        (do  ; Not a special form? -> function call
          ; Unset nested (callees assume true)
          (= nestedLocal nested
             nested      undefined)
          ; Compile first element (compiles to itself if atom)
          (macCompileGetLast (form.shift) first)
          ; If clar-top-level func, hoist it
          (if (and (in first (Object.keys functions))
                   (notRedefined first))
            (macDeclareVar first no))
          ; If operator, check if we're inside compile call to another operator; if not, put this into options
          (if (in first (Object.keys operators))
              (do (if (not opts.compilingOperator) (= isOuterOperator yes))
                  (= innerType              (or nestedLocal (is opts.compilingOperator))
                     opts.compilingOperator yes))
              ; If not operator, unset operator option for inner calls
              (do (= opts (JSON.parse (JSON.stringify opts)))
                  (delete opts.compilingOperator)))
          ; Compile each element and test for spread
          (for arg i form (do
               (if (hasSpread arg)
                   (do
                     (= argsSpread true)
                     (macCompileGetLast arg arg)
                     (= form[i] `("spread" arg)))
                   (do
                     (macCompileGetLast arg arg)
                     (= form[i] arg)))))
          ; Compile: simple or with spread
          (if (?! argsSpread)
            (if (in first (Object.keys operators))
                (buffer.push (operators[first] form innerType))
                (buffer.push (+ (pr first) "(" (spr form) ")")))
            (do  ; Compile as spread
              ; Compile args into expression that produces single list with elements spread into it, like `(1 2 ...`(3 4)) -> `(1 2 3 4)
              (= form `("quote" ,form))
              (macCompileGetLast form form)
              ; Embed as function and replace `first`
              ; Only operators that take multiple arguments allow spread; others give a compile error
              (if (in first (Object.keys operators))
                ; ToDo implement embedding as .toString and renaming of references which are not first element in list
                (if (and (in first (Object.keys opFuncs))
                         (spr opFuncs[first]))
                    (do (macDeclareVar first no)
                        (= first opFuncs[first].name))
                    (throw (Error (+ (pr first) " can't spread arguments (yet)")))))
              ; Split object name and method for applying
              (= split (utils.splitName first))
              (if (> split.length 1)
                  (= method (split.pop)
                     name   (split.join ""))
                  (= method ""
                     name   (car split)))
              ; Apply, passing self and list of spread args
              (if (isIdentifier name)
                (buffer.push (+ name method ".apply(" name ", " (pr form) ")"))
                (do (= (collector scope) (declareService "_ref" scope))
                    (buffer.push (+ "(" collector " = " name ")" method ".apply(" collector ", " (pr form) ")"))))))))
          ; Unset operator option for outer calls
          (if (? isOuterOperator)
              (delete opts.compilingOperator))
          ; Return compiled
          `(buffer scope)))))


(= specials (:))

(= specials.do (macCompileSpecial
  (code: (do
    (if opts.isTopLevel
      (do (= isTopLevel true)
          (delete opts.isTopLevel)))
    (if isTopLevel (macForkScope))
    (for exp i form (do
      ; `nested` tells the compiler whether the compiled form is going to be on its own line or merged with something
      (= nested (or (and (not isTopLevel)
                         (is i (- form.length 1))
                         nestedLocal)
                    (isPropertyExp form[(+ i 1)])))
      (if (?! exp)
        (buffer.push exp)
        (if (isPropertyExp exp)
          ; .dot or [bracket] notation: implicit reference to last object for method chaining
          (do (= ref (buffer.pop))
            (if (?! ref) (= ref ""))
            (macCompileAdd exp)
            (buffer.push (+ ref "\n" (buffer.pop))))
          ; simple sequence element
          (macCompileAdd exp)))))
    (if isTopLevel (macDeclareOrHoist))))))

(= specials.quote (macCompileSpecial (argsMin: 1 argsMax: 1
  code: (do
    (= form (car form))
    (if (and (isAtom form) (not (utils.isPrimitive form)) (not (utils.isSpecialValue form)))
      (buffer.push (JSON.stringify form))  ; identifiers and strings get additional quotes that soak up the additional rendering done when expanding a macro
      (elif (isAtom form)
        (buffer.push form))
      (elif (isHash form)
        (if (not opts.macro)
          (do (over exp key form
                (macCompileGetLast exp form[key]))
              (buffer.push form))
          ; in macro: quote all elements in hash
          (do (= newform (:))
              (over exp key form (do
                (= key (JSON.stringify key))
                (macCompileGetLast `("quote" exp) newform[key])))
              (buffer.push newform))))
      ; assume list
      (do
        ; todo no concat if single exp
        (= arr `()    ; collector array literal
           res "[]")  ; collector string for .concat
        (for exp form (do
          (if (and (isList exp)    (is (car exp) "quote")
                   (isList exp[1]) (is exp[1].length 0))
            (arr.push `())  ; quoted empty list becomes empty array literal
            (elif (and (isList exp) (is (car exp) "unquote")
                       (isList exp[1]) (is (car exp[1]) "spread"))
              (do  ; explicit unquote
                ; if someone puts more than a single element into a spread list, all but the first will be lost; todo assert number
                (macCompileGetLast (car (cdr exp)) exp)
                (if (? exp)
                  (do
                    (if (> arr.length 0)
                        (do (+= res (+ ".concat(" (pr arr) ")"))
                            (= arr `())))
                    (+= res (+ ".concat(" (pr exp) ")"))))))
            (elif (and (isList exp) (is (car exp) "quote"))
              (do (macCompileGetLast exp exp)
                  (if (? exp) (arr.push exp))))
            (elif (and (isList exp) (is (car exp) "unquote"))
              (do (macCompileGetLast exp exp)
                  (if (and (? exp) opts.macro)
                    (if (isList exp)
                      (for item i exp
                        ; atoms need to be re-quoted after compilation
                        (if (isAtom item)
                          (macCompileGetLast `("quote" item) exp[i])))))
                  (if (? exp) (arr.push exp))))
            (elif (and (isList exp) (is (car exp) "spread")
                       (not opts.macro))
              (do  ; implicit unquote outside macro
                (macCompileGetLast exp exp)
                (if (? exp)
                  (do
                    (if (> arr.length 0)
                        (do (+= res (+ ".concat(" (pr arr) ")"))
                            (= arr `())))
                    (+= res (+ ".concat(" (pr exp) ")"))))))
            (do (if (and (isAtom exp) (not opts.macro))
                  (macCompileGetLast exp exp)
                  (macCompileGetLast `("quote" exp) exp))
                (if (? exp) (arr.push exp))))))
        (if (> arr.length 0)
            (if (is res "[]") (= res (pr arr))
                (+= res (+ ".concat(" (pr arr) ")"))))
        (buffer.push res)))
    ))))

(= specials.unquote (macCompileSpecial (argsMin: 1 argsMax: 1
  code: (do
    (= form (car form))
    (if (and (isList form) (is (car form) "quote"))
        (macCompileGetLast form form))
    (macCompileAdd form)))))

(= specials["="] (macCompileSpecial (argsMin: 1
; (= <name> <form> <name> <form> ...)
; (= <name>)
  code: (do
    (if (is form.length 1)
      (do (macDeclareVar (car form))
          (macCompileAdd (car form)))
      (do
        (assertExp form {is (% #0.length 2) 0} "an even number of arguments")
        (while (> form.length 0) (do
          (= left  (form.shift)
             right (form.shift))
          (= lastAssign (if (is form.length 0) true))
          (macCompileGetLast right right)
          ; Check and expand if has macros
          (macMacroCheck left)
          (if (and (isList left) (is (car left) "get"))  ; property access
            (do (macCompileGetLast left left)
                (= res (+ (pr left) " = " (pr right)))
                (if (and lastAssign nestedLocal (isnt nestedLocal "parens"))
                    (= res (+ "(" res ")")))
                (buffer.push res))
            (elif (isList left) (do  ; destructuring assignment
              (macDeclareService ref "_ref")
              (macDeclareService ind "_i")
              (buffer.push (+ ref " = " (pr right)))
              (= spreads 0)
              (for name i left
                (if (is (car name) "spread")
                  (do
                    (if (> (++ spreads) 1) (throw (Error "an assignment can only have one spread")))
                    (macCompileGetLast name name)
                    (macDeclareVar name)
                    (= spreadname name
                       spreadind  i)
                    (buffer.push (+ "var " spreadname " = " left.length " <= " ref ".length ? [].slice.call(" ref ", " spreadind ", " ind " = " ref ".length - " (- left.length spreadind 1) ") : (" ind " = " spreadind ", [])")))
                  (elif (?! spreadname)
                    (do (macCompileGetLast name name)
                        (if (isVarName name) (macDeclareVar name))
                        (buffer.push (+ (pr name) " = " ref "[" i "]"))))
                  (do (macCompileGetLast name name)
                      (if (isVarName name) (macDeclareVar name))
                      (buffer.push (+ (pr name) " = " ref "[" ind "++]")))))))
            (do (if (isVarName left) (macDeclareVar left))  ; normal assignment
                (assertExp left isIdentifier)
                (= res (+ (pr left) " = " (pr right)))
                (if (and (isHash right) (not nestedLocal))
                  (+= res ";"))  ; a hash table assignment needs to end with a semicolon, otherwise the next line is considered a part of this one
                (if (and lastAssign nestedLocal (isnt nestedLocal "parens"))
                    (= res (+ "(" res ")")))
                (buffer.push res)))))))))))

; Mostly the same code for `fn` and `def`
(mac macFunctionDefinition (type "fn")
  `(macCompileSpecial
    (code: (do
      ; Fork scope in accordance with JS function scoping
      (macForkScope)
      ,(if (is type "fn")  ; different arg splitting for `fn` and `def`
        `(= (...args body) form)
        `(do
          (= (fname ...args body) form)
          (macDeclareVar fname yes no)))
      (scope.hoist.push ...(getArgNames args))
      (if (?! body) (= body ``()))
      (= optionals ``()
         spreads   0)
      (for arg i args (do
        ; Expand if macro
        (macMacroCheck arg)
        (if (isList arg)
          (do
            (assertExp arg {is #0.length 2} "optional or rest parameter")
            (if (is (car arg) "spread")
              (do
                (if (> (++ spreads) 1) (throw (Error "cannot define more than one rest parameter")))
                (macDeclareService ind "_i")
                (macCompileGetLast arg name)
                (assertExp name isVarName "valid identifier")
                (= restname name
                   restind  i
                   args[i]  restname)
                (= rest (list (+ "var " name " = " args.length " <= arguments.length ? [].slice.call(arguments, " i ", " ind " = arguments.length - " (- args.length i 1) ") : (" ind " = " restind ", [])"))))
              (do  ; assume optional parameter
                (assertExp (= name (car arg)) isVarName "valid parameter name")
                (= args[i] name)
                (optionals.push ``("if" ("?!" name) ("=" name arg[1]))))))
          (elif restname
            (rest.push (+ (pr arg) " = arguments[" ind "++]"))))))  ; when there's a restname, `ind` is defined
      (if (? restind) (= args (args.slice 0 restind)))  ; drop restarg and all following args from arg list; prevents bug with empty rest
      (if (> optionals.length 0) (= body ``("do" ...optionals body)))
      (= body (returnify body))  ; put form into `("return" ...) special form
      (macCompileResolve body body)
      (if rest (body.unshift ...rest))
      ; Declare vars
      (macDeclareOrHoist body)
      ,(if (is type "fn")  ; different template for `fn` and `def`
        `(buffer.push (+ "(function(" (spr args) ") {" (render body) " })"))
        `(do
          (buffer.push (+ "function " fname "(" (spr args) ") {" (render body) " }"))
          (buffer.push fname)))))))

(= specials.fn  (macFunctionDefinition))
; (fn <args> (<body>))
; (fn (<body>))
; (fn)

(= specials.def (macFunctionDefinition def))
; (def <name> <args> (<body>))
; (def <name> (<body>))
; (def <name>)

(= specials.mac (fn form
; (mac <args> (<body>))
; macro definition: makes a macro and returns `("")
  (makeMacro form)))

; Puts collector variable in end of given branch
(def collect compiled collector (isCase no) (nestedLocal yes) (do
  (if (and (isList compiled) (> compiled.length 0)) (do
    ; when I wrote this, only God and I knew what this /\{$/ logic was for
    ; now, God only knows
    (if (/\{$/.test (last compiled))
      (= plug (compiled.pop)))
    (= lastItem (compiled.pop))
    ; collectify if we're nested
    (if nestedLocal
        (if (/^return\s/.test lastItem)
          (= lastItem (lastItem.replace /^return\s/ (+ "return " collector " = ")))
          (elif (utils.kwtest lastItem)
            (= lastItem (+ collector " = undefined; " lastItem)))
          (= lastItem (+ collector " = " (pr lastItem)))))
    (compiled.push lastItem)
    (if isCase (compiled.push "break"))
    (if (? plug) (compiled.push plug))))
  compiled))

(= specials.if (macCompileSpecial (code: (do
; (if <test> <then-branch> (elif <test> <elif-branch>)... <else-branch>)
; (if <test> <then-branch>)  ;; <else-branch> = undefined
; todo if last form in function and no returns inside, end each branch with return instead of collector variable
; what arguments mean:
  ; predicate prebranch   ...midcases postbranch
  ; test      then-branch ...elifs    else-branch
  (= (predicate prebranch ...midcases postbranch) form)
  (if (and (isList postbranch) (is (car postbranch) "elif"))
      (do (midcases.push postbranch)
          (= postbranch undefined)))
  ; prepare forms
  ; for ternary safety: compiled expressions could contain operators with a lower precedence than the ternary `?` or `:`
  (= nested yes)
  (macCompileGetLast predicate predicate)
  (if (?! predicate) (= predicate "false"))  ; JS requires something in that field
  ; if this isn't nested, further compiled branches should be aware of that
  (= nested nestedLocal)
  (macCompileResolve prebranch prebranch)
  (macCompileResolve postbranch postbranch)
  ; choose between binary, ternary and full form
  (if (and (isnt nestedLocal)        ; binary form not an expression!
           (<= prebranch.length 1)
           (is midcases.length 0)
           (or (is postbranch.length 0)
               (?! (car postbranch))
               (is (car postbranch) "")))
    ; binary
    (do (= res (+ "if (" (pr predicate) ")" (pr (car prebranch)) ";"))  ; print `undefined` if nothing
        (buffer.push res ""))  ; extra "" signals this is a multi-line statement
    (elif (and (is prebranch.length 1) (not (utils.kwtest (car prebranch)))
               (is midcases.length 0)
               (is postbranch.length 1) (not (utils.kwtest (car postbranch))))
      ; ternary
      (do (= res (+ (pr predicate) " ? "
                    (or (pr (car prebranch)) undefined) " : "  ; print `undefined` if nothing
                    (or (pr (car postbranch)) undefined)))     ; print `undefined` if nothing
          (if (and nestedLocal (isnt nestedLocal "parens"))
              (= res (+ "(" res ")")))
          (buffer.push res)))
      (do  ; full form
        (if nestedLocal (macDeclareService collector "_ref"))
        (= prebranch (collect prebranch collector no nestedLocal))
        (= postbranch (collect postbranch collector no nestedLocal))
        (for mid i midcases (do
          (assertExp mid (fn x (is (x.shift) "elif")) "elif")
          (= (midtest midbranch) mid)
          (macCompileResolve midtest midtest "parens")
          (if (?! midtest) (= midtest "false"))  ; JS requires something in that field
          ; temporary ban on more-than-single-expression tests in midcases
          ; todo implement later (check if can use multiple exps with commas)
          (if (> midtest.length 1) (throw (Error (+ (pr "elif") " must compile to single expression (todo fix later); got:" (pr midtest)))))
          (macCompileResolve midbranch midbranch)
          (= midcases[i] (test: midtest branch: (collect midbranch collector no nestedLocal)))))
        ; compile full form
        (= comp (+ "if (" (pr predicate) ") { " (render prebranch) " } "))
        (for mid midcases
          (+= comp (+ " else if (" (spr mid.test) ") { " (render mid.branch) " }")))
        (if (and (? postbranch)
                 (or (> postbranch.length 1)
                     (? (car postbranch))))
            (+= comp (+ " else { " (render postbranch) " }")))
        (buffer.push comp)
        (if nestedLocal
            (buffer.push collector)
            ; more than 1 element in buffer signals to caller that this is not an expression
            (buffer.push ""))))))))

(= specials.switch (macCompileSpecial (code: (do
; (switch <exp> (case <test> ... <test> <case-branch>) ... <def-branch>)
; switch <exp> (case <test> <case-branch) ... )  ;;  <def-branch> = undefined
; todo multiple tests per case
; todo if last form in function and no returns inside, end each branch with return instead of collector variable
; what arguments mean
  ; predicate ...midcases postbranch
  ; test      cases       default
  (= (predicate ...midcases postbranch) form)
  (if (and (? postbranch) (is (car postbranch) "case"))
      (do (midcases.push postbranch)
          (= postbranch undefined)))
  (if nestedLocal (macDeclareService collector "_ref"))
  ; prepare forms
  (macCompileGetLast predicate predicate "parens")
  (if (?! predicate) (= predicate "false"))  ; JS requires something in that field
  ; if this isn't nested, further compiled branches should be aware of that
  (= nested nestedLocal)
  (for mid i midcases (do
    (assertExp mid (fn x (is (x.shift) "case")) "case")
    (= (midtest midbranch) mid)
    (macCompileResolve midtest midtest)
    (if (?! midtest) (= midtest "false"))  ; JS requires something in that field
    ; temporary ban on more-than-single-expression tests in midcases
    ; todo implement later (check if can use multiple exps with commas)
    (if (> midtest.length 1) (throw (Error (+ (pr "case") " must compile to single expression (todo fix later); got: " (pr midtest)))))
    (macCompileResolve midbranch midbranch)
    (= midcases[i] (test: midtest branch: (collect midbranch collector yes nestedLocal)))))
  (macCompileResolve postbranch postbranch)
  (= postbranch (collect postbranch collector no nestedLocal))
  ; compile
  (= comp (+ "switch (" (pr predicate) ") { "))
  (for mid midcases
    (+= comp (+ " case " (spr mid.test) ": " (render mid.branch))))
  (+= comp (+ " default: " (render postbranch) " }"))
  (buffer.push comp)
  (if nestedLocal
      (buffer.push collector)
      ; more than 1 element in buffer signals to caller that this is not an expression
      (buffer.push ""))))))

; Shared collector code for all loops
(mac macCollect
  `(do
    (= rear (body.pop))
    (if (or (utils.isPrimitive       rear)
            (utils.isString          rear)
            (utils.isSpecialValue    rear)
            (utils.isSpecialValueStr rear))
        ; a literal; just push it
        (body.push (+ collector ".push(" (pr rear) ")"))
        ; identifier, can be safely repeated in code, test it with the `?` macro, and push it
        (elif (isIdentifier rear)
              (do (macCompileGetLast ``("?" rear) tested "parens")
                  (body.push (+ "if (" tested ") " collector ".push(" (pr rear) ")"))))
        ; might contain side effects, reference it, test it, and push it
        (do (macDeclareService subst "_ref")
            (body.push (+ "if (typeof (" subst " = " (pr rear) ") !== 'undefined') "
                          collector ".push(" subst ")" ))))))

; Mostly the same code for `for` and `over`
(mac macLoopDefinition (type "for") (ind `"_i")
  `(macCompileSpecial (argsMin: 2 argsMax: 4
    code: (do
      (= (value key iterable body) form)
      ,(if (is type "for")
        `(if (?! body)  ; assume <value> <iterable> <body>
          (if (?! iterable)  ; assume <integer> <body>
            (do
              (if (or (isNaN (Number value))
                      (not (> (parseInt value) 0)))
                (throw (Error (+ "expecting integer, got " (pr value)))))
              (= body     key
                 iterable ``("quote" (range 1 (parseInt value))))
              (macDeclareService key ,ind)
              (macDeclareService value "_val"))
            (do
              (= body     iterable
                 iterable key)
              (macDeclareService key ,ind)
              (macDeclareVar value)))
          (do
            (macDeclareVar key)
            (macDeclareVar value)))
      (elif (is type "over")
        `(if (?! body)  ; assume <value> <iterable> <body>
          (do
            (= body     iterable
               iterable key)
            (macDeclareService key ,ind)
            (macDeclareVar value))
          (elif (?! iterable)
            (do
              (= body     key
                 iterable value)
              (macDeclareService key ,ind)
              (macDeclareService value "_val")))
          (do
            (macDeclareVar key)
            (macDeclareVar value)))))
      (assertExp key isVarName "valid identifier")
      (assertExp value isVarName "valid identifier")
      (if nestedLocal
          (do (macDeclareService collector "_res")  ; array for iteration results
              (buffer.push (+ collector " = []"))))
      (macDeclareService ref "_ref")  ; iterable
      (macCompileGetLast iterable iterable)
      (buffer.push (+ ref " = " (pr iterable)))
      ; if this isn't nested, further compiled body should be aware of that
      (= nested nestedLocal)
      (macCompileResolve body body)
      ; only collect if the form is nested, if the last expression isn't a keyword, and it's not undefined, unless it's a literal, in which case it's allowed to be undefined
      (if (and nestedLocal (not (utils.kwtest (pr (last body)))))
        (macCollect))
      ,(if (is type "for")
        `(buffer.push (+ "for (" key " = 0; " key " < " ref ".length; ++" key ") { " value " = " ref "[" key "]; " (render body) " }"))
        (elif (is type "over")
         `(buffer.push (+ "for (" key " in " ref ") { " value " = " ref "[" key "]; " (render body) " }"))))
      (if nestedLocal
          (buffer.push collector)
          ; more than 1 element in buffer signals to caller that this is not an expression
          (buffer.push ""))))))

(= specials.for (macLoopDefinition))
; (for <value> <index> <iterable> <body>)
; (for <value> <iterable> <body>)
; (for <integer> <body>)  ;? todo change to <iterable> <body> for comprehended arrays

(= specials.over (macLoopDefinition over "_key"))
; (over <value> <key> <iterable> <body>)
; (over <value> <iterable> <body>)
; (over <iterable> <body>)

(= specials.while (macCompileSpecial (argsMin: 2 argsMax: 3
; (while <test> <body> <return_value>)  -- returns return_value
; (while <test> <body>)                 -- returns array of body values
  code: (do
    (= (test body rvalue) form)
    (if (is form.length 2)  ; no rvalue: array mode
      ; checking by form length to allow user to pass `undefined` and `null` as rvalue
      (if nestedLocal (do (macDeclareService collector "_res")
          (buffer.push (+ collector " = []"))))
        (= comp ""))  ; rvalue: no array mode
    (macCompileGetLast test test "parens")
    ; if this isn't nested, further compiled body should be aware of that
    (= nested nestedLocal)
    (macCompileResolve body body)
    (if (and nestedLocal (is form.length 2) (not (utils.kwtest (pr (last body)))))
      (macCollect))
    (buffer.push (+ "while (" (pr test) ") { " (render body) " }"))
    (if (is form.length 2)
      (if nestedLocal
          (buffer.push collector)
          ; more than 1 element in buffer signals to caller that this is not an expression
          (buffer.push ""))
      (do (macCompileResolve rvalue rvalue)
          (buffer.push (render rvalue))))))))

(= specials.try (macCompileSpecial (argsMin: 1 argsMax: 3
; (try <try> (catch err <catch>) <finally>)
; (try <try> (catch err <catch>))
; (try <try> <catch> <finally>)
; (try <try> <catch>)
; (try <try>)
  code: (do
    (= (tryForm catchForm finalForm) form)
    (macCompileResolve tryForm tryForm "parens")
    (if nestedLocal (do (macDeclareService collector "_ref")
                        (tryForm.push (+ collector " = " (pr (tryForm.pop))))))
    (if (and (isList catchForm) (is (car catchForm) "catch"))
      (do
        (assertExp catchForm {is #0.length 2 3} "valid catch form")
        (= (catchForm err catchForm) catchForm)
        (assertExp err isVarName "valid identifier"))
      (macDeclareService err "_err"))  ; shouldn't be declared, it's like an argument, todo fix
    (if (?! catchForm) (= catchForm undefined))
    ; if this isn't nested, further compiled parts should be aware of that
    (= nested nestedLocal)
    (macCompileResolve catchForm catchForm)
    (if (and nestedLocal (not (utils.kwtest (pr (last catchForm)))))
        (catchForm.push (+ collector " = " (pr (catchForm.pop)))))
    (if (? finalForm)
      (do
        (if (and (isList finalForm) (is (car finalForm) "finally"))
          (do (assertExp finalForm {is #0.length 2})
              (= finalForm (last finalForm))))
        (macCompileResolve finalForm finalForm)
        (if (and nestedLocal (not (utils.kwtest (pr (last finalForm)))))
            (finalForm.push (+ collector " = " (pr (finalForm.pop)))))))
    (= res (+ "try { " (render tryForm) " } catch (" (pr err) ") { " (render catchForm) " }"))
    (if (? finalForm) (+= res (+ " finally { " (render finalForm) " }")))
    (buffer.push res)
    (if nestedLocal
        (buffer.push collector)
        ; more than 1 element in buffer signals to caller that this is not an expression
        (buffer.push ""))))))

(= specials.get (macCompileSpecial (argsMin: 1 argsMax: 2
; (get <object> <property>)
; (get <property>)
  code: (do
    (= (object property) form)
    (if (?! property)
      (= property object
         object   ""))
    (macCompileGetLast object object)
    (macCompileGetLast property property)
    (assertExp object {? #0} "valid object")
    (if (utils.isDotName property)
      (buffer.push (+ (pr object) property))
      (buffer.push (+ (pr object) "[" (pr property) "]")))))))

(= specials.spread (macCompileSpecial (argsMin: 1 argsMax: 1
  code: (do
    (= form (car form))
    (if (isList form)
      (macCompileAdd form)
      (elif (isAtom form)
        (buffer.push form))
      (throw (Error (+ "spread requires atom, got: " (pr form)))))))))

(= specials.return (macCompileSpecial (argsMin: 0 argsMax: 1
  code: (do
    (if (isnt form.length 0)
      (do
        (macCompileGetLast (car form) form yes)
        (if (not (utils.kwtest form))
            (= form (+ "return " (pr form))))
        (buffer.push form)))))))


; Macro store
(= macros (:))

; Imports macros from given stores, overriding defaults
; Each store must be a hash table where keys are macro names and values are macro functions
(= exports.importMacros (def importMacros ...stores
  (do (for store stores
        (over val key store
              (= macros[key] val)))
      macros)))

; Import and merge macros
(importMacros (require "./macros"))

; Parses form for macro definitions and makes macros, removing definitions from source
(def parseMacros form
     (do (if (utils.isHash form)
             (over val key form
                   (= form[key] (parseMacros val)))
             (elif (utils.isList form)
                   ; standard definition: (mac x) -> ()
                   (if (is (car form) "mac")
                       (= form (makeMacro (cdr form)))
                       ; self-expanding definition: ((mac x)) -> (x)
                       (elif (and (>= form.length 1)
                                  (utils.isList (car form))
                                  (is (car (car form)) "mac"))
                             (= (car form) (makeMacro (cdr (car form)) yes)))
                       ; other cases; check recursively
                       (for val i form
                            (= form[i] (parseMacros val))))))
         form))

(def makeMacro form selfExpand (do
     (= (name ...body) form)
     (if (?! name) (throw (Error "a macro requires a name")))
     (if (?! body) (throw (Error "a macro requires a body")))
     (= body `("do" ("fn" ,...body)))
     (= (compiled scope) (compileForm body (hoist:`() service:`() replace:(:)) (macro: yes isTopLevel: yes)))
     (= rendered         (render compiled))
     (= macros[name]     (clarEval rendered))
     (if selfExpand name `())))

; Parses form for known macros to expand, replacing macro calls with macro results
; Doesn't reparse after expansion
(def expandMacros form (do
  (if (utils.isHash form) (do
    (over val key form
      (= form[key] (expandMacros val))))
    (elif (utils.isList form)
      (if (is (car form) "mac")
        (= form (parseMacros form))
        (elif (in (car form) (Object.keys macros)) (do
          (= args (cdr form))
          ; (= args (concat ...(for element (cdr form)
          ;   (if (and (isList element) (is (car element) "spread"))
          ;       (if (isnt element.length 2)
          ;           (throw Error (+ "expecting valid spread form, got:" (pr element)))
          ;           element[1])
          ;       `(element)))))
          (= form (macros[(car form)] ...args))
          (if (is (typeof form) "undefined") (= form `()))))  ; no render
        (for val i form
          (= form[i] (expandMacros val))))))
  form))

; Recursively travels code and expands all macros, resolving uniq name conflicts
(def macroexpand form (uniq (new Uniq undefined)) (do
  (if (isAtom form)
    (if (isService form) (do
      (= form (uniq.checkAndReplace form))))
    (elif (isList form)
      (if (is (car form) "mac")
        ; recursively define
        (= form (macroexpand (parseMacros form) uniq))
        ; recursively expand
        (elif (in (car form) (Object.keys macros))
          (= form (macroexpand (expandMacros form) (new Uniq uniq))))
        ; parse remaining non-macro list
        (for elem i form
          (= form[i] (macroexpand elem uniq)))))
    (elif (isHash form)
      (over val key form
        (= form[key] (macroexpand val uniq))))
    (throw Error (+ "unexpected form: " (pr form))))
  form))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; Functions Import ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Functions store
(= functions (:))

(= exports.importFunctions (def importFunctions ...stores
  (do (for store stores
        (over val key store
          (if (isa val "function")
            (if (and (? val.name) (isnt val.name ""))
              (= functions[val.name] val)
              (= functions[key] val)))))
      functions)))

; Import and merge functions
(importFunctions (require "./functions"))


; Export utilities
(= exports.utils utils)

(= exports.fileExtensions `(".clar")
   exports.register       (fn (require "./register"))
   exports.tokenise       (fn src (tokenise src))
   exports.lex            (fn src (lex (tokenise src)))
   exports.parse          (fn src (parse (lex (tokenise src))))
   exports.macroexpand    (fn src (macroexpand (parse (lex (tokenise src))))))

(= exports.macros macros)        ; expose macros object for override by user
(= exports.functions functions)  ; expose functions object for override by user

(= exports.compile (def compile src opts (do
   (= defaults (wrap:       yes
                topScope:   yes   ; for built-in-func overrides
                isTopLevel: yes   ; for functions wrapping `do`
                pretty:     yes)  ; enables beautifier
      opts     (utils.merge defaults opts))
   (= parsed (parse (lex (tokenise src))))
   (parsed.unshift "do")  ; always put code into an implicit `do`
   (if opts.wrap
       (= parsed `(("get" ("fn" parsed) "'call'") "this")))
   (if (not opts.repl)
       (= functionsRedeclare `()
          functionsRedefine  `()))  ; reset functions override stores when compiling each new file
   (= (compiled scope) (compileForm (macroexpand (parseMacros parsed)) (hoist:`() service:`() replace:(:)) opts))
   (if (and opts.pretty (? beautify))
       (beautify (render compiled) (indent_size: 2))
       (render compiled)))))

(= exports.eval (def clarEval src
  (if (and (? vm) (? vm.runInThisContext))
    (vm.runInThisContext src)
    (eval src))))


(= exports.compileFile (def compileFile filename (do
   (= raw      (fs.readFileSync filename "utf8")
      stripped (if (is (raw.charCodeAt 0) 0xFEFF)
                   (raw.substring 1)
                   raw))
   (try (exports.compile stripped) (catch err (throw err))))))

(= exports.run (def run code (options (:)) (do
   (= mainModule         require.main
      mainModule.filename
      (= process.argv[1] (if options.filename
                             (fs.realpathSync options.filename)
                             ".")))
   ; Clear module cache
   (if mainModule.moduleCache (= mainModule.moduleCache (:)))
   ; Assign paths for node_modules loading
   (= dir (if options.filename
              (path.dirname (fs.realpathSync options.filename))
              (fs.realpathSync ".")))
   (= mainModule.paths ((require "module")._nodeModulePaths dir))
   (if (or (not (utils.isclar mainModule.filename)) require.extensions)
       (= code (exports.compile code)))
   (mainModule._compile code mainModule.filename))))
