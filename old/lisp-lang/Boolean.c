#include "Vyion.h"

/* Wrappers for checking truth values */
int IsTrue(VyBoolean** b){
	if(b[0]->torf != 0){
		return 1;	
	}else{
		return 0;	
	}
}
int IsFalse(VyBoolean** b){
	if(b[0]->torf == 0){
		return 1;	
	}else{
		return 0;	
	}
}

/*                           Creation of booleans 
 * Note: since all boolean values are the same, there is no need for more
 * than two of them. Therefore, just return the global true or false value. */
VyBoolean** t = NULL;
VyBoolean** f = NULL;

VyBoolean** MakeTrueBool(){
	if(t == NULL){
		/* Create a true boolean object if one doesn't exist yet */
		t = CreateBoolObj();
		t[0]->torf = 1;
	}
	return t;
}
VyBoolean** MakeFalseBool(){
	if(f == NULL){
		/* Create a false boolean object if one doesn't exist yet */
		f = CreateBoolObj();
		f[0]->torf = 0;
	}
	return f;
}

/* Functions for logic operations and, or, xor, and not (non-short-circuiting) */
VyBoolean** BoolAnd(VyBoolean** one, VyBoolean** two){
	if(IsTrue(one) && IsTrue(two)){
		return t;	
	}
	
	return f;
}
VyBoolean** BoolOr(VyBoolean** one, VyBoolean** two){
	if(IsTrue(one) || IsTrue(two)){
		return t;	
	}

	return f;
}
VyBoolean** BoolXor(VyBoolean** one, VyBoolean** two){
	if((IsTrue(one) && IsFalse(two)) || (IsFalse(one) && IsFalse(two))){
		return t;	
	}

	return f;
}
VyBoolean** BoolNot(VyBoolean** b){
	if(IsTrue(b)){
		return f;	
	}else{
		return t;	
	}
}

/* Functions for comparing numbers */
VyBoolean** LessThan(VyNumber** one, VyNumber** two){
	/* If they are of the same type, then compare */
	if(one[0]->type == INT && two[0]->type == INT){
		if(GetInt(one) < GetInt(two)){
			return t;	
		} else{
			return f;	
		}
	}
	if(one[0]->type == REAL && two[0]->type == REAL){
		if(GetDouble(one) < GetDouble(two)){
			return t;	
		} else{
			return f;	
		}
	}

	/* If the types are different, make sure that one is an int */
	if(one[0]->type == REAL){
		return LessThan(two, one);	
	}

	/* Guaranteed that type one is int and type two is double */
	else{
		if((double)(GetInt(one)) < GetDouble(two)){
			return t;	
		}else{
			return f;	
		}
	}
}
VyBoolean** GreaterThan(VyNumber** one, VyNumber** two){
	/* If they are of the same type, then compare */
	if(one[0]->type == INT && two[0]->type == INT){
		if(GetInt(one) > GetInt(two)){
			return t;	
		} else{
			return f;	
		}
	}
	if(one[0]->type == REAL && two[0]->type == REAL){
		if(GetDouble(one) > GetDouble(two)){
			return t;	
		} else{
			return f;	
		}
	}

	/* If the types are different, make sure that one is an int */
	if(one[0]->type == REAL){
		return GreaterThan(two, one);	
	}

	/* Guaranteed that type one is int and type two is double */
	else{
		if((double)(GetInt(one)) > GetDouble(two)){
			return t;	
		}else{
			return f;	
		}
	}
}

VyBoolean** LessThanOrEqual(VyNumber** one, VyNumber** two){
	if(IsTrue(LessThan(one, two)) || IsTrue(Equal(one, two))){
		return t;	
	}

	return f;
}
VyBoolean** GreaterThanOrEqual(VyNumber** one, VyNumber** two){
	if(IsTrue(GreaterThan(one, two)) || IsTrue(Equal(one, two))){
		return t;	
	}

	return f;
}

VyBoolean** Equal(VyNumber** one, VyNumber** two){
	/* Because all numbers are in simplest terms, numbers with different types are not equal */
	if(one[0]->type != two[0]->type){
		return f;	
	}

	/* Now check each type */
	if(one[0]->type == INT){
		if(GetInt(one) == GetInt(two)){
			return t;	
		}
	}
	if(one[0]->type == REAL){
		if(GetDouble(one) == GetDouble(two)){
			return t;	
		}
	}
	if(one[0]->type == COMPLEX){
		/* Check that both the imaginary and real parts are equal */
		return BoolAnd(Equal(GetReal(one), GetReal(two)), Equal(GetImaginary(one), GetImaginary(two)));
	}
	else {
		return f;	
	}
}
VyBoolean** NotEqual(VyNumber** one, VyNumber** two){
	return BoolNot(Equal(one, two));	
}

/* Print a boolean value as either true! or false!, which are the names of the variables that represent the booleans */
void PrintBoolean(VyBoolean** b){
	if(IsTrue(b)){
		printf("true!");	
	}else{
		printf("false!");	
	}
}
