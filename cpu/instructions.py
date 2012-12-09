#!/usr/bin/python -i

def bitval(value, length):
    binstr = bin(value)[2:]
    binstrlen = len(binstr)
    return '0' * (length - binstrlen) + binstr

def num2bin(value):
    return bitval(value, 32)

def num2inst(value):
    binstr = num2bin(value)
    opcode = int(binstr[0:3], 2)
    specifier = int(binstr[3:6], 2)
    reg1 = int(binstr[6:11], 2)
    reg2 = int(binstr[11:16], 2)
    immediate = int(binstr[16:], 2)
    print "op(%d) spec(%d) reg(%d <- %d) immediate(%d)" % (opcode, specifier, reg1, reg2, immediate)

def inst2hex(op, spec, r1, r2, im):
    opcode = bitval(op, 3)
    specifier = bitval(spec, 3)
    reg1 = bitval(r1, 5)
    reg2 = bitval(r2, 5)
    immediate = bitval(im, 16)

    combined = "%s%s%s%s%s" % (opcode, specifier, reg1, reg2, immediate)
    return hex(int(combined, 2))

# Instruction types

def moveconst(reg, const):
    return inst2hex(0, 3, reg, 0, const);

def moveregreg(dest, src):
    return inst2hex(0, 0, dest, src, 0);

def movefrommem(destreg, srcreg, offset):
    return inst2hex(0, 2, destreg, srcreg, offset);

def movetomem(destreg, srcreg, offset):
    return inst2hex(0, 1, destreg, srcreg, offset);

def program_ints_to_verilog(program):
    print "\n".join(["storage[%d] <= %s32'd%d;" % (num, "-" if int(instr) < 0 else "", abs(int(instr))) for (instr, num) in zip(program.strip().split("\n"), range(0, 1000))])
