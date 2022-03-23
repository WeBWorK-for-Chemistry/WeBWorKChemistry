loadMacros('MathObjects.pl');
loadMacros('betterUnits.pl');

#loadMacros('NumberWithUnits.pm');


our %fundamental_units = %Units::fundamental_units;
our %known_units = %Units::known_units;

sub _contextInexactValueWithUnits_init {InexactValueWithUnits::Init()};

package InexactValueWithUnits;

sub Init {
  
  # main::PG_restricted_eval('sub NumberWithUnits {Parser::Legacy::NumberWithUnits->new(@_)}');

  my $context = $main::context{InexactValueWithUnits} = Parser::Context->getCopy("Numeric");
  $context->{name} = "InexactValueWithUnits";

  #
  #  Remove all the stuff we don't need
  #
  $context->variables->clear;
  $context->constants->clear;
  $context->parens->clear;
  $context->operators->clear;
  $context->functions->clear;
  $context->strings->clear;

  #
  #  Don't reduce constant values (so 10^2 won't be replaced by 100)
  #
  $context->flags->set(reduceConstants => 0);
  #
  #  Flags controlling input and output
  #
  $context->flags->set(
    creditSigFigs => 0.25,  # credit for getting correct # of sig figs
    creditValue => 0.5,     # credit for getting correct value
    creditUnits => 0.25,     # credit for matching units
    failOnValueWrong => 1,  # ignore sig figs (and any further credit) 
                            # if value is wrong

  );

  $context->{value}{InexactValue} = 'InexactValue::InexactValue';
  $context->{value}{InexactValueWithUnits} = 'InexactValueWithUnits::InexactValueWithUnits';
  $context->{value}{"Value()"} = 'InexactValueWithUnits::InexactValueWithUnits';

# We make copies of these hashes here because these copies will be unique to  # the problem.  The hashes in Units are shared between problems.  We pass
  # the hashes for these local copies to the NumberWithUnits package to use
  # for all of its stuff.    
  Parser::Legacy::ObjectWithUnits::initializeUnits(\%fundamental_units,\%known_units);
#
  #  Create the constructor function
  #
  main::PG_restricted_eval('sub InexactValueWithUnits {Value->Package("InexactValueWithUnits")->new(@_)}');
  
}
#sub InexactValueWithUnits {Parser::Legacy::InexactValueWithUnits->new(@_)};
sub parserInexactValueWithUnits::fundamental_units {
	return \%fundamental_units;
}
sub parserInexactValueWithUnits::known_units {
	return \%known_units;
}
sub parserInexactValueWithUnits::add_unit {
    my $newUnit = shift;
	my $Units= BetterUnits::add_unit($newUnit->{name}, $newUnit->{conversion});
    return %$Units;
}

######################################################################

#
#  Customize for NumberWithUnits
#

package InexactValueWithUnits::InexactValueWithUnits;

#our @ISA = qw(Value);
our @ISA = qw(Parser::Legacy::ObjectWithUnits InexactValue::InexactValue);

sub name {'inexactValueWithUnits'};
sub cmp_class {'Inexact Value with Units'};

my $strictUnits = 1;
my $hasChemicals= 0;

sub new {
	my $self = shift; my $class = ref($self) || $self;
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
	my $num = shift;
	# we need to check if units is the options hash
	my $units = shift;
	
	my $options;

	if (ref($units) eq 'HASH') {
		$options = $units;
		$units = '';
	} else {
		$options = shift;
	}

	# this will require units to be defined in betterUnits.
	# setting to false will cause anything after the number to be added 
	# as a new unit if not recognized.
	if (defined($self->context->flags->get('strictUnits'))){
		$strictUnits = $self->context->flags->get('strictUnits');
	}

	# this is for use in chemistry so that chemical units (i.e. FeCl_3) are recognized and can be matched up with 
	# the named version (i.e. iron (III) chloride).  This avoids having the question writer to have to come up with 
	# many variations of the same unit for each question.

	# There are a few issues with having chemicals be recognizable units.  Some elements have the same symbol as a common unit. (listed)
	# hydrogen (H) and henry (H)
	# carbon (C) and coulomb (C)
	# sulfur (S) and siemens (S)
	# protactinium (Pa) and pascal (Pa)
	# nitrogen (N) and newton (N)
	# fluorine (F) and farad (F)
	# vanadium (V) and volt (V)
	# tungsten (W) and watt (W)
	# meitnerium (Mt) and megaton (Mt)
	# A possible solution is to find chemical units FIRST if $hasChemicals is true.  However, that could backfire if a chemistry problem has chemicals and Pascal units for pressure.
	# While unlikely, it's possible.  
	# Another better solution is to check for chemical units, THEN check that the first unit is a quantitative unit rather than qualitative. 
	# i.e. There never will be 1.4 carbon. If 1.4 C is written, that has to mean Coulomb.  But if 1.4 g C is written, that C is interpreted as carbon since g is quantitative.  
	# This isn't foolproof but close enough.  We'll id qualitative units by having an additional hash property in the definition.  Units need to be checked in the term section.

	if (defined($self->context->flags->get('hasChemicals'))){
		$hasChemicals = $self->context->flags->get('hasChemicals');
	}
	
	# register a new unit/s if needed
	# first from the context (global)
	if (defined($self->context->flags->get('newUnit'))){
		my $newUnit =$self->context->flags->get('newUnit');
		if (ref($newUnit) eq 'ARRAY') {
			@newUnits = @{$newUnit};
		} else {
			@newUnits = ($newUnit);
		}

		foreach my $newUnit (@newUnits) {
			if (ref($newUnit) eq 'HASH') {
				BetterUnits::add_unit($newUnit->{name}, $newUnit->{conversion});
			} elsif (ref($newUnit) eq 'ARRAY') {
				# create the unit hash manually and set it the same for all units in the array as they all mean the same thing
				@sameUnits = @{$newUnit};
				my $unitFundamentIdentical = '';
				$knownUnits = \%BetterUnits::known_units;
				foreach my $sameUnit (@sameUnits) {					
					
					if ($unitFundamentIdentical eq ''){
						$unitFundamentIdentical = $sameUnit;
					}  
					my $unitHash = {	'factor' 	=> 1,
										"$unitFundamentIdentical"     => 1 } ;
					$knownUnits->{$sameUnit} = $unitHash;
					#warn $sameUnit;
					#warn $unitHash;
					$BetterUnits::fundamental_units{$unitFundamentIdentical} = 0;
					#warn %known_units;

				}
				#warn "$_ $BetterUnits::known_units{$_}\n" for (keys %BetterUnits::known_units);
			}
			else{
				BetterUnits::add_unit($newUnit);
				#my %op = %{$options->{known_units}};
  				#warn "$_ $op{$_}\n" for (keys %op);
				#warn %fundamental_units;
			}
		}
	} 

	# %fun = $BetterUnits::known_units;
    #   warn "$_ $fun{$_}\n" for (keys %fun);
	# #second from the value
	# if (defined($options->{newUnit})) {
	# 	my @newUnits;
	# 	if (ref($options->{newUnit}) eq 'ARRAY') {
	# 		@newUnits = @{$options->{newUnit}};
	# 	} else {
	# 		@newUnits = ($options->{newUnit});
	# 	}

	# 	foreach my $newUnit (@newUnits) {
	# 		if (ref($newUnit) eq 'HASH') {
	# 			$self->add_unit($newUnit->{name}, $newUnit->{conversion});
	# 		} else {
	# 			$self->add_unit($newUnit);
	# 		}
	# 	}
	# }
	Value::Error("You must provide a ".$self->name) unless defined($num);
	
	if (ref $num eq "ARRAY"){
		my $t = join( ',', @$num );;
		#warn "Array: $t";
	} else {
		#warn "Value: $num";		
	}
	if (ref $num eq "ARRAY") {
		#warn "From Array: $units";
	} else {
		(my $tempnum,$units) = splitUnits($num) unless $units;
		if (defined $tempnum){
			$num = $tempnum;
		}
		#warn "From Value: $units";
	}
	
	# check that units are valid
	if ($strictUnits){

	}
	
	#warn "Trying to make:  $num";

	#Value::Error("You must provide units for your ".$self->name) unless $units;
	if ($units){
		Value::Error("Your units can only contain one division") if $units =~ m!/.*/!;
	}
	#@temp = @$num;
	#$temp0 = $temp[0];
	#$temp1 = $temp[1];
	#warn "Trying to make:  $temp0 $temp1";
	$num = $self->makeValue($num,context=>$context);
	#warn "result is $num";

	# store a copy of fundamental units on self
	$num->{fundamental_units} = \%fundamental_units;
	$num->{known_units} = {};

	# register a new unit/s if needed
	# first from the context (global)
	# if (defined($self->context->flags->get('newUnit'))){

	# 	my $newUnit =$self->context->flags->get('newUnit');
	# 	if (ref($newUnit) eq 'ARRAY') {
	# 		@newUnits = @{$newUnit};
	# 	} else {
	# 		@newUnits = ($newUnit);
	# 	}

	# 	foreach my $newUnit (@newUnits) {
	# 		if (ref($newUnit) eq 'HASH') {
	# 			$self->add_unit($num, $newUnit->{name}, $newUnit->{conversion});
				
	# 		} elsif (ref($newUnit) eq 'ARRAY') {
	# 			# create the unit hash manually and set it the same for all units in the array as they all mean the same thing
	# 			@sameUnits = @{$newUnit};
	# 			my $unitFundamentIdentical = '';
	# 			foreach my $sameUnit (@sameUnits) {
	# 				if ($unitFundamentIdentical eq ''){
	# 					$unitFundamentIdentical = $sameUnit;
	# 				} 
	# 				my $unitHash = {	'factor' 	=> 1,
	# 									"$unitFundamentIdentical"     => 1 } ;
					 
	# 				$self->add_unit($num, $sameUnit, $unitHash);
	# 				#$BetterUnits::fundamental_units{$unitFundamentIdentical} = 0;
	# 				#warn %known_units;

	# 			}
	# 			#warn "$_ $BetterUnits::known_units{$_}\n" for (keys %BetterUnits::known_units);
	# 		} else {
	# 			$self->add_unit($num, $newUnit);
	# 		}
	# 	}
	# } 
	
	
#warn "$units WTH" ;

	my %Units = $units ? getUnits($units) : %fundamental_units;
	#warn %Units;

	#warn "$_ $Units{$_}\n" for (keys %Units);
	#quick loop to remove fundamental units that are zero
	@keys = (keys %Units);
	for ($i=scalar @keys -1;$i>=0; $i--){
		#warn $Units{$keys[$i]};
		if ($Units{$keys[$i]} == 0){
			delete $Units{$keys[$i]};
		}
	}
	# warn $num;
	# warn %Units;

	#warn "Trying to make:  ${Units{s}}";
	Value::Error($Units{ERROR}) if ($Units{ERROR});
	# make a copy of the inexact value to do comparisons with

	my $refcopy = $num->copy; 
	#warn $refcopy;
	$num->{inexactValue} = $refcopy;
	$num->{units} = defined $units ? $units : '';
	$num->{units_ref} = \%Units;
	$num->{isValue} = 1;
	$num->{correct_ans} .= ' '.$units if defined $num->{correct_ans};
	
	#$test = Parser::Legacy::ObjectWithUnits::TeXunits($units);
	#warn "$test";
	$num->{correct_ans_latex_string} .= ' '. Parser::Legacy::ObjectWithUnits::TeXunits($units) if defined $num->{correct_ans_latex_string};
	bless $num, $class;

	$num->{precedence}{'InexactValueWithUnits'} = 4;
	return $num;
}

# copied from Units.pm
sub getUnits {
  my $units = shift;
  my $options = {};
  if ($fundamental_units) {
    $options->{fundamental_units} = $fundamental_units;
  }
  if ($known_units) {
    $options->{known_units} = $known_units;
  }
  if ($hasChemicals){
	  $options->{hasChemicals} = 1;
  }

  my %Units = BetterUnits::evaluate_units($units,$options);
  if ($Units{ERROR}) {
    $Units{ERROR} =~ s/ at ([^ ]+) line \d+(\n|.)*//;
    $Units{ERROR} =~ s/^UNIT ERROR:? *//;
  }
  return %Units;
}

# borrowed from NumberWithUnits.pm
sub add_fundamental_unit {
  my $self = shift;
  my $num = shift;
  my $unit = shift;
  $num->{fundamental_units}->{$unit} = 0;
	#warn $fundamental_units;
}

# borrowed from NumberWithUnits.pm
sub add_unit {
  my $self = shift;
  my $num = shift;
  my $unit = shift;
  my $hash = shift;
  
  unless (ref($hash) eq 'HASH') {
    $hash = {'factor'    => 1,
	     "$unit"     => 1 };
  }

  # make sure that if this unit is defined in terms of any other units
  # then those units are fundamental units.  
  foreach my $subUnit (keys %$hash) {
    if (!defined($num->{fundamental_units}->{$subUnit})) {
      $self->add_fundamental_unit($num, $subUnit);
    }
  }

  $num->{known_units}->{$unit} = $hash;

}

sub getUnitNames {

  my $units = \%BetterUnits::known_units;
   #warn %$units;
   my @keys = keys(%$units);
   my $compare = sub { 
	   return length($_[1]) < length($_[0]) if length($_[0]) != length($_[1]); 
	   my $cmp = $_[0] cmp $_[1];
	   if ($cmp == 1) {
		   return 0;
	   } else {
		   return 1;
	   }
	   };
	my $result2 = join('|', main::PGsort( $compare,@keys));
	return $result2;
}


sub splitUnits {
	#my $unitNames = getUnitNames();
	#my $aUnit = '(?:'.getPrefixNames().')?(?:'.$unitNames.')(?:\s*(?:\^|\*\*)\s*[-+]?\d+)?';
	#my $unitPattern = $aUnit.'(?:\s*[/* ]\s*'.$aUnit.')*';
	#my $unitSpace = "($aUnit) +($aUnit)";
	my $string = shift;

	
	# This seems to handle when user inputs latex mu value "\mu" in place of simple 'u'.  i.e. \mu m instead of um for micrometers
	# Also, automatically converts 'u' prefix to the more accurate 'μ' prefix (which is harder to type)
	#warn "$string";
	#$string =~ s/(\\mu\s?|u)(?=$unitNames)/μ/;  # replace \mu, \mu with space, or u with: μ
	#warn "$string";
	#my ($num,$units) = $string =~ m!^(.*?(?:[)}\]0-9a-z]|\d\.))\s*($unitPattern)\s*$!;
	#my $regex = qr/^(\d*?[\.,]?\d*?(?:e|\s?[x|\*]\s?10\^)[+-]?\d*|\d*[\.,]?\d*)(.*)$/mp;

	if ($string =~ /(\d+?[\.]?\d*?(?:e|\s?[x|\*]\s?10\^)[+-]?\d+|\d*[\.]\d*|\d*)(.*)/g){
		#warn $1;
		#warn $2;
		$val = $1;
		$units = $2;
	}
	#warn "Going to match: >$string<";
	#warn "$num2";
	
	#warn "units: $units" if $units;
	#warn "unitless: $string[0]" unless $units;
	if ($units) {
		#while ($units =~ s/$unitSpace/$1*$2/) {};
		#$units =~ s/ //g;  # Why did I remove spaces here?  this conflicts with units like "fl oz" which have a space.  I don't want to force having a '-' dash between them yet.
							# This might break something else, but we'll remove it for now.						
		$units =~ s/\*\*/^/g; #replace Perl exponent notation (**) with standard computer caret notation (^)
	}
	#warn "$units";
	return ($val,$units);
}

sub getPrefixNames {
	my $a;
	my $b;
	my $prefixes = \%BetterUnits::prefixes;
	my @prefixArray = keys %$prefixes;
	my @sortedArray = main::PGsort(sub {
		return length($_[1]) > length($_[0]) if length($_[0]) != length($_[1]);
		return ($_[0] cmp $_[1]) > 0 ;
	}, @prefixArray);
	my $joined = join('|', @sortedArray);
	return $joined;
}

sub make {
	my $self = shift;
	
	return $self;
 }

sub makeValue {
	my $self = shift; my $value = shift;
	
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
	if (ref($value) eq ARRAY){
		# this is the case when we want to pass a value with explicit sig figs
		@arr = @$value;
		return Value->Package("InexactValue")->new($arr[0], $arr[1]);
	} else {
		return Value->Package("InexactValue")->new($value);
	}
}

# sub checkStudentValue {
#   my $self = shift; my $student = shift;
#   return 1;
# }

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
    $inexactWithUnitsStudent=0;
    $studentAnswer = $ans->{student_ans};
    if ($ans->{student_ans} eq ''){
      $inexactWithUnitsStudent = $self->new([0,9**9**9],'');  #blank answer is zero with infinite sf
      } else {
      $inexactWithUnitsStudent = $self->new($ans->{student_ans});
    }
	$ans->{student_value} = $inexactWithUnitsStudent;
	$ans->{preview_latex_string} = $inexactWithUnitsStudent->TeX;#$inexactStudent->TeX;# "\\begin{array}{l}\\text{".join("}\\\\\\text{",'@student')."}\\end{array}";
    $ans->{student_ans} = $inexactWithUnitsStudent->string; #$inexactStudent->string; 

    return $ans;
  });

  # REMINDER:  Evaluator should JUST be for equality
  #           if you need messages for why it's wrong, that MUST go in post-filter
  #           the reason for this is that MultiAnswer will stop evaluating if there is a message after the individual evaluation
  
  return $cmp;
}

sub cmp_parse {
	my $self = shift; my $ans = shift;

	$studentAnswer = $ans->{student_ans};
	
	if ($ans->{student_ans} eq ''){
		$inexactWithUnitsStudent = $self->new([0,9**9**9],'');  #blank answer is zero with infinite sf
	} else {
		$inexactWithUnitsStudent = $self->new($ans->{student_ans});
	}
	$ans->{student_value} = $inexactWithUnitsStudent;
	$ans->{preview_latex_string} = $inexactWithUnitsStudent->TeX; #$inexactStudent->TeX;# "\\begin{array}{l}\\text{".join("}\\\\\\text{",'@student')."}\\end{array}";
	$ans->{student_ans} = $inexactWithUnitsStudent->string; #$inexactStudent->string; 

	my $correct = $ans->{correct_value};
	my $student = $ans->{student_value};
	$ans->{_filter_name} = "InexactValueWithUnits answer checker";
	$creditSF = $self->getFlag("creditSigFigs");
	$penaltyRoundingError = $self->getFlag("penaltyRoundingError");
	$creditValue = $self->getFlag("creditValue");
	$creditUnits = $self->getFlag("creditUnits");
	$failOnValueWrong = $self->getFlag("failOnValueWrong");

	$ans->score(0); # assume failure
	$self->context->clearError();

	$currentCredit = 0;
	
	my $result = $correct->compareValuesWithUnits(
		$student,
		{
			"creditSigFigs"=>$creditSF,
			"penaltyRoundingError"=>$penaltyRoundingError,
			"creditValue"=>$creditValue,
			"creditUnits"=>$creditUnits,
			"failOnValueWrong"=>$failOnValueWrong
		});
	
	my @resultArr = @$result;
	$currentCredit = shift @resultArr;
	$message = shift @resultArr;

	$ans->score($currentCredit);

	return $ans;
}

sub compareValuesWithUnits {
	my $self = shift;
	my $student = shift;
	my $options = shift;

	my $roundingErrorPossibles = $options->{"roundingErrorPossibles"};
	my $penaltyRoundingError = $options->{"penaltyRoundingError"};
	my $creditSF = $options->{"creditSigFigs"};	
	my $creditValue = $options->{"creditValue"};
	my $creditUnits = $options->{"creditUnits"};
	my $failOnValueWrong = $options->{"failOnValueWrong"};
	my $currentCredit = 0;
	my $message = '';
	
	if ($self->{inexactValue}->valueAsRoundedNumber() == $student->{inexactValue}->valueAsRoundedNumber()) {
		# numbers match, now check sig figs
		$currentCredit += $creditValue;
		
	} else {
		# use the possible rounding error calculations to compute an "acceptable" range for potential student answers
		if (defined $roundingErrorPossibles) {
			my @possibles = @$roundingErrorPossibles;
			# take the last one for now.
			my $lastPossible = pop @possibles;
			my $range = abs ($lastPossible->{inexactValue}->valueAsRoundedNumber() - $self->{inexactValue}->valueAsRoundedNumber());
			my $min = $self->{inexactValue}->valueAsRoundedNumber() - $range;
			my $max = $self->{inexactValue}->valueAsRoundedNumber() + $range;
			if ($student->{inexactValue}->valueAsRoundedNumber() < $max && $student->{inexactValue}->valueAsRoundedNumber() > $min) {
				# within rounding error range!
				$message .= "Your answer probably has rounding errors.  ";
				$currentCredit += $creditValue;
				if (defined $penaltyRoundingError){
					$currentCredit -= $penaltyRoundingError;
				}
			} else {
				# not within range, failed value!
				if ($failOnValueWrong){
					$message .= "Your answer is incorrect.  ";
					return [$currentCredit, $message];
				}
			}
		} else {
			# not within range, failed value!
			if ($failOnValueWrong){
				$message .= "Your answer is incorrect.  ";
				return [$currentCredit, $message];
			}
		}
	}
	# if we haven't returned yet, then we check sig figs and units
	
	# grade sig figs amount anyways 
	# CAUTION!  If correct answer is exact, then disregard sig figs because students have no way to force system to recognize an 'exact' value.  
	# Exact values are ver context-dependent.
	if ($self->sigFigs() == Inf || $self->sigFigs() == $student->sigFigs()){
		$currentCredit += $creditSF;
	} else {
		$message  .= "Incorrect sig figs.  ";
	}
	# grade units!          
	warn "GRADING $self and $student";
	if (compareUnitHash($self->{units_ref}, $student->{units_ref} )){
		$currentCredit += $creditUnits;
	} else {
		$message .= "Incorrect units.  ";
	}
	warn $self;
	warn %{$self->{units_ref}};
	warn $student;
	warn %{$student->{units_ref}};
	warn "credit: $currentCredit  $message";
	
	
	return [$currentCredit, $message];
}

sub string {
  my $self = shift;
  #return $self;
  #   $val = $self->value;
  # $sigs = $self->sigFigs;
  # $cla = ref($self);
  # warn "Value is $val";
  # warn "SigFigs are $sigs";
  # warn "Class is $cla";
  # warn ref($self);
  if (defined $self->{units}){
    return InexactValue::InexactValue::string($self) . ' ' . $self->{units};
  } else {
    return InexactValue::InexactValue::string($self);
  }
}

sub TeX {
  my $self = shift;
  #$n = InexactValue::InexactValue::string($self);
  $n = $self->{inexactValue};
  #warn "$n";
  $n =~ s/(?:E|x10\^)\+?(-?)0*([^)]*?)$/\\times 10^{$1$2}/gi; # convert E notation to x10^(...)
  #warn "$n";
	
  return $n . '\ ' . TeXunits($self->{units});
}

# Adapted from NumberWithUnits.pm original which fails to add spaces in units that have a space.
# also display micro 'u' as the greek mu.
#  Convert units to TeX format
#  (fix superscripts, put terms in \rm,
#   escape percent,
#   and make a \frac out of fractions)
#
sub TeXunits {
  my $units = shift;
  $units =~ s/\^\(?([-+]?\d+)\)?/^{$1}/g; # fixes exponents
  $units =~ s/\*/\\,/g; 
  $units =~ s/%/\\%/g;
  $units =~ s/μ/\\mu /g;
  $units =~ s/ /\\,/g;  # example: adds space between 'fl oz'
  return '{\rm '.$units.'}' unless $units =~ m!^(.*)/(.*)$!;
  my $displayMode = $main::displayMode;
  return '{\textstyle\frac{'.$1.'}{'.$2.'}}' if ($displayMode eq 'HTML_tth');
  return '{\textstyle\frac{\rm\mathstrut '.$1.'}{\rm\mathstrut '.$2.'}}';
}


sub convertTo {
	my $self = shift;
	my $unitFrom = $self->{units};
	my $unitTo = shift;

	$region = 'us';
	if ($self->context->flags->get('unitRegion') eq 'uk'){
		$region = 'uk';
	}
	unless (defined $self->{units}){
		Value::Error("The value provided doesn't contain any units so cannot be converted.");
	}

	my $multiplier = BetterUnits::convertUnit($unitFrom,$unitTo, {region=> $region});
	$t2 = $self->{inexactValue} * $multiplier;
	$t = $self->new([$t2->value, $t2->sigFigs], $unitTo);
	return $t;
}


sub add {
  my ($self,$l,$r,$other) = InexactValueWithUnits::InexactValueWithUnits::checkOpOrderWithPromote(@_);
  $leftPos = $l->leastSignificantPosition();    
  $rightPos = $r->leastSignificantPosition();
  $leftMostPosition = $self->basicMin($leftPos, $rightPos);
  $newValue = $l->valueAsNumber() + $r->valueAsNumber();
  $newSigFigs = $self->calculateSigFigsForPosition($newValue, $leftMostPosition);
  #my $num = Value->Package("InexactValue")->new($newValue, $newSigFigs);
  #Value::Error("error is $units");
  return $self->new([$newValue, $newSigFigs], $self->{units});
}

sub sub {
  my ($self,$l,$r,$other) = InexactValueWithUnits::InexactValueWithUnits::checkOpOrderWithPromote(@_);
  $leftPos = $l->leastSignificantPosition();
  $rightPos = $r->leastSignificantPosition();
  $leftMostPosition = $self->basicMin($leftPos, $rightPos);
  $newValue = $l->valueAsNumber() - $r->valueAsNumber();
  $newSigFigs = $self->calculateSigFigsForPosition($newValue, $leftMostPosition);
  #my $num = Value->Package("InexactValue")->new($newValue, $newSigFigs);
  #Value::Error("error is $units");
  return $self->new([$newValue, $newSigFigs], $self->{units});
}

sub mergeUnits {
	my $self = shift;
	my $leftOptions = shift;
	my $rightOptions = shift;

	my $leftKnown = $leftOptions->{known_units};
	my $rightKnown = $rightOptions->{known_units};
	my $mainKnown = \%BetterUnits::known_units;
	
	my $leftFundamental = $leftOptions->{fundamental_units};
	my $rightFundamental = $rightOptions->{fundamental_units};
	
	foreach my $subUnit (keys %$rightKnown) {
		if (!defined($leftFundamental->{$subUnit})) {
			$leftFundamental->{$subUnit} = 0;
		}

		if (!defined($mainKnown->{$subUnit})) {
  			$mainKnown->{$subUnit} = $rightKnown->{$subUnit};
		}
  	}
	foreach my $subUnit (keys %$leftKnown) {
		if (!defined($mainKnown->{$subUnit})) {
  			$mainKnown->{$subUnit} = $leftKnown->{$subUnit};
		}
	}


	my $options = {known_units=>$mainKnown, fundamental_units=>$leftFundamental};
	return $options;
}

sub mult {
	my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
	my $newInexact = $left->{inexactValue} * $right->{inexactValue};

	# merge additional units with standard units
	my $newOptions = $self->mergeUnits($left,$right); 
	
	if (defined $left->{context}->flags->get('hasChemicals')){
	  $newOptions->{hasChemicals} = $left->{context}->flags->get('hasChemicals');
	} 
	#warn "BEFORE " . $left->{units} . " WITH " . $right->{units};
	$newUnitString = combineStringUnitsCleanly($left->{units}, $right->{units}, 1, $newOptions);
	#warn "AFTER MULTIPLY $newUnitString";
	$result = $self->new([$newInexact->valueAsNumber, $newInexact->sigFigs], $newUnitString);
	
	return $result;
}

sub div {
  my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
  #Value::Error("Division by zero") if $r->{data}[0] == 0;
  #$minSf = $left->minSf($left, $right);
  my $newInexact = $left->{inexactValue} / $right->{inexactValue};

  # merge additional units with standard units
  my $newOptions = $self->mergeUnits($left,$right);
	
  if (defined $left->{context}->flags->get('hasChemicals')){
	$newOptions->{hasChemicals} = $left->{context}->flags->get('hasChemicals');
  } 
    
  $newUnitString = combineStringUnitsCleanly($left->{units}, $right->{units}, 0, $newOptions);
  
  $result = $self->new([$newInexact->valueAsNumber, $newInexact->sigFigs], $newUnitString);
  
  return $result;
}

sub combineStringUnitsCleanly {
  my $left = shift;
  my $right = shift;
  my $isMultiply= shift;
  my $options = shift;

  if ($hasChemicals){
	  #warn "HAS CHEMICALS!!!!";
	  $options->{hasChemicals} = 1;
  }

  my @unitArrayLeft = process_unit_for_stringCombine($left, $options);
  my @unitArrayRight = process_unit_for_stringCombine($right, $options);

  my $newUnitString = '';
  my @numerator;
  my @denominator;

  $debug='';
  foreach $key (@unitArrayLeft) {
    $debug = $debug . $key; #"$key => $unitArrayLeft{$key}\n";
  }
  
  # need to see if any units on the right match units on the left.
  # the tricky part is that ft won't match foot by name, so we need to compare what they're made of
  # if they're the same, we'll take the name that occurs left in the list.
  my @usedR = ();
  for ($l=0; $l < scalar(@unitArrayLeft); $l++ ) {
    $leftMatch=0;
    for ($r=0; $r < scalar(@unitArrayRight); $r++) {

      if (compareUnitHash(@unitArrayLeft[$l]->{unitHash},@unitArrayRight[$r]->{unitHash})){
        
        $leftMatch = 1;
        push @usedR, $r;
        # same units on both sides!
        # now combine them
        my $power=0;
        if ($isMultiply){
          $power = $unitArrayLeft[$l]->{power} + $unitArrayRight[$r]->{power};
        } else{
          $power = $unitArrayLeft[$l]->{power} - $unitArrayRight[$r]->{power};
        }
        if ($power != 0){
          my %newUnitHash = %{$unitArrayLeft[$l]};
          if ($power > 0){
            $newUnitHash{power} = $power;
            push @numerator, \%newUnitHash;
          } else {
            $newUnitHash{power} = $power * -1;  #change it back to positive
            push @denominator, \%newUnitHash;
          }
        }
      }
    }
    if ($leftMatch==0){
      #no match for left unit, just put it into the new unit
      my %newUnitHash = %{$unitArrayLeft[$l]};
      if (%newUnitHash{power} > 0){
        push @numerator, \%newUnitHash;
      } else {
        $newUnitHash{power} = %newUnitHash{power} * -1;  #change it back to positive
        push @denominator, \%newUnitHash;
      }
    }
  }
  # now that we've scanned for similar units and combined those, any unused units from the right go into the new unit
  for ($r=0;$r < scalar @unitArrayRight; $r++){
    if (scalar (@usedR) == 0 || $usedR[0] != $r ){
      #no match for right unit, so put it into the new unit

      my %newUnitHash = %{$unitArrayRight[$r]};
	  
      if (%newUnitHash{power} > 0){
        if ($isMultiply){
          push @numerator, \%newUnitHash;
        } else {
          push @denominator, \%newUnitHash;
        }
      } else {        
        $newUnitHash{power} = %newUnitHash{power} * -1;  #change it back to positive
        if ($isMultiply){
          push @denominator, \%newUnitHash;
        } else {
          push @numerator, \%newUnitHash;
        }
      }
    }else {
      shift @usedR;
    }
  } 

  for (local $a=0;$a< scalar(@numerator); $a++){
    if ($a > 0){
      $newUnitString = $newUnitString . '*';
    }
    $newUnitString = $newUnitString . $numerator[$a]->{name} . ($numerator[$a]->{power} == 1 ? '' : "^${numerator[$a]->{power}}");
  }
  if (scalar @denominator > 0){
    $newUnitString =  $newUnitString . '/';
  }
  for (local $a=0;$a< scalar(@denominator); $a++){
    if ($a > 0){
      $newUnitString = $newUnitString . '*';
    }
    $newUnitString = $newUnitString . $denominator[$a]->{name} . ($denominator[$a]->{power} == 1 ? '' : "^${denominator[$a]->{power}}");
  }

  return $newUnitString;
}

# We use this to compare two unit hashes to test for equality.  Can't compare references.
sub compareUnitHash {
  my $leftref = shift;
  #my %left = %{$leftref->{unitHash}};
  my %left = %$leftref;
  my $rightref = shift;
  #my %right = %$rightref->{unitHash}};
  my %right = %$rightref;

  
  # from https://stackoverflow.com/questions/1273616/how-do-i-compare-two-hashes-in-perl-without-using-datacompare
  # same number of keys?
  if (%left != %right) {
    # warn 'not equal not correct';
	# should never be called unless error in code
	#warn "LEFT: " . join(',',%left);
	#warn "RIGHT: " . join(',',%right);
	#warn "not equal at all";
    return 0;
  } else {
    my %cmp = map { $_ => 1 } keys %left;
    for my $key (keys %right) {
      last unless exists $cmp{$key};
      last unless $left{$key} eq $right{$key};
      delete $cmp{$key};
    }
    if (%cmp) {
	  #warn "LEFT: " . join(',',%left);
	  #warn "RIGHT: " . join(',',%right);
      #warn "LEFTOVER: " . join(',',%cmp);
      #warn 'was not correct';
      return 0;
    } else {
      my %cmp = map { $_ => 1 } keys %right;
	  for my $key (keys %left) {
		last unless exists $cmp{$key};
		last unless $left{$key} eq $right{$key};
		delete $cmp{$key};
	  }  
	  if (%cmp){
		#warn "LEFT: " . join(',',%left);
		#warn "RIGHT: " . join(',',%right);
		#warn "LEFTOVER: " . join(',',%cmp);
		#warn 'was not correct';
		return 0;
	  } else {
		#warn "LEFT: " . join(',',%left);
		#warn "RIGHT: " . join(',',%right);
		#warn "Correct";
      	return 1;
	  }
    }
  }
}

# This will create an array that contains the string value of the unit, the found "known" unit hash,
# and the power of the unit adjusted negative if it's in the denominator.
# These will be used to create new units when doing multiplication and division.  
sub process_unit_for_stringCombine {
  my $string = shift;

  my $options = shift;

  my $fundamental_units = \%BetterUnits::fundamental_units;
  my $known_units = \%BetterUnits::known_units;
    
  if (defined($options->{fundamental_units})) {
    $fundamental_units = $options->{fundamental_units};
  } else {
    $options->{fundamental_units} = $fundamental_units;
  }

  if (defined($options->{known_units})) {
    $known_units = $options->{known_units};
  } else {
    $options->{known_units} = $known_units;
  }
  
  die ("UNIT ERROR: No units were defined.") unless defined($string);  #
	#split the string into numerator and denominator --- the separator is /
  my ($numerator,$denominator) = split( m{/}, $string );

  $denominator = "" unless defined($denominator);
  my @numerator_array = process_term_for_stringCombine($numerator, 1, $options);
  my @denominator_array =  process_term_for_stringCombine($denominator, 0, $options);

  push @numerator_array, @denominator_array;
  return @numerator_array;
}

# returns an array of hashes with properties: unitHash (hash containing fundamentals), name (string), power (number)
sub process_term_for_stringCombine {
	my $string = shift;
	my $isNumerator = shift;
	my $options = shift;
	
	my $fundamental_units = \%BetterUnits::fundamental_units;
	my $known_units = \%BetterUnits::known_units;
	
	if (defined($options->{fundamental_units})) {
		$fundamental_units = $options->{fundamental_units};
	} else {
		$options->{fundamental_units} = $fundamental_units;
	}

	if (defined($options->{known_units})) {
	  $known_units = $options->{known_units};
	} else {
    	$options->{known_units} = $known_units;
  	}
	
  	my @known_unit_hash_array = ();
	#my %unit_hash = %$fundamental_units;
	if ($string) {

		

		# Split the numerator or denominator into factors -- the separators are * and blank space (assuming it's not part of a known unit)
		# The system will always use * for separating terms.  i.e. after multiplying two numbers with units an asterix is used to separate the terms
		# A user might use space though... but space is more complicated as it's used inside units too.  Keep these two processes separate.  Check 
		# for special cases (i.e. chemicals) after separating using asterisk, but BEFORE splitting on spaces.
		my @factors = split(/\*/, $string);

		my $f;
		foreach $f (@factors) {

			if ($options->{hasChemicals}){
				if (!defined &Chemical::Chemical::new){
						die "You need to load contextChemical.pl if you want to use chemicals as units.";
				}
				my $chemical = Chemical::Chemical->new($f);
				if (defined $chemical && scalar @{$chemical->{data}} > 0){
					$power = 1; # reset power to 1 since it might have picked up a chemical charge as the power.
					$unit_prefix = '';  # remove any prefix parsed before.
					$unit_base = $chemical->guid();
					
					# now check if the $unit_base is in the list before adding it.  Since there are many variations of chemical names, we can only check against a post-processed name.
					unless ($known_units->{$unit_base}){
						#warn "add unit $unit_base";
						BetterUnits::add_unit($unit_base);
					}
					#warn "special process $f";
					my %fundamental_units_for_chemical = %BetterUnits::fundamental_units; #make copy of base unit hash
					#warn %$fundamental_units_for_chemical;
					$fundamental_units_for_chemical{$unit_base} = 1;
					#warn %fundamental_units_for_chemical;
					#warn "isNumerator: $isNumerator";
					my %unit_name_hash = (name=> $unit_base, unitHash => \%fundamental_units_for_chemical, power=>1);   # $reference_units contains all of the known units.
		
					#warn %unit_name_hash;
					push @known_unit_hash_array, \%unit_name_hash;
					#warn "chem: $unit_base";
					$f = '';
					if (defined $chemical->{leading}){
						$f = $chemical->{leading};
						#warn "leading has $f";
					}
				}
			}


			# here we should check to see if there are any unknown units combined with spaces
			# i.e. "mol Fe2+" will fail in process_factor subroutine because it is two units, not one.
			# The trick is to not split units that are technically one (like fluid ounce).  
			# Adding a dash is fine, but if a user adds a custom unit with spaces, we want to honor it.
			my @unitsNameArray = keys %$known_units;
			@unitsNameArray = grep(/\s/, @unitsNameArray);
			my $unitsJoined = join '|', @unitsNameArray;
			my @splitUnits = ( $f =~ m/($unitsJoined|\S+)/g );
			
			foreach $f (@splitUnits) {

				my %factor_hash = process_factor_for_stringCombine($f,$isNumerator, $options);

				push @known_unit_hash_array, \%factor_hash;
			}
		}
	}
	#returns a unit hash.
	
	return @known_unit_hash_array;
}

sub process_factor_for_stringCombine {
	my $string = shift;
	my $isNumerator = shift;
	#split the factor into unit and powers

	my $options = shift;

	my $fundamental_units = \%BetterUnits::fundamental_units;
	my $known_units = \%BetterUnits::known_units;
	my $prefixes = \%BetterUnits::prefixes;
	
	if (defined($options->{fundamental_units})) {
		$fundamental_units = $options->{fundamental_units};
	} else {
		$options->{fundamental_units} = $fundamental_units;
	}

	if (defined($options->{known_units})) {
		$known_units = $options->{known_units};
	} else {
    	$options->{known_units} = $known_units;
  	}

	# %op = %$known_units;
	# warn $known_units;
	# warn "$_ $op{$_}\n" for (keys %op);
	my ($unit_name,$power) = split(/\^/, $string);
	my @unitsNameArray = keys %$known_units;
	my $unitsJoined = join '|', @unitsNameArray;
	
	my $unit_base;
	my $unit_prefix;
	$power = 1 unless defined($power);
	
	
	#unless ( defined($unit_base) && defined( $known_units->{$unit_base} )  ) {
		($unit_base) = $unit_name =~ /($unitsJoined)$/;
		$unit_prefix = $unit_name =~ s/\s*($unitsJoined)\s*$//r;
		$unit_prefix =~ s/\s//;
		#warn $unitsJoined;
		#warn "NAME: $string";
		#warn "Unit Base: $unit_base";
		# warn "Unit Prefix: " .$unit_prefix;
	#}

	unless (defined($unit_base)){
		# if not-strict mode, register this unit as a new unit with its own fundamentals
		#warn "add unit $unit_name";
		
		BetterUnits::add_unit($unit_name);
		$unit_base = $unit_name;
		$unit_prefix = '';
		#warn "unknown $unit_base";
		#die "UNIT ERROR Unrecognizable unit: |$unit_base|";
	}
	
	$prefixExponent = 0;
	# warn "prefix exponent: ".$prefixExponent;
	if ( defined($unit_prefix) && $unit_prefix ne '') {
			if (exists($prefixes->{$unit_prefix})){
			$prefixExponent = $prefixes->{$unit_prefix}->{'exponent'};
		} else {
			warn "Unit Prefix unrecognizable: $unit_prefix";
		}
	}
	unless ($isNumerator) {
		$power = $power * -1;
	}
	
	my $unit_hash_ref = $known_units->{$unit_base};
	my %unit_hash = %$unit_hash_ref;

	my $u;
	foreach $u (keys %unit_hash) {
		if ( $u eq 'factor' ) {
			# only need to modify the factor by the prefix, not the power.
			# We do this so we can cancel the powers out without having to worry about undoing the underlying hash.
			# The underlying hash is just used to recognize the unit.  We can match foot with ft via the hash.
			$unit_hash{$u} = ($unit_hash{$u}*(10**$prefixExponent));  # calculate the correction factor for the unit
		}
	}
	#quick loop to remove fundamental units that are zero
	@keys = (keys %unit_hash);
	for ($i=scalar @keys -1;$i>=0; $i--){
		#warn 'searching '.$keys[$i] . ':  '.%unit_hash{$keys[$i]};
		if ($unit_hash{$keys[$i]} == 0){
		#	warn 'got one';
			delete $unit_hash{$keys[$i]};
		}
	}

	my %unit_name_hash = (name=> $unit_prefix.$unit_base, unitHash => \%unit_hash, power=>$power);   # $reference_units contains all of the known units.
	#warn %unit_name_hash;
	return %unit_name_hash;
	
	# } else {
	# 	die "UNIT ERROR Unrecognizable unit: |$unit_base|";
	# }
	#return @known_unit_hash_array;
}

sub checkOpOrderWithPromote {
  my ($l,$r,$flag) = @_; $r = $l->promote($r);
  if ($flag) {return ($l,$r,$l,$r)} else {return ($l,$l,$r,$r)}
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


# package UnitsMath;
# @ISA = qw(Units);


1;
