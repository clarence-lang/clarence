<div align="center">
    <p><a href="http://clarence-lang.github.io"><img src="https://raw.githubusercontent.com/clarence-lang/assets/master/clary.jpg" height=" 230"></img>
    <br>
    </br>
    C L A R E N C E - L A N G</p></a>
    <br>	
    <hr>
 </div>


Clarence is a dynamic, embeddable scripting-language. It's syntax are highly inspired by Clojure. However, it features aweful new modifications on it's vm. With Clarence, you're allowed to write code, that even writes code for you! The entire core (vm, parser, interpreter, bytecode) is pretty small, you could implement it in nearly a weekend! It was implemented using Clarence itselfe (self-host). 

Clarence features a fast dynamic bytecode compilation. Similar to Just in Time compilations. You can use it for scientific computations, embeds of large projects and much much more... It's vm is written in Clarence itselfes so it got self-hosted. That's quite nice, cause while compilation, you are allowed to get some parallel compilations using macros! 

> Note: This is the version 0.2.3. All lower versions will not be support. This is the current one.

Sounds great? So take a look in the <a href="https://github.com/clarence-lang/clarence/tree/master/samples">samples</a> directory or get even an Installer for Clarence!

## Install
---

Clarence is built on top of JavaScript but compiled by itselfe so you just need to install it's module from NPM. Use this shell script by pasting it in a native shell like: cmd.exe, terminal, powershell...

> Note: We've setted the --global flag so we can call the clarence REPL from nearly everywhere. 

```bash
$ npm install -g clar

Result:

+ clar@0.2.3
added 29 packages from 22 contributors in 4.227s
```

Done!  Everything is installed and you are now good to go!

---

## Getting started

You can get started by calling it's help using this command:

```javascript
$ clar --help
```

And it will appear like this:

```javascript
Usage: clar [options] path/to/script.clar -- [args]
When called without options, compiles your script and prints the output to stdout.")
List of valid options

  -c --compile       compile to JavaScript and save as .js files
  -o --output [dir]  set the output directory for compiled JavaScript
  -i --interactive   run an interactive clarence REPL (this is the default with no options and arguments)")
  -v --version       display the version number")
```

## Style
---

Sample stylish clarence apps:

```clojure
(ns web.server)

(def http (js/require "http"))

(defn handler [request]
    { :status 200
        :headers { "Content-type" "text/html" }
        :body "Hello, World!" })
        
(defn process [req res handler]
    (let [response (handler req)
          status (get response :status 200)
          headers (get response :headers {"Content-type" "text/html"})
          body (get response :body "")]

        (.writeHead res (status (to-object headers)))
        (.end res (body))))
        
(defn run [handler port]
    (.listen (.createServer http ((fn [req res] (process req res handler)))) (port))
    (println "Server listening at port " port))
    
(run handler 3000)
```

It's a simple webserver using a http module that is parsed to clarence. It will run on http://localhost:3000

---


Made by Timo Sarkar 

Licensed under MIT
---

Domo Arigato! 

... And happy coding!
