# WeBWorKChemistry
WeBWorK scripts for doing problems related to Chemistry (and beyond!)

This repo is a work-in-progress!  It has not yet been added to the WeBWorK repo as it needs more testing and improvements.  If you want to contribute, please submit a PR!  It's easy to do.  (Fork this repo, make some changes to your forked repo, then come back here and make a PR that points to your forked repo.)  

# InexactValue

You can create an InexactValue with a string:

`InexactValue("2.00");`

You can create one with a number and explicit number of sig figs:

`InexactValue(2, 3);  # essentially creates the value 2.00`

You can even explicitly make the value exact.  (This is useful when you want to use the methods on InexactValue.  It will also be useful later with units.)

`InexactValue(2, Infinity);`

The methods include getting the number of sig figs.  This is useful for questions asking a student how many significant figures a number might have: 

`$inexactValue->sigFigs`

Best of all, you can do math with InexactValue and the correct significant figures are calculated according to the standard rules taught in most chemistry courses.  
```
$result = InexactValue("4.00") * InexactValue("2.0");
# $result contains an InexactValue with value of 8 and 2 significant figures.  The string output will be "8.0". 
```

# InexactValueWithUnits

This is an extension of InexactValue with a modified version of the units macro.  To make an InexactValueWithUnits, you provide exactly what you would provide a normal InexactValue as an array for the first parameter, then the units for the second parameter.
```
$n1 = InexactValueWithUnits('1.609', 'km');
$d1 = InexactValueWithUnits(['1', Infinity], 'mi');
```
When you do math with these values, the units automatically combine correctly:
```
$result = $n1/$d1;
# using values above
# $result contains an InexactValueWithUnits that will output the string:  1.609 km mi^-1
```
