(= child_process (require "child_process")
   path          (require "path")
   utils         (require "./utils")
   clar          (require "./clar"))

; Load and run a clar file for Node, stripping `BOM`s
(def loadFile module filename
     (module._compile (clar.compileFile filename) filename))

; If the installed version of Node supports `require.extensions`, register as an extension
(if require.extensions
    (for ext clar.fileExtensions
         (= require.extensions[ext] loadFile)))
