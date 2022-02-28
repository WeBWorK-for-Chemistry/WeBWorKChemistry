

# This is the "exported" subroutine.  Use this to evaluate the units given in an answer.

sub evaluate_units {
	&Units::evaluate_units;
}

# Methods for evaluating units in answers
package BetterUnits;

#require Exporter;
#@ISA = qw(Exporter);
#@EXPORT = qw(evaluate_units);


# compound units are entered such as m/sec^2 or kg*m/sec^2
# the format is unit[^power]*unit^[*power].../  unit^power*unit^power....
# there can be only one / in a unit.
# powers can be negative integers as well as positive integers.

    # These subroutines return a unit hash.
    # A unit hash has the entries
    #      factor => number   number can be any real number
    #      m      => power    power is a signed integer
    #      kg     => power
    #      s      => power
    #      rad    => power
    #      degC   => power
    #      degF   => power
    #      degK   => power
    #      mol	  => power
	#	   amp	  => power
	#	   cd	  => power

# Unfortunately there will be no automatic conversion between the different
# temperature scales since we haven't allowed for affine conversions.

our %fundamental_units = ('factor' => 1,
                     'm'      => 0,
                     'kg'     => 0,
                     's'      => 0,
                     'rad'    => 0,
                     'degC'   => 0,
                     'degF'   => 0,
                     'degK'   => 0,
                     'mol'    => 0,  # moles, treated as a fundamental unit
                     'amp'    => 0,
                     'cd'     => 0,  # candela, SI unit of luminous intensity
);


# This hash contains all of the units which will be accepted.  These must
# be defined in terms of the fundamental units given above.  If the power
# of the fundamental unit is not included it is assumed to be zero.

our $PI = 4*atan2(1,1);
#         9.80665 m/s^2  -- standard acceleration of gravity

our %known_units_uk = (
  'fluid ounce'  => {
    'factor'    => 0.0000284130625,
    'm'         => 3
  },
  'fl oz'  => {
    'factor'    => 0.0000284130625,
    'm'         => 3
  },
  'gill'  => {
    'factor'    => 0.0001420653125,
    'm'         => 3
  },
  'gi'  => {
    'factor'    => 0.0001420653125,
    'm'         => 3
  },
  'pint'  => {
    'factor'    => 0.00056826125,
    'm'         => 3
  },
  'pt'  => {
    'factor'    => 0.00056826125,
    'm'         => 3
  },
  'quart'  => {
    'factor'    => 0.0011365225,
    'm'         => 3
  },
  'qt'  => {
    'factor'    => 0.0011365225,
    'm'         => 3
  },
  'gallon'  => {
    'factor'    => 0.00454609,
    'm'         => 3
  },
  'gal'  => {
    'factor'    => 0.00454609,
    'm'         => 3
  },
);

our %known_units = ('m'  => {
                           'factor'    => 1,
                           'm'         => 1
                          },
                
                 's'  => {
                           'factor'    => 1,
                           's'         => 1
                          },
                'rad' => {
                           'factor'    => 1,
                           'rad'       => 1
                          },
               'degC' => {
                           'factor'    => 1,
                           'degC'      => 1
                          },
               'degF' => {
                           'factor'    => 1,
                           'degF'      => 1
                          },
               'degK' => {
                           'factor'    => 1,
                           'degK'      => 1
                          },
               'mol'  => {
                           'factor'    =>1,
                           'mol'       =>1
                         },
                'amp' => {
                           'factor'    => 1,
                           'amp'       => 1,
                         },
                'cd'  => {
                           'factor'    => 1,
                           'cd'        => 1,
                         },
                 '%'  => {
                           'factor'    => 0.01,
                         },
# ANGLES
# deg  -- degrees
# sr   -- steradian, a mesure of solid angle
#
                'deg'  => {
                           'factor'    => 0.0174532925,
                           'rad'       => 1
                          },
              'degree' => {
                           'factor'    => 0.0174532925,
                           'rad'       => 1
                          },
             'degrees' => {
                           'factor'    => 0.0174532925,
                           'rad'       => 1
                          },
              'radian' => {
                           'factor'    => 1,
                           'rad'       => 1
                          },
             'radians' => {
                           'factor'    => 1,
                           'rad'       => 1
                          },
                'sr'  => {
                           'factor'    => 1,
                           'rad'       => 2
                          },
# TIME
# s     -- seconds
# ms    -- miliseconds
# min   -- minutes
# hr    -- hours
# day   -- days
# yr    -- years  -- 365 days in a year
# fortnight	-- (FFF system) 2 weeks
#
                  'sec'  => {
                           'factor'    => 1,
                           's'         => 1
                          },
                  'second'  => {
                           'factor'    => 1,
                           's'         => 1
                          },
                  'seconds'  => {
                           'factor'    => 1,
                           's'         => 1
                          },
                  'min'  => {
                           'factor'    => 60,
                           's'         => 1
                          },
                  'minute'  => {
                           'factor'    => 60,
                           's'         => 1
                          },
                  'minutes'  => {
                           'factor'    => 60,
                           's'         => 1
                          },
                  'hr'  => {
                           'factor'    => 3600,
                           's'         => 1
                          },
                  'hour'  => {
                           'factor'    => 3600,
                           's'         => 1
                          },
                  'hours'  => {
                           'factor'    => 3600,
                           's'         => 1
                          },
                  'h'  => {
                           'factor'    => 3600,
                           's'         => 1
                          },
                  'day'  => {
                           'factor'    => 86400,
                           's'         => 1
                          },
                  'month'  => {
                           'factor'    => 60*60*24*30,
                           's'         => 1
                          },
                  'months'  => {
                           'factor'    => 60*60*24*30,
                           's'         => 1
                          },
                  'mo'  => {
                           'factor'    => 60*60*24*30,
                           's'         => 1
                          },
                  'yr'  => {
                           'factor'    => 31557600,
                           's'         => 1
                          },
                  'fortnight'  => {
                           'factor'    => 1209600,
                           's'         => 1
                          },

# LENGTHS
# m    -- meters
# cm   -- centimeters
# km   -- kilometers
# mm   -- millimeters
# micron -- micrometer
# um   -- micrometer
# nm   -- nanometer
# A    -- Angstrom
#
                 
             'micron'  => {
                           'factor'    => 1E-6,
                           'm'         => 1
                          },
                 
                  'A'  => {
                           'factor'    => 1E-10,
                           'm'         => 1
                          },
				'Å'  => {
                           'factor'    => 1E-10,
                           'm'         => 1
                          },
# ENGLISH LENGTHS
# in    -- inch
# ft    -- feet
# mi    -- mile
# furlong -- (FFF system) 0.125 mile
# light-year
# AU	-- Astronomical Unit
# parsec
#
                 'in'  => {
                           'factor'    => 0.0254,
                           'm'         => 1
                          },
                 'inch'  => {
                           'factor'    => 0.0254,
                           'm'         => 1
                          },
                 'inches'  => {
                           'factor'    => 0.0254,
                           'm'         => 1
                          },
                 'ft'  => {
                           'factor'    => 0.3048,
                           'm'         => 1
                          },
                 'feet'  => {
                           'factor'    => 0.3048,
                           'm'         => 1
                          },
                 'foot'  => {
                           'factor'    => 0.3048,
                           'm'         => 1
                          },
                 'mi'  => {
                           'factor'    => 1609.344,
                           'm'         => 1
                          },
                 'furlong'  => {
                           'factor'    => 201.168,
                           'm'         => 1
                          },
         'light-year'  => {
                           #'factor'    => 9.46E15,
                           'factor'    => 9460730472580800,
                           'm'         => 1
                          },
         'AU'  		   => {
                           'factor'    => 149597870700,
                           'm'         => 1
                          },
         'parsec'  => {
                           'factor'    => 3.08567758149137E16, #30.857E15,
                           'm'         => 1
                          },
# VOLUME
# L   -- liter
# cc -- cubic centermeters
#
                  'L'  => {
                           'factor'    => 0.001,
                           'm'         => 3
                          },
                 'cc'  => {
                           'factor'    => 1E-6,
                           'm'         => 3,
                          },
                'cup'  => {
                         'factor'    => 0.0002365882365,
                           'm'         => 3
                          },
               'cups'  => {
                           'factor'    => 0.0002365882365,
                           'm'         => 3
                          },
        'fluid ounce'  => {
          'factor'    => 0.0000295735295625,
          'm'         => 3
        },
        'fl oz'  => {
          'factor'    => 0.0000295735295625,
          'm'         => 3
        },
				'gal'  => {
                           'factor'    => 0.003785411784,
                           'm'         => 3
                          },
				'gallon'  => {
                           'factor'    => 0.003785411784,
                           'm'         => 3
                          },
				'gallons'  => {
                           'factor'    => 0.003785411784,
                           'm'         => 3
                          },
        'pint'  => {
                           'factor'    => 0.000473176473,
                           'm'         => 3
                          },
        'pt'  => {
                           'factor'    => 0.000473176473,
                           'm'         => 3
                          },
				'qt'  => {
                           'factor'    => 0.000946352946,
                           'm'         => 3
                          },
				'quart'  => {
                           'factor'    => 0.000946352946,
                           'm'         => 3
                          },
				'quarts'  => {
                           'factor'    => 0.000946352946,
                           'm'         => 3
                          },
				'tbsp'  => {
                           'factor'    => 0.0000147867647813,
                           'm'         => 3
                          },
				'tablespoon'  => {
                           'factor'    => 0.0000147867647813,
                           'm'         => 3
                          },
				'tablespoons'  => {
                           'factor'    => 0.0000147867647813,
                           'm'         => 3
                          },
				'tsp'  => {
                           'factor'    => 0.00000492892159375,
                           'm'         => 3
                          },
				'teaspoon'  => {
                           'factor'    => 0.00000492892159375,
                           'm'         => 3
                          },
				'teaspoons'  => {
                           'factor'    => 0.00000492892159375,
                           'm'         => 3
                          },
# VELOCITY
# knots -- nautical miles per hour
# c		-- speed of light
#
              'knots'  => {
                           'factor'    =>  0.5144444444,
                           'm'         => 1,
                           's'         => -1
                          },
              'c'  => {
                           'factor'    =>  299792458,	# exact
                           'm'         => 1,
                           's'         => -1
                          },
              'mph'  => {
                           'factor'    =>  0.44704,
                           'm'         => 1,
                           's'         => -1
                          },
# MASS
# g    -- grams
# tonne -- metric ton
#
                  
                  'g'  => {
                           'factor'    => 0.001,
                           'kg'        => 1
                          },
                  'tonne'  => {
                           'factor'    => 1000,
                           'kg'        => 1
                          },
# ENGLISH MASS
# slug -- slug
# firkin	-- (FFF system) 90 lb, mass of a firkin of water
#
               'slug'  => {
                           'factor'    => 14.6,
                           'kg'         => 1
                          },
                  'firkin'  => {
                           'factor'    => 40.8233133,
                           'kg'        => 1
                          },
# FREQUENCY
# Hz    -- Hertz
#
                 'Hz'  => {
                           'factor'    => 2*$PI,  #2pi
                           's'         => -1,
                           'rad'       => 1
                          },
                
                'rev'  => {
                			'factor'   => 2*$PI,
                			'rad'      => 1
                		  },
                'cycles'  => {
                			'factor'   => 2*$PI,
                			'rad'      => 1
                		  },

# COMPOUND UNITS
#
# FORCE
# N      -- Newton
# dyne   -- dyne
# lb     -- pound
# ton    -- ton
#
                 'N'  => {
                           'factor'    => 1,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
            
               'dyne'  => {
                           'factor'    => 1E-5,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
                 'lb'  => {
                           'factor'    => 4.4482216152605,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'lbs'  => {
                           'factor'    => 4.4482216152605,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'ton'  => {
                           'factor'    => 8900,
                           'm'         => 1,
                           'kg'        => 1,
                           's'         => -2
                          },
# ENERGY
# J      -- Joule
# erg    -- erg
# lbf    -- foot pound
# kt	 -- kiloton (of TNT)
# Mt	 -- megaton (of TNT)
# cal    -- calorie
# eV     -- electron volt
# kWh    -- kilo Watt hour
#
                    'J'  => {
                           'factor'    => 1,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                
                'erg'  => {
                           'factor'    => 1E-7,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'lbf'  => {
                           'factor'    => 1.35582,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'kt'  => {
                           'factor'    => 4.184E12,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'Mt'  => {
                           'factor'    => 4.184E15,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'cal'  => {
                           'factor'    => 4.19,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
               
                'eV'  => {
                           'factor'    => 1.60E-9,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
                'kWh'  => {
                           'factor'    => 3.6E6,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -2
                          },
# POWER
# W      -- Watt
# hp     -- horse power  746 W
#
                 'W'  => {
                           'factor'    => 1,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -3
                          },
                 
                'hp'   => {
                           'factor'    => 746,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -3
                          },
# PRESSURE
# Pa     -- Pascal
# atm    -- atmosphere
# bar	 -- 100 kilopascals
# cmH2O	 -- centimetres of water
#
                 'Pa'  => {
                           'factor'    => 1,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                
                'atm'  => {
                           'factor'    => 1.01E5,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'bar'  => {
                           'factor'    => 100000,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
               
                'Torr'  => {
                           'factor'    => 133.322,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'mmHg'  => {
                           'factor'    => 133.322,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'cmH2O'  => {
                           'factor'    => 98.0638,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
                'psi'  => {
                           'factor'    => 6895,
                           'm'         => -1,
                           'kg'        => 1,
                           's'         => -2
                          },
# ELECTRICAL UNITS
# C      -- Coulomb
# V      -- volt
# mV     -- milivolt
# kV     -- kilovolt
# MV     -- megavolt
# F      -- Farad
# mF     -- miliFarad
# uF     -- microFarad
# ohm    -- ohm
# kohm   -- kilo-ohm
# Mohm	 -- mega-ohm
# S		 -- siemens
#
                'C'    => {
                           'factor'    => 1,
                           'amp'       => 1,
                           's'         => 1,
                         },
                'V'    => {			# also J/C
                           'factor'    => 1,
                           'kg'        => 1,
                           'm'         => 2,
                           'amp'       => -1,
                           's'         => -3,
                         },
               
                'F'    => {			# also C/V
                           'factor'    => 1,
                           'amp'       => 2,
                           's'         => 4,
                           'kg'        => -1,
                           'm'         => -2,
                         },
                
                'ohm'  => {			# V/amp
                           'factor'    => 1,
                           'kg'        => 1,
                           'm'         => 2,
                           'amp'       => -2,
                           's'         => -3,
                         },

                'S'  => {			# 1/ohm
                           'factor'    => 1,
                           'kg'        => -1,
                           'm'         => -2,
                           'amp'       => 2,
                           's'         => 3,
                         },
# MAGNETIC UNITS
# T	 	 -- tesla
# G	 	 -- gauss
# Wb	 -- weber
# H	 	 -- henry
#
                'T'    => {			# also kg/A s^2		N s/C m
                           'factor'    => 1,
                           'kg'        => 1,
                           'amp'       => -1,
                           's'         => -2,
                         },
                'G' => {
                           'factor'    => 1E-5,
                           'kg'        => 1,
                           'amp'       => -1,
                           's'         => -2,
                         },
                'Wb'    => {			# also T m^2
                           'factor'    => 1,
                           'kg'        => 1,
                           'm'         => 2,
                           'amp'       => -1,
                           's'         => -2,
                         },
                'H'    => {			# also V s/amp
                           'factor'    => 1,
                           'kg'        => 1,
                           'm'         => 2,
                           'amp'       => -2,
                           's'         => -2,
                         },
# LUMINOSITY
# lm	-- lumen, luminous flux
# lx	-- lux, illuminance
#
                'lm' => {
                           'factor'    => 1,
                           'cd'        => 1,
                           'rad'       => -2,
                         },
                'lx' => {
                           'factor'    => 1,
                           'cd'        => 1,
                           'rad'       => -2,
                           'm'         => -2,
                         },

# ATOMIC UNITS
# amu	-- atomic mass units
# dalton	-- 1 amu
# me	-- electron rest mass
# barn	-- cross-sectional area
# a0	-- Bohr radius
#
                'amu' => {
                           'factor'    => 1.660538921E-27,
                           'kg'        => 1,
                         },
                'dalton' => {
                           'factor'    => 1.660538921E-27,
                           'kg'        => 1,
                         },
                'me' => {
                           'factor'    => 9.1093826E-31,
                           'kg'        => 1,
                         },
                'barn' => {
                           'factor'    => 1E-28,
                           'm'         => 2,
                         },
                'a0' => {
                           'factor'    => 0.5291772108E-10,
                           'm'         => 1,
                         },
# RADIATION
# Sv	-- sievert, dose equivalent radiation	http://xkcd.com/radiation
# mSv	-- millisievert				http://blog.xkcd.com/2011/03/19/radiation-chart
# uSv	-- microsievert				http://blog.xkcd.com/2011/04/26/radiation-chart-update
#
                'Sv' => {
                           'factor'    => 1,
                           'm'         => 2,
                           's'         => -2,
                         },
                
# BIOLOGICAL & CHEMICAL UNITS
# mmol	-- milli mole
# micromol	-- micro mole
# nanomol	-- nano mole
# kat	-- katal, catalytic activity
#
               
                'kat' => {
                           'factor'    => 1,
                           'mol'       => 1,
                           's'         => -1,
                         },

# ASTRONOMICAL UNITS
# kpc	-- kilo parsec
# Mpc	-- mega parsec
# solar-mass	-- solar mass
# solar-radii	-- solar radius
# solar-lum	-- solar luminosity
         'kpc'  => {
                           'factor'    => 30.857E18,
                           'm'         => 1
                          },
         'Mpc'  => {
                           'factor'    => 30.857E21,
                           'm'         => 1
                          },
                'solar-mass' => {
                           'factor'    => 1.98892E30,
                           'kg'        => 1,
                         },
                'solar-radii' => {
                           'factor'    => 6.955E8,
                           'm'         => 1,
                         },
                'solar-lum' => {
                           'factor'    => 3.8939E26,
                           'm'         => 2,
                           'kg'        => 1,
                           's'         => -3
                         },

);

our %prefixes = (
	'Y' => {'name' => 'yotta', 'exponent' => 24} ,
	'Z' => {'name' => 'zetta', 'exponent' => 21} ,
	'E' => {'name' => 'exa', 'exponent' => 18} ,
	'P' => {'name' => 'peta', 'exponent' => 15} ,
	'T' => {'name' => 'tera', 'exponent' => 12} ,
	'G' => {'name' => 'giga', 'exponent' => 9} ,
	'M' => {'name' => 'mega', 'exponent' => 6} ,
	'k' => {'name' => 'kilo', 'exponent' => 3} ,
	'h' => {'name' => 'hecto', 'exponent' => 2} ,
	'da' => {'name' => 'deka', 'exponent' => 1} ,
	'd' => {'name' => 'deci', 'exponent' => -1} ,
	'c' => {'name' => 'centi', 'exponent' => -2} ,
	'm' => {'name' => 'milli', 'exponent' => -3} ,
	'u' => {'name' => 'micro', 'exponent' => -6} ,
	'μ' => {'name' => 'micro', 'exponent' => -6} ,
  #'\mu' => {'name' => 'micro', 'exponent' => -6} ,
	'n' => {'name' => 'nano', 'exponent' => -9} ,
	'p' => {'name' => 'pico', 'exponent' => -12} ,
	'f' => {'name' => 'femto', 'exponent' => -15} ,
	'a' => {'name' => 'atto', 'exponent' => -18} ,
	'z' => {'name' => 'zepto', 'exponent' => -21} ,
	'y' => {'name' => 'yocto', 'exponent' => -24} 
);


sub process_unit {

    my $string = shift;

    my $options = shift;

    # $fund = $options->{known_units};
    # %op = %$fund;
    # warn "decoding options";
	  # warn "$_ $op{$_}\n" for (keys %op);
    # warn "end options";

    my $fundamental_units = \%fundamental_units;
    my $known_units = \%known_units;
	
    if (defined($options->{fundamental_units})) {
      $fundamental_units = $options->{fundamental_units};
    }

    if (defined($options->{known_units})) {
      $known_units = $options->{known_units};
    }

# 
    
    die ("UNIT ERROR: No units were defined.") unless defined($string);  #
	#split the string into numerator and denominator --- the separator is /
    my ($numerator,$denominator) = split( m{/}, $string );



    $denominator = "" unless defined($denominator);
    my %numerator_hash = process_term($numerator,{fundamental_units => $fundamental_units, known_units => $known_units});
    my %denominator_hash =  process_term($denominator,{fundamental_units => $fundamental_units, known_units => $known_units});


    my %unit_hash = %$fundamental_units;
	my $u;
	foreach $u (keys %unit_hash) {
		if ( $u eq 'factor' ) {
			$unit_hash{$u} = $numerator_hash{$u}/$denominator_hash{$u};  # calculate the correction factor for the unit
		} else {

			$unit_hash{$u} = $numerator_hash{$u} - $denominator_hash{$u}; # calculate the power of the fundamental unit in the unit
		}
	}
	# return a unit hash.
	return(%unit_hash);
}

sub process_term {
	my $string = shift;
	my $options = shift;

	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;
	
	if (defined($options->{fundamental_units})) {
	  $fundamental_units = $options->{fundamental_units};
	}

	if (defined($options->{known_units})) {
	  $known_units = $options->{known_units};
	}
	
	my %unit_hash = %$fundamental_units;
	if ($string) {

		#split the numerator or denominator into factors -- the separators are *

	    my @factors = split(/\*/, $string);
    
		my $f;
		foreach $f (@factors) {
			my %factor_hash = process_factor($f,{fundamental_units => $fundamental_units, known_units => $known_units});

			my $u;
			foreach $u (keys %unit_hash) {
				if ( $u eq 'factor' ) {
					$unit_hash{$u} = $unit_hash{$u} * $factor_hash{$u};  # calculate the correction factor for the unit
				} else {

					$unit_hash{$u} = $unit_hash{$u} + $factor_hash{$u}; # calculate the power of the fundamental unit in the unit
				}
			}
		}
	}
	#returns a unit hash.
	#print "process_term returns", %unit_hash, "\n";
	return(%unit_hash);
}

sub compareUnitRefs {
  my $first = shift;
  my %a = %$first;
  my $second = shift;
  my %b = %$second;
  my $equal = 1;
  if (%a != %b){
    $equal = 0;  # do not have same # of keys
  } else {
    # https://stackoverflow.com/questions/1273616/how-do-i-compare-two-hashes-in-perl-without-using-datacompare#:~:text=Compare%20is%20not%20a%20detailed%20enough%20phrase%20when,don%27t%20have%20the%20same%20number%20of%20keysn%22%3B%20%7D
    my %cmp = map { $_ => 1 } keys %a;
    for my $key (keys %b) {
        last unless exists $cmp{$key};
        last unless $a{$key} eq $b{$key};
        delete $cmp{$key};
    }
    if (%cmp){
      $equal = 0;
    }
  }
  return $equal;

  foreach $u (keys %$first){

  }
}

sub comparePhysicalQuantity {
	my $first = shift;
	my $second = shift;
	my $equal = 1;
	my $u;
	foreach $u (keys %$first) {
		if ( $u ne 'factor') {
			if (!defined $first->{$u} && !defined $second->{$u}){
				next;
			} elsif (!defined $first->{$u} || !defined $second->{$u}){
				$equal=0;
				last;
			}
			$equal = $first->{$u} == $second->{$u};
			if ($equal == 0){
				last;
			}
		}
	}
	return $equal;
}


sub process_factor {
	my $string = shift;
	#split the factor into unit and powers

	my $options = shift;
  #my %op = %{$options->{known_units}};
  #warn "$_ $op{$_}\n" for (keys %op);

	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;
	
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
  #warn "$unitsJoined";
  #warn $unit_prefix;
  #warn $unit_base;

	$power = 1 unless defined($power);
	my %unit_hash = %$fundamental_units;
	if ( defined( $known_units->{$unit_base} )  ) {
		$prefixExponent = 0;
		if ( defined($unit_prefix) && $unit_prefix ne ''){
			 if (exists($prefixes{$unit_prefix})){
				$prefixExponent = $prefixes{$unit_prefix}->{'exponent'};
			} else {
			 	die "Unit Prefix unrecognizable: |$unit_prefix|";
			}
		}
		my %unit_name_hash = %{$known_units->{$unit_base}};   # $reference_units contains all of the known units.
		my $u;
		foreach $u (keys %unit_hash) {
			if ( $u eq 'factor' ) {
				$unit_hash{$u} = ($unit_name_hash{$u}*(10**$prefixExponent))**$power;  # calculate the correction factor for the unit
			} else {
				my $fundamental_unit = $unit_name_hash{$u};
				$fundamental_unit = 0 unless defined($fundamental_unit); # a fundamental unit which doesn't appear in the unit need not be defined explicitly
				$unit_hash{$u} = $fundamental_unit*$power; # calculate the power of the fundamental unit in the unit
			}
		}
	} else {
		die "UNIT ERROR Unrecognizable unit: |$unit_base|";
	}
	%unit_hash;
}

sub convertUnit {
  my $fromUnit = shift;
	my $toUnit = shift;
  #warn $fromUnit;
  #warn $toUnit;
  my $options = shift;

	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;
  my $region = 'us';

  if (defined($options->{fundamental_units})) {
	  $fundamental_units = $options->{fundamental_units};
	}

	if (defined($options->{known_units})) {
	  $known_units = $options->{known_units};
	}

  if (defined($options->{region})){
    $region = $options->{region};
  }

  if ($region eq 'uk'){
    @known_units{ keys %known_units_uk } = values %known_units_uk;
  }

  my ($unit_name_from,$power_from) = split(/\^/, $fromUnit);
  #warn $unit_name_from;
	$power_from = 1 unless defined($power_from);

  my %unit_hash_from = %$fundamental_units;
	if ( defined( $known_units->{$unit_name_from} )  ) {
		my %unit_name_from_hash = %{$known_units->{$unit_name_from}};   # $reference_units contains all of the known units.
    #warn %unit_name_from_hash;
		my $u;
		foreach $u (keys %unit_name_from_hash) {
			if ( $u eq 'factor' ) {
        #warn "$u: $unit_name_from{$u}";
        #warn "$u: $unit_name_from_hash{$u}";
				$unit_hash_from{$u} = $unit_name_from_hash{$u}**$power_from;  # calculate the correction factor for the unit
        #warn "power: $power_from";
			} else {
				my $fundamental_unit = $unit_name_from_hash{$u};
        $fundamental_unit = 0 unless defined($fundamental_unit); # a fundamental unit which doesn't appear in the unit need not be defined explicitly
				#warn "fundamental: $fundamental_unit";
        $unit_hash_from{$u} = $fundamental_unit*$power_from; # calculate the power of the fundamental unit in the unit
			}
		}
	} else {
		die "UNIT ERROR Unrecognizable unit: |$unit_name_from|";
	}

  my ($unit_name_to,$power_to) = split(/\^/, $toUnit);
  #warn $unit_name_to;
	$power_to = 1 unless defined($powepower_tor_to);

  my %unit_hash_to = %$fundamental_units;
	if ( defined( $known_units->{$unit_name_to} )  ) {
		my %unit_name_to_hash = %{$known_units->{$unit_name_to}};   # $reference_units contains all of the known units.
    #warn %unit_name_to_hash;
		my $u;
		foreach $u (keys %unit_name_to_hash) {
			if ( $u eq 'factor' ) {
        #warn "$u: $unit_name_to{$u}";
        #warn "$u: $unit_name_to_hash{$u}";
				$unit_hash_to{$u} = $unit_name_to_hash{$u}**$power_to;  # calculate the correction factor for the unit
        #warn "power: $power_to";
			} else {
				my $fundamental_unit = $unit_name_to_hash{$u};
        $fundamental_unit = 0 unless defined($fundamental_unit); # a fundamental unit which doesn't appear in the unit need not be defined explicitly
				#warn "fundamental: $fundamental_unit";
        $unit_hash_to{$u} = $fundamental_unit*$power_to; # calculate the power of the fundamental unit in the unit
			}
		}
	} else {
		die "UNIT ERROR Unrecognizable unit: |$unit_name_to|";
	}
  
  #foreach my $name (keys %unit_hash_from) {
   # warn "$name $unit_hash_from{$name}";
  #}
#foreach my $name (keys %unit_hash_to) {
  #  warn "$name $unit_hash_to{$name}";
 #}

  $multiplier = $unit_hash_from{'factor'}/$unit_hash_to{'factor'};
  #warn "multiplier:  $multiplier";

	#%unit_hash_from;
  return $multiplier;
}

# # This is the "exported" subroutine.  Use this to evaluate the units given in an answer.
# sub evaluate_units {
#         my $unit = shift;
# 	my $options = shift;

# 	my $fundamental_units = \%fundamental_units;
# 	my $known_units = \%known_units;
	
# 	if (defined($options->{fundamental_units}) && $options->{fundamental_units}) {
# 	  $fundamental_units = $options->{fundamental_units};
# 	}

# 	if (defined($options->{known_units}) && $options->{fundamental_units}) {
# 	  $known_units = $options->{known_units};
# 	}
	
# 	my %output =  eval(q{process_unit( $unit, {fundamental_units => $fundamental_units, known_units => $known_units})});
# 	%output = %$fundamental_units if $@;  # this is what you get if there is an error.
# 	$output{'ERROR'}=$@ if $@;
# 	%output;
# }
# #################

1;
