#!/usr/local/bin/perl4.036
#======================================================================
#
#  /cgi-bin/upload.pl
#
#----------------------------------------------------------------------

   if ( $ENV{'HOME'} eq "" ) {
      unshift(@INC,'/u6/users/kens/public_html/cgi-bin');
   } elsif  ( $ENV{'HOME'} eq "/u6/users/kens" ) {
      unshift(@INC,'/u6/users/kens/public_html/cgi-bin');
   } elsif ( $ENV{'HOME'} eq "C:\\" ) {
      unshift(@INC,'c:\website\cgi-shl');
   } else { die "Content/type: text/plain\n\n Bad install"; }

   require "config.pl";
   require "grabrefs.pl";
   require "agent.pl";


   $| = 1;   

   $tmpfile  = "/tmp/asdf".$ENV{'REMOTE_ADDR'};
 
   print "$tmpfile\n";
   #  
   #  Read in the CGI buffer and save in temp file
   #
   open(TMP,">$tmpfile");

   read(STDIN, $buffer, $ENV{'CONTENT_LENGTH'});
   print TMP $buffer;
   close(TMP);
  
   # 
   #  Now extract file from temp file
   # 
   open (TMP,$tmpfile);

   #
   #  Input is a MIME multipart message, so don't do ReadParse.
   #  Instead get user ID from first part, then read the file from
   #  the second part.
   #
   $inline = <TMP>;
   $inline = <TMP>;
   $inline = <TMP>;
   $user = <TMP>;
   $user =~ s/\s*//g;
   &config($user);
   
   # 
   #  Extract version number from MIME/multipart separator line
   #
   $inline = <TMP>;
   ($vernum) = ( $inline =~ /(\d+)/);
   
   # 
   #  Extract file name from next line
   #
   $inline = <TMP>;
   $filename = $1 if ($inline =~ /filename=\"(.*)\"/); 
  
   # 
   #  Trim off path info to get filename
   #
   $filename =~ s,.*[^/\\]*[/\\]([^/\\]*)$,$1, || &throw("Bad file name");
   
   # Now that we know the name of the file, let's create it in our upload
   # directory..
   open(FILE,">${G'uploaddir}${filename}");
   
   # 
   # Skip over Content-type info
   #
   $junk = <TMP>; 
   $junk = <TMP>;
   
   
   # And we're gunna read/write all the lines of our file until we come to the
   # MIME-multipart separator, which we'll ignore.
   while (<TMP>) {
      print FILE if (!(/-{28,29}$vernum/));
   }
   
   close (TMP);
   close (FILE);

   unlink($tmpfile);
   
   $input{'user'} = $user;
   $input{'file'} = $filename;

   #
   #  Now have agent process the uploaded file
   #
   &agent("upload",%input);

#======================================================================
