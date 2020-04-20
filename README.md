<div align="center">
    <p><a href="http://clarence-lang.github.io">
    <br>
    </br>
    C L A R E N C E - L A N G</p></a>
    <br>	
    <hr>
 </div>


Clarence is a dynamic, embeddable scripting-language. It's syntax are highly inspired by Clojure. However, it features aweful new modifications on it's vm. With Clarence, you're allowed to write code, that even writes code for you! The entire core (vm, parser, interpreter, bytecode) is pretty small, you could implement it in nearly a weekend! It was implemented using Clarence itselfe (self-host). 

Clarence features a fast dynamic bytecode compilation. Similar to Just in Time compilations. You can use it for scientific computations, embeds of large projects and much much more... It's vm is written in Clarence itselfes so it got self-hosted. That's quite nice, cause while compilation, you are allowed to get some parallel compilations using macros! 

> Note: This is the version 0.2.3. All lower versions will not be support. This is the current one. See <a href="https://github.com/clarence-lang/clarence/blob/clarence-v.0.2.0/CHANGELOG">changelog</a> to see what has changed since the Last update.

Sounds great? So take a look in the <a href="https://github.com/clarence-lang/clarence/tree/clarence-v.0.2.0/samples">samples</a> directory or get even an Installer for Clarence!

## Install

Clarence is built on top of JavaScript but compiled by itselfe so you just need to install it's module from NPM. Use this shell script by pasting it in a native shell like: cmd.exe, terminal, powershell...

> Note: We've setted the --global flag so we can call the clarence REPL from nearly everywhere. 

```bash
$ npm install -g clar

Result:

+ clar@0.2.3
added 29 packages from 22 contributors in 4.227s
```

Done!  Everything is installed and you are now good to go!


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

## Executables
---

By passing different flags to <clar> you are able to call different environments. See below:
    
### The REPL:

> Named: Read Eval Print Loop. A REPL is called when no argument is passed:

```bash
$ clar

Result: 

Clarence 0.2.3-5b6b9f1 (C) Timo S.
Version 0.2.3 (2020-04-20) Clar
Type some Clarence expressions:

::>
```

You can type some code (see <a href="https://github.com/clarence-lang/clarence/tree/clarence-v.0.2.0/samples">samples</a>) in the REPL.

---

### Loading scripts

> Note: You can load external scripts that are stored in plain/clar files. eg: <file.clar>

Or you can load them directly in a native shell:

```bash
$ clar <PATH/TO/yourfile.clar>
```

eg.:

```bash
$ cat mul.clar # shows file content # needs cat installed
-----------------------------------------------------
(mac makeReduce name operator
  `(def ,name ...args
    (if (isnt args.length 0)
        (args.reduce {,operator #0 #1}))))

(makeReduce mul *)
(mul 2 2)
----------------------------------------------------
$ clar mul.clar # executes the file

Result:
Integer: 4
undefined

```

---

Made by Timo Sarkar 

Licensed under MIT
---

Domo Arigato! 

... And happy coding!
