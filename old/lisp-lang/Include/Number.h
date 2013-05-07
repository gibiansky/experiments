#ifndef NUMBER_H
#define NUMBER_H

/* In Vyion, a number is it's own type. Unlike most other languages, there is no external difference between integers,
 * floats, complex numbers, ratios, longnums, etc. A number may be converted to a specific type if it is needed, and auxilary functions
 * may provide more info about the number, but by default numbers are automatically converted back and forth between needed types by the 
 * built-in arithmetic functions. 
 */

/* Define all the numeric types */
typedef struct {
	int i;
} IntNum;

typedef struct {
	double d;
} RealNum;

typedef struct {
	VyNumber** real;
	VyNumber** imaginary;
} ComplexNum;

typedef struct {
	int numerator;
	int denominator;
} RatioNum;


/* Numeric types: integers, floats, complex numbers, and ratios */
struct VyNumber {
	int type;
	void* data;
};

/* Parse a number from a string */
VyNumber** ParseNumber(char*);

/* Get any parsing errors; NULL if none */
char* GetLastNumberParsingError();

/* Create a number */
VyNumber** CreateNumber(int);

/* Convert a number to one of its sub-types (Only to be used internally) */
void* NumberToSubtype(VyNumber**);

/* Delete and free memory */
void DeleteNumber(VyNumber**);

/* Print the number to stdout */
void PrintNumber(VyNumber**);

/* Create specific types of number */
VyNumber** CreateInt(int);
VyNumber** CreateReal(double);
VyNumber** CreateImaginary(VyNumber**);
VyNumber** CreateComplex(VyNumber**, VyNumber**);
VyNumber** CreateRatio(int,int);

/* Retrieve data from numbers */
int GetInt(VyNumber**);
double GetDouble(VyNumber**);
int GetNumerator(VyNumber**);
int GetDenominator(VyNumber**);
VyNumber** GetReal(VyNumber**);
VyNumber** GetImaginary(VyNumber**);

/* Negate a number */
VyNumber** NegateNumber(VyNumber**);

/* Add two numbers */
VyNumber** AddNumbers(VyNumber**,VyNumber**);

/* Subtract two numbers */
VyNumber** SubtractNumbers(VyNumber**,VyNumber**);

/* Divide two numbers */
VyNumber** DivideNumbers(VyNumber**,VyNumber**);

/* Multiply two numbers */
VyNumber** MultiplyNumbers(VyNumber**,VyNumber**);

/* Exponentiate a number */
VyNumber** ExponentiateNumber(VyNumber**,VyNumber**);

/* Conversions between number types */
VyNumber** RatioToReal(VyNumber**);

#endif /* NUMBER_H */
