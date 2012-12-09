; This program iterates over the numbers 0 through 18
; And turns on each relevant LED. Then, it loops back down
; and turns off each LED.
move $0, 0
move $1, 1 

; Loop over LEDs in increasing order, turn them on
LoopIncr:

led $0, $1
add $0, $1, $0

gte 2, $0
jump-if LoopIncr

move $2, 0

; Loop over LEDs in decreasing order, turn them off
LoopDecr:

sub $0, $1, $0
led $0, $2

lt 0, $0
jump-if LoopDecr

; Count number of instructions
InfLoop:
number $2, $0
add $0, $1, $0
jump InfLoop
