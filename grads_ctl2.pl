#!/usr/bin/perl
#
# type "./grads_ctl2.pl" or see end of file for help
#
use strict;
my $ver="0.10b2";
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
#	elsif( "$ARGV[$i]" eq "--xdfopen" ){ $arg{xdfopen} = 1; }
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

	    #print $desc_in{TDEF}->{LINEAR}->[0] . "\n";

	    # overwrite by control file (analyze again)
	    &ana_ctl( \@tmp, \%desc );

	}
    
    }
    #
    ############################################################
    #
    # get value (specified by --key)
    #
    ############################################################
    #
    if( "$arg{key}" ne "" )
    {
        #
        #----- key = OPTIONS : true (1) or false (0)
        #   target = XREV, YREV, ZREV, etc...
        #
        if( "$arg{key}" eq "OPTIONS" )
        {
	    if( "$arg{target}" eq "" ){ &dump_ctl( \%desc, "OPTIONS" ); exit; }
	    #
	    if( defined( $desc{OPTIONS}->{$arg{target}} ) )
	    {
		if( $desc{OPTIONS}->{$arg{target}} eq 1 ){ print "1\n"; exit; }
	    }
	    print "0\n";
	    exit;
	}

        #
        #----- key = UNDEF : value
        #
        if( "$arg{key}" eq "UNDEF" )
        {
	    print $desc{UNDEF} . "\n";
	    exit;
	}

        #
        #----- key = XDEF, YDEF, ZDEF, TDEF, EDEF
        #
	if( $arg{key} =~ /^(XDEF|YDEF|ZDEF|TDEF|EDEF)$/ )
	{
            # target = NUM: number of grids
	    if( "$arg{target}" eq "NUM" ){ print $desc{${arg{key}}}->{NUM} . "\n"; exit; }

	    # target = TYPE: level type (LINEAR or LEVELS)
	    if( "$arg{target}" eq "TYPE" ){ print $desc{${arg{key}}}->{TYPE} . "\n"; exit; }

	    # target = STEP: increment of levels
	    #                if inhomogeneoug grid, return NONE
	    #   unit = SEC, MN, HR, DY : output time increment in specified unit
	    #                            (only for key=TDEF)
	    if( "$arg{target}" eq "STEP" )
	    {
		if( defined( $desc{${arg{key}}}->{LINEAR} ) )
		{
		    my $incre = $desc{${arg{key}}}->{LINEAR}->[1];

		    if( "$arg{key}" eq "TDEF" )
		    {
			my $f_tunit = 1;
			
			if( $arg{unit} =~ /^(SEC|MN|HR|DY)$/ )
			{
			    
			    $f_tunit = $FAC_TUNIT{$1};
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
		print "NONE";
		exit;
	    }

	    # target = ALL-LEVELS or ALL : all levels
	    if( "$arg{target}" eq "ALL-LEVELS" || "$arg{target}" eq "ALL" )
	    {
		for( $i=1; $i<=$desc{${arg{key}}}->{NUM}; $i++ )
		{
		    print &levels( \%desc, $arg{key}, $i ) . " ";
		}
		print "\n";
		exit;
	    }

	    # target = n (>=1)    : specified levels
	    if( $arg{target} =~ /^(\d+$)/ )
	    {
		print &levels( \%desc, $arg{key}, $1 ) . "\n";
		exit
	    }
	    
	    #   target = INDEX      : index of level by level value
	    #                         (use --value to specify)
	    if( "$arg{target}" eq "INDEX" && $arg{value} =~ /^-*\d+(\.\d*)*$/ )
	    {
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
	}
	
	#
        #----- key = VARS
	#
	if( "$arg{key}" eq "VARS" )
	{
	    # target = NUM
	    if( "$arg{target}" eq "NUM" )
	    {
		print $desc{VARS}->{NUM} . "\n";
		exit;
	    }

	    elsif( "$arg{target}" eq "ALL" )
	    {
		for( my $i=0; $i<=$desc{VARS}->{NUM}-1; $i++ )
		{
		    print $desc{VARS}->{LIST}->[$i] . " ";
		}
		print "\n";
		exit
	    }

	    # TODO: from here...


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
	print "dump as control file is\n";
	print "under construction\n";
	
	print "\n";
	&dump_ctl( \%desc, "OPTIONS" );
	print "\n";
	exit 1;
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

    if( "$key" eq "OPTIONS" )
    {
	print $key;
	while ( my ( $key, $val ) = each %{$$desc{OPTIONS}} )
	{
	    if( $val == 1 ){ print " " . $key; }
	}
	print "\n";
    }



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
#    my $xdfopen  = shift;  # 0 or 1
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
#    $$desc{aaa} = "bbb";

    #
    #----- analyze and store for desc
    #
    my $ref;
    for( my $j=0; $j<=$#KEYWORD; $j++ )
    {
	if( $args{${KEYWORD[$j]}} eq "" ){ next; }
	#$args{${KEYWORD[$j]}} =~ s/\n+$//;
	my @tmp = split /\s+/, $args{${KEYWORD[$j]}};  # line(s) for key=${KEYWORD[$j]}
#	print $args{${KEYWORD[$j]}} . "\n";
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
#	    print "$$desc{$KEYWORD[$j]}->{BIG_ENDIAN}\n";
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
#	    print $$desc{$KEYWORD[$j]}->{START}->[0] . "\n";
#	    print $$desc{$KEYWORD[$j]}->{END}->[0] . "\n";
#	    print $$desc{$KEYWORD[$j]}->{STR}->[0] . "\n";
	}
	#
	#----- XDEF (, YDEF, ZDEF, TDEF)
	# 
	# $$desc{XDEF}->{NUM}: number of levels
	# $$desc{XDEF}->{TYPE}: type of levels (LINEAR or LEVELS)
	# $$desc{XDEF}->{LEVELS}->[]: each level
	# $$desc{XDEF}->{LINEAR}->[]: start and increment
	#
	elsif(    "$KEYWORD[$j]" eq "XDEF" 
	       || "$KEYWORD[$j]" eq "YDEF" 
	       || "$KEYWORD[$j]" eq "ZDEF"
	       || "$KEYWORD[$j]" eq "TDEF" )
	{
	    if( $tmp[0] !~ /^[0-9]+$/ ){ shift(@tmp); }  # possible xdfopen style -> shift
#	    if( $xdfopen eq 1 ){ shift(@tmp); }

	    $tmp[1] = uc( $tmp[1] );
	    $ref = { "$tmp[1]" => "", "NUM" => "$tmp[0]", "TYPE" => "$tmp[1]" };
	    $$desc{$KEYWORD[$j]} = $ref;

	    if( "$tmp[1]" eq "LEVELS" )
	    {
#		$ref = [1, 2, 1];
		$ref = [ @tmp[2..$#tmp] ];
		$$desc{$KEYWORD[$j]}->{LEVELS} = $ref;


#		if( "$KEYWORD[$j]" eq "ZDEF" )
#		{
#		    print $tmp[0];
#		    exit ;
#		}
		# calculate start and increment if possible
		&levels2linear( $desc, $KEYWORD[$j] );

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

#	    print $tmp[1] . "\n";
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
#    my $ref_hash = { "aa" => "bb" };
#    print $$ref_hash{aa};
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

#    my @vlist;         # variable list
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
#		$$desc{$key}->{NUM} = $val;
#		$$desc{$key}->{TYPE} = "LEVELS";
		next LINELOOP;
	    }
	}

	if( $mode eq "variables" )
	{
	    if( $$nc[$i] =~ /([a-zA-Z][a-zA-Z0-9_]*) *\((lon|lat|lev|time)( *, *(lon|lat|lev|time))* *\)/i )
	    {
		$var = $1;
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
#		    print $attr . "\n";
#		    print $val . "\n";
#		    exit 1;
		    if( $attr eq "long_name" )
		    {
			$$desc{VARS}->{VAR}->{$var}->{DESC} = $val;
#			exit;
		    }
		    if( $attr eq "_FillValue" )
		    {
 			$$desc{VARS}->{VAR}->{$var}->{UNDEF} = $val;
 			$$desc{UNDEF} = $val;  # overwrite
#			print $val . ": ok\n";
#			exit;
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
    my $incre = $$desc{$key}->{LEVELS}->[1] - $$desc{$key}->{LEVELS}->[0];
    my $ref = []; $$desc{$key}->{LINEAR} = $ref;
    $$desc{$key}->{LINEAR}->[0] = $$desc{$key}->{LEVELS}->[0];
    $$desc{$key}->{LINEAR}->[1] = $incre;
    for( my $i=1; $i<=$$desc{$key}->{NUM}-2; $i++ )
    {
	if( $incre != $$desc{$key}->{LEVELS}->[$i+1] - $$desc{$key}->{LEVELS}->[$i] )
	{ undef(@{$$desc{$key}->{LINEAR}}); last; }
    }
}

sub linear2levels()
{
    my $key = shift;
    my $start = shift;
    my $incre = shift;
    my $index = shift;

    my $ret;

    if( "$key" eq "EDEF" )
    { print STDERR "error: key=$key with LINEAR is not supported\n"; exit 1; }

    elsif( "$key" eq "TDEF" )
    {
	my $f_tunit;
	if( $incre=~ /^(\d+)(SEC|MN|HR|DY)$/ )
	{
	    $f_tunit = $FAC_TUNIT{uc($2)};
	    $incre = $1 * $f_tunit * ( $index - 1 );
	}
	else
	{
	    print STDERR "error: TDEF increment = $incre\n";
	}
	$ret = `export LANG=en ; date -u --date "$start $incre seconds" +%H:%MZ%d%b%Y`;
	$ret =~ s/\n//;
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
  grads_ctl2.pl Version $ver

Usage:
  grads_ctl2.pl
    [--ctl ctl-filename | --nc netcdf-filename]
    [--key keyword [--target target] [-unit unit] [--var var] [--value value] ]
    [--ncdump fullpath-to-ncdump]

Options:
  --key "OPTIONS"
    Output all the OPTIONS in control-file style.

  --key "OPTIONS" --target target
    target = ( "TEMPLATE" | "BIG_ENDIAN" | "XREV" ... )
      Output 1 or 0 if specified or not-specified.


"UNDEF"
    keyword = XYZDEF
    keyword = var-name

Examples:
  grads_ctl2.pl --ctl abc.ctl --key XDEF --target NUM
    Display number of levels in X coordinate.

EOF
#    [--force-xdef?]

}
exit 1;
