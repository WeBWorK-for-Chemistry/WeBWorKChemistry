use warnings;
use strict;
package main;

use Test::More;
use Test::Exception; # needed only if you test for errors.

## the following needs to include at the top of any testing  down to TOP_MATERIAL

BEGIN {
	die "PG_ROOT not found in environment.\n" unless $ENV{PG_ROOT};
	die "WEBWORK_ROOT not found in environment.\n" unless $ENV{WEBWORK_ROOT};

	$main::pg_dir = $ENV{PG_ROOT};
	$main::webwork_dir = $ENV{WEBWORK_ROOT};

}

use lib "$main::webwork_dir/lib";
use lib "$main::pg_dir/lib";

require("$main::pg_dir/t/build_PG_envir.pl");

loadMacros("MathObjects.pl");
#require "PG.pl";
#require '../contextInexactValueWithUnits.pl';


is(1,1, 'should be 1');
is(2,2,"should be 2");

