#!/usr/local/bin/perl4.036
#----------------------------------------------------------------------
   
   
   if ( $ENV{'HOME'} eq "" ) {
      unshift(@INC,'/u6/users/kens/public_html/cgi-bin');
   } elsif ( $ENV{'HOME'} eq "C:\\" ) {
      unshift(@INC,'c:\website\cgi-shl');
   } else { die "Content/type: text/plain\n\n Bad install"; }

   require "config.pl";
   require "cgi-lib.pl";
   require "dumpvar.pl";
   
   &config("kens");
   &ReadParse(*input);
   
   print "Content-type: text/plain\n\n";
   
   if ( $input{'dump'} ) { 
      &dumpvar($input{'dump'})
   } else {
      open(FILE,$G'datadir.$input{'file'}) || print "Footer failed.";
      while(<FILE>){ print; }
   }
   
#----------------------------------------------------------------------
