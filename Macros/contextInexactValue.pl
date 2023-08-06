## @file contextInexactValueFILETHIS

loadMacros("MathObjects.pl");
loadMacros('PGauxiliaryFunctions.pl'); # needed for Round function

sub _contextInexactValue_init {InexactValue::Init()}

package InexactValue;

sub Init {
	my $context = $main::context{InexactValue} = Parser::Context->getCopy("Numeric");
	$context->{name} = "InexactValue";

	#
	#  Remove all the stuff we don't need
	#
	$context->variables->clear;
	$context->constants->clear;
	$context->parens->clear;
	$context->operators->clear;
	$context->functions->clear;
	$context->strings->clear;

	$context->strings->add(infinity => {infinite => 1});
	$context->strings->add(inf => {infinite => 1});
	#
	#  Don't reduce constant values (so 10^2 won't be replaced by 100)
	#
	$context->flags->set(reduceConstants => 0);
	#
	#  Flags controlling input and output
	#
	$context->flags->set(
		creditSigFigs => 0.5,   # credit for getting correct # of sig figs
		creditValue => 0.5,     # credit for getting correct value
		failOnValueWrong => 1,  # ignore sig figs (and any further credit) 
														# if value is wrong
	);
	

	#
	#  Hook into the Value package lookup mechanism
	#
	$context->{value}{InexactValue} = 'InexactValue::InexactValue';
	$context->{value}{"Value()"} = 'InexactValue::InexactValue';

	#$context = $main::context{"InexactValue"} = Parser::Context->getCopy("InexactValue");
	
	#
	#  Create the constructor function
	#
	main::PG_restricted_eval('sub InexactValue {Value->Package("InexactValue")->new(@_)}');

}

# The rules for significant figures here are those used in chemistry 
# intro and basic-level courses.  

package InexactValue::InexactValue;
#** @class InexactValue::InexactValue
# @brief Here's where I describe the internals...
#*

our @ISA = qw(Value);

# practical definition for infinity for sig fig count, can also use MathObject Infinity.
my $inf    = 9**9**9;  

sub new {
	#** @method public new ($x)
	# @param x required - String literal that is converted to number with set sig figs OR a 2-item array where the 1st item is the value and the 2nd item is the number of signififcant digits 
    # @brief Constructor.  
	# Example: new('1.30') 
	# Example: new([1.3, 3])
    #*
	my $self = shift; my $class = ref($self) || $self;
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
	my $x = shift; $x = [$x,@_] if scalar(@_) > 0; # not going to worry about this scenario yet.
	# return $x->inContext($context) if isInexactValue($x);  # if it's already an inexact value object, return it
	
	# this all seems to deal with turning a single parameter into an array so we can deal with
	# the generic case of passing multiple arguments.  [ ] creates an array reference, so we need
	# arrow operator to dereference before using index.
	$x = [$x] unless ref($x) eq 'ARRAY';
	# Value::Error("Can't convert ARRAY of length %d to %s",scalar(@{$x}),Value::showClass($self))
	#   unless (scalar(@{$x}) == 1);
	
	my $argCount = @$x;
	my $sigFigCount = 0;
	my $isScientificNotation = false;
	# Tolerance is useful when asking students to record an inexact value from an analog instrument (i.e. ruler).  The last digit will always vary by a little bit.
	# While a relative value of tolerance is ok, it's easier to use absolute tolerance since we know approximately how much the last digit will very.
	my $options = {
		tolerance => 0, 
		tolType => 'absolute',
		scientificNotationThreshold => 6, # can be set to 20 if problem requires conversion from standard to sci and we need to force standard
	};

	#	$tolerance = 0;          # zero tolerance by default
	#	$tolType = 'absolute';   # absolute tolerance if not zero
	
	my $matchNumber = '';

	if ($argCount >= 2) {
		# two arguments mean either a specific number of sig figs is provided or an options hash
		#$isScientificNotation = $x->[0] =~ /((?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10(?:\^|\*\*)-|\s?(?:x|\*)\s?10(?:\^|\*\*)\+|\s?(?:x|\*)\s?10(?:\^|\*\*))\d+)/;
		@result = getValue($x->[0]);
		$isScientificNotation = $result[1];
		$matchNumber = $result[0]; #$x->[0];

		if (ref $x->[1] eq ref {}){
			# 2nd arg is an options hash
			$options = {%{$x->[1]}, %$options};
		} else {
			# check for infinity string first
			if (ref $x->[1] eq 'Value::Infinity') {
				$sigFigCount = $inf;
			} else {
				$sigFigCount = $x->[1];
			}
		}

		if ($argCount > 2)
		{	
			foreach ( keys%{ $x->[2] } ){
				$options->{ $_ } = $x->[2]->{ $_ } ; 
			}
			
		}

		if (exists $options->{isScientificNotation}){
			$isScientificNotation = $options->{isScientificNotation};
		}

	} else {
		# one argument means that a text value representing the significant figures value has been provided
		@result = getValue($x->[0]);
		$isScientificNotation = $result[1];
		$matchNumber = $result[0];
		# verify the string contains a number we can match
		#($matchNumber) = $x->[0] =~ /((?:\+?-?\d+(?:\.\d+)?(?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10\^-|\s?(?:x|\*)\s?10\^\+|\s?(?:x|\*)\s?10\^)\d+)|(?:\+?-?\d+(?:\.?\d*)?)|(?:\.\d+))/;
		# added short phrase at beginning to detect plain exponent notation i.e. 10^-5
		#($matchNumber) = $x->[0] =~ /((?:10\^\+?-?\d+)|(?:\+?-?\d+(?:\.\d+)?(?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10\^-|\s?(?:x|\*)\s?10\^\+|\s?(?:x|\*)\s?10\^)\d+)|(?:\+?-?\d+(?:\.?\d*)?)|(?:\.\d+))/;
		#unless (defined $matchNumber) { 
		#	$temp = $x->[0];
		#		Value::Error("Can't convert this to a value. $temp  ");
		#}
		
		# find out if this is standard notation or scientific notation
		# /((?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10(?:\^|\*\*)-|\s?(?:x|\*)\s?10(?:\^|\*\*)\+|\s?(?:x|\*)\s?10(?:\^|\*\*))\d+)/;
		# added short phrase at beginning to detect plain exponent notation i.e. 10^-5
		#$isScientificNotation = $x->[0] =~ /((?:10\^\+?-?\d+)|(?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10(?:\^|\*\*)-|\s?(?:x|\*)\s?10(?:\^|\*\*)\+|\s?(?:x|\*)\s?10(?:\^|\*\*))\d+)/;
		
		#($isSimpleExponent, $expVal) = $x->[0] =~ /((?:^10\^(\+?-?\d+)))/;
		#if ($isSimpleExponent) {
		#	# do the math...
		#	$matchNumber =  10**$expVal;
		#	
		#} 

		# replace fancier scientific notation with plain 'e' so the computer recognizes it
		#$matchNumber =~ s/\s?(?:x|\*)\s?10(?:\^|\*\*)/e/;
		# split into coefficient and rest is scientific notation 
		my @parts = split(/e/, $matchNumber);
		
		# split coefficient into left and right side of decimal point 
		# -1 in 3rd parameter is to make unlimited empty matches (show empty trailing part if there is a decimal point even with nothing afterwards)
		my @decimalParts = split(/,|\./, $parts[0], -1); 
		$decimalPartsSize = @decimalParts;
		
		# first see if first part is empty string... if so, convert to a zero otherwise next step fails
		if ($decimalParts[0] eq ''){
			$decimalParts[0] = 0;
		}
		# convert first decimalPart to number and see if it is zero
		my $firstPartAsNumber = $decimalParts[0] + 0;
		my $isFirstZero = ($firstPartAsNumber == 0);
			
		if ($decimalPartsSize == 2)
		{
			# has decimal, get no of sig figs in first part, convert to number, then back to string, then get length
			$absFirstPartAsNumber = abs($firstPartAsNumber);
			$sigFigCount = ($isFirstZero ? 0 : length("$absFirstPartAsNumber"));
			
			# get no of sig figs in second part if not empty (i.e. 25.  decimal point at end)
			unless ($decimalParts[1] eq "")
			{
					# if starts with 0, then decimal part might have leading zeros... convert to number, then back to string, then get length
					# if starts with non-zero, decimal part is all significant... just count digits
					$secondPartAsNumber = $decimalParts[1] + 0;
					$sigFigCount += ($isFirstZero ? length("$secondPartAsNumber") : length($decimalParts[1]));
			}
		}
		else
		{
			 # if decimalPart[0] is a zero, do nothing
			unless ($isFirstZero)
			{
				# use trailing zeros regex
				@matches = ($decimalParts[0] =~ /[1-9]+|0+/g);
				$last = pop @matches;
				if (($last + 0) == 0) #if the last match contains zeros
				{
					#remove them and count the rest
					$piece = substr($decimalParts[0], 0, length($decimalParts[0]) - length($last));
					$sigFigCount = length($piece);
				} else {
					# just count all the digits
					$sigFigCount = length($decimalParts[0]);
				}
			} else {
				$sigFigCount = $inf;
			} 
		}
	}
	my $s = bless {data => [$matchNumber], context => $context}, $class;

	$s->sigFigs($sigFigCount);
	$s->preferScientificNotation($isScientificNotation);
	$s->{isInexact} = 1;
	$s->{precedence}{'InexactValue'} = 3;
	$s->{options} = $options;
	return $s;
}

sub getValue {
	#** @function private getValue ($x)
	# @brief Parses string value in multiple formats into number 
	# @param x required Raw string that needs to be parsed into a value.
	# @retval result Array: 1st item is coefficient, 2nd item is scientific exponent.
	#*
	my $x = shift;
	my @result;
	$result[1] = 0;
	
	# verify the string contains a number we can match
	#($matchNumber) = $x->[0] =~ /((?:\+?-?\d+(?:\.\d+)?(?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10\^-|\s?(?:x|\*)\s?10\^\+|\s?(?:x|\*)\s?10\^)\d+)|(?:\+?-?\d+(?:\.?\d*)?)|(?:\.\d+))/;
	# added short phrase at beginning to detect plain exponent notation i.e. 10^-5
	($result[0]) = $x =~ /((?:10\^\+?-?\d+)|(?:\+?-?\d+(?:\.\d+)?(?:e|e\+|e-|E|E\+|E-|\s?(?:x|X|\*)\s?10\^-|\s?(?:x|\*)\s?10\^\+|\s?(?:x|X|\*)\s?10\^)\d+)|(?:\+?-?\d+(?:\.?\d*)?)|(?:\.\d+))/;
	unless (defined $result[0]) { 
		$temp = $x;
		$result[0] = 0;
			#Value::Error("Can't convert this to a value. $temp  ");
	}
	
	# find out if this is standard notation or scientific notation
	# /((?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10(?:\^|\*\*)-|\s?(?:x|\*)\s?10(?:\^|\*\*)\+|\s?(?:x|\*)\s?10(?:\^|\*\*))\d+)/;
	# added short phrase at beginning to detect plain exponent notation i.e. 10^-5
	$result[1] = $x =~ /((?:10\^\+?-?\d+)|(?:e|e\+|e-|E|E\+|E-|\s?(?:x|X|\*)\s?10(?:\^|\*\*)-|\s?(?:x|X|\*)\s?10(?:\^|\*\*)\+|\s?(?:x|X|\*)\s?10(?:\^|\*\*))\d+)/;

	($isSimpleExponent, $expVal) = $x =~ /((?:^10\^(\+?-?\d+)))/;
	if ($isSimpleExponent) {
		# do the math...
		$result[0] =  10**$expVal;
		return @result;
	} 

	# replace fancier scientific notation with plain 'e' so the computer recognizes it
	$result[0] =~ s/\s?(?:x|X|\*)\s?10(?:\^|\*\*)/e/;
	$result[0] =~ s/E/e/;
	
	# split into coefficient and rest is scientific notation 
	#my @parts = split(/e/, $matchNumber);
	return @result;
}

sub make {
	#** @method private make ($x)
	# @param x required String literal that is converted to number with set sig figs OR a 2-item array where the 1st item is the value and the 2nd item is the number of signififcant digits  
    # @brief Internal alternate constructor. 
    #*
	my $self = shift;
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
	#Value::Error($self->value);
	#my $x = shift; $x = [$x,@_] if scalar(@_) > 0; # not going to worry about this scenario yet.
	#return $x->inContext($context) if isInexactValue($x);  # if it's already an inexact value object, return it
	
	# this all seems to deal with turning a single parameter into an array so we can deal with
	# the generic case of passing multiple arguments.  [ ] creates an array reference, so we need
	# arrow operator to dereference before using index.
	$self = [$self] unless ref($x) eq 'ARRAY';
	# Value::Error("Can't convert ARRAY of length %d to %s",scalar(@{$x}),Value::showClass($self))
	#   unless (scalar(@{$x}) == 1);
	
	my $argCount = @$self;
	my $sigFigCount = 0;
	my $isScientificNotation = false;
	my $matchNumber = '';

	# my %options = (
	# 	tolerance => 0.000001, 
	# 	tolType => 'absolute'
	# );
	my $options = {
		tolerance => 0, 
		tolType => 'absolute',
		scientificNotationThreshold => 6, # can be set to 20 if problem requires conversion from standard to sci and we need to force standard
	};

	if ($argCount >= 2) {
		# two arguments mean that a plain number with an explicit number of significant figures has been provided
		@result = getValue($x->[0]);
		$isScientificNotation = $result[1];
		$matchNumber = $result[0]; 
		
		if (ref $self->[1] eq ref {}){
			# 2nd arg is an options hash
			$options = $self->[1];
		} else {
			# check for infinity string first
			if ($x->[1] eq 'infinity' || $x->[1] eq 'Infinity') {
				$sigFigCount = $inf;
			} else {
				$sigFigCount = $x->[1];
			}
		}

		if ($argCount > 2)
		{			
			foreach ( keys%{ $self->[2] } ){
				$options->{ $_ } = $self->[2]->{ $_ } ; 
			}
		}

		if (exists $options->{isScientificNotation}){
			$isScientificNotation = $options->{isScientificNotation};
		}
	} else {
		# one argument means that a text value representing the significant figures value has been provided
		# verify the string contains a number we can match

		@result = getValue($x->[0]);
		$isScientificNotation = $result[1];
		$matchNumber = $result[0]; #$x->[0];
		# ($matchNumber) = $self->[0] =~ /((?:\+?-?\d+(?:\.\d+)?(?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10\^-|\s?(?:x|\*)\s?10\^\+|\s?(?:x|\*)\s?10\^)\d+)|(?:\+?-?\d+(?:\.?\d*)?)|(?:\.\d+))/;
		# unless (defined $matchNumber) { 
		# 	$temp = $self->[0];
		# 		Value::Error("Can't convert this to a value. $temp  ");
		# }
		
		# # find out if this is standard notation or scientific notation
		# $isScientificNotation = $self->[0] =~ /((?:e|e\+|e-|E|E\+|E-|\s?(?:x|\*)\s?10(?:\^|\*\*)-|\s?(?:x|\*)\s?10(?:\^|\*\*)\+|\s?(?:x|\*)\s?10(?:\^|\*\*))\d+)/;
		
		# # replace fancier scientific notation with plain 'e' so the computer recognizes it
		# $matchNumber =~ s/\s?(?:x|\*)\s?10(?:\^|\*\*)/e/;
		
		# split into coefficient and rest is scientific notation 
		my @parts = split(/e/, $matchNumber);
		
		# split coefficient into left and right side of decimal point 
		# -1 in 3rd parameter is to make unlimited empty matches (show empty trailing part if there is a decimal point even with nothing afterwards)
		my @decimalParts = split(/,|\./, $parts[0], -1); 
		$decimalPartsSize = @decimalParts;
		
		# convert first decimalPart to number and see if it is zero
		$firstPartAsNumber = $decimalParts[0] + 0;
		my $isFirstZero = ($firstPartAsNumber == 0);
			
		if ($decimalPartsSize == 2)
		{
			# has decimal, get no of sig figs in first part, convert to number, then back to string, then get length
			$absFirstPartAsNumber = abs($firstPartAsNumber);
			$sigFigCount = ($isFirstZero ? 0 : length("$absFirstPartAsNumber"));

			# get no of sig figs in second part if not empty (i.e. 25.  decimal point at end)
			unless ($decimalParts[1] eq "")
			{
					# if starts with 0, then decimal part might have leading zeros... convert to number, then back to string, then get length
					# if starts with non-zero, decimal part is all significant... just count digits
					$secondPartAsNumber = $decimalParts[1] + 0;
					$sigFigCount += ($isFirstZero ? length("$secondPartAsNumber") : length($decimalParts[1]));
			}
		}
		else
		{
			 # if decimalPart[0] is a zero, do nothing
			unless ($isFirstZero)
			{
				# use trailing zeros regex
				@matches = ($decimalParts[0] =~ /[1-9]+|0+/g);
				$last = pop @matches;
				if (($last + 0) == 0) #if the last match contains zeros
				{
					#remove them and count the rest
					$piece = substr($decimalParts[0], 0, length($decimalParts[0]) - length($last));
					$sigFigCount = length($piece);
				} else {
					# just count all the digits
					$sigFigCount = length($decimalParts[0]);
				}
			} else {
				$sigFigCount = $inf;
			} 
		}
	}
	
	my $s = bless {data => [$matchNumber], context => $context}, $class;
	
	$s->sigFigs($sigFigCount);
	$s->preferScientificNotation($isScientificNotation);
	$s->{isInexact} = 1;
	$s->{precedence}{'InexactValue'} = 3;
	$s->{options} = $options;
	return $s;
}

sub sigFigs {
	#** @method public scalar sigFigs ($value)
	# @brief Gets or sets number of significant figures. 
	# @param value optional Number of significant figures to set if needed. 
    # 
	#*
	my ($self, $value) = @_;
	if (@_ == 2) {
		$self->{sigFigs} = $value;
	} 
	return $self->{sigFigs};
}

sub preferScientificNotation {
	#** @method public scalar preferScientificNotation ($value)
	# @brief Sets flag to output scientific notation whenever possible. 
	# @param value - Boolean (1 or 0) to set flag. 
    # 
	#*
		my ($self, $value) = @_;
		if (@_ == 2) {
				$self->{preferScientificNotation} = $value;
		} 
		return $self->{preferScientificNotation};
}

sub valueAsNumber {
	#** @method public scalar valueAsNumber ()
	# @brief Returns unrounded internal value of InexactValue.  This includes irrational values 
	# resulting from calculations.  Will NOT round to the sig figs set internally. 
    # 
	#*
	my $self = shift;
	
	@valArray = $self->value;# + 0;
	$valAsNumber = $valArray[0] + 0;
	return $valAsNumber;
}

sub valueAsRoundedNumber {
	#** @method public scalar valueAsRoundedNumber ()
	# @brief Returns internal rounded value of InexactValue as a string. 
	# Will round to the sig figs set internally. 
	#*
	my $self = shift;
	$roundedValue = $self->string(true);
	return $roundedValue;
}

sub valueAsRoundedScientific {
	#** @method public scalar valueAsRoundedScientific ()
	# @brief Returns internal rounded value of InexactValue as a string, 
	# but forced as scientific notation. Will round to the sig figs set internally. 
	#*
	my $self = shift;
	$roundedValue = $self->string(true, true);
	return $roundedValue;
}

#
# Generate the unrounded inexact value (from a previous calculation) and underline the last significant figure.
# Add a true parameter to force scientific notation. (NOT WORKING YET)
#
sub unroundedValueMarked {
	my $self = shift;
	my $options = shift;

	# by default, limit to at most 3 digits past last significant digit.  0 means no limit.
 	my $limit = 3;
 	if (exists $options->{limit}){ 
 		$limit = $options->{limit};
 	}

	my $unRoundedValue = $self->valueAsNumber();
	my $strPos = '';
	my $trail;
	
	if (($self->preferScientificNotation() ? $self->valueAsRoundedScientific() : $self->valueAsRoundedNumber()) =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){

		if(defined $1){
			$strPos = $-[1]; # $-[1] gives the position of the match!
		} elsif (defined $2){
			$strPos = $-[2];
		} elsif (defined $3){
			$strPos = $-[3];
		} elsif (defined $4){
			$strPos = $-[4];
			if ($strPos > 0){
				$strPos--;
			}
		}
	}
	# what if unroundedvalue is scientific?
	if ($unRoundedValue =~ /e/){
		$trail = substr($unRoundedValue, $strPos + 2, length($unRoundedValue) - $strPos - 2);
		if (length $trail > $limit){
			if ($trail =~ /\./){
				$trail = substr($trail, 0, $limit + 1);
			} else {
				$trail = substr($trail, 0, $limit);
			}
		}
		$trail =~ s/e/\\times 10^ /r;
	} else {
		$trail = substr($unRoundedValue, $strPos + 1, length($unRoundedValue) - $strPos - 1);
		if (length $trail > $limit){
			if ($trail =~ /\./){
				$trail = substr($trail, 0, $limit + 1);
			} else {
				$trail = substr($trail, 0, $limit);
			}
		}
	}
	$unRoundedValue = substr($unRoundedValue, 0, $strPos) . '\\underline{' . substr($unRoundedValue, $strPos,1) . '}' . $trail;
	
	return $unRoundedValue;
}

#
#  Stringify using x notation not E,
#  using the right number of digits, and trimming
#  if requested.
#
sub string {
	#** @method public scalar string ($preventClean, $forceScientific)
	# @brief Returns string representation of InexactValue.  
	# Will round to the sig figs set internally.
	# "Cleaning" converts 'e' computer notation into readable 'x10^' notation.
	# Scientific notation is normally output when the value's exponent would be 
	# greater than the positive scientificNotationThreshold (default: 6) or less 
	# than the negative of that same value.  This can be set as a context option.
	# @param preventClean optional - Prevent cleaning, i.e. prevent conversion of 'e' to 'x10^'
	# @param forceScientific optional - Force scientific notation even for easy to read numbers.
	#*
	my $self = shift;
	my $preventClean = shift;

	my $forceScientific = shift;
	if ($self->sigFigs() == 0){
		return 'zero sig figs';
	}

	@valArray = $self->value;# + 0;
	$valAsNumber = $valArray[0];
	
	# Only here is scientific required or preferred
	if ($self->preferScientificNotation() || $forceScientific) {
		$decimals = $self->sigFigs() - 1;
		if ($preventClean) {
			if ($decimals == $inf){
				return sprintf("%e", $self->roundingHack($valAsNumber));
			} else {
				$log = main::floor(log(abs($valAsNumber))/log(10));
				$rounded = main::Round($valAsNumber,($log*-1) + $decimals);
				return sprintf("%.${decimals}e", $rounded);
			}
		} else {
			if ($decimals == $inf){	
				# cleaning adds trailing zeros if exact, remove them
				return $self->cleanSciText(sprintf("%e", $valAsNumber),{trimZeros => 1});				
			}else {
				$log = main::floor(log(abs($valAsNumber))/log(10));
				$rounded = main::Round($valAsNumber,($log*-1) + $decimals);
				return $self->cleanSciText(sprintf("%.${decimals}e", $rounded));
			}
		}   

	} else {
		# Usually will be here for most numbers.
		if ($self->sigFigs() == Infinity){
			
			return $valAsNumber; # no modification for a number with infinity sig figs.  No reason to write more zeros.
								 # There's no way to show it has inifinite sig figs.
		} else {
			
			# For any non infinite number (non-scientific normally)
			if ($valAsNumber == 0){
				return sprintf("%." . ($self->sigFigs()-1) . "f", $valAsNumber);
			}
			elsif (abs($valAsNumber) < 1) { # val less than one
				# get position of first significant digit i.e. 0.00000001 <= eigth place after decimal
				# by converting it to sci notation and get the abs of the exponent
				@esplit = split(/e|E/, sprintf("%e", $valAsNumber));
				if (defined $esplit[1]) { #if we make zero scientific, it won't work...
					$firstNonZeroPosition = abs($esplit[1]);
					$scientificNotationThreshold = $self->{options}->{scientificNotationThreshold};
					# if position plus required sigfigs is not more than 20 digits (limit for floating point errors) 
					# This is not correct, that's just the max... We'll just casually convert to sci notation if smaller than threshold
					if ($firstNonZeroPosition - 1 + $self->sigFigs() <= $scientificNotationThreshold){
						# ok to show as standard notation
						$digits = $firstNonZeroPosition - 1 + $self->sigFigs();
						return sprintf("%.${digits}f", main::Round($valAsNumber, $digits));
					} else {
						# must show as sci notation b/c won't work or surpasses scientific threshold (i.e. too many zeros after decimal)
						$digits = $self->sigFigs() - 1;
						if ($preventClean) {
							# if digits are infinite, this will throw an error.  For exact values, don't force a number of digits. Just use what is printed normally.
							# if ($digits > 20) {
							# 	return sprintf("%e", $self->roundingHack($valAsNumber));
							# }
							return sprintf("%.${digits}e", main::Round($valAsNumber, $firstNonZeroPosition + $digits));
						} else {
							# if digits are infinite, this will throw an error.  For exact values, don't force a number of digits. Just use what is printed normally.
							# if ($digits > 20) {
							# 	return $self->cleanSciText(sprintf("%e", $self->roundingHack($valAsNumber)));
							# }
							return $self->cleanSciText(sprintf("%.${digits}e", main::Round($valAsNumber, $firstNonZeroPosition+$digits)));
						}
					}
				} else {
					return '0';
				}
			} else { # val greater than one
			
				# need to show using decimal only if digits are not more than 6 orders of magnitude
				# this is now set by options parameter via scientificNotationThreshold
				# get position of first digit
				@esplit = split(/e|E/, sprintf("%e", $valAsNumber));
				if (defined $esplit[1]) { 
					$scientificNotationThreshold = $self->{options}->{scientificNotationThreshold};
					#if we make zero scientific, it won't work... but this shouldn't happen here... must be another case
					$firstPosition = abs($esplit[1]);
					if ($firstPosition < $scientificNotationThreshold) {
						# try printing part of number without decimal
						#$nondecimalPartAbs = sprintf("%.0f", abs($self->roundingHack($valAsNumber)));
						# There was a major bug here.  Using sprintf actually rounds when all we want is to truncate the decimal part.
						$nondecimalPartAbs = int(abs($self->roundingHack($valAsNumber)));
						$sign = $valAsNumber >= 0;
						# if there are more sig figs than the whole part of the number (i.e. 12 with 4 sig figs)
						if ($self->sigFigs() > length($nondecimalPartAbs)) {
							# there is definitely a decimal, count how many places
							$fixedDecimal = $self->sigFigs() - length($nondecimalPartAbs);
							# redo convert value to fixed decimal place
							# if ($fixedDecimal eq "Inf"){
							# 	return sprintf("%.0f", $self->roundingHack($valAsNumber));
							# } 
							return sprintf("%.${fixedDecimal}f", $self->roundingHack($valAsNumber));

						} elsif ($self->sigFigs() == length($nondecimalPartAbs)) {
							# no decimal, but there are exactly the right number of digits in non-decimal part
							# must check if number ends in zero; if so, we need a decimal point at the end.  
							# BUG: using $nondecimalPartAbs from before causes 55.5 with 2 sf to round to 55 only.
							$nondecimalPartAbs = sprintf("%.0f", abs($self->roundingHack($valAsNumber)));
							if (substr($nondecimalPartAbs,-1) == 0) {
								return ($sign ? '' : '-') . $nondecimalPartAbs . '.';
							} else {
								return ($sign ? '' : '-') . $nondecimalPartAbs;
							}

						} else {
							# There are not enough significant figures.  
							# Need to see if trailing zeros will let us write a simple decimal number
							# Loop through digits going from ones place to higher (backwards)

							# testing if pre-rounding to whole number works better for this...
							# the problem is that without the pre-rounding, a number like 1996 rounded to 1 sig fig should be 2000
							# but the algorithm thought there weren't enough zeros to show 1 sig fig with 1996.  So we have to do the rounding here, 
							# then test. 
							
							#$nondecimalPartAbs = sprintf("%.${digits}e", $self->roundingHack($valAsNumber));
							$sigfigs = $self->sigFigs();
							$digits = length($valAsNumber) - $self->sigFigs();  
							# negative value for digits because we are rounding non-decimal digits.
							$nondecimalPartAbs = sprintf("%.${sigfigs}e", main::Round($valAsNumber, $digits * -1));
							$nondecimalPartAbs = sprintf("%.0f", abs($nondecimalPartAbs));

							$firstNonZeroDigitIndex = 0;
							for ($i = length($nondecimalPartAbs) - 1; $i >= 0; $i--) {
								if (substr($nondecimalPartAbs, $i, 1) ne '0')
								{
									last;
								}
								$firstNonZeroDigitIndex++;
							}

							if ((length($nondecimalPartAbs) - $firstNonZeroDigitIndex) == $self->sigFigs()) {
								# we have just trailing zeros to make the sigfigs match without reverting 
								# to scientific notation
								$temp = ($sign ? '' : '-') . $nondecimalPartAbs;
								return ($sign ? '' : '-') . $nondecimalPartAbs;

							} else {
								# have to use scientific, there's no way to write the number using standard notation
								$digits = $self->sigFigs() - 1;
								#$digits = length($valAsNumber) - $self->sigFigs();  
								
								if ($preventClean) {
									return sprintf("%.${digits}e", main::Round($valAsNumber, $digits));
								} else {

									return $self->cleanSciText(sprintf("%.${digits}e", main::Round($valAsNumber, $digits)));
								}
								
							}
						} 
					} else {
						# must make scientific, past threshold set.  (remember: value is greater than one here)
						$digits = $self->sigFigs() - 1;
						# if ($digits eq "Inf"){
						# 	return sprintf("%.0f", $self->roundingHack($valAsNumber));
						# } 
						if ($preventClean) {
							return sprintf("%.${digits}e", main::Round($valAsNumber, $digits));
							#return sprintf("%.${digits}e", $self->roundingHack($valAsNumber));
						} else {
							return $self->cleanSciText(sprintf("%.${digits}e", main::Round($valAsNumber, $digits)));
							#return $self->cleanSciText(sprintf("%.${digits}e", $self->roundingHack($valAsNumber)));
						}
					}
				} else {
					return "0";
				}
			}
		}
	}
	
	# this is a fallback pathway.  It should never be reached unless there's a bug in the code above.
	my $digits = $self->getFlag("snDigits");
	my $trim = ($self->getFlag("snTrimZeros") ? '0*' : '');
	my $r = "333";#$self->cleanSciText(sprintf("%e", $self->value));
	return $r;
}

# THIS IS NOT FUNCTIONAL.  LEAVING IT HERE UNTIL WE CAN REMOVE IT FROM OTHER PLACES.
sub roundingHack {	
	my $self = shift;
	my $s = shift;
	return main::Round($s,20);
	#Round($val, +for decimal/-for other way);
	# floating point rounding causes errors
	# 5.555 is stored as 5.554999999999999999 something... and it will round down to 5.55, when we want it to round up to 5.56!
	# Hacky way to fix:  tack on a few zeros to the end with a 1 before rounding. 
	# Need to make sure there's a decimal point first and check it won't become scientific automatically
	# This HACK will NOT work if you have to ADD more zeros to a number than is shown in the hack...
	# i.e. if you need to show 1 with 10 sig figs -> 1.000000000
	#      the hack will screw this up and show -> 1.000000001
	# Right now, the hack limits us to adding 10 zeros... probably can add more, but I don't know the limit yet.
	$hackedNumber=0;
	if ($s =~ /e/){
		@esplit3 = split(/e/, $s);
		if ($esplit3[0] =~ /\./){
			$hackedNumber = $esplit3[0].'000000001e'.$esplit3[1];
			
			$hackedNumber = $hackedNumber + 0; 
		} else {
			$hackedNumber = $esplit3[0].'.000000001e'.$esplit3[1];
			
			$hackedNumber = $hackedNumber + 0;
		}
	}else {
		if ($s =~ /\./){
			$hackedNumber = "$s".'000000001';
			
			$hackedNumber = $hackedNumber + 0; 
		} else {
			$hackedNumber = "$s".'.000000001';
			
			$hackedNumber = $hackedNumber + 0;
		}
	}
	return $hackedNumber;
}

sub cleanSciText {
	#** @method public scalar cleanSciText ($s, %$options)
	# @brief Converts 'e' scientific notation to 'x10^' notation.  
	# Example:  Converts '1e3' to '1x10^3'.
	# Optionally trims zeros.  Some "exact" values like 1e5 get output
	# to 1.00000e5 by sprintf.  Trimming these zeros would be necessary.
	# @param s required - Value/string to convert
	# @param options optional - Contains {trimZeros} key as boolean.
	#*
	my $self = shift;
	my $s = shift;
	my $options = shift;
	# the or (|) followed by nothing allows perl to populate the group with an empty string 
	# instead of no variable.
	$s =~ s/(e)(\+|)?(-|)?(0*)/x10^$3/;
	if (defined $options && exists $options->{trimZeros} && $options->{trimZeros}){
		# e switch at end lets perl use code for regex replacement.  Have to test for undefined group before using it.
		$s =~ s/(?:(\.[1-9]+)|(?:\.)(test|))0*/defined($1)?$1:q{}/e;	
	}
	return $s
}


#
#  Convert x notation to TeX form
#  Our text output should always have 10x notation if scientific.
#
sub TeX {
	#** @method public scalar TeX ($preventClean)
	# @brief Returns LaTeX representation of InexactValue.  
	# Will round to the sig figs set internally.
	# Actually calls string method first.
	# "Cleaning" converts 'e' computer notation into readable '\10^' notation
	# which in LaTeX would use \times instead of x.
	# @param preventClean optional - Prevent cleaning, i.e. prevent conversion of 'e' to 'x10^'
	#*
	my $self = shift;
	my $preventClean = shift;
	my $r = $self->string($preventClean);
	$r =~ s/x/\\times /;
	$r =~ s/\^(.*)/^{$1}/;
	return $r;
}

# sub unroundedMarked {
# 	my $self = shift;
# 	my $options = shift;

# 	# by default, limit to at most 3 digits past last significant digit.  0 means no limit.
# 	my $limit = 3;
# 	if (exists $options->{limit}){ 
# 		$limit = $options->{limit};
# 	}
	
# 	my $value = $self->valueAsNumber();
# 	warn $value;
# 	my $strPos = 0;
# 	warn $self;
# 	warn $self->valueAsRoundedNumber();
# 	if (($self->preferScientificNotation() ? $self->valueAsRoundedScientific() : $self->valueAsRoundedNumber()) =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){
# 		if(defined $1){
# 			$strPos = $1;
# 		} elsif (defined $2){
# 			$strPos = $2;
# 		} elsif (defined $3){
# 			$strPos = $3;
# 		} elsif (defined $4){
# 			$strPos = $4;
# 		}
# 	}
# 	warn $strPos;
# 	my $trailAmount = length($value) - $strPos - 1;
# 	if ($trailAmount > $limit && $limit != 0){
# 		warn 'here';
# 		warn $trailAmount;
# 		$trailAmount = 3;
# 	}

# 	my $trail = substr($value, $strPos + 1, $trailAmount);
# 	my $trail =~ s/e/\\times 10^ /r;

# 	$value = substr($value, 0, $strPos) . '\\underline{' . substr($value, $strPos,1) . '}' . $trail;
# 	return $value;
# }

sub generateSfCountingExplanation {
	my $self = shift;
	my $detailedExplanation = shift;
	my $useSciNot = $self->preferScientificNotation();

	my $s = $self->string(true);
	my @breakdown = ();
	my $explanation = '';
	my $hasDecimal = 0;
	if ($useSciNot){
		my @esplit = split(/e/, $s);
		$exp = $esplit[1] + 0;
		$explanation = '\\underbrace{' . $esplit[0] . '}_{\\text{coeffecient}}^{\\text{✔}}~' . '\\underbrace{\\times 10^{' . $exp . '}}_{\\text{exponent}}^{\\text{✘}}~';
		$explanation = $self->TeX . ':' . $explanation . '=' . $self->sigFigs();
		if ($detailedExplanation ){
			$explanation = $explanation . '\\\\ \\text{All digits in coefficent of scientific notation are significant.  The exponent is never significant.}'
		}
		return $explanation;
	} else {
		($leadingZeros, $rest, $whole) = $s =~ /(?:(0*\.0*)(\S*))|(\S*)/;
		if (defined $leadingZeros ) {
			push(@breakdown,{val => $leadingZeros, type => 'leading'}); 
			$whole = $rest;
			$hasDecimal = 1;
		}
		if (defined $whole){
			($pre, $dec, $post) = $whole =~ /(\d*)(\.?)(\d*)/;
		
			if ($pre ne ''){
				while ($pre =~ /([123456789]*)(0*)/g){
					if ($1 ne ''){
						push @breakdown, {val => $1, type => 'nonzero'}; 
						#$explanation = $explanation . '\\underbrace{'. $1 . '}_{\\text{non-zero, significant}}';
					}
					if ($2 ne ''){
						push @breakdown, {val => $2, type => 'unknownzero'};
					}
				}
			}
			
			if ($dec ne ''){
				
				$hasDecimal = 1;
				push(@breakdown,{val => '.', type => 'decimal'});
			}
			if ($post ne ''){
				while ($post =~ /([123456789]*)(0*)/g){
					if ($1 ne ''){
						push(@breakdown,{val => $1, type => 'nonzero'}); 
					}
					if ($2 ne ''){
						push(@breakdown,{val => $2, type => 'unknownzero'});
					}
				}
			}
			$nomoretrailingzeros=0;
			$hasTrailingZeros = 0;

			for ($a = @breakdown -1 ; $a >= 0; $a--){
				#$explanation = $a . $explanation;
				$item = $breakdown[$a];
				if (defined $item->{type}){
					if ($item->{type} eq 'nonzero'){
						$nomoretrailingzeros = 1;
						$explanation = '\\underbrace{' . $item->{val} . '}_{\\text{non-zero}}^{\\text{✔}}~' . $explanation;
					} elsif ($item->{type} eq 'unknownzero'){
						if ($nomoretrailingzeros) {
							$explanation = '\\underbrace{' . $item->{val} . '}_{\\text{internal}}^{\\text{✔}}~'. $explanation;
						} else {
							$hasTrailingZeros=1;
							if ($hasDecimal){
								$explanation = '\\underbrace{' . $item->{val} . '}_{\\text{trailing*}}^{\\text{✔}}~'. $explanation;
							} else {
								$explanation = '\\underbrace{' . $item->{val} . '}_{\\text{trailing*}}^{\\text{✘}}~'. $explanation;
							}
						}
					} elsif ($item->{type} eq 'decimal') {
						$explanation = '.' . $explanation;
					} elsif ($item->{type} eq 'leading') {
						$explanation = '\\underbrace{'. $item->{val} . '}_{\\text{leading}}^{\\text{✘}}~' . $explanation;
					} else {
						$explanation = $item->{type} . 'not' . $explanation;
					}
				} else {
					$explanation = "item undefined." . $explanation ;
				}
				
			}
		}
		$doOrNot = $hasDecimal ? 'do' : 'do not';
		$notOrNothing = $hasDecimal ? '' : ' NOT';
		$explanation = $self->TeX . ':' . $explanation . '=' . $self->sigFigs();
		if ($detailedExplanation ) {
			if ($hasTrailingZeros){
				$explanation = $explanation . "~\\text{signficant figures.} \\\\ \\text{*Trailing zeros $doOrNot count as significant because a decimal point is$notOrNothing present.}";
			}
		}
		return $explanation;
		#return '\\underbrace{'.$s.'}_{\\text{leading zero, just placeholders}}';
	}
	
}

#
# This function is necessary for the rounding explanation section.  When rounding using sprintf, trailing zeros disappear.  We want to keep them in the explanation.
# This manually rounds a number up (using recursion).
#
sub roundUp {
	$self = shift;
	$stringToRoundUp = shift;
	($digitToRound, $decimal) = $stringToRoundUp =~ /(\d)(\.?\,?)$/; #must be at end, might have decimal point (and comma for international)
	$pieceTrimmed = $stringToRoundUp =~ s/\d\.?\,?$//r;
	if ($digitToRound == 9) {
			$pieceTrimmed = $self->roundUp($pieceTrimmed);
			$digitToRound = 0;
	} else {
		$digitToRound++;
	}
	return $pieceTrimmed . ($digitToRound == 0 ? '0' : $digitToRound) . $decimal;
}

#
# Generate an explanation for how to round to X sig figs.  1st parameter must be sf to round to.
# This uses the internally stored value, not the already rounded "display" value.  So it ignores the stored sigFigs property and uses the roundTo parameter.
#
sub generateSfRoundingExplanation {
	my $self = shift;
	my $roundTo = shift;
	if (!defined $roundTo || !$roundTo){
		return "Error:  Didn't specify a number of digits to round to.";
	}
	my $options = shift;
	my $suppressStart=0;
	if (exists $options->{suppressStart}){
		$suppressStart = $options->{suppressStart};
	}
	my $usePlainText = 0;
	if (exists $options->{plainText}){
		$usePlainText = $options->{plainText};
	}
	# my $outputTextOnly;
	# if (exists $options->{outputTextOnly}){
	#   $outputTextOnly = $options->{outputTextOnly};
	# }
	
	my $useSciNot = $self->preferScientificNotation();

	my $s = $self->string(true);

	$leadingZeros = '';
	$originalData = $self->{data}[0];
	$originalValue = $self->new($originalData);
	my $trimmedData;
	my $trailingExponent;

	# need initial check so we can be sure that $1 is either defined or undefined
	# the "r" non-destructive substitution parameter seems to be buggy since we can't check for success
	if ($originalData =~ /^\s*-?\s*(0[.,]0*)/){
		$trimmedData = $originalData =~ s/^\s*-?\s*(0[.,]0*)//r;
		if (defined $1){
			$leadingZeros = $1;
		}
	} else {
		$trimmedData = $originalData;
	}
	if ($trimmedData =~ s/e(\+?-?\d*)\s*//){
		$trailingExponent = $1;
	}
	$decimalRemoved = $trimmedData =~ s/\.?\,?//r;

	my $explanation = '';
	#my $textExplanation = '';

	unless ($usePlainText){
		if ($suppressStart != 1) {
			$explanation = $originalValue->TeX . '~\\text{with ' . $roundTo . ' sig figs }→~'; 
		}
	}

		# need to remove digits
	if (length($decimalRemoved) > $roundTo ) {
		$keepPart = '';
		$ind = 0;
		for ($a=0;$a < $roundTo;$a++){
			$digit = substr($trimmedData, $ind,1);
			$ind++;
			unless ($digit =~ /\d/){
				$keepPart = $keepPart . $digit; # this is the decimal point; keep it, too.
				$digit = substr($trimmedData, $ind,1);
				$ind++;
			}
			$keepPart = $keepPart . $digit;
			
		}
		
		#check to see if there's a trailing zero... put it back on the $keepPart
		if ($ind < length($trimmedData)){
			$check = substr($trimmedData, $ind, 1);
			if ($check =~ /[\.\,]/){
				$keepPart = $keepPart . $check;
			}
		}
		$firstDigitToDrop = substr($trimmedData, $ind, 1);
		$ind++;
		$restToDrop = substr($trimmedData, $ind, length($trimmedData) - $ind);

		if ($useSciNot) {
			if ($usePlainText){
				$explanation .= " Keep the " . $keepPart . " part of the original number. The rest will be dropped as insignificant except for the exponential portion. "
			} else {
				$explanation .= '\\overbrace{'. $keepPart.'}^{\\text{keep}}~'.'\\overbrace{\\underset{↑}{'. $firstDigitToDrop . '}'.$restToDrop .'}^{\\text{reject}}\times 10^{' . $trailingExponent . '}';
			}
		} else {    
			if ($usePlainText){
				$explanation .= " Keep the " . $keepPart . " part of the original number. The rest will be considered insignificant."
			} else {
				$explanation .= $leadingZeros .'\\overbrace{'. $keepPart .'}^{\\text{keep}}~'.'\\overbrace{\\underset{↑}{'. $firstDigitToDrop . '}'.$restToDrop . '}^{\\text{reject}}';
			} 
		}	

		$roundingExplanation = $firstDigitToDrop >= 5 ? '5 or greater' : 'less than 5';
		$roundingDirection = $firstDigitToDrop >= 5 ? 'up' : 'down';
		if ($usePlainText){
			$explanation .= " Since the first insignificant digit after is " . $roundingExplanation . ", the last significant digit needs to be rounded " . $roundingDirection ."."; 
		} else {
			$explanation .= "\\xrightarrow[\\text{$roundingExplanation, round $roundingDirection}]{\\text{since $firstDigitToDrop at arrow is }}";
		}

		unless ($usePlainText){
			if ($useSciNot){				
					$explanation .= $self->TeX;
				
			} else {
				if ($firstDigitToDrop >= 5) {
					$keepPart = $self->roundUp($keepPart);
				}
				unless ($leadingZeros . $keepPart =~ /[\.\,]/) { # if leadingZeros + keepPart does not have a decimal, 
																												# then most likely we'll need trailing zeroes to pad out the actual number
					@decSplit = split(/[\.\,]/, $restToDrop);
					$digits = 1;
					if (defined $decSplit[0]){
						$digits = $digits + length($decSplit[0]);
					}
					for ($a=0;$a < $digits; $a++){
						$keepPart = $keepPart . "0";
					}
				}
				$explanation .= $leadingZeros. $keepPart;
				
			}
		}
		if ($s =~ /e/ && !$useSciNot) {
			#if scientific despite not prefering it, we HAVE to use sci notation to display correct sigfigs
			if ($usePlainText){
				$explanation .= " Even though the number was using standard notation, we are forced to use scientific notation to display the correct number of significant figures in this case."
				
			}else{
				$explanation .= "\\xrightarrow[\\text{required for $roundTo sig figs}]{\\text{scientific notation}}";
				$explanation .= $self->TeX;
			}			
		} 

	
	} elsif (length($decimalRemoved) < $roundTo) {
		if ($usePlainText){
			$explanation = $textExplanation . " The provided number does not have enough significant figures.";	

		} else {
			if ($useSciNot){
				$explanation = $explanation. '\\overbrace{'. $trimmedData.'}^{\\text{keep}}~\times 10^{' . $trailingExponent . '}';
			} else {
				$explanation = $explanation. $leadingZeros .'\\overbrace{'. $trimmedData . '}^{\\text{keep}}~';
			}
		}
		 
		
	
		$originalSF = $originalValue->sigFigs();
		$zeroesNeeded = $roundTo - $originalSF;
		if ($usePlainText){
			$explanation .= " We must add " . $zeroesNeeded . " extra zeroes to the end of this number.";		
		} else {
			$explanation .= "\\xrightarrow[\\text{Need to add $zeroesNeeded zeros}]{\\text{Only $originalSF sig figs}}";
		}
		if ($s =~ /e/ && !$useSciNot) {
			#if scientific despite not prefering it, we HAVE to use sci notation to display correct sigfigs
			if ($usePlainText){
				$explanation .= " Even though the number was using standard notation, we are forced to use scientific notation to display the correct number of significant figures in this case.";
			}else{
				$explanation .= '✘' . "\\xrightarrow[\\text{must use scientific notation}]{\\text{Impossible with standard notation}}";
			}
		} 
		unless ($usePlainText) {
			$explanation .= $self->TeX;
		}
	} else {
		#perfect length already, do nothing
		if ($usePlainText){
			$explanation .= ' This number already has the correct number of significant figures.';
		}else {
			$explanation .= '\\ \\mathrm{Already has correct number of significant figures!}';
		}
	
	}

	return $explanation;
	
}


sub generateAddSubtractExplanation {
	my $self = shift;
	my $first = shift;
	my $second = shift;
	my $operation = shift;
	my $options = shift;

	my $useUnroundedFirst = $options->{useUnroundedFirst};
	my $useUnroundedSecond = $options->{useUnroundedSecond};
	my $leaveUnrounded = $options->{leaveUnrounded};
	my $usePlainText = $options->{plainText};
	

	if (!defined $first || !$first){
		return "Error:  Didn't specify the first parameter.";
	}
	if (!defined $second || !$second){
		return "Error:  Didn't specify the second parameter.";
	}
	if (!defined $operation || !$operation){
		return "Error:  Didn't specify the operation parameter (1 or -1).";
	}
	my $useSciNot = $self->preferScientificNotation();

	$posFirst = $first->leastSignificantPosition();  
	$posSecond = $second->leastSignificantPosition(); # -1 = ones, -2 = tens, 0 nothing, 1 = tenths, 2= hundredths
	#return Value::Error($posSecond);

	my $valueFirst;
	my $valueSecond;

	if ($useUnroundedFirst) {
		$valueFirst = $first->valueAsNumber();
	} else {
		$valueFirst = $first->preferScientificNotation() ? $first->valueAsRoundedScientific() : $first->valueAsRoundedNumber();
	}

	if ($useUnroundedSecond){
		$valueSecond = $second->valueAsNumber();
	} else {
		$valueSecond = $second->preferScientificNotation() ? $second->valueAsRoundedScientific() : $second->valueAsRoundedNumber();
	}

	my $strPosFirst = '';
	if ($valueFirst =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){
		if(defined $1){
			$strPosFirst = $-[1];
		} elsif (defined $2){
			$strPosFirst = $-[2];
		} elsif (defined $3){
			$strPosFirst = $-[3];
		} elsif (defined $4){
			$strPosFirst = $-[4];
		}
	}
	#return Value::Error($strPosFirst);
	# original regex: /(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/
	my $strPosSecond = '';
	if ($valueSecond =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){
		if(defined $1){
			$strPosSecond = $-[1];
		} elsif (defined $2){
			$strPosSecond = $-[2];
		} elsif (defined $3){
			$strPosSecond = $-[3];
		} elsif (defined $4){
			$strPosSecond = $-[4];
		}
	}
	# this is for scientific notation, will stay blank if nothing
	$firstTrail = '';
	if ($first->preferScientificNotation){
		$exp = substr($valueFirst, $strPosFirst + 2,length($valueFirst)-$strPosFirst) + 0;
		$firstTrail = "\\times 10^{$exp}";
	}
	$secondTrail = '';
	if ($second->preferScientificNotation){
		$exp = substr($valueSecond, $strPosSecond + 2,length($valueSecond)-$strPosSecond) + 0;
		$secondTrail = "\\times 10^{$exp}";
	}

	$firstTeX = $first->TeX;
	$secondTeX = $second->TeX;
	my $explanation = '';

	if ($usePlainText){
		my $operationVerb = $operation > 0 ? "adding" : "subtracting";
		my $operationObject = $operation > 0 ? "to" : "from";
		my $nameOfFirstPosition = ($posFirst >= 7 || $posFirst <= -7) ? $self->getNameOfPosition($posFirst) : 'in the '. $self->getNameOfPosition($posFirst) . ' place';
		my $nameOfSecondPosition = ($posSecond >= 7 || $posSecond <= -7) ? $self->getNameOfPosition($posSecond) : 'in the '. $self->getNameOfPosition($posSecond) . ' place';
		$explanation .= "You are $operationVerb a value whose <i>least significant digit</i> is $nameOfSecondPosition $operationObject a value whose <i>least significant digit</i> is $nameOfFirstPosition. ";

	} else {
		$explanation .= '\\overbrace{' . substr($firstTeX, 0, $strPosFirst) . '\\underline{' . substr($firstTeX, $strPosFirst,1) . '}' . $firstTrail .'}^{\\text{' . $self->getNameOfPosition($posFirst). '}}';
		$explanation .= ($operation > 0 ?  '+' : '-' ) . '\\overbrace{' . substr($secondTeX, 0, $strPosSecond) . '\\underline{' . substr($secondTeX, $strPosSecond,1) . '}' . $secondTrail .'}^{\\text{' . $self->getNameOfPosition($posSecond). '}}';
	}
	

	$rightmost = $posFirst > $posSecond ? $posFirst : $posSecond; #need this to limit floating point errors when decimals are present
	$leftmost = $posFirst < $posSecond ? $posFirst : $posSecond; #this one is for actual rounding.
	$leftmostName = $self->getNameOfPosition($leftmost);
	if ($usePlainText) {
		my $leftMostNamePlainText = ($leftmost >= 7 || $leftmost <= -7) ? $leftmostName : "the $leftmostName position" ;
		$explanation .= "The answer should have its <i>least significant digit</i> be the same as the left-most digit of the those two positions:  $leftMostNamePlainText. ";
	} else {
		if ($leftmost >= 7 || $leftmost <= -7) {
			$explanation .= "\\xrightarrow[\\text{position is $leftmostName}]{\\text{Left-most smallest significant}}";
		} else {
			$explanation .= "\\xrightarrow[\\text{position is the $leftmostName position}]{\\text{Left-most smallest significant}}";
		}
	}
	
	
	$simpleOperation = $operation > 0 ? $valueFirst + $valueSecond : $valueFirst - $valueSecond;
 
	#if there are any floating point errors, this will show up here.  Need to limit the digits displayed.
	$simpleAsInexact;
	if ($rightmost>0){ #it's got decimals...round to smallest decimal!
		$simpleAsInexact = $self->new(sprintf("%.${rightmost}f",$simpleOperation));
	} else {
		$simpleAsInexact = $self->new(sprintf("%.0f",$simpleOperation));
	}
	$simpleAsValue = $self->preferScientificNotation() ? $simpleAsInexact->valueAsRoundedScientific : $simpleAsInexact->valueAsRoundedNumber;
	$simpleAsTeX = $simpleAsInexact->TeX;
	#$actualAnswerPosition = $self->leastSignificantPosition();
	$answerValue = $self->preferScientificNotation() ? $self->valueAsRoundedScientific() : $self->valueAsRoundedNumber();
	#this regex is for the purpose of identifying the position of the last significant digit in the rounded value, NOT the unrounded one.
	my $strActualAnswerPosition = '';
	if ($answerValue =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){
		if(defined $1){
			$strActualAnswerPosition = $-[1];
		} elsif (defined $2){
			$strActualAnswerPosition = $-[2];
		} elsif (defined $3){
			$strActualAnswerPosition = $-[3];
		} elsif (defined $4){
			$strActualAnswerPosition = $-[4];
		}
	}

	# this is for scientific notation, will stay blank if nothing
	my $answerTrail = '';
	if ($first->preferScientificNotation || $second->preferScientificNotation || $simpleAsInexact->preferScientificNotation){
		@expsplit = split(/e/, $simpleAsValue);
		$exp = $expsplit[1]+0;
		if ($usePlainText){
			$answerTrail = "x10^$exp";
		}else {
			$answerTrail = "\\times 10^{$exp}";
		}
		$simpleAsValue = $expsplit[0];  #overwriting simpleAsValue so we don't write the exponent part AGAIN later.
	}

	if ($usePlainText){
		$boldValue = substr($simpleAsValue, $strActualAnswerPosition,1);
		$value = substr($simpleAsValue, 0, $strActualAnswerPosition) . '<b>' . $boldValue . '</b>' . substr($simpleAsValue, $strActualAnswerPosition + 1, length($simpleAsValue)-$strActualAnswerPosition) . $answerTrail;
		
		$explanation .= "The answer by calculator is $value, but we now know the least significant figure is the bold $boldValue. ";
	} else {
		$explanation .= substr($simpleAsValue, 0, $strActualAnswerPosition) . '\\underline{' . substr($simpleAsValue, $strActualAnswerPosition,1) . '}' . substr($simpleAsValue, $strActualAnswerPosition + 1,length($simpleAsValue)-$strActualAnswerPosition) . $answerTrail;
	}

	unless ($leaveUnrounded){
		if ($usePlainText){
			my $answer = $self->string; 
			$explanation .= "Finally, round to the least significant figure to get <b>$answer</b>."
		} else {
			$explanation .= "\\xrightarrow[\\text{$leftmostName position}]{\\text{Round to}}";
			$explanation .= $self->TeX;
		}
	}

	$explanation;
}

sub generateMultiplyDivideExplanation {
	my $self = shift;
	my $first = shift;
	my $second = shift;
	my $operation = shift; # +1 multiply, -1 divide
	my $options = shift;

	my $useUnroundedFirst = $options->{useUnroundedFirst};
	my $useUnroundedSecond = $options->{useUnroundedSecond};
	my $leaveUnrounded = $options->{leaveUnrounded};
	my $usePlainText = $options->{plainText};

	if (!defined $first || !$first){
		return "Error:  Didn't specify the first parameter.";
	}
	if (!defined $second || !$second){
		return "Error:  Didn't specify the second parameter.";
	}
	if (!defined $operation || !$operation){
		return "Error:  Didn't specify the operation parameter (1 or -1).";
	}
	my $useSciNot = $self->preferScientificNotation();

	my $explanation = '';
	my $sfFirst = $first->sigFigs();
	my $sfSecond = $second->sigFigs(); 

	
	my $valueFirst;
	my $valueSecond;
	my $firstTrail;
	my $secondTrail;

	if ($useUnroundedFirst) {
		$valueFirst = $first->valueAsNumber();
	} else {
		$valueFirst = $first->preferScientificNotation() ? $first->valueAsRoundedScientific() : $first->valueAsRoundedNumber();
	}

	if ($useUnroundedSecond){
		$valueSecond = $second->valueAsNumber();
	} else {
		$valueSecond = $second->preferScientificNotation() ? $second->valueAsRoundedScientific() : $second->valueAsRoundedNumber();
	}


	my $valueFirstR = $valueFirst;
	if ($useUnroundedFirst){
		my $strPosFirst = '';
		if (($first->preferScientificNotation() ? $first->valueAsRoundedScientific() : $first->valueAsRoundedNumber()) =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){
			if(defined $1){
				$strPosFirst = $-[1];
			} elsif (defined $2){
				$strPosFirst = $-[2];
			} elsif (defined $3){
				$strPosFirst = $-[3];
			} elsif (defined $4){
				$strPosFirst = $-[4];
			}
		}
		$firstTrail = substr($valueFirstR, $strPosFirst + 1, length($valueFirstR) - $strPosFirst - 1);
		$firstTrail =~ s/e/\\times 10^ /r;
		# if ($first->preferScientificNotation){
		#   $exp = substr($valueFirstR, $strPosFirst + 2,length($valueFirstR)-$strPosFirst) + 0;
		#   $firstTrail = "\\times 10^{$exp}";
		# }

		$valueFirstR = substr($valueFirstR, 0, $strPosFirst) . '\\underline{' . substr($valueFirstR, $strPosFirst,1) . '}' . $firstTrail;
	} else {
		$valueFirstR =~ s/e/\\times 10^ /r;
		$valueFirstR =~ s/x/\\times /r;
		$valueFirstR =~ s/\^(.*)/^{$1}/;
	}
 
	my $valueSecondR = $valueSecond;
	if ($useUnroundedSecond){
		my $strPosSecond = '';
		if ($valueSecondR =~ /(?:\.\d*?([0123456789])$)|(?:([123456789])0*$)|(?:([1234567890])\.$)|(?:([1234567890])(?:e[+-]?\d*)?$)/){
			if(defined $1){
				$strPosSecond = $-[1];
			} elsif (defined $2){
				$strPosSecond = $-[2];
			} elsif (defined $3){
				$strPosSecond = $-[3];
			} elsif (defined $4){
				$strPosSecond = $-[4];
			}
		}
		$secondTrail = substr($valueSecondR, $strPosSecond + 1, length($valueSecondR) - $strPosSecond - 1);
		$secondTrail =~ s/e/\\times 10^ /r;
		# if ($second->preferScientificNotation){
		#   $exp = substr($valueSecondR, $strPosSecond + 2,length($valueSecondR)-$strPosSecond) + 0;
		#   $secondTrail = "\\times 10^{$exp}";
		# }

		$valueSecondR = substr($valueSecondR, 0, $strPosSecond) . '\\underline{' . substr($valueSecondR, $strPosSecond,1) . '}' . $secondTrail;
	} else {
		$valueSecondR =~ s/e/\\times 10^ /r;
		$valueSecondR =~ s/x/\\times /r;
		$valueSecondR =~ s/\^(.*)/^{$1}/;
	}

	if ($usePlainText){
		$explanation .= "$valueFirstR has $sfFirst significant figures and $valueSecondR has $sfSecond significant figures.  "; 
	}else {
		if ($operation > 0){
			$explanation .= '\\overbrace{' . $valueFirstR . '}^{\\text{' . $sfFirst . ' sig figs}}';
			$explanation .= '\\times \\overbrace{' . $valueSecondR .'}^{\\text{' . $sfSecond . ' sig figs}}';
		} else {
			$explanation .= '\\frac{\\overbrace{' . $valueFirstR . '}^{\\text{' . $sfFirst . ' sig figs}}}';
			$explanation .= '{\\underbrace{' . $valueSecondR .'}_{\\text{' . $sfSecond . ' sig figs}}}';
		}
	}

	my $minSf = $sfFirst > $sfSecond ? $sfSecond : $sfFirst;
	if ($usePlainText){
		$explanation .= "The smallest number of sig figs is " . $minSf . ".";
	} else {
		$explanation .= "\\xrightarrow[\\text{$minSf sig figs}]{\\text{Minimum}}" ;
	}
	# may need to force more digits under extreme sig figs cases
	my $unroundedValueCleaned = $useSciNot ? sprintf('%e',$self->valueAsNumber) : sprintf('%f', $self->valueAsNumber);
	my $newInexact = $self->new("$unroundedValueCleaned", $minSf);
	if ($usePlainText){
		my $temp = $newInexact->generateSfRoundingExplanation($minSf, {plainText=>1});
		$temp =~ s/original number/calculated solution/;
		$explanation .= $temp;
	} else {
		my $sfExplained = $newInexact->generateSfRoundingExplanation($minSf);
		$explanation .= $sfExplained;
	}
	
	return $explanation;
}

sub getNameOfPosition {
	$self = shift;
	$digit = shift;
	if ($digit == 1){
		return 'tenths';
	} elsif ($digit == 2) {
		return 'hundredths';
	} elsif ($digit == 3) {
		return 'thousandths';
	} elsif ($digit == 4) {
		return 'ten-thousandths';
	} elsif ($digit == 5) {
		return 'hundred-thousandths';
	} elsif ($digit == 6) {
		return 'millionths';
	} elsif ($digit == 0) {
		return 'ones';
	} elsif ($digit == -1) {
		return 'tens';
	} elsif ($digit == -2) {
		return 'hundreds';
	} elsif ($digit == -3) {
		return 'thousands';
	} elsif ($digit == -4) {
		return 'ten-thousands';
	} elsif ($digit == -5) {
		return 'hundred-thousands';
	} elsif ($digit == -6) {
		return 'millions';
	} elsif ($digit <= -7) {
		$conv = abs($digit)+1;
		return "$conv digits left of decimal";
	} elsif ($digit >= 7){
		return "$digit digits right of decimal";
	}
}

sub simpleUncertainty {
	$self = shift;
	# This yields a simple uncertainty for basic chemistry.  
	# i.e. +/-1 in the last digit
	$pos = -1 * $self->leastSignificantPosition();
	return 10**($pos);
}

sub calculatedUncertainty {
	$self = shift;
	# TBD
	# This is for propagating uncertainty via calculations.  
	# i.e. adding relative uncertainty when multiplying/dividing 
	# and adding absolute uncertainty when adding/subtracting.
	Value::Error("Not implemented yet!"); 
}

##################################################
#
#  Binary operations
#
sub minSf {
	$self = shift;
	my $a = shift;
	my $b = shift;
	my $minSf = 0;
	if ($a->sigFigs() > $b->sigFigs()){
		$minSf = $b->sigFigs();
	} else {
		$minSf = $a->sigFigs();
	}
	return $minSf;
}

sub basicMin {
	$self = shift;
	my $a = shift;
	my $b = shift;
	my $minSf = 0;
	if ($a > $b){
	$minSf = $b;
	} else {
	$minSf = $a;
	}
	return $minSf;
}

sub isExactZero {
	$self = shift;
	if ($self->sigFigs == 9**9**9 && $self->valueAsNumber == 0){
		return 1;
	} else {
		return 0;
	}
}

sub isOne {
	$self = shift;
	if ($self->valueAsNumber == 1){
		return 1;
	} else {
		return 0;
	}
}


# negative values mean last place is tens or hundreds, etc.
# positive values mean last place is in the decimal region, tenths, hundredths, etc
# 0 is the ones digit
sub leastSignificantPosition {
	$self = shift;
	my $val = $self->valueAsNumber();
	my $sf = $self->sigFigs();
	$val = abs($val);
	if ($val >= 10) {
		my $p = 1;
		while ($val / (10**$p) >= 10) {  # this used to be just '>' but 100. would show 1 as the least sig position (tenths) which is WRONG
			$p++;
		}
		return -$p + $sf - 1;

	} elsif ($val < 1) {
		my $p = 1;
		while ($val * (10**$p) < 1) {
			$p++;
		}
		return $p + $sf - 1;

	} else {
		return $sf - 1;
	}
}

sub calculateSigFigsForPosition {
	$self = shift;
	my $val = shift;
	my $position = shift;
	#my $sign = $val < 0 ? -1 : 1;
	my $temp = abs(sprintf('%.0f',$val * (10**$position)));
	my $sf = 1;
	while ($temp / (10**$sf) > 1) {
			$sf++;
	}
	return $sf;
}

# this is mostly the same as the Value version, but this creates an "infinite SF" Inexact Value
# when the value being promoted is not already an Inexact Value.  Only works with reals and numbers.
sub promote {
	my $self = shift; my $class = ref($self) || $self;
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
	my $x = (scalar(@_) ? shift : $self);
	return $x->inContext($context) if ref($x) eq $class && scalar(@_) == 0;
	return $self->new($context,$x,$inf,@_);
}

# this is exactly the same as the Value version, but called here to use our own promote function
sub checkOpOrderWithPromote {
	my ($l,$r,$flag) = @_; $r = $l->promote($r);
	if ($flag) {return ($l,$r,$l,$r)} else {return ($l,$l,$r,$r)}
}

sub add {
	my ($self,$l,$r,$other) = Value::checkOpOrderWithPromote(@_);
	#$left= $l->value; $right= $r->value;
	$leftPos = $l->leastSignificantPosition();
	$rightPos = $r->leastSignificantPosition();
	$leftMostPosition = $self->basicMin($leftPos, $rightPos);
	$newValue = $l->valueAsNumber() + $r->valueAsNumber();
	$newSigFigs = $self->calculateSigFigsForPosition($newValue, $leftMostPosition);

	return $self->new($newValue, $newSigFigs);
}

sub sub {
	my ($self,$l,$r,$other) = Value::checkOpOrderWithPromote(@_);
	#$left= $l->value; $right= $r->value;
	$leftPos = $l->leastSignificantPosition();
	$rightPos = $r->leastSignificantPosition();
	$leftMostPosition = $self->basicMin($leftPos, $rightPos);
	$newValue = $l->valueAsNumber() - $r->valueAsNumber();
	$newSigFigs = $self->calculateSigFigsForPosition($newValue, $leftMostPosition);

	return $self->new($newValue, $newSigFigs);
}

sub mult {
	my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
	# edge case: multiplication by exact zero gives exact zero
	if ($left->isExactZero || $right->isExactZero){
		return $self->new(0,9**9**9);
	}

	$minSf = $left->minSf($left, $right);
	return $self->new($left->valueAsNumber() * $right->valueAsNumber(), $minSf);
}

sub div {
	my ($self,$l,$r,$other) = Value::checkOpOrderWithPromote(@_);
	Value::Error("Division by zero") if $r->{data}[0] == 0;
	# edge case: division using exact zero gives exact zero
	if ($l->isExactZero ){
		return $self->new(0,9**9**9);
	}

	$minSf = $self->minSf($l, $r);
	return $self->new($l->valueAsNumber() / $r->valueAsNumber(), $minSf);
}

sub power {
	# best rule: the error is equal to the error of the exponent times 
	#       the value of the exponential
	# rule for intro chem: (used here!)
	# count decimals in exponent and use that for answer sig figs
	my ($self,$l,$r,$other) = Value::checkOpOrderWithPromote(@_);

	my $decimalPortionOfExponent = abs($r->valueAsRoundedNumber()) - sprintf('%.f',abs($r->valueAsRoundedNumber()));
		
	my $shortCutToCountSigFigs = $self->new("$decimalPortionOfExponent");
	my $powerResult = $l->valueAsNumber()**$r->valueAsNumber();

	if ($l->sigFigs() < $shortCutToCountSigFigs->sigFigs()){
		return $self->new($powerResult, $l->sigFigs());
	} else {
		return $self->new($powerResult, $shortCutToCountSigFigs->sigFigs());
	}

}


# this is log base 10... not sure how to add new functions
sub log {
	# best rule:  the error is equal to the error of the argument 
	#             divided by the argument
	# rule for intro chem: (used here!)
	# count total sig figs in argument and use as decimal count for answer
	my $self = shift;
	my $sigFigs = $self->sigFigs();
	my $logResult = log($self->valueAsNumber())/log(10);
	# warn "DOING REGULAR LOG";
	# warn $logResult;
	if (abs($logResult) < 1){
		return $self->new($logResult, $sigFigs);

	} else {
		my $decimalPortion = abs($logResult) - sprintf('%.f',abs($logResult));
		my $shortCutToCountSigFigs = $self->new($decimalPortion, $sigFigs);
		if ($logResult > 0){
			return $self->new(sprintf('%.f',$logResult) + $shortCutToCountSigFigs);
		} else {
			return $self->new(sprintf('%.f',$logResult) - $shortCutToCountSigFigs);
		}
	}
}

sub ln {
	# best rule:  the error is equal to the error of the argument 
	#             divided by the argument
	# rule for intro chem: (used here!)
	# count total sig figs in argument and use as decimal count for answer
	my $self = shift;
	my $sigFigs = $self->sigFigs();
	my $logResult = log($self->valueAsNumber());
	# warn "DOING natural log";

	if (abs($logResult) < 1){
		return $self->new($logResult, $sigFigs);

	} else {
		my $decimalPortion = abs($logResult) - int(abs($logResult));
		my $shortCutToCountSigFigs = new InexactValue::InexactValue($decimalPortion, $sigFigs);
		# warn $logResult;
		# warn int(abs($logResult));
		# warn $shortCutToCountSigFigs;
		if ($logResult > 0){
			# warn $self->new(sprintf('%.f',$logResult) + $shortCutToCountSigFigs);
			return new InexactValue::InexactValue(sprintf('%.f',$logResult) + $shortCutToCountSigFigs);
		} else {
			return new InexactValue::InexactValue(sprintf('%.f',$logResult) - $shortCutToCountSigFigs);
		}
	}
}

sub abs {
	my $self=shift;
	my $newValue = abs($self->valueAsNumber);
	return $self->new($newValue,$self->sigFigs());
}



#
#  What to call us in error messages
#
sub cmp_class {"Inexact Value"}


# sub cmp_preprocess {
#   my $self = shift; my $ans = shift;
#   #$inexactStudent=0;
#   if (defined $ans->{student_value}) {
#     $ans->{preview_latex_string} = $ans->{student_value}->TeX;
#     $ans->{student_ans} = $self->quoteHTML($ans->{student_value}->string);
#   } else {
#     $ans->{student_value} = $self->new(0,$inf);  #blank answer is zero with infinite sf
#   }
# }

# sub cmp_defaults {
#   return (
#   Value::Real->cmp_defaults(@_),
#   typeMatch => 'InexactValue::InexactValue',
# );
# }

sub typeMatch {
	my $self = shift;  my $other = shift;
	return 1 unless ref($other);
	$self->type eq $other->type && !$other->isFormula;
}

sub cmp {
	my $self = shift;

	my $cmp = $self->SUPER::cmp(
		correct_ans => $self->string,
		correct_ans_latex_string =>  $self->TeX,
		@_
	);  


	$cmp->install_pre_filter('erase');
	$cmp->install_pre_filter(sub {
		my $ans = shift;
		$inexactStudent=0;
		if ($ans->{student_ans} eq ''){
			$inexactStudent = $self->new(0,$inf);  #blank answer is zero with infinite sf
		} else {
			$inexactStudent = $self->new($ans->{student_ans});
		}

		$ans->{student_value} = $inexactStudent;
		$ans->{preview_latex_string} = $inexactStudent->TeX;#$inexactStudent->TeX;# "\\begin{array}{l}\\text{".join("}\\\\\\text{",'@student')."}\\end{array}";
		$ans->{student_ans} = $inexactStudent->string; 

		return $ans;
	});

	return $cmp;
}

sub cmp_parse {
	my $self = shift; my $ans = shift;
	$ans->{_filter_name} = "InexactValue answer checker";
	
	#$ans->{correct_value}->cmp_parse($ans);

	my $correct = $ans->{correct_value};
	my $student = $ans->{student_value};
	$ans->{_filter_name} = "InexactValue answer checker";
	$creditSF = $self->getFlag("creditSigFigs");
	$creditValue = $self->getFlag("creditValue");
	$failOnValueWrong = $self->getFlag("failOnValueWrong");

	$ans->score(0); # assume failure
	$self->context->clearError();

	$currentCredit = 0;

	
	# Edge case of entering zero.  This is not perfect.  Theoretically, we could have zero with sig figs... but skip for now.
	if ($student->valueAsNumber == 0){
		if ($correct->valueAsNumber == 0){
			$ans->score(1);
		} else {
			$ans->score(0);
		}
		return $ans;
	}

	$currentCredit = $correct->compareValue($student, {"creditSigFigs"=>$creditSF, "creditValue"=>$creditValue, "failOnValueWrong"=>$failOnValueWrong});

	# # The following is naive - the actual answer might be 1.25 and a student may answer 1.3.  This will evaluate as false when it should evaluate
	# # as true, but marked sig figs wrong.  
	# # if ($correct->valueAsRoundedNumber() == $student->valueAsRoundedNumber()){

	# # Instead, we will compare both numbers rounded to the smallest number of sig figs between the two.  However, in the case
	# # of a student having the fewer number of sig figs, we limit to only one sig fig lower than the correct number.  i.e.
	# # Student: 1.1 g vs Correct: 1.111 g will mark student as wrong.
	# # Student: 1.11 g vs Correct: 1.111 g will mark student as correct.
	# # Student: 1.11111111 g vs Correct: 1.111 g will mark student as correct
	# # *** This condition can be later adjusted with flags.
	# # Keep edge case in mind:
	# # Correct Answer: 5 g
	# # Student cannot have 1 fewer sig fig in this case. 
	# my $min = $correct->sigFigs() < $student->sigFigs() ? $correct->sigFigs() : $student->sigFigs();
	# if ($min < 1){
	# 	$ans->score(0);
	# 	return $ans;
	# }
	# if ($correct->sigFigs() - $min > 1){
	# 	$min = $correct->sigFigs - 1;
	# }
	
	# my $transformedCorrect = $self->new($correct->valueAsNumber, $min);
	# my $transformedStudent = $self->new($student->valueAsNumber, $min);
	
	# # WHAT ABOUT ROUNDING ERRORS??? NEED ANOTHER CHECK FOR SLIGHT VARIATIONS... TO COME!
	# if ($transformedCorrect->valueAsRoundedNumber == $transformedStudent->valueAsRoundedNumber){
	# 	# numbers match, now check sig figs
	# 	$currentCredit += $creditValue;
	# 	if ($correct->sigFigs == $student->sigFigs){
	# 		$currentCredit += $creditSF;
	# 	} else {
	# 	#$ans->{ans_message} = "Your significant figures are not correct.";
	# 	}
	# } else {
	# 	if ($failOnValueWrong) {
	# 		#$ans->{ans_message} = $correct->valueAsRoundedNumber();
	# 	} else {
	# 		# grade sig figs amount anyways
	# 		if ($correct->sigFigs == $student->sigFigs){
	# 			$currentCredit += $creditSF;
	# 		#$ans->{ans_message} = "Your value is not correct, but your significant values are good.";
	# 		} else {
	# 		#$ans->{ans_message} = "Your value and your significant figures are both incorrect.";
	# 		}
	# 	}
	# }
	$ans->score($currentCredit);

	return $ans;
}

sub compareValue {
	my $self = shift;
	my $student = shift;
	my $options = shift;

	$creditSF = $options->{"creditSigFigs"};	
	$creditValue = $options->{"creditValue"};
	$failOnValueWrong = $options->{"failOnValueWrong"};

	my $currentCredit = 0;


	my $min = $self->sigFigs() < $student->sigFigs() ? $self->sigFigs() : $student->sigFigs();
	if ($min < 1){
		return 0; # assume wrong
	}

	# This is the greatest acceptable difference in sig figs if student has FEWER 
	# sig figs than the correct answer.
	# i.e. Correct answer should be 1.609 and student puts 1.6 -> difference is 2
	#	but if student puts 2, that's a difference of 3.... too much, so the 
	# whole answer is wrong instead of just the sig figs.
	my $maxDifference = 2;

	if ($self->sigFigs() - $min > $maxDifference){
		$min = $self->sigFigs - $maxDifference;
	}
	
	# Two options: 
	# 1) Tolerance is zero, so allow calculated answer with wrong sig figs.
	#    The sig figs can be graded wrong, but the answer can be ok still.
	# 2) Tolerance is not zero, likely student is reading an analog value from 
	#    a ruler or something similar.  Can't get sig figs wrong at all.

	my $isAnswerValueGood=0;
	
	# Tolerance is useful when asking students to record an inexact value from an analog instrument (i.e. ruler).  The last digit will always vary by a little bit.
	# While a relative value of tolerance is ok, it's easier to use absolute tolerance since we know approximately how much the last digit will very.
	my $tolerance = $self->{options}{tolerance};
	my $tolType = $self->{options}{tolType};

	if ($tolerance == 0) {
		#warn 'here';
		my $transformedCorrect = $self->new($self->valueAsNumber, $min);
		#warn $transformedCorrect;
		#warn $transformedCorrect->valueAsNumber;
		#warn $transformedCorrect->valueAsRoundedNumber;
		my $transformedStudent = $self->new($student->valueAsNumber, $min);
		#warn $transformedStudent->valueAsRoundedNumber;
		if ($transformedCorrect->valueAsRoundedNumber == $transformedStudent->valueAsRoundedNumber){
			$isAnswerValueGood = 1;
		}
	} else {

		if ($tolType eq 'relative') {
			$tolerance = $correct->valueAsNumber * $tolerance * 0.01;
		}
		$correctWithTolerancePlus = $self->valueAsNumber + $tolerance;
		$correctWithToleranceMinus = $self->valueAsNumber - $tolerance;
		if ($student->valueAsNumber >= $correctWithToleranceMinus && $student->valueAsNumber <= $correctWithTolerancePlus) {
			$isAnswerValueGood = 1;
		}
	}

	# WHAT ABOUT ROUNDING ERRORS??? NEED ANOTHER CHECK FOR SLIGHT VARIATIONS... TO COME!
	if ($isAnswerValueGood == 1){
		# numbers match, now check sig figs
		$currentCredit += $creditValue;
		if ($self->sigFigs == $student->sigFigs){
			$currentCredit += $creditSF;
		} else {
			$ans->{ans_message} = "Your significant figures are not correct.";
		}
	} else {
		if ($failOnValueWrong) {
			#$ans->{ans_message} = $correct->valueAsRoundedNumber();
		} else {
			# grade sig figs amount anyways
			if ($self->sigFigs == $student->sigFigs){
				$currentCredit += $creditSF;
			#$ans->{ans_message} = "Your value is not correct, but your significant values are good.";
			} else {
			#$ans->{ans_message} = "Your value and your significant figures are both incorrect.";
			}
		}
	}
	return $currentCredit;

}

# sub cmp_parse {
#   my $self = shift; my $ans = shift;

#   my $context = $ans->{correct_value}{context} || $current;

#   my $correct = $ans->{correct_value};
#   my $student = $ans->{student_value};
#   $ans->{_filter_name} = "InexactValue answer checker";
#   $creditSF = $self->getFlag("creditSigFigs");
#   $creditValue = $self->getFlag("creditValue");
#   $failOnValueWrong = $self->getFlag("failOnValueWrong");

#   $ans->score(0); # assume failure
# }

sub clone {
		my $self = shift;
		my $copy = bless { %$self }, ref $self;
		#$register{$copy} = localtime; # Or whatever else you need to do with a new object.
		# ...
		return $copy;
}


#
#  Only match against strings and Scientific Notation
#
sub typeMatch {
	my $self = shift; my $other = shift; my $ans = shift;
	return $other->{isInexact};
}


1;
