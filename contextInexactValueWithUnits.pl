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
	my $Units= Parser::Legacy::ObjectWithUnits::add_unit($newUnit->{name}, $newUnit->{conversion});
    return %$Units;
}

######################################################################

#
#  Customize for NumberWithUnits
#

package InexactValueWithUnits::InexactValueWithUnits;

#our @ISA = qw(Value);
our @ISA = qw(Parser::Legacy::ObjectWithUnits InexactValue::InexactValue);

sub name {'inexactValue'};
sub cmp_class {'Inexact Value with Units'};

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

	# register a new unit/s if needed
	if (defined($options->{newUnit})) {
		my @newUnits;
		if (ref($options->{newUnit}) eq 'ARRAY') {
			@newUnits = @{$options->{newUnit}};
		} else {
			@newUnits = ($options->{newUnit});
		}

		foreach my $newUnit (@newUnits) {
			if (ref($newUnit) eq 'HASH') {
				Parser::Legacy::ObjectWithUnits::add_unit($newUnit->{name}, $newUnit->{conversion});
			} else {
				Parser::Legacy::ObjectWithUnits::add_unit($newUnit);
			}
		}
	}
	Value::Error("You must provide a ".$self->name) unless defined($num);

	(my $tempnum,$units) = splitUnits($num) unless $units;
	
	if (defined $tempnum){
		$num = $tempnum;
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

	my %Units = $units ? Parser::Legacy::ObjectWithUnits::getUnits($units) : %fundamental_units;

	#quick loop to remove fundamental units that are zero
	@keys = (keys %Units);
	for ($i=scalar @keys -1;$i>=0; $i--){
		if ($Units{$keys[$i]} == 0){
			delete $Units{$keys[$i]};
		}
	}

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

sub splitUnits {
	my $aUnit = '(?:'.getPrefixNames().')?(?:'.Parser::Legacy::ObjectWithUnits::getUnitNames().')(?:\s*(?:\^|\*\*)\s*[-+]?\d+)?';
	my $unitPattern = $aUnit.'(?:\s*[/* ]\s*'.$aUnit.')*';
	my $unitSpace = "($aUnit) +($aUnit)";
	my $string = shift;
	my ($num,$units) = $string =~ m!^(.*?(?:[)}\]0-9a-z]|\d\.))\s*($unitPattern)\s*$!;
	if ($units) {
		while ($units =~ s/$unitSpace/$1*$2/) {};
		$units =~ s/ //g;
		$units =~ s/\*\*/^/g;
	}
	return ($num,$units);
}

sub getPrefixNames {
	my $a;
	my $b;
	my $prefixes = \%Units::prefixes;
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
    #warn "StudentAnswer:  $studentAnswer";
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
	if ($self->sigFigs() == $student->sigFigs()){
		$currentCredit += $creditSF;
	} else {
		$message  .= "Incorrect sig figs.  ";
	}
	# grade units!          
	if (compareUnitHash($self->{units_ref}, $student->{units_ref} )){
		$currentCredit += $creditUnits;
	} else {
		$message .= "Incorrect units.  ";
	}
		
	
	
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
  # $cla =  ref($self);
  # warn "Just checking: $cla";
  # return "2";
  my $n = InexactValue::InexactValue::string($self);
  
  $n =~ s/E\+?(-?)0*([^)]*)/\\times 10^{$1$2}/i; # convert E notation to x10^(...)
  return $n . '\ ' . Parser::Legacy::ObjectWithUnits::TeXunits($self->{units});
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

sub mult {
	my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
	#$minSf = $left->minSf($left, $right);
	#warn "SF: " . $minSf;
	# warn "LEFT: " .$left;
	# warn "RIGHT: " .$right;
	# warn "LEFT: " .$left->{inexactValue};
	# warn "RIGHT: " .$right->{inexactValue};
	# warn "LEFT: " .$left->{inexactValue}->valueAsNumber;
	# warn "RIGHT: " .$right->{inexactValue}->valueAsNumber;
	my $newInexact = $left->{inexactValue} * $right->{inexactValue};
	# warn "RESULT: " .$newInexact;
	# warn "LEFT: " .$left->{units};
	# warn "RIGHT: " .$right->{units};
	$newUnitString = combineStringUnitsCleanly($left->{units}, $right->{units}, 1);
	# warn "UNITS: " . $newUnitString;
	$result = $self->new([$newInexact->valueAsNumber, $newInexact->sigFigs], $newUnitString);
	# warn "Result final: " .$result;
	return $result;
}

sub div {
  my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
  #Value::Error("Division by zero") if $r->{data}[0] == 0;
  #$minSf = $left->minSf($left, $right);
  my $newInexact = $left->{inexactValue} / $right->{inexactValue};
  $newUnitString = combineStringUnitsCleanly($left->{units}, $right->{units}, 0);
  return $self->new([$newInexact->valueAsNumber, $newInexact->sigFigs], $newUnitString);
}

sub combineStringUnitsCleanly {
  my $left = shift;
  my $right = shift;
  my $isMultiply= shift;
  my @unitArrayLeft = process_unit_for_stringCombine($left);
  my @unitArrayRight = process_unit_for_stringCombine($right);

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
    #warn 'not equal not correct';
    return 0;
  } else {
    my %cmp = map { $_ => 1 } keys %left;
    for my $key (keys %right) {
      last unless exists $cmp{$key};
      # if ($left{$key} ne $right{$key}){
      #   warn $left{$key} . ' ne ' . $right{$key};
      # }
      last unless $left{$key} eq $right{$key};
      delete $cmp{$key};
    }
    if (%cmp) {
      #warn %cmp;
      #warn 'was not correct';
      return 0;
    } else {
      #warn 'was correct';
      return 1;
    }
  }
}

# This will create an array that contains the string value of the unit, the found "known" unit hash,
# and the power of the unit adjusted negative if it's in the denominator.
# These will be used to create new units when doing multiplication and division.  
sub process_unit_for_stringCombine {
  my $string = shift;

  my $options = shift;

  my $fundamental_units = \%Units::fundamental_units;
  my $known_units = \%Units::known_units;
    
  if (defined($options->{fundamental_units})) {
    $fundamental_units = $options->{fundamental_units};
  }

  if (defined($options->{known_units})) {
    $known_units = $options->{known_units};
  }
  
  die ("UNIT ERROR: No units were defined.") unless defined($string);  #
	#split the string into numerator and denominator --- the separator is /
  my ($numerator,$denominator) = split( m{/}, $string );

  $denominator = "" unless defined($denominator);
  my @numerator_array = process_term_for_stringCombine($numerator, 1, {fundamental_units => $fundamental_units, known_units => $known_units});
  my @denominator_array =  process_term_for_stringCombine($denominator, 0, {fundamental_units => $fundamental_units, known_units => $known_units});

  push @numerator_array, @denominator_array;
  return @numerator_array;
}

# returns an array of hashes with properties: unitHash (hash containing fundamentals), name (string), power (number)
sub process_term_for_stringCombine {
	my $string = shift;
	my $isNumerator = shift;
	my $options = shift;
	
	my $fundamental_units = \%Units::fundamental_units;
	my $known_units = \%Units::known_units;
	
	if (defined($options->{fundamental_units})) {
	  $fundamental_units = $options->{fundamental_units};
	}

	if (defined($options->{known_units})) {
	  $known_units = $options->{known_units};
	}
	
  	my @known_unit_hash_array = ();
	#my %unit_hash = %$fundamental_units;
	if ($string) {

		#split the numerator or denominator into factors -- the separators are *
	  my @factors = split(/\*/, $string);

		my $f;
		foreach $f (@factors) {
			my %factor_hash = process_factor_for_stringCombine($f,$isNumerator,{fundamental_units => $fundamental_units, known_units => $known_units});
      push @known_unit_hash_array, \%factor_hash;
			
		}
	}
	#returns a unit hash.
	#print "process_term returns", %unit_hash, "\n";
	return @known_unit_hash_array;
}

sub process_factor_for_stringCombine {
	my $string = shift;
	my $isNumerator = shift;
	#split the factor into unit and powers

	my $options = shift;

	my $fundamental_units = \%Units::fundamental_units;
	my $known_units = \%Units::known_units;
	my $prefixes = \%Units::prefixes;
	
	if (defined($options->{fundamental_units})) {
		$fundamental_units = $options->{fundamental_units};
	}

	if (defined($options->{known_units})) {
		$known_units = $options->{known_units};
	}

	my ($unit_name,$power) = split(/\^/, $string);
	my @unitsNameArray = keys %$known_units;
	my $unitsJoined = join '|', @unitsNameArray;
	my ($unit_base) = $unit_name =~ /($unitsJoined)$/;
	my ($unit_prefix) = $unit_name =~ s/($unitsJoined)$//r;
	# warn "Unit Base: " .$unit_base;
	# warn "Unit Prefix: " .$unit_prefix;

	$power = 1 unless defined($power);

	if ( defined( $known_units->{$unit_base} )  ) {
		$prefixExponent = 0;
		# warn "prefix exponent: ".$prefixExponent;
		if ( defined($unit_prefix) && $unit_prefix ne ''){
			 if (exists($prefixes->{$unit_prefix})){
				$prefixExponent = $prefixes->{$unit_prefix}->{'exponent'};
			} else {
				die "Unit Prefix unrecognizable: |$unit_prefix|";
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
		return %unit_name_hash;

	} else {
		die "UNIT ERROR Unrecognizable unit: |$unit_base|";
	}
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
