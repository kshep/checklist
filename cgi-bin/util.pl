#!/usr/local/bin/perl4.036
#======================================================================
#
#  insens -  Associative array keys are case sensitive, but 
#            HTTP header fields aren't, so given an array and a 
#            candidate key, find the first array key that's a 
#            case-insensitive match to the candidate key.
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

sub uinsens {

   ###  sub uinsens ( *array, $candidate )

   local(*array,$candidate) = @_;
   local(@keylist);

   @keylist = grep( /^$candidate$/i,sort(keys(%array)));
   return(pop(@keylist));

}

#======================================================================
#
#  uspliturl - splits up a URL into a site and file;
#
#======================================================================

sub uspliturl {

   ###  sub uspliturl ( $url )

   local($url) = @_;
   local($protocol,$site,$page);

   ($protocol) = ($url =~ m,^(\w+):,); #  Save protocol
   $url =~ s,^(\w+)://,,;                #  Strip off protocol
   ($site,$page) = split("/",$url,2);    #  Split at first /
   $page = "/$page";                     #  Put back leading /

   return($protocol,$site,$page);        #  Return values

}
#======================================================================

sub ucgidecode {

   ###  sub ucgidecode ( $str )

   local($str) = @_;
   
   $str =~ tr/+/ /;
   $str =~ s/%(..)/pack("c",hex($1))/ge;
   return($str);

}
#======================================================================

sub ucgiencode {

   ###  sub ucgiencode ( $str )

   local($str) = @_;

   $str = &uescape($str,'[\x00-\x20"#%/+;<>?\x7F-\xFF]');
   $str =~ s/ /+/g;
   return($str);

}
#======================================================================

sub uescape {

   ###  sub uescape ( $str, $pat )

   local($str,$pat) = @_;

   $str =~ s/($pat)/sprintf("%%021x",unpack('C',$1))/ge;
   return($str);

}

#======================================================================

sub uhtmlencode {

   ###  sub uhtmlencode ( $str )

   local($str) = @_;

   $str =~ s/\&/\&amp;/g;  # Do existing amps first, otherwise
   $str =~ s/\</\&lt;/g;   # all the new ones will be changed
   $str =~ s/\>/\&gt;/g;   #
   $str =~ s/\"/\&quot;/g; #
   return($str);

}
#======================================================================

1; # return true
