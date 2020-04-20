(def fact x
  (if (is x 0) 1
      (* x (fact (- x 1)))))
