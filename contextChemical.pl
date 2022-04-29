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
	'O2' => 'peroxide',
	'O_2' => 'peroxide',
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
	'peroxide'=> {
		'atomNum'=> [8,8],
		'charge'=>-2,
		'TeX'=>'O_2^{2-}',
		'SMILES'=>'[O-][O-]'
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
# merge polyatomics into namedRecognitionTargets
%namedRecognitionTargets = (%namedRecognitionTargets, %polyatomicIons);

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
	
	bless {data => $chemical, bonding => $result->{bonding}, leading => $leading, nameInputed => $result->{nameInputed}, outputType=> $outputType , context => $context}, $class;
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
			$atomNum = %namedRecognitionTargets{$3}->{atomNum};
			$chemicalPiece->{'atomNum'} = $atomNum;
			if (!$2 && exists %namedRecognitionTargets{$3}->{charge}){
				$chemicalPiece->{charge} = %namedRecognitionTargets{$3}->{charge};
				
			}
			if (exists $polyatomicIons{$3}){
				$chemicalPiece->{polyAtomic} = $polyatomicIons{$3};
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
				if (exists $polyatomicFormulaVariations{$1}){
					if (exists $polyatomicIons{$polyatomicFormulaVariations{$1}}){
						my $name = $polyatomicFormulaVariations{$1};
						my $polyatomicIonsRef = \%polyatomicIons;
						my $polyatomic = $polyatomicIonsRef->{$name};
						$chemicalPiece->{atomNum} = $polyatomic->{atomNum};
						$chemicalPiece->{polyAtomicName} = $polyatomicFormulaVariations{$1};
						$chemicalPiece->{polyAtomic} = $polyatomic;
						#warn %$chemicalPiece;
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
				my $value = 1;
				my $temp = superscriptReverse($3);
				if (index($temp, '+') != -1) {
					$sign = 1;
				} elsif (index($temp, '-') != -1) {
					$sign = -1;
				} 
				($val) =$temp =~ /(\d)/;
				if (defined $val){
					$value = $val;
				}
				$chemicalPiece->{charge} = $sign*$value;
			}
			#warn %$chemicalPiece;

			push @chemical, $chemicalPiece;
		}
		
		# note: overall charge will be assigned to 2nd component.  There's no mechanism to define charge of overall chemical yet.
		# now let's determine if we have an ionic compound so that we can assign charges , only necessary if binary
		if (scalar @chemical == 4){
			warn "WOOW";
			warn $x;
		}

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
							my $peroxide = %polyatomicIons{'peroxide'};
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
					warn "STILL NO CHARGES";
				}


				# $lcmultiple = lcm($charge1,$charge2);
				# $comp1->{count}= abs($lcmultiple/$charge1);
				# $comp2->{count} = abs($lcmultiple/$charge2);
			} else {
				
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
					warn "There was no way to determine the charge of the metal. Was the roman numeral missing?";
				}
				if (exists $comp2->{charge}) {
					$charge2 = $comp2->{charge};
				} elsif (exists $standardIons{$comp2->{atomNum}}) {
					$charge2 = $standardIons{$comp2->{atomNum}};
					$comp2->{charge} = $charge2;
				} else {
					# shouldn't really be here.
					warn "There was no way to determine the charge of the nonmetal. Artificial non-metal maybe?";
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
			warn "Can't handle three component compounds.";
		}
	}
	#warn "PARSED UNITS $x";
	#foreach $chem (@chemical){
	#		warn %$chem;
	#}
	if (defined $leadingUnknown){
		return {chemical=>\@chemical, leading=>$leadingUnknown, nameInputed=>$nameInputed, bonding=>$bonding};
	}
	return {chemical=>\@chemical, nameInputed=>$nameInputed, bonding=>$bonding};

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

sub compareAtomNums {
	my $a1r = shift;
	my $a2r = shift;
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

sub string {
	my $self = shift;
	my $options = shift;
	my $text = '';
	my $overallCharge=0;
	my $nameOutput = $self->{nameInputed};
	if (exists $options->{asFormula}){
		$nameOutput = 0;
	}
	if (exists $options->{asName}){
		$nameOutput = 1;
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
					warn "There shouldn't be more than 1 match. ";
				}
				$match = $allMatches[0];
				if ($text =~ /\S$/g){
					$text .= " ";
				}

				my $elementName = '';
				# If covalent and 2nd component
				# need to use the ide version of the nonmetal.  This algorithm only gets the element name since it has no charge.
				if ($self->{bonding} == 2 && $index == 1){
					my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) 
						&&  exists $namedRecognitionTargets{$_}->{charge} } 
						keys %namedRecognitionTargets;
					if (scalar @allMatches > 1){
						warn "There shouldn't be more than 1 match. ";
					}
					$match = $allMatches[0];
					$elementName = $match;
				} else {
					$elementName = $match;
				}

				#if covalent, use prefix
				if ($self->{bonding} == 2){
					# only use it if not 1 for 1st element
					if ($index > 0 || $component->{count} > 1){
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
						warn "There shouldn't be more than 1 match. ";
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
			
			if (exists $component->{charge}) {
				$overallCharge += $component->{charge} * $component->{count};
			}
			if (ref($component->{atomNum}) eq 'ARRAY'){
				# warn %$component;
				# warn @{ $component->{atomNum} };
				#warn @{ $component->{atomNum}};
				$polyatomic = $component->{polyAtomic}->{TeX};
				$polyatomic =~ s/\^.*//g; # removing these because it's in a compound.  We don't show charge.
				$polyatomic =~ s/\_//g;
				$polyatomic = subscript($polyatomic);
				if ($component->{count} > 1){
					#warn 'more than 1  ' . $polyatomic;
					$text .= "($polyatomic)";
				} else {
					#warn 'only 1  ' . $polyatomic;
					$text .= $polyatomic;
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
		my $sign = $overallCharge > 0 ? "⁺" : "⁻"; #these are unicode superscript + and -
		my $value = '';
		if (abs($overallCharge) != 1){
			$value = abs($overallCharge);
		}
		$text .= superscript("$value$sign");
	}
	return $text;
}


sub TeX {
	my $self = shift;
	my $options = shift;
	my $text = '\mathrm{';
	my $overallCharge=0;
	my $nameOutput = $self->{nameInputed};
	if (exists $options->{asFormula}){
		$nameOutput = 0;
	}
	if (exists $options->{asName}){
		$nameOutput = 1;
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
					warn "There shouldn't be more than 1 match. ";
				}
				$match = $allMatches[0];
				if ($text =~ /\S$/g){
					$text .= '\ ';
				}

				my $elementName = '';
				# If covalent and 2nd component
				# need to use the ide version of the nonmetal.  This algorithm only gets the element name since it has no charge.
				if ($self->{bonding} == 2 && $index == 1){
					my @allMatches = grep { compareAtomNums($namedRecognitionTargets{$_}->{atomNum}, $component->{atomNum}) 
						&&  exists $namedRecognitionTargets{$_}->{charge} } 
						keys %namedRecognitionTargets;
					if (scalar @allMatches > 1){
						warn "There shouldn't be more than 1 match. ";
					}
					$match = $allMatches[0];
					$elementName = $match;
				} else {
					$elementName = $match;
				}

				#if covalent, use prefix
				if ($self->{bonding} == 2){
					# only use it if not 1 for 1st element
					if ($index > 0 || $component->{count} > 1){
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
						warn "There shouldn't be more than 1 match. ";
					}
					$match = $allMatches[0];
					if ($text =~ /\S$/g){
						$text .= '\ ';
					}
					$text .= "$match";
				}
				# check if type II metal by checking if metal has common ion (type I).  If type II, add roman numeral charge
				# we can ignore polyatomics (they have an array for atomic number)
				if (ref($component->{atomNum}) ne 'ARRAY'){
					if (!exists $standardIons{$component->{atomNum}}){
						#warn $match . ' is type II';
						$text .= '\ (' . $romanNumerals{$component->{charge}} . ')';
					}
				}
				$component->{atomNum}
			}
		} else {
			# write formula!
			
			if (exists $component->{charge}) {
				$overallCharge += $component->{charge} * $component->{count};
			}
			if (ref($component->{atomNum}) eq 'ARRAY'){

				$polyatomic = $component->{polyAtomic}->{TeX};
				$polyatomic =~ s/\^.*//g; # removing these because it's in a compound.  We don't show charge.
				
				if ($component->{count} > 1){
					$text .= "($polyatomic)";
				} else {
					$text .= $polyatomic;
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
				# now check count
				if ($secondCopy[$j]->{count} == @firstCopy[$i]->{count}){
					# same number!
					$totalScore += $matchCount/(scalar @$first); # 
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
