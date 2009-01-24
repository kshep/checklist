#!/usr/local/bin/perl4.036
#======================================================================
#
#  config - sets up all paths and page variables given a userid
# 
#           Puts all variables in the G package, so they can be
#           accessed easily.
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

require "throw.pl";
require "date.pl";

sub config {

   ###  sub config ( $user )

   package G;

   #
   #  Identify the installation site
   #
   if    ( $ENV{'HOME'} eq ""              )  { $site = "aimnet"; } 
   elsif ( $ENV{'HOME'} eq "/u6/users/kens" ) { $site = "aimnet"; } 
   elsif ( $ENV{'HOME'} eq "C:\\"           ) { $site = "pc"; } 
   else  { die "Content/type: text/plain\n\n Bad install"; }

   #
   #  User name passed as single argument
   #
   ($user) = @_;

   $tz = "PST";
   $date = &'datetotz(&'datenow,$tz);

   if ( ! $user ) { &main'throw("CheckList doesn't know who you are",$user) };

   #
   #  CheckList install site
   #
   if ( $site eq "pc" ) {
      $basepath    = "http://localhost/";
      $basedir     = "c:/website/";
      $userdocdir  = $basedir . "htdocs/" . $user . "/"; 
   }
   elsif ( $site eq "aimnet" ) {
      $basepath    = "http://www.aimnet.com";
      $basedir     = "/u6/users/kens/public_html/";
      $datadir     = $basedir . "data/";
      $userdocdir  = $basedir . "users/" . $user . "/"; 
   }


   #
   #  Paths to documents
   #
   $rcgipath     = "/~kens/cgi-bin/";
   $rdocpath     = "/~kens/";
   $ruserdocpath = "/~kens/users/" . $user . "/";
   $rimagepath   = "/~kens/images/";

   $cgipath     = $basepath . $rcgipath;
   $docpath     = $basepath . $rdocpath;
   $userdocpath = $basepath . $ruserdocpath;
   $imagepath   = $basepath . $rimagepath;

   $rlogoimage        = $rimagepath . "logo.gif";
   $rheaderimage      = $rimagepath . "check.gif";
   $rbulletimage      = $rimagepath . "bullet.gif";
   $rcheckimage       = $rimagepath . "minichek.gif";
   $rlineimage        = $rimagepath . "line.gif";
   $rblankimage       = $rimagepath . "blank.gif";
   $rchecklineimage   = $rimagepath . "checkline.gif";

   $logoimage        = $imagepath . "logo.gif";
   $headerimage      = $imagepath . "check.gif";
   $bulletimage      = $imagepath . "bullet.gif";
   $checkimage       = $imagepath . "minichek.gif";
   $lineimage        = $imagepath . "line.gif";
   $blankimage       = $imagepath . "blank.gif";
   $checklineimage   = $imagepath . "checkline.gif";

   #
   #  Data directories
   #
   $datadir     = $basedir . "data/";
   $userdatadir = $datadir . "users/" . $user . "/";
   $pagedatadir = $datadir . "pages/";
   $dbdir       = $datadir . "db/";
   $uploaddir   = $userdatadir . "uploads/";

   $logfile     = $datadir . "main.log";
   $errfile     = $datadir . "main.err";

   $dbfile      = $dbdir . "main.pdb";

   $checklist   = $userdatadir . "check.lst";

}

#======================================================================
1; # return true
