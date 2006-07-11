#!/usr/bin/perl -w
#
# perl xml1.pl languagetool_root file_to_be_checked language (hu, de, en)
#
  
 my ( $line1, $oline,$sline,  $apos, $cut, $rule, $comment, $i, $mpos);
 my @array = ();
 my @rules = ();
 my @comments = ();
 $apos = 0;
 $cut = 0;
 
# print $ARGV[0].'/tools/'.$ARGV[2].'rule.txt', "\n";
 open(RULES, $ARGV[0].'/tools/'.$ARGV[2].'rule.txt') || die "Can't open ".$ARGV[2]."rule.txt";
 while($line1 = <RULES>){
#   print "line1:", $line1, "--",substr($line1,0,1),"\n";
   if(substr($line1,0,1) ne '#'){
     chop($line1);
     if(length($line1) > 2){
       ($rule, $comment) = split('<\.',$line1);
        push(@rules, $rule);
       push(@comments, $comment); 
#      print $rule,"+++",$comment,"\n";
     }
   }
 }
 close RULES;
 
 open(FILE, $ARGV[1]);
 $apos = 0;
 while($line1 = <FILE>){
    $oline = $line1;
    $i = 0;
    foreach $rule (@rules){
      $sline = $line1;
      while ($line1 =~ m/$rule/gi){
#       print "matched:",$rule," line:",$line1," pos:",pos($line1),"\n";
#       print "pos:", pos($line1), " elotte:", $`, " minta:<", $&,"> utána:", $',"\n";
       $mpos = $apos +$cut + pos($line1)-length($&);
       if($mpos < 0) {$mpos = 0;}
       print "", $mpos," ",$apos+$cut+pos($line1)," ",$comments[$i],"\n"  ;
       $cut = $cut + pos($line1);
       $line1 = substr($line1, pos($line1));
#       print  "line12:",$line1;    
     } # line match
     $line1 = $sline;
     $i++;
     $cut = 0;
   } # rules
    $apos = $apos + length($oline);
    $cut = 0;
 } 
   close(FILE);

