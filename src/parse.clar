
(= utils (require "./utils"))


(= module.exports (def parse form
  (if (utils.isList form)
      (do (for val i form (= form[i] (parse val)))
          form)
      (elif (utils.isHash form)
            (do (over val key form (= form[key] (parse val)))
                form))
      (do (= form (utils.typify form))
          (if (/^#(\d+)/.test form)
              (form.replace /^#(\d+)/ "arguments[$1]")
              form)))))