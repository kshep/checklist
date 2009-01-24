#!/usr/local/bin/perl4.036
#======================================================================
#
#  grabrefs - given the handle of a text file and an assoc array,
#             read the hrefs from the document and build the array
#             where the key is the URL and the value is the text of
#             the link
#
#======================================================================

require "cgi-lib.pl";
require "date.pl";
require "db.pl";
require "scanpage.pl";
require "throw.pl";
require "util.pl";

sub grabrefs {

   ###  sub grabrefs ( $FILE, %refs );

   local($FILE,*refs) = @_;
   local($inline);
   local($body);

   #
   #  Get the entire file as a single line
   #
   while ($inline = <$FILE>) {
      $inline =~ s/[\r\n]+/ /g;
      $body .= $inline;
   }

   #
   #  Grabe the base if there is one
   #
   $body =~ s/<\s*BASE[^>]*HREF\s*=\s*"([^"]*)"[^>]*>//i;
   $base = $1;
   if ( ! $base ) {
      $body =~ s/<\s*BASE[^>]*HREF\s*=\s*'([^']*)'[^>]*>//i;
      $base = $1;
   }
   $base =~ s,/$,,;

   #
   #  Process all the links
   #
   while ( $body =~ /<\s*A\s*[^>]*HREF/ ) {

      #
      #  Pull out HREFs and text between tags and </A>
      #
      if ( $body =~ s/<\s*A[^>]*HREF\s*=\s*"([^"]*)"[^>]*>([^<]*)<\/A>//i ){
         $key = $1;  $value = $2;
      } 
      elsif ( $body =~ s/<\s*A[^>]*HREF\s*=\s*'([^']*)'[^>]*>([^<]*)<\/A>//i ){
         $key = $1;  $value = $2;
      }

      #
      #  Prepend base if HREF doesn't have a protocol
      #
      if ( $key !~ m/:/ ) {
         $key =~ s,^/,,;
         $key = $base . "/" . $key;
      }

      #
      #  Only process HTTP hrefs
      #
      ($proto) = ( $key =~ m,^(\w+):,);
      if ( $proto =~ /http/i ) {
         $refs{$key} = $value;
      }

   }

}
