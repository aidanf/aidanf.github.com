#! /usr/local/bin/perl -w

use strict;

package BodyTextExtor;


########################################################################################################################
##
##                                    PUBLIC methods
##
########################################################################################################################
sub new
{
    my $self = {};
    
    shift;
    
    $self->{HTML} = shift;

    _remove_crap($self);
    _identify_tags($self);
    _identify_text($self);
    _convert_to_binary($self);
    _encode_binary($self);
    _initialise_lookups($self);

    bless($self);

    return($self);
}


sub body_text
{
    my $self=shift;
    my $encoded = $self->{encoded};
    my $l = scalar(@$encoded);
    my $i_max=0;
    my $j_max=$l-1;
    my ($i,$j,$pre_len,$end);
    my ($tst_obj, $obj_max);
#get best obj fcn
    $obj_max=0;
    for($i=0;$i<$l-2;$i++){
	for($j=$i+1;$j<$l-1;$j++){
	    my $tst_obj = _objective_fcn2($self,$i,$j);
	    if($tst_obj>$obj_max){
		$obj_max = $tst_obj;
		$i_max=$i;
		$j_max=$j;
	    }
	}
    }
    
#translate out encoded indices to binary indices
    for($i=0;$i<$i_max;$i++){
	$pre_len+=abs(@$encoded[$i]);
    }
    $end = $pre_len;
    for($i=$i_max;$i<$j_max;$i++){
	$end+=abs(@$encoded[$i]);
    }
    

    # end text extraction
    my $output;
    # prepare to print extractd results
    $output="";
    for($i=$pre_len;$i<$end;$i++)
    {
	$output = $output.$self->{document}[$i]." " if $self->{document}[$i] ne 'TAG';    
    }
    
    return _translate_html_entities($output);
}

########################################################################################################################
##
##                                    PRIVATE methods
##
########################################################################################################################

sub _objective_fcn2{
    my $self=shift;
    my $i=shift;
    my $j=shift;
    my $return_val=0;

    my $index;
    my $lookup0_N = $self->{lookup0_N};
    my $lookupN_0 = $self->{lookupN_0};
    my $encoded = $self->{encoded};

    $return_val-=@$lookup0_N[$i];

    for($index=$i;$index<=$j-1;$index++){
        if(@$encoded[$index]>0){
	   $return_val+=@$encoded[$index];
        }
    }

    $return_val-=@$lookupN_0[$j];

    return $return_val;
}


sub _remove_crap{
#############################
# get rid of comments       #
#############################
    my $self = shift;
$self->{HTML} =~ s{ <!                   # comments begin with a `<!'
                        # followed by 0 or more comments;

    (.*?)		# this is actually to eat up comments in non 
			# random places

     (                  # not suppose to have any white space here

                        # just a quick start; 
      --                # each comment starts with a `--'
        .*?             # and includes all text up to and including
      --                # the *next* occurrence of `--'
        \s*             # and may have trailing while space
                        #   (albeit not leading white space XXX)
     )+                 # repetire ad libitum  XXX should be * not +
    (.*?)		# trailing non comment text
   >                    # up to a `>'
}{
    if ($1 || $3) {	# this silliness for embedded comments in tags
	"<!$1 $3>";
    } 
}gesx;                 # mutate into nada, nothing, and niente


# .. and scripts
$self->{HTML} =~ s#<script.*?/script>#<script></script>#gsi;
}

sub _identify_tags{
###############################
# identify the remaining tags #
###############################
    my $self=shift;
$self->{HTML} =~ s{ <                    # opening angle bracket

    (?:                 # Non-backreffing grouping paren
         [^>'"] *       # 0 or more things that are neither > nor ' nor "
            |           #    or else
         ".*?"          # a section between double quotes (stingy match)
            |           #    or else
         '.*?'          # a section between single quotes (stingy match)
    ) +                 # repetire ad libitum
                        #  hm.... are null tags <> legal? XXX
   >                    # closing angle bracket
}{ TAG }gsx;                 # mutate into nada, nothing, and niente
}

sub _identify_text{
    my $self=shift;
    my @document = split(" ",$self->{HTML});
    $self->{document} = \@document;
    $self->{HTML}=~s{\S+}{($& eq 'TAG') ? 'TAG' : 'TEXT'}gise;
}

sub _convert_to_binary{
    my $self=shift;
#convert to binary string
    $self->{HTML}=~s/\s+//g;
    $self->{HTML}=~s/TAG/0/g;
    $self->{HTML}=~s/TEXT/1/g;

#make sure we only have 1's or 0's
    $self->{HTML}=~s/\D//g;
    my @bin_doc=($self->{HTML}=~/1|0/g);
    $self->{bin_doc}=\@bin_doc;
}

sub _encode_binary{
#set up encoded array
    my $self=shift;
    my $bin_doc = $self->{bin_doc};
    my @encoded=();
    my $total_len = scalar(@$bin_doc);
    my $curr=@$bin_doc[0];
    my $enc_count=0;
    my ($i,$j);

    for($i=0;$i<$total_len;$i++){
	if(@$bin_doc[$i]==$curr){
	    $enc_count++;
	}
	else{
	    if($curr==0){
		push(@encoded ,-$enc_count);
	    }else{
		push(@encoded ,$enc_count);
	    }
	    $enc_count=1;
	    $curr = ($curr + 1) % 2;
	}
    }
    push(@encoded ,-$enc_count);
    $self->{encoded}=\@encoded;
#finished encoded
}

sub _initialise_lookups{
#lookuptables
    my $self=shift;
    my @lookup0_N=();
    my @lookupN_0=();
    my $encoded = $self->{encoded};
    my $l = scalar(@$encoded);

    if(@$encoded[0]<0){
	$lookup0_N[0]=@$encoded[0];
    }
    else{
	$lookup0_N[0]=0;
    }
    
    if(@$encoded[$l-1]<0){
	$lookupN_0[$l-1]=@$encoded[$l-1];
    }
    else{
	$lookupN_0[$l-1]=0;
    }
    for (my $i=1;$i<$l;$i++){
	if(@$encoded[$i]<0){
	    $lookup0_N[$i] = $lookup0_N[$i-1] + @$encoded[$i];
	}
	else{
	    $lookup0_N[$i] = $lookup0_N[$i-1];
	}
    }
    for (my $i=$l-2;$i>=0;$i--){
	if(@$encoded[$i]<0){
	    $lookupN_0[$i] = $lookupN_0[$i+1] + @$encoded[$i];
	}
	else{
	    $lookupN_0[$i] = $lookupN_0[$i+1];
	}
    }
    $self->{lookup0_N}=\@lookup0_N;
    $self->{lookupN_0}=\@lookupN_0;
}

sub _translate_html_entities{
######################################
# translate html entities to text   #
#####################################
    my $out = shift;

    my %entity = (

        lt     => '<',     #a less-than
        gt     => '>',     #a greater-than
        amp    => '&',     #a nampersand
        quot   => '"',     #a (verticle) double-quote

        nbsp   => chr 160, #no-break space
        iexcl  => chr 161, #inverted exclamation mark
        cent   => chr 162, #cent sign
        pound  => chr 163, #pound sterling sign CURRENCY NOT WEIGHT
        curren => chr 164, #general currency sign
        yen    => chr 165, #yen sign
        brvbar => chr 166, #broken (vertical) bar
        sect   => chr 167, #section sign
        uml    => chr 168, #umlaut (dieresis)
        copy   => chr 169, #copyright sign
        ordf   => chr 170, #ordinal indicator, feminine
        laquo  => chr 171, #angle quotation mark, left
        not    => chr 172, #not sign
        shy    => chr 173, #soft hyphen
        reg    => chr 174, #registered sign
        macr   => chr 175, #macron
        deg    => chr 176, #degree sign
        plusmn => chr 177, #plus-or-minus sign
        sup2   => chr 178, #superscript two
        sup3   => chr 179, #superscript three
        acute  => chr 180, #acute accent
        micro  => chr 181, #micro sign
        para   => chr 182, #pilcrow (paragraph sign)
        middot => chr 183, #middle dot
        cedil  => chr 184, #cedilla
        sup1   => chr 185, #superscript one
        ordm   => chr 186, #ordinal indicator, masculine
        raquo  => chr 187, #angle quotation mark, right
        frac14 => chr 188, #fraction one-quarter
        frac12 => chr 189, #fraction one-half
        frac34 => chr 190, #fraction three-quarters
        iquest => chr 191, #inverted question mark
        Agrave => chr 192, #capital A, grave accent
        Aacute => chr 193, #capital A, acute accent
        Acirc  => chr 194, #capital A, circumflex accent
        Atilde => chr 195, #capital A, tilde
        Auml   => chr 196, #capital A, dieresis or umlaut mark
        Aring  => chr 197, #capital A, ring
        AElig  => chr 198, #capital AE diphthong (ligature)
        Ccedil => chr 199, #capital C, cedilla
        Egrave => chr 200, #capital E, grave accent
        Eacute => chr 201, #capital E, acute accent
        Ecirc  => chr 202, #capital E, circumflex accent
        Euml   => chr 203, #capital E, dieresis or umlaut mark
        Igrave => chr 204, #capital I, grave accent
        Iacute => chr 205, #capital I, acute accent
        Icirc  => chr 206, #capital I, circumflex accent
        Iuml   => chr 207, #capital I, dieresis or umlaut mark
        ETH    => chr 208, #capital Eth, Icelandic
        Ntilde => chr 209, #capital N, tilde
        Ograve => chr 210, #capital O, grave accent
        Oacute => chr 211, #capital O, acute accent
        Ocirc  => chr 212, #capital O, circumflex accent
        Otilde => chr 213, #capital O, tilde
        Ouml   => chr 214, #capital O, dieresis or umlaut mark
        times  => chr 215, #multiply sign
        Oslash => chr 216, #capital O, slash
        Ugrave => chr 217, #capital U, grave accent
        Uacute => chr 218, #capital U, acute accent
        Ucirc  => chr 219, #capital U, circumflex accent
        Uuml   => chr 220, #capital U, dieresis or umlaut mark
        Yacute => chr 221, #capital Y, acute accent
        THORN  => chr 222, #capital THORN, Icelandic
        szlig  => chr 223, #small sharp s, German (sz ligature)
        agrave => chr 224, #small a, grave accent
        aacute => chr 225, #small a, acute accent
        acirc  => chr 226, #small a, circumflex accent
        atilde => chr 227, #small a, tilde
        auml   => chr 228, #small a, dieresis or umlaut mark
        aring  => chr 229, #small a, ring
        aelig  => chr 230, #small ae diphthong (ligature)
        ccedil => chr 231, #small c, cedilla
        egrave => chr 232, #small e, grave accent
        eacute => chr 233, #small e, acute accent
        ecirc  => chr 234, #small e, circumflex accent
        euml   => chr 235, #small e, dieresis or umlaut mark
        igrave => chr 236, #small i, grave accent
        iacute => chr 237, #small i, acute accent
        icirc  => chr 238, #small i, circumflex accent
        iuml   => chr 239, #small i, dieresis or umlaut mark
        eth    => chr 240, #small eth, Icelandic
        ntilde => chr 241, #small n, tilde
        ograve => chr 242, #small o, grave accent
        oacute => chr 243, #small o, acute accent
        ocirc  => chr 244, #small o, circumflex accent
        otilde => chr 245, #small o, tilde
        ouml   => chr 246, #small o, dieresis or umlaut mark
        divide => chr 247, #divide sign
        oslash => chr 248, #small o, slash
        ugrave => chr 249, #small u, grave accent
        uacute => chr 250, #small u, acute accent
        ucirc  => chr 251, #small u, circumflex accent
        uuml   => chr 252, #small u, dieresis or umlaut mark
        yacute => chr 253, #small y, acute accent
        thorn  => chr 254, #small thorn, Icelandic
        yuml   => chr 255, #small y, dieresis or umlaut mark
    );
    ####################################################
    # now fill in all the numbers to match themselves
    ####################################################
    my $chr;
    for $chr ( 0 .. 255 ) { 
        $entity{ '#' . $chr } = chr $chr;
    }


$out =~ s{ (
        &              # an entity starts with a semicolon
        ( 
	    \x23\d+    # and is either a pound (#) and numbers
	     |	       #   or else
	    \w+        # has alphanumunders up to a semi
	)         
        ;?             # a semi terminates AS DOES ANYTHING ELSE (XXX)
    )
} {

    $entity{$2}        # if it's a known entity use that
        ||             #   but otherwise
        $1             # leave what we'd found; NO WARNINGS (XXX)

}gex;                  # execute replacement -- that's code not a string

    return $out;
}


return 1;

# (c) Aidan Finn (2001)
# released under the terms of the GNU GPL














































