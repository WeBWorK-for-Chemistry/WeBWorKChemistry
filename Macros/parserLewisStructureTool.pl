# This macro was created by Lee McPherson to allow students to "draw" basic Lewis Structures
# and have them grade their structure on the server.  This tool is NOT designed for complex
# organic chemistry structures and is intended more for the general chemistry Lewis Structures
# with a focus on correct number of Lone Pair Electrons and basic geometries including dash/wedge
# bonds.

=head1 NAME

lewisStructureTool.pl - Allow students to draw Lewis Structures with interactive javascript.

=head1 DESCRIPTION

=head1 OPTIONS

There are a number of options that you can supply to control the appearance and grading of the 
Lewis Structure tool.

=over

=item lonePairPenalty (Default: 0.25)

This subtracts a percentage for each atom with an incorrect number of lone pairs.  
i.e. a chlorine with zero lone pairs but one that needed 3 lone pairs will only be penalized once.  

=item bondOrderPenalty (Default: 0.25)

This subtracts a percentage for each incorrect bond's bond order.  

=item showFormalCharges (Default: 0)

This will show any formal charges in the actual structure and turn on grading for them.

=item formalChargePenalty (Default: 0.10)

This only applies if showFormalCharges is active.  For each missing/incorrect formal charge,
the tool will deduct this percentage from the overall score.  Only applies if skeletal 
structure is correct (atoms and initial bonds are correct).

=item requirePerspective (Default: 1)

For geometries that need dash/wedge bonds to show 3D perspective (i.e. tetrahedral, trigonal pyramid, etc.)
the tool will deduct the penalty (below) if incorrect.  The actual positioning of these bonds does not 
matter as long as the connections are correct.

=item perspectivePenalty (Default: 0.25)

For geometries that need dash/wedge bonds to show 3D perspective (i.e. tetrahedral, trigonal pyramid, etc.)
the tool will deduct this percentage if those bonds are not detected.  Incorrect usage will also
trigger this penalty (i.e. two wedge bonds instead of one dash and one wedge).

=back

=cut

sub _parserLewisStructureTool_init {
    ADD_JS_FILE(
'https://cdn.jsdelivr.net/gh/limefrogyank/LewisStructuresWeb@latest/dist/bundle.js',
        1, { defer => undef }
    );
    main::PG_restricted_eval(
        'sub LewisStructureTool { parser::LewisStructureTool->new(@_) }');
}

loadMacros( 'MathObjects.pl', 'contextChemical.pl',
    'contextArbitraryString.pl' );

package parser::LewisStructureTool;
our @ISA = qw(Value::String);

sub new {
    my $self = shift;
    my $class   = ref($self) || $self;
    my $context = Parser::Context->getCopy('ArbitraryString');
    my $value   = shift;

    my $obj = $self->SUPER::new( $context, @_ );

    my $cl = bless {
        data          => $value,
        type          => $self->type(),
        context       => $context,
        staticObjects => [],
        cmpOptions    => {}
    }, $class;

    return $cl;
}

sub ANS_NAME {
    my $self = shift;
    $self->{name} = main::NEW_ANS_NAME() unless defined( $self->{name} );
    return $self->{name};
}

sub type { return 'String'; }

# Produce a hidden answer rule to contain the JavaScript result and insert the lewis structure div.
sub ans_rule {
    my $self     = shift;
    my $out      = main::NAMED_HIDDEN_ANS_RULE( $self->ANS_NAME );
    my $inputs   = $self->getPG('$inputs_ref');
    my $ans_name = $self->ANS_NAME;

    #warn %$inputs;

    if ( $main::displayMode eq 'TeX' ) {
        return &{ $self->{printGraph} }
          if defined( $self->{printGraph} )
          && ref( $self->{printGraph} ) eq 'CODE';

        # ADD CODE HERE TO PRODUCE A BOX FOR DRAWING ON PAPER.
        # TO-DO !!!!

    }
    elsif ( $main::displayMode ne 'PTX' ) {

        #$self->constructJSXGraphOptions;

        my $drawingToolName = "${ans_name}_drawingTool";
        my $kekuleOutput    = "false";
        $kekuleOutput = $inputs->{$ans_name}
          if ( defined $inputs->{$ans_name} );
        my $showFormalCharges =
          $self->{cmpOptions}{showFormalCharges} ? "show-formal-charges" : "";

        $out .= <<END_SCRIPT;
<lewis-structure-canvas id='$drawingToolName' $showFormalCharges></lewis-structure-canvas>
<script>
	
    let flag = false;
    let awaiting = false;
	
    const initialize${ans_name} = () => {
		const kekuleOutput = document.getElementById('${ans_name}');
		const svgOutput = document.getElementById('${ans_name}_svgOutput');
		//console.log(kekuleOutput);
		//console.log("TEST output");
		const drawingTool = document.getElementById('${ans_name}_drawingTool');

		const getOutputAsync = async () => {
			awaiting = true;
			//console.log('getting');
			let compressed = await drawingTool.getCompressedWebworkOutputAsync();
			awaiting = false;
			kekuleOutput.value = btoa(JSON.stringify(compressed));
			svgOutput.value = btoa(drawingTool.getSVG());
		}
		
		drawingTool.addEventListener('change', async (ev)=> {
			// This guarantees that the function is not run concurrently with another and one runs once past the final event.
			// Probably unnecessary since javascript is single-threaded...
			if (!awaiting) {            
				await getOutputAsync();
				while (flag){
					flag=false;
					await getOutputAsync();
				}
			} else {
				flag=true;
			}         
		});

		if ('$kekuleOutput'.length > 0){
			//console.log(JSON.parse(atob('$kekuleOutput')));
			drawingTool.loadKekuleCompressed(JSON.parse(atob('$kekuleOutput')).kekuleMimeCompressed);
			//console.log('LOADING');
		}
	};

	if (document.readyState === 'loading') {window.addEventListener('DOMContentLoaded', initialize${ans_name} );}
	else {initialize${ans_name}();}
</script>
END_SCRIPT

    }

    my $extra = <<END_INPUT;
<input type='hidden' name="${ans_name}_svgOutput" id="${ans_name}_svgOutput" ><br>
END_INPUT
    main::RECORD_EXTRA_ANSWERS("${ans_name}_svgOutput");
    return $out . $extra;
}

# sub cmp_defaults {
# 	my ($self, %options) = @_;
# 	return (
# 		$self->SUPER::cmp_defaults(%options)
# 	);
# }

# sub cmp_preprocess {
#     my $self     = shift;
#     my $ans      = shift;
#     my $inputs   = $self->getPG('$inputs_ref');
#     my $ans_name = $self->ANS_NAME;
#     warn "HE";
#     if ( $main::displayMode ne 'TeX' && $main::displayMode ne 'PTX' ) {
#         $ans->{student_ans} =
#           '';    #$main::PG->decode_base64($inputs->{"${ans_name}_svgOutput"});
#         $ans->{preview_latex_string} =
#           $main::PG->decode_base64( $inputs->{"${ans_name}_svgOutput"} );
#     }
# }

sub cmp {
    my $self    = shift;
    my $grade   = 0;
    my $message = '';

    my $cmp = $self->SUPER::cmp(
        mathQuillOpts   => "disabled",
        non_tex_preview => 1,
        %{ $self->{cmpOptions} },
        @_
    );

	
    # $cmp->install_evaluator('reset');
    # $cmp->install_evaluator(
    #     sub {
    #         $self    = shift;
    #         $correct = shift;
    #         $ansHash = shift;
    #         $correct->cmp_Error( $ansHash, 'testing' );
    #         return Value->Error('tes333ting');
    #     }
    # );
    #$cmp->{rh_ans}->throw_error("DUMB", "THIS IS DUMB");
    #warn $cmp->{rh_ans}->pretty_print;
    # warn ref $cmp;
    # warn ref $cmp->{rh_ans};
    # warn ref $cmp->{rh_ans}{checker};
    # warn %{ $cmp->{rh_ans} };
    # warn ref( $cmp->{rh_ans}{checker} );

    my $t = $cmp->{rh_ans};
	
    # foreach my $key ( keys %{ $cmp->{rh_ans} } ) {
    #     warn "KEY: $key";
    #     warn $cmp->{rh_ans}->{$key};
    # }

    unless ( ref( $cmp->{rh_ans}{checker} ) eq 'CODE' ) {
        $cmp->{rh_ans}{checker} = sub {
            #return Value->Error('testing');
            $self                   = shift;
            $correct                = shift;
            $ansHash                = shift;
            $ansHash->{ans_message} = $message;
			
			# show Lewis Structure, not raw code
			$ansHash->{student_ans} = $self->showStudentAnswer();

			# hide the preview
			undef $ansHash->{preview_latex_string};
            return $grade;

        }

    }

    # warn ref( $cmp->{rh_ans}{checker} );

    $cmp->{rh_ans}{non_tex_preview} = 1;

    my $inputs   = $self->getPG('$inputs_ref');
    my $ans_name = $self->ANS_NAME;
    if ( $main::displayMode ne 'TeX' && $main::displayMode ne 'PTX' ) {
        my $ans_name = $self->ANS_NAME;

        $cmp->{rh_ans}{correct_ans_latex_string} = $self->showCorrectAnswer();
		#$cmp->{rh_ans}{preview_text_string} = 0;
        #$cmp->{rh_ans}{correct_ans} = "TEST";

        # if (! exists @_{checker}){
        # 	$cmp->{rh_ans}{checker} = sub { return 0.6;};
        # }
        my $result = $main::PG->decode_base64( $inputs->{"${ans_name}"} );
        my $json   = JSON->new->allow_nonref;

        # if ($result == 0 || $result == ""){
        # 	return $cmp;
        # }
        my $kekuleJS;

        eval { $kekuleJS = $json->decode($result); };    #->{simpleKekule};

        if ( !defined $kekuleJS ) {

            return $cmp;
        }
        else {

            my $bondOrderPenalty =
              defined $self->{cmpOptions}{bondOrderPenalty}
              ? $self->{cmpOptions}{bondOrderPenalty}
              : 0.25;
            my $lonePairPenalty =
              defined $self->{cmpOptions}{lonePairPenalty}
              ? $self->{cmpOptions}{lonePairPenalty}
              : 0.25;

            my $showFormalCharges =
              defined $self->{cmpOptions}{showFormalCharges}
              && $self->{cmpOptions}{showFormalCharges};
            my $formalChargePenalty =
              defined $self->{cmpOptions}{formalChargePenalty}
              ? $self->{cmpOptions}{formalChargePenalty}
              : 0.10;

            my $requirePerspective =
              defined $self->{cmpOptions}{requirePerspective}
              ? $self->{cmpOptions}{requirePerspective}
              : 1;
            my $perspectivePenalty =
              defined $self->{cmpOptions}{perspectivePenalty}
              ? $self->{cmpOptions}{perspectivePenalty}
              : 0.25;

            my $simpleKekule;
            eval { $simpleKekule = $json->decode( $kekuleJS->{simpleKekule} ); };

            my $correctMoleculeHash =
              Chemical::LewisStructure::generateHashFromLaTeXFormula(
                $self->{data} );

            #warn "CORRECT MOLECULE";
            # my $tempAtomCount = scalar @{$correctMoleculeHash->{atoms}};
            #  warn "ATOM COUNT: $tempAtomCount";
            #  warn %$correctMoleculeHash;
            #  for my $atom (@{$correctMoleculeHash->{atoms}}){
            #  	warn %$atom;
            #  }
            #  for my $bond (@{$correctMoleculeHash->{bonds}}){
            #  	warn %$bond;
            #  }
            my $structureAnalysis =
              Chemical::LewisStructure::compareKekuleCTABAndHash(
                $simpleKekule->{ctab}, $correctMoleculeHash );

            #warn %$structureAnalysis;
            # for my $connectors (@{$structureAnalysis->{badConnectors}}){
            # 	warn %$connectors;
            # }

            #warn %$structureAnalysis;
            if ( $structureAnalysis->{atomsCorrect} ) {
                $grade = 1;

            }
            else {
                $message .=
"You're either missing atoms or some atoms aren't connected to the correct atoms. ";
                return $cmp;
            }
            if ( !$structureAnalysis->{bondOrderCorrect} ) {
                my $bondOrderErrors =
                  scalar @{ $structureAnalysis->{badConnectors} };
                $grade -= $bondOrderErrors *
                  $bondOrderPenalty;    # 25% off for each bond order error.
                $message .=
"You have at least $bondOrderErrors <b>bond order</b> problem(s). ";
            }
            if ( !$structureAnalysis->{lonePairsCorrect} ) {
                my $lonePairErrors =
                  scalar @{ $structureAnalysis->{badLonePairNodes} };
                $grade -= $lonePairErrors *
                  $lonePairPenalty
                  ; # 25% off for each lone pair node error. (i.e. missing 3 lone pairs on one atom, marked off 25% once)
                $message .=
"You have at least $lonePairErrors atom(s) with <b>lone pairs</b> incorrect. ";
            }
            if ( $showFormalCharges
                && !$structureAnalysis->{formalChargesCorrect} )
            {
                my $formalChargeErrors =
                  scalar @{ $structureAnalysis->{badFormalChargeNodes} };
                $grade -= $formalChargeErrors *
                  $formalChargePenalty
                  ;    # default 10% off for each formal charge error.
                $message .=
"You have at least $formalChargeErrors atom(s) missing formal charges. ";
            }

            if ( $requirePerspective && !$kekuleJS->{perspectiveCorrect} ) {
                $grade -= $perspectivePenalty
                  ; # flat %25 off for leaving out dash-wedge bonds when tetrahedral, trigonal pyramidal, etc.
                $message .=
"Your <b>perspective</b> is incorrect.  You may be missing dash/wedge bonds. ";
            }
            if ( $grade < 0 ) {
                $grade = 0;
            }
        }
    }

	# $cmp->{rh_ans}->{preview_text_string} = "D";
	# $cmp->{rh_ans}->{preview_latex_string} = "T";
   
    return $cmp;
}

# sub cmp_parse {
#     my $self = shift;
#     my $ans  = shift;
   
#     $ans->score(0.5);
#     return $ans;
# }

our $correctAnswerIteration = 1;

# # DEPRECATED - this won't work on solution part of problem because it delays loading until you click the link
# sub showCorrectAnswerOLD {
# 	$self = shift;
# 	my $formula = $self->{data};
# 	my $inputs = $self->getPG('$inputs_ref');
# 	my $ans_name = $self->ANS_NAME;
# 	my $iteration = $correctAnswerIteration++;
# 	my $kekuleOutput = $inputs->{$ans_name} if (defined $inputs->{$ans_name});

# 	my $answerHash = Chemical::LewisStructure::generateHashFromLaTeXFormula($formula);
# 	my $answerMol = Chemical::LewisStructure::hashToMolFile($answerHash);

# 	my $correctAnswer = <<END_SCRIPT;
# <lewis-structure-canvas id='${ans_name}_answerTool_$iteration' readonly></lewis-structure-canvas>
# <script>

#     const initialize${ans_name}_answerTool_$iteration  = () => {
# 		const answerTool$iteration = document.getElementById('${ans_name}_answerTool_$iteration');

# 		if ('$kekuleOutput'.length > 0){
# 			//console.log(JSON.parse(atob('$kekuleOutput')));
# 			answerTool$iteration.loadMoleculeUsingMolAsync(`$answerMol`, true);
# 		}
# 	};

# 	if (document.readyState === 'loading') window.addEventListener('DOMContentLoaded', initialize${ans_name}_answerTool_$iteration);
# 	else initialize${ans_name}_answerTool_$iteration();
# </script>
# END_SCRIPT
# 	return $correctAnswer;
# }

# This is intended for the checker and shows in the box when a student clicks on the green checkmark (or red x).
sub showStudentAnswer {
    $self = shift;
    my $formula = $self->{data};

	my $inputs   = $self->getPG('$inputs_ref');
    my $ans_name = $self->ANS_NAME;


	return $main::PG->decode_base64($inputs->{"${ans_name}_svgOutput"});

}

sub showCorrectAnswer {
    $self = shift;
    my $formula = $self->{data};

    #my $inputs = $self->getPG('$inputs_ref');
    my $ans_name  = $self->ANS_NAME;
    my $iteration = $correctAnswerIteration++;
    my $showFormalCharges =
      $self->{cmpOptions}{showFormalCharges} ? "show-formal-charges" : "";

    #my $kekuleOutput = $inputs->{$ans_name} if (defined $inputs->{$ans_name});

    my $answerHash =
      Chemical::LewisStructure::generateHashFromLaTeXFormula( $formula,
        { saveSteps => 0, showFormalCharges => $showFormalCharges } );

# With Lone Pairs adds lone pairs as an atom item (that gets hacked in drawing tool)
    my $answerMol = Chemical::LewisStructure::hashToMolFile( $answerHash,
        { noCharges => 0, onlySingleBonds => 0, withLonePairs => 0 } );

    #warn $answerMol;
    my $correctAnswer = <<END_SCRIPT;
<lewis-structure-canvas id='${ans_name}_answerTool_$iteration' mol='$answerMol' $showFormalCharges readonly></lewis-structure-canvas>

END_SCRIPT
    return $correctAnswer;
}

sub showSolutionGuide {
    $self = shift;
    my $formula       = $self->{data};
    my $correctAnswer = '<ul>';

    #$correctAnswer .= "HEY CHECK IT<br/>";
    #my $inputs = $self->getPG('$inputs_ref');
    my $ans_name          = $self->ANS_NAME;
    my $iteration         = $correctAnswerIteration++;
    my $showFormalCharges = defined $self->{cmpOptions}{showFormalCharges}
      && $self->{cmpOptions}{showFormalCharges} ? 1 : 0;
    my $showFormalChargesAttribute =
      $showFormalCharges ? "show-formal-charges" : "";

    #my $kekuleOutput = $inputs->{$ans_name} if (defined $inputs->{$ans_name});

    my $answerHash =
      Chemical::LewisStructure::generateHashFromLaTeXFormula( $formula,
        { saveSteps => 1, showFormalCharges => $showFormalCharges } );

    # warn scalar @$answerHash;
    my @steps = @$answerHash;

# my $tempIndex = 2;
# warn %{$steps[$tempIndex]};
# warn %{$steps[$tempIndex]->{hash}};
# warn $steps[$tempIndex]->{title};
# warn "FROM ANSWER";
# for my $atoms (@{$steps[$tempIndex]->{hash}->{atoms}}) {
# 	warn %$atoms;
# }
# With Lone Pairs adds lone pairs as an atom item (that gets hacked in drawing tool)
# my $answerMol = Chemical::LewisStructure::hashToMolFile($steps[$tempIndex]->{hash}, {noCharges=>0, onlySingleBonds=>0, withLonePairs=>1});
# warn $answerMol;

    my $first = 0;

    for my $step (@steps) {

        #warn "HERE";
        #warn ref $step;
        #warn %$step;
        my $test = $step->{hash};

        #warn keys %{ $step->{hash} };
        #if (keys %{ $step->{hash} }){
        my $stepMol = Chemical::LewisStructure::hashToMolFile( $step->{hash},
            { noCharges => 0, onlySingleBonds => 0, withLonePairs => 1 } );

        #}
        my $title         = $step->{title};
        my $details       = defined $step->{details} ? $step->{details} : '';
        my $electronsLeft = $step->{electronsLeft};

        # my %T = %$step;
        # for my $t (keys %T){
        # 	my $temp = $T{$t};
        # 	$correctAnswer .= "$temp \n";
        # }
        #$correctAnswer .= "%T <br/>";
        $correctAnswer .= "<li>";
        $correctAnswer .= "<b>$title</b> <br/>";
        $correctAnswer .= "$details <br/>";
        $correctAnswer .= "Electrons available: $electronsLeft <br/>";
        if ($first) {
            $correctAnswer .=
"<lewis-structure-canvas id='${ans_name}_answerTool_$iteration' mol='$stepMol' $showFormalChargesAttribute explicit-lone-pairs readonly></lewis-structure-canvas>\n";
        }
        $correctAnswer .= "</li>";
        $first = 1;
        $iteration++;
    }

# 	 = <<END_SCRIPT;
# <lewis-structure-canvas id='${ans_name}_answerTool_$iteration' mol='$answerMol' $showFormalCharges explicit-lone-pairs readonly></lewis-structure-canvas>

    # END_SCRIPT
    $correctAnswer .= "</ul>";

    return $correctAnswer;

}

1;
