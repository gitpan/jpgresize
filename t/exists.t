#!/usr/bin/perl

use strict;
use warnings;
use vars qw(@Makefilelines %Installpaths %Options &exists_script 
	$HomeDir $Tests $Version_new $Version_old &get_version_from_file);
use constant SCRIPT => 'jpgresize';

print "This test will check, if you already have installed ".SCRIPT."\n";

BEGIN{
	my $fh;
	my $convert = sub {
		foreach (@_) {
			chomp;
			s/\~\//$HomeDir\//;
		}
		return @_;
	};
	my $split_key_value = sub {
		my @rvalue;
		foreach (@_) {
			push(@rvalue,split(/ = /,$_,2));
		}
		return @rvalue;
	};
	$HomeDir = $ENV{HOME}; # Home directory
	
	# Get Makefile 
	open ($fh,"<./Makefile") || die "Can't open ./Makefile";
	@Makefilelines=$convert->(grep /^\w+ = /,<$fh>);
	close ($fh);
	
	# Get Makefile Options
	%Options=$split_key_value->(@Makefilelines);

	# Where can I find a previous version?
	%Installpaths = (
		INSTALLBIN => 1,
		DESTINSTALLBIN => 1,
		INSTALLSITEBIN => 1,
		DESTINSTALLSITEBIN => 1,
		INSTALLVENDORBIN => 1,
		DESTINSTALLVENDORBIN => 1,
		INSTALLSCRIPT => 1,  
		DESTINSTALLSCRIPT => 1, 
		INSTALLSITESCRIPT => 1, 
		DESTINSTALLSITESCRIPT => 1, 
		INSTALLVENDORSCRIPT => 1, 
		DESTINSTALLVENDORSCRIPT => 1 
	);
	my %pathstmp;
	$Tests=0;
	foreach (@Makefilelines) {
		chomp;
		my ($key, $value) = $split_key_value->($_);
		next unless ($Installpaths{$key});
		if ($value =~ /\$/) {
			$value =~ s/\$\((\w+)\)/\$Options\{$1\}/g;
			eval '$value="'.$value.'"';
			if ($@) {
			    die "Error while trying eval '$value=".'"'."'".$value.
					"'".'"'."'";
			}
		}
		$value =~ s/\/+/\//g;
		unless (exists $pathstmp{$value}) {
			$Installpaths{$key}=$value;
			$pathstmp{$value}=1;
			$Tests++;
		} else {
			$Installpaths{$key}=0;
		}
	}
}	
use Test::Simple tests => $Tests;
# Get Versions
if (defined $Options{VERSION} && $Options{VERSION} ne '') {
	$Version_new = $Options{VERSION}
} 
if ($Version_new !~ /\w/ && defined $Options{VERSION_FROM} && $Options{VERSION_FROM} ne '') {
	$Version_new = get_version_from_file($Options{VERSION_FROM});
}
if ($Version_new !~ /\w/) {
	die "Can't find the VERSION of ".SCRIPT."\n";
}

foreach my $value (keys %Installpaths) {
	next unless($Installpaths{$value});
	my $exists_rvalue=0;
	if($exists_rvalue=exists_script($Installpaths{$value})) {
		if ($exists_rvalue == 1) {
			ok(1, SCRIPT." already exists in the directory ".$Installpaths{$value}.". The versions compare, it is not neccessary to install ".SCRIPT." again");
		} elsif ($exists_rvalue == 2) {
			ok(1, SCRIPT." already exists in the directory ".$Installpaths{$value}." but you have a newer testversion. I will overwrite the old one.");
		} elsif ($exists_rvalue == 3) {
			ok(0, SCRIPT." already exists in the directory ".$Installpaths{$value}." and the testversion is newer. You should not overwrite it with an old testversion.");
		} elsif ($exists_rvalue == 4) {
			ok(0, SCRIPT." already exists in the directory ".$Installpaths{$value}." and it seems, that it is more tested than the new one. Do you really want to overwrite it with a newer and less tested version?");
		} elsif ($exists_rvalue == 5) {
			ok(1, SCRIPT." already exists in the directory ".$Installpaths{$value}." but you have a newer version. I will overwrite the old one.");
		} elsif ($exists_rvalue == 6) {
			ok(0, SCRIPT." already exists in the directory ".$Installpaths{$value}." and the version is newer. You should not overwrite it with an old version.");
		} else {
			ok(0, SCRIPT." already exists in the directory ".$Installpaths{$value});
		}
	} else {
		ok(1, "Nothing found in ".$Installpaths{$value});
	}
}
sub get_version_from_file {
	my $file=shift;
	my ($fh, $line);
	open($fh,"<".$file) || 
		die "Can't open ".$file;
	while (($line =<$fh>) !~ /(?:[\$*])(?:(?:[\w\:\']*)\bVERSION)\b.*\= *([\'\"])?(?:.+?)\1?\;/) {}
	close($fh);
	chomp($line);
	$line =~ s/(?:[\$*])(?:(?:[\w\:\']*)\bVERSION)\b.*\= *([\'\"])?(.+?)\1?\;/$2/; 
	return $line;
}

# Return Value
# 0 Script doesn't exists
# 1 Script exists and the versions compare
# 2 Script exists and it is an older testversion
# 3 Script exists and it is an newer testversion
# 4 An older version of the Script exists, but its testversionlevel is higher
# 5 Script exists and the version is older
# 6 Script exists and the version is newer
# 7 Script exists and I was not able to compare the versions
sub exists_script {
	my $path = shift;
	my $get_version_number = sub {
		my $Version_string = shift;
		my ($version,$ext);
		$Version_string =~ /^(\d+(?:\.\d+)*)(.*)$/;
		($version,$ext)=($1,$2);
		$ext='' if ($ext =~ /^\s+$/);
		return ($version,$ext);
	};
	my $get_testversion_number = sub {
		my $ext = shift;
		my @testversions=qw(alpha beta gamma);
		my $level = 4;
		if ($ext ne '') {
			do {
				$level--;
			} until ($level == 0 || $ext =~ /$testversions[3-$level]/)
		}
		return $level;
	};
	my $compare = sub {
		my $value1 = shift;
		my $value2 = shift;
		my $equation = shift;
		my $rvalue=-1;
		my (@value1,@value2,$value1_max,$value2_max,$comp);
		$value1_max=(@value1=split(/\./,$value1));
		$value2_max=(@value2=split(/\./,$value2));
		for(my $i=0;$i<$value1_max && $i<$value2_max;$i++) {
			next if ($value1[$i] == $value2[$i]);
			eval '$rvalue=('.$value1[$i].$equation.$value2[$i].')?1:0;';
			if ($@) {
			    die "Error while trying eval '".'$rvalue=('.$value1[$i].$equation.$value2[$i]."')?1:0;'";
			}
		}
		if ($rvalue == -1) {
			eval '$rvalue=('.$value1_max.$equation.$value2_max.')?1:0;';
			if ($@) {
			    die "Error while trying eval '".'$rvalue('.$value1_max.$equation.$value2_max."')?1:0;'";
			}
		}
		return $rvalue;
	};
	my ($testversion_old, $testversion_new);
	if (-e $path."/".SCRIPT) {
		$Version_old = get_version_from_file($path."/".SCRIPT);
		return 1 if ($Version_new eq $Version_old);
		my ($version_old_nr,$version_new_nr,$version_old_ext,$version_new_ext);
		($version_old_nr,$version_old_ext) = 
			$get_version_number->($Version_old);
		($version_new_nr,$version_new_ext) = 
			$get_version_number->($Version_new);
		return 7 if (($version_old_nr !~ /^\d+(?:\.\d+)*$/) ||
			($version_new_nr !~ /^\d+(?:\.\d+)*$/));
		$testversion_old=
			$get_testversion_number->($version_old_ext);
		$testversion_new=
			$get_testversion_number->($version_new_ext);
		return 7 unless ($testversion_old && $testversion_new);
		if ($compare->($version_old_nr,$version_new_nr,'==')) {
			return 2 if ($testversion_old < $testversion_new);
			return 3 if ($testversion_old > $testversion_new);
			return 1;
		}
		if ($compare->($version_old_nr,$version_new_nr,'<')) {
			if ($testversion_old > $testversion_new) {
				return 4;
			} else {
				return 5;
			}
		}
		return 6 if ($compare->($version_old_nr,$version_new_nr,'>'));
	} else {
		return 0;
	}
}

