(= vm       (require "vm")
   nodeREPL (require "repl")
   clar     (require "./clar"))

(= replDefaults (
   useGlobal: yes
   prompt:    "::> "
   eval: (fn input context filename cb
     (do ; XXX: multiline hack
         (= input (input.replace /\uFF00/g "\n")
            ; Node input arrives wrapped in ( \n), unwrap
            input (input.replace /^\(([^]*)\n\)$/g "$1"))
         (try (do (= js (clar.compile input (wrap: no repl: yes)))
                  
                  (= result (vm.runInThisContext js filename))
                  (cb null result))
              (catch err (cb err)))))))

(def enableMultiline repl
; BUG: counts parens inside strings and regexes, todo fix
; BUG: hangs on multiline with unclosed {, infinite loop somewhere
     (do (= rli          repl.rli
            inputStream  repl.inputStream
            outputStream repl.outputStream
            origPrompt   (if (? repl._prompt) repl._prompt repl.prompt)
            multiline    (enabled: no
                          prompt:  (origPrompt.replace /^[^>\s]*>?/ (fn x (x.replace /./g ".")))
                          buffer:  "")
            ; proxy line listener
            lineListener (car (rli.listeners "line")))
         (rli.removeListener "line" lineListener)
         (rli.on "line" (fn cmd
           (if multiline.enabled
               (do (+= multiline.buffer (+ cmd "\n"))
                   (= opened (if (? (= m (multiline.buffer.match /\(/g)))
                                 m.length 0)
                      closed (if (? (= m (multiline.buffer.match /\)/g)))
                                 m.length 0))
                   (if (> opened closed)
                       (do (rli.setPrompt multiline.prompt)
                           (rli.prompt true))
                       (do (= multiline.enabled no
                              multiline.buffer (multiline.buffer.replace /\n/g "\uFF00"))
                           (rli.emit "line" multiline.buffer)
                           (= multiline.buffer "")
                           (rli.setPrompt origPrompt)
                           (rli.prompt true))))
               (do (= opened (if (isa (= m (cmd.match /\(/g)) "string") m.length 0)
                      closed (if (isa (= m (cmd.match /\)/g)) "string") m.length 0))
                   (if (> opened closed)
                       (do (= multiline.enabled yes)
                           (+= multiline.buffer (+ cmd "\n"))
                           (rli.setPrompt multiline.prompt)
                           (rli.prompt true))
                       (lineListener cmd))))))))

(= exports.start (= start (fn
   (do (= repl (nodeREPL.start replDefaults))
       (repl.on "exit" (fn (repl.outputStream.write "\n")))
       (enableMultiline repl)
       repl))))
