
(= repeat (require "./utils").repeat)


(= exports.OptionParser (= OptionParser ((fn (do

 (def OptionParser rules banner
  (do (= this.banner banner
         this.rules  (buildRules rules))
      this))  ; necessary for prototyping to work

  (= OptionParser.prototype.parse (fn args (do
    (= options          (arguments: `())
       skippingArgument no
       originalArgs     args
       args             (normaliseArguments args))
    (for arg i args (do
      (if skippingArgument (do
        (= skippingArgument no)
        continue))
      (if (is arg "--") (do
        (= pos (originalArgs.indexOf "--")
           options.arguments (options.arguments.concat (originalArgs.slice (+ pos 1))))
        break))
      (= isOption (is (or (arg.match long_flag)
                          (arg.match short_flag))))
      (= seenNonOptionArg (> options.arguments.length 0))
      (if (not seenNonOptionArg) (do
        (= matchedRule no)
        (for rule this.rules
          (if (is arg rule.shortFlag rule.longFlag) (do
            (= value true)
            (if rule.hasArgument
              (= skippingArgument yes
                 value            args[(+ i 1)]))
            (= options[rule.name] (if rule.isList
              ((or options[rule.name] `()).concat value)
              value))
            (= matchedRule yes)
            break)))
        (if (and isOption (not matchedRule))
          (throw (new Error (+ "unrecognised option: " arg))))))
      (if (or seenNonOptionArg (not isOption))
          (options.arguments.push arg))))
    options)))

  ; Return help text for this OptionParser
  (= OptionParser.prototype.help (fn (do
    (= lines `())
    (if this.banner (lines.unshift (+ this.banner "\n")))
    (for rule this.rules (do
      (= spaces  (- 15 rule.longFlag.length)
         spaces  (if (> spaces 0) (repeat " " spaces) "")
         letPart (if rule.shortFlag (+ rule.shortFlag ", ") "    "))
      (lines.push (+ "  " letPart rule.longFlag spaces rule.description))))
    (+ "\n" (lines.join "\n") "\n"))))

  OptionParser)))))


(= long_flag  /^(--\w[\w\-]*)/
   short_flag /^(-\w)$/
   multi_flag /^-(\w{2,})/
   optional   /\[(\w+(\*?))\]/)


(def buildRules rules
    (for tuple rules
      (do (if (< tuple.length 3) (tuple.unshift null))
          (buildRule ...tuple))))

; Build rule from `-o` short flag, `--output [dir]` long flag, and option description
(def buildRule shortFlag longFlag description (options (:))
  (do (= match    (longFlag.match optional)
         longFlag (longFlag.match long_flag)[1])
      (name:        (longFlag.substr 2)
       shortFlag:   shortFlag
       longFlag:    longFlag
       description: description
       hasArgument: (is (and match match[1]))
       isList:      (is (and match match[2])))))

; Normalise arguments by expanding merged flags into multiple flags
; This allows to have `-wl` be same as `--watch --lint` (even though clar doesn't have these options...)
(def normaliseArguments args
  (do (= args   (args.slice 0)
         result `())
      (for arg args
           (if (= match (arg.match multi_flag))
               (for l (match[1].split "")
                    (result.push (+ "-" l)))
               (result.push arg)))
      result))
