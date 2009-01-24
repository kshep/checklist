#!/usr/local/bin/perl4.036
#======================================================================
#
# /cgi-bin/changed.pl
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

   if ( $ENV{'HOME'} eq "" ) {
      unshift(@INC,'/u6/users/kens/public_html/cgi-bin');
   } elsif ( $ENV{'HOME'} eq "/u6/users/kens" ) {
      unshift(@INC,'/u6/users/kens/public_html/cgi-bin');
   } elsif ( $ENV{'HOME'} eq "C:\\" ) {
      unshift(@INC,'c:\website\cgi-shl');
   } else { die "Content/type: text/plain\n\n Bad install"; }

   require "config.pl";
   require "cgi-lib.pl";
   require "agent.pl";

   &ReadParse(*input);

   &config($input{'user'});
   &agent("changed",%input); 

#======================================================================
