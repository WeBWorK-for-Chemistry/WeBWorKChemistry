HEADER_TEXT(<<END_SCRIPT);

<script src="https://cdnjs.cloudflare.com/ajax/libs/svg.js/3.2.0/svg.min.js" integrity="sha512-EmfT33UCuNEdtd9zuhgQClh7gidfPpkp93WO8GEfAP3cLD++UM1AG9jsTUitCI9DH5nF72XaFePME92r767dHA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>

<!--
<script>
	function processChanges(jsmeEvent) {
		var jsme = jsmeEvent.src;
		var smiles = jsme.smiles();
		var jmeFile = jsme.jmeFile();
		var svg = jsme.getMolecularAreaGraphicsString();
		document.getElementById('jmeFile').value = jmeFile;
		document.getElementById('drawingSMILES').value = smiles;
		document.getElementById('svgString').value = btoa(svg);
	}
    function jsmeOnLoad() {
        jsmeApplet = new JSApplet.JSME("jsme_container", "380px", "340px", {
            "options" : "oldlook,marker"
		});
		jsmeApplet.setCallBack("AfterStructureModified", processChanges);
		var jmeFile = document.getElementById('jmeFile').value;
		jsmeApplet.readMolecule(jmeFile);
	}
	
</script>
-->

END_SCRIPT

sub NchooseK {
    my ( $n, $k ) = @_;
    my @array              = 0 .. ( $n - 1 );
    my @out                = ();
    my $rand_num_generator = new PGrandom();
    while ( @out < $k ) {
        push( @out, splice( @array, random( 0, $#array, 1 ), 1 ) );
    }
    @out;
}

sub processFlowchart {

    #$rand_num_generator = shift;
    $flowchart = shift;

    # get collection of node titles and labels
    my %hashAnswers = ();
    while ( $flowchart =~
        m/(\w*?)(?:(?:\[\()(?:\(\[)|\[|\(|{)(.*?)(?:(?:\]\))(?:\)\])|\]|\)|})/gx
      )
    {
        $hashAnswers{$1} = $2;
    }

    # remove all labels and add class definition to keep nodes wide
    $flowchart =~
s/(\w*?)((?:\[\()(?:\(\[)|\[|\(|{)(.*?)((?:\]\))(?:\)\])|\]|\)|})/$1$2 $4:::wide/g;
    $flowchart .= 'classDef wide padding:40px';
    warn $flowchart;

    # create randomized answers
    my $rand_num_generator = new PGrandom();
    my @keyList            = keys %hashAnswers;
    @keyList = main::PGsort( sub { $_[0] gt $_[1] }, @keyList )
      ;    # sort required because hash is not ordered!
    @shuffled = NchooseK( scalar @keyList, scalar @keyList );
    my @randomizedList = ();
    foreach (@shuffled) {
        push( @randomizedList, $keyList[$_] );
    }

# generate answer key:  key is index shown to students, value is node it belongs to
    %answerKey = ();
    for ( $i = 0 ; $i < @randomizedList ; $i++ ) {
        $answerKey{$i} = $randomizedList[$i];
        warn $randomizedList[$i];
        warn $hashAnswers{ $randomizedList[$i] };
    }

    return ("answerKey", %answerKey, "flowchart", $flowchart);
}

1;
