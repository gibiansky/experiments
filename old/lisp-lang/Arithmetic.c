#include "Vyion.h"

/* Retrieving values from number structs */
inline int GetInt(VyNumber** num){
	return ((IntNum*) NumberToSubtype(num))->i;	
}
inline double GetDouble(VyNumber** num){
	return ((RealNum*) NumberToSubtype(num))->d;	
}
inline VyNumber** GetImaginary(VyNumber** num){
	return ((ComplexNum*) NumberToSubtype(num))->imaginary;	
}
inline VyNumber** GetReal(VyNumber** num){
	return ((ComplexNum*) NumberToSubtype(num))->real;
}
inline int GetDenominator(VyNumber** num){
	return ((RatioNum*) NumberToSubtype(num))->denominator;	
}
inline int GetNumerator(VyNumber** num){
	return ((RatioNum*) NumberToSubtype(num))->numerator;
}

/* Clone a number */
VyNumber** CloneNumber(VyNumber** num){
	switch(num[0]->type){
		case INT:
			return CreateInt(GetInt(num));
		case REAL:
			return CreateReal(GetDouble(num));
		case COMPLEX:
			return CreateComplex(CloneNumber(GetReal(num)), CloneNumber(GetImaginary(num)));
		default:
			return NULL;
	}
}

/* Negate a number */
VyNumber** NegateNumber(VyNumber** num){
	/* Use the number type to decide what to do */
	num = CloneNumber(num);
	
	int numType = num[0]->type;

	/* Negate the number */
	if(numType == INT){
		IntNum* i = NumberToSubtype(num);
		i->i *= -1;	
	}
	if(numType == REAL){
		RealNum* rNum = NumberToSubtype(num);
		rNum->d *= -1;	
	}
	if(numType == COMPLEX){
		ComplexNum* cNum = NumberToSubtype(num);
		cNum->real = NegateNumber(GetReal(num));	
		cNum->imaginary = NegateNumber(GetImaginary(num));	
	}
	if(numType == RATIO){
		RatioNum* ratNum = NumberToSubtype(num);
		ratNum->numerator *= -1;	
	}

	return num;
}

/* Check whether the number equals 0 */
int EqualsZero(VyNumber** num){
	/* Use ANDS and ORS to check */
	if((num[0]->type == INT     && GetInt(num)       == 0)
			||(num[0]->type == REAL    && GetDouble(num)    == 0)
			||(num[0]->type == COMPLEX && EqualsZero(GetReal(num)) && EqualsZero(GetImaginary(num)))
			||(num[0]->type == RATIO   && GetNumerator(num) == 0)){ 
		return 1;	
	}
	else {
		return 0;	
	}
}

/* Reduce a number to its best type (i.e. no complex numbers with 0i, no doubles with 0's after the decimal point, etc */
void ReduceNumber(VyNumber** num){
	/* Check that, if it is a double, it isnt an int in disguise */
	if(num[0]->type == REAL){
		double d = GetDouble(num);
		/* If it is, change it to an int */
		if(d == (int)(d)){
			num[0]->type = INT;

			IntNum* iNum = NumberToSubtype(num);
			iNum->i = (int)(d);
		}
	}

	/* Check that, if it is a complex number, the imaginary part isn't 0 */
	else if(num[0]->type == COMPLEX){
		if(EqualsZero(GetImaginary(num))){
			/* Make it equal the real part */
			VyNumber** realPart = GetReal(num);
			num[0]->type = realPart[0]->type;

			switch(num[0]->type){
				case INT:
					((IntNum*)(NumberToSubtype(num)))->i = GetInt(realPart);
					break;
				case REAL:
					((RealNum*)(NumberToSubtype(num)))->d = GetDouble(realPart);
					break;
			}

			
		}
	}
}

/* A utility function for multiplying two numbers known to be complex */
VyNumber** MultiplyComplexNumbers(VyNumber** c1, VyNumber** c2){
	/* Multiplying complex numbers: 
	 *   (a + bi)(x + yi) =
	 * = ax + ayi + xbi + byi^2
	 * = ax - by + ayi + xbi
	 * = (ax - by) + (ay + xb)i
	 */

	/* Get the components */
	VyNumber** realOne = GetReal(c1);		 // a
	VyNumber** imaginaryOne = GetImaginary(c1); // b
	VyNumber** realTwo = GetReal(c2);		 // x
	VyNumber** imaginaryTwo = GetImaginary(c2); // y

	/* Multiply them to get the new components */
	VyNumber** realResult = SubtractNumbers(MultiplyNumbers(realOne, realTwo), MultiplyNumbers(imaginaryOne, imaginaryTwo)); // (ax - by)
	VyNumber** imaginaryResult = AddNumbers(MultiplyNumbers(realOne, imaginaryTwo), MultiplyNumbers(realTwo, imaginaryOne)); // (ay + xb)

	/* Return the complex number */
	VyNumber** ret = CreateComplex(realResult, imaginaryResult); // (ax - by) + (ay + xb)i
	return ret;
}

/* Get the complex conjugate of a number */
VyNumber** ComplexConjugate(VyNumber** num){
	VyNumber** conjugate = CreateComplex(GetReal(num), NegateNumber(GetImaginary(num)));	
	return conjugate;
}

/* Divide a number by a complex number */
VyNumber** DivideByComplex(VyNumber** one, VyNumber** two){
	/* We know that two (the denominator) is complex */

	/* To get rid of it, multiply by it's conjugate */
	VyNumber** conjugate = ComplexConjugate(two);
	VyNumber** denominator = MultiplyNumbers(two, conjugate);

	/* Reduce the complex number to a real one */
	ReduceNumber(denominator);


	/* Now multiply the first number by the conjugate to get the numerator */
	VyNumber** numerator = MultiplyNumbers(one, conjugate);

	/* Now divide using conventional methods */
	return DivideNumbers(numerator, denominator);
}

/* Raise a complex number to a power */
VyNumber** ComplexExponent(VyNumber** cmplex, VyNumber** exp){
	/* Not yet implemented  */		
	return NULL;
}

/* Add two numbers */
VyNumber** AddNumbers(VyNumber** one, VyNumber** two){
	/* Type conversions (in order of precedence):
	 * 	Complex + Anything = Complex, unless imaginary part = 0
	 * 	Real + Anything = Real
	 * 	Ratio + Ratio or Ratio + Int = Ratio
	 * 	Int + Anything = Anything
	 */

	int typeOne = one[0]->type;
	int typeTwo = two[0]->type;

	VyNumber** num;

	/* Use the number's types to decide what to do */
	if(typeOne == INT){
		int oneInt = GetInt(one);
		switch(typeTwo){
			case INT:	
				/* Int + Int = Int */
				num = CreateInt(oneInt + GetInt(two));
				break;
			case REAL:
				/* Int + Real = Real */
				num = CreateReal(oneInt + GetDouble(two));
				break;
			case COMPLEX:
				/* Int + Complex = Complex */
				num = CreateComplex(AddNumbers(one, GetReal(two)), GetImaginary(two));	
				break;
		}

	}
	else if(typeOne == REAL){
		double oneDouble = GetDouble(one);
		switch(typeTwo){
			case INT:	
				/* Real + Int = Real */
				num = CreateReal(oneDouble + GetInt(two));
				break;
			case REAL:
				/* Real + Real = Real */
				num = CreateReal(oneDouble + GetDouble(two));
				break;
			case COMPLEX:
				/* Real + Complex = Real */
				num = CreateComplex(AddNumbers(one, GetReal(two)), GetImaginary(two));	
				break;
		}		
	}
	else if(typeOne == COMPLEX){
		VyNumber** oneReal = GetReal(one);
		VyNumber** oneImaginary = GetImaginary(one);
		switch(typeTwo){
			/* If both are complex, add the real and imaginary parts */
			case COMPLEX:
				/* Complex + Complex = Complex */
				num = CreateComplex(AddNumbers(oneReal, GetReal(two)), AddNumbers(oneImaginary, GetImaginary(two)));	
				break;
				/* If only the first one is complex, then add the second one to the real part of the complex number */
			case INT:	
			case REAL:
				/* Complex + (Int|Real) = Complex */
				num = CreateComplex(AddNumbers(oneReal, two), oneImaginary);
				break;
		}	
	}

	return num;
}

/* Subtract two numbers */
VyNumber** SubtractNumbers(VyNumber** one, VyNumber** two){
	/* Just add the first number and the negated second number */	
	return AddNumbers(one, NegateNumber(two));
}

/* Multiply two numbers */
VyNumber** MultiplyNumbers(VyNumber** one, VyNumber** two){
	/* Type conversions (in order of precedence):
	 * 	Complex * Anything = Complex, unless imaginary part = 0
	 * 	Real * Anything = Real
	 * 	Ratio * Ratio or Ratio * Int = Ratio
	 * 	Int * Anything = Anything
	 */

	int oneType = one[0]->type;
	int twoType = two[0]->type;

	VyNumber** num;

	/* Determine what to do based on the types of the numbers */
	if(oneType == INT){
		switch(twoType){
			case INT:
				/* Int * Int = Int */
				num = CreateInt(GetInt(one) * GetInt(two));
				break;
			case REAL:
				/* Int * Real = Real */
				num = CreateReal(GetInt(one) * GetDouble(two));
				break;
			case COMPLEX:
				/* Int * Complex = Complex */
				num = CreateComplex(MultiplyNumbers(one, GetReal(two)), MultiplyNumbers(one, GetImaginary(two)));
				break;
		}
	}
	else if(oneType == REAL){
		switch(twoType){
			case INT:
				/* Real * Int = Real */
				num = CreateReal(GetDouble(one) * GetInt(two));
				break;
			case REAL:
				/* Real * Real = Real */
				num = CreateReal(GetDouble(one) * GetDouble(two));
				break;
			case COMPLEX:
				/* Real * Complex = Complex */
				num = CreateComplex(MultiplyNumbers(one, GetReal(two)), MultiplyNumbers(one, GetImaginary(two)));
				break;
		}
	}
	else if(oneType == COMPLEX){
		switch(twoType){
			case INT:
			case REAL:
				/* (Int|Real) * Complex = Complex */
				num = CreateComplex(MultiplyNumbers(GetReal(one), two), MultiplyNumbers(GetImaginary(one), two));
				break;
			case COMPLEX:
				/* Call the utility function */
				/* Complex * Complex = Complex */
				num = MultiplyComplexNumbers(one, two);
				break;
		}
	}

	/* Multiplication may induce some wrong types, so reduce the number to its best type: */
	ReduceNumber(num);

	return num;

}

/* Divide two numbers */
VyNumber** DivideNumbers(VyNumber** one, VyNumber** two){
	/* Type conversions (in order of precedence):
	 * 	Complex / Anything = Complex, unless imaginary part = 0
	 * 	Real / Anything = Real
	 * 	Ratio / Ratio or Ratio / Int = Ratio
	 * 	Int / Int = Ratio
	 * 	Int / Anything = Real
	 */
	
	int oneType = one[0]->type;
	int twoType = two[0]->type;
	
	VyNumber** num;

	/* Determine what to do based on the types of the numbers */
	if(oneType == INT){
		switch(twoType){
			case INT:
				/* Int / Int = Real */
				num = RatioToReal(CreateRatio(GetInt(one) , GetInt(two)));
				break;
			case REAL:
				/* Int / Real = Real */
				num = CreateReal(GetInt(one) / GetDouble(two));
				break;
			case COMPLEX:
				/* Int / Complex = Complex */
				num = DivideByComplex(one, two);
				break;
		}
	}
	else if(oneType == REAL){
		switch(twoType){
			case INT:
				/* Real / Int = Real */
				num = CreateReal(GetDouble(one) / GetInt(two));
				break;
			case REAL:
				/* Real / Real = Real */
				num = CreateReal(GetDouble(one) / GetDouble(two));
				break;
			case COMPLEX:
				/* Real / Complex = Complex */
				num = DivideByComplex(one, two);
				break;
		}
	}
	else if(oneType == COMPLEX){
		switch(twoType){
			case INT:
			case REAL:
				/* Complex / (Int|Real) = Complex */
				num = CreateComplex(DivideNumbers(GetReal(one), two), DivideNumbers(GetImaginary(one), two));
				break;
			case COMPLEX:
				/* Complex / Complex = Complex */
				num = DivideByComplex(one, two);
		}
	}

	/* Reduce the number to its best type */
	ReduceNumber(num);

	return num;
}

/* Take a power */
VyNumber** ExponentiateNumber(VyNumber** base, VyNumber** exponent){
	int baseType = base[0]->type;
	int expType  = exponent[0]->type;

	/* Cannot raise to complex power, so return error code -1 */
	if(expType == COMPLEX){
		return (VyNumber**)(-1);
	}

	VyNumber** num;

	if(baseType == INT){
		switch(expType){
			case INT:
				num =  CreateInt((int)(pow(GetInt(base), GetInt(exponent))));
				break;
			case REAL:
				num =  CreateReal(pow(GetInt(base), GetDouble(exponent)));
				break;
		}
	}
	else if(baseType == REAL){
		switch(expType){
			case INT:
				num =  CreateReal(pow(GetDouble(base), GetInt(exponent)));
				break;
			case REAL:
				num =  CreateReal(pow(GetDouble(base), GetDouble(exponent)));
				break;
		}
	}
	else if(baseType == COMPLEX){
			num = ComplexExponent(base, exponent);	
	}

	return num;
}
