loadMacros('MathObjects.pl');

loadMacros('NumberWithUnits.pm');


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

  ($tempnum,$units) = Parser::Legacy::ObjectWithUnits::splitUnits($num) unless $units;
  if (defined $tempnum){
    $num = $tempnum;
  }
  #warn "Trying to make:  $num";
  
  #Value::Error("You must provide units for your ".$self->name) unless $units;
  if ($units){
    Value::Error("Your units can only contain one division") if $units =~ m!/.*/!;
  }
    #warn "Trying to make:  $num";
  $num = $self->makeValue($num,context=>$context);
  
  my %Units = $units ? Parser::Legacy::ObjectWithUnits::getUnits($units) : %fundamental_units;
  
  #warn "Trying to make:  ${Units{s}}";
  Value::Error($Units{ERROR}) if ($Units{ERROR});
  # make a copy of the inexact value to do comparisons with
 
  my $refcopy = $num->copy; 
  #warn $refcopy;
  $num->{inexactValue} = $refcopy;
  $num->{units} = $units;
  $num->{units_ref} = \%Units;
  $num->{isValue} = 1;
  $num->{correct_ans} .= ' '.$units if defined $num->{correct_ans};
  #$test = Parser::Legacy::ObjectWithUnits::TeXunits($units);
  #warn "$test";
  $num->{correct_ans_latex_string} .= ' '. Parser::Legacy::ObjectWithUnits::TeXunits($units) if defined $num->{correct_ans_latex_string};
  bless $num, $class;

  # $self = shift; my $class = ref($self) || $self;
  # # my $context = (Value::isContext($_[0]) ? shift : $self->context);



  # $self = $self->SUPER::new(@_);
  $num->{precedence}{'InexactValueWithUnits'} = 4;
  # $num = $self->makeValue("2.0",context=>$context);
  # $units = 'g';
  # my %Units = Parser::Legacy::ObjectWithUnits::getUnits($units);
  # Value::Error($Units{ERROR}) if ($Units{ERROR});
  # $num->{units} = $units;
  # $num->{units_ref} = \%Units;
  # $num->{isValue} = 1;
  # $num->{correct_ans} .= ' '.$units if defined $num->{correct_ans};
  # $num->{correct_ans_latex_string} .= ' '.TeXunits($units) if defined $num->{correct_ans_latex_string};
  # bless $num, $class;

  return $num;
}
sub make {
   my $self = shift;
   #$r = ref($self);
   #warn "make called: $r";
   return $self;
 }

sub makeValue {
  my $self = shift; my $value = shift;
  #my %options = (context => $self->context, @_);
  #$num = 1;
   my $context = (Value::isContext($_[0]) ? shift : $self->context);
   #$num = InexactValue::InexactValue::make($value);
  #$v= Value::makeValue($value);
  #$te=Value->context;
  #Value::Error("$v");
  #warn "Trying to make:  $value";
  if (ref($value) eq ARRAY){
    # this is the case when we want to pass a value with explicit sig figs
    @arr = @$value;
    #warn "DOING WEIRD";
    return Value->Package("InexactValue")->new($arr[0], $arr[1]);
  } else {
       # warn "DOING WEIRD2 $value";
    return Value->Package("InexactValue")->new($value);
  }

  # my $num = Value->Package("InexactValue")->new($value);

  # return $num;
}

sub checkStudentValue {
  my $self = shift; my $student = shift;
  return 1;
}

sub cmp {
  #warn "this is warning me.";
    my $self = shift;
    #Value::Error("HEHEHEHE");
  #my $correct = ($self->{correct_ans}||$self->string);
  my $cmp = new AnswerEvaluator;
  $cmp->ans_hash(
    type => "Value (".$self->class.")",
    correct_ans => $self->string,
    correct_ans_latex_string => $self->TeX,
    correct_value => $self,
    $self->cmp_defaults(@_),
    %{$self->{context}{cmpDefaults}{$self->class} || {}},  # context-specified defaults
    @_,
  );
  
  $cmp->install_pre_filter('erase');
  $cmp->install_pre_filter(sub {
    my $ans = shift;
    #warn "prefilter is running";
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
  $cmp->install_evaluator('erase');
  $cmp->install_evaluator(sub {
    my $ans = shift;
    #warn "evaluator is running";

    my $correct = $ans->{correct_value};
    my $student = $ans->{student_value};
    $ans->{_filter_name} = "InexactValueWithUnits answer checker";
    $creditSF = $self->getFlag("creditSigFigs");
    $creditValue = $self->getFlag("creditValue");
    $creditUnits = $self->getFlag("creditUnits");
    $failOnValueWrong = $self->getFlag("failOnValueWrong");

    $ans->score(0); # assume failure
    $self->context->clearError();

    $currentCredit = 0;

    if ($correct->{inexactValue}->valueAsRoundedNumber() == $student->{inexactValue}->valueAsRoundedNumber()) {
      # numbers match, now check sig figs
        $currentCredit += $creditValue;
      if ($correct->sigFigs() == $student->sigFigs()){
        $currentCredit += $creditSF;
      }
      # grade units!          
      if (compareUnitHash($correct->{units_ref}, $student->{units_ref} )){
        $currentCredit += $creditUnits;
      }
    } else {
        if ($failOnValueWrong){
          # do nothing
                  
        } else {
      
          # grade sig figs amount anyways
          if ($correct->sigFigs() == $student->sigFigs()){
            $currentCredit += $creditSF;
          }
          # grade units!          
          if (compareUnitHash($correct->{units_ref}, $student->{units_ref} )){
            $currentCredit += $creditUnits;
          }
        }
    }
    #$ans->score(1);
    $ans->score($currentCredit);

    return $ans;
  });

  return $cmp;
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
  my $num = Value->Package("InexactValue")->new($newValue, $newSigFigs);
  #Value::Error("error is $units");
  return $self->new($num, $self->{units});
}

sub sub {
  my ($self,$l,$r,$other) = InexactValueWithUnits::InexactValueWithUnits::checkOpOrderWithPromote(@_);
  $leftPos = $l->leastSignificantPosition();
  $rightPos = $r->leastSignificantPosition();
  $leftMostPosition = $self->basicMin($leftPos, $rightPos);
  $newValue = $l->valueAsNumber() - $r->valueAsNumber();
  $newSigFigs = $self->calculateSigFigsForPosition($newValue, $leftMostPosition);
  my $num = Value->Package("InexactValue")->new($newValue, $newSigFigs);
  #Value::Error("error is $units");
  return $self->new($num, $self->{units});
}

sub mult {
  my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
  $minSf = $left->minSf($left, $right);
  my $num = Value->Package("InexactValue")->new($left->valueAsNumber() * $right->valueAsNumber(), $minSf);
  
  $newUnitString = combineStringUnitsCleanly($left->{units}, $right->{units}, 1);

  return $self->new($num, $newUnitString);
}

sub div {
  my ($self,$left,$right,$flag) = Value::checkOpOrderWithPromote(@_);
  #Value::Error("Division by zero") if $r->{data}[0] == 0;
  $minSf = $left->minSf($left, $right);
  my $num = Value->Package("InexactValue")->new($left->valueAsNumber() / $right->valueAsNumber(), $minSf);
  
  $newUnitString = combineStringUnitsCleanly($left->{units}, $right->{units}, 0);
  #return $self->new($num, "g");
  return $self->new($num, $newUnitString);
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

  for ($a=0;$a< scalar(@numerator); $a++){
    if ($a > 0){
      $newUnitString = $newUnitString . '*';
    }
    $newUnitString = $newUnitString . $numerator[$a]->{name} . ($numerator[$a]->{power} == 1 ? '' : "^${numerator[$a]->{power}}");
  }
  if (scalar @denominator > 0){
    $newUnitString =  $newUnitString . '/';
  }
  for ($a=0;$a< scalar(@denominator); $a++){
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
      if ($left{$key} ne $right{$key}){
        warn $left{$key} . ' ne ' . $right{$key};
      }
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
	
	if (defined($options->{fundamental_units})) {
	  $fundamental_units = $options->{fundamental_units};
	}

	if (defined($options->{known_units})) {
	  $known_units = $options->{known_units};
	}

	my ($unit_name,$power) = split(/\^/, $string);
	$power = 1 unless defined($power);

	if ( defined( $known_units->{$unit_name} )  ) {
    unless ($isNumerator) {
      $power = $power * -1;
    }
		my %unit_name_hash = (name=> $unit_name, unitHash => $known_units->{$unit_name}, power=>$power);   # $reference_units contains all of the known units.
    return %unit_name_hash;
    
	} else {
		die "UNIT ERROR Unrecognizable unit: |$unit_name|";
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
