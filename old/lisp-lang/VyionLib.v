|{ Set up macros that create macros and functions without using mambda and lambda }|
(set macro
    (mambda (name arguments &(body)) 
        [set $name (mambda $arguments $@body)]))

(macro function (name arguments &(body)) 
        [set $name (lambda $arguments $@body)])

|{ Define additional list functions which aren't built-in }|
(function concat (l1 l2) [$@l1 $@l2])
(function list (&(body)) body)
(function append (list &(body)) [$@list $@body])
(function front (list &(body)) [$@body $@list])

|{ Define a temporary infix system, which, although simple, can still be useful }|
(macro infix (expr) [$(nth expr 1) $(nth expr 0) $(nth expr 2)])

|{ Increment and decrement macros }|
(macro inc(n) [set $n {$n + 1}])
(macro dec(n) [set $n {$n - 1}])

|{ Implement the looping macros while and for }|
(macro while(condition &(body))
	(set symb (unique))
	[tagbody ($symb (if $condition ($@body (go $symb))))])

(macro for-each(var-name lst &(body))
	(set i (unique))
	(set eval-list (unique))
	(set size (unique))

	[
	(set $eval-list $lst)
	(set $size (len $eval-list))
	(set $i 0)
	(while {$i < $size}
		(set $var-name (nth $eval-list $i))
		$@body
		(inc $i)
	)
	]
)


|{ Define the short circuiting boolean operators }|
(macro or(first second)
	[if $first 
		#then 'true!
		#else $second])

(macro and(first second)
	[if (not $first)
		#then 'false!
		#else $second])

|{ Macro-run allows code to be run as a macro but not to return a value (macro-run return values should NEVER be used for anything) }|
(macro macro-run (name args &(body))
	[macro $name $args $@body '[]])
