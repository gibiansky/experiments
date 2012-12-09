move $0, 0
move $1, 1
move $2, 2
move $3, 3
move $4, 4
move $5, 5
move $6, 6
move $7, 7
move $8, 8
move $9, 9

move $saved-0, 0
move $saved-1, 1

led $0, $saved-1
led $1, $saved-0
led $2, $saved-1
led $3, $saved-0
led $4, $saved-1

number $0, $9
number $1, $8
number $2, $7
number $3, $6

LoopStart:

switch $saved-2, $5
switch $saved-3, $6
led $5, $saved-2
led $6, $saved-2
led $7, $saved-2
led $8, $saved-3
led $9, $saved-3

jump LoopStart
