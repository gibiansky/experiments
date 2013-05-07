#include "Vyion.h"

/* Return the last caused parsing error */
char* parsingError = NULL;
char* GetLastNumberParsingError(){
	return parsingError;	
}

/* Find the amount of memory this number uses */
int NumberSize(int type){
	switch(type){
		case REAL:
			return sizeof(RealNum);
		case COMPLEX:
			return sizeof(ComplexNum);
		case INT:
			return sizeof(IntNum);
		case RATIO:
			return sizeof(RatioNum);
		default:
			return 0;
	}
}

/* Create a general number with no init value */
VyNumber** CreateNumber(int type){
	/* Create a number object */
	VyNumber** num = CreateNumObj();
	num[0]->type = type;

	/* Now allocate space for the actual contents of this number */
	num[0]->data = malloc(NumberSize(type));

	return num;
}

/* Convert a VyNumber** to one of the number subtypes (actually, to a void pointer) */
void* NumberToSubtype(VyNumber** num){
	return num[0]->data;
}

/* Create an integer */
VyNumber** CreateInt(int i){
	/* Create a number */
	VyNumber** num = CreateNumber(INT);

	/* Set the value */
	IntNum* iNum = NumberToSubtype(num);
	iNum->i = i;

	return num;
}

/* Create a double value number */
VyNumber** CreateReal(double d){
	VyNumber** num = CreateNumber(REAL);

	RealNum* rNum = NumberToSubtype(num);
	rNum->d = d;

	return num;
}

/* Create a complex number with a real coefficient of 0 (i.e. only the imaginary part)  */
VyNumber** CreateImaginary(VyNumber** n){
	VyNumber** num = CreateNumber(COMPLEX);

	ComplexNum* cNum = NumberToSubtype(num);
	cNum->real = CreateInt(0);
	cNum->imaginary = n;

	return num;
}

/* Create a complex number */
VyNumber** CreateComplex(VyNumber** real, VyNumber** imaginary){
	VyNumber** cmplex = CreateNumber(COMPLEX);

	ComplexNum* cNum = NumberToSubtype(cmplex);

	cNum->real = real;
	cNum->imaginary = imaginary;

	return cmplex;
}

/* Create a ratio from two ints */
VyNumber** CreateRatio(int numerator, int denominator){
	VyNumber** ratio = CreateNumber(RATIO);

	RatioNum* rNum = NumberToSubtype(ratio);

	rNum->numerator = numerator;
	rNum->denominator = denominator;

	return ratio;
}

/* Convert a ratio to a double number */
VyNumber** RatioToReal(VyNumber** ratio){
	RatioNum* rNum = NumberToSubtype(ratio);
	double real = ((double)(rNum->numerator))/rNum->denominator;
	return CreateReal(real);
}

/* Print a number */
void PrintNumber(VyNumber** num){
	/* Print the number differently depending on the type */
	if(num[0]->type == INT){
		IntNum* iNum = NumberToSubtype(num);
		printf("%d",iNum->i);  
	}else if(num[0]->type == REAL){
		RealNum* rNum = NumberToSubtype(num);
		printf("%f", rNum->d);	
	}else if(num[0]->type == COMPLEX){
		ComplexNum* cNum = NumberToSubtype(num);
		PrintNumber(cNum->real);
		printf("+");
		PrintNumber(cNum->imaginary);
		printf("i");
	}
}

/* Convert a string to a double */
double StringToDouble(char* str){
	double result = 0;

	int index = 0;
	char next = str[index];

	/* Find the integer part */
	while(next != '.' && next != '\0'){
		/* Find the int value of the digit */
		int digit = next - '0';

		/* Update result */
		result = result*10 + digit;

		/* Next character */
		index++;
		next = str[index];
	}

	/* Find the decimal part if it exists */
	if(next == '.'){
		/* Skip the decimal point */
		index++;
		next = str[index];

		double scale = 0.1;
		while(next != '\0'){
			/* Add the value to the result */
			int digit = next - '0';
			result = result + digit * scale;
			scale *= 0.1;

			/* Next character */
			index++;
			next = str[index];
		}
	}

	return result;
}

/* Given all the data about a number that is contained in the string, create a number from it */
VyNumber** ParseNumberFromData(CharList* beforeRadix, CharList* afterRadix, CharList* exponential, int isNegated, int isImaginary){

	/* Determine the type based on the arguments and parse the number appropriately */
	VyNumber** num = NULL;

	/* Convert the CharList*s to strings so that we can deal with them */
	char* exponentialStr = ToStr(exponential);
	char* beforeRadixStr = ToStr(beforeRadix);
	char* afterRadixStr = ToStr(afterRadix);

	/* Concatenate the strings to form a double */
	char* dotted = ConcatStrings(beforeRadixStr, ".");
	char* doubleStr = ConcatStrings(dotted,afterRadixStr);
	free(dotted);

	/* Imaginary? */
	if(isImaginary){
		/* Create a complex number with default real value of 0 */
		num = CreateNumber(COMPLEX);
		ComplexNum* cNum = NumberToSubtype(num);
		cNum->real = CreateInt(0);
		cNum->imaginary = ParseNumberFromData(beforeRadix, afterRadix, exponential, 0, 0);
	}

	/* Integer? */
	else if(Size(afterRadix) <= atoi(exponentialStr)){
		/* Integer IF there is no decimal part OR the 10 exponent turns the decimal into an integer */
		double d = StringToDouble(doubleStr);
		int i = (int)(d*pow(10, atoi(exponentialStr)));

		/* Make negative if needed */
		if(isNegated){
			i = -i; 
		}

		num = CreateNumber(INT);
		IntNum* iNum = NumberToSubtype(num);
		iNum->i = i;
	}

	/* Else, double */
	else {
		double d =  StringToDouble(doubleStr);
		d = d*pow(10,atoi(exponentialStr));

		/* Make negative if needed */
		if(isNegated){
			d = -d; 
		}

		num = CreateNumber(REAL);
		RealNum* rNum = NumberToSubtype(num);
		rNum->d = d;
	}

	/* Free the used strings */
	free(exponentialStr);
	free(beforeRadixStr);
	free(afterRadixStr);
	free(doubleStr);

	return num;
}

/* Given a string, find all the data needed to create a number from it an create a number */
VyNumber** ParseNumber(char* numStr){
	/* Set the parsing error to NULL to reset it */
	parsingError = NULL;

	/* Declare variables to store data about the number */
	int hasRadix = 0;

	/* The radix denotes where the integer part ends */
	CharList* beforeRadix = MakeCharList();
	CharList* afterRadix = MakeCharList();

	/* For exponential form */
	int isExponentialForm = 0;
	CharList* exponent = MakeCharList();

	/* Imaginary? */
	int imaginary = 0;

	/* Negated? */
	int isNegated = 0;

	/* Declare variables needed for iteration over the characters */
	int index = 0;
	char next = numStr[index];

	/* If it is negated, parse the rest and negate */
	if(numStr[0] == '-'){
		isNegated = 1;
		index++;
		next = numStr[index];
	}

	/* Also allow a + instead of a -, although it does nothing */
	else if(numStr[0] == '+'){
		index++;
		next = numStr[index];
	}


	/* For each character in the string */
	while(next != '\0'){
		/* If it finds a radix */
		if(next == '.'){
			hasRadix = 1;

			/* If it is already in exponential form, a radix is an error, because exponential 
			 * form only takes ints for the exponent, so there cannot be a radix */
			if(isExponentialForm){
				parsingError = "Badly formatted number: scientific notation exponent must be integer.";
				return NULL;
			}
		}

		/* Scientific notation */
		else if(next == 'e'){
			isExponentialForm = 1;

			/* If the next is + or -, allow them */
			if(numStr[index + 1] == '+' || numStr[index + 1] == '-'){
				Add(exponent, numStr[index + 1]);

				/* Continue on to the next character */
				index++;
				next = numStr[index];
			}

			/* 'e' cannot be the last character */
			else if(numStr[index + 1] == '\0'){
				parsingError = "Badly formatted number: Expecting exponent after 'e' (scientific notation)";
				return NULL;
			}
		}

		/* If it is an imaginary number */
		else if(next == 'i'){
			imaginary = 1;

			/* If the 'i' isn't last, error */
			if(numStr[index + 1] != '\0'){
				parsingError = "Badly formatted number: 'i', indicating imaginary numbers, must come last in a number.";
				return NULL;
			}
		}

		/* No other non-numeric characters are allowed */
		else if(!isNumeric(next)){
			parsingError = "Badly formatted number: non-numeric characters in number.";
			return NULL;
		}

		/* If it is just a number, add it to the correct char list */
		else{
			if(!isExponentialForm){
				if(!hasRadix){
					Add(beforeRadix, next);
				}
				else{
					Add(afterRadix, next);
				}
			}
			else{
				Add(exponent, next);
			}
		}

		/* Next character */
		index++;
		next = numStr[index];
	}

	/* Call a function to use the data gained to create a number */
	VyNumber** number = ParseNumberFromData(beforeRadix, afterRadix, exponent, isNegated, imaginary);

	/* Free the character lists */
	Delete(beforeRadix);
	Delete(afterRadix);
	Delete(exponent);

	/* Return the result */
	return number;


}

