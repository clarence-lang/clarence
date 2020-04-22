
(= clar         (require "./clar")
   clar.require require
   compile      clar.compile)


; Use standard JS `eval` to eval code
(= clar.eval (fn code (options (:)) (do
  (= options.wrap no)
  (eval (compile code options)))))

(= clar.run (fn code (options (:)) (do
  (= options.wrap no)
  (= compiled (compile code options))
  ((Function (compile code options))))))

; If we're not in a browser environment, end the script
(if (?! window) return)

; Load remote script by XHR
(= clar.load (fn url callback (options (:)) (hold no) (do
  (= options.sourceFiles `(url)
     xhr (if window.ActiveXObject
             (new window.ActiveXObject "Microsoft.XMLHTTP")
             (new window.XMLHttpRequest)))
  (xhr.open "GET" url yes)
  (if (of `overrideMimeType xhr) (xhr.overrideMimeType "text/plain"))
  (= xhr.onreadystatechange (fn (do
    (if (is xhr.readyState 4)
        (if (is xhr.status 0 200)
            (do (= param `(xhr.responseText options))
                (if (not hold) (clar.run ...param)))
            (throw (new Error (+ "Could not load " url)))))
    (if callback (callback param)))))
  (xhr.send null))))

; Compile and eval all `text/clar` script tags
; Happens on page load
(def runScripts (do
  (= scripts (window.document.getElementsByTagName "script")
     clars   `()
     index   0)
  (for s scripts
    (if (is s.type "text/clar") (clars.push s)))
  (def execute (do
    (= param clars[index])
    (if (instanceof param Array)
      (do (clar.run ...param)
          (++ index)
          (execute)))))
  (for script i clars (let script script i i (do
    (= options (:))
    (if script.src
      (clar.load script.src (fn param
        (do (= clars[i] param)
            (execute)))
        options
        true)
      (do (= options.sourceFiles `("embedded"))
          (= clars[i] `(script.innerHTML options)))))))
  (execute)))

; Listen for window load: decent browsers / IE
(if window.addEventListener
  (window.addEventListener "DOMContentLoaded" runScripts no)
  (window.attachEvent "onload" runScripts))
