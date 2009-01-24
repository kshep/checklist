#!/usr/local/bin/perl4.036
#======================================================================
#
# login.pl - script to redirect to the page specified by the 
#            argument "listname"
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

   if ( $ENV{'HOME'} eq "" ) {
      unshift(@INC,'/u6/users/kens/public_html/cgi-bin');
   } elsif ( $ENV{'HOME'} eq "C:\\" ) {
      unshift(@INC,'c:\website\cgi-shl');
   } else { die "Content/type: text/plain\n\n Bad install"; }

   require "cgi-lib.pl";
   require "config.pl";
   require "throw.pl";
   require "date.pl";

   &ReadParse(*input);

   $date = &datetotz(&datenow,"PST");
   $user = $input{'user'};

   &config($user);

   open(LOG,">> ${G'datadir}access.log");
   print LOG "$date $G'user --- LOGIN \n";
   close(LOG);

   if ( $user ) {

      if ( -e "${G'userdocdir}index.htm" ) {
         print "Location: ${G'userdocpath}index.htm\n\n";
      } else {
         print "Location: ${G'docpath}invalid.htm\n\n";
      }

   } else {
      print "Location: ${G'docpath}invalid.htm\n\n";
   }

#======================================================================
