#!/usr/bin/perl

use strict;
use warnings;
use vars qw(@par $img_small);
use constant SCRIPT => './build/script/jpgresize';
@par=qw(-W 400 -H 300 -r -e _small ./t/check.jpg);
use Test::Simple tests => 3;

system(SCRIPT,@par);
if ($? != 0) {
	ok(0,"I can't execute ".SCRIPT.". Error Code: ".$? >> 8);
} else {
	ok(1,"I executed the command ".SCRIPT." ".join(" ",@par));
}
use Image::Resize;
eval{$img_small = Image::Resize->new("./t/check_small.jpg")};
if ($@) {
	ok(0, $@);
} else {
	ok(1, "I will check the dimension of check_small.jpg");
}
if ($img_small->width() == 400 && $img_small->height() == 300) {
	ok(1, "dimension ok!");
} else {
	ok(0, "your version of jpgresize did something strange with check.jpg. I estimate an other dimension.");
}

