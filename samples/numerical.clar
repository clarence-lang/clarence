(def numerify x
  (if (isNaN (Number x))
      (do (prn 'not a number:' x)
          NaN)
      (Number x)))
