# This is the "exported" subroutine.  Use this to evaluate the units given in an answer.

sub evaluate_units {
	&BetterUnits::evaluate_units;
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
								'meters'  => {
													 'factor'    => 1,
													 'm'         => 1
													},
								'meter'  => {
													 'factor'    => 1,
													 'm'         => 1
													},
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
									'liter'  => {
													 'factor'    => 0.001,
													 'm'         => 3
													},
									'liters'  => {
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
				'pints' => {
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
									'gram'  => {
													 'factor'    => 0.001,
													 'kg'        => 1
													},
									'grams'  => {
													 'factor'    => 0.001,
													 'kg'        => 1
													},
									'tonne'  => {
													 'factor'    => 1000,
													 'kg'        => 1
													},
									'lb'  => {
													 'factor'    => 0.45359237,
													 'kg'        => 1
													},
									'lbs'  => {
													 'factor'    => 0.45359237,
													 'kg'        => 1
													},
									'pound'  => {
													 'factor'    => 0.45359237,
													 'kg'        => 1
													},
									'pounds'  => {
													 'factor'    => 0.45359237,
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
# lbf     -- pound-force
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
								 'lbf'  => {
													 'factor'    => 4.4482216152605,
													 'm'         => 1,
													 'kg'        => 1,
													 's'         => -2
													},
								'pound-force'  => {
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
# ft-lbf    -- foot pound
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
								'ft-lbf'  => {
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
# mmol	-- milli mole  		<-- this is covered by prefix now
# micromol	-- micro mole	<-- this is covered by prefix now
# nanomol	-- nano mole	<-- this is covered by prefix now
# mole -- spelled out mol
# Molarity -- concentration
# kat	-- katal, catalytic activity
#
							 	'mole' => {
													 'factor'    => 1,
													 'mol'       => 1
												 },
								'moles' => {
													 'factor'    => 1,
													 'mol'       => 1
												 },				
								'kat' => {
													 'factor'    => 1,
													 'mol'       => 1,
													 's'         => -1,
												 },
								'M' => {
													'factor'    => 1000,
													'mol'       => 1,
													'm'			=> -3
								},
# this may be temporary
								'molecule' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'molecules' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'atom' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'atoms' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'ion' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'ions' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'formula unit' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'formula units' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
												 },
								'f.u.' => {
													 'factor'    => 1.66053906717384666E-24,
													 'mol'       => 1
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
	'y' => {'name' => 'yocto', 'exponent' => -24} ,
	
	'yotta' => {'name' => 'yotta', 'exponent' => 24} ,
	'zetta' => {'name' => 'zetta', 'exponent' => 21} ,
	'exa' => {'name' => 'exa', 'exponent' => 18} ,
	'peta' => {'name' => 'peta', 'exponent' => 15} ,
	'tera' => {'name' => 'tera', 'exponent' => 12} ,
	'giga' => {'name' => 'giga', 'exponent' => 9} ,
	'mega' => {'name' => 'mega', 'exponent' => 6} ,
	'kilo' => {'name' => 'kilo', 'exponent' => 3} ,
	'hecto' => {'name' => 'hecto', 'exponent' => 2} ,
	'deka' => {'name' => 'deka', 'exponent' => 1} ,
	'deci' => {'name' => 'deci', 'exponent' => -1} ,
	'centi' => {'name' => 'centi', 'exponent' => -2} ,
	'milli' => {'name' => 'milli', 'exponent' => -3} ,
	'micro' => {'name' => 'micro', 'exponent' => -6} ,
	'nano' => {'name' => 'nano', 'exponent' => -9} ,
	'pico' => {'name' => 'pico', 'exponent' => -12} ,
	'femto' => {'name' => 'femto', 'exponent' => -15} ,
	'atto' => {'name' => 'atto', 'exponent' => -18} ,
	'zepto' => {'name' => 'zepto', 'exponent' => -21} ,
	'yocto' => {'name' => 'yocto', 'exponent' => -24} 
);


sub evaluate_units {
				my $unit = shift;
	my $options = shift;

	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;
	
	if (defined($options->{fundamental_units}) && $options->{fundamental_units}) {
		$fundamental_units = $options->{fundamental_units};
	} else {
		$options->{fundamental_units} = $fundamental_units;
	}

	if (defined($options->{known_units}) && $options->{fundamental_units}) {
		$known_units = $options->{known_units};
	} else {
		 $options->{known_units} = $known_units;
	}
	
	my %output =  process_unit( $unit, $options);
	%output = %$fundamental_units if $@;  # this is what you get if there is an error.
	$output{'ERROR'}=$@ if $@;
	%output;

}

sub process_unit {

	my $string = shift;

	my $options = shift;

	# $fund = $options->{known_units};
	# %op = %$fund;
	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;

	if (defined($options->{fundamental_units})) {
		$fundamental_units = $options->{fundamental_units};
	} else {
		$options->{fundamental_units} = $fundamental_units;
	}


	if (defined($options->{known_units})) {
		$known_units = $options->{known_units};
	} else {
		$options->{known_units} = $known_units;
	}
	
	die ("UNIT ERROR: No units were defined.") unless defined($string);  #
	#split the string into numerator and denominator --- the separator is /
	my ($numerator,$denominator) = split( m{/}, $string );
	# warn "numerator: $numerator";
	# warn "denominator: $denominator";
	$denominator = "" unless defined($denominator);

	my %numerator_hash = process_term($numerator, $options);
	my %denominator_hash =  process_term($denominator, $options);
	# warn "Process units: $string";
	# warn %numerator_hash;
	# warn %denominator_hash;

	my %unit_hash = %$fundamental_units;
	$unit_hash{'parsed'} = [];  # add an empty array to the hash

	my $u;
	foreach $u (keys %unit_hash) {
		if ( $u eq 'factor' ) {
			# calculate the correction factor for the unit
			$unit_hash{$u} = $numerator_hash{$u}/$denominator_hash{$u};  
		} elsif ($u eq 'parsed') {
			foreach (@{$numerator_hash{$u}}){
				push @{$unit_hash{$u}}, $_;
			}
			foreach (@{$denominator_hash{$u}}){
			 	$_->{power} = $_->{power} * -1;
			 	push @{$unit_hash{$u}}, $_;
			}

		} else {
			# calculate the power of the fundamental unit in the unit
			# possibility that new unit is in denominator but not numerator, so check first. Assume zero power for missing fundamental.
			$unit_hash{$u} = ($numerator_hash{$u} ? $numerator_hash{$u} : 0) - ($denominator_hash{$u} ? $denominator_hash{$u} : 0); 
		}
	}

	# Transfer any piggyback items to the main unit_hash
	if (exists $numerator_hash{piggybackUnit}){
		$unit_hash{piggybackUnit} = $numerator_hash{piggybackUnit};
	}
	if (exists $denominator_hash{piggybackUnit}){
		$unit_hash{piggybackUnit} = $denominator_hash{piggybackUnit};
	}

	# return a unit hash.
	# warn %unit_hash;
	
	return(%unit_hash);
}

sub process_term {
	my $string = shift;
	my $options = shift;

	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;
	
	if (defined($options->{fundamental_units})) {
		$fundamental_units = $options->{fundamental_units};
	} else {
		$options->{fundamental_units} = $fundamental_units;
	}

	if (defined($options->{known_units})) {
		$known_units = $options->{known_units};
	} else {
		$options->{known_units} = $known_units;
	}
	
	my %unit_hash = %$fundamental_units;

	$unit_hash{'parsed'} = [];  # add an empty array to the hash
	if ($string) {
		#warn $string;
		# First check for chemicals.  Later this can be transformed into a "preprocess" callback function that is
		# passed here in the options so we can make this more generic and move chemicals out of the units file. 
		


		#split the numerator or denominator into factors -- the separators are *
		# The system will always use * for separating terms.  i.e. after multiplying two numbers with units an asterix is used to separate the terms
		# A user might use space though... but space is more complicated as it's used inside units too.  Keep these two processes separate.  Check 
		# for special cases (i.e. chemicals) after separating using asterisk, but BEFORE splitting on spaces.
		my @factors = split(/\*/, $string);
		
		my $f;
		foreach $f (@factors) {
			#warn "FACTOR: $f";
			# trim whitespace from $f
			#warn '/' . $f . '/';
			#$f =~ s/^\s+|\s+$//g;
			if ($options->{hasChemicals}){
				if (!defined &Chemical::Chemical::new){
					die "You need to load contextChemical.pl if you want to use chemicals as units.";
				}
				my $chemical = undef;
				$chemical = Chemical::Chemical->new($f);
				if (defined $chemical && scalar @{$chemical->{data}} > 0){
					my $power = 1; # reset power to 1 since it might have picked up a chemical charge as the power.
					my $unit_base = $chemical->guid();

					#piggyback the unit details (string,TeX) on the hash so that we can write them correctly on the screen
					unless (exists $unit_hash{piggybackUnit}){
						$unit_hash{piggybackUnit} = {};
					}
					$piggyback = $unit_hash{piggybackUnit};
				
					#warn $chemical->{leading};
					#my $s = $chemical->{leading} . $chemical->string();
					$piggyback->{$f} = $chemical; #{string=> $chemical->{leading} . ' ' . $chemical->string, TeX=> $chemical->{leading} .'\,'. $chemical->TeX, base=>$unit_base};
					
					# now check if the $unit_base is in the list before adding it.  Since there are many variations of chemical names, we can only check against a post-processed name.
					unless ($known_units->{$unit_base}){
						#warn "add unit $unit_base";
						BetterUnits::add_unit($unit_base);
					}
					# add it to the local copy of fundamental units here
					$unit_hash{$unit_base} = 1;
					#warn %unit_hash;
					$f = '';
					if (defined $chemical->{leading}){
						$f = $chemical->{leading};
					}

					#warn "BetterUnits chem: $unit_base";
				}
			} 
			# here we should check to see if there are any unknown units combined with spaces
			# i.e. "mol Fe2+" will fail in process_factor subroutine because it is two units, not one.
			# The trick is to not split units that are technically one (like fluid ounce).  
			# Adding a dash is fine, but if a user adds a custom unit with spaces, we want to honor it.
			my @unitsNameArray = keys %$known_units;
			@unitsNameArray = grep(/\s/, @unitsNameArray);
			@unitsNamesArray2 = main::PGsort(sub {length($_[0]) > length($_[1])}, @unitsNameArray);
			my $unitsJoined = join '|', @unitsNamesArray2;
			my @splitUnits = ( $f =~ m/($unitsJoined|\S+)/g );

			foreach $s (@splitUnits) {
				my %factor_hash = process_factor($s, $options);
				# warn "Factor hash";
				# warn $f;
				# warn %factor_hash;
				my $u;
				foreach $u (keys %unit_hash) {
					if ( $u eq 'factor' ) {
						$unit_hash{$u} = $unit_hash{$u} * $factor_hash{$u};  # calculate the correction factor for the unit
					} elsif ($u eq 'piggybackUnit'){
							# do nothing;
					} elsif ($u eq 'parsed') {
						foreach (@{$factor_hash{$u}}){
							push @{$unit_hash{$u}}, $_;
						}
					} else {

						$unit_hash{$u} = $unit_hash{$u} + $factor_hash{$u}; # calculate the power of the fundamental unit in the unit
					}
				}
				# need to add missing fundamentals if we added new ones in the process_factor method
				# copy the parsed unit array to the new hash
				foreach $u (keys %factor_hash){
					unless (defined %unit_hash{$u}){
						$unit_hash{$u} = $factor_hash{$u};
					}
				}
				

			}


		}
	}
	#returns a unit hash.
	#print "process_term returns", %unit_hash, "\n";
	# foreach my $test (@known_unit_hash_array){
	# 	warn %$test;
	# }
	return(%unit_hash);
}

# This will cancel out qualitative units that are already the same
sub simplifyConversionFactorUnits {
	my $n = shift;
	#my %numerator = %$n;
	my $d = shift;
	#my %denominator = %$d;
	for my $key (keys %$d){
		if ($key ne 'factor'){
			if (exists($n->{$key})){
				#warn "key exists: $key";
				delete $n->{$key};
				delete $d->{$key};
			}
		}
	}
	
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
}

sub compareConversionFactorUnitRefs {
	my $numerator1 = shift;
	my $denominator1 = shift;
	my $numerator2 = shift;
	my $denominator2 = shift;

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

# This is to compare units that match other than prefixes.  For grading where any answer is ok
# as long as the base units match.
sub compareBaseUnits {
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

sub isMolarRatio {  
	my $first = shift;
	my $second = shift;
	my $equal = 1;
	my $u;
	
	if (exists($first->{'mol'}) && exists($second->{'mol'})){
		return 1;
	} else {
		return 0;
	}
		
}


sub add_unit {
	my $unit = shift;
	my $hash = shift;
	
	my $fundamental_units = \%fundamental_units;
	my $known_units = \%known_units;
	
	unless (ref($hash) eq 'HASH') {
		$hash = { 'factor'    => 1,    # this is 1 by default because it's a new "fundamental unit" 
							"$unit"     => 1 };  # this is 1 by default because it's the base.
	}
	
	# make sure that if this unit is defined in terms of any other units
	# then those units are fundamental units.  
	foreach my $subUnit (keys %$hash) {
		if (!defined($fundamental_units->{$subUnit})) {
			$fundamental_units->{$subUnit} = 0;  
		}
	}
	#warn %$fundamental_units;
	
	$known_units->{$unit} = $hash;

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
	} else {
		$options->{fundamental_units} = $fundamental_units;
	}

	if (defined($options->{known_units})) {
		$known_units = $options->{known_units};
	} else {
		$options->{known_units} = $known_units;
	}
	
	my ($unit_name,$power) = split(/\^/, $string);

	my @unitsNameArray = keys %$known_units;

	@unitNamesArray2 = main::PGsort(sub {length($_[0]) > length($_[1])}, @unitsNameArray);
	#warn @unitNamesArray2;
	my $unitsJoined = join '|', @unitNamesArray2;

	my $unit_base;
	my $unit_prefix;
	$power = 1 unless defined($power);

	my %unit_hash = %$fundamental_units;

	unless ( defined($unit_base) && defined( $known_units->{$unit_base} )  ) {
		($unit_base) = $unit_name =~ /($unitsJoined)$/;
		$unit_prefix = $unit_name =~ s/\s*($unitsJoined)\s*$//r;
		$unit_prefix =~ s/\s//;
	}
		
	unless (defined($unit_base)){  
		# if not-strict mode, register this unit as a new unit with its own fundamentals
		BetterUnits::add_unit($unit_name);
		# need to get a new copy of the fundamental units hash
		$unit_base = $unit_name;
		undef $unit_prefix;
	}
	
	
	$prefixExponent = 0;
	
	if ( defined($unit_prefix) && $unit_prefix ne ''){
		if (exists($prefixes{$unit_prefix})){
			$prefixExponent = $prefixes{$unit_prefix}->{'exponent'};
		} else {
			
			#warn "Unit Prefix unrecognizable: $unit_prefix";
		}
	}
	my %unit_name_hash = %{$known_units->{$unit_base}};   # $reference_units contains all of the known units.
	#warn %unit_name_hash;
	my $u;
	#warn %unit_hash;
	foreach $u (keys %unit_hash) {
		if ( $u eq 'factor' ) {
			$unit_hash{$u} = ($unit_name_hash{$u}*(10**$prefixExponent))**$power;  # calculate the correction factor for the unit
		} elsif ($u eq 'parsed'){
			# shouldn't reach here.
		} else {
			my $fundamental_unit = $unit_name_hash{$u};
			# if (defined $fundamental_unit){
			#   warn $fundamental_unit . '  ' . $u;
			#   warn "power:  $power";
			# }
			$fundamental_unit = 0 unless defined($fundamental_unit); # a fundamental unit which doesn't appear in the unit need not be defined explicitly
			$unit_hash{$u} = $fundamental_unit*$power; # calculate the power of the fundamental unit in the unit
		}
	}
	push @{$unit_hash{'parsed'}}, {prefix=>$unit_prefix, base=>$unit_base, power=>$power};
	#warn %unit_hash;
	%unit_hash;
}

sub unitsToPower {
	$unit_ref = shift;
	$power = shift;
	$parsed = $unit_ref->{parsed};
	#warn $parsed;
	$unitString = '';
	#warn %$unit_ref;
	foreach (@$parsed){
		#warn 'here';
		$newPower = $_->{power} * $power;
		if ($unitString ne ''){
			$unitString .= '*';
		}
		$unitString = $_->{prefix}.$_->{base}.'^'.$newPower;
	}
	return $unitString;
}

sub convertUnitHash {
	# 1.  Verify that physical quantities are same (same base units + powers) <---- NOT IMPLEMENTED
	# 2.  Compare factors and generate a multiplier

	my $fromUnitHash = shift;
	my $toUnitHash = shift;
	#warn $fromUnit;
	#warn $toUnit;
	my $options = shift;


	$multiplier = $fromUnitHash->{'factor'}/$toUnitHash->{'factor'};
	
	#%unit_hash_from;
	return $multiplier;
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
		warn "$unit_name_from";
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
