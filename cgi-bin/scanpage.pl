#!/usr/local/bin/perl4.036
#======================================================================
#
#  scanpage - process the web page indicated by the pageid specified
#             by the single argument
#
#----------------------------------------------------------------------
#
#  Files Modified
#
#     <pageid>.hst  -  File history
#     <pageid>.htm  -  Most recently retrieved HTML file
#     <pageid>.hdr  -  Header of most recently retrieved HTML file
#     <pageid>.t*   -  Temporary files used only while subs are running
#
#          .tht  -  Temp HTML        (fresh)
#          .thd  -  "    Header      (fresh)
#          .tfo  -  "    filtered old HTML file
#          .tfn  -  "    filtered new HTML file
#          .ths  -  "    history file (newest changes)
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

require "throw.pl";
require "db.pl";
require "date.pl";
require "config.pl";
require "http.pl";
require "util.pl";


sub scanpage {

   ###  sub scanpage ( $pageid )

   local($pageid) = @_;
   local($caller) = caller;
   local($trace);

   if ($caller eq "main") { $trace = 1 };
$trace = 1;

   #
   #  Page delimiter for log file
   #
   $trace && print ">","-"x70,"\n";
   $trace && print ">\n";
   $trace && print "> SCANNING $pageid \n";
   $trace && print ">\n";

   local($date) = &datenow();

   local(%pagedb);
   local($url,$protocol,$site,$page,$base);
   local($headerfile);
   local($htmlfile);
   local($histfile);
   local($tmpheaderfile);
   local($tmphtmlfile);
   local($tmphistfile);
   local($diffnewfile);
   local($diffoldfile);
   local($lastdiffdate);
   local($httpstatus,$httpreason,$httpservdate,$httpmoddate);
   local($compdate);
   local($inline);

   #
   #  Open page database to get location of file
   #
   open(PAGEDB,$G'dbfile) || &throw("Can't open page database");
   &dbread(PAGEDB,*pagedb);
   close(PAGEDB);

   #
   #  Make sure page requested is in DB
   #
   if ( ! defined($pagedb{$pageid}) ) {
      print "$date $pageid not in $G'dbfile\n";
      open(ERR,">> $G'errfile");
      print ERR "$date $pageid not in $G'dbfile\n";
      close(ERR);
      return(0);
   }
 
   #
   #  Get page info from DB
   #
   $url  = $pagedb{$pageid};
   ($protocol,$site,$page) = &uspliturl($url);
   $base = "$protocol://$site";

   #
   #  Build file names
   #   
   $headerfile     = $G'pagedatadir . "$pageid.hdr";
   $htmlfile       = $G'pagedatadir . "$pageid.htm";
   $histfile       = $G'pagedatadir . "$pageid.hst";
   $tmpheaderfile  = $G'pagedatadir . "$pageid.thd";
   $tmphtmlfile    = $G'pagedatadir . "$pageid.tht";
   $tmphistfile    = $G'pagedatadir . "$pageid.ths";
   $diffnewfile    = $G'pagedatadir . "$pageid.tfn"; 
   $diffoldfile    = $G'pagedatadir . "$pageid.tfo"; 

   #
   #  If HTML and header file don't exist (page hasn't been
   #  scanned before) then create them
   #
   if ( ! -e $headerfile ) { open(TMP,"> $headerfile");close(TMP); }
   if ( ! -e $htmlfile   ) { open(TMP,"> $htmlfile");close(TMP); }

   #
   #  Determine when page was last checked
   #
   if ( -e $histfile ){
      #
      #  If history exists, last check date is on first line
      #  preceded by "=== "
      #
      open(HIST,$histfile) || &throw("Can't open $histfile");
      $lastdiffdate = <HIST>;
      chop $lastdiffdate;
      $lastdiffdate =~ s/^=== *//;

   } else {
      #
      #  If no history, create an empty history file and set
      #  last date checked to 0 ( set to some time in 1901 or so)
      #
      open(TMP,"> $histfile"); close(TMP);
      open(HIST,"$histfile") || &throw("Can't open $histfile");
      $lastdiffdate = &datecheck(0);

   }

   #
   #  Open tmp files for header and HTML and get page
   #
   open(HEAD,"> $tmpheaderfile") || &throw("Can't open $tmpheaderfile");
   open(HTML,"> $tmphtmlfile") || &throw("Can't open $tmphtmlfile");

   $t = &httpgetpage($lastdiffdate,$site,$page,HEAD,HTML) || return(0);

   $trace && print ">>>$t<<<\n";

   close(HEAD);
   close(HTML);

   #
   #  Read header for status info and dates
   #
   open(HEAD,$tmpheaderfile) || &throw("Can't open $tmpheaderfile");
   ($httpstatus,$httpreason,$httpservdate,$httpmoddate) = &httpreadhead(HEAD);
   close(HEAD);

   $trace && print ">\n";
   $trace && print "> Status   : $httpstatus\n";
   $trace && print "> Reason   : $httpreason\n";
   $trace && print "> Date     : $httpservdate\n";
   $trace && print "> Modified : $httpmoddate\n";

   #
   #  Process HTML ( 304=Page not modified )
   #
   if ( (($httpstatus < 200)||($httpstatus > 299)) && ($httpstatus!=304) ){

      print "$date $pageid $httpstatus $httpreason\n";

      open(ERR,">> $G'errfile");
      print ERR "$date $pageid $httpstatus $httpreason\n";
      close(ERR);
      $trace && print ">\n> ERR $date $pageid $httpstatus $httpreason\n";

      open(LOG,">> $G'logfile");
      print LOG "$date $pageid ERROR $httpstatus $httpreason\n";
      close(LOG);
      $trace && print "> LOG $date $pageid ERROR $httpstatus $httpreason\n";

      return(0);

   } else {

      #
      #  Compare modification date from server to the date the
      #  page was last diffed
      #
      $compdate = &datecomp($lastdiffdate,$httpmoddate);

      if ( ($compdate == -1) && ( $httpstatus != 304 ) ){

         #
         #  Prepare new and old HTML files for comparison
         #
         $trace && print ">\n";
         $trace && print "> Filtering new file\n";
         open(THT,$tmphtmlfile) || &throw("Can't open $tmphtmlfile");
         open(TFN,"> $diffnewfile") || &throw("Can't open $diffnewfile");
         &filter(THT,TFN,$url,$trace);
         $trace && print "\n";
         close(THT);
         close(TFN);

         $trace && print ">\n";
         $trace && print "> Filtering old file\n";
         open(HTM,$htmlfile) || &throw("Can't open $htmlfile");
         open(TFO,"> $diffoldfile") || &throw("Can't open $diffoldfile");
         &filter(HTM,TFO,$url,$trace);
         $trace && print "\n";
         close(HTM);
         close(TFO);

         #
         #  Compare files
         #
         open(THIST,"> $tmphistfile") ||  &throw("Can't open $tmphistfile");
         open(DIFF,"diff $diffoldfile $diffnewfile |") || 
	    &throw("Can't open diff");

         #
         #  Pipe diff results to temp hist file if there are changes
         #  under the current date
         #
         if($inline = <DIFF>){

            open(LOG,">> $G'logfile") || &throw("Can't open $G'logfile");
            print LOG "$date $pageid $httpstatus $httpreason (diff)\n";
            close(LOG);

            $trace &&
	       print ">\n> LOG $date $pageid $httpstatus $httpreason (diff)\n";

            print THIST "=== $date\n";
            print THIST $inline;
            while(<DIFF>) { 
               print THIST; 
            }

         } else {

            open(LOG,">> $G'logfile");
            print LOG "$date $pageid $httpstatus $httpreason (no diff)\n";
            close(LOG);

            $trace && print ">\n> LOG $date $pageid $httpstatus ";
	    $trace && print "$httpreason (no diff)\n";

         }

         close(DIFF);

         #
         #  Add previous history to temp history file, including
         #  date chopped off to check when last scanned
         #
         if ( $lastdiffdate ne &datecheck("0") ) {
            print THIST "=== $lastdiffdate\n";
            while(<HIST>) { 
               print THIST; 
            }
         }
         close(HIST);
         close(THIST);

         #
         #  Temp history file now contains all history, so make
         #  it perm, along with the temp HTML and header files
         #
         unlink($histfile) || &throw("Can't unlink $histfile");
         rename($tmphistfile,$histfile) || &throw("Can't rename $tmphistfile");
         unlink($htmlfile) || &throw("Can't unlink $htmlfile");
         rename($tmphtmlfile,$htmlfile) || &throw("Can't rename $tmphtmlfile");
         unlink($headerfile) || &throw("Can't unlink $headerfile");
         rename($tmpheaderfile,$headerfile) || 
	    &throw("Can't rename $tmpheaderfile");

         unlink($diffoldfile) || &throw("Can't unlink $diffoldfile");
         unlink($diffnewfile) || &throw("Can't unlink $diffnewfile");

      } else {
         open(LOG,">> $G'logfile");
         print LOG "$date $pageid $httpstatus $httpreason (no comp)\n";
         close(LOG);
         $trace && print ">\n> LOG $date $pageid $httpstatus ";
	 $trace && print "$httpreason (no comp)\n";
      }

   }

   $trace && print ">\n";
   $trace && print ">","-"x70,"\n";
   return(1);

}

#======================================================================
# 
#  filter - Reads an HTML file and writes a file suitable for diffing
#           and display. Assumes the file has been doesn't have any
#           trailing open tags.
#
#----------------------------------------------------------------------
#  Arguments:  file handle of input file (HTML)
#              file handle of output file 
#----------------------------------------------------------------------
#  Returns:    1
#----------------------------------------------------------------------

sub filter {

   ###  sub filter ( $INFILE, $OUTFILE, $trace )

   local($INFILE,$OUTFILE,$url,$trace) = @_;

   local($block,$line,$tag,$act,$lastact);

   local($lnum);
   local($protocol,$site,$page) = &uspliturl($url);
   local($base) = "$protocol://$site";

   local($n) = "\n";
   local($b) = "<BR>\n";
   local($p) = "\n<P>";
   local($text) = "";

   ##
   #
   # The results of diffing two versions of a web page as
   # retrieved from a server could be a mess, so each HTML
   # page must be converted into a diff-friendly format.
   #
   # This format is itself an HTML file to the extent that
   # a diff of two files in this format should generate valid 
   # HTML segments. This new format should retain as much of the
   # original formatting information as possible while allowing
   # diff to make comparisons based on content alone.
   # 
   # The following array gives the rules generating files in
   # this new format. All attributes will be stripped from the
   # original file, some tags will be removed, and the new
   # file will be formated according to the rules here.
   #
   # - Any tags found in the file that do not appear in the table
   #   are deleted.
   #
   # - Tags that start with a % have been modified so that
   #   we can display text found in tag attributes.
   #
   # - If an action is a % ONLY, then the original tag is used
   #   as is, as is the case with anchors.
   #
   # - The rest of the tags are mapped so that the resulting
   #   HTML will look relatively clean when it's chunked up by
   #   diff and markupdiff later on.
   #
   #------------------------------------------------------------
   #
   local(%tagact) = (

      "%IMG",       " [ Image: ",       "/%IMG",       "] ", 
#      "%INPUT",     " [ Input: ",       "/%INPUT",     "] ",
      "A",          "%",                "/A",          "%",
      "ADDRESS",    $n,                 "/ADDRESS",    $n,
      "B",          " ",                "/B",          " ",
      "BLOCKQUOTE", $n,                 "/BLOCKQUOTE", $n,
      "BR",         " | ",
      "CAPTION",    $n,                 "/CAPTION",    $n,
      "CENTER",     $n,                 "/CENTER",     $n,
      "CITE",       $n,                 "/CITE",       $n,
      "CODE",       $n,                 "/CODE",       $n,
      "DD",         "\n<BR>",
      "DIR",        $n,                 "/DIR",        $n,
      "EM",         " ",                "/EM",         " ",
      "FORM",       $p,                 "/FORM",       $p,
      "H1",         $p,                 "/H1",         $p,
      "H2",         $p,                 "/H2",         $p,
      "H3",         $n,                 "/H3",         $b,
      "H4",         $n,                 "/H4",         $b,
      "H5",         $n,                 "/H5",         $b,
      "H6",         $n,                 "/H6",         $b,
      "HR",         $p,
      "I",          " ",                "/I",          " ",
      "IMG",        " [Image] ",  
      "INPUT",      " [Input] ",
      "KBD",        $n,                 "/KBD",        $n, 
      "LI",         "\n<BR>* ",
      "OPTION",     "\n- ",            
      "P",          $p,
      "PRE",        $n,                 "/PRE",        $n,
      "SAMP",       " ",                "/SAMP",       " ",
      "SCRIPT",     "<SCRIPT>",         "/SCRIPT",     "</SCRIPT>",
      "STRONG",     " ",                "/STRONG",     " ",
      "TABLE",      $p,                 "/TABLE",      $p,
      "TEXTAREA",   $n,                 "/TEXTAREA",   $n,
      "TH",         " ",
      "TITLE",      " [ Title: ",       "/TITLE",      "]$n$p",
      "TR",         $b,                 "/TR",         $b,
      "TT",         " ",                "/TT",         " ",
      "VAR",        " ",                "/VAR",        " ",
      "-","-"

   );
   #
   ##

   $trace && print ">";

   $lnum = 0;

   while (<$INFILE>) {

      $lnum++;

      $trace && print "\n>  $lnum  (read)";

      $block =  $_;

      #
      #  Convert each chunk read from INFILE into a block of tags
      #  and text, with either a single tag or text on each line in 
      #  the block
      # 

      $trace && print "(split)";
      $block =~ s/\r//g;             # Strip out returns
      $block =~ s/>([^<])/>\n$1/g;   # Split line after tags
      $block =~ s/([^>])</$1\n</g;   # Split line before tags
      $block =~ s/>\s*</>\n</g;      # Split line between tags

      #
      #  Some sites seem to end up with quite a few AHREFs, so convert
      #  them to A HREFs (and to ANAME just in case.)
      #
      $block =~ s/<\s*AHREF\s*=\s*/<A HREF=/gi;
      $block =~ s/<\s*ANAME\s*=\s*/<A NAME=/gi;


      #
      #  Now convert all relative HREFs to absolutes
      #
      #  First take care of # tags by prepending the url
      #
      #  Then if there's an http: without a /, replace it with
      #  the base ref. Next prepend base to all HREFS, then remove 
      #  if prepending broke the reference.
      #
      #  http:/path/file is also a valid form (?) but we don't catch it.
      #  
      #
      $url =~ s,/$,,;

      $trace && print "(hrefs)";

      $block =~ s,<([^>]*)HREF\s*=\s*(["']?)#,<$1HREF=$2$url#,gi;
      $block =~ s,<([^>]*)HREF\s*=\s*(["']?)(http:)([^/]),<$1HREF=$2$base/$3,gi;
      $block =~ s,<([^>]*)HREF\s*=\s*(["']?),<$1HREF=$2$base/,gi;
      $block =~ s,<([^>]*)HREF\s*=\s*(["']?)$base/+(\w+):,<$1HREF=$2$3:,gi;
      $block =~ s,<([^>]*)HREF\s*=\s*(["']?$base)/+,<$1HREF=$2/,gi;

      #
      #  Move ALTs of IMGs out of tags and delimit with %IMG
      #

      $trace && print "(alts)";
      while ( $block =~ /< *IMG[^>]*ALT *= */i ) {
         $block =~ 
           s/< *IMG([^>]*)ALT *= *"([^>"]*)"([^>]*)>/<%IMG$1$3>\n$2\n<\/%IMG>/i;
         $block =~ 
           s/< *IMG([^>]*)ALT *= *'([^>']*)'([^>]*)>/<%IMG$1$3>\n$2\n<\/%IMG>/i;
         $block =~
           s/<%IMG([^>]*)>\s*<\/%IMG>/<IMG$1>/i;
      }

      #
      #  Move Input names out of tags and delimit with %INPUT
      #

#      $trace && print "(inputs)";
#      while ( $block =~ /< *INPUT[^>]*VALUE *= */i ) {
#         $block =~ 
#           s/< *INPUT([^>]*)VALUE *= *"([^>"]*)"([^>]*)>/<%INPUT$1$3>\n$2\n<\/%INPUT>/i;
#         $block =~ 
#           s/< *INPUT([^>]*)VALUE *= *'([^>']*)'([^>]*)>/<%INPUT$1$3>\n$2\n<\/%INPUT>/i;
#         $block =~ 
#           s/< *INPUT([^>]*)VALUE *= *([^ >]*)([^>]*)>/<%INPUT$1$3>\n$2\n<\/%INPUT>/i;
#         $block =~
#           s/<%INPUT([^>]*)>\s*<\/%INPUT>/<INPUT$1>/i;
#      }

      #   
      #  Now break the block into lines and process each one
      #  as either a tag or text.
      #

      $trace && print "(split)";
      foreach $line (split(/\n/,$block)) {

         $line =~ s/^\s*$//;  # Kill the line if it's only whitespace

         if ( $line ne "" ){
 
            #   
            #  Convert tags according to the tag action array
            #   
            if ( $line =~ /^</ ) {
      
               #
               #  Grab everything up to the first space or = and
               #  convert it to upper case.
               #
               ($tag) = split(/[\s=]/,$line);
               $tag   =~ s/[<>]//g;
               $tag   =~ tr/a-z/A-Z/;
       
               #
               #  Look up the tag in the matrix and add the
               #  appropriate markup to the text to write.
               #
               $lastact = $act; 
               $act = $tagact{$tag};
               if ( $act eq "%" ) {
                  $act = $line;
                  $act =~ s/\n//g;
               }

               ##
               ##  Keep tables, but strip out WIDTH attribs or 
               ##  page formatting gets a bit messy
               ##
               # if ( $act =~ /<(TABLE|TR|TD|TH)/ ) {
               #    $act =~ s/WIDTH *= *"*[0-9\%]*"*//i;
               #    print "]$act[\n";
               # }

               #
               #  Now add the the action
               #
               $text .= $act;

            } 

            #   
            #  If line is text, add (with single leading/trailing space)
            #  to text to write.
            #   
            else {
               $line =~ s/^\s*/ /;
               $line =~ s/\s*$/ /;
               $text .= $line;
            }
         }
      }
   }

   #
   #  Process the text to remove extraneous markup info before 
   #  writing to the file. $text contains the entire file, split
   #  with \n
   #
   $text = &strip($text);
   print $OUTFILE "$text\n\n";

   return(1);

}

#======================================================================
# 
#  strip - Takes as a single argument a string of HTML (which may 
#          contain \ns) and strips out unnecessary whitespace, 
#          empty tags, etc. Returns the cleaned up string.
#
#----------------------------------------------------------------------
#  Arguments:  string containing HTML
#----------------------------------------------------------------------
#  Returns:    string containing clean text
#----------------------------------------------------------------------

sub strip {

   ###  sub strip ( $text );

   local($text) = @_;

   #
   #  Completely kill JavaScript et al.
   #
   $text =~ s/<SCRIPT>.*<\/SCRIPT>//g;

   #
   #  Kill whitespace inside anchors.
   #
   $text =~ s/<A([^>]*)>\s*([^<]*)/<A$1>$2/gi;
   $text =~ s,\s*</A>,</A>,gi;
   #
   #  But make sure we leave some between anchors
   #
   $text =~ s,</A><A,</A> <A,gi;

   #
   #  Remove extra whitespace
   #
   $text =~ s/\t/ /g;
   $text =~ s/^ *//g;
   $text =~ s/ *$//g;
   $text =~ s/  */ /g;
   $text =~ s/\n */\n/g;
   $text =~ s/ *\n/\n/g;

   #
   #  Remove blank lines
   #
   $text =~ s/\n\s*\n/\n/g;

   #
   #  Remove double BRs and Ps
   #
   while ( $text =~ /<(BR|P)>\s*<(BR|P)>/) {
      $text =~ s/<BR>\s*<BR>/<BR>/g;
      $text =~ s/<BR>\s*<P>/\n<P>/g;
      $text =~ s/<P>\s*<BR>/<P>/g;
      $text =~ s/<P>\s*<P>/<P>/g;
   }

   #
   #  Drop trailing P or BR
   # 
   $text =~ s/<(BR|P)>$//;

   ##  Strip lines with no text.
   #
   #   while( $text =~ /<(BR|P)>\n*<[^>]*>\n*<(BR|P)>/ ){
   #     $text =~   s/<(BR|P)>(\n*<[^>]*>\n*)<(BR|P)>/<$1><$3>/g;
   #   }
   #
   ##  Don't need a BR before or after some tags
   #
   #   $text =~ s/<(\/UL)>(\s*)<BR>\s*/<$1>$2/g;
   #   $text =~ s/<BR>(\s*)<(UL)>/$1<$2>/g;
   #
   #   while( $text =~ /^<(BR|P)>/ ){
   #      $text =~ s/^<(BR|P)>//g;
   #   }
   #
   #   while( $text =~ /<(BR|P)>$/ ){
   #      $text =~ s/<(BR|P)>$//g;
   #   }
   #
   ##

   return($text);

}

#======================================================================
1; # return true
