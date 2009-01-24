#!/usr/local/bin/perl4.036
#======================================================================
#
#  agent - Performs all user functions. Called by the CGI scripts
#          for page handling with $mode set to name of caller and
#          %input loaded with the data sent via HTTP.
#
#          Could this be outside the document tree, hence safe(r)?
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

require "cgi-lib.pl";
require "date.pl";
require "db.pl";
require "scanpage.pl";
require "throw.pl";
require "util.pl";

sub agent {

   ###  sub agent ( $mode, %input )

   local($mode,%input) = @_;

   local(%list,%listbyurl,%listbytitle);
   local($form);
   local($pageid,$visit,$url,$title,$desc);
   local($protocol,$site,$file,$statuscode);
   local($filename);
   local(%tags);
   local(%links,%linksbytext,%status,%title);

   $| = 1;

   #
   #  date will always be the date agent was invoked in local TZ
   #
   local($date) = $G'date;

   #
   #  Log call
   #
   open(LOG,">> ${G'datadir}access.log");
   print LOG "$date $G'user $mode $input{'form'} $input{'url'}\n";
   close(LOG);

   if ( $input{'url'} !~ m,\w+:, ) { $input{'url'} = "http:\/\/$input{'url'}";}

   #
   #  Always read personal page list and create list
   #  for looking up pageid by title and URL
   #
   if ( -e $G'checklist ) {
      open(LIST,$G'checklist) || &throw("Can't open $G'checklist");
      &dbread(LIST,*list);
      close(LIST);
      %listbyurl   = &dbinvert(*list,2);
      %listbytitle = &dbinvert(*list,3);
   }
 
   ##
   #
   #  Add, Edit, and Delete modes all act on single pages and
   #  display a series of forms, so group these modes together
   # 
   if ( $mode =~ /(add|edit|delete)/ ) {

      $form = $input{'form'};
   
      #
      #  If no form filled out yet, show the appropriate selection form
      #
      if ( ! $form ) {
   
         if ( $mode =~ /(edit|delete)/ ) {
            &selectform($mode,%listbytitle);
         } 
         elsif ( $mode =~ /add/ ){
            &urlform($mode);
         }
         else { &throw("Can't $form in $mode") };

      } 
  
      #
      #  Selection form completed, so either edit or delete the page
      # 
      elsif ( $form eq "select" ) {

         $title  = $input{'title'};
         $pageid = $listbytitle{$title};

         ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
         if ( $visit eq "") { $visit = &datecheck("0"); }
         $visit = &datetotz($visit,$G'tz);
   
         if ( $mode eq "edit" ) {
            &editform($mode,$pageid,$visit,$url,$title,$desc);
         }
         elsif ( $mode eq "delete" ) {

            delete($list{$pageid});
            open(LIST,"> $G'checklist") || &throw("Can't open $G'checklist");
            &dbwrite(LIST,*list);
            close(LIST);
            &deleted($mode,$pageid,$url,$title,$desc);
         }
         else { &throw("Can't $form in $mode") };
   
      }

      #
      #  URL form filled out, so look for page and put up edit form
      #
      elsif ( $form eq "url" ) {

         $url = $input{'url'};

         #
         #  Save URLs in the DB with trailing / stripped. If it's
         #  needed, the appropriate routine will add it on the fly.
         #
         #  This is easier than always checking the DB for the URL
         #  with and without the /. If this isn't per HTTP RFC, (i.e.
         #  if with and without / can be distinct sites, change 
         #  later.
         #
         $url =~ s,/$,,;
   
         ##
         ##  If the user asks to add a URL that already eists, change
         ##  to edit mode on the fly.
         ##
         if ( $pageid = $listbyurl{$url} ){
            ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
            $visit = &datetotz($visit,$G'tz);
            $mode = "edit";
         } else {
            ##
            ##  Page not in list, so get info from server
            ##

            ($protocol,$site,$file) = &uspliturl($url);
            $pageid = &getpageid($url);
 	    if ( ! $pageid ) {
 	       &adderror($url); 
 	       return(0);
 	    } else {
               $title  = &getpagetitle($pageid);
            }
         }

         #
         #  If usedef radio button is checked then add default
         #  info to the checklist and show the "added" page
         #
         if ($input{'usedef'} && ($mode eq "add") ) {
            $visit  = &datecheck(0);
            $list{$pageid} = join("\000",$visit,$url,$title,$desc);
            open(LIST,"> $G'checklist") || &throw("Can't open $G'checklist");
            &dbwrite(LIST,*list);
            close(LIST);
            &updated($mode,$pageid,$url,$title,$desc);
         } else {
            &editform($mode,$pageid,$visit,$url,$title,$desc);
         }
      }
  
      # 
      #  Edit form filled out, so update page info in DB
      # 
      elsif ( $form eq "edit" ) {
         if ( $mode eq "add" ) {
            $visit  = &datecheck(0);
         } else {
            $visit  = $input{'visit'};
            $visit  = &datetotz($visit,"GMT");
         }
         $pageid = $input{'pageid'};
         $url    = $input{'url'};
         $title  = $input{'title'};
         $desc   = $input{'desc'};
         $desc   =~ s/\s+/ /g;
         $list{$pageid} = join("\000",$visit,$url,$title,$desc);
         open(LIST,"> $G'checklist") || &throw("Can't open $G'checklist");
         &dbwrite(LIST,*list);
         close(LIST);
         &updated($mode,$pageid,$url,$title,$desc);
      }

      # 
      #  User has selected list of Links
      # 
      elsif ( $form eq "list" ) {

         print "Content-type: text/html\n\n";
         &pageheader(STDOUT,"Added Links",3,1);
         print "\n";
         print "<P>\n";
         print "<CENTER><FONT SIZE=+1>\n";

         &pagemenu(STDOUT,4,1,
                   "Add Link    : ${G'ruserdocpath}add.htm",
                   "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
                   "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
                   "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

         print "</FONT></CENTER>\n";
         print "<P>\n";

         print "<CENTER>\n";
         print "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=80%>\n";
         print "<TR><TD>\n";

         #
         #  Build list of links
         #
         foreach $inputname (sort(keys(%input))) {
            if ( $inputname =~ /^LINK/ ) {
               ($num,$url) = ($inputname =~ /LINK(\w+) (.*)/);
               $url =~ s,/$,,;
               $links{$url} = $input{"TEXT$num"};
               $status{$url} = "add";
            }
         }

         #
         #  Now attempt to add each link
         #

         foreach $url (keys(%links)) {
            $linksbytext{$links{$url}} = $url;
         }

         foreach $text (sort(keys(%linksbytext))) {

            $url = $linksbytext{$text};

            #
            #  If the link isn't already on the list, try to add it
            #
            if ( $pageid = $listbyurl{$url} ){
               $status{$url} = "exists";
            } else {
               ($protocol,$site,$file) = &uspliturl($url);
               if ( $pageid = &getpageid($url) ) {
                  $visit = &datecheck(0);
                  $title = $text;
                  $desc = "";
                  $list{$pageid} = join("\000",$visit,$url,$title,$desc);
                  $status{$url} = "ok";
               } else {
                  $status{$url} = "error";
               }
            }

            #
            #  Print results of add attempt
            #
            print "<P><IMG SRC=\"$G'rbulletimage\">";

            if ( $status{$url} eq "ok" ) {
               print "<A HREF=\"$url\">$text</A> ";
               print "was added to your CheckList.\n";
            }
            elsif ( $status{$url} eq "exists" ) {
               print "<A HREF=\"$url\">$text</A> ";
               print "was already on your CheckList.\n"
            }
            else {
               print "<A HREF=\"$url\">$text</A> ";
               print "could not be added to your CheckList.\n";
            }

         }
         open(LIST,"> $G'checklist") || &throw("Can't open $G'checklist");
         &dbwrite(LIST,*list);
         close(LIST);

         print "</TD></TR></TABLE>\n";
         print "</CENTER>\n";
         print "<P>\n";

#         &doupdatebutton(STDOUT,$mode);  # Add button to update lists

         &pagefooter(STDOUT);

      }
      else { &throw("Can't $form in $mode") };
   
   } 

   #
   #  Generate pages list
   # 
   elsif ( $mode =~ /list/ ) {
   
      #
      #  Write Page List HTML file
      #
      print "Content-type: text/html\n\n";
      &pageheader(STDOUT,"Page List",2,0);
   
      print "<CENTER>\n";
      print "<P><EM>List updated $date</EM>\n";
      print "</CENTER>\n";
      print "<P>\n";
      print "<DL>\n";
   
      #
      #  Generate full list
      #
      foreach $ptitle (sort(keys(%listbytitle))){
   
         #
         #  Get pageid and other fields
         #
         $pageid = $listbytitle{$ptitle};
         ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
         $visit  = &datetotz($visit,$G'tz);
         $svisit = &dateshort($visit);
   
         #
         #  Put page on list
         #
         print "<P><DT><IMG SRC=\"${G'rbulletimage}\">";
         print "<STRONG><A HREF=\"$url\">${title}</A></STRONG>\n";
         print "<DD>$desc<BR>\n" if ( $desc ) ;
   
      }
      print "</DL>\n";
      print "<P>\n";
   
#      &doupdatebutton(STDOUT,$mode);  # Add button to update lists
   
      &pagefooter(STDOUT);
   
   } 

   #
   #  Generate changed pages
   # 
   elsif ( $mode =~ /changed/ ) {
   
      #
      #  Generate full list, building an array of the pageids of updated
      #  pages in the process
      #
      foreach $ptitle (sort(keys(%listbytitle))){
   
         #
         #  Get pageid and other fields
         #
         $pageid = $listbytitle{$ptitle};
         ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
         $visit  = &datetotz($visit,$G'tz);
         $svisit = &dateshort($visit);
   
         #
         #  Read date of last page update from history file
         #
         $histfile = $G'pagedatadir . "$pageid.hst";
         open(HST,$histfile) || &throw("Can't open $histfile");
         $update{$pageid}  = <HST>;
         $update{$pageid}  =~ s/^=== *//;
         $update{$pageid}  =~ s/\n$//;
         $update{$pageid}  = &datetotz($update{$pageid},$G'tz);
         $supdate{$pageid} = &dateshort($update{$pageid});
         close(HST);
   
         #
         #  Add to list of changed pages if updated since last visit
         #
         if ( &datecomp($visit,$update{$pageid}) == -1 ) {
            push(@changedpages,$pageid);
         }

      }
   
      #
      #  Write Changed Pages HTML file
      #
      print "Content-type: text/html\n\n";
      &pageheader(STDOUT,"Changed Pages",1,0);
   
      if ( $#changedpages != -1 ) {
   
         print "<CENTER>\n";
         print "<P><EM>List updated $date</EM>\n";
         print "</CENTER>\n";
         print "<P>\n";
         print "Here's the list of pages that have changed since you ";
         print "last visited them. Once you've visited a page, click ";
         print "on the check box next to the page description. Clicking ";
         print "on the button at the end of the list will update the ";
         print "<EM>Visited</EM> date for the checked pages and remove ";
         print "them from the list until they are updated again. You ";
         print "can click on the <EM>Changed</EM> date to see a summary ";
         print "of the changes to the page, if one is available.\n";
         print "<P>\n";
   
         foreach $pageid (@changedpages) {
            ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
            $visit = &datetotz($visit,$G'tz);
            $tsup = $supdate{$pageid};
            print "<IMG SRC=\"$G'rbulletimage\">";
            print "<A HREF=\"#$pageid\">";
	    print "Changed $tsup</A>";
            print " - <STRONG><A HREF=\"$url\">$title</A></STRONG><BR>\n";
         }
   
         print "<P><HR><P>\n";
         print "<DL>\n";
   
         foreach $pageid (@changedpages) {
            ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
            $visit   = &datetotz($visit,$G'tz);
            $supdate = &dateshort($update{$pageid});
            $svisit  = &dateshort($visit);
            &dopage(STDOUT,$pageid,$title,$desc,$url,$visit,$update);
         }
   
         print "</DL>\n";
         print "<P>\n";
   
         &dovisitbutton(STDOUT);  # Button to mark all pages as visited
#         &doupdatebutton(STDOUT,$mode); # Button to update page lists
   
      } else {
   
         print "<P>\n";
         print "<CENTER>\n";
         print "<FONT SIZE=+1>\n";
         print "As of $date,<BR>";
         print "no pages have changed since your last visit.\n";
         print "</FONT>\n";
         print "<P>\n";
   
#         &doupdatebutton(STDOUT,$mode); # Button to update page lists
   
      }
      &pagefooter(STDOUT);
   
   }

   #
   #  Mark all pages as visited
   # 
   elsif ( $mode =~ /visitall/ ) {

      if ( $input{'date'} ){
         $visitdate = $input{'date'};
      } else {
         $visitdate = $date;
      }
     
      foreach $pageid (keys(%list)) {
         ($visit,$url,$title,$desc) = split("\000",$list{$pageid});
         $visit = &datetotz($visitdate,"GMT");
         $list{$pageid} = join("\000",$visit,$url,$title,$desc);
      }
      open(LIST,"> $G'checklist") || &throw("Can't open $G'checklist");
      &dbwrite(LIST,*list);
      close(LIST);
      &visited;

   }

   # 
   #   Upload a file containing URLs
   # 
   elsif ( $mode =~ /upload/ ) {

      $filename = $input{'file'};

      open(FILE,"${G'uploaddir}$filename");
      &grabrefs(FILE,*tags);

      &addlistform($mode,*tags);
      
   }

   else { &throw("Invalid mode $mode"); }

   return(1);
}

#======================================================================

sub selectform {

   ###  sub selectform ( $mode, %pages )

   local($mode,%pages) = @_;
   local($capmode,$choice,$action);
   local($ptitle);

   if ( $mode eq "delete" ) {
      $capmode = "Delete"; 
      $action  = $G'rcgipath . "delete.pl"; 
      $choice  = 2;
   } elsif ( $mode eq "edit" ) {
      $capmode = "Edit";
      $action  = $G'rcgipath . "edit.pl";
      $choice  = 3;
   } else { 
      &throw("Bad mode $mode");
   }

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"${capmode} a Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,$choice,0,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";
   print "<P>\n";
   print "<CENTER>\n";
   print "Select the title of the page you would like to ${mode} and ";
   print "use the <EM>${capmode} Selected Link</EM> button to submit ";
   print "the form.\n";
   print "</CENTER>\n";
   print "<P>\n";
   print "\n";

   print "<FORM ACTION=\"${action}\" METHOD=\"POST\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"form\" VALUE=\"select\">\n";
   print "\n";
   print "<CENTER>\n";
   print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0>\n";
   print "\n";

   print "<TR>\n";
   print "<TD VALIGN=TOP><STRONG>$capmode the link to</STRONG></TD>\n";
   print "<TD>\n";
   print "<SELECT NAME=\"title\" SIZE=\"10\">\n";
         foreach $ptitle (sort(keys(%pages))){
            print "<OPTION>$ptitle\n";
         }
   print "</SELECT>\n";
   print "</TD></TR>\n";

   print "<TR>\n";
   print "<TD COLSPAN=2 ALIGN=CENTER>\n";
   print "<INPUT TYPE=\"submit\" VALUE=\"${capmode} Selected Link\">\n";
   print "</TD>\n";
   print "</TR>\n";

   print "</TABLE>\n";
   print "</CENTER>\n";
   print "</FORM>\n";
   print "\n";

   &pagefooter(STDOUT);

   return(1);

}

#======================================================================

sub urlform {

   ###  sub urlform ( $mode )

   local($mode) = @_;
   local($capmode,$choice,$action);

   $capmode = "Add";
   $action  = $G'rcgipath . "add.pl";

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"Add a Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,1,0,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";
   print "<P>\n";
   print "To add a page to your CheckList, enter the URL of the page ";
   print "in the box below and use the <EM>Add Link</EM> button to ";
   print "submit the form. If the <EM>Use default page title</EM> ";
   print "button is checked the page will be added using the title ";
   print "CheckList finds when it first checks the page. If you'd like ";
   print "to enter a different title or add a description for the page, ";
   print "you can check the <EM>Edit page title and description</EM> ";
   print "button or you can edit the link later.\n";
   print "\n";
   print "<P>\n";
   print "\n";

   print "<FORM ACTION=\"$action\" METHOD=\"POST\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"form\" VALUE=\"url\">\n";
   print "\n";
   print "<CENTER>\n";
   print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0>\n";

   print "<TR>\n";
   print "<TD ALIGN=LEFT><STRONG>Location (URL)</STRONG></TD>\n";
   print "<TD><INPUT TYPE=\"text\" NAME=\"url\" SIZE=45></TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD ALIGN=LEFT><STRONG>Title and Desc.</STRONG></TD>\n";
   print "<TD>\n";
   print "<INPUT TYPE=\"radio\" NAME=\"usedef\" VALUE=\"X\" CHECKED>";
   print "Use default page title\n";
   print "<INPUT TYPE=\"radio\" NAME=\"usedef\" VALUE=\"\">";
   print "Edit page title and description\n";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR><TD COLSPAN=2 ALIGN=CENTER>\n";
   print "<INPUT TYPE=\"submit\" VALUE=\"Add Link\">\n";
   print "<INPUT TYPE=\"reset\" VALUE=\"Clear Values\">\n";
   print "</TD>\n";
   print "</TR>\n";

   print "</TABLE>\n";
   print "</CENTER>\n";
   print "</FORM>\n";

   print "<P>\n";

   &pagefooter(STDOUT);

   return(1);
}

#======================================================================

sub addlistform {

   local($mode,*tags) = @_;
   local($capmode,$choice,$action);
   local($url,$urltext);
   local($i,$num);

   $action  = $G'rcgipath . "add.pl";

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"Add a Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,4,1,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";

   print "<P>\n";
   print "<CENTER>\n";
   print "Place a check mark in the box next to each page\n";
   print "you would like to add to your checklist.\n";
   print "</CENTER>\n";
   print "<P>\n";
 
   print "<FORM ACTION=\"$action\" METHOD=\"POST\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"form\" VALUE=\"list\">\n";

   print "<CENTER>\n";
   print "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=0 WIDTH=80%>\n";
   print "<TR><TD>\n";

#   %tagsbytext = &dbinvert(%tags,1);

   foreach $url (keys(%tags)) {
      $tagsbytext{$tags{$url}} = $url;
   }

   $i = 0;
   foreach $urltext (sort(keys(%tagsbytext))) {
      $i++;
      $num = sprintf("%03d",$i);
      $url = $tagsbytext{$urltext};
      print "<INPUT TYPE=\"checkbox\" NAME=\"LINK$num $url\">";
      print "<INPUT TYPE=\"hidden\" NAME=\"TEXT$num\" VALUE=\"$urltext\">";
      print "<A HREF=\"$url\">$urltext</A><P>\n";
   }
   print "</TD></TR>\n";
   print "<TR><TD ALIGN=CENTER>\n";
   print "<INPUT TYPE=\"submit\" VALUE=\"Add Links\">\n";
   print "<INPUT TYPE=\"reset\" VALUE=\"Clear all marks\">\n";
   print "</TD></TR>\n";
   print "</TABLE>\n";
   print "</CENTER>\n";
   print "<P>\n";

   print "</FORM>\n";
   print "<P>\n";

   &pagefooter(STDOUT);

   return(1);

}
#======================================================================

sub editform {

   ###  sub editform ( $mode, $pageid, $visit, $url, $title, $desc )

   local($mode,$pageid,$visit,$url,$title,$desc) = @_;
   local($capmode,$choice,$action);
   local(@words,$word,$line);

   if    ( $mode eq "add"   ) { 
      $capmode = "Add";
      $choice  = 1;
      $action  = $G'rcgipath . "add.pl";
   } elsif ( $mode eq "delete" ) { 
      $capmode = "Delete";
      $choice  = 2;
      $action  = $G'rcgipath . "delete.pl";
   } elsif ( $mode eq "edit"   ) { 
      $capmode = "Edit";
      $choice  = 3;
      $action  = $G'rcgipath . "edit.pl";
   } else  {
      &throw("Bad mode $mode");
   }

   #
   # Format the description field for display in a TEXTAREA
   #
   @words = split(" ",$desc);
   $desc = "";
   foreach $word (@words){
      $line .= $word . " ";
      if ( length($line) >= 40 ) {
         $desc .= $line . "\n";
         $line = "";
      }
   } 
   $desc .= $line;

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"${capmode} a Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,$choice,0,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";
   print "<P>\n";
   print "After making changes to the title and description of the link, ";
   print "use the <EM>Update Link</EM> button to save changes. You will ";
   print "then need to generate a new list to see the changes you make ";
   print "take effect.\n";
   print "<P>\n";
   print "\n";

   print "<FORM ACTION=\"${action}\" METHOD=\"POST\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"pageid\" VALUE=\"${pageid}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"visit\"  VALUE=\"${visit}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"url\"    VALUE=\"${url}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"form\"   VALUE=\"edit\">\n";
   print "\n";
   print "<CENTER>\n";
   print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0>\n";

   print "<TR>\n";
   print "<TD ALIGN=RIGHT><STRONG>Location</STRONG></TD>\n";
   print "<TD>$url\n";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD ALIGN=RIGHT VALIGN=TOP><STRONG>Title</STRONG></TD>\n";
   print "<TD><INPUT TYPE=\"text\" NAME=\"title\" SIZE=50 VALUE=\"$title\">";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD ALIGN=\"right\" VALIGN=\"top\"><STRONG>Description</STRONG>";
   print "</TD>\n";
   print "<TD><TEXTAREA NAME=\"desc\" COLS=50 ROWS=5>$desc</TEXTAREA></TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD COLSPAN=2 ALIGN=CENTER>\n";
   print "<INPUT TYPE=\"submit\" VALUE=\"Update Link\">\n";
   print "<INPUT TYPE=\"reset\" VALUE=\"Reset Values\">\n";
   print "</TD>\n";
   print "</TR>\n";

   print "</TABLE>\n";
   print "</CENTER>\n";
   print "</FORM>\n";
   print "\n";
   print "<P>\n";

   &pagefooter(STDOUT);

}

#======================================================================

sub deleted {

   ###  sub deleted ( $mode, $pageid, $url, $title, $desc )

   local($mode,$pageid,$url,$title,$desc) = @_;

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"Deleted a Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,0,0,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";

   print "<P>\n";
   print "Deleted link.\n";
   print "<P>\n";

   print "<CENTER>\n";
   print "<TABLE BORDER=1 CELLPADDING=10 CELLSPACING=0 WIDTH=90%>\n";
   print "<TR><TD>\n";

   print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0>\n";

   print "<TR>\n";
   print "<TD ALIGN=RIGHT><STRONG>Location</STRONG></TD>\n";
   print "<TD>$url\n";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD ALIGN=RIGHT VALIGN=TOP><STRONG>Title</STRONG></TD>\n";
   print "<TD>$title\n";
   print "</TD>\n";
   print "</TR>\n";

   if ($desc) {
      print "<TR>\n";
      print "<TD ALIGN=\"right\" VALIGN=\"top\">";
      print "<STRONG>Description</STRONG></TD>\n";
      print "<TD>${desc}</TD>\n";
      print "</TR>\n";
   }

   print "</TABLE>\n";
   print "</TD></TR></TABLE>\n";
   print "</CENTER>\n";

#   &doupdatebutton(STDOUT,$mode);

   print "\n";
   print "<P>\n";

   &pagefooter(STDOUT);

}

#======================================================================

sub updated {

   ###  sub updated ( $mode, $pageid, $url, $title, $desc )

   local($mode,$pageid,$url,$title,$desc) = @_;
   local($choice) = 0;
   local($capmode);

   if    ( $mode eq "add"  ) { 
      $capmode = "Added";   }
   elsif ( $mode eq "edit" ) { 
      $capmode = "Updated"; }
   else  {
      &throw("Bad mode $mode");
   }

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"${capmode} a Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,0,0,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";

   print "<P>\n";
   print "<CENTER>The title and description of the link have been ";
   print "updated</CENTER>\n";
   print "<P>\n";

   print "<CENTER>\n";
   print "<TABLE BORDER=1 CELLPADDING=10 CELLSPACING=0 WIDTH=90%>\n";
   print "<TR><TD>\n";

   print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0>\n";

   print "<TR>\n";
   print "<TD ALIGN=RIGHT><STRONG>Location</STRONG></TD>\n";
   print "<TD>\n";
   print "${url}\n";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD ALIGN=RIGHT VALIGN=TOP><STRONG>Title</STRONG></TD>\n";
   print "<TD>\n";
   print "${title}\n";
   print "</TD>\n";
   print "</TR>\n";

   if ($desc) {
      print "<TR>\n";
      print "<TD ALIGN=\"right\" VALIGN=\"top\"><STRONG>Description</STRONG>";
      print "</TD>\n";
      print "<TD>\n";
      print "$desc\n";
      print "</TD>\n";
      print "</TR>\n";
   }

   print "</TABLE>\n";
   print "</TD></TR></TABLE>\n";
   print "</CENTER>\n";

#   &doupdatebutton(STDOUT,$mode);

   print "\n";
   print "<P>\n";

   &pagefooter(STDOUT);

   return(1);

}

#======================================================================

sub doupdatebutton {

   ###  sub doupdatebutton ( $FILE , $mode )

   local($F,$mode) = @_;

   print $F "<CENTER>\n";
   if ( $mode =~ /list/ ){
      print $F "<FORM ACTION=\"${G'rcgipath}list.pl\" METHOD=\"POST\">\n";
   } else {
      print $F "<FORM ACTION=\"${G'rcgipath}changed.pl\" METHOD=\"POST\">\n";
   }
   print $F "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print $F "<INPUT TYPE=\"submit\" VALUE=\"Update List\">\n";
   print $F "</FORM>\n";
   print $F "<P>\n";
   print $F "</CENTER>\n";

}

#======================================================================

sub dovisitbutton {

   ###  sub dovisitbutton ( $FILE )

   local($F) = @_;

   print $F "<CENTER>\n";
   print $F "<FORM ACTION=\"${G'rcgipath}visitall.pl\" METHOD=\"POST\">\n";
   print $F "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print $F "<INPUT TYPE=\"hidden\" NAME=\"date\" VALUE=\"${G'date}\">\n";
   print $F "<INPUT TYPE=\"submit\" VALUE=\"Mark all sites as Visited\">\n";
   print $F "</FORM>\n";
   print $F "</CENTER>\n";

}

#======================================================================

sub visited {

   ###  sub visited

   local($choice) = 0;

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"Marked as Visited",0,0);

   print "<P>\n";
   print "<CENTER>\n";
   print "<FONT SIZE=+1>\n";
   print "All pages on your list have been marked as visited<BR>";
   print "on $date.";
   print "</FONT></CENTER><P>\n";

#   &doupdatebutton(STDOUT,$mode);

   print "\n";
   print "<P>\n";

   &pagefooter(STDOUT);

}

#======================================================================

sub getpagetitle {

   ##  sub getpagetitle ( $pageid )

   local($pageid) = @_;
   local($htmlfile) = $G'pagedatadir . "$pageid.htm";
   local($inline,$block,$title);

   open(HTML,$htmlfile) ||
      &throw("Can't open $htmlfile");

   while ($inline = <HTML>) {
     $block .= $inline;
     if (($title) = ($block =~ /<\s*TITLE\s*>([^<]*)<\s*\/\s*TITLE\s*>/i)){
        $title =~ s/^\s*//g;
        $title =~ s/\s*$//g;
        close(HTML);
        return($title);
     }
   }
   close(HTML);
   return("");

} 

#======================================================================
#  getpageid
#----------------------------------------------------------------------
#
#  Once centralized DB handling is available, getpageid will simply
#  send a URL to the DB handler and get a pageid back. In the mean
#  time, manage the DB locally...
#
#  opens the page DB, checks for the URL, if exists, returns the
#  pageid. If doesn't exist, generate a new pageid, get the page,
#  and returnthe pageid
#
#----------------------------------------------------------------------

sub getpageid {

   ##  sub getpageid ( $url )

   local($url) = @_;
   local($protocol,$site,$page) = &uspliturl($url);
   local(%pagedb,%dbbyurl);
   local(@pageids,$highid,$newid);
   local($pageid);
   local($statuscode);

   #
   #  Open page database to get location of file
   #
   open(PAGEDB,$G'dbfile) || &throw("Can't open page database",$G'dbfile);
   &dbread(PAGEDB,*pagedb);
   close(PAGEDB);

   %dbbyurl   = &dbinvert(*pagedb,1);

   if ( $pageid = $dbbyurl{$url} ) {

      return($pageid);

   } else {

      $statuscode = &httpping($site,$page);

      if (($statuscode<200) || ($statuscode>299)) { return(0) };

      @pageids = sort(keys(%pagedb));
      $highid = pop(@pageids);

      $newid  = &dbinckey($highid);

      $pagedb{$newid} = $url;

      open(PAGEDB,"> $G'dbfile") ||
         &throw("Can't open $G'dbfile");
      &dbwrite(PAGEDB,*pagedb);
      close(PAGEDB);

      &scanpage($newid);

      return($newid);

   }

}

#======================================================================

sub dopage {

   ###  sub dopage ( $FILE, $pageid, $title, $desc, $url, $visit, $update )

   local($F,$pageid,$title,$desc,$url,$visit,$update) = @_;

   print $F "<P><DT>";
   print $F "<FONT SIZE=+1><STRONG>\n";
   print $F "<IMG SRC=\"$G'rcheckimage\">";
   print $F "<A NAME=\"$pageid\"><A HREF=\"$url\">$title</A>\n";
   print $F "</STRONG></FONT>\n";
   if ( $desc ) {
      print $F "<DD><EM>$desc</EM>\n";
   } else {
      print $F "<DD>\n";
   }

   print $F "<P>";

   &dochanges($F,$pageid,$visit);

}

#======================================================================
#  dochanges - print changes to a given page as a DL
#----------------------------------------------------------------------

sub dochanges {

   ###  sub dochanges ( $FILE, $pageid, $sincedate )

   local($FILE,$pageid,$sincedate) = @_;

   local($sincedate) = &datetotz($sincedate,$G'tz);

   local(%info);
   local($visit,$base,$title,$desc);
   local($histfile);
   local($block,$line,$date);
   local($havedate)=0;

   #
   # Read page information from database
   #
   open(DUMPINFO,$G'checklist) || &throw("Can't open $G'checklist");
   &dbread(DUMPINFO,*info);
   ($visit,$base,$title,$desc) = split("\000",$info{$pageid});
   $visit = &datetotz($visit,$G'tz);

   #
   # Open page history file
   #
   $histfile = $G'pagedatadir . "$pageid.hst";
   open(HISTORY,$histfile) || &throw("Can't open $histfile");

   while(<HISTORY>){
      $line = $_;
      if ( $line =~ /^===/ ) {

	 if ( $havedate ) {
            if ( &datecomp($sincedate,$date) == -1 ) {     
               &dodate($FILE,&formatdate($date));
               &markup($FILE,$block);
            }
            $block = "";
         }
         ($date) = ($line =~ /^=== +(.+)$/); 
         $date = &datetotz($date,$G'tz);
	 $havedate = 1;

      } else {

         $block .= $line;

      }
   }
   if ( &datecomp($sincedate,$date) == -1 ) {
      &dodate($FILE,&formatdate($date));
      &markup($FILE,$block);
   }

}

#======================================================================

sub formatdate{
   
   ###  sub formatdate ( $input )

   local($input) = @_;

   local(%dofw) = (
      "Sun", "Sunday",
      "Mon", "Monday",
      "Tue", "Tuesday",
      "Wed", "Wednesday",
      "Thu", "Thursday",
      "Fri", "Friday",
      "Sat", "Saturday" );

   local($day,$mday,$month,$year,$hour,$min,$sec,$zone) =
      ($input =~ /^(\w+), +(\d+) +(\w+) +(\d+) +(\d+):(\d+):(\d+) +(\w+)$/);

   sprintf("<IMG SRC=\"$G'rbulletimage\"> On %s, %d %s %d at %d:%02d:%02d %s\n",
      $dofw{$day},$mday,$month,$year,$hour,$min,$sec,$zone);

}

#======================================================================
# 
# markup - Processes a string containing diff results and creates
#          the HTML file of changes. Arguments are the string
#          containing diff results and the handle to the output file.
#
#          Arguments:  string containing diff results
#                      file handle of ouput file
#
#----------------------------------------------------------------------

sub markup {

   ###  sub markup ( $OUTFILE, $data )

   local($OUTFILE,$data) = @_;
   local($line);
   local($mode,$oldblock,$newblock);

   local($firstblock) = 1;

   print $OUTFILE "<DL>\n";

   foreach $line ( split(/\n/,$data) ) {
    
      # 
      #  Process ed command lines
      # 
      if ( $line =~ /^[^<>-]/ ) {

         #
         # Finding an ed command line signals the end
         # of the previous block, unless it's the first line
         #
         $mode = "a" if $line =~ /a/; 
         $mode = "c" if $line =~ /c/; 
         $mode = "d" if $line =~ /d/; 

         if ( $firstblock == 0 ) {
            &doblock($OUTFILE,$mode,$oldblock,$newblock);
            $oldblock = "";
            $newblock = "";
         } else {
            $firstblock = 0;
         }

      }

      # 
      #  Process file1 lines
      # 
      if ( $line =~  /^</ ) {
         $line =~ s/^< //;
         $oldblock .= $line if ( $line ne "" );
      }

      # 
      #  Process file2 lines
      # 
      if ( $line =~ /^>/ ) {
         $line =~ s/^> //;
         $newblock .= $line if ( $line ne "" );
      }
   }

   #
   # Write last block and footer
   #
   &doblock($OUTFILE,$mode,$oldblock,$newblock);

   print $OUTFILE "</DL>\n";

   return(1);

}

#======================================================================

sub dodate {

   ###  sub dodate ( $FILE, $dateline )

   local($FILE,$dateline) = @_;

   print $FILE "<P><STRONG>$dateline</STRONG>\n";

}

#======================================================================

sub doblock {

   ###  sub doblock ( $FILE, $mode, $oldblock, $newblock )

   local($FILE,$mode,$oldblock,$newblock) = @_;
   
   #
   #  Don't start blocks with BR or P
   #
   $newblock =~ s/^<(BR|P)>//;
   $oldblock =~ s/^<(BR|P)>//;

   print $FILE "<P>\n";

   if (( $mode eq "c") && ( $oldblock eq "" )) { $mode = "a" };

   if ( $mode eq "a" ){
#      print $FILE "<P><DT><EM>Added</EM>\n";
#      print $FILE "<DD>$newblock\n";
      print $FILE "$newblock\n";
   }

   if ( $mode eq "c" ){
#      print $FILE "<P><DT><EM>Changed</EM>\n";
#      print $FILE "<DD>$oldblock\n";
#      print $FILE "<DT><EM>To</EM>\n";
#      print $FILE "<DD>$newblock\n";
      print $FILE "$newblock\n";
   }

#   if ( $mode eq "d" ){
#      print $FILE "<P><DT><EM>Deleted</EM>\n";
#      print $FILE "<DD>$oldblock\n";
#   }

}

#======================================================================
#
#  pageheader - prints a standard HTML page header
#
#----------------------------------------------------------------------
#  Arguments:  a string containing the name of the image to display
#              a string containing the page title
#              number of menu option to display
#              true if link for option should be active
#----------------------------------------------------------------------
#  Returns:    1
#----------------------------------------------------------------------

sub pageheader {

   ###  sub pageheader ( $FILE, $title, $opt, $link )

   local($F,$title,$opt,$link) = @_;

   local($subopt);

   print $F "<HTML>\n";
   print $F "<!---  Header ";
   print $F "-------------------------------------------------->\n";
   print $F "<HEAD>\n";
   print $F "<TITLE>CheckList - ${title}</TITLE>\n";
#   print $F "<BASE HREF=\"${G'basepath}\">\n";
   print $F "</HEAD>\n";
   print $F "\n";
   print $F "<BODY BGCOLOR=#FFFFFF TEXT=#000000>\n";
   print $F "\n";
   print $F "<!---  Menu  ";
   print $F "---------------------------------------------------->\n";
   print $F "<TABLE BORDER=0 CELLSPACING=0 CELLPADDING=5 WIDTH=100%>\n";
   print $F "\n";
   print $F "<TR><TD ALIGN=CENTER COLSPAN=2>";
   print $F "<IMG SRC=\"${G'rlogoimage}\"></TD></TR>\n";
   print $F "\n";
   print $F "<TR><TD ALIGN=LEFT VALIGN=BOTTOM><FONT SIZE=+1>\n";

   $subopt = ( $opt <= 2 ) ? $opt : 0;

   &pagemenu($F,$subopt,$link,
             "Changed Pages : ${G'rcgipath}changed.pl?user=${G'user}",
             "Page List     : ${G'rcgipath}list.pl?user=${G'user}" );

   print $F "</FONT></TD>\n";
   print $F "\n";
   print $F "<TD ALIGN=RIGHT VALIGN=BOTTOM><FONT SIZE=+1>\n";

   $subopt = ( $opt >= 3 ) ? $opt-2 : 0;

   &pagemenu($F,$subopt,$link,
             "Manage List   : ${G'ruserdocpath}manage.htm",
             "Preferences   : ${G'ruserdocpath}prefs.htm",
             "Home          : ${G'ruserdocpath}index.htm" );

   print $F "</FONT></TD></TR>\n";
   print $F "\n";
   print $F "<TR><TD ALIGN=CENTER COLSPAN=2>";
   print $F "<IMG SRC=\"${G'rlineimage}\"></TD></TR>";
   print $F "</TABLE>\n";
   print $F "<!-----------";
   print $F "---------------------------------------------------->\n";

   return(1);

}

#======================================================================
#
#  pagefooter - prints an HTML footer
#
#----------------------------------------------------------------------
#  Arguments:  file handle
#----------------------------------------------------------------------
#  Returns:    1
#----------------------------------------------------------------------

sub pagefooter {

   ###  sub pagefooter ( $FILE );

   local($F) = @_;

   print $F "<HR><!","-"x70,">\n";
   print $F "<CENTER>\n";
   print $F "<FONT SIZE=-1>\n";
   print $F "<ADDRESS>\n";
   print $F "Copyright &#169; 1996, Ken Sheppardson. All rights reserved.\n";
   print $F "Send questions to ";
   print $F "<A HREF=\"mailto:kens@aimnet.com\">kens@aimnet.com</A>\n";
   print $F "</ADDRESS>\n";
   print $F "</CENTER>\n";
   print $F "</BODY>\n";
   print $F "</HTML>\n";

   return(1);

}

#======================================================================
#
#  pagemenu  - prints HTML for a menu horizontal text menu
#
#----------------------------------------------------------------------
#  Arguments:  number indicating which menu option corresponse to the
#                 current page
#              true if choice should have link active
#              array of choices - seperate name from link by : 
#----------------------------------------------------------------------
#  Returns:    1
#----------------------------------------------------------------------

sub pagemenu {
   ###  sub pagefooter ( $FILE, $choice, $showlink, @items )

   local($F,$choice,$showlink,@items) = @_;
   local($name,$link);

   local($i);

   for ($i = 0; $i <= $#items; $i++) {

      ($name,$link) = split(":",$items[$i],2);
      $name =~ s/^\s*//; $name =~ s/\s*$//;
      $link =~ s/^\s*//; $link =~ s/\s*$//;

      if ( $i == $choice-1 ) {
         print $F "<STRONG>";
         print $F "<A HREF=\"$link\">" if ( $showlink);
         print $F $name;
         print $F "</A>" if ( $showlink );
         print $F "</STRONG>";
      } else {
         print $F "<A HREF=\"$link\">$name</A>";
      }
      if ( $i < $#items ) { print $F " | "; }
      print $F "\n";

   }
   return(1);

}

#======================================================================

sub adderror {

   ###  sub adderror ( $url )

   local($url) = @_;
   local($capmode,$choice,$action);

   $capmode = "Add";
   $action  = $G'rcgipath . "add.pl";

   print "Content-type: text/html\n\n";

   &pageheader(STDOUT,"Error Adding Link",3,1);

   print "\n";
   print "<P>\n";
   print "<CENTER><FONT SIZE=+1>\n";

   &pagemenu(STDOUT,0,0,
             "Add Link    : ${G'ruserdocpath}add.htm",
             "Delete Link : ${G'rcgipath}delete.pl?user=${G'user}",
             "Edit Link   : ${G'rcgipath}edit.pl?user=${G'user}",
             "Upload a Hotlist : ${G'ruserdocpath}upload.htm");

   print "</FONT></CENTER>\n";

   print "<P>\n";
   print "An error occured checking <STRONG>${url}</STRONG>. ";
   print "The link was not added to your CheckList.\n";

   print "Either the site could not be contacted or the page ";
   print "does not exist. If the URL you entered is correct, ";
   print "you should try adding the page later.\n";

   print "<FORM ACTION=\"$action\" METHOD=\"POST\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"user\" VALUE=\"${G'user}\">\n";
   print "<INPUT TYPE=\"hidden\" NAME=\"form\" VALUE=\"url\">\n";
   print "\n";
   print "<CENTER>\n";
   print "<TABLE BORDER=0 CELLPADDING=5 CELLSPACING=0>\n";

   print "<TR>\n";
   print "<TD ALIGN=LEFT><STRONG>Location (URL)</STRONG></TD>\n";
   print "<TD>";
   print "<INPUT TYPE=\"text\" NAME=\"url\" SIZE=45 VALUE=\"${url}\">";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR>\n";
   print "<TD ALIGN=LEFT><STRONG>Title and Desc.</STRONG></TD>\n";
   print "<TD>\n";
   print "<INPUT TYPE=\"radio\" NAME=\"usedef\" VALUE=\"X\" CHECKED>";
   print "Use default page title\n";
   print "<INPUT TYPE=\"radio\" NAME=\"usedef\" VALUE=\"\">";
   print "Edit page title and description\n";
   print "</TD>\n";
   print "</TR>\n";

   print "<TR><TD COLSPAN=2 ALIGN=CENTER>\n";
   print "<INPUT TYPE=\"submit\" VALUE=\"Add Link\">\n";
   print "<INPUT TYPE=\"reset\" VALUE=\"Clear Values\">\n";
   print "</TD>\n";
   print "</TR>\n";

   print "</TABLE>\n";
   print "</CENTER>\n";
   print "</FORM>\n";
   
   print "<P>\n";

   &pagefooter(STDOUT);

   return(1);

}

1; # return true
