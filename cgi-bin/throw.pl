#!/usr/local/bin/perl4.036
#======================================================================
#
#  throw - Prints an error message to STDOUT and dumps the stack
#
#----------------------------------------------------------------------
#  Arguments:  a text string error message
#              a list of other info to be prited during dump
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------

require "util.pl";

sub throw {

   ###  sub throw ( $message, (misc parameters) )

   local($message) = shift;

   print "Content-type: text/html\n\n";

   $message = &uhtmlencode($message);

   print "<H1>CheckList Error</H1>\n";
   print "If you could send the message between the lines to me at ";
   print "<A HREF=\"mailto:kens@aimnet.com\">kens@aimnet.com</A> ";
   print "along with a brief description of what you were ";
   print "trying to do when you got this message, I'd really appreciate it.\n";
   print "<P><HR>\n";

   print "<P><STRONG>$message</STRONG><BR>\n";

   #
   #  Stack traceback from Perl debugger
   #
   for ($i = 0; ($p,$f,$l,$s,$h,$w) = caller($i); $i++) {
      @a = @DB'args;
      for (@a) {
         if (/^StB\000/ && length($_) == length($_main{'_main'})) {
            $_ = sprintf("%s",$_);
         } else {
            s/'/\\'/g;
            s/([^\0]*)/'$1'/ unless /^-?[\d.]+$/;
            s/([\200-\377])/sprintf("M-%c",ord($1)&0177)/eg;
            s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;
         }
      }
      $w = $w ? '@ = ' : '$ = ';
      $a = $h ? '(' . join(', ', @a) . ')' : '';

      $f =~ s,.*[/\\]([^/\\]*)\.[^.]*$,$1,;

      unshift(@sub, "$w&$s$a in $f at $l");
   }
   for ($i=0; $i <= $#sub; $i++) {
      $x = &uhtmlencode($sub[$i]);
      print "    $x\n<BR>\n";
   }

   print "<P><HR><P>\n";

   exit(1);

}

#======================================================================
1; # return true
