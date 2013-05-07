
# The compiler used and the command line arguments to it
COMPILER	= gcc
ARGS		= -Wall -I Include/ -g 
EXECUTABLE	= vyion
CMDLINK		= ${COMPILER} -lm -o ${EXECUTABLE} ${ARGS}		# Link the .o files into an executable
CMD		= ${COMPILER} -c ${ARGS}				# Don't link, just compile to .o

ALLFILES 	= Arithmetic.o Boolean.o CharList.o Eval.o Function.o Lexer.o List.o Number.o Object.o Parser.o ParseTree.o Scope.o ScopeStack.o StringUtil.o Symbol.o Token.o Variable.o Macro.o Error.o FlowControl.o Mem.o

# Top level rule, compile whole program
all: ${EXECUTABLE}

# Invoke the compiler with linking enabled 
${EXECUTABLE}: ${ALLFILES}
	${CMDLINK} ${ALLFILES}

# Compile all C files into object code
%.o: %.c
	${CMD} $<

# Clean out the project and delete all .o files
clean:
	rm -rf *.o ${EXECUTABLE}
