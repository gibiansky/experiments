all: compile
	cp *.test tests/data;
	echo 0 > tests/data/verify
	echo 0 >> tests/data/verify

compile:
	iverilog *.v -o main

clean:
	rm main
	rm tests/data/*;

tests: move movebyte alu compare logical jump

move: compile
	echo "Move Test:"
	cp tests/move/* tests/data;
	./main
	echo
	
movebyte: compile
	echo "Move Byte Test:"
	cp tests/movebyte/* tests/data;
	./main
	echo

alu: compile
	echo "Arithmetic Test:"
	cp tests/alu/* tests/data;
	./main
	echo

compare: compile
	echo "Comparison Test:"
	cp tests/compare/* tests/data;
	./main
	echo

logical: compile
	echo "Logical Test:"
	cp tests/logical/* tests/data;
	./main
	echo

jump: compile
	echo "Jump Test:"
	cp tests/jump/* tests/data;
	./main
	echo



