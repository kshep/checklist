#!/usr/local/bin/perl4.036

require "throw.pl";
require "date.pl";
require "util.pl";

#======================================================================
#
# httpgetpage - connects to a web server and retrieves a document. Puts
#               the header in one file and the entity in another.
#
#----------------------------------------------------------------------
#  Arguments:  string containing last date checked
#              string containing site name
#              string containing file name
#              file handle to write header to
#              file handle to write HTML to
#----------------------------------------------------------------------

sub httpgetpage {

   ###  sub httpgetpage ( $date, $site, $file, $HEAD, $HTML )

   local($date,$site,$file,$HEAD,$HTML) = @_;
   local($inline,$firstline);
   local($go,$sc);

   $go = 0;

   #
   #  Try "everything possible" to get a good header
   #
   do {

      &httpopen($site,SITE) || return(0);
print "httpopen ok\n";
   
      #
      #  Send Full-Request (GET)
      #
      print SITE "GET $file HTTP/1.1\n";
      print SITE "If-Modified-Since: $date\n" if ( $date ne "" );
      print SITE "\n";

      #
      #  Grab first line of response
      #
      $inline = <SITE>;
      $inline =~ s/\r\n/\n/g;
      $inline =~ s/\r/\n/g;

      #
      #  If first line contains HTTP, process the full header, otherwise
      #  it's a simple header, so save the firstline and go.
      #
      if ( $inline =~ /HTTP/ ) {

         #
         #  First grab the statuscode
         #
         ($sc) = ( $inline =~ /HTTP\/\d+\.\d+ (\d+) / );

         #
         #  Read up to a blank line
         #
         $header = $inline;
         while ( ($inline = <SITE>) !~ /^\s*$/ ) {
            $inline =~ s/\r\n/\n/g;
            $inline =~ s/\r/\n/g;
            $header .= $inline;
         }

         #
         #  Don't even try to process unimplemented codes and
         #  server errors
         #
         #      1xx - (Unimplemented)
         #      500 - Internal Server Error
         #      501 - Not Implemented
         #      502 - Bad Gateway
         #      503 - Service Unavailable
         #
         if ( ($sc<200) ) {
            print $HEAD $header;
            return($sc);
         }
     
         #   
         #   Treat all 200 codes as success
         #   
         #      200 - OK
         #      201 - Created
         #      202 - Accepted
         #      204 - No Content
         #   
         elsif ( ($sc>199) && ($sc<299)) {
            $go = 1;
         }

         #   
         #   If redirect, then try the new URL
         #   
         #      301 - Moved Permanently
         #      302 - Moved Temporarily
         #   
         elsif ( ($sc==301) || ($sc==302)) {
            ($url) = ($header =~ /Location:\s*(.*)\s*/i);
            ($protocol,$site,$file) = &uspliturl($url);
         }

         #   
         #   If not modified, we're done
         #   
         #      304 - Not Modified
         #   
         elsif ( $sc==304 ){
            print $HEAD $header; 
            return($sc);
         } 

         #
         #   On client error, try appending a / if one doesn't exist
         #
         #      400 - Bad Request
         #      401 - Unauthorized
         #      403 - Forbidden
         #      404 - Not Found
         #
         elsif ( ($sc>399) && ($sc<500) ) {
            if ( $file =~ /\/$/ ) {
               print $HEAD $header;
               return($sc);
            } else {
               $file .= '/';
            }
         }

      } else {
         $firstline = $inline;
         $go = 1;
      }

   } until ( $go == 1);

   print $HEAD $header;

   #
   #  Haven't returned, so process the rest of the file as the entity.
   #
   while($inline = <SITE>) {
      $inline =~ s/\r\n/\n/g;
      $inline =~ s/\r/\n/g;
      $inline =~ s/\n/ /g;

      #
      #  Firstline will be true if simple header, so prepend to inline
      #
      if ( $firstline ) { 
         $inline = $firstline . $inline;
         $firstline="";
      }

      #   
      #  Get rid of trailing whitespace and make sure 
      #  there are no trailing open tags as lines are read. If a
      #  line ends with an open tag, append more lines until
      #  the tag is closed.
      #   
      while ( ($inline =~ /<[^>]*$/) && ($entity == 1) ) {
        $inline =~ s/\s*$/ /;
        $inline .= <SITE>;
        $inline =~ s/\r\n/\n/g;
        $inline =~ s/\r/\n/g;
      }
      $inline =~ s/<([^>]*)\n/<$1 /;
      print $HTML $inline;
   
   } 
   
   if ( $inline !~ /\n$/ ) { print $HTML "\n"; }
   close(SITE);

   return($sc);

}

#======================================================================
#
#  httpopen - opens a socket to the specified host
#
#======================================================================

sub httpopen{

   ###  sub httpopen ( $site, $HANDLE )

   local($site,$HANDLE) =  @_;

   local($port) =  $site;
   local($sockaddr,$remote) = ("Snc4x8");
   local(@hostaddr);

   #
   #  Get port number if site contains one
   #
   if ($site =~ /:[0-9]+$/) {
      $site =~ s/:[0-9]+$//;
      $port =~ s/^.*://;
   } else {
      $port=80;
   }

   #
   #  Open socket
   #
   @hostaddr = &httpaddr($site);
   if ( $hostaddr[0] == 0 ) { return(0); }

   $remote = pack($sockaddr,2,$port,@hostaddr);

   socket($HANDLE,2,2,6)    || return(0);
print "socket ok\n";
   connect($HANDLE,$remote) || return(0);
print "connect ok\n";
   select($HANDLE); 
   $|=1;                    # Unbuffer HANLDE 
   select(STDOUT);

   return(1);
}

#======================================================================

sub httpaddr {

   ###  sub httpaddr ( $host )


   local($httphost) = @_;

   local(@addrinfo) = gethostbyname($httphost);
   if ( ! $addrinfo[0] ) {
      return(0,0,0,0);
   } else {
      return(unpack("C4",$addrinfo[4]));
   }	

}

#======================================================================
#
#  httpreadhead - returns fields in the <pageid>.thd file
#                 statuscode
#                 reason
#                 modifdate
#
#======================================================================
#
#  Valid status codes and associated "reasons" from the HTTP/1.0 spec
#
#       Status-Code    = "200"   ; OK
#                      | "201"   ; Created
#                      | "202"   ; Accepted
#                      | "204"   ; No Content
#                      | "301"   ; Moved Permanently
#                      | "302"   ; Moved Temporarily
#                      | "304"   ; Not Modified
#                      | "400"   ; Bad Request
#                      | "401"   ; Unauthorized
#                      | "403"   ; Forbidden
#                      | "404"   ; Not Found
#                      | "500"   ; Internal Server Error
#                      | "501"   ; Not Implemented
#                      | "502"   ; Bad Gateway
#                      | "503"   ; Service Unavailable
#
#======================================================================

sub httpreadhead {

   ###  sub httpreadhead ( $FILE )

   local($FILE) = @_;
   local($inputline);
   local($statuscode,$reason);
   local(%header);
   local($modifdate,$servdate);

   #
   #  Grab the status info from the first line
   #
   $inputline = <$FILE> || &throw("Can't read from header file");

   ($statuscode,$reason) = ( $inputline =~ /HTTP\/\d+\.\d+ (\d+) (.*)\s*/ );

   #
   #  Now open the header as a DB and get the dates
   #
   &dbread($FILE,*header);
   $modifdate = $header{&uinsens(*header,'last-modified')};
   $servdate  = $header{&uinsens(*header,'date')};
   $modifdate = &datecheck($modifdate);
   $servdate  = &datecheck($servdate);

   return($statuscode,$reason,$servdate,$modifdate);

}
#======================================================================

sub httpping {

   ###  sub httpgetpage ( $site, $file )

   local($site,$file) = @_;
   local($inline,$firstline);
   local($go,$sc);


   $go = 0;

   #
   #  Try "everything possible" to get a good header
   #
   do {

      &httpopen($site,SITE) || return (0);
   
      #
      #  Send FUll-Request (HEAD)
      #
      print SITE "HEAD $file HTTP/1.1\n";
      print SITE "\n";

      #
      #  Grab first line of response
      #
      $inline = <SITE>;
      $inline =~ s/\r\n/\n/g;
      $inline =~ s/\r/\n/g;

      #
      #  If first line contains HTTP, process the full header, otherwise
      #  it's a simple header, so save the firstline and go.
      #
      if ( $inline =~ /HTTP/ ) {

         #
         #  First grab the statuscode
         #
         ($sc) = ( $inline =~ /HTTP\/\d+\.\d+ (\d+) / );

         #
         #  Read up to a blank line
         #
         $header = $inline;
         while ( ($inline = <SITE>) !~ /^\s*$/ ) {
            $inline =~ s/\r\n/\n/g;
            $inline =~ s/\r/\n/g;
            $header .= $inline;
         }

         #
         #  Don't even try to process unimplemented codes and
         #  server errors
         #
         #      1xx - (Unimplemented)
         #      500 - Internal Server Error
         #      501 - Not Implemented
         #      502 - Bad Gateway
         #      503 - Service Unavailable
         #
         if ( ($sc<200) ) {
            return($sc);
         }
     
         #   
         #   Treat all 200 codes as success
         #   
         #      200 - OK
         #      201 - Created
         #      202 - Accepted
         #      204 - No Content
         #   
         elsif ( ($sc>199) && ($sc<299)) {
            $go = 1;
         }

         #   
         #   If redirect, then try the new URL
         #   
         #      301 - Moved Permanently
         #      302 - Moved Temporarily
         #   
         elsif ( ($sc==301) || ($sc==302)) {
            ($url) = ($header =~ /Location:\s*(.*)\s*/i);
            ($protocol,$site,$file) = &uspliturl($url);
         }

         #   
         #   If not modified, we're done
         #   
         #      304 - Not Modified
         #   
         elsif ( $sc==304 ){
            return($sc);
         } 

         #
         #   On client error, try appending a / if one doesn't exist
         #
         #      400 - Bad Request
         #      401 - Unauthorized
         #      403 - Forbidden
         #      404 - Not Found
         #
         elsif ( ($sc>399) && ($sc<500) ) {
            if ( $file =~ /\/$/ ) {
               return($sc);
            } else {
               $file .= '/';
            }
         }

      } else {
         $firstline = $inline;
         $go = 1;
      }

   } until ( $go == 1);

   return($sc);

   close(SITE);

}
#======================================================================
1; # return true
