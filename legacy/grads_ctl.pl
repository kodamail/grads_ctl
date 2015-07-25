#!/usr/bin/perl
#
# usage:
#   grads_ctl.pl (ctl=ctl-filename | nc=netcdf-filename)
#
#
#     key=VAR_LIST: all the variable names (separated with space)
#     key=VDEF: number of variables
#

use strict;
use CGI;
my $cgi = new CGI;

############################################################
#
# arguements
#
############################################################
my $fname_ctl =     $cgi->param( 'ctl'    );
my $fname_nc  =     $cgi->param( 'nc'     );
my $key       = uc( $cgi->param( 'key'    ) );
my $var       = uc( $cgi->param( 'var'    ) );
my $target    = uc( $cgi->param( 'target' ) );
my $unit      = uc( $cgi->param( 'unit'   ) );
my $value     =     $cgi->param( 'value'  );
#Smy $pos       =     $cgi->param( 'pos'    );
#if( $fname_ctl eq "" )
#{ print STDERR "ctl is not specified.\n"; exit; }
if( $key eq "" )
{ print STDERR "key is not specified.\n"; exit; }

############################################################
#
# constant
#
############################################################
# all the key words
my @KEYWORD = ( "DSET", "CHSUB", "DTYPE", "INDEX", "STNMAP", 
		"TITLE", "UNDEF", "UNPACK", "FILEHEADER", "XYHEADER", 
		"THEADER", "HEADERBYTES", "TRAILERBYTES", "XVAR", "YVAR", 
		"ZVAR", "STID", "TVAR", "TOFFVAR", "OPTIONS", 
		"PDEF", "XDEF", "YDEF", "ZDEF", "TDEF", 
		"EDEF", "VECTORPAIRS", "VARS", "ENDVARS" );
# key words which allow multiple line
my @KEYWORD_ML = ( "XDEF", "YDEF", "ZDEF", "EDEF" );

# factor to convert to sec 
my %f_tunit = ( "SEC" => 1, "MN" => 60, "HR" => 3600, "DY" => 86400 );


############################################################
#
# read control file
#
############################################################
my @ctl;
if( "$fname_ctl" ne "" )
{
    if( open(LINK, "< $fname_ctl") )
    {
	@ctl = <LINK>;
	close(LINK);
    }
}

############################################################
#
# read NetCDF header
#
############################################################
my @nc;
if( "$fname_nc" ne "" )
{
    my $tmp = `ncdump -c $fname_nc`;
    #@nc = split( /\s/, $tmp );
    @nc = split( /\n/, $tmp );
}
#exit 1;
#print "ok\n";

############################################################
#
# analyze control file
#   obtain args for each syntax
#   obtain variable list
#
############################################################
my $key_now = "";  # current key
my %args;          # arguements for each key
my @vlist;         # variable list
my %vargs;         # arguements for each variable
LINELOOP: for( my $i=0; $i<=$#ctl; $i++ )
{
    if( $ctl[$i] =~ /^\s*$/ ){ next LINELOOP; }
    if( $ctl[$i] =~ /^[*@]/ ){ next LINELOOP; }

    for( my $j=0; $j<=$#KEYWORD; $j++ )
    {
#	if( $ctl[$i] =~ /^$KEYWORD[$j] +(.*)$/i )
	if( $ctl[$i] =~ /^$KEYWORD[$j]( +(.*))?$/i )
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
	    $args{${key_now}} = $args{${key_now}} . $ctl[$i] . " ";
	    next LINELOOP;
	}
    }

    # for variable list
    if( $key_now eq "VARS" )
    {
	my $var_temp;
	if( $ctl[$i] =~ /^([^ ]+)/ ){ $var_temp = uc( $1 ); push( @vlist, $1 ); }
	if( $ctl[$i] =~ /^[^ ]+ +(.*)/ ){ $vargs{$var_temp} = $1; }
	next LINELOOP;
    }

    # syntax error
    my $line = $i + 1;
    print STDERR "error: fails to analyze $fname_ctl (line: $line ctl: $ctl[$i])\n";
    exit;
}


############################################################
#
# analyze netCDF file (NOT prior to ctl)
#
############################################################
if( $args{$key} eq "" )  # if necessary -> try to overwrite
{
    my $mode = "";
    my $mode2 = "";
    my $val;
    my $var = "";
    my @tdef_units = ();
    LINELOOP: for( my $i=0; $i<=$#nc; $i++ )
    {
	if( $nc[$i] =~ /^\s*$/ ){ next LINELOOP; }
	#if( $nc[$i] =~ /^[*@]/ ){ next LINELOOP; }
	
	#print "$i: $nc[$i]\n";
	
	if( $nc[$i] =~ /^(.+):$/ )
	{
	    $mode = $1;
	    $mode2 = "";
	    next;
	}
	
	if( $mode eq "dimensions" )
	{
	    if( $nc[$i] =~ /^\s*([a-z]+)\s*=\s([0-9]+)\s*;\s*$/i )
	    {
		my $id    = $1;
		$val = $2;
		if(    $id =~ /^lon$/i  ){ $args{XDEF} = $val . $args{XDEF}; }
		elsif( $id =~ /^lat$/i  ){ $args{YDEF} = $val . $args{YDEF}; }
		elsif( $id =~ /^lev$/i  ){ $args{ZDEF} = $val . $args{ZDEF}; }
		elsif( $id =~ /^time$/i ){ $args{TDEF} = $val . $args{TDEF}; }
		next LINELOOP;
	    }
	}
	if( $mode eq "variables" )
	{
	    if( $nc[$i] =~ /([a-zA-Z][a-zA-Z0-9_]*) *\((lon|lat|lev|time)( *, *(lon|lat|lev|time))* *\)/i )
	    {
		$var = $1;
		if( $var !~ /^(lon|lat|lev|time)$/i )
		{
		    push( @vlist, $var );
		}
		next LINELOOP;
	    }
	    elsif( $var eq "time" )
	    {
		if( $nc[$i] =~ /time:units\s*=\s\"([^\"]*)\"/i )
		{
		    @tdef_units = split( /\s+/, $1 );
		    #print STDERR "0:$tdef_units[0]" . "\n";
		    #print STDERR "1:$tdef_units[1]" . "\n";
		    #print STDERR "2:$tdef_units[2]" . "\n";
		    #print STDERR "3:$tdef_units[3]" . "\n";
		    my $tdef_init = `date --date "$tdef_units[2] $tdef_units[3]" +%H:%Mz%d%b%Y`;
		    $tdef_init =~ s/\n//g;
		    $args{TDEF} .= " LINEAR $tdef_init";
		}
		
		#print STDERR "$nc[$i]\n";
	    }

	    
	}
	elsif( $mode eq "data" )
	{
	    my $chk;
	    if( $nc[$i] =~ /^\s*([a-z]+)\s*=([^;]+)(;*)$/i )
	    {
		$mode2 = $1;
		$val = $2;
		$chk   = $3;
	    }
	    elsif( $nc[$i] =~ /^\s*([^;]*)(;*)$/i )
	    {
		$val .= $1;
		$chk    = $2;
	    }

	    if( $chk eq ";" )
	    {
		#print STDERR "mode2=$mode2 val=$value\n";
		#exit 1;
		my @tmp = split( /,/, $val);
		if(    $mode2 =~ /^lon/i  ){ $args{XDEF} .= " LEVELS " . join( " ",@tmp ); }
		elsif( $mode2 =~ /^lat/i  ){ $args{YDEF} .= " LEVELS " . join( " ",@tmp ); }
		elsif( $mode2 =~ /^lev/i  ){ $args{ZDEF} .= " LEVELS " . join( " ",@tmp ); }
		elsif( $mode2 =~ /^time/i )
		{
		    # assume constant time interval
		    my $dt = $tmp[1] - $tmp[0];
		    if( $tdef_units[0] =~ /seconds/i ){ $dt .= "SEC"; }
		    if( $tdef_units[0] =~ /minutes/i ){ $dt .= "MN"; }
		    if( $tdef_units[0] =~ /hours/i   ){ $dt .= "HR"; }
		    if( $tdef_units[0] =~ /days/i    ){ $dt .= "DY"; }
		    $args{TDEF} .= " $dt";
		    #print STDERR "ok: $args{TDEF}\n";
		    #$args{TDEF} .= " LEVELS " . join( " ",@tmp );
		}
		#print "XDEF: $args{XDEF} ok\n";
		#print "$val\n";
		$mode2 = "";
		$val = ""
		#exit 1;
	    }
	}
    }
}

# delete space
#for( (my $k, my $v) = each (%args) ){ $args{$k} =~ s/\s+/ /g; }

############################################################
#
# obtain results for the user-specified key
#
############################################################

$args{$key} =~ s/\s+/ /g;
my @args_out = split( / /, $args{$key} );


#
# key = OPTIONS : true (1) or false (0)
#   target = XREV, YREV, ZREV, etc...
#
if( $key eq "OPTIONS" )
{
    for( my $i=0; $i<=$#args_out; $i++ )
    {
	if( $args_out[$i] =~ /$target/i ){ print "1" ; exit; }
    }
    print "0";
    exit;
}

#
# key = XDEF, YDEF, ZDEF, TDEF, EDEF
#   target = NUM        : number of levels
#   target = TYPE       : level type (linear or levels)
#   target = ALL-LEVELS or ALL : all levels
#   target = n (>=1)    : specified levels
#   target = STEP       : increment
#                         if inhomogeneoug grid, return NONE
#     unit = SEC, MN, HR, DY : output time increment in specified unit
#                              (only for key=TDEF)
#
if( $key =~ /^(XDEF|YDEF|ZDEF|TDEF|EDEF)$/ )
{
    # check netCDF-type ctl or not
    if ( ${args_out[0]} =~ /^(lon|lat|lev|time)$/i ){ shift(@args_out); }

    # RETURN number of grids
    my $num = ${args_out[0]};
    if( $num eq "" ){ $num = 1; }
    if( $target eq "NUM" ){ print $num; exit; }


    # RETURN linear or levels
    my $type = uc( ${args_out[1]} );
    if( $target eq "TYPE" ){ print $type; exit; }

    # each level (only for XDEF, YDEF, ZDEF)
    my @level;
    if( $type eq "LINEAR" )
    {
	my $start = uc( ${args_out[2]} );
	my $incre = uc( ${args_out[3]} );

	# RETURN increment
	if( $target eq "STEP" )
	{
	    my $f_tunit = 1;
	    if( $key eq "TDEF" && $unit =~ /^(SEC|MN|HR|DY)$/i )
	    {
		$f_tunit = $f_tunit{$1};
		if( $incre =~ /^(\d+)(SEC|MN|HR|DY)$/i )
		{
		    $f_tunit = $f_tunit{$2} / $f_tunit;
		    $incre = $1 * $f_tunit;
		    $incre = $incre . $unit;
		}
	    }
	    print $incre ;
	    exit;
	}

	# calculate each level
	if( $target == 1 )
	{
	    print $start;
	    exit;
	}
	if( $key eq "TDEF" || $key eq "EDEF" )
	{ print STDERR "error: key=$key with $type is not supported\n"; exit; }
	for( my $i=0; $i<=$num-1; $i++ )
	{
	    $level[$i] = $start + $i * $incre;
	}
    }
    else
    {
	@level = @args_out[2..$#args_out];
    }

    # RETURN increment
    if( $target eq "STEP" )
    {
	my $incre = $level[1] - $level[0];
	for( my $i=1; $i<=$#level-1; $i++ )
	{
	    if( $incre != $level[$i+1] - $level[$i] )
	    { print STDERR "error: increment is not unique\n"; exit; }
	}
	print $incre;
	exit;
    }

    # RETURN all the levels
    if( $target eq "ALL-LEVELS" || $target eq "ALL" )
    {
	print join( " ", @level );
	exit;
    }

    # RETURN one specified level
    if( $target =~ /^\d+$/ )
    {
	if( $target > $num ){ print STDERR "error: specified array index ($target) exceeds number of grid ($num)\n"; exit; }
	if( $target < 1 ){ print STDERR "error: specified array index ($target) is less than 1\n"; exit; }
	print $level[$target-1];
	exit;
    }

    # RETURN index of the specified dimension value
    if( $target eq "INDEX" && $value =~ /^-*\d+(\.\d*)*$/ )
    {
	my $dif_min = 1e+33;
	my $idx = -1;
	for( my $i=0; $i<=$#level; $i++ )
	{
	    my $dif_tmp = abs($level[$i]-$value);
	    if( $dif_min > $dif_tmp )
	    {
		$dif_min = $dif_tmp;
		$idx = $i;
	    }
	}
	print $idx+1;  # . " $level[$idx]\n";
	exit;
    }

#print "ok\n";

#    print STDERR "syntax error\n";
#    exit;
}


#
# key = VAR_LIST
# key = VAR  var = var-name
#   target = LEVS    : number of levels
#   target = UNITS   : 
#   target = COMMENT : description
#
if( $key eq "VAR_LIST" )
{
    for( my $i=0; $i<=$#vlist; $i++ ){ print $vlist[$i] . " "; }
    exit;
}
if( $key eq "VAR" )
{
    my $args = $vargs{$var};
    if( $args eq "" ){ print STDERR "var=" . $var . " does not exist.\n"; exit; }
    if( $target eq "LEVS" )
    {
	if( $args =~ /^ *(\d+)/ ){ print $1; exit; }
	else{ print STDERR "syntax error in VAR LEVS.\n"; exit; }
    }
    if( $target eq "UNITS" )
    {
#	if( $args =~ /^ *(\d+) *([\d,]+)/ ){ print $2; exit; }
#	if( $args =~ /^ *(\d+)  *([\d,-]+)/ ){ print $2; exit; }
	if( $args =~ /^ *(\d+)  *([^ ]+)/ ){ print $2; exit; }
	else{ print STDERR "syntax error in VAR UNITS.\n"; exit; }
    }
    if( $target eq "COMMENT" )
    {
	$args =~ s/\*/\\\*/g;  # sanitize *
	if( $args =~ /^ *(\d+) +([\d,]+) +(.*)$/ ){ print $3; exit; }
	else{ print STDERR "syntax error in VAR COMMENTS.\n"; exit; }
    }
    print STDERR "target=" . $target . " does not exist in key=VAR, ctl=" . $fname_ctl . ".\n";
    exit;
}


#
# key = key : get all the elements of specified key
#
if( $args{$key} ne "" ){ print $args{$key} ; exit; }


print STDERR "key=" . $key . " does not exist in " . $fname_ctl . "\n";
exit;
