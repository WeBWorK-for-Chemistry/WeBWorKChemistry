loadMacros('MathObjects.pl');
loadMacros('betterUnits.pl');

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

#   $context->operators->add(
#      '<'  => {precedence => .5, associativity => 'left', type => 'bin', string => ' < ',
#               class => 'InexactValueWithUnits::InexactValueWithUnits', eval => 'evalLessThan', combine => 1, perl => '<'},

#      '>'  => {precedence => .5, associativity => 'left', type => 'bin', string => ' > ',
#               class => 'InexactValueWithUnits::InexactValueWithUnits', eval => 'evalGreaterThan', combine => 1, perl => '>'}
#   );

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

our $unitTranslation = {};

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
					$BetterUnits::fundamental_units{$unitFundamentIdentical} = 0;
				}
			}
			else{
				BetterUnits::add_unit($newUnit);

			}
		}
	} 


	Value::Error("You must provide a ".$self->name) unless defined($num);

	unless (ref $num eq "ARRAY") {
		(my $tempnum,$units) = splitUnits($num) unless $units;
		
		if (defined $tempnum){
			$num = $tempnum;
		}
		#warn "From Value: $units";
	}
	
	# check that units are valid
	if ($strictUnits){

	}

	if ($units){
		Value::Error("Your units can only contain one division") if $units =~ m!/.*/!;
	}

	$num = $self->makeValue($num,context=>$context);

	# store a copy of fundamental units on self
	$num->{fundamental_units} = \%fundamental_units;
	$num->{known_units} = {};

	my %Units = $units ? getUnits($units) : %fundamental_units;

	#warn %Units;

	# This is a hack to get proper formating for chemicals as units.  Since units are stored in plain text (not as Chemical objects), we need
	# to get their proper formats when the unit parsing is done.  Since that only returns a unit_hash, we're piggybacking on that and removing it
	# when present.
	if (exists $Units{piggybackUnit}){
		$piggybackUnit = $Units{piggybackUnit};
		delete $Units{piggybackUnit};

		foreach my $k (keys %$piggybackUnit){
			#warn %{ $piggybackUnit->{$k}};
			$unitTranslation{$k} = $piggybackUnit->{$k};

			#warn %{ $unitTranslation{$k}};
		}
	}

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
	# check if chemicals among them
	
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

	# this has all the groups 
	#  ^((?:10\^[+\-]?\d+)|(?:[+\-]?(\d*)(\.?)(\d*)(?:(?:e|E|(?:\s*?(?:X|x|\*)\s*?10\^))([+\-]?)(\d*))?))(.*)$

	# original one that broke with 10^4 cm
	#  ((?:10\^[+-]?\d+)|(?:\d+?[\.]?\d*?(?:e|E|\s?[x|\*]\s?10\^)[+-]?\d+|\d*[\.]\d*|\d*))(.*)


	
	if ($string =~ /^((?:10\^[+\-]?\d+)|(?:[+\-]?\d*\.?\d*(?:(?:e|E|(?:\s*?(?:X|x|\*)\s*?10\^))[+\-]?\d*)?))(.*)$/g){
		$val = $1;
		$units = $2;

		if (!$val && $units){
			#if there are units, assume there's a 1 in front if not there.  i.e. a student could put 'mL' only in a denominator answer blank for density. 
			$val = 1;
		}
		if (!$val && !$units){
			$val = 0;
		}
	} else {
		$val = 0;
		$units = '';  
	}
	#warn "Going to match: >$string<";
	#warn "$num2";
	
	#warn "units: $units" if $units;
	#warn "unitless: $string[0]" unless $units;
	if ($units) {
		#while ($units =~ s/$unitSpace/$1*$2/) {};
		#$units =~ s/ //g;  # Why did I remove spaces here?  this conflicts with units like "fl oz" which have a space.  I don't want to force having a '-' dash between them yet.
							# This might break something else, but we'll remove it for now.					
	    $units =~ s/^\s+//;  # removes leading whitespace if present
	    $units =~ s/\s+$//;  # removes trailing whitespace if present
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
		return InexactValue::InexactValue->new($arr[0], $arr[1]);
		#return Value->Package("InexactValue")->new($arr[0], $arr[1]);
	} else {
		return InexactValue::InexactValue->new($value); # Value->Package("InexactValue")->new($value);
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
	$anyPrefix = $self->getFlag("anyPrefix");

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
			"failOnValueWrong"=>$failOnValueWrong,
			"anyPrefix"=>$anyPrefix
		});
	
	my @resultArr = @$result;

	$currentCredit = shift @resultArr;
	$message = shift @resultArr;
	$ans->score($currentCredit);

	return $ans;
}
sub compareValuesAnyPrefix {
	my $self = shift;
	my $student = shift;
	my $options = shift;

	my $creditValue = $options->{"creditValue"};

	
	my $result = BetterUnits::compareBaseUnits($student->{units_ref}, $self->{units_ref});
	
	$multiplier = BetterUnits::convertUnitHash($student->{units_ref}, $self->{units_ref});
	if ($multiplier == 1){ 
		# without this check, the units check for credit might false positive.
		# i.e. answer is 23 J and user just forgets units: "23"
		# This will give a multiplier of "1" and be correct for the units check.  
		# We force it incorrect here.
		return 0;
	}
	$multiplier2 = InexactValueWithUnits::InexactValueWithUnits->new([$multiplier,Inf],'');
	my $converted = $multiplier2 * $student ;
	
	%optCopy = %$options;
	# do the value compare again, but make sure we're not stuck in a loop
	$optCopy{'anyPrefix'} = 0;
	$result = $self->{inexactValue}->compareValue($converted->{inexactValue}, \%optCopy);

	return $result;
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
	my $anyPrefix = $options->{"anyPrefix"};
	my $currentCredit = 0;
	my $message = '';
	my $anyPrefixUnitCorrection = false;


	my $valueCompare = $self->{inexactValue}->compareValue($student->{inexactValue}, $options);
	
	if ($anyPrefix && !$valueCompare){
		$valueCompare = $self->compareValuesAnyPrefix($student, $options);
	}

	if ($valueCompare){
		$currentCredit+= $valueCompare;

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
	# if ($self->sigFigs() == Inf || $self->sigFigs() == $student->sigFigs()){
	# 	$currentCredit += $creditSF;
	# } else {
	# 	$message  .= "Incorrect sig figs.  ";
	# }
	# grade units!          
	#warn "GRADING $self and $student";
	# warn %{$self->{units_ref}};
	# warn %{$student->{units_ref}};
	if (compareUnitHash($self->{units_ref}, $student->{units_ref} )){
		$currentCredit += $creditUnits;
	} elsif ($anyPrefix && $self->compareValuesAnyPrefix($student, $options)) {
		$currentCredit += $creditUnits;
	} else {
		$message .= "Incorrect units.  ";
	}

	return [$currentCredit, $message];
}

sub string {
	my $self = shift;

	if (defined $self->{units}){
		$units = $self->{units};
		$units =~ s/^\s+//;  # removes leading whitespace if present

		# check if any units can be "translated".  i.e. chemical units that need to be formated properly;

		foreach my $k (keys %unitTranslation){
			#warn '/' . $k . '/';
			#warn 'before: ' . $units;
			my $special = %unitTranslation{$k};
			my $leading = '';
			my $s;
			if (exists $special->{leading} && $special->{leading} ne ''){
				#warn 'leading: ' . $special->{leading} . '<';
				$leading = $special->{leading};
				$s = $leading . ' ' . $special->string();
			} else {
				$s = $special->string();
			}
			
			$units =~ s/\Q$k/$s/;
			#warn 'after: ' . $units;
		}

		return InexactValue::InexactValue::string($self) . ' ' . $units;
	} else {
		return InexactValue::InexactValue::string($self);
	}
}

sub TeX {
	my $self = shift;
	my $options = shift;
	my $cancel = exists($options->{shouldCancel});
	#$n = InexactValue::InexactValue::string($self);
	$n = $self->{inexactValue};

	$n =~ s/(?:E|x10\^)\+?(-?)0*([^)]*?)$/\\times 10^{$1$2}/gi; # convert E notation to x10^(...)
	#warn "$n";

	if (defined $self->{units}){
		$units = $self->{units};
		if ($cancel) {
			return $n . '\\ \\cancel{' . TeXunits($units) . '}';
		}
		return $n . '\\ ' . TeXunits($units);
	} else {
		return $n;
	}
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

	# check if any units can be "translated".  i.e. chemical units that need to be formated properly;
	foreach my $k (keys %unitTranslation){
		#warn 'before: ' . $units;
		my $special = %unitTranslation{$k};
		#warn 'special: ';
		#warn $special;
		my $leading = '';
		my $s;
		if (exists $special->{leading} && $special->{leading} ne ''){
			#warn 'leading: ' . $special->{leading} . '<';
			$leading = $special->{leading};
			$s = $leading . '\\,' . $special->TeX();
		} else {
			$s = $special->TeX();
		}
		#my $s = $leading . '\\,' . $special->TeX();
		
		$units =~ s/\Q$k/$s/;
		#warn 'after: ' . $units;
	}
	$units =~ s/^\s+//;  # removes leading whitespace if present
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
	if (defined($self->context->flags->get('unitRegion')) && $self->context->flags->get('unitRegion') eq 'uk'){
		$region = 'uk';
	}
	unless (defined $self->{units}){
		Value::Error("The value provided doesn't contain any units so cannot be converted.");
	}

	my $multiplier = BetterUnits::convertUnit($unitFrom, $unitTo, {region=> $region});
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
  #warn "AFTER Divide $newUnitString";
  $result = $self->new([$newInexact->valueAsNumber, $newInexact->sigFigs], $newUnitString);
  
  return $result;
}

sub power {
	# best rule: the error is equal to the error of the exponent times 
	#       the value of the exponential
	# rule for intro chem: (used here!)
	# count decimals in exponent and use that for answer sig figs
	# If power is exact, then keep original sig figs.
	
	my ($self,$l,$r,$other) = Value::checkOpOrderWithPromote(@_);

	my $decimalPortionOfExponent = abs($r->valueAsRoundedNumber()) - sprintf('%.f',abs($r->valueAsRoundedNumber()));
		
	my $shortCutToCountSigFigs = $self->new("$decimalPortionOfExponent");
	my $powerResult = $l->valueAsNumber()**$r->valueAsNumber();
	#warn $r->{units};
	$newUnitString = BetterUnits::unitsToPower($l->{units_ref}, $r->valueAsRoundedNumber);
	#warn $newUnitString;

	if ($r->sigFigs() == Inf){
		return $self->new([$powerResult, $l->sigFigs()], $newUnitString);
	}
	elsif ($l->sigFigs() < $shortCutToCountSigFigs->sigFigs()){
		return $self->new([$powerResult, $l->sigFigs()], $newUnitString);
	} else {
		return $self->new([$powerResult, $shortCutToCountSigFigs->sigFigs()], $newUnitString);
	}

}

# sub evalLessThan {
# 	my ($self,$a,$b) = @_; my $context = $self->context;
# 	warn "HERE!";
# 	return 0;
# }

# sub evalGreaterThan {
# 	my ($self,$a,$b) = @_; my $context = $self->context;
# 	warn "HERE2!";
# 	return 0;
# }

sub combineStringUnitsCleanly {
	my $left = shift;
	my $right = shift;
	my $isMultiply= shift;
	my $options = shift;

	if ($hasChemicals){
		# warn "HAS CHEMICALS!!!!  $left {$isMultiply} $right";
		$options->{hasChemicals} = 1;
	}
	

	my @unitArrayLeft = process_unit_for_stringCombine($left, $options);
	my @unitArrayRight = process_unit_for_stringCombine($right, $options);
	# warn 'left: ' . $left;
	# foreach (@unitArrayLeft){
	# 	warn %$_;
	# }
	# warn 'right: ' . $right;
	# foreach (@unitArrayRight){
	# 	warn %$_;
	# }
	
	my $newUnitString = '';
	my @numerator = ();
	my @denominator = ();

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

			if (compareUnitHash($unitArrayLeft[$l]->{unitHash},$unitArrayRight[$r]->{unitHash})){
				# warn %{$unitArrayLeft[$l]};
				#  warn %{$unitArrayLeft[$l]->{unitHash}};
				#  warn %{$unitArrayRight[$r]->{unitHash}};
				$leftMatch = 1;
				push @usedR, $r;
				# same units on both sides!
				# now combine them
				my $power=0;
				if ($isMultiply) {
					$power = $unitArrayLeft[$l]->{power} + $unitArrayRight[$r]->{power};
				} else{
					$power = $unitArrayLeft[$l]->{power} - $unitArrayRight[$r]->{power};
				}
				if ($power != 0) {
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
	@usedR = main::PGsort(sub { $_[0] > $_[1]}, @usedR); 
	foreach (@usedR){
		splice(@unitArrayRight, $_, 1);
	}
  # now that we've scanned for similar units and combined those, any unused units from the right go into the new unit
	for ($r=0;$r < scalar @unitArrayRight; $r++){
		#if (scalar (@usedR) == 0 || $usedR[0] != $r ){
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
		#} else {
		#	shift @usedR;
		#}
	} 

	# We should sort the units before converting to plain string.  If 'hasChemicals' in options, those should go last.
	#  foreach (@numerator){
	#  	warn 'numer:';
	#  	warn %$_;
	#  }
	@numerator = main::PGsort(sub { (exists($_[0]->{isQualitative})? 0 : 1) > (exists($_[1]->{isQualitative}) ? 0 : 1)}, @numerator); 
	#  foreach (@numerator){
	#  	warn 'denom:';
	# 	warn %$_;
	#  }
	@denominator = main::PGsort(sub { (exists($_[0]->{isQualitative})? 0 : 1) > (exists($_[1]->{isQualitative}) ? 0 : 1)}, @denominator); 
	
	if (scalar @numerator > 0){
		for (local $a=0;$a< scalar(@numerator); $a++){
			#warn '/' . $numerator[$a]->{name} . '/';
			if ($a > 0){
				$newUnitString = $newUnitString . '*';
			}
			if (exists($numerator[$a]->{isQualitative})){  # put qualitative units in parentheses so that powers are not interpreted into the unit name itself
				$newUnitString = $newUnitString .'(' . $numerator[$a]->{name} . ')' . ($numerator[$a]->{power} == 1 ? '' : "^${numerator[$a]->{power}}");
			}else{
				$newUnitString = $newUnitString . $numerator[$a]->{name} . ($numerator[$a]->{power} == 1 ? '' : "^${numerator[$a]->{power}}");
			}
		}
	} else {
		$newUnitString = '1';
	}
	if (scalar @denominator > 0){
		$newUnitString =  $newUnitString . '/';
	} else {
		# Denominator is empty, normally that's fine.  But if numerator is empty, too. i.e. "1"
		# then that will leave a "1" as the canceled unit instead of showing nothing.
		# Need to erase everything at this point.
		if ($newUnitString eq '1'){
			$newUnitString = '';
		}
	}
	for (local $a=0;$a< scalar(@denominator); $a++){
			#warn %{$denominator[$a]};
		if ($a > 0){
			$newUnitString = $newUnitString . '*';
		}
		if (exists($denominator[$a]->{isQualitative})){  # put qualitative units in parentheses so that powers are not interpreted into the unit name itself
			$newUnitString = $newUnitString .'(' . $denominator[$a]->{name} . ')' . ($denominator[$a]->{power} == 1 ? '' : "^${denominator[$a]->{power}}");
		} else {
			$newUnitString = $newUnitString . $denominator[$a]->{name} . ($denominator[$a]->{power} == 1 ? '' : "^${denominator[$a]->{power}}");
		}
	}
	#warn $newUnitString;
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

	# Since we're storing the parsed units in this hash item, let's remove it from the temporary hash
	# so that we can compare with a student made hash that may not have the parsed item in it yet.
	delete($left{'parsed'});
	delete($right{'parsed'});


	# from https://stackoverflow.com/questions/1273616/how-do-i-compare-two-hashes-in-perl-without-using-datacompare
	# same number of keys?
	if (%left != %right) {
		# WHAT ABOUT EQUIVALENT UNITS?  i.e. M vs mol/L ??

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
			return 0;
		} else {
			my %cmp = map { $_ => 1 } keys %right;
			for my $key (keys %left) {
				last unless exists $cmp{$key};
				last unless $left{$key} eq $right{$key};
				delete $cmp{$key};
			}  
			if (%cmp){
				return 0;
			} else {
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
				# While this will never be used as a standard input by students, calculations with qualitative chemical name units can sometimes
				# pick up temporary powers.  i.e.  1.36 g Fe * (1 mol Fe / 55.85 g Fe) in the conversion of grams of iron to moles of iron.
				# While putting Fe in the molar mass is not necessary at all, it is not incorrect, either, and well within the realm of possibilities
				# for student answers.  Internally, we'll surround qualitative units with parentheses () so that it is easier to discover powers.
				# Otherwise, those powers will be interpreted as part of the unit itself.

				($qualUnit, $qualUnitPower) = $f =~ /\((.*)\)(?:\^(.*))?/g;
				if (defined $qualUnit){
					$f = $qualUnit;
				}
				
				my $chemical = Chemical::Chemical->new($f);

				if (defined $chemical && scalar @{$chemical->{data}} > 0){
					$power = 1; # reset power to 1 since it might have picked up a chemical charge as the power.
					if (defined($qualUnitPower)){
						$power = $qualUnitPower;
					}
					$unit_prefix = '';  # remove any prefix parsed before.
					$unit_base = $chemical->guid();
					
					# now check if the $unit_base is in the list before adding it.  Since there are many variations of chemical names, we can only check against a post-processed name.
					unless ($known_units->{$unit_base}){
						BetterUnits::add_unit($unit_base);
					}
					my %fundamental_units_for_chemical = %BetterUnits::fundamental_units; #make copy of base unit hash
					$fundamental_units_for_chemical{$unit_base} = 1;
					my %unit_name_hash = (name=> $unit_base, unitHash => \%fundamental_units_for_chemical, power=>$power, isQualitative=>1);   # $reference_units contains all of the known units.
					push @known_unit_hash_array, \%unit_name_hash;
					$f = '';
					if (defined $chemical->{leading}){
						$f = $chemical->{leading};
					}
				}
			}


			# here we should check to see if there are any unknown units combined with spaces
			# i.e. "mol Fe2+" will fail in process_factor subroutine because it is two units, not one.
			# The trick is to not split units that are technically one (like fluid ounce).  
			# Adding a dash is fine, but if a user adds a custom unit with spaces, we want to honor it.
			my @unitsNameArray = keys %$known_units;
			@unitsNameArray = grep(/\s/, @unitsNameArray);
			@unitNamesArray2 = main::PGsort(sub {length($_[0]) > length($_[1])}, @unitsNameArray);
			my $unitsJoined = join '|', @unitNamesArray2;
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
	my ($unit_name,$power) = split(/\^/, $string);
	my @unitsNameArray = keys %$known_units;
	@unitNamesArray2 = main::PGsort(sub {length($_[0]) > length($_[1])}, @unitsNameArray);
	my $unitsJoined = join '|', @unitNamesArray2;
	
	my $unit_base;
	my $unit_prefix;
	$power = 1 unless defined($power);
	
	
	($unit_base) = $unit_name =~ /($unitsJoined)$/;
	$unit_prefix = $unit_name =~ s/\s*($unitsJoined)\s*$//r;
	$unit_prefix =~ s/\s//;

	unless (defined($unit_base)){
		# if not-strict mode, register this unit as a new unit with its own fundamentals
		
		BetterUnits::add_unit($unit_name);
		$unit_base = $unit_name;
		$unit_prefix = '';
		#die "UNIT ERROR Unrecognizable unit: |$unit_base|";
	}
	
	$prefixExponent = 0;
	if ( defined($unit_prefix) && $unit_prefix ne '') {
		if (exists($prefixes->{$unit_prefix})){
			$prefixExponent = $prefixes->{$unit_prefix}->{'exponent'};
		} else {
			#warn "Unit Prefix unrecognizable: $unit_prefix";
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
		if ($unit_hash{$keys[$i]} == 0){
			delete $unit_hash{$keys[$i]};
		}
	}

	my %unit_name_hash = (name=> $unit_prefix.$unit_base, unitHash => \%unit_hash, power=>$power);   # $reference_units contains all of the known units.
	return %unit_name_hash;
	
}

sub checkOpOrderWithPromote {
  my ($l,$r,$flag) = @_; 
  #warn $flag;
  $r = $l->promote($r);
  if ($flag) {return ($l,$r,$l,$r)} else {return ($l,$l,$r,$r)}
}

# this is mostly the same as the Value version, but this creates an infinite sig fig and no unit InexactValueWithUnits
# when the value being promoted is not already an Inexact Value with Units.  Only works with reals and numbers.
sub promote {

	my $self = shift; my $class = ref($self) || $self;
	#   my $r = shift;
	#   warn $r;
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
	unless (scalar(@_)){
		warn "empty!";
	}
	my $x = (scalar(@_) ? shift : $self);
	# warn 'Class: '. $class;
	# warn 'Self:'.$self;
	# warn 'Context: '.$context;
	# warn 'x: '.$x;

	return $x->inContext($context) if ref($x) eq $class && scalar(@_) == 0;
	$s = $self->new([$x,Inf], '', @_);
	# warn ref($s);
	return $s;
}


# package UnitsMath;
# @ISA = qw(Units);


1;
