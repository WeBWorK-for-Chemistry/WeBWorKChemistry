loadMacros("MathObjects.pl");

sub _contextChemical_init {Chemical::Init()}

package Chemical;
#
#  Set up the context and Chemical() constructor
#
sub Init {
  my $context = $main::context{Chemical} = Parser::Context->getCopy("Numeric");
  $context->{name} = "Chemical";

  $context->functions->clear();
  $context->strings->clear();
  $context->constants->clear();
  $context->lists->clear();
  $context->parens->clear();
  $context->operators->clear();

  #
	#  Hook into the Value package lookup mechanism
	#
	$context->{value}{Chemical} = 'Chemical::Chemical';
	$context->{value}{"Value()"} = 'Chemical::Chemical';
  
  main::PG_restricted_eval('sub Chemical {  Chemical::Chemical->new(@_) };');
}

# package Chemical::Utilities;

# # Borrowed from:
# # https://github.com/psdeshpande/LZ77-Data-Compression-perl/blob/master/lz77.perl
# sub compression
# {
#     my $str = shift;
#     {
# 		use bytes;
# 		my $byte_size = length($str);
# 		print "Original Text Before Compression: $str\n";
# 		print "Size of text before compression in bytes: $byte_size\n";
# 	}
# 	die "Sorry, code too long\n" if length($str) >= 1<<16;
#     my @rep;
#     my $la = 0;
# 	while ($la < length $str) {
# 	my $n = 1;
# 	my ($tmp, $p);
# 	$p = 0;
# 	while ($la + $n < length $str
# 	       && $n < 255
# 	       && ($tmp = index(substr($str, 0, $la),
# 				substr($str, $la, $n),
# 				$p)) >= 0) {
# 	    print "inside loop\n";
# 		$p = $tmp;
# 	    $n++;
# 		print "n is:: $n";
# 		print "p is:: $p";
		
# 	}
	
# 	--$n;
# 	my $c = substr($str, $la + $n, 1);
# 	push @rep, [$p, $n, ord $c];
# 	$la += $n + 1;
#     }
	 
#     join('', map { pack 'SCC', @$_ } @rep);
	
# }

# sub decompression
# {
#     my $str = shift;
#     {
# 		use bytes;
# 		my $byte_size1 = length($str);
# 		print "Size of text after compression in bytes: $byte_size1\n";
# 	}
	
# 	my $ret = '';
#     while (length $str) {
# 	my ($s, $l, $c) = unpack 'SCC', $str;
# 	$ret .= substr($ret, $s, $l).chr$c;
# 	$str=substr($str,4);
#     }

#     $ret;
# }


package Chemical::LewisStructure;

our %idealBondCount = ( 
1=>1,2=>0,3=>1,4=>2,5=>3,6=>4,7=>3,8=>2,9=>1);

sub compareKekuleCTABAndHash {
	my $kekuleCTAB = shift;
	my $moleculeHash = shift;

	@nodes = @{$kekuleCTAB->{nodes}};
	$connectors = $kekuleCTAB->{connectors};

	@atoms = @{$moleculeHash->{atoms}};
	$bonds = $moleculeHash->{bonds};

	#my $result = isIsomorphic($nodes[0], $kekuleCTAB, $atoms[0], $moleculeHash);
	if (scalar @atoms != scalar @nodes){
		my %failure = (atomsCorrect=>0, bondOrderCorrect=>0, formalChargesCorrect=>0, lonePairsCorrect=>0, badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		return \%failure;
	}
	if (scalar @$bonds != scalar @$connectors){
		my %failure = (atomsCorrect=>0, bondOrderCorrect=>0, formalChargesCorrect=>0, lonePairsCorrect=>0, badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		return \%failure;
	}

	# Find common node, start with unique atoms... or just try carbons and loop
	# We should find least electronegative element, then tie-break with most bonds.
	my $startAtom;
	my $startNode;
	my $leastElectronegative = 10;
	map { 
		if ($_->{enPauling} < $leastElectronegative){
			$leastElectronegative = $_->{enPauling};
		}
	} @atoms;
	my @startAtomCandidates = grep {
		$_->{enPauling} == $leastElectronegative }
	 @atoms;
	#warn scalar @startAtomCandidates;
	if (scalar @startAtomCandidates == 1){
		$startAtom = $startAtomCandidates[0];
	} else {
		my $maxBonds = 0;
		for my $atom (@startAtomCandidates){
			my $currentBondCount = 0;
			map {
				if ($_->{1} == $atom || $_->{2} == $atom ){
					$currentBondCount++;
				}
			} @$bonds;
			if ($currentBondCount > $maxBonds){
				$maxBonds = $currentBondCount;
				$startAtom = $atom;
			}
		}
	}
	
	$leastElectronegative = 10;
	map {
		my $node = $_;
		my ($atomNumMinus1) = grep { $Chemical::Chemical::elements[$_] eq $node->{isotopeId} } 0 .. scalar @Chemical::Chemical::elements-1; 
		my $nodeElectronegativity = $Chemical::Chemical::paulingElectronegativities[$atomNumMinus1];
		if ($nodeElectronegativity < $leastElectronegative){
			$leastElectronegative = $nodeElectronegativity;
		}
		$node->{enPauling} = $nodeElectronegativity;
	} @nodes;
	#warn "LEAST EN: $leastElectronegative";
	my @startNodeCandidates = grep {
		$_->{enPauling} == $leastElectronegative }
	@nodes;
	#warn "StartNodeCandidates  " .	scalar @startNodeCandidates;
	if (scalar @startNodeCandidates == 1){
		$startNode = $startNodeCandidates[0];
	} else {
		my $maxConnectors = 0;
		for (my $i=0; $i < scalar @startNodeCandidates; $i++){
			my $node = $startNodeCandidates[$i];
			my $currentConnectorCount = 0;
			map {
				if ($_->{connectedObjs}->[0] == $i || $_->{connectedObjs}->[1] == $i ){
					$currentConnectorCount++;
				}
			} @$connectors;
			if ($currentConnectorCount > $maxConnectors){
				$maxConnectors = $currentConnectorCount;
				$startNode = $node;
			}
		}
	}

	if ($startNode->{isotopeId} ne  $Chemical::Chemical::elements[$startAtom->{atomNum} - 1] ){
		my %failure = (atomsCorrect=>0, bondOrderCorrect=>0, formalChargesCorrect=>0, lonePairsCorrect=>0, badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		return \%failure;
	}
	
	return isIsomorphic($startNode, $kekuleCTAB, $startAtom, $moleculeHash);


}

sub isIsomorphic {
	my $node = shift;
	my $kekuleCTAB = shift;
	my $atom = shift;
	my $moleculeHash = shift;
	# When finding combinations of bonds to check for isomorphism, we have to keep track of paths we've already gone down.
	# This isn't a regular tree with a well defined root and a path to follow down.  
	my $lastConnector = shift; 
	my $lastBond = shift;

	# warn "last connector";
	# warn %$lastConnector;

	my %success = (atomsCorrect=>1, bondOrderCorrect=>1, formalChargesCorrect=>1, lonePairsCorrect=>1, badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
	
	if ($node->{isotopeId} ne $Chemical::Chemical::elements[$atom->{atomNum} - 1]){
		# warn "NOT SAME ATOMS";
		# # warn %$node;
		# warn $node->{isotopeId};
		# # warn %$atom;
		# warn $Chemical::Chemical::elements[$atom->{atomNum} - 1];
		$success{atomsCorrect} = 0;
		return \%success;
	} else {
		# warn $node->{isotopeId};
		# warn $Chemical::Chemical::elements[$atom->{atomNum} - 1];
		# #$success{atomsCorrect} = 1;
		# warn 'OK THESE ARE MATCHING ATOMS';
	}

	# count connectors
	my @kekuleArray = @{$kekuleCTAB->{nodes}};
	my @kekuleIndexArray = grep { $kekuleArray[$_] == $node } 0 .. $#kekuleArray;
	# warn @kekuleIndexArray;
	my $kekuleIndex = -1;
	if (scalar @kekuleIndexArray > 0){
		$kekuleIndex = $kekuleIndexArray[0];
	}
	#  warn 'kekule index';
	#  warn $kekuleIndex;
	# for my $tconn (@{$kekuleCTAB->{connectors}}){
	# 	warn %$tconn;
	# }
	my @connectors;
	map {
			# warn "checking connector";
			if (! defined $lastConnector || $_ != $lastConnector){
				# warn @{$_->{connectedObjs}};
				if ($_->{connectedObjs}->[0] == $kekuleIndex || $_->{connectedObjs}->[1] == $kekuleIndex){
					push(@connectors, $_);
				}
			}
		} @{$kekuleCTAB->{connectors}};

	my @bonds;
	map {
		if ((! defined $lastBond || $_ != $lastBond) && ($_->{1} == $atom || $_->{2} == $atom)){
			push(@bonds, $_);
		}
	} @{$moleculeHash->{bonds}};
	
	# Check for same number of bonds
	if (scalar @connectors != scalar @bonds){
		 warn "NOT SAME NUMBER OF BONDS";
		 warn scalar @connectors;
		 warn scalar @bonds;
		$success{atomsCorrect} = 0;
		return \%success;
	} else {
		# warn scalar @connectors;
		# warn scalar @bonds;
		# warn "SAME BOND COUNT";
		#$success{atomsCorrect} = 1;
	}

	
	
	# Here's the meat of the comparison.  We need to verify:
	# 1. correct bond orders
	# 2. correct number of lone pairs
	# 3. correct formal charges
	# 4. XXX perspective bonds are correct XXX  NO, we don't need this because the drawing app can verify that already.

	# For versatility, we might just verify that the basic atoms are connected correctly, but return a hash that tracks not just "match", 
	# but multiple conditions.  Take the "best" result.  i.e. student could draw correct atoms and bonds, but get bond order and lone pairs wrong. 
	# So we'll find a result where connections match but nothing else.

	# Checking lonepair counts here
	my $nodeLonePairs = 0;
	map {
		if($_->{__type__} eq "Kekule.ChemMarker.UnbondedElectronSet"){
			$nodeLonePairs++;
		}
	} @{$node->{attachedMarkers}};
	#warn "LONE PAIRS ON NODE: $nodeLonePairs";

	my $atomLonePairs = defined $atom->{lonePairs} ? $atom->{lonePairs} : 0;
	#warn "LONE PAIRS ON ATOM: $atomLonePairs";

	if ($nodeLonePairs != $atomLonePairs){
		$success{lonePairsCorrect} = 0;
		#warn "bad lone pair nodes";
		push(@{$success{badLonePairNodes}}, $node);
	}

	# Checking charge here
	my $nodeFormalCharge =  defined $node->{charge} ? $node->{charge} : 0;
	#warn "Formal Charge ON NODE: $nodeFormalCharge";

	my $atomFormalCharge = defined $atom->{charge} ? $atom->{charge} : 0;
	#warn "Formal Charge ON ATOM: $atomFormalCharge";

	if ($nodeFormalCharge != $atomFormalCharge){
		$success{formalChargesCorrect} = 0;
		push(@{$success{badFormalChargeNodes}}, $node);
	}

	# SOMEHOW, NODES ARRAYS ON ANALYSIS AREN"T GETTING COPIED THROUGH TO THE END.  
	
	if (scalar @connectors > 0){
		# warn "THERE ARE MORE CONNECTORS TO CHECK";
		# warn scalar @connectors;

		# warn "CIRCLE";
		# my $permutations = getCirclePermutations(3);
		# warn @$permutations;
		# for my $test1 (@$permutations){
		# 	#warn $test1;
		# 	warn @$test1;
		# }
		# warn "PAIRINGS";
		#generatePairings(\@connectors, \@bonds);

		%branchSuccess = %success ;#(atomsCorrect=>0, bondOrderCorrect=>0, lonePairsCorrect=>0, formalChargesCorrect=>0,  badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		#%branchSuccess = (atomsCorrect=>0, bondOrderCorrect=>0, lonePairsCorrect=>0, formalChargesCorrect=>0,  badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		my @temp = (\@connectors, \@bonds);
		my $combinations = generatePairings(\@connectors, \@bonds);
		# warn "combinations " . scalar @$combinations;
		# warn @$combinations;
		# for my $combo (@$combinations){
		# 	warn "combo: " . scalar @$combo;
		# 	warn @$combo;
		# 	# for my $y (keys %$combo){
		# 	# 	for my $z (@{$combo->{$y}}){
		# 	# 		warn %$z;
		# 	# 	}
		# 	# }
		# 	for my $pairT (@$combo){
		# 		warn @$pairT;
		# 		for my $bondT (@$pairT){
		# 			warn %$bondT;
		# 		}
		# 	}
		# }
		#%branchSuccess = (atomsCorrect=>0, bondOrderCorrect=>0, lonePairsCorrect=>0, formalChargesCorrect=>0,  badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		
		my @combinationResults = ();
		for $combo (@$combinations) {
			#warn "COMBO is";
			
			# There are several combinations to check.  To "succeed" all pairings inside one combination must match.
			my @pairingResults = ();
			for my $x (@$combo){

				my $nextNode = $kekuleArray[$x->[0]->{connectedObjs}->[0]];
				if ($nextNode == $node){
					$nextNode = $kekuleArray[$x->[0]->{connectedObjs}->[1]];
				}
				my $nextAtom = $x->[1]->{1};
				if ($nextAtom == $atom){
					$nextAtom = $x->[1]->{2};
				}
				
				#  warn %$node;
				#  warn "CHECKING COMBINATION:";
				#  warn %$nextNode;
				#  warn %$nextAtom;
				#my $combinationTest = isIsomorphic($nextNode,$kekuleCTAB, $nextAtom, $moleculeHash, $x->{$y}->[0], $x->{$y}->[1] );
				my $combinationTest = isIsomorphic($nextNode,$kekuleCTAB, $nextAtom, $moleculeHash, $x->[0], $x->[1] );
				#  warn "POST COMBINATION TEST";
				# warn %$combinationTest;
				#warn %{@{$combinationTest->{badFormalChargeNodes}}[0]};
				
				
				my $orderTest = $x->[0]->{bondOrder} == $x->[1]->{order};
				# warn "Order was:  $orderTest";
				#Store bad order node regardless
				if (!$orderTest){
					# push(@{$combinationTest->{badConnectors}},$x->{$y}->[0]);
					push(@{$combinationTest->{badConnectors}},$x->[0]);
					# If recursive order tests return good order, ONLY change it to bad if this order test failed
					$combinationTest->{bondOrderCorrect} = $orderTest;
				}

				# warn "POST ORDER EDITED";
				# warn %$combinationTest;
				# warn "COMBINATION RESULTS";
				# warn $combinationTest;

				# only add pairing result if atoms are correct
				#if ($combinationTest->{atomsCorrect}){
					push(@pairingResults, $combinationTest);
				#}
				# if ($combinationTest->{lonePairsCorrect}*1 + $combinationTest->{bondOrderCorrect}*2 + $combinationTest->{atomsCorrect}*3 
				# 	> $success{lonePairsCorrect}*1 + $success{bondOrderCorrect}*2 + $success{atomsCorrect}*3 ){
				# 	%success= %$combinationTest;
				# }
				# warn "kekule";
				# warn %{$x->{$y}->[0]};
				# warn "custom";
				# warn %{$x->{$y}->[1]};
				# for my $z (@{$x->{$y}}){
				# 	warn %$z;
				# }
			}

			# my $atomsCorrect = $pairingResults[0]{atomsCorrect};
			# my $bondOrderCorrect = $pairingResults[0]{bondOrderCorrect};
			# my $lonePairsCorrect = $pairingResults[0]{lonePairsCorrect};
			my %successPairing = (atomsCorrect=>1, bondOrderCorrect=>1, lonePairsCorrect=>1, formalChargesCorrect=>1,  badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
		
			# my %successPairing = (
			# 	atomsCorrect=>1, 
			# 	bondOrderCorrect=>1, 
			# 	formalChargesCorrect=>1,
			# 	lonePairsCorrect=>1, 
			# 	badConnectors=>[], 
			# 	badLonePairNodes=>[], 
			# 	badFormalChargeNodes=>[]
			# 	);
			# warn "BEFORE SORTING PAIRING RESULTS";
			# warn scalar @pairingResults;
			my $trashPairings = 0;
			# for my $pairing (@pairingResults){
			# 	warn "CHECK";
			# 	if (!$pairing->{atomsCorrect}){
			# 		warn "BAD";
			# 		next;
			# 	} 
			# 	if (!$successPairing{atomsCorrect}){
			# 		warn "GOOD!";
			# 		$successPairing{atomsCorrect} = 1;
			# 	}
			# 	if ($pairing->{formalChargesCorrect}*1 + $pairing->{lonePairsCorrect}*2 + $pairing->{bondOrderCorrect}*3 + $pairing->{atomsCorrect}*4 
			# 			>= $successPairing{formalChargesCorrect}*1 + $successPairing{lonePairsCorrect}*2 + $successPairing{bondOrderCorrect}*3 + $successPairing{atomsCorrect}*4){
			# 		%successPairing = %$pairing;
			# 		warn "REPLACED SUCCESS PAIRING";
			# 	}		
			# }
			map {
				if ($_->{atomsCorrect}==0){
					$successPairing{atomsCorrect} = 0;
				} 
				if ($_->{bondOrderCorrect}==0){
					$successPairing{bondOrderCorrect} = 0;
				} 
				if ($_->{formalChargesCorrect}==0){
					$successPairing{formalChargesCorrect} = 0;
				} 
				if ($_->{lonePairsCorrect}==0){
					$successPairing{lonePairsCorrect} = 0;
				} 
				if ($_->{badConnectors}){
					my @tempArray = (@{$successPairing{badConnectors}}, @{$_->{badConnectors}});
					$successPairing{badConnectors} = \@tempArray;
				}
				if ($_->{badLonePairNodes}){
					my @tempArray = (@{$successPairing{badLonePairNodes}}, @{$_->{badLonePairNodes}});
					$successPairing{badLonePairNodes} = \@tempArray;
				}
				if ($_->{badFormalChargeNodes}){
					my @tempArray = (@{$successPairing{badFormalChargeNodes}}, @{$_->{badFormalChargeNodes}});					
					$successPairing{badFormalChargeNodes} = \@tempArray;
				}
			} @pairingResults;
			#warn "WERE ATOMS CORRECT AT ALL IN SET?";
			#warn $successPairing{atomsCorrect};
			if ($successPairing{atomsCorrect}){
				#warn "SUCCESSFUL PAIRING (i.e. node with atom)";
				#warn %successPairing;
				push(@combinationResults, \%successPairing);
			}
		}
		# warn "TEST COMBO RESULTS";
		# warn scalar @combinationResults;
		# for my $comboResult(@combinationResults){
		#  	warn %$comboResult;
		# 	warn scalar @{$comboResult->{badFormalChargeNodes}};
		# }
		#warn "ALL COMBINATION RESULTS";
		#warn scalar @combinationResults;
		if (scalar @combinationResults > 0){
			my %bestOne = (atomsCorrect=>0, bondOrderCorrect=>0, lonePairsCorrect=>0, formalChargesCorrect=>0,  badConnectors=>[], badLonePairNodes=>[], badFormalChargeNodes=>[]);
			map {
				# THIS MAY NOT WORK AS INTENDED.  DEFINITELY AN AREA TO CHECK IF FURTHER BUGS ARE FOUND.
				# Simple algorithm to rank correctness of model
				if ($_->{formalChargesCorrect}*1 + $_->{lonePairsCorrect}*2 + $_->{bondOrderCorrect}*3 + $_->{atomsCorrect}*4 
						>= $bestOne{formalChargesCorrect}*1 + $bestOne{lonePairsCorrect}*2 + $bestOne{bondOrderCorrect}*3 + $bestOne{atomsCorrect}*4){
					%bestOne = %$_;
					#warn "REPLACED BEST ONE SUCCESS";
				}			
			} @combinationResults;
			if ($bestOne{atomsCorrect}==0){
				$branchSuccess{atomsCorrect} = 0;
			} 
			if ($bestOne{bondOrderCorrect}==0){
				$branchSuccess{bondOrderCorrect} = 0;
			} 
			if ($bestOne{formalChargesCorrect}==0){
				$branchSuccess{formalChargesCorrect} = 0;
			} 
			if ($bestOne{lonePairsCorrect}==0){
				$branchSuccess{lonePairsCorrect} = 0;
			} 
			if ($bestOne{badConnectors}){
				my @tempArray = (@{$branchSuccess{badConnectors}}, @{$bestOne{badConnectors}});
				$branchSuccess{badConnectors} = \@tempArray;
			}
			if ($bestOne{badLonePairNodes}){
				my @tempArray = (@{$branchSuccess{badLonePairNodes}}, @{$bestOne{badLonePairNodes}});
				$branchSuccess{badLonePairNodes} = \@tempArray;
			}
			if ($bestOne{badFormalChargeNodes}){
				my @tempArray = (@{$branchSuccess{badFormalChargeNodes}}, @{$bestOne{badFormalChargeNodes}});					
				$branchSuccess{badFormalChargeNodes} = \@tempArray;
			}
		} else {
			$branchSuccess{atomsCorrect} = 0;
		}
		#warn "Branch Success";
		# warn scalar @{$branchSuccess{badFormalChargeNodes}};
		#warn %branchSuccess;
		#warn scalar @{$branchSuccess{badFormalChargeNodes}};
		#warn "NODES";
		return \%branchSuccess;
	} else {
		#warn "NO MORE CONNECTORS";
		#warn %success;		
		
		return \%success;
	}

	#return \%success;
}



sub generatePairings {
	my $arrayRef1=shift;
	my $arrayRef2=shift;

#warn scalar @$arrayRef1;
# warn scalar @$arrayRef2;
	if (scalar @$arrayRef1 != scalar @$arrayRef2){
		warn "THEY ARE NOT THE SAME!";
		return ();
	}

	my $permutations = getCirclePermutations(scalar @$arrayRef1);
	#warn "Permutations: " . scalar @$permutations;
	my @sets = ();
	for my $perm (@$permutations){
		#warn "inside perm: " . scalar @$perm;
		
		#for my $col (@$perm){
		
		for (my $it=0; $it < scalar @$perm; $it++){
			my @set = (); 
			for (my $row=0; $row < scalar @$perm; $row++){
				
				my $first = $arrayRef1->[$row];
				my $col = $it + $row >= scalar @$perm ? ($it + $row - scalar @$perm) : $it + $row;
				# warn "COL $col";
				# warn "PERM ";
				# warn @$perm;
				#warn $perm->[$col];
				my $second = $arrayRef2->[$perm->[$col]];
				my @pair = ($first, $second);
				push(@set, \@pair);
			}
			push(@sets, \@set);
		}
		
		#}
	}
	
	# for my $t(@sets){
	# 	for my $t2(@$t){
	# 		warn "array combination";
	# 		warn @$t2;
	# 	}
	# }
	#warn "Generated " . scalar @sets;
	return \@sets; 
}

sub getCirclePermutations {
	my $count = shift;
	my $listRef = shift;
	my $pieceRef = shift;
	my $choicesRef = shift;


	if (!defined $listRef){
		my @tempList = ();
		$listRef = \@tempList;
	} 
	
	if (defined $pieceRef){
	#	@piece = @$pieceRef;
	} else {
		$pieceRef = [];
		push(@$pieceRef, 0);
	}

	my @choices;
	if (defined $choicesRef){
		@choices = @$choicesRef;
	} else {
		@choices = (1..$count-1);
	}

	
	for my $item (@choices){
		my @choicesCopy = @choices;
		my @pieceCopy = @$pieceRef;
		push (@pieceCopy, $item);
		
		my $index = 0;
		$index++ until $choicesCopy[$index] eq $item;
		splice(@choicesCopy, $index, 1);
		$listRef = getCirclePermutations($count,  $listRef, \@pieceCopy, \@choicesCopy);
		$index++;
	}

	if (scalar @$pieceRef == $count){
			push(@$listRef, $pieceRef);
	}

	
	return $listRef;
}

# sub hashToMolFilesForSolution {
# 	my $structure = shift;
# 	#hash ref {$formula, \@atoms, \@bonds}
	
# 	my $mol = $structure->{formula} . "\n";
# 	$mol .= "WeBWorKChemistry" . time . "\n";
# 	$mol .= "Comment line \n";
# 	$mol .=  sprintf('%3s', scalar @{$structure->{atoms}}) . sprintf('%3s', scalar @{$structure->{bonds}}) . '  0  0  0  0  0  0  0999 V2000' . "\n";  #additional properties not handled yet
# 	my $zero = '    0.0000';
# 	for my $atom (@{$structure->{atoms}}){
# 		my $element = $Chemical::Chemical::elements[$atom->{atomNum}-1];
# 		my $charge;# = $atom->{charge};
# 		if (exists $atom->{charge}){
# 			if  ($atom->{charge} == 3) {
# 				$charge = 1
# 			} elsif ($atom->{charge} == 2){
# 					$charge = 2;
# 			} elsif ($atom->{charge} == 1){
# 				$charge = 3
# 			} elsif ($atom->{charge} == -1){
# 				$charge = 5
# 			} elsif ($atom->{charge} == -2){
# 				$charge = 6
# 			} elsif ($atom->{charge} == -3){
# 				$charge = 7
# 			} else {
# 				$charge = 0
# 			}
# 		} else {
# 			$charge = 0;
# 		}
# 		$mol .= "$zero$zero$zero " . sprintf('%3s', $element) . ' 0' . sprintf('%3s', $charge) . '  0' . '  1' . '  0' . '  0' . '  0' . '  0'. '  0'. '  0'. '  0'. '  0'. "\n";
# 	}
# 	for my $bond (@{$structure->{bonds}}){
# 		$mol .= sprintf('%3s', $bond->{1}->{id} + 1) . sprintf('%3s', $bond->{2}->{id} + 1) . sprintf('%3s', $bond->{order}) . '  0' . '  0' . '  0' . '  0' ."\n";
# 	}
# 	# skipped property block ...

# 	$mol .= "M  END\n";
# 	return $mol;
# }


sub hashToMolFile {
	my $structure = shift;
	my $options = shift;
	my $addLonePairs = defined $options->{withLonePairs} && $options->{withLonePairs};
	my $noCharges = defined $options->{noCharges} && $options->{noCharges};
	my $onlySingleBonds = defined $options->{onlySingleBonds} && $options->{onlySingleBonds};
	# for my $testAtom (@{$structure->{atoms}}){
	# 	warn %$testAtom;
	# }
	#hash ref {$formula, \@atoms, \@bonds}
	
	my $totalLonePairs = 0;
	map {
		if (defined $_->{lonePairs}){
			$totalLonePairs += $_->{lonePairs};
		}
	} @{$structure->{atoms}};
	
	my $mol = $structure->{formula} . "\n";
	#$mol .= $structure->{atoms}->[1]->{charge};
	$mol .= "WeBWorKChemistry" . time . "\n";
	$mol .= "Comment line \n";
	# the atoms count is going to be wrong if I include lonepairs
	$mol .=  sprintf('%3s', scalar @{$structure->{atoms}} + ($addLonePairs ? $totalLonePairs : 0)) . sprintf('%3s', scalar @{$structure->{bonds}} + ($addLonePairs ? $totalLonePairs : 0)) . '  0  0  0  0  0  0  0999 V2000' . "\n";  #additional properties not handled yet
	my $zero = '    0.0000';
	my $atomIndex = 1;
	my $lonePairIndex= @{$structure->{atoms}} + 1;
	my @futureBonds = ();
	for my $atom (@{$structure->{atoms}}){
		my $element = $Chemical::Chemical::elements[$atom->{atomNum}-1];
		my $charge = 0;# = $atom->{charge};
		if (!$noCharges){
			#
			if (exists $atom->{charge}){
				if  ($atom->{charge} == 3) {
					$charge = 1
				} elsif ($atom->{charge} == 2){
						$charge = 2;
				} elsif ($atom->{charge} == 1){
					$charge = 3
				} elsif ($atom->{charge} == -1){
					$charge = 5
				} elsif ($atom->{charge} == -2){
					$charge = 6
				} elsif ($atom->{charge} == -3){
					$charge = 7
				} else {
					$charge = 0
				}
			}
		} else {
			$charge = 0;
		}
		$mol .= "$zero$zero$zero " . sprintf('%3s', $element) . ' 0' . sprintf('%3s', $charge) . '  0' . '  1' . '  0' . '  0' . '  0' . '  0'. '  0'. '  0'. '  0'. '  0'. "\n";
		#$mol .= sprintf('%3s', $bond->{1}->{id} + 1) . sprintf('%3s', $bond->{2}->{id} + 1) . sprintf('%3s', $onlySingleBonds ? '1' : $bond->{order}) . '  0' . '  0' . '  0' . '  0' ."\n";
	}

	# OpenBabel resolves a LP as an unknown atom with label "A"
	if ($addLonePairs){
		for my $atom (@{$structure->{atoms}}){
			if (defined $atom->{lonePairs} && $atom->{lonePairs} > 0){
				my $lonePairs = $atom->{lonePairs};
				foreach my $LPIndex (0..$lonePairs-1){
					warn "LONE PAIR: $LPIndex";
					$mol .= "$zero$zero$zero " . sprintf('%3s', 'LP') . ' 0' . sprintf('%3s', '0') . '  0' . '  1' . '  0' . '  0' . '  0' . '  0'. '  0'. '  0'. '  0'. '  0'. "\n";
					my $futureBond = sprintf('%3s', $lonePairIndex) . sprintf('%3s', $atomIndex) . sprintf('%3s', '1') . '  0' . '  0' . '  0' . '  0' ."\n";
					push(@futureBonds,$futureBond); 
					$lonePairIndex++;
				}
			}
			$atomIndex++;
			#$mol .= "$zero$zero$zero " . sprintf('%3s', $element) . ' 0' . sprintf('%3s', $charge) . '  0' . '  1' . '  0' . '  0' . '  0' . '  0'. '  0'. '  0'. '  0'. '  0'. "\n";
		}
	}
	for my $bond (@{$structure->{bonds}}) {
		$mol .= sprintf('%3s', $bond->{1}->{id} + 1) . sprintf('%3s', $bond->{2}->{id} + 1) . sprintf('%3s', $onlySingleBonds ? '1' : $bond->{order}) . '  0' . '  0' . '  0' . '  0' ."\n";
	}
	if ($addLonePairs){
		for my $lpbond (@futureBonds){
			$mol .= $lpbond;
		}
	}
	# skipped property block ...

	$mol .= "M  END\n";
	return $mol;
}

sub copyMoleculeHash {
	my $original = shift;
	my %copy;

	my %atomDictionary = ();
	my %bondDictionary = ();

    my @atoms;
	# contain atom hash: {id, atomNum, charge, lonePairs, enPauling*, bonds}   * - included, but not needed
	my @bonds;
	# contain bond hash: {id, atom1, atom2, order, stereo?}  ? - not included, but maybe needed?

	#my %copy = (atomNum=>$original->{atomNum}, count=>$original->{count}, valence=>$original->{valence}, enPauling=>$original->{enPauling}, lonePairs=>$original->{lonePairs}, bonds=>$original->{atomNum});

	for my $atom (@{$original->{atoms}}){
		my %atomCopy = (id=>$atom->{id}, atomNum=>$atom->{atomNum}, count=>$atom->{count}, valence=>$atom->{valence}, enPauling=>$atom->{enPauling}, lonePairs=>$atom->{lonePairs}, charge=>$atom->{charge}  );
		# missing bonds
		push(@atoms, \%atomCopy);
		$atomDictionary{$atom} = \%atomCopy;
	}
	for my $bond (@{$original->{bonds}}) {
		my %bondCopy = (id=>$bond->{id}, 1=> $atomDictionary{$bond->{1}}, 2=> $atomDictionary{$bond->{2}}, order=>$bond->{order});
		push(@bonds, \%bondCopy);
		$bondDictionary{$bond} = \%bondCopy;
	}
	# back to atoms, fill in bonds 
	for my $atom (@{$original->{atoms}}){
		$copy = $atomDictionary{$atom};
		for my $bond (@{$atom->{bonds}}){
			push(@{$copy->{bonds}}, $bondDictionary{$bond});
		}
	}

	$copy{atoms} = \@atoms;
	$copy{bonds} = \@bonds;
	$copy{formula} = $original{formula};
	return \%copy; 

}

# Need an atom connection table similar to how mol files are created.  Atom list.  Then connection list using labeled atoms.
# CANNOT DO CONDENSED MOLECULAR FORMULAS
sub generateHashFromLaTeXFormula {
    my $formula = shift;
	# RETURNS hash ref {$formula, \@atoms, \@bonds}

	my $options = shift;
	my $saveSteps = defined $options->{saveSteps} && $options->{saveSteps};
	my $showFormalCharges = defined $options->{showFormalCharges} && $options->{showFormalCharges};
	
	my @steps = ();  # will be an array of hash where {title => string, hash => hash, electronsLeft => number}

    my @atoms;
	# contain atom hash: {id, atomNum, charge, lonePairs, enPauling*, bonds}   * - included, but not needed
	my @bonds;
	# contain bond hash: {id, atom1, atom2, order, stereo?}  ? - not included, but maybe needed?
	my @tempAtoms;
	my @tempBonds;
    # Parse formula
    # Count elements using function in main Chemical package.
	my $val = Chemical::Chemical::parseValue($formula);
	my $chemical = $val->{chemical};
	
	my $totalCharge = 0;

	#need to flatten chemical array because it's setup to do polyatomics with an array of atomNum inside atomNum
	my @deleteIndices;
	my @elementsToAdd;
	for ($i=0; $i<scalar @$chemical; $i++){
		my %piece = %{$chemical->[$i]};
		if (ref $piece{atomNum} eq "ARRAY") {
			push(@deleteIndices, $i);
			$totalCharge += $piece{charge};
			for my $subAtom (@{$piece{atomNum}}){
				my %atomHash = (atomNum=>$subAtom, count=>1, valence=>$Chemical::Chemical::valenceStandardMap{$subAtom}, enPauling=>$Chemical::Chemical::paulingElectronegativities[$subAtom-1], lonePairs=>0, bonds=>[]);
				for($j=0;$j<$piece{count};$j++){
					my %copy = %atomHash; 
					push(@elementsToAdd, \%copy);
				}
			}
		}
	}
	for (reverse @deleteIndices){
		delete @{$chemical}[$_];
	}
	for (@elementsToAdd){
		push(@$chemical,$_);
	}

	my $totalElectrons = 0;	
	my $valenceDetails = '';
	map {
		$totalElectrons += $_->{valence} * $_->{count};
		if ($valenceDetails ne ''){
			$valenceDetails .= ' + ';
		}
		$valenceDetails .=  $_->{count} . '(' . $_->{valence} .')'; 
		} @$chemical;
	$totalElectrons += ($totalCharge * -1);
	if ($totalCharge != 0){
		$valenceDetails .= ' + ' . ($totalCharge * -1) . ' (for charge)';
	}
	$valenceDetails .= " = $totalElectrons";

	# @tempAtoms = @atoms;
	# @tempBonds = @bonds;
	# warn "TESTING";
	# for my $atoms (@tempAtoms) {
	# 	warn %$atoms;
	# }
	# warn "TOTAL";
	#warn $totalElectrons;
	if ($saveSteps){
		push(@steps, {
			title=>"Count total valence electrons.", 
			details=>$valenceDetails, 
			hash=>copyMoleculeHash({"formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds}), 
			electronsLeft=>$totalElectrons
			});
	}
	# 1. Sort by electronegativity, but put hydrogen LAST
	# PGsort uses 0 for first is bigger and 1 for 2nd is bigger
	# <=> uses 1 for 1st is bigger and -1 for 2nd is bigger (0 for equal)
	my @enSorted = main::PGsort(sub {
		if ($_[0]->{atomNum} == 1){return 0;}
		elsif ($_[1]->{atomNum} == 1){ return 1;}
		else {($_[0]->{enPauling} <=> $_[1]->{enPauling}) == 1 ? 0 : 1};
	}, @$chemical);

	if (scalar @enSorted == 0){
		warn "shouldn't be here";
		return "";
	}

	my $sortedIndex=0;
	my $centralCandidate = $enSorted[$sortedIndex];

	my $atomIndex=0;
	my $bondIndex=0;
	my @central;
	my @terminal;
	# 2. Check if multiple carbons in basic formula.... create chain.

	if ($centralCandidate->{atomNum} == 6 && $centralCandidate->{count} > 1){
		for ($i=0; $i<$centralCandidate->{count}; $i++){
			my %copy = %$centralCandidate;
			delete($copy{count});
			$copy{id} = $atomIndex++; 
			push(@central, \%copy);
			push(@atoms, \%copy);
		}
	} else{
		my %copy = %$centralCandidate;
		delete($copy{count}); 
		$copy{id} = $atomIndex++; 
		push(@central, \%copy);
		push(@atoms, \%copy);
		for ($i=1; $i<$centralCandidate->{count}; $i++){
			my %copy = %$centralCandidate;
			delete($copy{count}); 
			$copy{id} = $atomIndex++; 
			push(@terminal, \%copy);
			push(@atoms, \%copy);

		}
	}
	
	$sortedIndex++;
	while ($sortedIndex < scalar @enSorted){
		my $nextAtom = $enSorted[$sortedIndex]; 
		for ($i=0; $i<$nextAtom->{count}; $i++){
			my %copy = %$nextAtom;
			delete($copy{count});
			$copy{id} = $atomIndex++; 
			push(@terminal, \%copy);
			push(@atoms, \%copy);

		}
		$sortedIndex++;
	}
	
	# Make the connections. Terminal atom to central atoms.
	# If carbon chain, take turns adding terminal atoms to each central atom. 
	# If carbon chain, make bonds between each carbon first.
	my $centralIndex=0;
	my %centralType = %{$central[0]};
	my $connectionDetails = $Chemical::Chemical::elements[$centralType{atomNum}-1] . ' should be the central atom.';
	if (scalar @central && $centralType{atomNum} == 6){
		$connectionDetails .= ' Since there are more than one, create a chain.';
	}
	
	for (my $i=1; $i<scalar @central; $i++){
		$totalElectrons -= 2;
		my %newBond = (1=> $central[$i-1], 2=> $central[$i], order=>1);
		push(@bonds, \%newBond);
		push(@{$central[$i-1]->{bonds}}, \%newBond);
		push(@{$central[$i]->{bonds}}, \%newBond);
	}

	my $crashCount = 0;
	for my $terminalAtom (@terminal){
		# Ensure atom does not already have X bonds for the atom type.
		my $centralAtom = $central[$centralIndex];
		#warn %{$centralAtom};
		if (! exists $centralAtom->{bonds}){
			$centralAtom->{bonds} = [];
		}
		while (exists $idealBondCount{$centralAtom->{atomNum}} && scalar @{$centralAtom->{bonds}} == $idealBondCount{$centralAtom->{atomNum}}){
			if (scalar @central > 1 && $centralIndex < scalar @central - 1 ){
				$centralIndex++;
			} else {
				$centralIndex = 0;
			}
			$centralAtom = $central[$centralIndex];
			
			$crashLoopCount++;
			#warn $centralIndex;
			if ($crashLoopCount > 20){
				warn "THIS IS BROKEN";
				last;
			}
		}
		
		$totalElectrons -= 2;
		my %newBond = (1=> $centralAtom, 2=> $terminalAtom, order=>1);
		push(@bonds, \%newBond);
		push(@{$centralAtom->{bonds}}, \%newBond);
		push(@{$terminalAtom->{bonds}}, \%newBond);
		if (scalar @central > 1 && $centralIndex < scalar @central - 1 ){
				$centralIndex++;
			} else {
				$centralIndex = 0;
			}
		
	}

	if ($saveSteps){
		push(@steps, {
			title=>"Put least electronegative element in center (except hydrogen). If multiple carbons, connect those as a chain with single bonds.  Connect all other atoms with single bonds to the central atom(s).",
			details=>$connectionDetails, 
			hash=> copyMoleculeHash({"formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds}), 
			electronsLeft=>$totalElectrons
			});
	}

	# we have a skeletal structure with single bonds.  Now do the octet rule for terminal atoms.
	my $addedLonePairs=0;
	for my $terminalAtom (@terminal){
		if ($terminalAtom->{atomNum} > 5){
			# count current electrons (should be 2! -- let's skip this and hardcode 2 in for now)
			# add 6 more electrons as lone pairs
			if ($totalElectrons >= 6){
				$terminalAtom->{lonePairs} = 3;	
				$totalElectrons -= 6;
				$addedLonePairs += 3;
			} else {
				warn $totalElectrons;
				warn %$terminalAtom;
				warn "Don't think this should happen."
			}
		} else {
			# probably hydrogen terminal atom.  
			# don't add any electrons.  
			
		}
	}

	if ($saveSteps){
		push(@steps, {
			title=>"Satisfy the octet rule for all outer/terminal atoms using lone pairs of electrons.",
			details=>"Added $addedLonePairs sets of lone pairs to the outer atoms.",
			hash=>copyMoleculeHash({"formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds}), 
			electronsLeft=>$totalElectrons
			});
	}

	# Do octet rule for central atom(s);
	# Add leftover lonepairs to central atom.  If not, need to add extra bonds
	my $nothingToDo = $totalElectrons > 0 ? 0 : 1;
	my $addedToCentral=0;
	for my $centralAtom (@central){
		my $currentElectrons = 0;
		map {
			if ($_->{1} == $centralAtom) {
				$currentElectrons += ($_->{order} * 2);
			} elsif ($_->{2} == $centralAtom) {
				$currentElectrons += ($_->{order} * 2);
			}
			} @bonds;

		while ($totalElectrons > 0) {
			if ($totalElectrons == 1){
				# do something special... TBD
			} else {
				# need to add electrons to central atom regardless of octet rules
				$centralAtom->{lonePairs} += 1;
				$totalElectrons -= 2;
				$currentElectrons += 2;
				$addedToCentral += 2;
			}
		}

		push(@steps, {
			title=>"Try to satisfy the octet rule for each cental atom with the remaining electrons. Remember that not all atoms require an octet to be stable.",
			details=>$nothingToDo ? "There are no remaining electrons to add to the central atom." : "Put the $addedToCentral electrons on the central atom.",
			hash=>copyMoleculeHash({"formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds}), 
			electronsLeft=>$totalElectrons});

		if ($centralAtom->{atomNum} > 5 && $currentElectrons < 8){
			# Central atom needs more electrons
			# share lone pairs from terminal atoms OR other central atoms
			my @centralCandidates = grep {$_->{lonePairs} && $_ != $centralAtom} @central;
			my @terminalCandidates = grep {$_->{lonePairs}} @terminal;
			my @candidates = (@centralCandidates, @terminalCandidates);
			# choose candidate(s) least likely to leave bad formal charge.
			# for now, we'll do 2 at a time 
			#	1.  if candidates are the same valence, do them in sequence
			#	2.  if candidates have different valence, ALWAYS remove lp from lower valence.
			my $crashCount = 0;
			# my $foundValenceCandidates = 0;
			#my @usedTerminalAtoms = ();
			while ($currentElectrons < 8){
				my $lowestValence = 100;
				map {if ($_->{valence} < $lowestValence) {$lowestValence = $_->{valence}}} @candidates;
				@lowestValenceCandidates = grep {$_->{valence} == $lowestValence} @candidates;
				# if (scalar @lowestValenceCandidates > 0){
				# 	$foundValenceCandidates = 1;
				# }
				for my $valenceCandidate (@lowestValenceCandidates){
					if ($valenceCandidate->{lonePairs} > 0){
						$valenceCandidate->{lonePairs}--;
						$currentElectrons += 2;
						# need to increase bond order... find bond
						($foundBond) = grep {($_->{1} == $centralAtom && $_->{2} == $valenceCandidate) 
							|| ($_->{2} == $centralAtom && $_->{1} == $valenceCandidate)} @bonds;
						$foundBond->{order}++;
						# push(@usedTerminalAtoms, $valenceCandidate);
						if ($currentElectrons == 8){
							last;
						}
					}
				}
				$crashLoopCount++;
				if ($crashLoopCount > 10){
					warn "THIS IS BROKEN";
					last;
				}
			}

			my $details = '';
			if (scalar @lowestValenceCandidates == 1){
				$details = "Sharing electrons from " . $Chemical::Chemical::elements[$lowestValenceCandidates[0]->{atomNum}-1] . " will give the best lewis structure.";
			} else {
				# HERE'S WHERE WE CAN IDENTIFY RESONANCE STRUCTURES!
				$details = "Sharing electrons from " . $Chemical::Chemical::elements[$lowestValenceCandidates[0]->{atomNum}-1] . " will give the best lewis structure.";
				#map { $details = "Sharing electrons from "} @lowestValenceCandidates;
			}
			

			push(@steps, {
				title=>"Since central atom needed more electrons than was available, share a lone pair of electrons from a terminal atom with the central atom as an extra bond.	Remember if there are multiple options, pick the one that will leave you with the most ideal formal charges.",
				details=> $details,
				hash=>copyMoleculeHash({"formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds}), 
				electronsLeft=>$totalElectrons});
			
		}
		
	}
	$details = '';
	# subroutine for finding Formal Charge
	for my $atom (@atoms){
		my $atomElectrons = 0;
		map {
			if ($_->{1} == $atom) {
				$atomElectrons += ($_->{order} * 2);
			} elsif ($_->{2} == $atom) {
				$atomElectrons += ($_->{order} * 2);
			}
			} @bonds;
		my $formalCharge = $atom->{valence} - ($atomElectrons / 2) - (exists($atom->{lonePairs}) ? $atom->{lonePairs} * 2 : 0);
		$atom->{charge} = $formalCharge;
		if ($saveSteps){
			warn $formalCharge;
			warn %$atom;		
			warn "ADDED FORMAL CHARGES";
			$details .= $atom->{charge} . '  ';
		}
	}
	if ($saveSteps && $showFormalCharges){
		push(@steps, {
			title=>"Calculate formal charges.",
			details=> "Formal Charge = Valence Electrons - lone pair electrons - (0.5 * bonding electrons)",
			hash=>copyMoleculeHash({"formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds}), 
			electronsLeft=>$totalElectrons
			});
	}
	# warn "ATOMS";
	# for $atom (@atoms){
	# 	warn %{$atom};
	# }
	# warn "BONDS";
	# for $bond (@bonds){
	# 	warn %{$bond};
	# }

    %result = ("formula"=>$formula, "atoms"=>\@atoms, "bonds"=>\@bonds);

	if ($saveSteps){
		return \@steps;
	} else {
		return \%result;
	}
}


package Chemical::Chemical;
our @ISA = qw(Value);

sub name {'chemical'};
sub cmp_class {'Chemical'};

our @elements = (
      "H",                                                                                   "He",
      "Li","Be",                                                    "B", "C", "N", "O", "F", "Ne",
      "Na","Mg",                                                    "Al","Si","P", "S", "Cl","Ar",
      "K", "Ca",  "Sc","Ti","V", "Cr","Mn","Fe","Co","Ni","Cu","Zn","Ga","Ge","As","Se","Br","Kr",
      "Rb","Sr",  "Y", "Zr","Nb","Mo","Tc","Ru","Rh","Pd","Ag","Cd","In","Sn","Sb","Te","I", "Xe",
      "Cs","Ba",  "Lu","Hf","Ta","W", "Re","Os","Ir","Pt","Au","Hg","Ti","Pb","Bi","Po","At","Rn",
      "Fr","Ra",  "Lr","Rf","Db","Sg","Bh","Hs","Mt","Ds","Rg","Cn","Nh","Fl","Mc","Lv","Ts","Og",

                  "La","Ce","Pr","Nd","Pm","Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb",
                  "Ac","Th","Pa","U", "Np","Pu","Am","Cm","Bk","Cf","Es","Fm","Md","No"
    );

# Source: https://en.wikipedia.org/wiki/Electronegativities_of_the_elements_%28data_page%29
# Unregistered electronegatives have been set as -1 so they can easily be identified and not mistaken for real values.  
# This works for finding central atoms of odd element compounds (i.e. XeF_2).
our @paulingElectronegativities = (2.2,-1,0.98,1.57,2.04,2.55,3.04,3.5,3.98,-1,0.93,1.31,1.61,1.9,2.19,2.58,3.16,-1,0.82,1,1.36,1.54,1.63,1.66,1.55,1.83,1.88,1.91,1.9,1.65,1.81,2.01,2.18,2.55,2.96,3,0.82,0.95,1.22,1.33,1.6,2.16,1.9,2.2,2.28,2.2,1.93,1.69,1.78,1.96,2.05,2.1,2.66,2.6,0.79,0.89,1.1,1.12,1.13,1.14,-1,1.17,-1,1.2,-1,1.22,1.23,1.24,1.25,-1,1.27,1.3,1.5,2.36,1.9,2.2,2.2,2.28,2.54,2,1.62,2.33,2.02,2,2.2,-1,-1,0.9,1.1,1.3,1.5,1.38,1.36,1.28,1.3,1.3,1.3,1.3,1.3,1.3,1.3,1.3,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1);

# Source: https://github.com/Bowserinator/Periodic-Table-JSON
our @atomicMasses = (1.008,4.0026022,6.94,9.01218315,10.81,12.011,14.007,15.999,18.9984031636,20.17976,22.989769282,24.305,26.98153857,28.085,30.9737619985,32.06,35.45,39.9481,39.09831,40.0784,44.9559085,47.8671,50.94151,51.99616,54.9380443,55.8452,58.9331944,58.69344,63.5463,65.382,69.7231,72.6308,74.9215956,78.9718,79.904,83.7982,85.46783,87.621,88.905842,91.2242,92.906372,95.951,98,101.072,102.905502,106.421,107.86822,112.4144,114.8181,118.7107,121.7601,127.603,126.904473,131.2936,132.905451966,137.3277,138.905477,140.1161,140.907662,144.2423,145,150.362,151.9641,157.253,158.925352,162.5001,164.930332,167.2593,168.934222,173.0451,174.96681,178.492,180.947882,183.841,186.2071,190.233,192.2173,195.0849,196.9665695,200.5923,204.38,207.21,208.980401,209,210,222,223,226,227,232.03774,231.035882,238.028913,237,244,243,247,247,251,252,257,258,259,266,267,268,269,270,269,278,281,282,285,286,289,289,293,294,294,315);
# 0 = Solid, 1 = Liquid, 2 = Gas, 3 = Unknown
our @stateOfMatter = (2,2,0,0,0,0,2,2,2,2,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0);
# Kelvin
our @meltingPoints = (13.99,0.95,453.65,1560,2349,-1,63.15,54.36,53.48,24.56,370.944,923,933.47,1687,-1,388.36,171.6,83.81,336.7,1115,1814,1941,2183,2180,1519,1811,1768,1728,1357.77,692.68,302.9146,1211.4,-1,494,265.8,115.78,312.45,1050,1799,2128,2750,2896,2430,2607,2237,1828.05,1234.93,594.22,429.7485,505.08,903.78,722.66,386.85,161.4,301.7,1000,1193,1068,1208,1297,1315,1345,1099,1585,1629,1680,1734,1802,1818,1097,1925,2506,3290,3695,3459,3306,2719,2041.4,1337.33,234.321,577,600.61,544.7,527,575,202,300,1233,1500,2023,1841,1405.3,912,912.5,1449,1613,1259,1173,1133,1800,1100,1100,1900,2400,-1,-1,-1,126,-1,-1,-1,-1,700,340,670,709,723,-1,-1);
our @boilingPoints = (20.271,4.222,1603,2742,4200,-1,77.355,90.188,85.03,27.104,1156.09,1363,2743,3538,-1,717.8,239.11,87.302,1032,1757,3109,3560,3680,2944,2334,3134,3200,3003,2835,1180,2673,3106,-1,958,332,119.93,961,1650,3203,4650,5017,4912,4538,4423,3968,3236,2435,1040,2345,2875,1908,1261,457.4,165.051,944,2118,3737,3716,3403,3347,3273,2173,1802,3273,3396,2840,2873,3141,2223,1469,3675,4876,5731,6203,5869,5285,4403,4098,3243,629.88,1746,2022,1837,1235,610,211.5,950,2010,3500,5061,4300,4404,4447,3505,2880,3383,2900,1743,1269,-1,-1,-1,-1,5800,-1,-1,-1,-1,-1,-1,-1,3570,1430,420,1400,1085,883,350,630);

our %valenceStandardMap = (
1=>1,2=>2,
3=>1,4=>2,5=>3,6=>4,7=>5,8=>6,9=>7,10=>8,
11=>1,12=>2,  13=>3,14=>4,15=>5,16=>6,17=>7,18=>8,
19=>1,20=>2,  31=>3,32=>4,33=>5,34=>6,35=>7,36=>8,
37=>1,38=>2,                51=>5,52=>6,53=>7,54=>8,
55=>1,56=>2,                83=>5,84=>6,85=>7,86=>8

);


our %polyatomicFormulaVariations = (
	'C2H3O2' => 'acetate',
	'C_2H_3O_2' =>'acetate',
	'CH_3COO' =>'acetate',
	'CH3COO' => 'acetate',
	'H_3CCOO' => 'acetate',
	'H3CCOO' => 'acetate',
	'BrO3' => 'bromate',
	'BrO_3' => 'bromate',
	'ClO3' => 'chlorate',
	'ClO_3' => 'chlorate',
	'ClO2' => 'chlorite',
	'ClO_2' => 'chlorite',
	'CN' => 'cyanide',
	'H2PO4' => 'dihydrogen phosphate',
	'H_2PO_4' => 'dihydrogen phosphate',
	'HCO3' => 'hydrogen carbonate',
	'HCO_3' => 'hydrogen carbonate',
	'HSO4' => 'hydrogen sulfate',
	'HSO_4' => 'hydrogen sulfate',
	'OH' => 'hydroxide',
	'ClO' => 'hypochlorite',
	'NO3' => 'nitrate',
	'NO_3' => 'nitrate',
	'NO2' => 'nitrite',
	'NO_2' => 'nitrite',
	'ClO4' => 'perchlorate',
	'ClO_4' => 'perchlorate',
	'MnO4' => 'permanganate',
	'MnO_4' => 'permanganate',
	'CO3' => 'carbonate',
	'CO_3' => 'carbonate',
	'CrO4' => 'chromate',
	'CrO_4' => 'chromate',
	'Cr2O7' => 'dichromate',
	'Cr_2O_7' => 'dichromate',
	'HPO4' => 'hydrogen phosphate',
	'HPO_4' => 'hydrogen phosphate',
	'C2O4' => 'oxalate',
	'C_2O_4' => 'oxalate',
	# Not going to watch for peroxide since it is indistinguishable from plain oxygen.  Will find it when comparing charges.
	#'O2' => 'peroxide',
	#'O_2' => 'peroxide',
	'SiO3' => 'silicate',
	'SiO_3' => 'silicate',
	'SO4' => 'sulfate',
	'SO_4' => 'sulfate',
	'SO3' => 'sulfite',
	'SO_3' => 'sulfite',
	'AsO_4' => 'arsenate',
	'AsO4' => 'arsenate',
	'PO4' => 'phosphate',
	'PO_4' => 'phosphate',
	'PO3' => 'phosphite',
	'PO_3' => 'phosphite',
	'NH_4' => 'ammonium',
	'NH4' => 'ammonium'
	# Not going to watch for dimercury since it is indistinguishable from plain mercury.  Will find it when comparing charges.
	#'Hg2' => 'dimercury',
);

my %additionalVariants= ();
foreach my $p (keys %polyatomicFormulaVariations){
	my $newKey = subscript($p);
	
	$newKey =~ s/_//g;
	unless (exists $additionalVariants{$newKey}){
		
		$additionalVariants{$newKey} = $polyatomicFormulaVariations{$p};
	}
}
%polyatomicFormulaVariations = (%polyatomicFormulaVariations, %additionalVariants);


our %polyatomicIons = (
	'acetate'=> {
		'atomNum'=> [8,8,6,6,1,1,1],
		'charge'=>-1,
		'TeX'=>'CH_3COO^-',
		'SMILES'=>'CC(=O)[O-]'
	},
	'bromate'=> {
		'atomNum'=> [35,8,8,8],
		'charge'=>-1,
		'TeX'=>'BrO_3^-',
		'SMILES'=>'[O-][Br+2]([O-])[O-]'
	},
	'chlorate'=> {
		'atomNum'=> [17,8,8,8],
		'charge'=>-1,
		'TeX'=>'ClO_3^-',
		'SMILES'=>'O=Cl(=O)[O-]'
	},
	'chlorite'=> {
		'atomNum'=> [17,8,8],
		'charge'=>-1,
		'TeX'=>'ClO_2^-',
		'SMILES'=>'[O-][Cl+][O-]',
		'alternate'=> [{atomNum=>17,count=>1},{atomNum=>8,count=>2}]
	},
	'cyanide'=> {
		'atomNum'=> [7,6],
		'charge'=>-1,
		'TeX'=>'CN^-',
		'SMILES'=>'[C-]#N'
	},
	'dihydrogen phosphate'=> {
		'atomNum'=> [15,8,8,8,8,1,1],
		'charge'=>-1,
		'TeX'=>'H_2PO_4^-',
		'SMILES'=>'OP(=O)(O)[O-]'
	},
	'hydrogen carbonate'=> {
		'atomNum'=> [8,8,8,6,1],
		'charge'=>-1,
		'TeX'=>'HCO_3^-',
		'SMILES'=>'OC([O-])=O'
	},
	'hydrogen sulfate'=> {
		'atomNum'=> [16,8,8,8,1],
		'charge'=>-1,
		'TeX'=>'HSO_4^-',
		'SMILES'=>'O[S](=O)(=O)[O-]'
	},
	'hydroxide'=> {
		'atomNum'=> [8,1],
		'charge'=>-1,
		'TeX'=>'OH^-',
		'SMILES'=>'[OH-]'
	},
	'hypochlorite'=> {
		'atomNum'=> [17,8],
		'charge'=>-1,
		'TeX'=>'ClO^-',
		'SMILES'=>'[O-]Cl'
	},
	'nitrate'=> {
		'atomNum'=> [8,8,8,7],
		'charge'=>-1,
		'TeX'=>'NO_3^-',
		'SMILES'=>'[N+](=O)([O-])[O-]'
	},
	'nitrite'=> {
		'atomNum'=> [8,8,7],
		'charge'=>-1,
		'TeX'=>'NO_2^-',
		'SMILES'=>'N(=O)[O-]',
		'alternate'=> [{atomNum=>7,count=>1},{atomNum=>8,count=>2}]
	},
	'perchlorate'=> {
		'atomNum'=> [17,8,8,8,8],
		'charge'=>-1,
		'TeX'=>'ClO_4^-',
		'SMILES'=>'[O-][Cl+3]([O-])([O-])[O-]'
	},
	'permanganate'=> {
		'atomNum'=> [25,8,8,8,8],
		'charge'=>-1,
		'TeX'=>'MnO_4^-',
		'SMILES'=>'[O-][Mn](=O)(=O)=O'
	},

	'carbonate'=> {
		'atomNum'=> [8,8,8,6],
		'charge'=>-2,
		'TeX'=>'CO_3^{2-}',
		'SMILES'=>'C(=O)([O-])[O-]'
	},
	'chromate'=> {
		'atomNum'=> [24,8,8,8,8],
		'charge'=>-2,
		'TeX'=>'CrO_4^{2-}',
		'SMILES'=>'[O-][Cr](=O)(=O)[O-]'
	},
	'dichromate'=> {
		'atomNum'=> [24,24,8,8,8,8,8,8,8],
		'charge'=>-2,
		'TeX'=>'Cr_2O_7^{2-}',
		'SMILES'=>'O=[Cr](=O)([O-])O[Cr](=O)(=O)[O-]'
	},
	'hydrogen phosphate'=> {
		'atomNum'=> [15,8,8,8,8,1],
		'charge'=>-2,
		'TeX'=>'HPO_4^{2-}',
		'SMILES'=>'OP(=O)([O-])[O-]'
	},
	'monohydrogen phosphate'=> {
		'atomNum'=> [15,8,8,8,8,1],
		'charge'=>-2,
		'TeX'=>'HPO_4^{2-}',
		'SMILES'=>'OP(=O)([O-])[O-]'
	},
	'oxalate'=> {
		'atomNum'=> [8,8,8,8,6,6],
		'charge'=>-2,
		'TeX'=>'C_2O_4^{2-}',
		'SMILES'=>'C(=O)(C(=O)[O-])[O-]'
	},
	'peroxide'=> {
		'atomNum'=> [8,8],
		'charge'=>-2,
		'TeX'=>'O_2^{2-}',
		'SMILES'=>'[O-][O-]'
	},
	'silicate'=> {
		'atomNum'=> [14,8,8,8],
		'charge'=>-2,
		'TeX'=>'SiO_4^{2-}',
		'SMILES'=>'[O-][Si]([O-])([O-])[O-]'
	},
	'sulfate'=> {
		'atomNum'=> [16,8,8,8,8],
		'charge'=>-2,
		'TeX'=>'SO_4^{2-}',
		'SMILES'=>'S(=O)(=O)([O-])[O-]'
	},
	'sulfite'=> {
		'atomNum'=> [16,8,8,8],
		'charge'=>-2,
		'TeX'=>'SO_3^{2-}',
		'SMILES'=>'[O-]S(=O)[O-]',
		'alternate'=> [{atomNum=>16,count=>1},{atomNum=>8,count=>3}]
	},
	'arsenate'=> {
		'atomNum'=> [33,8,8,8],
		'charge'=>-3,
		'TeX'=>'AsO_4^{3-}',
		'SMILES'=>'[O-][As+]([O-])([O-])[O-]'
	},
	'phosphate'=> {
		'atomNum'=> [15,8,8,8,8],
		'charge'=>-3,
		'TeX'=>'PO_4^{3-}',
		'SMILES'=>'[O-]P([O-])([O-])=O'
	},
	'phosphite'=> {
		'atomNum'=> [15,8,8,8],
		'charge'=>-3,
		'TeX'=>'PO_3^{3-}',
		'SMILES'=>'[O-]P([O-])([O-])'
	},

	'ammonium'=> {
		'atomNum'=> [7,1,1,1,1],
		'charge'=>1,
		'TeX'=>'NH_4^+',
		'SMILES'=>'[NH4+]'
	},

	'dimercury'=> {
		'atomNum'=> [80,80],
		'charge'=>2,
		'TeX'=>'Hg_2^{2+}',
		'SMILES'=>'[Hg+].[Hg+]'
	}
);	

# list elements which naturally appear as diatomic or more...
our %multiAtomElements = (1=>2,7=>2,8=>2,9=>2,17=>2,35=>2,53=>2,15=>4);

our %standardIons = (1=>1,3=>1,4=>2,6=>-4,7=>-3,8=>-2,9=>-1,11=>1,12=>2,13=>3,15=>-3,16=>-2,17=>-1,19=>1,20=>2,30=>2,31=>3,34=>-2,35=>-1,37=>1,38=>2,47=>1,48=>2,49=>3,52=>-2,53=>-1,55=>1,56=>2);

# cat: 0 = nonmetal, 1 = metalloid, 2 = metal
our %elementProperties = (1 => {'cat' => 0},2 => {'cat' => 2},3 => {'cat' => 2},4 => {'cat' => 2},5 => {'cat' => 1},6 => {'cat' => 0},7 => {'cat' => 0},8 => {'cat' => 0},9 => {'cat' => 0},10 => {'cat' => 2},11 => {'cat' => 2},12 => {'cat' => 2},13 => {'cat' => 2},14 => {'cat' => 1},15 => {'cat' => 0},16 => {'cat' => 0},17 => {'cat' => 0},18 => {'cat' => 2},19 => {'cat' => 2},20 => {'cat' => 2},21 => {'cat' => 2},22 => {'cat' => 2},23 => {'cat' => 2},24 => {'cat' => 2},25 => {'cat' => 2},26 => {'cat' => 2},27 => {'cat' => 2},28 => {'cat' => 2},29 => {'cat' => 2},30 => {'cat' => 2},31 => {'cat' => 2},32 => {'cat' => 1},33 => {'cat' => 1},34 => {'cat' => 0},35 => {'cat' => 0},36 => {'cat' => 2},37 => {'cat' => 2},38 => {'cat' => 2},39 => {'cat' => 2},40 => {'cat' => 2},41 => {'cat' => 2},42 => {'cat' => 2},43 => {'cat' => 2},44 => {'cat' => 2},45 => {'cat' => 2},46 => {'cat' => 2},47 => {'cat' => 2},48 => {'cat' => 2},49 => {'cat' => 2},50 => {'cat' => 2},51 => {'cat' => 1},52 => {'cat' => 1},53 => {'cat' => 0},54 => {'cat' => 2},55 => {'cat' => 2},56 => {'cat' => 2},57 => {'cat' => 2},58 => {'cat' => 2},59 => {'cat' => 2},60 => {'cat' => 2},61 => {'cat' => 2},62 => {'cat' => 2},63 => {'cat' => 2},64 => {'cat' => 2},65 => {'cat' => 2},66 => {'cat' => 2},67 => {'cat' => 2},68 => {'cat' => 2},69 => {'cat' => 2},70 => {'cat' => 2},71 => {'cat' => 2},72 => {'cat' => 2},73 => {'cat' => 2},74 => {'cat' => 2},75 => {'cat' => 2},76 => {'cat' => 2},77 => {'cat' => 2},78 => {'cat' => 2},79 => {'cat' => 2},80 => {'cat' => 2},81 => {'cat' => 2},82 => {'cat' => 2},83 => {'cat' => 2},84 => {'cat' => 2},85 => {'cat' => 1},86 => {'cat' => 2},87 => {'cat' => 2},88 => {'cat' => 2},89 => {'cat' => 2},90 => {'cat' => 2},91 => {'cat' => 2},92 => {'cat' => 2},93 => {'cat' => 2},94 => {'cat' => 2},95 => {'cat' => 2},96 => {'cat' => 2},97 => {'cat' => 2},98 => {'cat' => 2},99 => {'cat' => 2},100 => {'cat' => 2},101 => {'cat' => 2},102 => {'cat' => 2},103 => {'cat' => 2},104 => {'cat' => 2},105 => {'cat' => 2},106 => {'cat' => 2},107 => {'cat' => 2},108 => {'cat' => 2},109 => {'cat' => 2},110 => {'cat' => 2},111 => {'cat' => 2},112 => {'cat' => 2},113 => {'cat' => 2},114 => {'cat' => 2},115 => {'cat' => 2},116 => {'cat' => 2},117 => {'cat' => 1},118 => {'cat' => 2},119 => {'cat' => 2});

our %namedRecognitionTargets = ('hydrogen' => {'atomNum' => 1},'helium' => {'atomNum' => 2},'lithium' => {'atomNum' => 3},'beryllium' => {'atomNum' => 4},'boron' => {'atomNum' => 5},'carbon' => {'atomNum' => 6},'nitrogen' => {'atomNum' => 7},'oxygen' => {'atomNum' => 8},'fluorine' => {'atomNum' => 9},'neon' => {'atomNum' => 10},'sodium' => {'atomNum' => 11},'magnesium' => {'atomNum' => 12},'aluminium' => {'atomNum' => 13},'silicon' => {'atomNum' => 14},'phosphorus' => {'atomNum' => 15},'sulfur' => {'atomNum' => 16},'chlorine' => {'atomNum' => 17},'argon' => {'atomNum' => 18},'potassium' => {'atomNum' => 19},'calcium' => {'atomNum' => 20},'scandium' => {'atomNum' => 21},'titanium' => {'atomNum' => 22},'vanadium' => {'atomNum' => 23},'chromium' => {'atomNum' => 24},'manganese' => {'atomNum' => 25},'iron' => {'atomNum' => 26},'cobalt' => {'atomNum' => 27},'nickel' => {'atomNum' => 28},'copper' => {'atomNum' => 29},'zinc' => {'atomNum' => 30},'gallium' => {'atomNum' => 31},'germanium' => {'atomNum' => 32},'arsenic' => {'atomNum' => 33},'selenium' => {'atomNum' => 34},'bromine' => {'atomNum' => 35},'krypton' => {'atomNum' => 36},'rubidium' => {'atomNum' => 37},'strontium' => {'atomNum' => 38},'yttrium' => {'atomNum' => 39},'zirconium' => {'atomNum' => 40},'niobium' => {'atomNum' => 41},'molybdenum' => {'atomNum' => 42},'technetium' => {'atomNum' => 43},'ruthenium' => {'atomNum' => 44},'rhodium' => {'atomNum' => 45},'palladium' => {'atomNum' => 46},'silver' => {'atomNum' => 47},'cadmium' => {'atomNum' => 48},'indium' => {'atomNum' => 49},'tin' => {'atomNum' => 50},'antimony' => {'atomNum' => 51},'tellurium' => {'atomNum' => 52},'iodine' => {'atomNum' => 53},'xenon' => {'atomNum' => 54},'cesium' => {'atomNum' => 55},'barium' => {'atomNum' => 56},'lanthanum' => {'atomNum' => 57},'cerium' => {'atomNum' => 58},'praseodymium' => {'atomNum' => 59},'neodymium' => {'atomNum' => 60},'promethium' => {'atomNum' => 61},'samarium' => {'atomNum' => 62},'europium' => {'atomNum' => 63},'gadolinium' => {'atomNum' => 64},'terbium' => {'atomNum' => 65},'dysprosium' => {'atomNum' => 66},'holmium' => {'atomNum' => 67},'erbium' => {'atomNum' => 68},'thulium' => {'atomNum' => 69},'ytterbium' => {'atomNum' => 70},'lutetium' => {'atomNum' => 71},'hafnium' => {'atomNum' => 72},'tantalum' => {'atomNum' => 73},'tungsten' => {'atomNum' => 74},'rhenium' => {'atomNum' => 75},'osmium' => {'atomNum' => 76},'iridium' => {'atomNum' => 77},'platinum' => {'atomNum' => 78},'gold' => {'atomNum' => 79},'mercury' => {'atomNum' => 80},'thallium' => {'atomNum' => 81},'lead' => {'atomNum' => 82},'bismuth' => {'atomNum' => 83},'polonium' => {'atomNum' => 84},'astatine' => {'atomNum' => 85},'radon' => {'atomNum' => 86},'francium' => {'atomNum' => 87},'radium' => {'atomNum' => 88},'actinium' => {'atomNum' => 89},'thorium' => {'atomNum' => 90},'protactinium' => {'atomNum' => 91},'uranium' => {'atomNum' => 92},'neptunium' => {'atomNum' => 93},'plutonium' => {'atomNum' => 94},'americium' => {'atomNum' => 95},'curium' => {'atomNum' => 96},'berkelium' => {'atomNum' => 97},'californium' => {'atomNum' => 98},'einsteinium' => {'atomNum' => 99},'fermium' => {'atomNum' => 100},'mendelevium' => {'atomNum' => 101},'nobelium' => {'atomNum' => 102},'lawrencium' => {'atomNum' => 103},'rutherfordium' => {'atomNum' => 104},'dubnium' => {'atomNum' => 105},'seaborgium' => {'atomNum' => 106},'bohrium' => {'atomNum' => 107},'hassium' => {'atomNum' => 108},'meitnerium' => {'atomNum' => 109},'darmstadtium' => {'atomNum' => 110},'roentgenium' => {'atomNum' => 111},'copernicium' => {'atomNum' => 112},'nihonium' => {'atomNum' => 113},'flerovium' => {'atomNum' => 114},'moscovium' => {'atomNum' => 115},'livermorium' => {'atomNum' => 116},'tennessine' => {'atomNum' => 117},'oganesson' => {'atomNum' => 118},'ununennium' => {'atomNum' => 119},
	'fluoride'=>{'atomNum'=>9,'charge'=>-1}, 'chloride'=>{'atomNum'=>17,'charge'=>-1}, 'bromide'=>{'atomNum'=>35,'charge'=>-1}, 'iodide'=>{'atomNum'=>53,'charge'=>-1},
	'oxide'=>{'atomNum'=>8,'charge'=>-2},'sulfide'=>{'atomNum'=>16,'charge'=>-2},'selenide'=>{'atomNum'=>34,'charge'=>-2},'telluride'=>{'atomNum'=>52,'charge'=>-2},
	'nitride'=>{'atomNum'=>7,'charge'=>-3},'phosphide'=>{'atomNum'=>15,'charge'=>-3},'arsenide'=>{'atomNum'=>33,'charge'=>-3},'antimonide'=>{'atomNum'=>51,'charge'=>-3},
	'hydride'=>{'atomNum'=>1,'charge'=>-1}
	);

our %commonNames = (
	'water' => {
		'chemical'=> [{'atomNum'=>1,'count'=>2,'charge'=>0},{'atomNum'=>8,'count'=>1,'charge'=>0}],
		'TeX'=>'H_2O',
		'SMILES'=>'O'
	},
	'ammonia' => {
		'chemical'=> [{'atomNum'=>7,'count'=>1,'charge'=>0},{'atomNum'=>1,'count'=>3,'charge'=>0}],
		'TeX'=>'NH_3',
		'SMILES'=>'N'
	}
);

# merge polyatomics into namedRecognitionTargets
%namedRecognitionTargets = (%namedRecognitionTargets, %polyatomicIons, %commonNames);

our %romanNumerals = (1=> 'I', 2=>'II', 3=>'III', 4=>'IV', 5=>'V', 6=>'VI', 7=>'VII', 8=>'VIII', 9=> 'IX', 10=>'X');
our %prefixesCovalent = (1=> 'mono', 2=>'di', 3=>'tri', 4=>'tetra', 5=>'penta', 6=>'hexa', 7=>'hepta', 8=>'octa', 9=> 'nona', 10=>'deca');

sub new {
  	#warn "new";
    my $self = shift; my $class = ref($self) || $self;
	my $context = (Value::isContext($_[0]) ? shift : $self->context);
    my $x = shift; $x = [$x,@_] if scalar(@_) > 0; 

	my $options = shift;

    $x = [$x] unless ref($x) eq 'ARRAY';
    my $argCount = @$x;

    # unless ($argCount > 2){
    #     die "Only one or two arguments.";
    # }


	my $requireFormula=0;
	my $requireName=0;

	# a problem may require an answer as a formula or a name
	if (defined($self->context->flags->get('requireFormula'))){
		$requireFormula = $self->context->flags->get('requireFormula');
	}
	if (exists $options->{requireFormula}) {
		$requireFormula = $options->{requireFormula};
	}

	if (defined($self->context->flags->get('requireName'))){
		$requireName = $self->context->flags->get('requireName');
	}
	if (exists $options->{requireName}) {
		$requireName = $options->{requireName};
	}

	if ($requireFormula && $requireName){
		die "You can't set both formula and name as required.";
	}

	my $outputType = $requireName ? 1 : ($requireFormula ? 2 : 0);
	
    my $result = parseValue($x->[0]);
	$chemical = $result->{chemical};

	
	# foreach $t (@$chemical){
	# 	warn %$t;
	# }
	
	if (defined $result->{leading}){
		$leading = $result->{leading}; # for units where mol precedes the chemical and we want to return it.
	} else {
		$leading = undef;
	}
	
	if (defined $result->{commonName}){
		$commonName = $result->{commonName}; # for units where mol precedes the chemical and we want to return it.
	} else {
		$commonName = undef;
	}


	bless {data => $chemical, bonding => $result->{bonding}, leading => $leading, nameInputed => $result->{nameInputed}, commonName=>$commonName, outputType=> $outputType , context => $context}, $class;
}

sub parseValue {
  
	my $x = shift;
	
	#warn '/' . $x . '/';
	if (! defined $x || $x eq '' || $x =~ /^\s*$/) {
		return {chemical=>[], nameInputed=>0, bonding=>0};
	}
	#no warnings "numeric";
	my @result;
	$result[1] = 0;
	
	my $nameInputed=0;

    my $compare = sub { 
	   return length($_[1]) < length($_[0]) if length($_[0]) != length($_[1]); 
	   my $cmp = $_[0] cmp $_[1];
	   if ($cmp == 1) {
		   return 0;
	   } else {
		   return 1;
	   }
	};

	my @symbols = (@elements, keys %polyatomicFormulaVariations);

	#foreach my $t (keys %additionalVariants){
	$symbolsResult = join('|', main::PGsort( $compare, @symbols));

	my @names = keys %namedRecognitionTargets;
	my $namesResult = join('|', main::PGsort( $compare, @names));
	#warn $symbolsResult;
	my @chemical;
	my $leadingUnknown = undef;

	# 0=unknown, 1=ionic, 2=covalent (used for the purpose of writing formulas and names)
	my $bonding=0;

	# We'll use this to break out of all parsing and just replace the name with the prestored chemical.
	my $commonName=0;
	
	# these are possible words that appear after a chemical.  In a capture group because it is necessary
	# for certain ions.  i.e. potassium ion (K^+) vs potassium (K).  For others, it's optional but there just in case.
	my $trailingWords = 'ions|ion|atoms|atom|molecules|molecule|formula units|fu|f\.u\.';
	# 1. Check if contains names. Case will not matter.
	# 2. If no names, then case DOES matter and check element symbols
	# warn "processing $x";
	
	while($x =~ /(.*?)(mono|mon|di|tri|tetra|tetr|penta|pent|hexa|hex|hepta|hept|octa|oct|nona|non|deca|dec)?($namesResult)(?:\s*)(?:\()?(\b(?:VIII|III|VII|II|IV|IX|VI|I|V|X)\b)?(?:\))?(?:\s*)($trailingWords)?/gi) {  # case insensitive
		my $chemicalPiece = {};
		if ($1){
			$leadingUnknown = $1;
		}
		if ($2){
			my $lower = lc($2);
			if ($lower eq "mono" || $lower eq "mon"){
				$chemicalPiece->{'prefix'} = 1;
			} elsif ($lower eq "di"){
				$chemicalPiece->{'prefix'} = 2;
			} elsif ($lower eq "tri"){
				$chemicalPiece->{'prefix'} = 3;
			} elsif ($lower eq "tetra" || $lower eq "tetr"){
				$chemicalPiece->{'prefix'} = 4;
			} elsif ($lower eq "penta" || $lower eq "pent"){
				$chemicalPiece->{'prefix'} = 5;
			} elsif ($lower eq "hexa" || $lower eq "hex"){
				$chemicalPiece->{'prefix'} = 6;
			} elsif ($lower eq "hepta" || $lower eq "hept"){
				$chemicalPiece->{'prefix'} = 7;
			} elsif ($lower eq "octa" || $lower eq "oct"){
				$chemicalPiece->{'prefix'} = 8;
			} elsif ($lower eq "nona" || $lower eq "non"){
				$chemicalPiece->{'prefix'} = 9;
			} elsif ($lower eq "deca" || $lower eq "dec"){
				$chemicalPiece->{'prefix'} = 10;
			}
		} 
		if ($3){
			$chemicalPiece->{name} = $3;
			$atomNum = $namedRecognitionTargets{$3}->{atomNum};
			$chemicalPiece->{'atomNum'} = $atomNum;
			if (!$2 && exists $namedRecognitionTargets{$3}->{charge}){
				$chemicalPiece->{charge} = $namedRecognitionTargets{$3}->{charge};
				
			}
			if (exists $polyatomicIons{$3}){
				$chemicalPiece->{polyAtomic} = $polyatomicIons{$3};
			} 
			if (exists $commonNames{$3}){
				@chemical = @{$commonNames{$3}->{chemical}};
				$commonName = $3;
				last;
			}
			
		}
		if ($4){
			
			my $upper = uc($4);
			if ($upper eq "I"){
				$chemicalPiece->{'charge'} = 1;
			} elsif ($upper eq "II"){
				$chemicalPiece->{'charge'} = 2;
			} elsif ($upper eq "III"){
				$chemicalPiece->{'charge'} = 3;
			} elsif ($upper eq "IV"){
				$chemicalPiece->{'charge'} = 4;
			} elsif ($upper eq "V"){
				$chemicalPiece->{'charge'} = 5;
			} elsif ($upper eq "VI"){
				$chemicalPiece->{'charge'} = 6;
			} elsif ($upper eq "VII"){
				$chemicalPiece->{'charge'} = 7;
			} elsif ($upper eq "VIII"){
				$chemicalPiece->{'charge'} = 8;
			} elsif ($upper eq "IX"){
				$chemicalPiece->{'charge'} = 9;
			} elsif ($upper eq "X"){
				$chemicalPiece->{'charge'} = 10;
			}
		}
		if ($5) {
			# trailing word present.  For now, we'll track the word ion and add a charge if one is not already present
			if ($5 =~ /ions|ion/){
				unless (exists $chemicalPiece->{charge} 
					|| exists $standardIons{$chemicalPiece->{atomNum}} ){
					$chemicalPiece->{charge} = $standardIons{$chemicalPiece->{atomNum}};
				}
			}
		}
		# in case we want to know if parentheses were omitted, we can add options here.

		push @chemical, $chemicalPiece;		
	}
	
	# if this is true, then we couldn't parse any names.  This chemical is written as a formula.  
	if (scalar @chemical == 0) {

		# formula units will always have no spaces, so first split the leading units (if any) from the formula
		@arr = split ' ', $x;

		#assume last piece is formula
		$y = $arr[scalar @arr - 1];

		splice @arr, scalar @arr - 1, 1;
		$leadingUnknown = join ' ', @arr;
		
		while($y =~ /(?:\(?)($symbolsResult)(?:\)?)(?:_?\{?)([\d₁₂₃₄₅₆₇₈₉₀]*)(?:\}?)(?:\^?\{?)([\d¹²³⁴⁵⁶⁷⁸⁹⁰]*[+\-⁺⁻]?)(?:\}?)/g) {
			my $chemicalPiece = {};
			if ($1){
				# check for polyatomic ions to make parsing simpler... finds' name of polyatomic ion, then gets hash for it
				if (exists $polyatomicFormulaVariations{$1}){
					if (exists $polyatomicIons{$polyatomicFormulaVariations{$1}}){
						my $name = $polyatomicFormulaVariations{$1};
						my $polyatomicIonsRef = \%polyatomicIons;
						my $polyatomic = $polyatomicIonsRef->{$name};
						$chemicalPiece->{atomNum} = $polyatomic->{atomNum};
						$chemicalPiece->{polyAtomicName} = $polyatomicFormulaVariations{$1};
						$chemicalPiece->{polyAtomic} = $polyatomic;
					}
				} else {
					my ($index) = grep { $elements[$_] eq $1 } 0 .. (@elements-1);
					$chemicalPiece->{atomNum} = $index+1;
				}
			}
			if ($2){
				$chemicalPiece->{count} = subscriptReverse($2);
			} else {
				$chemicalPiece->{count} = 1;
			}
			if ($3) {
				my $sign = 1;
				my $value = 1;  #if charge exists, default charge 1
				my $temp = superscriptReverse($3);
				if (index($temp, '+') != -1) {  # if contains a + sign, then $sign is 1
					$sign = 1;
				} elsif (index($temp, '-') != -1) {  #if contains a - sign, then $sign is -1
					$sign = -1;
				} 
				($val) =$temp =~ /(\d)/;
				if (defined $val){
					$value = $val;
				}
				$chemicalPiece->{charge} = $sign*$value;
			}
			push @chemical, $chemicalPiece;
		}
		
		# note: overall charge will be assigned to 2nd component.  There's no mechanism to define charge of overall chemical yet.
		# now let's determine if we have an ionic compound so that we can assign charges , only necessary if binary
		if (scalar @chemical == 4){
			#warn "WOW we can't do this one.";
			#warn $x;
		}

		# binary compound
		if (scalar @chemical == 2){
			my $comp1 = $chemical[0];
			my $comp2 = $chemical[1];
			my $comp1Cat = $elementProperties{$comp1->{atomNum}}->{cat};
			my $comp2Cat = $elementProperties{$comp2->{atomNum}}->{cat};
			unless (defined $comp1Cat){
				if (exists $comp1->{polyAtomic}){
					if ($comp1->{polyAtomic}->{charge} > 0){
						$comp1Cat = 2;
					} else {
						$comp1Cat = 0; #non-metal
					}
				}
			}
			unless (defined $comp2Cat){
				if (exists $comp2->{polyAtomic}){
					if ($comp2->{polyAtomic}->{charge} > 0){
						$comp2Cat = 2;
					} else {
						$comp2Cat = 0; #non-metal
					}
				}
			}
			
			if (($comp1Cat == 0 && $comp2Cat == 2) || ($comp1Cat == 2 && $comp2Cat == 0)){
				# ionic
				$bonding = 1;
				my $chargesDetermined=0;
				my $charge1;
				my $charge2;

				# need to lookup standard charges, but have to also make sure that ratios support them.
				# 1.  find standard charges
				# 2.  compare ratios with charges and see if they total zero
				# 3.  adjust metal charge if type II to match ratio
				# 4.  adjust non-metal otherwise.  i.e. oxygen might be peroxide. 

				if (exists $standardIons{$comp1->{atomNum}}) {
					$charge1 = $standardIons{$comp1->{atomNum}};
				} 
				if ( ! defined $charge1 && exists $comp1->{polyAtomic}){
					#try polyatomic
					$charge1 = $comp1->{polyAtomic}->{charge};
				}
				if (exists $standardIons{$comp2->{atomNum}}) {
					$charge2 = $standardIons{$comp2->{atomNum}};
				} 
				if (! defined $charge2 && exists $comp2->{polyAtomic}){
					#try polyatomic
					$charge2 = $comp2->{polyAtomic}->{charge};
				}

				# if metal is Type II
				if (!$chargesDetermined && !$charge1){
					$charge1 = abs($comp2->{count} * $charge2 / $comp1->{count});
					$comp1->{charge} = $charge1;
					$chargesDetermined = 1;
				}

				if ($charge1 && $charge2){ 
					if ($comp1->{count} * $charge1 + $comp2->{count} * $charge2 == 0){
						$chargesDetermined=1;
						$comp1->{charge} = $charge1;
						$comp2->{charge} = $charge2;
					}
					else
					{
						# charges + count don't add up to a neutral molecule
						# check for unique polyatomics like peroxide.... need a list.
						# peroxide check
						if ($comp2->{atomNum} == 8 && $comp2->{count} == 2) {
							my $peroxide = $polyatomicIons{'peroxide'};
							if ($comp1->{count} * $charge1 + 1 * $peroxide->{charge} == 0){
								$chargesDetermined=1;
								$comp1->{charge} = $charge1;
								$comp2->{atomNum} = $peroxide->{atomNum};
								$comp2->{charge}= $peroxide->{charge};
								$comp2->{count} = 1;
							}
						}
						#warn "peroxide maybe?";
					}
				} else {
					#warn "STILL NO CHARGES";
				}


				# $lcmultiple = lcm($charge1,$charge2);
				# $comp1->{count}= abs($lcmultiple/$charge1);
				# $comp2->{count} = abs($lcmultiple/$charge2);
			} else {
				#covalent! (not ionic)
				$bonding=2;
			}
		} elsif (scalar @chemical == 1) {  # from formula
			# Need some disambiguation here.  NO_2 will identify as nitrite immediately.  But it could be nitrogen dioxide (neutral)
			# The {similar} key on {polyatomic} will list the neutral version of the polyatomic ion formula.	
			
			if (exists $chemical[0]->{polyAtomic}){
				unless (defined $chemical[0]->{charge}){
					if (exists $chemical[0]->{polyAtomic}->{alternate}){
						#warn "found";
						$newChemical = $chemical[0]->{polyAtomic}->{alternate};
						@chemical = @$newChemical;
					}
				}
			}

		}

	} else {
		$nameInputed = 1;
		# Our chemical comes from names.  Let's try to figure out the numbers of each atom.
		# We will only handle 1 or 2 chemical components (binary max)
		
		# return immediately if this is from a common name
		unless ($commonName) {
			if (scalar @chemical == 1) {
				$piece = $chemical[0];
				# is it an ion or elemental?
				if (!defined $piece->{charge}){
					if (exists $multiAtomElements{$piece->{atomNum}}){
						$piece->{count} = $multiAtomElements{$piece->{atomNum}};
					} else {
						$piece->{count} = 1;
					}
				} else {
					# it's got a charge, so default count 1.  This will work with Hg2 2+ because that's counted as a polyatomic
					$piece->{count} = 1;
				}

			} elsif (scalar @chemical == 2) {
				# binary compound... is it covalent or ionic? while we could check for charges or prefixes, remember that students could be putting in VERY wrong answers,
				# so we need to go back to basics and just see if it's a metal/non-metal combination for ionic or other for covalent.  This is not going to work for identifying the 
				# type of compound (semiconductors and stuff on the borders), but it will work for names to formulas.
				my $comp1 = $chemical[0];
				my $comp2 = $chemical[1];
				my $comp1Cat = $elementProperties{$comp1->{atomNum}}->{cat};
				my $comp2Cat = $elementProperties{$comp2->{atomNum}}->{cat};
				unless (defined $comp1Cat){
					if (exists $comp1->{charge}){
						if ($comp1->{charge} > 0){
							$comp1Cat = 2;
						} else {
							$comp1Cat = 0; #non-metal
						}
					}
				}
				unless (defined $comp2Cat){
					if (exists $comp2->{charge}){
						if ($comp2->{charge} > 0){
							$comp2Cat = 2;
						} else {
							$comp2Cat = 0; #non-metal
						}
					}
				}
				
				if (($comp1Cat == 0 && $comp2Cat == 2) || ($comp1Cat == 2 && $comp2Cat == 0)){
					# ionic
					$bonding = 1;
					#warn 'ionic! ' . $comp1->{atomNum} . '  ' . $comp2->{atomNum} ;
					my $charge1;
					my $charge2;

					if (exists $comp1->{charge}) {
						# type II metal (got charge from roman numeral)
						$charge1 = $comp1->{charge};
					} elsif (exists $standardIons{$comp1->{atomNum}}) {
						# type I metal
						
						$charge1 = $standardIons{$comp1->{atomNum}};
						$comp1->{charge} = $charge1;
					} else {
						# shouldn't really be here.
						#warn "There was no way to determine the charge of the metal. Was the roman numeral missing?";
					}
					if (exists $comp2->{charge}) {
						$charge2 = $comp2->{charge};
					} elsif (exists $standardIons{$comp2->{atomNum}}) {
						$charge2 = $standardIons{$comp2->{atomNum}};
						$comp2->{charge} = $charge2;
					} else {
						# shouldn't really be here.
						#warn "There was no way to determine the charge of the nonmetal. Artificial non-metal maybe?";
					}

					$lcmultiple = lcm($charge1,$charge2);
					if ($charge1 && $charge2){
						$comp1->{count}= abs($lcmultiple/$charge1);
						$comp2->{count} = abs($lcmultiple/$charge2);
					}
				} else {
					# assume covalent for rest
					
					$bonding = 2;
					if (exists $comp1->{prefix}){
						$comp1->{count} = $comp1->{prefix};
					} else {
						$comp1->{count} = 1;
					}
					if (exists $comp2->{prefix}){
						$comp2->{count} = $comp2->{prefix};
					} else {
						#warn "This shouldn't happen. If it does, it is a student mistake and will create an unexpected molecule.";
						$comp2->{count} = 1;
					}
				}
			} else {
				#warn "Can't handle three component compounds.";
			}
		}
	}
	# add pauling electronegativities and valence to chemical array
	foreach (@chemical){
		$_->{enPauling} = $paulingElectronegativities[$_->{atomNum} - 1];
		$_->{valence} = $valenceStandardMap{$_->{atomNum}};
	}
	
	$result = {chemical=>\@chemical, nameInputed=>$nameInputed, bonding=>$bonding};

	if (defined $leadingUnknown){
		$result->{leading} = $leadingUnknown;
		#return {chemical=>\@chemical, leading=>$leadingUnknown, nameInputed=>$nameInputed, bonding=>$bonding};
	}
	if ($commonName){
		$result->{commonName} = $commonName;
	}	
	#return {chemical=>\@chemical, nameInputed=>$nameInputed, bonding=>$bonding};
	return $result;
}

sub lcm {
	my $a = shift;
	my $b = shift;

	if ($a == 0 || $b == 0){
		return 0;
	}
	return ($a * $b) / gcd($a,$b);
}

sub gcd {
	my $a = shift;
	my $b = shift;

	my $rem = 0;
	while ($b != 0){
		$rem = $a % $b;
		$a = $b;
		$b = $rem;
	}
	return $a;
}

sub guid {
	# for now, we'll use the string as the guid, but this won't work for future versions where isomers can be distinguished.
	my $self = shift;
	return $self->string({asFormula=>1});
}

sub isElement {
	my $self = shift;
	my $options = shift;
	# each item in data can be a polyatomic, not just an element.  Need to parse through.
	my %uniqueElements = ();
	foreach my $component (@{$self->{data}}) {
		# check if atomNum is an array...
		if (ref $component->{atomNum} eq 'ARRAY'){
			# This part is a mess mostly due to weirdos like O_2.  This gets detected as peroxide (same formula), but without a charge.
			foreach my $subComponent (@{$component->{atomNum}}) {
				unless (exists $uniqueElements{$subComponent}){
					$uniqueElements{$subComponent} = 1;

				}
				
			}
		} else {
			unless (exists $uniqueElements{$component->{atomNum}}){
				$uniqueElements{$component->{atomNum}} = 1;
			}
		}
	}
	if (defined $options && exists $options->{returnElement} && $options->{returnElement} == 1){
		if (scalar keys %uniqueElements == 1){
			my $element = (keys %uniqueElements)[0];
			return $element;
		} else {
			return 0;
		}
	} else {
		return scalar keys %uniqueElements == 1;
	}
}

sub standardState {
	my $self = shift;
	my $elementNum = $self->isElement({returnElement=>1});
	if (defined $elementNum){
		my $state = $stateOfMatter[$elementNum-1];
		if ($state == 0){
			return "Solid";
		} elsif ($state == 1){
			return "Liquid";
		} elsif ($state == 2){
			return "Gas";
		} else {
			return "Unknown";
		}
	} else {
		return "Unknown";
	}
}

sub meltingPoint {
	my $self = shift;
	my $elementNum = $self->isElement({returnElement=>1});
	if (defined $elementNum){
		my $mp = $meltingPoints[$elementNum-1];
		return $mp;
	} else {
		return -1;
	}
}

sub boilingPoint {
	my $self = shift;
	my $elementNum = $self->isElement({returnElement=>1});
	if (defined $elementNum){
		my $bp = $boilingPoints[$elementNum-1];
		return $bp;
	} else {
		return -1;
	}
}

# This is a convenience method for problem writers, but you should provide these values to students!  Using a periodic table 
# from other sources could introduce differences in precision that could cause rounding or precision errors later on. 
# Value is returned as an InexactValue if that package is loaded.  While atomic masses in array above are numbers, they will
# be treated as strings and sig figs determined that way.
sub molarMass {
	my $self = shift;
	
	if (InexactValue::InexactValue->can('new')){
		my $mass = InexactValue::InexactValue->new(0,Inf);
		foreach my $component (@{$self->{data}}) {
			# remember atomicMasses is zero-index but atomNum is actual
			$mass += (InexactValue::InexactValue->new(@atomicMasses[$component->{atomNum}-1]) * $component->{count});
		}
		return $mass;
		
	} else {
		my $mass = 0;
		foreach my $component (@{$self->{data}}) {
			# remember atomicMasses is zero-index but atomNum is actual
			$mass += (@atomicMasses[$component->{atomNum}-1] * $component->{count});
		}
		return $mass;
	}
}

sub compareAtomNums {
	my $a1r = shift;
	my $a2r = shift;
	if (!defined($a1r) || !defined($a2r)){
		return 0;
	}
	
	if (ref($a1r) eq 'ARRAY' && ref($a2r) ne 'ARRAY'){
		return 0;
	}
	if (ref($a1r) ne 'ARRAY' && ref($a2r) eq 'ARRAY'){
		return 0;
	}
	if (ref($a1r) ne 'ARRAY' && ref($a2r) ne 'ARRAY'){
		return $a1r eq $a2r;
	}

	my @a1 = @$a1r; #create copy of array
	my @a2 = @$a2r;
	if (scalar @a1 != scalar @a2){
		return 0;
	}
	
	my $found=0;
	for (my $i=scalar @a1 - 1; $i>=0; $i--){
		for (my $j=scalar @a2 -1; $j>=0; $j--){
			if ($a1[$i] == $a2[$j]){

				splice(@a2, $j,1);
				splice(@a1, $i,1);								
				last;
			}
		}
	}

	if (scalar @a1 == 0 && scalar @a2 == 0){
		return 1;
	} else {
		return 0;
	}
}

sub asNameString {
	my $self =shift;
	return $self->string({'asName'=>1});
}
sub asNameTeX {
	my $self =shift;
	return $self->TeX({'asName'=>1});
}
sub asFormulaString {
	my $self =shift;
	return $self->string({'asFormula'=>1});
}
sub asFormulaTeX {
	my $self =shift;
	return $self->TeX({'asFormula'=>1});
}

# method for debugging, do not use!
sub printRef {
	$hashRef = shift;
	%hash = %$hashRef;
	foreach my $key (keys %hash){
		if (defined($hash{$key})){
			warn $key . ' : ' . $hash{$key};
		} else {
			warn $key . ' : ' . 'undefined';
		}
		
	}
}

sub string {
	my $self = shift;
	my $options = shift;
	my $text = '';
	my $overallCharge = 0;

	# default return what was entered, but override with options
	my $nameOutput = $self->{nameInputed};
	if (exists $options->{asFormula}){
		$nameOutput = 0;
	}
	if (exists $options->{asName}){
		$nameOutput = 1;
	}

	if ($nameOutput == 1 && defined $self->{commonName}){
		# skip the logic below and just return the common name
		return $self->{commonName};
	}


	my $index=0;
	foreach my $component (@{$self->{data}}) {
		if ($nameOutput){
			# write name!
			my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) 
				&& ((exists $component->{charge}) 
					? ((exists $namedRecognitionTargets{$_}->{charge}) ? $namedRecognitionTargets{$_}->{charge} == $component->{charge} : 0 ) 
					: ((exists $namedRecognitionTargets{$_}->{charge}) ? 0 : 1)) } 
				keys %namedRecognitionTargets;
			if (scalar @allMatches > 0){
				if (scalar @allMatches > 1){
					#warn "There shouldn't be more than 1 match. ";
				}
				$match = $allMatches[0];
				if ($text =~ /\S$/g){
					$text .= " ";
				}

				my $elementName = '';
				# If covalent and 2nd component
				# need to use the ide version of the nonmetal.  This algorithm only gets the element name since it has no charge.
				if ($self->{bonding} == 2 && $index == 1){
					if (exists($component->{name})){
						$elementName = $component->{name};
					}else {
						my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) 
							&&  exists $namedRecognitionTargets{$_}->{charge} } 
							keys %namedRecognitionTargets;
						if (scalar @allMatches > 1){
							#warn "There shouldn't be more than 1 match. ";
						}
						$match = $allMatches[0];
						$elementName = $match;
					}
				} else {
					$elementName = $match;
				}

				#if covalent, use prefix
				if ($self->{bonding} == 2){
					# only use it if not 1 for 1st element
					if (exists($component->{prefix})){
						my $prefix = $prefixesCovalent{$component->{prefix}};
						# check if ending of prefix and beginning of element are a letter combination where a vowel must be dropped
						# i.e. mono oxide => monoxide,  tetra oxide => tetroxide
						# this happens with mono, tetra, penta, hexa (this one is weird), septa, octa, nona, deca
						# only if element begins with 'o'
						if ($elementName =~ /^o/){
							$prefix =~ s/[ao]$//g;
						}
						$text .= $prefix;
					} elsif ($index > 0 || $component->{count} > 1){
						my $prefix = $prefixesCovalent{$component->{count}};
						# check if ending of prefix and beginning of element are a letter combination where a vowel must be dropped
						# i.e. mono oxide => monoxide,  tetra oxide => tetroxide
						# this happens with mono, tetra, penta, hexa (this one is weird), septa, octa, nona, deca
						# only if element begins with 'o'
						if ($elementName =~ /^o/){
							$prefix =~ s/[ao]$//g;
						}
						$text .= $prefix;
					}
				} 

				$text .= $elementName;
				
			} else {
				# no matches.  sodium in sodium chloride won't match because "sodium" has no charge as the default element,
				# but the compound version does.  Need to relax charge restrictions
				# Only metal ions here.
				my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) } keys %namedRecognitionTargets;
				if (scalar @allMatches > 0){
					if (scalar @allMatches > 1){
						#warn "There shouldn't be more than 1 match. ";
					}
					$match = $allMatches[0];
					if ($text =~ /\S$/g){
						$text .= " ";
					}
					$text .= "$match";
				}
				# check if type II metal by checking if metal has common ion (type I).  If type II, add roman numeral charge
				# we can ignore polyatomics (they have an array for atomic number)
				if (ref($component->{atomNum}) ne 'ARRAY'){
					if (!exists $standardIons{$component->{atomNum}}){
						#warn $match . ' is type II';
						$text .= ' (' . $romanNumerals{$component->{charge}} . ')';
					}
				}
				$component->{atomNum}
			}


		} else {
			# write formula!
			#warn @{$self->{data}};
			#warn ref($component);
			#warn %{$component};
			#warn $component;
			
			if (exists $component->{charge}) {
				$overallCharge += $component->{charge} * $component->{count};
			}
			if (exists($component->{atomNum}) && ref($component->{atomNum}) eq 'ARRAY'){
				# polyatomic will NOT be present for peroxide.  
				#printRef($component);
				if (exists $component->{polyAtomic}) {
					$polyatomic = $component->{polyAtomic}->{TeX};
					$polyatomic =~ s/\^.*//g; # removing these because it's in a compound.  We don't show charge.
					$polyatomic =~ s/\_//g;
					#printRef($component->{polyAtomic});
					$polyatomic = subscript($polyatomic);
					if ($component->{count} > 1){
						#warn 'more than 1  ' . $polyatomic;
						$text .= "($polyatomic)";
					} else {
						#warn 'only 1  ' . $polyatomic;
						$text .= $polyatomic;
					}
				} else {
					# edge case peroxide
					$text .= 'O' . subscript(2);
				}
			}else{
				$text .= @elements[$component->{atomNum}-1];
			}
			if ($component->{count} > 1) {
				$text .= subscript($component->{count});
			}
			#warn $text;
		}

		$index++;
	}
	if ($overallCharge != 0){
		# $overallCharge is only being checked in formula writing
		my $sign = $overallCharge > 0 ? "⁺" : "⁻"; #these are unicode superscript + and -
		my $value = '';
		if (abs($overallCharge) != 1){
			$value = abs($overallCharge);
		}
		$text .= superscript("$value$sign");
	}
	if ($nameOutput 
		&& scalar @{$self->{data}} == 1 
		&& exists $self->{data}->[0]->{charge} 
		&& $self->{data}->[0]->{charge} != 0
		#&& exists($standardIons{$self->{data}->[0]->{atomNum}}) ){
	){
		# if one component and is a cation without a roman numeral, MUST put "ion" after name
		#printRef($self->{data}->[0]);
		$text .= " ion";
	}
	

		




	return $text;
}


sub TeX {
	my $self = shift;
	my $options = shift;
	my $text = '\\mathrm{';
	my $overallCharge=0;
	my $nameOutput = $self->{nameInputed};
	if (exists $options->{asFormula}){
		$nameOutput = 0;
	}
	if (exists $options->{asName}){
		$nameOutput = 1;
	}
	if ($nameOutput == 1 && defined $self->{commonName}){
		return '\\mathrm{' . $self->{commonName} . '}';
	}


	my $index=0;
	foreach my $component (@{$self->{data}}) {
		if ($nameOutput){
			# write name!
			my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) 
				&& ((exists $component->{charge}) 
					? ((exists $namedRecognitionTargets{$_}->{charge}) ? $namedRecognitionTargets{$_}->{charge} == $component->{charge} : 0 ) 
					: ((exists $namedRecognitionTargets{$_}->{charge}) ? 0 : 1)) } 
				keys %namedRecognitionTargets;
			if (scalar @allMatches > 0){
				if (scalar @allMatches > 1){
					#warn "There shouldn't be more than 1 match. ";
				}
				$match = $allMatches[0];
				
				if ($index > 0 && $text =~ /\S$/g){
					$text .= '\\ ';
				}

				my $elementName = '';
				# If covalent and 2nd component
				# need to use the ide version of the nonmetal.  This algorithm only gets the element name since it has no charge.
				if ($self->{bonding} == 2 && $index == 1){
					if (exists($component->{name})){
						$elementName = $component->{name};
					}else {
						my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) 
							&&  exists $namedRecognitionTargets{$_}->{charge} } 
							keys %namedRecognitionTargets;
						if (scalar @allMatches > 1){
							#warn "There shouldn't be more than 1 match. ";
						}
						$match = $allMatches[0];
						$elementName = $match;
					}
				} else {
					$elementName = $match;
				}

				#if covalent, use prefix
				if ($self->{bonding} == 2){
					# only use it if not 1 for 1st element

					if (exists($component->{prefix})){
						my $prefix = $prefixesCovalent{$component->{prefix}};
						# check if ending of prefix and beginning of element are a letter combination where a vowel must be dropped
						# i.e. mono oxide => monoxide,  tetra oxide => tetroxide
						# this happens with mono, tetra, penta, hexa (this one is weird), septa, octa, nona, deca
						# only if element begins with 'o'
						if ($elementName =~ /^o/){
							$prefix =~ s/[ao]$//g;
						}
						$text .= $prefix;
					} elsif ($index > 0 || $component->{count} > 1){
						my $prefix = $prefixesCovalent{$component->{count}};
						# check if ending of prefix and beginning of element are a letter combination where a vowel must be dropped
						# i.e. mono oxide => monoxide,  tetra oxide => tetroxide
						# this happens with mono, tetra, penta, hexa (this one is weird), septa, octa, nona, deca
						# only if element begins with 'o'
						if ($elementName =~ /^o/){
							$prefix =~ s/[ao]$//g;
						}
						$text .= $prefix;
					}
				} 

				$text .= $elementName;

			} else {
				# no matches.  sodium in sodium chloride won't match because "sodium" has no charge as the default element,
				# but the compound version does.  Need to relax charge restrictions
				# Only metal ions here.
				my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) } 
				keys %namedRecognitionTargets;
				if (scalar @allMatches > 0){
					if (scalar @allMatches > 1){
						#warn "There shouldn't be more than 1 match. ";
					}
					$match = $allMatches[0];
					if ($text =~ /\S$/g){
						$text .= '\\ ';
					}
					$text .= "$match";
				}
				# check if type II metal by checking if metal has common ion (type I).  If type II, add roman numeral charge
				# we can ignore polyatomics (they have an array for atomic number)
				if (ref($component->{atomNum}) ne 'ARRAY'){
					if (!exists $standardIons{$component->{atomNum}}){
						#warn $match . ' is type II';
						$text .= '\\ (' . $romanNumerals{$component->{charge}} . ')';
					}
				}
				$component->{atomNum}
			}
		} else {
			# write formula!
			
			if (exists $component->{charge}) {
				$overallCharge += $component->{charge} * $component->{count};
			}
			if (ref($component->{atomNum}) eq 'ARRAY') {

				# edge case: peroxide won't have polyAtomic if from formula
				if (exists $component->{polyAtomic}) {
					$polyatomic = $component->{polyAtomic}->{TeX};
					$polyatomic =~ s/\^.*//g; # removing these because it's in a compound.  We don't show charge.
					
					if ($component->{count} > 1){
						$text .= "($polyatomic)";
					} else {
						$text .= $polyatomic;
					}
				} else {
					# patch for peroxide (it gets confused with O2 the element so it's not in the match list by default for polyatomics)
					$text .= 'O_2';
				}
			}else{
				$text .= @elements[$component->{atomNum}-1];
			}
			if ($component->{count} > 1) {
				$text .= '_{' . $component->{count} . '}';
			}
		}

		$index++;
	}
	if ($overallCharge != 0){
		my $sign = $overallCharge > 0 ? "+" : "-"; 
		my $value = '';
		if (abs($overallCharge) != 1){
			$value = abs($overallCharge);
		}
		$text .= "^{$value$sign}";
	}

	$text .= '}';
	return $text;
}

sub subscript{
	my $value = shift;
	$value =~ s/1/₁/g;
	$value =~ s/2/₂/g;
	$value =~ s/3/₃/g;
	$value =~ s/4/₄/g;
	$value =~ s/5/₅/g;
	$value =~ s/6/₆/g;
	$value =~ s/7/₇/g;
	$value =~ s/8/₈/g;
	$value =~ s/9/₉/g;
	$value =~ s/0/₀/g;
	return $value;
}

sub subscriptReverse{
	my $value = shift;
	$value =~ s/₁/1/g;
	$value =~ s/₂/2/g;
	$value =~ s/₃/3/g;
	$value =~ s/₄/4/g;
	$value =~ s/₅/5/g;
	$value =~ s/₆/6/g;
	$value =~ s/₇/7/g;
	$value =~ s/₈/8/g;
	$value =~ s/₉/9/g;
	$value =~ s/₀/0/g;
	return $value;
}

sub superscript{
	my $value = shift;	
	$value =~ s/1/¹/g;
	$value =~ s/2/²/g;
	$value =~ s/3/³/g;
	$value =~ s/4/⁴/g;
	$value =~ s/5/⁵/g;
	$value =~ s/6/⁶/g;
	$value =~ s/7/⁷/g;
	$value =~ s/8/⁸/g;
	$value =~ s/9/⁹/g;
	$value =~ s/0/⁰/g;
	$value =~ s/\+/⁺/g;
	$value =~ s/\-/⁻/g;
	return $value;
}

sub superscriptReverse{
	my $value = shift;
	$value =~ s/¹/1/g;
	$value =~ s/²/2/g;
	$value =~ s/³/3/g;
	$value =~ s/⁴/4/g;
	$value =~ s/⁵/5/g;
	$value =~ s/⁶/6/g;
	$value =~ s/⁷/7/g;
	$value =~ s/⁸/8/g;
	$value =~ s/⁹/9/g;
	$value =~ s/⁰/0/g;
	$value =~ s/⁺/+/g;
	$value =~ s/⁻/-/g;
	return $value;
}




sub cmp_class {"Chemical"}

sub cmp {
	my $self = shift;
	#warn %$self;
	my $outputType=$self->{outputType};  # 1 is required name, 2 is required formula
	
	my $correct_ans;
	my $correct_ans_latex_string;
	if ($outputType == 1){
		$correct_ans = $self->asNameString;
		$correct_ans_latex_string = $self->asNameTeX;
	} elsif ($outputType == 2){
		$correct_ans = $self->asFormulaString;
		$correct_ans_latex_string = $self->asFormulaTeX;

	} else {
		$correct_ans = $self->string;
		$correct_ans_latex_string = $self->TeX;
	}

	my $cmp = $self->SUPER::cmp(
		correct_ans => $correct_ans,
		correct_ans_latex_string =>  $correct_ans_latex_string,
		@_
	);  

	$cmp->install_pre_filter('erase');
	$cmp->install_pre_filter(sub {
		my $ans = shift;
		$answerBlank = 0;
		
		$test = $ans->{student_ans} ;
		if (!$test){
			#warn "EMPTY";
			$ans->{student_ans} = "";
		}

		$answerBlank = $self->new($ans->{student_ans});

		#warn "ANSWER BLANK:  " . $answerBlank->string ;
		# if ($ans->{student_ans} eq ''){
		# 	#$inexactStudent = $self->new(0,$inf);  #blank answer is zero with infinite sf
		# } else {
			
			
		# }
		#warn "$answerBlank";
		#warn $answerBlank->TeX;
		$ans->{student_value} = $answerBlank;
		$ans->{preview_latex_string} = $answerBlank->TeX;
		$ans->{student_ans} = $answerBlank->string; 

		return $ans;
	});

	return $cmp;
}

sub cmp_parse {
	my $self = shift; my $ans = shift;

	my $outputType= $ans->{correct_value}->{outputType};  # 1 is required name, 2 is required formula
	# if (defined($self->context->flags->get('requireFormula'))){
	# 	$requireFormula = $self->context->flags->get('requireFormula');
	# 	$outputType = 2;
	# }
	# if (defined($self->context->flags->get('requireName'))){
	# 	$requireName = $self->context->flags->get('requireName');
	# 	$outputType = 1;
	# }
	# if ($requireFormula && $requireName){
	# 	die "You can't set both formula and name as required.";
	# }

	my $disorderPenalty = 0.5; # percentage of total.  This should be used for ionic.  Maybe for covalent.
	if (defined($self->context->flags->get('disorderPenalty'))){
		$disorderPenalty = $self->context->flags->get('disorderPenalty');
	}
	my $matchAtomicNumber=0.5;
	if (defined($self->context->flags->get('matchAtomicNumber'))){
		$matchAtomicNumber = $self->context->flags->get('matchAtomicNumber');
	}
	my $matchCount=0.5;
	if (defined($self->context->flags->get('matchCount'))){
		$matchCount = $self->context->flags->get('matchCount');
	}
	my $chargePenalty=0.5;
	if (defined($self->context->flags->get('chargePenalty'))){
		$chargePenalty = $self->context->flags->get('chargePenalty');
	}

	my $correct = $ans->{correct_value};
	my $student = $ans->{student_value};
	$ans->{_filter_name} = "Chemcial answer checker";

	$ans->score(0); # assume failure
	$self->context->clearError();

	$currentCredit = 0;

	$currentCredit = grade(
		$correct, 
		$student, 
		{outputType=>$outputType, disorderPenalty=>$disorderPenalty, matchAtomicNumber=>$matchAtomicNumber, matchCount=>$matchCount, chargePenalty=>$chargePenalty}
	);
		
	$ans->score($currentCredit);

	return $ans;
}

sub grade {
	my $correct = shift;
	my $student = shift;
	my $options = shift;
 
	my $first = $correct->{data};
	my $second = $student->{data};
	my $outputType = $options->{outputType};

	if (scalar @$second == 0){
		#warn "HERE";
		return 0;
	}

	# formula required but student gave name
	if ($outputType == 2 && $student->{nameInputed}){
		return 0;
	}
	# # name required but student gave formula
	if ($outputType == 1 && $student->{nameInputed} == 0){
		return 0;
	}
	# Anything that has more or fewer elements than the correct value is all wrong.
	if (scalar @$first != scalar @$second){
		return 0;
	}

	my @firstCopy = @$first;
	my @secondCopy = @$second; 

	my $totalScore = 0;
	# score per component.  this should be modifiable via context
	my $matchAtomNum=$options->{matchAtomicNumber};
	my $matchCount= $options->{matchCount};
	my $chargePenalty= $options->{chargePenalty};
	my $disorderPenalty = $options->{disorderPenalty};

	my $isDisordered = 0;

	my $firstCharge=0;
	my $secondCharge=0;

	# order matters for chemical formula (and names)
	# option for partial credit if correct, but out of order

	for (my $j=scalar @secondCopy - 1; $j >= 0; $j--){
		for (my $i=scalar @firstCopy - 1; $i >= 0; $i--){
			if (compareAtomNums($secondCopy[$j]->{atomNum}, $firstCopy[$i]->{atomNum})){
				
				$totalScore += $matchAtomNum/(scalar @$first);
				# if second element and not polyatomic, make sure ending was "ide"
				if ($correct->{bonding} != 0 && $i == 1  && exists($secondCopy[$j]->{name}) && !($secondCopy[$j]->{name} =~ /ide$/)){
					#warn "doesn't end with ide";
					$totalScore -= $matchAtomNum/(scalar @$first);
				}

				# now check count
				if ($secondCopy[$j]->{count} == @firstCopy[$i]->{count}){
					# same number!
					# if covalent and first element, make sure no prefix was recorded if only 1 of them.
					unless ($correct->{bonding} == 2 && $i == 0  && exists($secondCopy[$j]->{prefix}) && $secondCopy[$j]->{prefix}==1){
						$totalScore += $matchCount/(scalar @$first); 
					} 
				}

				if (defined $firstCopy[$i]->{charge}){
					$firstCharge += $firstCopy[$i]->{charge};
				}
				if (defined $secondCopy[$j]->{charge}){
					$secondCharge += $secondCopy[$j]->{charge};
				}

				splice(@secondCopy, $j, 1);
				splice(@firstCopy, $i, 1);
				if ($j != $i){
					$isDisordered = 1;
				}
				last;
			}
		}
	}

	# overall charge!
	if ($firstCharge != $secondCharge){
		$totalScore *= $chargePenalty;
	}

	if ($isDisordered){
		$totalScore *= $disorderPenalty;
	}
	
	return $totalScore;
}

1;
