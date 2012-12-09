; This program counts on the first hex display.
move $0, 0
move $1, 1 
move $2, 0

; LED test
led $0, $1
led $0, $0

InfLoop:
number $2, $0
add $0, $1, $0
jump InfLoop
