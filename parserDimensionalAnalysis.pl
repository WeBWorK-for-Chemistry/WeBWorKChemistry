=head1 NAME

parserDimensionalAnalysis.pl 

=head1 DESCRIPTION



=cut

loadMacros("MathObjects.pl");
loadMacros("contextInexactValueWithUnits.pl");


# ##################################################

package parser::MultiAnswer;

our %known_units = %BetterUnits::known_units;

# sub asConversionFactor {
# 	$self = shift;
# 	return $self->with(
# 		singleResult => 0,
# 		allowBlankAnswers=>1,
# 		checkTypes => 0,
# #   separator => '/',
# #   tex_separator => '/',
# #   tex_format => '\frac{%1s}{%2s}',
# 		checker => sub {
# 			my ($correct,$student,$ansHash) = @_;
# 			# setMessage starts with index 1.
# 			$ansHash->setMessage(1,'this is a test!!!!!!');
# 			# $first = shift @$correct;
# 			# push @$correct, $first;
# 			return [0.75,0.75];
# 		}
# 	);
# }


sub asDimensionalAnalysis {
	my $self = shift;
	my $given = shift;
	my $options = shift;	

	my $gradeGiven = 0;
	if (exists $options->{gradeGiven}){
		$gradeGiven = $options->{gradeGiven};
	}
	

	return $self->with(
		singleResult => 0,
		allowBlankAnswers=>1,
		checkTypes => 0,
		checker => sub {
			my ($correct,$student,$ansHash) = @_;

			my @scores = ();

			my @correctArray = @{$correct};
			my @studentArray = @{$student};

			my $studentCalc = $gradeGiven ? @studentArray[0] : $given;

			my $factorIndexStart = 0;
			if ($gradeGiven){
				$factorIndexStart = 1;
			}

			for ($i = 0; $i < scalar @studentArray - 1; $i++){
				if ($studentArray[$i]->isExactZero){
					# handle if zeros in blanks (assume exact 1 for dimensional analysis)
					# If we don't do this, we get division by zero errors.  
					# Plus, intent of blanks in student dimensional analysis is usually 1 mathmatically.
					# Final answer doesn't matter.
					$units = $studentArray[$i]->{units};
					$newValue = Value->Package("InexactValueWithUnits")->new(['1',9**9**9], $units);
					$studentArray[$i] = $newValue;
					
				} elsif ($studentArray[$i]->isOne) {
					# for student conversion factors, assume a 1 is exact!
					$units = $studentArray[$i]->{units};
					$newValue = Value->Package("InexactValueWithUnits")->new(['1',9**9**9], $units);
					$studentArray[$i] = $newValue;
				} 
				
			}

			# check pairs of values in conversion factors to see if they must be exact or not.
			# adding in 'hasChemicals' option:  pairs of mol values will be exact, too.
			# WARNING: a mole value with an energy value will have moles exact, too, but this doesn't fix that.  
			for ($i = $factorIndexStart; $i < scalar @studentArray - 1; $i+=2) {
				$numerator = $studentArray[$i];
				$denominator = $studentArray[$i+1];
				# a simple solution would be to look up the units being used and divide their factors... i.e. ft = 0.3048, in = 0.0254
				# so ft/in = 12 exactly
				# now we compare to what the student put.  1 ft / 12 in -> the inverse matches
				# Second example where NOT exact:  L = 0.001  cup = 0.000236588
				# L / cup = 4.22675706291
				# Student might put 1 L / 4.227 cup --- inverse would be 4.227 which is ne to 4.22675706291... so it's NOT exact
				# Technically, L to cups is never exact.  But if we get precision to this degree, it is probably ok to pretend it is exact.
				# We're not doing calculations for real-world problems... only education.

				# some conversions would have to be manually entered... i.e. lb to g... previous method would require gravity acceleration 
				# to be figured into the conversion because they're technically not the same physical quantities.  Need to compare physical
				# quantities first to see if they could be exact.
				if (BetterUnits::comparePhysicalQuantity($numerator->{units_ref}, $denominator->{units_ref})){
					
					my $studentInverseRatio = $denominator->{inexactValue} / $numerator->{inexactValue};
					my $ratio = $numerator->{units_ref}->{factor} / $denominator->{units_ref}->{factor};
					my $a = $ratio+0;
					$a =  main::Round($a,15);
					my $b = $studentInverseRatio->valueAsNumber +0;
					
					# comparing as string values to avoid floating point errors in comparison.  
					# 1000 != 1/0.001 in floating point math even though we know they are equal.
					# This MAY have an impact on precision tolerances. However, it would be odd to assume
					# greater than 12 significant figures for educational problems... so maybe moot.
					if ($ratio eq $studentInverseRatio->valueAsNumber()){  
						# they're exact!  convert them to values with infinite sig figs
						if ($numerator->sigFigs != 9**9**9){
							$studentArray[$i] = InexactValueWithUnits::InexactValueWithUnits->new([$numerator->valueAsNumber,9**9**9], $numerator->{units});
						}
						if ($denominator->sigFigs != 9**9**9){
							$studentArray[$i+1] = InexactValueWithUnits::InexactValueWithUnits->new([$denominator->valueAsNumber,9**9**9], $denominator->{units});
						}
					} 
				} elsif (BetterUnits::isMolarRatio($numerator->{units_ref}, $denominator->{units_ref})) {
					if ($numerator->sigFigs != 9**9**9){
						$studentArray[$i] = InexactValueWithUnits::InexactValueWithUnits->new([$numerator->valueAsNumber,9**9**9], $numerator->{units});
					}
					if ($denominator->sigFigs != 9**9**9){
						$studentArray[$i+1] = InexactValueWithUnits::InexactValueWithUnits->new([$denominator->valueAsNumber,9**9**9], $denominator->{units});
					}
				}
			}

			# warn $studentCalc;
			# calculate answer using student dimensional analysis finally
			for ($i = $factorIndexStart; $i < scalar @studentArray - 1; $i++){
				# warn $studentArray[$i];
				if ($i % 2 == $factorIndexStart){
					# numerator, so multiply
					$studentCalc *= $studentArray[$i];
				} else {
					# denominator, so divide
					$studentCalc /= $studentArray[$i];
				}
				# warn $studentCalc;
				# warn 'next';
			}

			$ansHash->setMessage(scalar @studentArray,"Your dimensional analysis returns this value: $studentCalc");

			# Time to grade dimensional analysis!
			# Grading assumes that the answer provided includes the REQURIED pathway for dimensional analysis.  While order will not matter,
			# the specific conversions do.  i.e. if cm -> m -> um is provided in the answer and the student gives a correct cm->um direct 
			# conversion, then the student will be marked wrong on the conversion work.
			my $count=1;
			my $studentGiven;
			
			if ($gradeGiven) {
				# We actually have to grade the given value of the problem.  Make sure 
				# students are entering dimensional analysis properly from scratch.
				$studentGiven = shift @studentArray;
				# check for matching units on student given and actual given,
				# then check for matching value (with tolerance)
				$givenScore=0;
				$message='';
				$valueGrade = $given->{inexactValue}->compareValue($studentGiven->{inexactValue},{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
				$givenScore = $valueGrade;
				if ($givenScore != 0 && $givenScore != 1){
					$message .= "Most likely you have a significant figures problem.";
				}
				if (InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($given->{units_ref}, $studentGiven->{units_ref}) == 0) {
				#if ($given->{units} ne $studentGiven->{units}) {
					$givenScore*=0.5;  # half-credit b/c missing units.
					$message .= "Your units are incorrect.";	
				}				
				push @scores, $givenScore;
				$ansHash->setMessage($count, $message);
				$count++;

				shift @correctArray; # throw away the first value, don't need it anymore
			} 

			# Remove the answer from the correct array and student array
			$correctAnswer = pop @correctArray;
			$studentAnswer = pop @studentArray;
			
			while (scalar @studentArray > 1) {

				$numerator = shift @studentArray;
				$denominator = shift @studentArray;
				$numeratorScore=0;
				$denominatorScore=0;
				$studentRatio = $numerator->{inexactValue} / $denominator->{inexactValue};  

				# going to compare simplified units via division of factors
				$studentDiv = $numerator/$denominator;

				for ($j = scalar @correctArray - 2; $j >= 0; $j-=2) { 
					# simplify conversion factors first
					#warn %{$numerator->{units_ref}};
					#warn %{$denominator->{units_ref}};
					#BetterUnits::simplifyConversionFactorUnits($numerator->{units_ref},$denominator->{units_ref});

					# for comparing simplified units
					$answerDiv = $correctArray[$j] / $correctArray[$j+1];

					# check for matching units on both parts, then check for matching value (with tolerance)
					#if (BetterUnits::compareUnitRefs($correctArray[$j]->{units_ref},$numerator->{units_ref}) && BetterUnits::compareUnitRefs($correctArray[$j+1]->{units_ref},$denominator->{units_ref})){
					if (BetterUnits::compareUnitRefs($answerDiv->{units_ref},$studentDiv->{units_ref})) {
						# if answer is an exact number (like 12 inches in 1 ft), student's input of 12 will automatically be inexact, so just tolerate sig fig "errors" if answer is exact
						$numeratorCreditSigFigs = 0.5;
						$numeratorCreditValue = 0.5;
						if ($correctArray[$j]->{inexactValue}->sigFigs() == Inf){
							$numeratorCreditSigFigs = 0;
							$numeratorCreditValue = 1.0;
						}
						$valueGradeNumerator = $correctArray[$j]->{inexactValue}->compareValue($numerator->{inexactValue},{"creditSigFigs"=>$numeratorCreditSigFigs, "creditValue"=>$numeratorCreditValue, "failOnValueWrong"=>1});
						$numeratorScore = $valueGradeNumerator;
						if ($numeratorScore != 0 && $numeratorScore != 1){
							$ansHash->setMessage($count,"Most likely you have a significant figures problem.");
						}
						$denominatorCreditSigFigs = 0.5;
						$denominatorCreditValue = 0.5;
						if ($correctArray[$j+1]->{inexactValue}->sigFigs() == Inf){
							$denominatorCreditSigFigs = 0;
							$denominatorCreditValue = 1.0;
						}
						$valueGradeDenominator = $correctArray[$j+1]->{inexactValue}->compareValue($denominator->{inexactValue},{"creditSigFigs"=>$denominatorCreditSigFigs, "creditValue"=>$denominatorCreditValue, "failOnValueWrong"=>1});
						$denominatorScore = $valueGradeDenominator;
						if ($denominatorScore != 0 && $denominatorScore != 1){
							$ansHash->setMessage($count+1,"Most likely you have a significant figures problem.");
						}
						if ($numeratorScore == 0 && $denominatorScore == 0) {
							# check the ratio to see if those match.  Maybe student used a different equality like 1L/1000mL instead of 0.001L/1mL
							$correctRatio = $correctArray[$j]->{inexactValue}/$correctArray[$j+1]->{inexactValue}; 
							$numeratorScore = $correctRatio->compareValue($studentRatio,{"creditSigFigs"=>$numeratorCreditSigFigs, "creditValue"=>$numeratorCreditValue, "failOnValueWrong"=>1});
							$denominatorScore = $correctRatio->compareValue($studentRatio,{"creditSigFigs"=>$denominatorCreditSigFigs, "creditValue"=>$denominatorCreditValue, "failOnValueWrong"=>1});

						}
	
						splice(@correctArray, $j, 2);
						last;
					} 
				}
				push @scores, $numeratorScore;
				push @scores, $denominatorScore;
				$count++;
				$count++;
			}

			# reload correctArray with the full array since we've been removing stuff.
			my @correctArray = @{$correct};

			# compute a potential answer with rounding errors from the correct dimensional analysis
			# This might have problems, but right now, we recalculate the answer by reducing the number
			# of sig figs for each factor by 1 (assuming there's more than 1 already).
			# This is done twice, so we get an imprecise calculation at the end.  This is used
			# to see if maybe the student got it right, but just had rounding errors.
			# We need more tests to see if edge cases will break this estimation.
			my @possibleRoundingErrorAnswers = ();
			my $roundingErrorAnswer = $given;
			for ($i = $factorIndexStart; $i < scalar @correctArray - 1; $i+=2){
				my $numerator = $correctArray[$i];
				my $denominator = $correctArray[$i+1];
				if ($numerator->{inexactValue}->sigFigs > 1 && $numerator->{inexactValue}->sigFigs != 9**9**9) {
					$numerator->{inexactValue}->sigFigs($numerator->{inexactValue}->sigFigs() - 1);
					$numerator = InexactValueWithUnits::InexactValueWithUnits->new($numerator->{inexactValue}->valueAsRoundedNumber, $numerator->{units});
				}
				if ($denominator->{inexactValue}->sigFigs > 1 && $denominator->{inexactValue}->sigFigs != 9**9**9) {
					$denominator->{inexactValue}->sigFigs($denominator->{inexactValue}->sigFigs() - 1);
					$denominator = InexactValueWithUnits::InexactValueWithUnits->new($denominator->{inexactValue}->valueAsRoundedNumber, $denominator->{units});
				}
				$roundingErrorAnswer *= $numerator;
				$roundingErrorAnswer /= $denominator;
			}
			push @possibleRoundingErrorAnswers, $roundingErrorAnswer;

			my $roundingErrorAnswer = $given;
			for ($i = $factorIndexStart; $i < scalar @correctArray - 1; $i+=2) {
				my $numerator = $correctArray[$i];
				my $denominator = $correctArray[$i+1];
				if ($numerator->{inexactValue}->sigFigs > 1 && $numerator->{inexactValue}->sigFigs != 9**9**9) {
					$numerator->{inexactValue}->sigFigs($numerator->{inexactValue}->sigFigs() - 1);
					$numerator = InexactValueWithUnits::InexactValueWithUnits->new($numerator->{inexactValue}->valueAsRoundedNumber, $numerator->{units});
				}
				if ($denominator->{inexactValue}->sigFigs > 1 && $denominator->{inexactValue}->sigFigs != 9**9**9) {
					$denominator->{inexactValue}->sigFigs($denominator->{inexactValue}->sigFigs() - 1);
					$denominator = InexactValueWithUnits::InexactValueWithUnits->new($denominator->{inexactValue}->valueAsRoundedNumber, $denominator->{units});
				}
				$roundingErrorAnswer *= $numerator;
				$roundingErrorAnswer /= $denominator;
			}
			push @possibleRoundingErrorAnswers, $roundingErrorAnswer;


			# now grade final answer
			#$finalStudentAnswer = shift @studentArray;
			$correctAnswer = pop @correctArray;
			my $result = $correctAnswer->compareValuesWithUnits(
				$studentAnswer,
				{
					"roundingErrorPossibles"=> \@possibleRoundingErrorAnswers,
					"penaltyRoundingError"=>0.25,
					"creditSigFigs"=>0.25, 
					"creditValue"=>0.5, 
					"creditUnits"=>0.25, 
					"failOnValueWrong"=>1
				});
			my @resultArr = @$result;
	
			push @scores, shift @resultArr;
			my $message = shift @resultArr;
			if ($message ne ''){
				$ansHash->setMessage($count,$message);
			}
			
			return \@scores;
		}
	);
}

sub asEquality {
	my $self = shift;
	my $given = shift;
	my $options = shift;	

	return $self->with(
		singleResult => 0,
		allowBlankAnswers=>1,
		checkTypes => 0,
		checker => sub {
			my ($correct,$student,$ansHash) = @_;

			my @scores = ();

			my @correctArray = @{$correct};
			my @studentArray = @{$student};

			unless (scalar @correctArray == 2) {
				Value::Error('There should only be two answers in this equality.');
			}

			my $studentCalc = $gradeGiven ? @studentArray[0] : $given;

			for ($i = 0; $i < 2; $i++){
				if ($studentArray[$i]->isExactZero){
					# handle if zeros in blanks (assume exact 1 for dimensional analysis)
					# If we don't do this, we get division by zero errors.  
					# Plus, intent of blanks in student dimensional analysis is usually 1 mathmatically.
					# Final answer doesn't matter.
					$units = $studentArray[$i]->{units};
					$newValue = Value->Package("InexactValueWithUnits")->new(['1',9**9**9], $units);
					$studentArray[$i] = $newValue;
					
				} elsif ($studentArray[$i]->isOne) {
					# for student conversion factors, assume a 1 is exact!
					$units = $studentArray[$i]->{units};
					$newValue = Value->Package("InexactValueWithUnits")->new(['1',9**9**9], $units);
					$studentArray[$i] = $newValue;
				} 				
			}

			# check both values in equality to see if they must be exact or not.			
			$left = $studentArray[0];
			$right = $studentArray[1];
			# a simple solution would be to look up the units being used and divide their factors... i.e. ft = 0.3048, in = 0.0254
			# so ft/in = 12 exactly
			# now we compare to what the student put.  1 ft / 12 in -> the inverse matches
			# Second example where NOT exact:  L = 0.001  cup = 0.000236588
			# L / cup = 4.22675706291
			# Student might put 1 L / 4.227 cup --- inverse would be 4.227 which is ne to 4.22675706291... so it's NOT exact
			# Technically, L to cups is never exact.  But if we get precision to this degree, it is probably ok to pretend it is exact.
			# We're not doing calculations for real-world problems... only education.

			# some conversions would have to be manually entered... i.e. lb to g... previous method would require gravity acceleration 
			# to be figured into the conversion because they're technically not the same physical quantities.  Need to compare physical
			# quantities first to see if they could be exact.

			if (BetterUnits::comparePhysicalQuantity($left->{units_ref}, $right->{units_ref})){
				my $studentInverseRatio = $right->{inexactValue} / $left->{inexactValue};
				my $ratio = $left->{units_ref}->{factor} / $right->{units_ref}->{factor};
				$studentInverseRatioAsNumber = $studentInverseRatio->valueAsNumber();
				# THIS is really strange, but 1000/1 is not the equal in value to 0.001 / 1e-6 
				# this is equivalent to using the equality 1 L = 1000 mL.
				# To get around this, we covert to string using the 'eq' operator.
				if ($ratio eq $studentInverseRatioAsNumber){
					# they're exact!  convert them to values with infinite sig figs

					if ($left->sigFigs != 9**9**9){
						$studentArray[0] = InexactValueWithUnits::InexactValueWithUnits->new([$left->valueAsNumber,9**9**9], $left->{units});
					}
					if ($right->sigFigs != 9**9**9){
						$studentArray[1] = InexactValueWithUnits::InexactValueWithUnits->new([$right->valueAsNumber,9**9**9], $right->{units});
					}
				} 
			}
			
			# Grade equality.  Order does not matter.
			my $count=1;
			my $studentGiven;

			# What if student supplied inverted equality? i.e. instead of 1 mL = 1e-3 L, they provide 1000 mL = 1 L.
			# We need to make sure the right units are used, BUT instead of comparing individual values, divide numerator and denominator and compare results.
			# Assume 2 values for array.  This is an equality.  Must have both sides filled out.
			if (scalar @studentArray != 2) {
				push @scores, 0;
				push @scores, 0;
				return \@scores;
			}

			$correctRatio = $correctArray[0]->{inexactValue}/$correctArray[1]->{inexactValue};
			$studentRatio;
			
			# Equalities MUST have units.  They are pointless without them.  So only grade if the units are there.
			#if ($studentArray[0]->{units} eq $correctArray[0]->{units} && $studentArray[1]->{units} eq $correctArray[1]->{units}) {
			if (InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($studentArray[0]->{units_ref}, $correctArray[0]->{units_ref}) == 1
			 && InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($studentArray[1]->{units_ref}, $correctArray[1]->{units_ref}) == 1) {

				$studentRatio = $studentArray[0]->{inexactValue}/$studentArray[1]->{inexactValue};
				$result = $correctRatio->compareValue($studentRatio,{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
				push @scores, $result;
				push @scores, $result;
				return \@scores;
			}

#			} elsif ($studentArray[1]->{units} eq $correctArray[0]->{units} && $studentArray[0]->{units} eq $correctArray[1]->{units}) {
			elsif (InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($studentArray[1]->{units_ref}, $correctArray[0]->{units_ref}) == 1
			 && InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($studentArray[0]->{units_ref}, $correctArray[1]->{units_ref}) == 1) {

				$studentRatio = $studentArray[1]->{inexactValue}/$studentArray[0]->{inexactValue};
				$result = $correctRatio->compareValue($studentRatio,{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
				push @scores, $result;
				push @scores, $result;
				return \@scores;

			} else {

				push @scores, 0;
				push @scores, 0;
				$ansHash->setMessage(1,"Without correct units, the equality is incorrect.");
				return \@scores;
			}
			
			#$studentValue = shift @studentArray;
			# check for matching units on both parts, then check for matching value (with tolerance)
			for ($i = 0; $i < scalar @studentArray; $i++) {
				$score = 0;
				for ($j = scalar @correctArray - 1; $j >= 0; $j--) {
					if ($studentArray[$i]->{units} eq $correctArray[$j]->{units}){
						my $correctValue = $correctArray[$j];
						$score = $correctValue->{inexactValue}->compareValue($studentArray[$i]->{inexactValue},{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
						if ($score != 0 && $score != 1){
							$ansHash->setMessage($i+1,"Most likely you have a significant figures problem.");
						}
						
						splice(@correctArray, $j, 1);
						#delete $correctArray[$j];
						last;
					}
				}
				push @scores, $score;
			}
			return \@scores;
		}
	);
}

sub asPairOfConversionFactors {
	my $self = shift;
	my $given = shift;
	my $options = shift;	

	return $self->with(
		singleResult => 0,
		allowBlankAnswers=>1,
		checkTypes => 0,
		checker => sub {
			my ($correct,$student,$ansHash) = @_;

			my @scores = ();

			my @correctArray = @{$correct};
			my @studentArray = @{$student};

			unless (scalar @correctArray == 4) {
				Value::Error('There should only be a pair of conversion factors.  i.e. only 4 answers');
			}

			my $studentCalc = $gradeGiven ? @studentArray[0] : $given;

			for ($i = 0; $i < 4; $i++){
				if ($studentArray[$i]->isExactZero){
					# handle if zeros in blanks (assume exact 1 for dimensional analysis)
					# If we don't do this, we get division by zero errors.  
					# Plus, intent of blanks in student dimensional analysis is usually 1 mathmatically.
					# Final answer doesn't matter.
					$units = $studentArray[$i]->{units};
					$newValue = Value->Package("InexactValueWithUnits")->new(['1',9**9**9], $units);
					$studentArray[$i] = $newValue;
					
				} elsif ($studentArray[$i]->isOne) {
					# for student conversion factors, assume a 1 is exact!
					$units = $studentArray[$i]->{units};
					$newValue = Value->Package("InexactValueWithUnits")->new(['1',9**9**9], $units);
					$studentArray[$i] = $newValue;
				} 				
			}
			
			# check both values in equality to see if they must be exact or not.	
			for ($i = 0; $i < scalar @studentArray; $i+=2) {
				$numerator = $studentArray[$i];
				$denominator = $studentArray[$i+1];		
			
				# a simple solution would be to look up the units being used and divide their factors... i.e. ft = 0.3048, in = 0.0254
				# so ft/in = 12 exactly
				# now we compare to what the student put.  1 ft / 12 in -> the inverse matches
				# Second example where NOT exact:  L = 0.001  cup = 0.000236588
				# L / cup = 4.22675706291
				# Student might put 1 L / 4.227 cup --- inverse would be 4.227 which is ne to 4.22675706291... so it's NOT exact
				# Technically, L to cups is never exact.  But if we get precision to this degree, it is probably ok to pretend it is exact.
				# We're not doing calculations for real-world problems... only education.

				# some conversions would have to be manually entered... i.e. lb to g... previous method would require gravity acceleration 
				# to be figured into the conversion because they're technically not the same physical quantities.  Need to compare physical
				# quantities first to see if they could be exact.
	
				if (BetterUnits::comparePhysicalQuantity($numerator->{units_ref}, $denominator->{units_ref})){
					my $studentInverseRatio = $denominator->{inexactValue} / $numerator->{inexactValue};
					my $ratio = $numerator->{units_ref}->{factor} / $denominator->{units_ref}->{factor};
					$studentInverseRatioAsNumber = $studentInverseRatio->valueAsNumber();
					# THIS is really strange, but 1000/1 is not the equal in value to 0.001 / 1e-6 
					# this is equivalent to using the equality 1 L = 1000 mL.
					# To get around this, we covert to string using the 'eq' operator.
					if ($ratio eq $studentInverseRatioAsNumber){
						# they're exact!  convert them to values with infinite sig figs
						if ($numerator->sigFigs != 9**9**9){
							# numerator is exact;
							$studentArray[$i] = InexactValueWithUnits::InexactValueWithUnits->new([$numerator->valueAsNumber,9**9**9], $numerator->{units});
						}
						if ($denominator->sigFigs != 9**9**9){
							# denominator is exact;
							$studentArray[$i+1] = InexactValueWithUnits::InexactValueWithUnits->new([$denominator->valueAsNumber,9**9**9], $denominator->{units});
						}
					} 
				}
			}
			
			# Grade equality.  Order does not matter.
			my $count=1;
			my $studentGiven;
			
			#$studentValue = shift @studentArray;
			# check for matching units on both parts, then check for matching value (with tolerance)
			for ($i = 0; $i < scalar @studentArray; $i+=2) {
				$scoreNum = 0;
				$scoreDenom = 0;
				# maybe student used 1L/1000mL instead of 0.001L/1mL, need to calculate the ratio and see if it matches instead.
				$studentRatio = $studentArray[$i]->{inexactValue}/$studentArray[$i+1]->{inexactValue};  
				#needs to go backwards here because we're deleting items from the array 
				for ($j = scalar @correctArray - 2; $j >= 0; $j-=2) {  
				
#					if ($studentArray[$i]->{units} eq $correctArray[$j]->{units} && $correctArray[$j+1]->{units} eq $studentArray[$i+1]->{units}) {
					if (InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($studentArray[$i]->{units_ref}, $correctArray[$j]->{units_ref}) == 1
					&& InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($studentArray[$i+1]->{units_ref}, $correctArray[$j+1]->{units_ref}) == 1) {
						$scoreNum = $correctArray[$j]->{inexactValue}->compareValue($studentArray[$i]->{inexactValue},{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
						if ($scoreNum != 0 && $scoreNum != 1) {
							$ansHash->setMessage($i+1,"Most likely you have a significant figures problem.");
						}						

						$scoreDenom = $correctArray[$j+1]->{inexactValue}->compareValue($studentArray[$i+1]->{inexactValue},{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
						if ($scoreDenom != 0 && $scoreDenom != 1) {
							$ansHash->setMessage($i+1+1,"Most likely you have a significant figures problem.");
						}

						if ($scoreNum == 0 && $scoreDenom == 0) {
							# check the ratio to see if those match.  Maybe student used a different equality like 1L/1000mL instead of 0.001L/1mL
							$correctRatio = $correctArray[$j]->{inexactValue}/$correctArray[$j+1]->{inexactValue}; 
							$result = $correctRatio->compareValue($studentRatio,{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
							$scoreNum = $result;
							$scoreDenom = $result;  
						}

						splice(@correctArray, $j, 2);
						last;
					}

				}
				push @scores, $scoreNum;
				push @scores, $scoreDenom;
			}
			return \@scores;
		}
	);
}

package DimensionalAnalysis;

sub generateExplanation {

	# starts with an array in case you want to separate numerator part and denominator part
	my $startingArrayRef = shift; 
	# array of conversion factors organized as [numerator,denominator,numerator,denominator,...] 
	my $conversionFactorsRef = shift;
	# final pre-calculated answer, NOT an array because we want it shown as one number
	my $finalAnswer = shift;

	# this is an options optional parameter
	my $options = shift;

	my $hasChemicals;
	if ($options->{hasChemicals}){
		$hasChemicals = 1;
	}

	my $explanation = '';

	
	@startingArray = @{ $startingArrayRef };

	my @finalAnswerUnitArray = InexactValueWithUnits::InexactValueWithUnits::process_unit_for_stringCombine($finalAnswer->{units},{hasChemicals=>$hasChemicals});
	my @finalAnswerUnitArrayCopy = @finalAnswerUnitArray;

	$startingUnits = $startingArray[0]->{units};
	$endingUnits = $finalAnswer->{units};
	

	# This is only for the first value!
	if (scalar(@startingArray) == 2) {
		$explanation .= '\frac{';
		$explanation .= @startingArray[0]->TeX;
		$explanation .= '}{';
		$explanation .= @startingArray[1]->TeX;
		$explanation .= '}';
	} else {
		#$explanation .= @startingArray[0]->TeX({shouldCancel=>1});

		my $val = $startingArray[0]->{inexactValue};
		my $numeratorUnits = '';
		my $denominatorUnits = '';
				
		@unitArray = InexactValueWithUnits::InexactValueWithUnits::process_unit_for_stringCombine($startingArray[0]->{units},{hasChemicals=>$hasChemicals});
		foreach $unit (@unitArray){
			$found = 0;
			for ($i=0; $i < scalar @finalAnswerUnitArrayCopy; $i++){
		 		if (InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($unit->{unitHash}, $finalAnswerUnitArrayCopy[$i]->{unitHash})){
					# Same so do NOT cancel out.
					splice(@finalAnswerUnitArrayCopy,$i,1);
					if ($unit->{power} > 0) {
						$numeratorUnits .= '\\mathrm{' . $unit->{name};
						if ($unit->{power} > 1){
							$numeratorUnits .= '^{'.$unit->{power}.'}';
						}
						$numeratorUnits .= '}';
					} else {
						$denominatorUnits .= '\\mathrm{' . $unit->{name};
						if ($unit->{power} < -1){
							$denominatorUnits .= '^{'.abs($unit->{power}).'}';
						}
						$denominatorUnits .= '}';
					}
					$found=1;
					last;
				} 
			}
			if ($found==0){
				
				if ($unit->{power} > 0) {
					$numeratorUnits .= '\\cancel{\\mathrm{';
					$numeratorUnits .= $unit->{name};
					if ($unit->{power} > 1){
						$numeratorUnits .= '^{'.$unit->{power}.'}';
					}
					$numeratorUnits .= '}}';
				} else {
					$denominatorUnits .= '\\cancel{\\mathrm{';
					$denominatorUnits .= $unit->{name};
					if ($unit->{power} < -1){
						$denominatorUnits .= '^{'.abs($unit->{power}).'}';
					}
					$denominatorUnits .= '}}';
				}
			}
		}

		if ($denominatorUnits eq ''){
			$explanation .= $val .$numeratorUnits;
		} else{
			$explanation .= '\\frac{' .$val. $numeratorUnits . '}{' .'1'. $denominatorUnits . '}';
		}
		
	}

	

	# now parse the dimensional analysis part
	@conversionFactors = @{ $conversionFactorsRef };
	for ($i=0; $i < scalar @conversionFactors; $i++){
		$isDenominator = $i % 2;
		$found = 0;
		# for $key (keys %{$conversionFactors[$i]->{units_ref}}){
		# 	warn $key .': '. $conversionFactors[$i]->{units_ref}->{$key};
		# }
		for ($j=0; $j < scalar @finalAnswerUnitArrayCopy; $j++){
			
			# for $key (keys %{$finalAnswerUnitArrayCopy[$j]->{unitHash}}){
			# 	warn $key .': '. $finalAnswerUnitArrayCopy[$j]->{unitHash}->{$key};
			# }

			if (InexactValueWithUnits::InexactValueWithUnits::compareUnitHash($conversionFactors[$i]->{units_ref}, $finalAnswerUnitArrayCopy[$j]->{unitHash})){
				# Same so do NOT cancel out.
				splice(@finalAnswerUnitArrayCopy,$j,1);	

				if ($isDenominator){
					$explanation .= '{'. $conversionFactors[$i]->TeX . '}';
				} else {
					$explanation .= '\\times';
					$explanation .= '\\frac{' . $conversionFactors[$i]->TeX . '}';
				}
				$found=1;
				last;
			}
		}
		#doesn't match units with answer, so cancel it.
		if ($found == 0){
			if ($isDenominator){
				$explanation .= '{' . $conversionFactors[$i]->TeX({shouldCancel=>1}) . '}';
				#$explanation .= '{'. $conversionFactors[$i]->{inexactValue} . '\cancel{\rm '. $conversionFactors[$i]->{units} . '}}';
			} else {
				$explanation .= '\\times';
				$explanation .= '\\frac{' . $conversionFactors[$i]->TeX({shouldCancel=>1}) . '}';
				#$explanation .= '\frac{' . $conversionFactors[$i]->{inexactValue} . '\cancel{\rm ' . $conversionFactors[$i]->{units} . '}}';
			}
		}
	}
	
	$explanation .= '=' . $finalAnswer->TeX;



	return  $explanation;

}

main::HEADER_TEXT(<<EOF);
<style>
.dimensionalAnalysis {
	display: flex;
	align-items: center;
}
.dimensionalAnalysis > div {
	text-align: center;
}
.dimensionalAnalysisFractionBar {
	line-height: 1px;
	width: 100%;
	border-bottom: 1px solid black;
	margin-bottom: 4px;
}
.dimensionalAnalysisMath {
	padding: 1em;
}
</style>  
EOF

sub generateProblemLaTeX {
	my $start = shift;
	my $colsref = shift;
	my $n = scalar @{$colsref};
	my $end = shift;
	my $tex;
	$tex .= '$ ';# . $start->TeX();
	$tex .= $start->TeX;
	for ($i=0; $i < $n; $i+=2) {
		$tex .= '\times';
		$tex .= '\frac';
		$tex .= '{\hspace{2cm}}';
		$tex .= '{\hspace{2cm}}';
	}
	$tex .= ' = ';
	$tex .='\fbox{\phantom{placeholder}}';
	$tex .= ' $';
	return $tex;
}

sub generateProblemHTML {
	my $start = shift;
	my $colsref = shift;
	my $n = scalar @{$colsref};
	my $end = shift;
	my $html;
	$html .= '';
	$html .= '<div class="dimensionalAnalysis">';
	$html .= '<div>';
	$html .= '$$ ' . $start->TeX . ' $$';  #this forces the number to display as LaTeX 
	$html .= '</div>';
	for ($i=0; $i < $n; $i+=2) {
		$html .= '<div class="dimensionalAnalysisMath">';
			$html .= main::math_ev3('\times');
		$html .= '</div>';
		$html .= '<div class="dimensionalAnalysisCol">';
			$html .= '<div>';
				$html .= $colsref->[$i];
			$html .= '</div>';       
			$html .= '<div class="dimensionalAnalysisFractionBar">';
				$html .= '<svg height="1" width="40">';
					$html .= '<desc>per</desc>';
				$html .= '</svg>';
			$html .= '</div>';       
			$html .= '<div>';
				$html .= $colsref->[$i+1];
			$html .= '</div>';       
		$html .= '</div>';
	}
	
	$html .= '<div  class="dimensionalAnalysisMath">';
		$html .= main::math_ev3('{}={}');
	$html .= '</div>';
	$html .= '<div>';
		$html .= $end;
	$html .= '</div>';
	$html .= '</div>';
	$html .= '';
	return $html;
}


sub generateProblem {

	my $start = shift;
	my $colsref = shift;
	my $n = scalar @{$colsref};
	my $end = shift;
	
	return main::MODES(HTML=>generateProblemHTML($start, $colsref, $end), TeX=>generateProblemLaTeX($start, $colsref, $end));
	
}


1;
