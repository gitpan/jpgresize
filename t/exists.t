#!/usr/bin/perl

use strict;
use warnings;
use Config;
use vars qw(@Testversions @Installpaths %Options &exists_script $Tests
	$HomeDir $Version_new $Version_old &get_version_from_file);
use constant SCRIPT => 'jpgresize';
# Testversions order (better tested versions first)
@Testversions=qw(beta alpha pre-alpha);

print "This test will check, if you already have installed ".SCRIPT."\n";

BEGIN{
	my $fh;
	my $convert = sub {
		foreach (@_) {
			s/\~\//$HomeDir\//;
		}
		return @_;
	};
	my $chompconvert = sub {
		my @return;
		foreach (@_) {
			chomp;
			push(@return,$convert->($_));
		}
		return @return;
	};
	my $split_key_value = sub {
		my @rvalue;
		foreach (@_) {
			push(@rvalue,split(/ = /,$_,2));
		}
		return @rvalue;
	};
	my %pathstmp;
	my $addtopaths = sub {
		my $value = shift; 
		unless (exists $pathstmp{$value} || $value =~ /^\s*$/) {
			push(@Installpaths,$value);
			$pathstmp{$value}=1;
		}
	};
	$HomeDir = $ENV{HOME}; # Home directory
	
	# Get Makefile 
	open ($fh,"<./Makefile") || die "Can't open ./Makefile";
	my @makefilelines=$chompconvert->(grep /^\w+ = /,<$fh>);
	close ($fh);
	
	# Get Makefile Options
	%Options=$split_key_value->(@makefilelines);

	# Where can I find a previous version?
	my %makefileinstallpaths = (
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
	my %configinstallpaths = (
		bin => 1,
		sitebin => 1,
		vendorbin => 1,
		scriptdir => 1
	);
	foreach (@makefilelines) {
		my ($key, $value) = $split_key_value->($_);
		next if (!$makefileinstallpaths{$key});
		if ($value =~ /\$/) {
			$value =~ s/\$\((\w+)\)/\$Options\{$1\}/g;
			eval '$value="'.$value.'"';
			if ($@) {
			    die "Error while trying eval '$value=".'"'."'".$value.
					"'".'"'."'";
			}
		}
		$value =~ s/\/+/\//g;
		$addtopaths->($value);
	}
	foreach (keys %configinstallpaths) {
		next unless ($configinstallpaths{$_} && exists $Config{$_} 
			&& defined $Config{$_});
		$addtopaths->($convert->($Config{$_}));
	}
	$Tests = @Installpaths;
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

foreach my $value (@Installpaths) {
	my $exists_rvalue=0;
	if($exists_rvalue=exists_script($value)) {
		if ($exists_rvalue == 1) {
			ok(1, SCRIPT." already exists in the directory ".$value.". The versions compare, it is not neccessary to install ".SCRIPT." again");
		} elsif ($exists_rvalue == 2) {
			ok(1, SCRIPT." already exists in the directory ".$value." but the testlevel of your version is higher. You should install the new one.");
		} elsif ($exists_rvalue == 3) {
			ok(0, SCRIPT." already exists in the directory ".$value." and its testlevel is higher. You should not install a version with a lower testlevel.");
		} elsif ($exists_rvalue == 4) {
			ok(0, SCRIPT." already exists in the directory ".$value." and it seems, that it is more tested than the new one. Do you really want to install a newer and less tested version?");
		} elsif ($exists_rvalue == 5) {
			ok(1, SCRIPT." already exists in the directory ".$value." but you have a newer version. You should install the new one.");
		} elsif ($exists_rvalue == 6) {
			ok(0, SCRIPT." already exists in the directory ".$value." and the version is newer. You should not install an old version.");
		} else {
			ok(0, SCRIPT." already exists in the directory ".$value);
		}
	} else {
		ok(1, "Nothing found in ".$value);
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
# 2 Script exists and it is an older testversion (versions need not compare)
# 3 Script exists and it is an newer testversion (versions compare)
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
		my $level = @Testversions+1;
		if ($ext ne '') {
			do {
				$level--;
			} until ($level == 0 || $ext =~ /^[\s\-]?$Testversions[3-$level]$/)
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
		if ($compare->($version_old_nr,$version_new_nr,'>')) {
			if ($testversion_old < $testversion_new) {
				return 2;
			} else {
				return 6;
			}
		}
	} else {
		return 0;
	}
}

