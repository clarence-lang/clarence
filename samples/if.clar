; binary form: single statement
(if true (prn 'breaking off'))

; ternary form: single expression per branch
(if (is 'universe expanding')      ; test
    (prn 'flight normal')          ; then-branch
    (alert 'catastrophe'))         ; else-branch

; block form: more than one expression per branch
(if hunting
    (do (= beast (randomBeast))
        (shoot beast))             ; then-branch
    (cook 'meat'))                 ; else-branch
