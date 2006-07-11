#!/usr/bin/perl -w
#
# PptkSpell - A Perl/Tk GUI based Perl-script spell-checking editor with error highlighting and optional support of text-to-speech
#
# Usage: see Perl documentation in pod format (perldoc)
#
#use strict;
use Tk;
require Tk::BrowseEntry;
use Text::Hunspell;
use Data::Dumper;


{   ###########################################################################
    package TextSpellHighlight;
    ###########################################################################

    use vars qw($VERSION %FUNC);
    $VERSION = '1.01';

    my @FUNC = qw//;

    # Build lookup tables
#    @FUNC{@FUNC} = (1) x @FUNC; undef @FUNC;

    use Tk qw(Ev);
    use AutoLoader;

    # Set @TextSpellHighlight::ISA = ('Tk::TextUndo')
    use base qw(Tk::TextUndo);


    Construct Tk::Widget 'TextSpellHighlight';
    my $w;
    sub ClassInit {
        my ($class, $mw) = @_;
        $class->SUPER::ClassInit($mw);
        $mw->bind($class, '<Control-o>', \&main::openDialog);
        $mw->bind($class, '<Control-n>', [\&main::addPage, 'Untitled']);
        $mw->bind($class, '<Control-s>', [\&main::saveDialog, 's']);
        $mw->bind($class, '<Control-m>', \&main::Mbrplay);
        $mw->bind($class, '<Control-p>', \&main::Replay);
        $mw->bind($class, '<Control-q>', \&main::NextGramError);
        $mw->bind($class, '<Control-w>', \&main::PrevGramError);
        $mw->bind($class, '<Control-x>', \&main::ClipCut );
        $mw->bind($class, '<Control-c>', \&main::ClipCopy );
        $mw->bind($class, '<Control-f>', \&main::Find );
        $mw->bind($class, '<Control-r>', \&main::FindReplace );
        $mw->bind($class, '<Control-z>', \&main::Undo );
        $mw->bind($class, '<Control-y>', \&main::Redo );
        $mw->bind($class, '<Control-g>', \&main::GotoLine );
        $mw->bind($class, '<F1>', \&main::commandHelp);
        return $class;
    }

        
    sub InitObject {
        my ($w, $args) = @_;
        $w->SUPER::InitObject($args);
        $w->tagConfigure('FUNC', -foreground => '#FF0000');
        $w->tagConfigure('BLUE', -foreground => '#0033ff');
        # Default: font family courier, size 10
        $w->configure(-font => $w->fontCreate(qw/-family times -size 17/), -wrap => 'word', -selectbackground=>'#ffff33');
        $w->{CALLBACK} = undef;
        $w->{CHANGES} = 0;
        $w->{LINE} = 0;
    }

    sub Button1 {
        my $w = shift;
        $w->SUPER::Button1(@_);
        &{$w->{CALLBACK}} if ( defined $w->{CALLBACK} );
    }

    sub see {
        my $w = shift;
        $w->SUPER::see(@_);
        &{$w->{CALLBACK}} if ( defined $w->{CALLBACK} );
    }

    # Set/Get the amount of changes
    sub numberChangesExt {
        my ($w, $changes) = @_;
        if ( @_ > 1 ) {
            $w->{CHANGES} = $changes;
        }
        return $w->{CHANGES};
    }

    # Register callback function and call it immediately
    sub positionChangedCallback {
        my ($w, $callback) = @_;
        &{$w->{CALLBACK} = $callback};
    }

    sub insert {
        my $w = shift;
        my ($s_line) = split(/\./, $w->index('insert'));
        $w->SUPER::insert(@_);
        my ($e_line) = split(/\./, $w->index('insert'));
        highlight($w, $s_line, $e_line);
        &{$w->{CALLBACK}} if ( defined $w->{CALLBACK} );
    }

    # Insert text without highlight
    sub insertWHL {
        my $w = shift;
        $w->SUPER::insert(@_);
    }

    # Background highlight
    sub backgroundHL {
        my ($w, $l) = @_;
        my ($end) = split(/\./, $w->index('end'));
        $w->{LINE} = $end unless ( $w->{LINE} );
        # 'cut/delete' correction if needed
        if ( $w->{LINE} != $end ) {
            $l -= ($w->{LINE} - $end);
            if ( $l < 0 ) { $l = 0 }
            $w->{LINE} = $end;
        }
        highlight($w, $l, $l+50 > $end ? $end-1 : $l+50);
        if ( $l+50 < $end ) {
            $w->after(50, [\&backgroundHL, $w, $l+50+1]);
        }
        else { $w->{LINE} = 0 }
    }

    sub insertTab {
        my ($w) = @_;
        my $pos = (split(/\./, $w->index('insert')))[1];
        # Insert spaces instead of tabs
        $w->Insert(' ' x (4-($pos%4)));
        $w->focus;
        &{$w->{CALLBACK}} if ( defined $w->{CALLBACK} );
        $w->break;
    }

    sub delete {
        my $w = shift;
        $w->SUPER::delete(@_);
        my ($line) = split(/\./, $w->index('insert'));
        highlight($w, $line, $line);
    }

    sub InsertKeypress {
        my $w = shift;
        $w->SUPER::InsertKeypress(@_);

        my ($line) = split(/\./, $w->index('insert'));
        highlight($w, $line, $line);
        &{$w->{CALLBACK}} if ( defined $w->{CALLBACK} );
    }

    sub highlight {
        my ($w, $s_line, $e_line) = @_;
        my $oldword = "";
        # Remove tags from current area
        foreach ( qw/FUNC BLUE/ ) {
            $w->tagRemove($_, $s_line.'.0', $e_line.'.end');
        }

        foreach my $ln($s_line .. $e_line) {
	    my ($i, $rot);
            my $line = $w->get($ln.'.0', $ln.'.end');
 #           print "----",$line,"----\n";
           # Highlight: strings
           # Highlight: functions, flow control words and operators,
            # do not highlight hashes, arrays or scalars
            while ( $line =~ /        \b        # Match a word boundary
                                          ((\w | [áéíóúöüõûÁÉÍÓÚÕÛÖÜäÄß.,])+) # Match a "word"
                                      \b        # Match a word boundary
                             /gx ) {
#	         print " ln:", $ln," s:", $s_line," e:", $e_line," p:",pos($line)," sw:", pos($line)-length($1),"\n";
 #                print $1,' ', pos($line),' ', pos($line) - length($1),"\n";
                if(!main::TestGramchk()) {
                    $rot = 0;
		    if (main::TestDouble() && ($1 eq $oldword)){
                            $w->tagAdd('FUNC', $ln.'.'.(pos($line)-length($1)),
                               $ln.'.'.pos($line));
		               $rot = 1;
	            }		    
                    if(!$rot && main::TestDotLc()){
		     my $elso = substr($1,0,1);
		     if( (!($elso =~ m/[0-9]/gx)) &&
		        (lc($elso) eq $elso ) &&
		     (main::DotBefore($line, pos($line) -length($1)) ) ){
                               $w->tagAdd('FUNC', $ln.'.'.(pos($line)-length($1)),
                                 $ln.'.'.pos($line));
				 next;
	               }
		    } # dotlc
		    if (!$rot && (!main::SpellTest($1)) ){
                             $w->tagAdd('FUNC', $ln.'.'.(pos($line)-length($1)),
                               $ln.'.'.pos($line));
 		    } # double or word wrong
		    $oldword = $1;
		} # not gram chk
	        elsif(!main::TestGram($ln, pos($line))){
#                    print $1, " ",pos($line),"\n";
		    $w->tagAdd('BLUE', $ln.'.'.(pos($line)-length($1)),
                               $ln.'.'.pos($line));
	        }
             } # while line
        } # foreach
    } # highlight
} # END - package TextSpellHighlight

###############################################################################
package main;
###############################################################################

use File::Find;
use File::Basename;
use Tk::HList;
use Tk::Dialog;
use Tk::ROText;
use Tk::Balloon;
use Tk::DropSite;
use Tk::NoteBook;
use Tk::Adjuster;
require Tk::LabEntry;
my $FIFO = '/tmp/.signature';
my $FIFOC = '/tmp/.csignature';
my $sline;
my $rcfile = "$ENV{'HOME'}/.pptkspellrc";
my $MbrolaSound = "/usr/local/mbrola/hu1/hu1";
my $txt2phoProc = "/usr/bin/doptkphots.sh";
my $speller = "";
#my $spellserver = "/usr/local/bin/spellserver";
my $language = "/home/en/program/hunspell-1.0-RC1/hu_HU";
my $mytmp = "/tmp/xxx";
my $info = "";
my $playit = "play";
my $tmpwav="/tmp/xx.wav";
my $languagetoolhome = "/mnt/win_d/hattyu/tyuk/dtest/python/danielnaber/cvs1/languagetool";
my $languageused = "hu";
my @filelist = ();
my ($file1, $file2, $file3, $file4);
my @sorok = ();
my @usorok = ();
my $gramerind = -1;
my $errline = '';
my $gramchk = 0;
my $configChanged = 0;
my $doubleChk = 1;
my $dotlcChk = 1;
my $initialdir = "/mnt/win_d/hattyu/tyuk/download/politika/tortenelem/safivalostort";
my $dobackup = 1;
my $doublespcfix = 0;
my $simpgramchk = 0;     


 my   $named_pipe;
 my   $namedr_pipe;
 my   $data;
 my   $olddata;
 my   $ServerOn = 1;
 my   $crlf = 1;


# Seed the random number generator
BEGIN { srand() if $] < 5.004 }

my @filetypes = (
    ['Texts',     '.txt',  'TEXT'],
    ['Other',     '*',  'TEXT']
    );

# Create main window and return window handle
my $mw = MainWindow->new(-title => 'Ptkspell');

if ($^O ne 'linux'){
	$mw->geometry( "600x700" );
}else{
    $mw->geometry( "700x900" );
}

# Manage window manager protocol
$mw->protocol('WM_DELETE_WINDOW' => \&exitCommand);

# Add menubar
$mw->configure(-menu =>
my $menubar = $mw->Menu(-tearoff => $Tk::platform eq 'unix'));

# Add 'File' entry to the menu
my $file = $menubar->cascade(qw/-label File -underline 0 -menuitems/ =>
    [
        [command => '~New',         -accelerator => 'Ctrl+N',
                                    -command => [\&addPage, 'Untitled']],
        [command => '~Open...',     -accelerator => 'Ctrl+O',
                                    -command => \&openDialog],
        [command => '~OpenOld...',     -accelerator => 'Ctrl+I',
                                    -command => \&openOldDialog],
        [command => '~Close',       -command => \&closeCommand,
                                    -state   => 'disabled'],
        '',
        [command => '~Save',        -accelerator => 'Ctrl+S',
                                    -command => [\&saveDialog, 's']],
        [command => 'Save ~As...',  -command => [\&saveDialog, 'a']],
        '',
        [command => 'E~xit',        -command => \&exitCommand],
    ], -tearoff => $Tk::platform eq 'unix');

# Add 'Edit' entry to the menu
my $edit = $menubar->cascade(qw/-label Edit -underline 0 -menuitems/ =>
    [
        [command => '~Undo',        -accelerator => 'Ctrl+Z',
                                    -command => [\&menuCommands, 'eu']],
        [command => '~Redo',        -accelerator => 'Ctrl+Y',
                                    -command => [\&menuCommands, 'er']],
        '',
        [command => 'Cu~t',         -accelerator => 'Ctrl+X',
                                    -command => [\&menuCommands, 'et']],
        [command => 'C~opy',        -accelerator => 'Ctrl+C',
                                    -command => [\&menuCommands, 'eo']],
        [command => 'P~aste',       -accelerator => 'Ctrl+V',
                                    -command => [\&menuCommands, 'ea']],
        '',
        [command => 'Select A~ll',  -command => [\&menuCommands, 'el']],
        [command => 'Unsele~ct All',-command => [\&menuCommands, 'ec']],
    ], -tearoff => $Tk::platform eq 'unix');
# Add 'Edit' entry to the menu
my $search = $menubar->cascade(qw/-label Search -underline 0 -menuitems/ =>
    [
        [command => '~Find',        -accelerator => 'Ctrl+F',
                                    -command => [\&menuCommands, 'ef']],
        [command => 'FindAnd~Replace',        -accelerator => 'Ctrl+R',
                                    -command => [\&menuCommands, 'ee']],
        '',
        [command => '~GotoLine',        -accelerator => 'Ctrl+G',
                                    -command => [\&menuCommands, 'eg']],
        [command => '~WhichLine?',  -command => [\&menuCommands, 'ew']],
     ], -tearoff => $Tk::platform eq 'unix');

# Add 'Misc' entry to the menu
my $misc = $menubar->cascade(qw/-label Misc -underline 0 -menuitems/ =>
    [
        [command => '~Properties...',       -command => \&propertiesDialog],
        [Checkbutton => 'CR~LF Conversion', -variable => \$crlf],
       '',
        [Checkbutton => '~GrammarCheck', -command => \&doGramCheck],                                         
        [command => 'NextGrammarError',        -accelerator => 'Ctrl+Q',
                 -command => \&NextGramError],
        [command => 'PreviousGrammarError',        -accelerator => 'Ctrl+W',
               -command => \&PrevGramError],
       '',
        [Checkbutton => '~DoubleWordCheck', -variable=>\$doubleChk ],       
        [Checkbutton => '~lcAfterDotCheck', -variable=>\$dotlcChk],          
        [Checkbutton => '~BackupFile', -variable=>\$dobackup],          
        [Checkbutton => 'D~oubleSpaceFix', -variable=>\$doublespcfix],          
        [Checkbutton => 'SimplifiedGrammarCheck', -variable=>\$simpgramchk],          
	'',
        [command => '~Configure',        
                                    -command => \&configure],
       '',
        [command => '~PlaySelected',        -accelerator => 'Ctrl+M',
                                    -command => \&Mbrplay],
        [command => '~Replay',        -accelerator => 'Ctrl+P',
                                    -command => \&Replay],
    ], -tearoff => $Tk::platform eq 'unix');
    

SetGramErMenu('disabled');

sub SetGramErMenu {
        my $how = shift;
    
        $misc->cget(-menu)->entryconfigure(4 + ($Tk::platform eq 'unix'),
                                           -state => $how);
        $misc->cget(-menu)->entryconfigure(5 + ($Tk::platform eq 'unix'),
                                           -state => $how);
}

    
# Add 'Help' entry to the menu
my $help = $menubar->cascade(qw/-label Help -underline 0 -menuitems/ =>
    [
        [command => '~Short Help...',    -command => \&helpDialog],
      '',
         [command => '~About...',    -command => \&aboutDialog],
    ], -tearoff => $Tk::platform eq 'unix');

# Add NoteBook metaphor
my $nb = $mw->NoteBook();

my $db = $mw->DialogBox(-title=>'OldFiles', 
                      -buttons=>['File1', 'File2', 'File3', 'File4', 'Cancel'],
		      -default_button=>'Cancel');
$db->add('LabEntry', -textvariable=>\$file1, -label=>'File1',   
        -width=>62, -labelPack=>[-side=>'left'])->pack;		    
$db->add('LabEntry', -textvariable=>\$file2, -label=>'File2',   
        -width=>62, -labelPack=>[-side=>'left'])->pack;		    
$db->add('LabEntry', -textvariable=>\$file3, -label=>'File3',   
        -width=>62, -labelPack=>[-side=>'left'])->pack;		    
$db->add('LabEntry', -textvariable=>\$file4, -label=>'File4',   
        -width=>62,  -labelPack=>[-side=>'left'])->pack;		    

my ($tw, $cmdHelp, %pageName);

sub GramCheckSet {
   if ( $gramchk) {
       SetGramErMenu('active');
    }
    else {
        SetGramErMenu('disabled');
    }

}

sub DotBefore {
   my $line = shift;
   my $pos = shift;
   my $i;
   my $vanpont = 0;
   my $csakszam = 0;
   for( $i = $pos-1; $i >= 0; $i--){
     my $ch = substr($line, $i,1);
#     print 'ch:', $ch,"\n";
     if($ch eq "."){ $vanpont = 1; }
     elsif($ch =~ m/[0-9]/gx && $vanpont){$csakszam = 1;}
     elsif($ch eq " " && $vanpont && $csakszam) {return 0;}
     elsif($ch eq " " && $vanpont) {return 1;}
     elsif($ch eq " "){ return 0;}
     elsif($ch =~ m/[A-Za-z_] | [áéíóúöüõûÁÉÍÓÚÖÜÕÛäÄß\)\]\}]/gx ){ if($vanpont) {return 1;} else{return 0;}}
   }
   return 0;
}


sub TestDouble {
   return $doubleChk;
}
sub TestDotLc {
   return $dotlcChk;
}
	 
sub TestGramchk {
  return $gramchk;
}

sub NextGramError {
  if(!$gramchk) {return;}
  my  ($ssor, $rstrt, $rstp, $str, $mycol);
  if($gramerind + 1 > $#usorok){
    $mw->bell;
    return;
  }
  else{
    ++$gramerind;
    ($ssor, $rstrt, $rstp, $str) = split(/ /, $usorok[$gramerind],4); 
    $mycol = $rstrt - 1;
    if($mycol < 0) {$mycol = 0;}
    $tw->see($ssor.".".$mycol);
    $tw->SetCursor($ssor.".".$mycol);
    $info = $str;
    $mw->update();
  }
}
sub PrevGramError {
  if(!$gramchk) {return;}
  my  ($ssor, $rstrt, $rstp, $str, $mycol);
  if($gramerind - 1 < 0){
    $mw->bell;
    return;
  }
  else{
    --$gramerind;
    ($ssor, $rstrt, $rstp, $str) = split(/ /, $usorok[$gramerind],4); 
    $mycol = $rstrt - 1;
    if($mycol < 0) {$mycol = 0;}
    $tw->see($ssor.".".$mycol);
    $tw->SetCursor($ssor.".".$mycol);
    $info = $str;
    $mw->update();
  }
}

sub ModifySor {
  my $sor = shift;
  my ($strt, $stp, $str, $i);
  my ($ssor, $cstrt, $cstp);
  my ($rstrt, $rstp);
  ($strt, $stp, $str) = split(/ /, $sor, 3);
#  print $strt,' ', $stp,' ', $str,"\n";
  for($i = 0; $i <= $#sorok; $i++){
   ($ssor, $cstrt, $cstp) = split(/ /,$sorok[$i]);
   if($cstp > $strt) {
     last;
   }
  }
  $rstrt = $strt-$cstrt+1;
  $rstp = $stp-$cstrt+1;
  $str =~ s/\<em\>//g;
  $str =~ s/\<\/em\>//g;
  return $ssor.' '.$rstrt.' '.$rstp.' '.$str;
}

sub  DoOpenFile {
  my $filename = shift;
  my $i;
#  print "in OPenFile\n";
  if ( defined $filename and $filename ne '' ) {
      if($gramchk){
        my $command;
      if(!$simpgramchk){
        $command = $languagetoolhome.'/tools/posi.sh '.$languagetoolhome.' '.$filename.' '.$languageused;
        } else{
        $command = $languagetoolhome.'/tools/posiperl.sh '.$languagetoolhome.' '.$filename.' '.$languageused;
	}
        $info = "Grammar check ongoing...";
	$mw->update();
	print "sgc:", $simpgramchk, " command:", $command,"\n";
	system($command);
        $info="";
	$mw->update();
	open(F, '<'.$filename);
	my ($sor1, $sum, $osum);
	my $outfile = $languagetoolhome.'/tools/checkout.txt';
        my $sor;
	$sum = 0; 
	$osum = 0;
	$i = 1;
	while($sor = <F>){
	  $sor1 = length($sor);
	  $sum = $sum + $sor1 -1;
#	  print $i.' '.$osum.' '.$sum,"\n";
	  push(@sorok, $i.' '.$osum.' '.$sum);
	  $sum++;
	  $osum = $sum;
	  $i++;
	}
	close(F);
        open(F, '<'.$outfile);
	@usorok = ();
	$i = 0;
        while ($sor = <F>){
	  chop($sor);
	  $sor = ModifySor($sor);
	  push( @usorok, $sor);
#          print $sor,"\n";
          $i++;
        }
        close F;
      
      }
       $errline = $i;
       addPage($filename);
       addFilelist($filename); 
       $gramerind = -1;
       NextGramError();
 }
}

sub openOldDialog {
  $file1 = $filelist[0];
  $file2 = $filelist[1];
  $file3 = $filelist[2];
  $file4 = $filelist[3];
  my $answer = $db->Show();
  if($answer ne 'Cancel'){
     my $filename;
     if( $answer eq 'File1'){
       $filename = $filelist[0];
     } elsif ($answer eq 'File2'){
       $filename = $filelist[1];
     } elsif ($answer eq 'File3'){
       $filename = $filelist[2];
     } elsif ($answer eq 'File4'){
       $filename = $filelist[3];
     }
     DoOpenFile($filename);
  }
}

# Accept drops from an external application
$nb->DropSite(-dropcommand => \&handleDND,
              -droptypes   => ($^O eq 'MSWin32' or ($^O eq 'cygwin' and
                              $Tk::platform eq 'MSWin32')) ? ['Win32'] :
                              [qw/XDND Sun/]);
#                              [qw/KDE XDND Sun/]);

# Accept ASCII text file or file which does not exist
foreach ( @ARGV ) {
    if ( (-e $_ && -T _) || !-e _ ) {
        addPage($_);
    }
}

# Add default page if there are no pages in notebook metaphor
unless ( keys %pageName ) {
    addPage('Untitled');
}



ReadConfiguration();
# start spell server
StartSpellServer();


sub StartSpellServer {
#print "In StartSpellServer\n";
if ($speller ne ""){
 $speller->delete($speller);
}
$speller = Text::Hunspell->new($language.".aff", $language.".dic");
    die unless $speller;
}

sub ValLangServer {
  return 1;
}

sub ValLanguage {
  if(!(-e $language.".aff")){
    $info = "language does not exist ".$language.".aff";
    return 0;
  }
  if(!(-e $language.".dic")){
    $info = "language does not exist ".$language.".dic";
    return 0;
  }
  return 1;
}

sub ValLanguagetool {
  if(!(-e $languagetoolhome."/TextChecker.py" )){
    $info = "Languagetool  does not exist ".$languagetoolhome ;
    return 0;
  }
  return 1;
}

sub ValLanguageUsed {
  if(($languageused ne "hu") &&  ($languageused ne "de") && ($languageused ne "en")){
    $info = "Language must be en, de or hu ".$languageused ;
    return 0;
  }
  return 1;
}

sub ValMbrolaSound {
  if(!(-e $MbrolaSound )){
    $info = "MbrolaSound  does not exist ".$MbrolaSound ;
    return 0;
  }
  return 1;
}
sub Valtxt2phoProc {
  if(!(-e $txt2phoProc )){
    $info = "txt2phoProc does not exist ".$txt2phoProc ;
    return 0;
  }
  return 1;
}

sub ReadConfiguration {
if ($^O eq 'MSWin32')
   {$rcfile = "./ptkspellrc";}
if(open(F,"<".$rcfile)){
  my $sor;
  while($sor = <F>){
   chop($sor);
   if($sor eq "[Language]"){
     $sor = <F>;
     chop($sor);
     $language = $sor;
   } elsif ($sor eq "[InitialDir]"){
     $sor = <F>;
     chop($sor);
     $initialdir = $sor;
   } elsif ($sor eq "[Languagetool]"){
     $sor = <F>;
     chop($sor);
     $languagetoolhome = $sor;
   } elsif ($sor eq "[LanguageUsed]"){
      $sor = <F>;
      chop($sor);
      $languageused = $sor;
   } elsif ($sor eq "[MbrolaSound]"){
      $sor = <F>;
      chop($sor);
      $MbrolaSound = $sor;
   } elsif($sor eq "[Txt2PhoProc]"){
      $sor = <F>;
      chop($sor);
      $txt2phoProc = $sor;
   } elsif($sor eq "[DoubleWdCheck]"){
      $sor = <F>;
      chop($sor);
      $doubleChk = $sor;
   } elsif($sor eq "[AfterDotCheck]"){
      $sor = <F>;
      chop($sor);
      $dotlcChk = $sor;
   } elsif($sor eq "[Backupfile]"){
      $sor = <F>;
      chop($sor);
      $dobackup = $sor;
   } elsif($sor eq "[DoubleSpaceFix]"){
      $sor = <F>;
      chop($sor);
      $doublespcfix = $sor;
   } elsif($sor eq "[SimplifiedGrammarCheck]"){
      $sor = <F>;
      chop($sor);
      $simpgramchk = $sor;      
   } elsif($sor eq "[FileList]"){
     while(1){
      $sor = <F>;
      chop($sor);
      if(length($sor) < 3) {last;}
      addFilelist($sor);
     }
   }
  }
  close(F);
 } else {
  print "Can't open ".$rcfile,"\n";;
 }
  ValLangServer();
  ValLanguage();
  ValLanguagetool();
  ValLanguageUsed();
  ValMbrolaSound();
  Valtxt2phoProc();
}
#InitLanguage();

#Init language

#sub InitLanguage{
#}

# Show filename over the 'pageName' using balloons
my ($balloon, $msg) = $mw->Balloon(-state => 'balloon',
                                   -balloonposition => 'mouse');
$balloon->attach($nb, -balloonmsg => \$msg,
                -motioncommand => sub {
                    my ($nb, $x, $y) = @_;
                    # Adjust screen to widget coordinates
                    $x -= $nb->rootx;
                    $y -= $nb->rooty;
                    my $name = $nb->identify($x, $y);
                    if ( defined $name ) {
                        $msg = 'File name: '.$pageName{$name}->FileName();
                        0; # Don't cancel the balloon
                    } else { 1 } # Cancel the balloon
                });
my $searchString="";

# Add status bar to the bottom of the screen
my $fr = $mw->Frame->pack(qw/-side bottom -fill x/);
$fr->Label(-textvariable => \my $st)->pack(qw/-side left/);
$fr->Label(-textvariable => \$errline)->pack(qw/-side left/);
#$fr->Label(-textvariable => \my $clk)->pack(qw/-side right/);
my $clk;

$fr->Label(-textvariable => \$info)->pack(qw/-side right/);
my $be = $fr->BrowseEntry(-variable=>\$searchString,   -browsecmd=>\&do_search, -listcmd=>\&getSuggestion)->pack(-side=>'right');

updateClock();

sub doGramCheck {
  if(!$gramchk){
    $gramchk = 1;
    $be->packForget();
   }else{
    $gramchk = 0;
    $be->pack(-side=>'right');
   }
}


sub do_search {
#  print "do_search\n";
  $tw->Insert($searchString);
}
sub getSuggestion {
   my $wd = $tw->getSelected();
 #  print "in getsugg wd:", $wd, "\n";
   if($wd eq "") {return;}
   my @list = $speller->suggest( $wd);
   
#   my @list = split(/ /, $data);
   if ($#list){
   my $i = 0;
   $be->delete('0', 'end');
   foreach(@list){
      $be->insert('end', $list[$i++]);
   }
  }
}


$nb->pack(qw/-side top -expand 1 -fill both/);

# the top part of the dialog box will let people enter their names,
# with a Label as a prompt

my $dialog = $mw->DialogBox( -title   => "Ptkspell Configure",
                            -buttons => [ "Configure", "Cancel" ]			    
                           );

$dialog->add("Label", -text => "Spell check files (.dic, .aff) location and name")->pack();
my $entry2 = $dialog->add("Entry", -textvariable => \$language, -width => 55,-background => '#fffff9')->pack();
$dialog->add("Label", -text => "Initial Directory for Open File")->pack();
my $entry21 = $dialog->add("Entry", -textvariable => \$initialdir, -width => 55,-background => '#fffff9')->pack();
$dialog->add("Label", -text => "Grammar checking Tool Home")->pack();
my $entry3 = $dialog->add("Entry", -textvariable => \$languagetoolhome, -width => 55,-background => '#fffff9')->pack();
$dialog->add("Label", -text => "Grammar checker language (de, en, hu)")->pack();
my $entry4 = $dialog->add("Entry", -textvariable => \$languageused, -width => 55,-background => '#fffff9')->pack();
$dialog->add("Label", -text => "Mbrola Language directory")->pack();
my $entry5 = $dialog->add("Entry", -textvariable => \$MbrolaSound, -width => 55,-background => '#fffff9')->pack();
$dialog->add("Label", -text => "Txt2pho procedure for mbrola")->pack();
my $entry6 = $dialog->add("Entry", -textvariable => \$txt2phoProc, -width => 55,-background => '#fffff9')->pack();

#test();

# Start the GUI and eventloop
MainLoop;


# Create modal 'About' dialog
sub aboutDialog {
    my $popup = $mw->Dialog(
        -popover        => $mw,
        -title          => 'About PtkSpell',
        -bitmap         => 'Tk',
        -default_button => 'OK',
        -buttons        => ['OK'],
        -text           => "PtkSpell\nVersion 1.00 - 22-May-2005\n\n".
                           "Copyright (C) Eleonora\n".
			   "Based on T-Pad (Tomi Parvainen)\n".
                           "http://www.cpan.org/scripts/\n\n".
                           "Perl Version $]\n".
                           "Tk Version $Tk::VERSION",
        );
    $popup->resizable('no', 'no');
    $popup->Show();
}
sub helpDialog {
    my $popup = $mw->Dialog(
        -popover        => $mw,
        -title          => 'Short Help to PtkSpell',
        -bitmap         => 'Tk',
        -default_button => 'OK',
        -buttons        => ['OK'],
        -text           => "Read (voice): Ctrl-M\n".
			   "re-Read (voice): Ctrl-P\n".
			   "Short Grammar Check is a fast, simplified Hungarian check\n".			   
			   "Grammar Check, Next: Ctrl-Q\n".
			   "Grammar Check, Prev: Ctrl-W\n".			   
			   "Save to clipboard: Ctrl-C\n". 
			   "Use on KDE Klipper to retrieve clipboard text\n",
         );
    $popup->resizable('no', 'no');
    $popup->Show();
}

sub doBackupSpcfix {
    my $pageName = shift;
    
    if($pageName ne 'Untitled') {
	my $tmpfile=$pageName."~";
        if($doublespcfix){
	  my $mline;
	  # correct file
	  open(FILE, $pageName) or die "$!";
	  open(FILE1, ">".$pageName."~") or die "$!";
	     while ( $mline = <FILE> ) {
		 while($mline =~ / ,/gi){
		    $mline =~ s/ ,/, /gi;
		 }
		 while($mline =~ / \./gi){
		    $mline =~ s/ \./\. /gi;
		 }
		 while($mline =~ / :/gi){
		    $mline =~ s/ :/: /gi;
		 }
		 while($mline =~ / ;/gi){
		    $mline =~ s/ ;/; /gi;
		 }
		 while($mline =~ / !/gi){
		    $mline =~ s/ !/! /gi;
		 }
		 while($mline =~ / \?/gi){
		    $mline =~ s/ \?/\? /gi;
		 }
		 while($mline =~ /  /gi){
		    $mline =~ s/  / /gi;
		 }
		 print FILE1 $mline;
            }
	close(FILE);
	close(FILE1);
	# copy corrected file back
 	  open(FILE, $pageName."~") or die "$!";
	  open(FILE1, ">".$pageName) or die "$!";
	         while ( $mline = <FILE> ) {
		 print FILE1 $mline;
            }
	close(FILE);
	close(FILE1);
	system("rm ".$tmpfile);
       }
       
       if($dobackup){
	  my $mline;
	  open(FILE, $pageName) or die "$!";
	  open(FILE1, ">".$tmpfile) or die "$!";
	         while ( $mline = <FILE> ) {
		 print FILE1 $mline;
            }
	close(FILE);
	close(FILE1);
        }
#        [Checkbutton => 'D~oubleSpaceFix', -variable=>\$doublespcfix],          
    }
}

# Add page to notebook metaphor
sub addPage {
    shift if UNIVERSAL::isa($_[0], 'TextSpellHighlight');
    my $pageName = shift;
#    print "addpage:",$pageName,"\n";

    # If the page exist, raise the old page and return
    foreach ( keys %pageName ) {
        if ( ($pageName{$_})->FileName() eq $pageName &&
              $pageName ne 'Untitled' ) {
            return $nb->raise($_);
        }
    }
    # make backup and fix double spaces
    # if requested
    doBackupSpcfix($pageName);
 
    # Add new page with 'random' name to the notebook
    my $name = rand();
    my $page = $nb->add($name,
                        -label => basename($pageName),
                        -raisecmd => \&pageChanged);

    # Create a widget with attached scrollbar(s)
    $tw = $page->Scrolled(qw/TextSpellHighlight
                            -spacing2 1 -spacing3 1
                            -scrollbars ose -background white
                            -borderwidth 2 -width 80 -height 25
                            -relief sunken/)->pack(qw/-expand 1 -fill both/);

    $tw->FileName($pageName);
    $pageName{$name} = $tw;
    
    $tw->bind('<FocusIn>', sub {
        $tw->tagRemove('MTCH', '0.0', 'end');
    });

    # Change popup menu to contain 'Edit' menu entry
    $tw->menu($edit->menu);
    mouseWheel($tw);

    if ( keys %pageName > 1 ) {
        # Enable 'File->Close' menu entry
        $file->cget(-menu)->entryconfigure(3 + ($Tk::platform eq 'unix'),
                                           -state => 'normal');
    }

    $nb->raise($name);

    # Write data to the new page. File 'Untitled' can
    # be used as a template for new script files!
    writeData($pageName);

    # Register callback function
    $tw->positionChangedCallback(\&updateStatus);
    
}

# Remove page and disable 'Close' menu item when needed
sub closeCommand {
    if ( confirmCh() ) {
        delete $pageName{$nb->raised()};
        $nb->delete($nb->raised());
    }
    if ( keys %pageName == 1 ) {
        # Disable 'File->Close' menu entry
        $file->cget(-menu)->entryconfigure(3 + ($Tk::platform eq 'unix'),
                                           -state => 'disabled');
    }
}

# Confirm the changes user has made before proceeding
sub confirmCh {
    if ( $nb->pagecget($nb->raised(), -label) =~ /\*/ ) {
        my $answer = $tw->Dialog(

                        -popover => $mw, -text => 'Save changes to '.
                         basename($tw->FileName()), -bitmap => 'warning',
                        -title => 'Ptkspell', -default_button => 'Yes',
                        -buttons => [qw/Yes No Cancel/])->Show;
        if ( $answer eq 'Yes' ) {
            saveDialog('s');
            return 0 if ( $nb->pagecget($nb->raised(), -label) =~ /\*/ ||
                          $tw->FileName() eq 'Untitled' );
        }
        elsif ( $answer eq 'Cancel' ) {
            return 0;
        }
    }
    return 1;
}

# Create Hierarchical List widget, which shows supported commands
# and a short description of each command


# Close all pages and quit T-Pad
sub exitCommand {
 #   test();
    while ( (my $pages = keys %pageName) > 0 ) {
        closeCommand();
        # Check if the user has pressed 'Cancel' button
        last if ( keys %pageName == $pages );
    }
    Save();
    exit if ( keys %pageName == 0 );
}



# Get the filename of the drop and add new page to the notebook metaphor
sub handleDND {
    my ($sel, $filename) = shift;

    # In case of an error, do the SelectionGet in an eval block
    eval {
        if ( $^O eq 'MSWin32' ) {
            $filename = $tw->SelectionGet(-selection => $sel, 'STRING');
        }
        else {
            $filename = $tw->SelectionGet(-selection => $sel, 'FILE_NAME');
        }
    };
    if ( defined $filename && -T $filename ) {
        addPage($filename);
    }
}

sub ClipCut {
   $tw->clipboardCut;
}
sub ClipCopy {
   $tw->clipboardCopy;
}
sub FindReplace{
   $tw->findandreplacepopup(0);
}
sub Find{
   $tw->findandreplacepopup(1);
}
sub Undo{
   $tw->undo;
}
sub Redo{
   $tw->redo;
}
sub GotoLine {
  $tw->GotoLineNumberPopUp();
}
# Handle different menu accelerator commands, which cannot be handled
# directly in menu entry (because of the tight bind of $tw)
sub menuCommands {
    my $cmd = shift;
    if    ( $cmd eq 'eu' ) { $tw->undo }
    elsif ( $cmd eq 'er' ) { $tw->redo }
    elsif ( $cmd eq 'et' ) { $tw->clipboardCut }
    elsif ( $cmd eq 'eo' ) { $tw->clipboardCopy }
    elsif ( $cmd eq 'ea' ) { $tw->clipboardPaste }
    elsif ( $cmd eq 'el' ) { $tw->selectAll }
    elsif ( $cmd eq 'ec' ) { $tw->unselectAll }
    elsif ( $cmd eq 'ef' ) { $tw->findandreplacepopup(1); }
    elsif ( $cmd eq 'ee' ) { $tw->findandreplacepopup(0); }
    elsif ( $cmd eq 'eg' ) { $tw->GotoLineNumberPopUp(); }
    elsif ( $cmd eq 'ew' ) { $tw->WhatLineNumberPopUp(); }
}

# Support for mouse wheel
sub mouseWheel {
    my $w = shift;

    # Windows support
    $w->bind('<MouseWheel>', [sub {
        $_[0]->yviewScroll(-($_[1]/120)*3, 'units');
    }, Tk::Ev('D')]);

    # UNIX support
    if ( $Tk::platform eq 'unix' ) {
        $w->bind('<4>', sub {
            $_[0]->yviewScroll(-3, 'units') unless $Tk::strictMotif;
        });
        $w->bind('<5>', sub {
            $_[0]->yviewScroll( 3, 'units') unless $Tk::strictMotif;
        });
    }
}

sub addFilelist {
 my $filename = shift;
# print "fn:",$filename,"\n";
 foreach( @filelist){
   if($_ eq $filename) {return;}
 }
  if($#filelist >= 3){
    shift @filelist;
  }
  push(@filelist, $filename); 
  $configChanged = 1;
# foreach( @filelist){
#   print $_,"\n";
# }
  
}

# Pop up a dialog box for the user to select a file to open
sub openDialog {
#	print "OpenDialog initdir:", $initialdir,"\n";
#	print Dumper(\@filetypes);
    my $filename = $mw->getOpenFile(-filetypes => \@filetypes, -initialdir => $initialdir);
    DoOpenFile($filename);
}

# Notebook page has changed, change the focus to the new page
# and initialise status bar to reflect page data
sub pageChanged {
    $tw = $pageName{$nb->raised()};

    $tw->focus if ( !defined $mw->focusCurrent ||
                    UNIVERSAL::isa($mw->focusCurrent, 'MainWindow') ||
                    UNIVERSAL::isa($mw->focusCurrent, 'TextSpellHighlight') );

    # Disable/Enable 'Misc->Properties' menu entry
    if ( -e $tw->FileName() ) {
        $misc->cget(-menu)->entryconfigure(0 + ($Tk::platform eq 'unix'),
                                           -state => 'active');
    }
    else {
        $misc->cget(-menu)->entryconfigure(0 + ($Tk::platform eq 'unix'),
                                           -state => 'disabled');
    }
    updateStatus();
}


# Create modal 'Properties' dialog
sub propertiesDialog {
    # Return if the file does not exist
    return unless ( -e $tw->FileName() );
    my $popup = $mw->Dialog(
        -popover => $mw,
        -title   => 'Source File Properties',
        -bitmap  => 'info',
        -default_button => 'OK',
        -buttons => ['OK'],
        -text    => "Name:\t".basename($tw->FileName()).
                "\nSize:\t".(stat($tw->FileName()))[7]." Bytes\n".
                "Saved:\t".localtime((stat($tw->FileName()))[9])."\n".
                "Mode:\t".sprintf("%04o", 07777&(stat($tw->FileName()))[2])
        );
    $popup->resizable('no', 'no');
    $popup->Show();
}


# Pop up a dialog box for the user to select a file to save
sub saveDialog {
    my $filename;
    shift if UNIVERSAL::isa($_[0], 'TextSpellHighlight');

    if ( $_[0] eq 's' && $tw->FileName() ne 'Untitled' ) {
        $filename = $tw->FileName();
    }
    else {
        $filename = $mw->getSaveFile(-filetypes => \@filetypes,
	                             -initialdir => $initialdir,
#                                     -initialfile => basename($tw->FileName()),
                                     -defaultextension => '.pl');
    }

    if ( defined $filename and $filename ne '' ) {
        if ( open(FILE, ">$filename") ) {
            # Write file to disk (change cursor to reflect this operation)
            $mw->Busy(-recurse => 1);
            my ($e_line) = split(/\./, $tw->index('end - 1 char'));
            foreach ( 1 .. $e_line-1 ) {
                print FILE $tw->get($_.'.0', $_.'.0 + 1 lines');
            }
            print FILE $tw->get($e_line.'.0', 'end - 1 char');
            $mw->Unbusy;
            close(FILE) or print "$!";
            $tw->FileName($filename);
            $nb->pageconfigure($nb->raised(), -label => basename($filename));
            $tw->numberChangesExt($tw->numberChanges);
            # Ensure 'File->Properties' menu entry is active
            $misc->cget(-menu)->entryconfigure(0 + ($Tk::platform eq 'unix'),
                                               -state => 'active');
        }
        else {
            my $msg = "File may be ReadOnly, or open for write by ".
                      "another application! Use 'Save As' to save ".
                      "as a different name.";
            $mw->Dialog(-popover => $mw, -text => $msg,
                        -bitmap => 'warning',
                        -title => 'Cannot save file',
                        -buttons => ['OK'])->Show;
        }
    }
}

# Update clock (without seconds) every minute
sub updateClock {
    ($clk = scalar localtime) =~ s/(\d+:\d+):(\d+)\s/$1 /;
     $mw->after((60-$2)*1000, \&updateClock);
}

# Update the statusbar
sub updateStatus {
    my ($cln, $ccol) = split(/\./, $tw->index('insert'));
    my ($lln) = split(/\./, $tw->index('end'));
    $st = "Line $cln (".($lln-1).'), Col.'.($ccol+1);

    my $title = $nb->pagecget($nb->raised(), -label);
    # Check do we need to add/remove '*' from title
    if ( $tw->numberChanges != $tw->numberChangesExt() ) {
        if ( $title !~ /\*/ ) {
            $title .= '*';
            $nb->pageconfigure($nb->raised(), -label => $title);
        }
    }
    elsif ( $title =~ /\*/ ) {
        $title =~ s/\*//;
        $nb->pageconfigure($nb->raised(), -label => $title);
    }
}

# Write data to text widget via read buffer
sub writeData {
    my $filename = $tw->FileName();

    if ( -e $filename ) {
        open(FILE, $filename) or die "$!";
        my $read_buffer;
        while ( <FILE> ) {
            s/\x0D?\x0A/\n/ if ( $crlf );
            $read_buffer .= $_;
            if ( ($.%100) == 0 ) {
                $tw->insertWHL('end', $read_buffer);
                undef $read_buffer;
            }
        }
        if ( $read_buffer ) {
            $tw->insertWHL('end', $read_buffer);
        }
        close(FILE) or die "$!";
       GramCheckSet();
       $misc->cget(-menu)->entryconfigure(3 + ($Tk::platform eq 'unix'),
                                           -state => 'disabled');
	if($gramchk == 1){
       $file->cget(-menu)->entryconfigure(0 + ($Tk::platform eq 'unix'),
                                           -state => 'disabled');
       $file->cget(-menu)->entryconfigure(1 + ($Tk::platform eq 'unix'),
                                           -state => 'disabled');
       $file->cget(-menu)->entryconfigure(2 + ($Tk::platform eq 'unix'),
                                           -state => 'disabled');
	}
    }

    $tw->ResetUndo;
    # Set cursor to the first line of text widget
    $tw->insertWHL('0.0');
    $tw->backgroundHL(1);
    $tw->focus();
}

sub SpellTest {
   my $wd = shift;
   my $ret;
   my $sor;
   my $new;
   my $i;
   my $ch;
   if($wd =~ m/([\+\-0-9])([0-9])+([\.\,])([0-9])+([\.\,])/gx) {return 1;}
    # no idea, why we have to recode the word ibto itself
    #
    for($i = 0; $i < length($wd); $i++){              
               $ch = substr($wd,$i,1);
               $new = $new.chr(ord($ch));
    }
    $wd = $new;

   $ret = $speller->check( $wd );
   return $ret;
}

sub cleanData {
	  my $data = shift;
	  my $i;
#	  hexdump($data);
	  for($i = 0; $i < 512; $i++){
	  	 substr($data, $i, 1) = "\0";
	  }
#	  hexdump($data);
	  return $data;
}

sub ErrorReport{
	print Win32::FormatMessage( Win32::GetLastError() );
}


sub TestGram {
  my ($ln, $col);
  my ($i, $ssor, $cstrt, $cstp, $str, $found);
  $ln = shift;
  $col = shift;
  $found = 0;
  for($i = 0; $i <= $#usorok; $i++){
   ($ssor, $cstrt, $cstp, $str) = split(/ /,$usorok[$i],4);
#   print "---",$usorok[$i],' ', $ssor,' ', $ln, ' ',$col,"\n";
#   print 'ss:',$ssor,' ln:',$ln,' col:', $col, ' cstrt:',$cstrt, ' cstp:', $cstp,"\n";
   if(($ssor == $ln) && ($col >= $cstrt) && ($col <= $cstp) ) {
     $found = 1;
     last;
   } elsif(($ssor == $ln) && ($cstp > $col)){
      last;
   } elsif($ssor > $ln){
      last;
   }
  }
   if($found){
      $info = $str;
      $mw->update();
      return 0;
   }
   else{
     return 1;
   }
}

sub Save {
  if($configChanged){
     WriteConfiguration();  # because of file list
  }
  if(-e $tmpwav){
     system("rm -rf ".$tmpwav);
  }
}


sub WriteConfiguration {
if(open(F,">".$rcfile)){
  print F "[Language]\n";
  print F $language,"\n";
  print F "\n";
  print F "[InitialDir]\n";
  print F $initialdir,"\n";
  print F "\n";
  print F "[Languagetool]\n";
  print F $languagetoolhome,"\n";
  print F "\n";
  print F "[LanguageUsed]\n";
  print F $languageused,"\n";
  print F "\n";
  print F "[MbrolaSound]\n";
  print F $MbrolaSound,"\n";
  print F "\n";
  print F "[Txt2PhoProc]\n";
  print F $txt2phoProc,"\n";
  print F "\n";
  print F "[DoubleWdCheck]\n";
  print F $doubleChk,"\n";
  print F "\n";
  print F "[AfterDotCheck]\n";
  print F $dotlcChk,"\n";
  print F "\n";
  print F "[Backupfile]\n";
  print F $dobackup,"\n";
  print F "\n";
  print F "[DoubleSpaceFix]\n";
  print F $doublespcfix,"\n";
  print F "\n";
  print F "[SimplifiedGrammarCheck]\n";
  print F $simpgramchk,"\n";
  print F "\n";
  if($#filelist  >= 0){
   print F "[FileList]\n";
   foreach( @filelist){
    if(length($_) > 3){
       print F $_,"\n";
    }
   }
   print F "\n";
  }
  close(F);
}
}


sub configure{
#print "ccc\n";
    my $button;
    my $done = 0;
    my ($res1, $res2, $res21, $res3, $res4, $res5, $res6);
    my ($oldlang, $oldmbrolasound, $oldtxt2phoproc, $oldlanguagetool, $oldlanguageused, $oldinitialdir);
    $oldlang = $language;
    $oldmbrolasound = $MbrolaSound;
    $oldtxt2phoproc = $txt2phoProc;
    $oldlanguagetool = $languagetoolhome;
    $oldlanguageused = $languageused;
    $oldinitialdir = $initialdir;
    
    do {    
        # show the dialog
        $button = $dialog->Show;

        # act based on what button they pushed
        if ($button eq "Configure") {
             $res1  = ValLangServer();
             $res2  = ValLanguage();
             $res21 = ValLanguageUsed();
             $res3  = ValMbrolaSound();
             $res4  = Valtxt2phoProc();
	     $res5  = ValLanguagetool();
	     $res6  = ValLanguageUsed();
	   if(!$res1 || !$res2 || !$res3 || !$res4 || !$res5 || !$res6){
	   } else {
	      if($oldlang ne $language){
	        StartSpellServer();
#               InitLanguage();
	      } 
#             print "you entered:",$WorkDirName, $MbrolaSound, $txt2phoProc, "\n";
            if($oldlang ne $language || 
             $oldmbrolasound ne $MbrolaSound ||
             $oldtxt2phoproc ne $txt2phoProc ||
             $oldlanguageused ne $languageused ||
             $oldinitialdir ne $initialdir ||
             $oldlanguagetool ne $languagetoolhome){ 
	     WriteConfiguration();
	     }
	     $done = 1;
	  }
	 } else {
           $fr =  "Configuration aborted";
           $done = 1;
        }
    } until $done;

}

sub Mbrplay {
  if(ValMbrolaSound() && Valtxt2phoProc()){
   open (F, ">/tmp/szoveg.txt") || die "Can't open szoveg.txt";
   print F $tw->getSelected();
   close(F);
   system("sh ".$txt2phoProc." /tmp/szoveg.txt ");
   system("mbrola ".$MbrolaSound." /tmp/x.pho ".$tmpwav); 
   system($playit." ".$tmpwav." &"); 
   system("rm -f /tmp/x1.txt");
   system("rm -f /tmp/x.pho");
   } else{
    $info = "Please configure mbrola first";
   }
}
sub Replay {
  system($playit." ".$tmpwav." &"); 
}

__END__

=head1 NAME

Ptkspell - A Perl/Tk GUI based Perl-script editor with syntax highlighting

=head1 SYNOPSIS

perl B<ptkspell.pl> [I<file(s)-to-edit>]

=head1 DESCRIPTION

Ptkspell is a Perl/Tk GUI based text editor with syntax highlight, grammar check and support of text-to-speech. Ptkspell supports spell  highlight for *.txt-files. Ptkspell support searching for suggestions for erroneous words. Usage: mark the erroneous(red) word with the cursor. When you click onto the combo box's selection button in the status line, the suggested words will be shown. If you select one of them, the erroneous word will be replaced with your selection. 
When you select grammar check, after doing it the grammar check selection button is disabled. You must leave ptkspell and reenter it to do spell checking again.

=head1 README

A Perl/Tk GUI based Perl-script editor with spell highlighting (*.txt), Grammar check and text-to-speech facility. Ptkspell runs under Windows, Unix and Linux.

=head1 PREREQUISITES

This script requires the C<Tk> a graphical user interface toolkit module for Perl.
In order to be able to use spellchecking, you must to copy you language(s) affix and dic files onto your computer.
If you want to use the text-to-speech facility, you must install the mbrola speech synthesizer and the voice(s) for the language(s) you need. 
If you want to use the grammar checking tool, you must install Daniel Naber's languagetool from http://tkltrans.sf.net.
You must tell the locations of the above files and the used language using the menu misc/configure. 

=head1 AUTHOR

Eleonora <F<eleonora46@gmx.net>>

=head1 COPYRIGHT

Copyright (c) 2005, Eleonora. All rights reserved.
This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=pod SCRIPT CATEGORIES

Win32
Win32/Utilities

=cut
