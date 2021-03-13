=head1 NAME

parserDimensionalAnalysis.pl 

=head1 DESCRIPTION



=cut

loadMacros("MathObjects.pl");
loadMacros("contextInexactValueWithUnits.pl");


# ##################################################

package parser::MultiAnswer;

our %known_units = %Units::known_units;

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

	return $self->with(
		singleResult => 0,
		allowBlankAnswers=>1,
		checkTypes => 0,
		checker => sub {
			my ($correct,$student,$ansHash) = @_;

			my @scores = ();

			my @correctArray = @{$correct};
			my @studentArray = @{$student};

			my $studentCalc = $given;

			for ($i = 0; $i < scalar @studentArray - 1; $i++){
				if ($studentArray[$i]->isExactZero){
					# handle if zeros in blanks (assume exact 1 for dimensional analysis)
					# If we don't do this, we get division by zero errors.  
					# Plus, intent of blanks in student dimensional analysis is usually 1 mathmatically.
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
			for ($i = 0; $i < scalar @studentArray - 1; $i+=2) {
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

				if (Units::comparePhysicalQuantity($numerator->{units_ref}, $denominator->{units_ref})){
					my $studentInverseRatio = $denominator->{inexactValue} / $numerator->{inexactValue};
					my $ratio = $numerator->{units_ref}->{factor} / $denominator->{units_ref}->{factor};
					
					if ($ratio == $studentInverseRatio->valueAsNumber()){
						# warn "this is an exact ratio  $numerator  /  $denominator";
						# they're exact!  convert them to values with infinite sig figs
						if ($numerator->sigFigs != 9**9**9){
							$studentArray[$i] = InexactValueWithUnits::InexactValueWithUnits->new([$numerator->valueAsNumber,9**9**9], $numerator->{units});
						}
						if ($denominator->sigFigs != 9**9**9){
							$studentArray[$i+1] = InexactValueWithUnits::InexactValueWithUnits->new([$denominator->valueAsNumber,9**9**9], $denominator->{units});
						}
					} 
				}
			}

			# calculate answer using student dimensional analysis finally
			for ($i = 0; $i < scalar @studentArray - 1; $i++){
				if ($i % 2 == 0){
					# numerator, so multiply
					$studentCalc *= $studentArray[$i];
				} else {
					# denominator, so divide
					$studentCalc /= $studentArray[$i];
				}
			}
    		$ansHash->setMessage(9,"Your dimensional analysis returns this value: $studentCalc");

			# Time to grade dimensional analysis!
			# Grading assumes that the answer provided includes the REQURIED pathway for dimensional analysis.  While order will not matter,
			# the specific conversions do.  i.e. if cm -> m -> um is provided in the answer and the student gives a correct cm->um direct 
			# conversion, then the student will be marked wrong on the conversion work.
			my $count=1;
			while (scalar @studentArray > 1) {
				$numerator = shift @studentArray;
				$denominator = shift @studentArray;
				$numeratorScore=0;
				$denominatorScore=0;
				for ($j=0; $j < scalar @correctArray - 1; $j+=2) {
					
					# check for matching units on both parts, then check for matching value (with tolerance)
					if ($correctArray[$j]->{units} eq $numerator->{units} && $correctArray[$j+1]->{units} eq $denominator->{units}){
						$valueGradeNumerator = $correctArray[$j]->{inexactValue}->compareValue($numerator->{inexactValue},{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
						$numeratorScore = $valueGradeNumerator;
						if ($numeratorScore != 0 && $numeratorScore != 1){
							$ansHash->setMessage($count,"Most likely you have a significant figures problem.");
						}
						$valueGradeDenominator = $correctArray[$j+1]->{inexactValue}->compareValue($denominator->{inexactValue},{"creditSigFigs"=>0.5, "creditValue"=>0.5, "failOnValueWrong"=>1});
						$denominatorScore = $valueGradeDenominator;
						if ($denominatorScore != 0 && $denominatorScore != 1){
							$ansHash->setMessage($count+1,"Most likely you have a significant figures problem.");
						}
					} 
				}
				push @scores, $numeratorScore;
				push @scores, $denominatorScore;
				$count++;
				$count++;
			}

			# compute a potential answer with rounding errors from the correct dimensional analysis
			my @possibleRoundingErrorAnswers = ();
			my $roundingErrorAnswer = $given;
			for ($i = 0; $i < scalar @correctArray - 1; $i+=2){
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
						for ($i = 0; $i < scalar @correctArray - 1; $i+=2){
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
			$finalStudentAnswer = shift @studentArray;
			$correctAnswer = pop @correctArray;
			my $result = $correctAnswer->compareValuesWithUnits(
				$finalStudentAnswer,
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



1;
