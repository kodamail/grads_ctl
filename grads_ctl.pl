#!/usr/bin/perl
#
# type "./grads_ctl.pl" or see end of file for help
#
use strict;
my $ver="0.20r2";
#
############################################################
#
# global constant
#
############################################################
#
#----- all the key words
#
my @KEYWORD = ( "DSET", "CHSUB", "DTYPE", "INDEX", "STNMAP", 
		"TITLE", "UNDEF", "UNPACK", "FILEHEADER", "XYHEADER", 
		"THEADER", "HEADERBYTES", "TRAILERBYTES", "XVAR", "YVAR", 
		"ZVAR", "STID", "TVAR", "TOFFVAR", "OPTIONS", 
		"PDEF", "XDEF", "YDEF", "ZDEF", "TDEF", 
		"EDEF", "VECTORPAIRS", "VARS", "ENDVARS" );
#
#----- key words which allow multiple line
#
my @KEYWORD_ML = ( "XDEF", "YDEF", "ZDEF", "EDEF" );
#
#----- factor to convert to sec 
#
#my %f_tunit = ( "SEC" => 1, "MN" => 60, "HR" => 3600, "DY" => 86400 );
my %FAC_TUNIT = ( "SEC" => 1, "MN" => 60, "HR" => 3600, "DY" => 86400 );
#
if( $#ARGV < 0 ){ &help(); }
else            { &main(); }
exit;

sub main()
{
    #
    ############################################################
    #
    # arguements
    #
    ############################################################
    #
    my %arg;
    $arg{ncdump} = "ncdump";
    my $i = 0;
    while( $i <= $#ARGV )
    {
	if(    "$ARGV[$i]" eq "--ctl"     ){ $i++; $arg{ctl}    =     $ARGV[$i];   }
	elsif( "$ARGV[$i]" eq "--key"     ){ $i++; $arg{key}    = uc( $ARGV[$i] ); }
	elsif( "$ARGV[$i]" eq "--nc"      ){ $i++; $arg{nc}     =     $ARGV[$i];   }
	elsif( "$ARGV[$i]" eq "--ncdump"  ){ $i++; $arg{ncdump} =     $ARGV[$i];   }
	elsif( "$ARGV[$i]" eq "--target"  ){ $i++; $arg{target} = uc( $ARGV[$i] ); }
	elsif( "$ARGV[$i]" eq "--unit"    ){ $i++; $arg{unit}   = uc( $ARGV[$i] ); }
	elsif( "$ARGV[$i]" eq "--value"   ){ $i++; $arg{value}  =     $ARGV[$i];   }
	elsif( "$ARGV[$i]" eq "--var"     ){ $i++; $arg{var}    = uc( $ARGV[$i] ); }
	#
	elsif( $ARGV[$i] =~ /\.ctl$/ && $arg{ctl}    eq "" ){ $arg{ctl}    =     $ARGV[$i];   }
	elsif( $ARGV[$i] =~ /\.nc$/  && $arg{nc}     eq "" ){ $arg{nc}     =     $ARGV[$i];   }
	elsif(                          $arg{key}    eq "" ){ $arg{key}    = uc( $ARGV[$i] ); }
	elsif(                          $arg{target} eq "" ){ $arg{target} = uc( $ARGV[$i] ); }
	#
	else{ print STDERR "syntax error: $ARGV[$i]\n"; exit 1; }
	$i++;
    }
    #
    #----- check consistency
    #
    if( "$arg{ctl}" ne "" && "$arg{nc}" ne "" )
    {
	print STDERR "syntax error: both --ctl and --nc are specified\n";
	exit 1; 
    }
    #
    ############################################################
    #
    # analyze control/NetCDF file or stdin and store
    #
    ############################################################
    #
    my %desc;
    #
    # default
    #
    if ( ! defined( $desc{EDEF} ) )
    {
	my $ref = { "NAMES" => "", "NUM" => "1", "TYPE" => "NAMES" };
	$desc{EDEF} = $ref;
	$ref = [ "NONE" ];
	$desc{EDEF}->{NAMES} = $ref;
    }
    #
    #
    # NetCDF
    if( $arg{nc} ne "" )
    {
	my $tmp = `$arg{ncdump} -c $arg{nc}`;
	my @nc = split( /\n/, $tmp );
	&ana_nc( \@nc, \%desc );  # NetCDF -> %desc (internal)
    }
    #
    # control file
    else
    {
	my @tmp;
	if( $arg{ctl} ne "" )
	{
	    if( open( LINK, "< $arg{ctl}" ) )
	    {
		@tmp = <LINK>;
		close(LINK);
	    }
	    else
	    {
		print STDERR "fail to open $arg{ctl}\n";
		exit 1;
	    }
	}
	else
	{
	    @tmp = <STDIN>;
	}
	&ana_ctl( \@tmp, \%desc );
        #
        #----- analyze NetCDF if DSET filename is NetCDF
	#
	if( $desc{DSET} =~ /\.nc/i )
	{
	    my $nc_filename = $desc{DSET};
	    my $dir = $arg{ctl};
	    $dir =~ s|[^/]*$||;
	    $nc_filename =~ s|^\^|$dir|;
	    $nc_filename =~ s|%ch|$desc{CHSUB}->{STR}->[0]|;

	    my %desc_esp = %desc;

	    my $tmp = `$arg{ncdump} -c $nc_filename`;
	    my @nc = split( /\n/, $tmp );
	    &ana_nc( \@nc, \%desc );

	    # overwrite by control file (analyze again)
	    &ana_ctl( \@tmp, \%desc );
	}
    }
    #
    ############################################################
    #
    # output (see help() for details)
    #
    ############################################################
    #
    if( "$arg{key}" ne "" )
    {
	#
	# target = "" -> output in control-file style
	#
	if( "$arg{target}" eq "" )
	{
	    my $ret = &dump_ctl( \%desc, "$arg{key}" );
	    if( $ret != 0 )
	    {
		print STDERR "syntax error; key=$arg{key} is not supported.\n";
		exit 1;
	    }
	    exit;
	}

        #
        #----- key = "DSET", "UNDEF" : value
        #
        elsif( $arg{key} =~ /^(DSET|UNDEF|TITLE)$/ && "$arg{target}" eq "VALUE" )
        {
	    if( defined( $desc{$arg{key}} ) ){ print $desc{$arg{key}} . "\n"; }
	    exit;
	}

        elsif( "$arg{key}" eq "DSET" )
	{
	    if( ! defined( $desc{$arg{key}} ) ){ exit 1; }

	    if( $desc{$arg{key}} !~ /(%ch|%m2|%d2)/ )
	    {
		print $desc{$arg{key}} . "\n";
		exit;
	    }

	    my $min = -1;
	    my $max = -1;

	    if( "$arg{target}" eq "ALL" )
	    {
		$min = 1;
		$max = $desc{TDEF}->{NUM};
	    }
	    elsif( $arg{target} =~ /^(\[|\()?0?([1-9][0-9]*):0?([1-9][0-9]*)(\]|\))?$/ )
	    {
		$min = $2; $max = $3;
		my ( $flag_min, $flag_max ) = ( $1, $4 );
		if( "$flag_min" eq "(" ){ $min++; }
		if( "$flag_max" eq ")" ){ $max--; }
	    }


	    if( $desc{$arg{key}} =~ /%ch/i )
	    {
		for( my $i=0; $i<$desc{CHSUB}->{NUM}; $i++ )
		{
		    if(    ( $min >= $desc{CHSUB}->{START}->[$i] && $min <= $desc{CHSUB}->{END}->[$i] )
			   || ( $max >= $desc{CHSUB}->{START}->[$i] && $max <= $desc{CHSUB}->{END}->[$i] ) 
			   || ( $min <= $desc{CHSUB}->{START}->[$i] && $max >= $desc{CHSUB}->{END}->[$i] )  )
		    {
			my $tmp = $desc{$arg{key}};
			$tmp =~ s/%ch/$desc{CHSUB}->{STR}->[$i]/g;
			print $tmp . "\n";
		    }
		}
	    }
	    else
	    {
		my $prev = "";
		for( my $i=$min; $i<=$max; $i++ )
		{
		    my $gtime = &levels( \%desc, "TDEF", $i );
		    my $date = `export LANG=en ; date -u --date "$gtime" +%Y%m%d\\\ %H:%M:%S`;
		    my $y4 = substr($date, 0, 4);
		    my $m2 = substr($date, 4, 2);
		    my $d2 = substr($date, 6, 2);
		    my $tmp = $desc{$arg{key}};
		    $tmp =~ s/%y4/$y4/ig;
		    $tmp =~ s/%m2/$m2/ig;
		    $tmp =~ s/%d2/$d2/ig;
		    if( "$tmp" ne "$prev")
		    {
			print $tmp . "\n";
			$prev = $tmp;
		    }
		}
	    }
	    exit;
	}

        #
        #----- key = OPTIONS : true (1) or false (0)
        #   target = XREV, YREV, ZREV, etc...
        #
        elsif( "$arg{key}" eq "OPTIONS" )
        {
	    if( defined( $desc{OPTIONS} ) )
	    {
		if( defined( $desc{OPTIONS}->{$arg{target}} ) )
		{
		    if( $desc{OPTIONS}->{$arg{target}} eq 1 ){ print "1\n"; exit; }
		}
	    }
	    print "0\n";
	    exit;
	}

        #
        #----- key = XDEF, YDEF, ZDEF, TDEF
        #
	elsif( $arg{key} =~ /^(XDEF|YDEF|ZDEF|TDEF|EDEF)$/ )
	{
            # target = "NUM": number of grids
	    if( "$arg{target}" eq "NUM" )
	    {
		if( defined( $desc{${arg{key}}} ) )
		{
		    if( defined( $desc{${arg{key}}}->{NUM} ) )
		    { print $desc{${arg{key}}}->{NUM} . "\n"; exit; }
		}
		print "1\n";
		exit;
	    }
	    #
	    # target = "TYPE": level type (LINEAR, LEVELS, or NAMES)
	    elsif( "$arg{target}" eq "TYPE" )
	    {
		if( defined ( $desc{${arg{key}}} ) )
		{
		    if( defined ( $desc{${arg{key}}}->{TYPE} ) )
		    {
			print $desc{${arg{key}}}->{TYPE} . "\n";
			exit;
		    }
		}
		exit;
	    }
	    #
	    # target = "INC": increment of levels
	    #                if inhomogeneoug grid, return NONE
	    #   unit = SEC, MN, HR, DY : output time increment in specified unit
	    #                            (only for key=TDEF)
	    elsif( "$arg{target}" eq "INC" )
	    {
		if( defined( $desc{${arg{key}}}->{LINEAR} ) )
		{
		    my $incre = $desc{${arg{key}}}->{LINEAR}->[1];
		    #
		    # change unit of $incre if necessary 
		    if( "$arg{key}" eq "TDEF" )
		    {
			if( $arg{unit} =~ /^(SEC|MN|HR|DY)$/ )
			{
			    my $f_tunit = $FAC_TUNIT{$1};
			    if( $incre =~ /^(\d+)(SEC|MN|HR|DY)$/i )
			    {
				$f_tunit = $FAC_TUNIT{uc($2)} / $f_tunit;
				$incre = $1 * $f_tunit;
				$incre = $incre . $arg{unit};
			    }
			}
		    }
		    print $incre . "\n";
		    exit;
		}
		print "NONE\n";
		exit;
	    }
	    #
	    # target = ALL-LEVELS or ALL : all levels
	    elsif( $arg{target} =~ /^(ALL-LEVELS|ALL)$/ )
	    {
		for( $i=1; $i<=$desc{${arg{key}}}->{NUM}; $i++ )
		{
		    print &levels( \%desc, $arg{key}, $i ) . " ";
		}
		print "\n";
		exit;
	    }
	    #
	    # target = n (>=1)    : specified levels
	    elsif( $arg{target} =~ /^(\d+$)/ )
	    {
		print &levels( \%desc, $arg{key}, $1 ) . "\n";
		exit
	    }
	    #
	    #   target = INDEX      : index of level by level value
	    #                         (use --value to specify)
	    elsif( "$arg{target}" eq "INDEX"  )
	    {
		if( $arg{value} !~ /^-*\d+(\.\d*)*$/ )
		{ print STDERR "error: value is not specified.\n" ; exit 1;}
		if( "$arg{key}" eq "TDEF" || "$arg{key}" eq "EDEF" )
		{ print STDERR "error: key=$arg{key} with --target INDEX is not supported\n"; exit 1; }
		my $dif_min = 1e+33;
		my $idx = -1;
		for( my $i=1; $i<=$desc{${arg{key}}}->{NUM}; $i++ )
		{
		    my $dif_tmp = abs( &levels( \%desc, $arg{key}, $i ) - $arg{value} );
		    if( $dif_min > $dif_tmp )
		    {
			$dif_min = $dif_tmp;
			$idx = $i;
		    }
		}
		print $idx . "\n";
		exit;
	    }
	    else
	    {
		print STDERR "syntax error for key=$arg{key}\n";
		exit 1;
	    }
	}
	
        #
        #----- key = "DIMS"
        #
	elsif( "$arg{key}" eq "DIMS" )
	{
            # target = "NUM": number of grids
	    if( "$arg{target}" eq "NUM" )
	    {
		if(    defined( $desc{XDEF} ) && defined( $desc{YDEF} ) 
		    && defined( $desc{ZDEF} ) && defined( $desc{TDEF} )
		    && defined( $desc{EDEF} ) )
		{
		    if(    defined( $desc{XDEF}->{NUM} ) && defined( $desc{YDEF}->{NUM} ) 
			&& defined( $desc{ZDEF}->{NUM} ) && defined( $desc{TDEF}->{NUM} )
	                && defined( $desc{EDEF}->{NUM} ) )
		    {
			print $desc{XDEF}->{NUM} . " " 
			    . $desc{YDEF}->{NUM} . " " 
			    . $desc{ZDEF}->{NUM} . " " 
			    . $desc{TDEF}->{NUM} . " "
			    . $desc{EDEF}->{NUM} . "\n";
			exit;
		    }
		}
		print "1\n";
		exit;
	    }
	    else{ print STDERR "syntax error for key=$arg{key}\n"; exit 1; }
	}

	#
        #----- key = VARS
	#
	elsif( "$arg{key}" eq "VARS" )
	{
	    # target = "NUM"
	    if( "$arg{target}" eq "NUM" )
	    {
		print $desc{VARS}->{NUM} . "\n";
		exit;
	    }
	    #
	    # target = "ALL"
	    elsif( "$arg{target}" eq "ALL" )
	    {
		for( my $i=0; $i<=$desc{VARS}->{NUM}-1; $i++ )
		{
		    print $desc{VARS}->{LIST}->[$i] . " ";
		}
		print "\n";
		exit;
	    }
	}

	#
	else
	{
	    print STDERR "syntax error: combination of key=$arg{key} and target=$arg{target} is not supported.\n";
	    exit 1;
	}

    }

    #
    ############################################################
    #
    # dump as control file
    #
    ############################################################
    #
    else
    {
	&dump_ctl( \%desc, "DSET" );
	&dump_ctl( \%desc, "TITLE" );
	&dump_ctl( \%desc, "CHSUB" );
	&dump_ctl( \%desc, "OPTIONS" );
	&dump_ctl( \%desc, "UNDEF" );
	&dump_ctl( \%desc, "XDEF" );
	&dump_ctl( \%desc, "YDEF" );
	&dump_ctl( \%desc, "ZDEF" );
	&dump_ctl( \%desc, "TDEF" );
	&dump_ctl( \%desc, "EDEF" );
	&dump_ctl( \%desc, "VARS" );
	exit;
    }

    return;
}

#
############################################################
#
# dump for control file
#
############################################################
#
sub dump_ctl()
{
    my $desc = shift;
    my $key  = shift;

    if( ! defined( $$desc{$key} ) && "$key" ne "DIMS" ){ return -1; }

    #
    # general: $key + value
    #
    if( $key =~ /^(DSET|TITLE|UNDEF)$/ )
    {
	print $key . "  " . $$desc{$key} . "\n";
	return 0;
    }
    #
    # specific
    #
    elsif( "$key" eq  "CHSUB" )
    {
	for( my $i=0; $i<$$desc{CHSUB}->{NUM}; $i++ )
	{
	    print $key 
		. "  " . $$desc{CHSUB}->{START}->[$i] 
		. "  " . $$desc{CHSUB}->{END}->[$i] 
		. "  " . $$desc{CHSUB}->{STR}->[$i] 
		. "\n";
	}
	return 0;
    }
    #
    elsif( "$key" eq "OPTIONS" )
    {
	print $key;
	while ( my ( $key2, $val ) = each %{$$desc{OPTIONS}} )
	{
	    if( $val == 1 ){ print "  " . $key2; }
	}
	print "\n";
	return 0;
    }
    #
    elsif( $key =~ /^(XDEF|YDEF|ZDEF|TDEF|EDEF)$/ )
    {
	return &dump_ctl_dims( $desc, $key );
    }
    #
    elsif( "$key" eq "DIMS" )
    {
	my $ret = 0;
	$ret += &dump_ctl_dims( $desc, "XDEF" );
	$ret += &dump_ctl_dims( $desc, "YDEF" );
	$ret += &dump_ctl_dims( $desc, "ZDEF" );
	$ret += &dump_ctl_dims( $desc, "TDEF" );
	$ret += &dump_ctl_dims( $desc, "EDEF" );
	return $ret;
    }
    #
    elsif( "$key" eq "VARS" )
    {
	print "VARS  " . $$desc{VARS}->{NUM} . "\n";
	for( my $i=0; $i<$$desc{VARS}->{NUM}; $i++ )
	{
	    my $var = $$desc{VARS}->{LIST}->[$i];
	    print $var . "  " 
		. sprintf( "%5s", $$desc{VARS}->{VAR}->{$var}->{ZNUM} ). "  "
	        . $$desc{VARS}->{VAR}->{$var}->{ATTR} . "  "
	        . $$desc{VARS}->{VAR}->{$var}->{DESC} . "\n";
	}
	print "ENDVARS\n";
	return 0;
    }

    else
    {
	print STDERR "error: key=$key is not supported in dump_ctl()\n";
	return -1;
    }
}


sub dump_ctl_dims
{
    my $desc = shift;
    my $key  = shift;

    if( ! defined( $$desc{$key} ) ){ return -1; }
    if( $$desc{$key}->{NUM} == 1 && $$desc{$key}->{NAMES}->[0] eq "NONE" ){ return 0; }

    print $key . "  " 
	. sprintf( "%6s", $$desc{$key}->{NUM} ) 
	. "  " . $$desc{$key}->{TYPE};
    if( "$$desc{$key}->{TYPE}" eq "LINEAR" )
    {
	print "  " . sprintf( "%14s", $$desc{$key}->{LINEAR}->[0] )
	    . "  " . sprintf( "%14s", $$desc{$key}->{LINEAR}->[1] );
    }
    elsif( "$$desc{$key}->{TYPE}" eq "NAMES" )
    {
	for( my $i=0; $i<$$desc{$key}->{NUM}; $i++ )
	{
	    print "  " . $$desc{$key}->{NAMES}->[$i];
	}
    }
    else
    {
	if( $$desc{$key}->{NUM} > 1 ){ print "\n"; }
	for( my $i=0; $i<$$desc{$key}->{NUM}; $i++ )
	{
	    if( $i > 0 )
	    {
		if( $i % 5 == 0 ){ print "\n"; }
		else{ print "  "; }
	    }
	    print sprintf( "%14s", $$desc{$key}->{LEVELS}->[$i] );
	}
    }
    print "\n";
    return 0;
}

#
############################################################
#
# analyze control file
#
############################################################
#
sub ana_ctl()
{
    my $ctl      = shift;
    my $desc     = shift;

    my %args;          # arguements for each key
    my $key_now = "";  # current key
    my @vlist;         # variable list
    my %vargs;         # arguements for each variable
    #
    #----- extract lines for each KEYWORD
    #
    LINELOOP: for( my $i=0; $i<=$#$ctl; $i++ )
    {
	if( $$ctl[$i] =~ /^\s*$/ ){ next LINELOOP; }
	if( $$ctl[$i] =~ /^[*@]/ ){ next LINELOOP; }

	for( my $j=0; $j<=$#KEYWORD; $j++ )
	{
	    if( $$ctl[$i] =~ /^$KEYWORD[$j]( +(.*))?$/i )
	    {
		$key_now = $KEYWORD[$j];
		$args{${key_now}} = $args{${key_now}} . $2 . " ";
		next LINELOOP;
	    }
	}

	# for multi lines syntax
	for( my $j=0; $j<=$#KEYWORD_ML; $j++ )
	{
	    if( $key_now eq $KEYWORD_ML[$j] )
	    {
		$args{${key_now}} = $args{${key_now}} . $$ctl[$i] . " ";
		next LINELOOP;
	    }
	}

	# for variable list
	if( $key_now eq "VARS" )
	{
	    my $var_temp;
	    if( $$ctl[$i] =~ /^([^ ]+)/     ){ $var_temp = lc( $1 ); push( @vlist, $var_temp ); }
	    if( $$ctl[$i] =~ /^[^ ]+ +(.*)/ ){ $vargs{$var_temp} = $1; }
	    next LINELOOP;
	}
	
	# syntax error
	my $line = $i + 1;
	print STDERR "error: fails to analyze (line: $line ctl: $$ctl[$i])\n";
	exit 1;
    }

    #
    #----- analyze and store for desc
    #
    my $ref;
    for( my $j=0; $j<=$#KEYWORD; $j++ )
    {
	if( $args{${KEYWORD[$j]}} eq "" ){ next; }
	my @tmp = split /\s+/, $args{${KEYWORD[$j]}};  # line(s) for key=${KEYWORD[$j]}
	#
	# single value
	#
	if(   "$KEYWORD[$j]" eq "DSET" 
           || "$KEYWORD[$j]" eq "DTYPE"
           || "$KEYWORD[$j]" eq "INDEX"
           || "$KEYWORD[$j]" eq "TITLE"
           || "$KEYWORD[$j]" eq "UNDEF" )
	{
	    $$desc{$KEYWORD[$j]} = $args{${KEYWORD[$j]}};
	}

	#
	# skip
	#
	elsif( "$KEYWORD[$j]" eq "ENDVARS" )
	{
	}

	#
	# complex
	#
	#----- OPTIONS
	#
	# e.g. $$dsec{OPTIONS}->{TEMPLATE} = 1 : true 
	#
	elsif( "$KEYWORD[$j]" eq "OPTIONS" )
	{
	    $ref = {};
	    $$desc{$KEYWORD[$j]} = $ref;

	    while( $#tmp >= 0 )
	    {
		$tmp[0] = uc( $tmp[0] );
		$$desc{$KEYWORD[$j]}->{$tmp[0]} = 1;
		shift(@tmp)
	    }
	}
	#
	#----- CHSUB
	# 
	# $$desc{CHSUB}->{NUM}  : number of CHSUBs
	# $$desc{CHSUB}->{START}: start timestep for each CHSUB
 	# $$desc{CHSUB}->{END}  : end timestep for each CHSUB
 	# $$desc{CHSUB}->{STR}  : strings each CHSUB
	#
	elsif( "$KEYWORD[$j]" eq "CHSUB" )
	{
	    $ref = { "START" => "", "END" => "", "STR" => "", "NUM" => 0 };
	    $$desc{$KEYWORD[$j]} = $ref;
	    $ref = []; $$desc{$KEYWORD[$j]}->{START} = $ref;
	    $ref = []; $$desc{$KEYWORD[$j]}->{END}   = $ref;
	    $ref = []; $$desc{$KEYWORD[$j]}->{STR}   = $ref;
	    while( $#tmp >= 2 )
	    {
		$$desc{$KEYWORD[$j]}->{NUM}++;
		push( @{$$desc{$KEYWORD[$j]}->{START}}, $tmp[0] );
		shift( @tmp );
		push( @{$$desc{$KEYWORD[$j]}->{END}}, $tmp[0] );
		shift( @tmp );
		push( @{$$desc{$KEYWORD[$j]}->{STR}}, $tmp[0] );
		shift( @tmp );
	    }
	}
	#
	#----- XDEF (, YDEF, ZDEF, TDEF, EDEF)
	# 
	# $$desc{XDEF}->{NUM}: number of levels
	# $$desc{XDEF}->{TYPE}: type of levels (LINEAR or LEVELS)
	# $$desc{XDEF}->{LEVELS}->[]: each level
	# $$desc{EDEF}->{NAME}->[]  : each name for ensemble dimension
	# $$desc{XDEF}->{LINEAR}->[]: start and increment
	#
	elsif(    "$KEYWORD[$j]" eq "XDEF" 
	       || "$KEYWORD[$j]" eq "YDEF" 
	       || "$KEYWORD[$j]" eq "ZDEF"
	       || "$KEYWORD[$j]" eq "TDEF" 
	       || "$KEYWORD[$j]" eq "EDEF" )
	{
	    if( $tmp[0] !~ /^[0-9]+$/ ){ shift(@tmp); }  # possible xdfopen style -> shift

	    $tmp[1] = uc( $tmp[1] );
	    $ref = { "$tmp[1]" => "", "NUM" => "$tmp[0]", "TYPE" => "$tmp[1]" };
	    $$desc{$KEYWORD[$j]} = $ref;

	    if( "$tmp[1]" eq "LEVELS" )
	    {
#		$ref = [1, 2, 1];
		$ref = [ @tmp[2..$#tmp] ];
		$$desc{$KEYWORD[$j]}->{LEVELS} = $ref;

		# calculate start and increment if possible
		&levels2linear( $desc, $KEYWORD[$j] );

	    }
	    elsif( "$tmp[1]" eq "NAMES" && "$KEYWORD[$j]" eq "EDEF" )
	    {
		$ref = [ @tmp[2..$#tmp] ];
		$$desc{$KEYWORD[$j]}->{NAMES} = $ref;
		# note: expanded expression of EDEF is not supported now.
	    }
	    elsif( "$tmp[1]" eq "LINEAR" )
	    {
		$tmp[2] = uc( $tmp[2] );
		$tmp[3] = uc( $tmp[3] );
		$ref = [ @tmp[2,3] ];
		$$desc{$KEYWORD[$j]}->{LINEAR} = $ref;
	    }
	    else
	    {
		print STDERR "ctl syntax error: @tmp\n";
		exit 1
	    }
	}
	#
	# $$desc{VARS}->{NUM}: number of variables
	# $$desc{VARS}->{LIST}->[]: list of variable name
	# $$desc{VARS}->{VAR}->{ms_tem}->{ZNUM}: number of levels for each variable
	# $$desc{VARS}->{VAR}->{ms_tem}->{ATTR}: attribute for each variable
	# $$desc{VARS}->{VAR}->{ms_tem}->{DESC}: description for each variable
	elsif( "$KEYWORD[$j]" eq "VARS" )
	{
	    $ref = { "VAR" => "", "NUM" => $#vlist+1, "LIST" => "" };
	    $$desc{$KEYWORD[$j]} = $ref;
	    $ref = [ @vlist ]; $$desc{$KEYWORD[$j]}->{LIST} = $ref;
	    $ref = {}; $$desc{$KEYWORD[$j]}->{VAR} = $ref;
	    foreach my $var ( @vlist )
	    {
		my @tmp_vargs = split /\s+/, $vargs{$var};
		$ref = {}; $$desc{$KEYWORD[$j]}->{VAR}->{$var} = $ref;
		$$desc{$KEYWORD[$j]}->{VAR}->{$var}->{ZNUM} = $tmp_vargs[0];
		$$desc{$KEYWORD[$j]}->{VAR}->{$var}->{ATTR} = $tmp_vargs[1];
		$$desc{$KEYWORD[$j]}->{VAR}->{$var}->{DESC} = @tmp_vargs[2..$#tmp_vargs];
	    }
	}

	else
	{
	    print STDERR "ctl syntax error: ${KEYWORD[$j]} is not supported now\n";
	    exit 1;
	}

    }
    return;
}

############################################################
#
# analyze netCDF file
#
############################################################
sub ana_nc()
{
    my $nc      = shift;
    my $desc     = shift;

    my $mode = "";
    my $mode2 = "";
    my $val;
    my $var = "";
    my @tdef_units = ();
    my $ref;

    $ref = { "NUM" => 0, "LIST" => "", "VAR" => "" };
    $$desc{VARS} = $ref;
    $ref = []; $$desc{VARS}->{LIST} = $ref;
    $ref = {} ; $$desc{VARS}->{VAR} = $ref;

    LINELOOP: for( my $i=0; $i<=$#$nc; $i++ )
    {
	if( $$nc[$i] =~ /^\s*$/ ){ next LINELOOP; }

	#
	#----- change mode
	#
	if( $$nc[$i] =~ /^(.+):$/ )
	{
	    $mode = $1;
	    $mode2 = "";
	    next;
	}

	#
	#----- mode = dimension
	#
	if( $mode eq "dimensions" )
	{
	    if( $$nc[$i] =~ /^\s*([a-z]+)\s*=\s([0-9]+)\s*;\s*$/i )
	    {
		my $id    = $1;
		$val = $2;
		my $key;

		if(    $id =~ /^lon$/i  ){ $key = "XDEF"; }
		elsif( $id =~ /^lat$/i  ){ $key = "YDEF"; }
		elsif( $id =~ /^lev$/i  ){ $key = "ZDEF"; }
		elsif( $id =~ /^time$/i ){ $key = "TDEF"; }
		$ref = { "NUM" => "$val", "TYPE" => "LEVELS" };
		$$desc{$key} = $ref;
		next LINELOOP;
	    }
	}

	if( $mode eq "variables" )
	{
#print STDERR $$nc[$i] . "\n";
	    if( $$nc[$i] =~ /([a-zA-Z][a-zA-Z0-9_]*) *\((lon|lat|lev|time)( *, *(lon|lat|lev|time))* *\)/i )
	    {
		$var = $1;
#print STDERR "  1: " . $var . "\n";
		if( $var !~ /^(lon|lat|lev|time)$/i )
		{
		    #push( @vlist, $var );
		    $$desc{VARS}->{NUM}++;
		    push( @{$$desc{VARS}->{LIST}}, $var );
		    $ref = { "ZNUM" => 1, "ATTR" => 99, "DESC" => "NONE" } ; $$desc{VARS}->{VAR}->{$var} = $ref;
		    if( $$nc[$i] =~ /[\(\s,]lev[\)\s,]/i )
		    {
			$$desc{VARS}->{VAR}->{$var}->{ZNUM} = $$desc{ZDEF}->{NUM};
		    }
		}
		next LINELOOP;
	    }

	    elsif( $$nc[$i] =~ /$var:([a-zA-Z0-9_]+)\s*=\s*\"?([^\"]*)\"?\s*;/ )
#	    elsif( $$nc[$i] =~ /$var:([a-zA-Z0-9_]+)\s*=\s*\"([^\"]*)\"/ )
	    {
		my ( $attr, $val ) = ( $1, $2 );
#print STDERR "  2: " . $var . "\n";
		if( $var eq "time" && $attr eq "units" )
		{
		    @tdef_units = split( /\s+/, $val );
		    my $tdef_init = `export LANG=en ; date -u --date "$tdef_units[2] $tdef_units[3]" +%H:%MZ%d%b%Y`;
		    $tdef_init =~ s/\n//g;
		    
		    $ref = {}; $$desc{TDEF} = $ref;		    
		    $ref = []; $$desc{TDEF}->{LINEAR} = $ref;
		    $$desc{TDEF}->{LINEAR}->[0] = $tdef_init;
		    #print $$desc{TDEF}->{LINEAR}->[0] . "\n";
		}

		if( $var !~ /^(lon|lat|lev|time)$/i )
		{
		    if( $attr eq "long_name" )
		    {
			if( $val ne "" ){ $$desc{VARS}->{VAR}->{$var}->{DESC} = $val; }
		    }
		    if( $attr eq "_FillValue" )
		    {
 			if( $val ne "" ){ $$desc{VARS}->{VAR}->{$var}->{UNDEF} = $val; }
 			$$desc{UNDEF} = $val;  # overwrite
		    }

		    # : number of levels for each variable


		}
	    }
	    
	}

	elsif( $mode eq "data" )
	{
	    my $chk;
	    if( $$nc[$i] =~ /^\s*([a-z]+)\s*=([^;]+)(;*)$/i )
	    {
		$mode2 = $1;
		$val = $2;
		$chk   = $3;
	    }
	    elsif( $$nc[$i] =~ /^\s*([^;]*)(;*)$/i )
	    {
		$val .= $1;
		$chk    = $2;
	    }

	    if( $chk eq ";" )
	    {
		#print STDERR "mode2=$mode2 val=$value\n";
		#exit 1;
		my @tmp = split( /,/, $val);

		if( $mode2 =~ /^time/i )
		{

		    # assume constant time interval
		    my $dt = $tmp[1] - $tmp[0];
		    if( $tdef_units[0] =~ /seconds/i ){ $dt .= "SEC"; }
		    if( $tdef_units[0] =~ /minutes/i ){ $dt .= "MN"; }
		    if( $tdef_units[0] =~ /hours/i   ){ $dt .= "HR"; }
		    if( $tdef_units[0] =~ /days/i    ){ $dt .= "DY"; }

#		    my $ref = []; $$desc{$key}->{LINEAR} = $ref;
		    
		    $$desc{TDEF}->{LINEAR}->[1] = "$dt";

#		    print $$desc{TDEF}->{LINEAR}->[1] . "\n";
#		    exit 1;

		    #print STDERR "ok: $args{TDEF}\n";
		    #$args{TDEF} .= " LEVELS " . join( " ",@tmp );
		}
		else
		{
		    my $key;
		    if(    $mode2 =~ /^lon$/i  ){ $key = "XDEF"; }
		    elsif( $mode2 =~ /^lat$/i  ){ $key = "YDEF"; }
		    elsif( $mode2 =~ /^lev$/i  ){ $key = "ZDEF"; }
		    elsif( $mode2 =~ /^time$/i ){ $key = "TDEF"; }
		    $ref = []; $$desc{$key}->{LEVELS} = $ref;
		    
		    @{$$desc{$key}->{LEVELS}} = @tmp;
		    
		    #print $$desc{$key}->{LEVELS}->[0] . "\n";
		    #print $$desc{$key}->{LEVELS}->[$$desc{$key}->{NUM}-1] . "\n";

		    &levels2linear( $desc, $key );
		    
		}

		$mode2 = "";
		$val = "";
	    }
	}
    }
}


sub levels2linear()
{
    my $desc = shift;
    my $key  = shift;

    # calculate start and increment if possible
    if( $$desc{$key}->{NUM} < 2 ){ return; }
    #
    my $incre = $$desc{$key}->{LEVELS}->[1] - $$desc{$key}->{LEVELS}->[0];
    my $ref = []; $$desc{$key}->{LINEAR} = $ref;
    $$desc{$key}->{LINEAR}->[0] = $$desc{$key}->{LEVELS}->[0];
    $$desc{$key}->{LINEAR}->[1] = $incre;
    for( my $i=1; $i<=$$desc{$key}->{NUM}-2; $i++ )
    {
	my $incre_tmp = $$desc{$key}->{LEVELS}->[$i+1] - $$desc{$key}->{LEVELS}->[$i];
#	if( $incre != $incre_tmp )
	if( abs( ( $incre - $incre_tmp ) / $incre ) > 1.0e-10 )
	{ undef( @{$$desc{$key}->{LINEAR}} ); last; }
    }
}

sub linear2levels()
{
    my $key   = shift;
    my $start = shift;
    my $incre = shift;
    my $index = shift;

    my $ret;

    if( "$key" eq "EDEF" )
    { print STDERR "error: key=$key with LINEAR is not supported\n"; exit 1; }

    elsif( "$key" eq "TDEF" )
    {
	my $f_tunit;
	if( $incre =~ /^(\d+)(SEC|MN|HR|DY)$/ )
	{
	    $f_tunit = $FAC_TUNIT{uc($2)};
	    $incre = $1 * $f_tunit * ( $index - 1 );
	    $ret = `export LANG=en ; date -u --date "$start $incre seconds" +%H:%MZ%d%b%Y`;
	    $ret =~ s/\n//;
	}
	elsif( $incre =~ /^(\d+)(MO)$/ )
	{
	    $incre = $1 * ( $index - 1 );
	    $ret = `export LANG=en ; date -u --date "$start $incre months" +%H:%MZ%d%b%Y`;
	    $ret =~ s/\n//;
	}
	elsif( $incre =~ /^(\d+)(YR)$/ )
	{
	    $incre = $1 * ( $index - 1 );
	    $ret = `export LANG=en ; date -u --date "$start $incre years" +%H:%MZ%d%b%Y`;
	    $ret =~ s/\n//;
	}
	else
	{
	    print STDERR "error: TDEF increment = $incre\n";
	}
    }
    
    else
    {
	$ret = $start + $incre * ( $index - 1 );
    }
    
    return $ret;
}


sub levels()
{
    my $desc = shift;
    my $key = shift;
    my $idx = shift;
    my $ret;

    if( defined( $$desc{$key}->{LEVELS} ) )
    {
	$ret = $$desc{${key}}->{LEVELS}->[$idx-1];
    }
    else
    {
	$ret = &linear2levels( $key, $$desc{$key}->{LINEAR}->[0], $$desc{$key}->{LINEAR}->[1], $idx );
    }
    return $ret;
}    



sub help()
{
    print << "EOF"
Name:
  grads_ctl.pl Version $ver

Usage:
  grads_ctl.pl
    [ [--ctl] ctl-filename | [--nc] netcdf-filename]
    [ [--key] keyword [ [--target] target] [--unit unit] [--var var] [--value value] ]
    [--ncdump fullpath-to-ncdump]

Options:
  --key ( "DSET" | "TITLE" | "CHSUB" | "OPTIONS" | "UNDEF" | "XDEF" | "YDEF" | "ZDEF" | "TDEF" | "EDEF" | "DIMS")
    Output all in control-file style. "DIMS" for all the dimensions.

  --key ( "DSET" | "TITLE" | "UNDEF" ) --target "value"
    Output single value.

  --key "DSET" --target ["("|"["]tmin:tmax[")"|"]"]
    Output single value.

  --key "OPTIONS" --target target
    target = ( "TEMPLATE" | "BIG_ENDIAN" | "XREV" ... )
      Output 1 or 0 if specified or not-specified.

  --key ( "XDEF" | "YDEF" | "ZDEF" | "TDEF" | "EDEF" )  --target target
    target = "NUM"
      Number of levels.
    target = "TYPE"
      Type of levels. "LINEAR" or "LEVELS". Output none if not specified.

  --key ( "XDEF" | "YDEF" | "ZDEF" | "TDEF" )  --target target
    target = "INC" [--unit unit]
      Increment. 
    target = ( "ALL" | "ALL-LEVELS" )
      Output all the levels.
    target = index
      index-th level value.

  --key ( "XDEF" | "YDEF" | "ZDEF" )  --target "index" --value value
    Index which is closest to the value.

  --key "TDEF" --target "INC" --unit ( "SEC" | "MN" | "HR" | "DY" )
    Increment with specified time unit.

  --key ( "DIMS" )  --target "NUM"
    Numbers of levels for all the dimensions.

  --key "VARS" --target target
    target = "NUM"
      Number of variables.
    target = "ALL"
      All the name of variables.

  Below keywords are not supported now:
    keyword = "DTYPE", "INDEX", "STNMAP", "UNPACK", "FILEHEADER", "XYHEADER", "THEADER", "HEADERBYTES", "TRAILERBYTES", "XVAR", "YVAR", "ZVAR", "STID", "TVAR", "TOFFVAR", "PDEF", "VECTORPAIRS"

Examples:
  grads_ctl.pl abc.ctl xdef num
    Display number of levels in X coordinate.

EOF
#    [--force-xdef?]
#    return 0;
}
exit 1;
