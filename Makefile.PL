use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $_swap_vers = 'find $(DISTVNAME) -type f -exec egrep -q ___EUMM_VERSION___ {} \; -exec sed -i "s/___EUMM_VERSION___/Build V$(VERSION)/" {} \; -print ;' .
'perldoc -uT $(DISTVNAME)/$(VERSION_FROM) > README.pod';

WriteMakefile(
    NAME              => 'Batch::Exec::Path',
    VERSION_FROM      => 'lib/Batch/Exec/Path.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
	'Batch::Exec' => '0',
	'Carp' => '0',
	'Data::Dumper' => '0',
	'File::HomeDir' => '0',
	'Log::Log4perl' => '0',
	'Logfer' => '0',
	'Parse::Lex' => '0',
	'Path::Tiny' => '0',
}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/Batch/Exec/Path.pm', # retrieve abstract from module
    dist              => { PREOP => $_swap_vers, },
    AUTHOR            => 'TMCMEEKI  <tmcmeeki@cpan.org>',
    LICENSE           => 'gpl_3',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);
