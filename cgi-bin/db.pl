#!/usr/local/bin/perl4.036
#======================================================================
# 
#  For use when DBM not available. Reads and writes associative 
#  arrays to the named files.
#
#  Primative in that the array is written one key/value pair per
#  line, seperated by a colon, and the record terminator is a \n.
#
#  Fine for simple cases, but not practical for general use.
#
#     dbread(ASSOC,DBHANDLE)
#     dbwrite(ASSOC,DBHANDLE)
#
#----------------------------------------------------------------------
#   a1   03/04/96   Original Version (alpha 1)
#----------------------------------------------------------------------


#======================================================================
#
#  dbread  -  Read associative array from file
#
#----------------------------------------------------------------------
#  Arguments:  associative array to fill
#              file handle to read from
#----------------------------------------------------------------------
#  Returns:    1
#----------------------------------------------------------------------

sub dbread {

   ###  sub dbread ( $FILE, *array )

   local($FILE,*array) = @_;
   local($inline,$key,$value);

   while ($inline = <$FILE>){
      chop $inline;
      $inline =~ s/ *:/:/;
      ($key,$value) = split(/:/,$inline,2);
      $key   =~ s/^ *//;
      $value =~ s/^ *//;
      $array{$key} = $value;

   }

   return(1);

}
#======================================================================
#
#  dbwrite  -  Write associative array to file
#
#----------------------------------------------------------------------
#  Arguments:  associative array to write
#              file handle to write to
#----------------------------------------------------------------------
#  Returns:    1
#----------------------------------------------------------------------

sub dbwrite {

   ###  sub dbwrite ( $FILE, *array )

   local($FILE,*array) = @_;
   local($key);

   foreach $key (sort(keys(%array))) {
      print $FILE "$key:$array{$key}\n";
   }

   return(1);

}
#======================================================================
#
#  dbinvert - builds an array to allow lookup of pageid by the
#             given field
#
#----------------------------------------------------------------------
#  Arguments: associative array containing original db
#             integer indicating which field to use as inverse key
#----------------------------------------------------------------------
#  Returns:   associative array containing db of inverse key vs pageid
#----------------------------------------------------------------------

sub dbinvert {

   ###  sub dbinvert ( *array, $keyfield )

   local(*array,$keyfield) = @_;
   local($key,@fields,%result);

   foreach $key (sort(keys(%array))) {
      @fields = split("\000",$array{$key});
      $result{$fields[$keyfield-1]} = $key;
   }

   return(%result);

}


#======================================================================
#
# increment the hex value contained in the key
#
#----------------------------------------------------------------------
#  Arguments:  string containing old key
#----------------------------------------------------------------------
#  Returns:    string containing new key = old key + 1
#----------------------------------------------------------------------

sub dbinckey {

   ###  sub dbinckey ( $oldkey )

   local($oldkey) = @_;
   local($headlen,$decval,$newhexval,$zeros,$newhexstr,$offset);

   local($head,$oldhexstr) = ( $oldkey =~ /([^0-9a-f]*)(.*)/i );
   $headlen           = length($head);
   $oldhexstrlen      = length($oldhexstr);
   $decval            = hex($oldhexstr);
   $decval++;
   $newhexval         = sprintf("%x",$decval);
   $zeros             = "0" x $oldhexstrlen;
   $newhexstr         = "$zeros$newhexval";
   $offset            = length($newhexstr)-length($oldhexstr);
   $newhexstr         = substr($newhexstr,$offset);

   return("$head$newhexstr");

}

#======================================================================
1; # return true
