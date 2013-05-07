(include 'VyionLib.v)

; All currently defined infix operators (start with only numerical operators)
(macro-run init-infix ()
	(global infix-ops [= != < > <= >= ** * / + -]))

; Create a macro to add a new infix operator
(macro-run def-operator(symbol ~?(before false!))
	; If the order isn't specified, just add it last
	(if (eq before false!) (set infix-ops (append infix-ops symbol))

		; Otherwise, add it before the specified element 
		((set elem (head infix-ops))
		 ; Find which element you're adding it before
		 (set index 0)
		 (while (not (eq elem before))
		 	(inc index)
			(set elem (nth infix-ops index)))
		 ; Insert it where needed
		 (set infix-ops (insert infix-ops symbol index)))))

(macro infix (&(body))
	(for 


