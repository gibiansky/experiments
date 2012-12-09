This is a simple multi-cycle processor written in Verilog for a small MIPS-like instruction set.

Summary
=======
* 32-bit machine, with 32-bit-long instructions
* 32 registers
* Opetaions on 32-bit words, with support for reading and writing 8-bit bytes to/from memory
* No floating point support; 32-bit signed integers only.
* Little-endian

Registers
=========
* 0-9: ($0 through $9) - Available for any use.
* 10: ($instruction) - Instruction pointer. 
* 11: ($stack) - Pointer to the top of the stack.
* 12: ($out) - Register in which ALU stores result for some operations (most which involve constants).
* 13: ($ret) - Return address.
* 14: ($frame) - Frame pointer.
* 15: ($static) - Pointer to the static data region.
* 16-31: Currently unused. While you can use these and the processor won't break, there is no way to use them from assembly since they have no given names.

Instructions
============

All instructions consist of (in order) a 3-bit opcode (defining the instruction type), a 3-bit specifier (defining the instruction action), and 26-bits of data specific to the opcode / specifier pair. Most instructions will use these 26 bits to store two 5-bit registers and a 16-bit constant. In some instructions, the 16-bit constant is actually used as a 5-bit register, with the left-most bits being ignored. The exceptions to these rules include the jump instructions, which have a 5-bit register area (currently unused) and a 21-bit signed constant offset (they will jump to the instruction pointer plus the offset). Any opcode / specifier pairs which are unlisted have not been implemented and may break the machine.

Instructions Specifications:
----------------------------

### move and move-byte (opcode 0):
__Note:__ The first register will always relate to the destination of the move, while the second will (if applicable) relate to the source of the move.

* specifier 0: moves a word from a register to a register (ex: move $instruction, $ret)
* specifier 1: moves a word from a register to memory (ex: move $frame[0x10], $1)
* specifier 2: moves a word from memory to a register (ex: move $1, $static[0x4])
* specifier 3: moves a word from a constant to a register (ex: move $2, 25)
* specifier 4: moves a byte (least significant) from memory to a register (ex: move-byte $3, $static[0x9])
* specifier 5: moves a byte (least significant) from a register to memory (ex: move-byte $4, $frame[0x3])

### arithmetic operations (opcode 1)
__Note:__ The first register is denoted as reg1, and the second as reg2. The 16-bit constant is the immediate. In instructions where the immediate is unused, the last 5 bits of the immediate are used to determine where to store the results of the operation. In the assembly code, an instruction that operates on two registers may opt to take a third register as the destination; without that, it defaults to $out.

* specifier 0: add (reg1 + reg2) (ex: add $1, $2 or add $1, $2, $1)
* specifier 1: add (reg1 + immediate) (ex: add $2, 5)
* specifier 2: subtract (reg1 - reg2) (ex: sub $4, $5, $6)
* specifier 3: subtract (immediate - reg1) (ex: sub $5, 15)
* specifier 4: multiply (reg1 * reg2) (ex: mul $out, $ret)
* specifier 5: multiply (reg1 * immediate) (ex: mul $0, 0x10)
* specifier 6: divide (reg1 / reg2) (ex: div $5, $0)
* specifier 7: divide (reg1 / immediate) (ex: div $0, 2)

### logical operations (opcode 2)
__Note:__ These instructions are on two registers unless specified, with immediate's last 5-bits being the desination, as for the arithmetic instructions. The 'not' instruction takes the logical opposite of a single register, while the 'negate' instruction negates the bits in a register.

* specifier 0: and (ex: and ...)
* specifier 1: or (ex: or ...)
* specifier 2: !=  (ex: neq ...)
* specifier 3: != (using immediate) (ex: neq $5, 10)
* specifier 4: ==  (ex: eq ...)
* specifier 5: ==  (using immediate) (ex: eq $6, 14)
* specifier 6: not (ex: not $out)
* specifier 7: negate (ex: negate $9)

### comparison operations (opcode 3)
__Note:__ These instructions are structurally identical to the arithmetic instructions. See above.

* specifier 0: < (ex: lt ...)
* specifier 1: < (using immediate) (ex: lt ...)
* specifier 2: <= (ex: lte ...)
* specifier 3: <= (using immediate) (ex: lte ...)
* specifier 4: > (ex: gt ...)
* specifier 5: > (using immediate) (ex: gt ...)
* specifier 6: >= (ex: gte ...)
* specifier 7: >= (using immediate) (ex: gte ...)

### jumps (opcode 4)
__Note:__ These instructions take a single 5-bit register (currently unused) and a 21-bit offset. The 21-bit offset is added to the instruction pointer if the jump is performed. When used in the assembler, the 21-bit offset is computed automatically via labels. Note that jump-if and jump-unless check whether $out is non-zero or zero respectively, and then either perform or ignore the jump as appropriate.

* specifier 0: unconditional jump (ex: jump Hello)
* specifier 1: jump if true (ex: jump-if LabelName)
* specifier 2: jump if false (ex: jump-unless IfAluOutIsZero)

Not Yet Done, But Planned
=========================
* System calls
* Interrupts
* Interrupt handlers