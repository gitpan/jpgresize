use ExtUtils::MakeMaker;

require 5.6.0;

WriteMakefile(
    'NAME'	=> 'jpgresize',
    'VERSION_FROM' => './jpgresize', # VERSION
    'dist'  => { COMPRESS => 'gzip', SUFFIX => 'gz' },
    'EXE_FILES' => [ './jpgresize' ], # scripts to install
    'PREREQ_PM' => { 'Getopt::Long' => '2.37', 'GD' => '2.41', 
		'Image::Resize' => '0.5'}, # required Perl Modules
	'AUTHOR' => 'Florian Goslich (flo@goslich-online.de)',
	'INST_ARCHLIB' => './build/arch',
	'INST_LIB' => './build/lib',
	'INST_BIN' => './build/bin',
	'INST_MAN1DIR' => './build/man1',
	'INST_MAN3DIR' => './build/man3',
	'INST_SCRIPT' => './build/script',
#	'DESTDIR' => '~/perl/test/'
);

