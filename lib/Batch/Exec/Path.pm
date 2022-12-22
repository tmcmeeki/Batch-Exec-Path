package Batch::Exec::Path;

=head1 NAME

Batch::Exec::Path cross-platform path handling for the batch executive.

=head1 AUTHOR

Copyright (C) 2022  B<Tom McMeekin> tmcmeeki@cpan.org

=head1 SYNOPSIS

  use Batch::Exec::Path;


=head1 DESCRIPTION

Pathname parser for cross-platform contexts, particularly catering to hybrid
or virtualised environments.  Specifically this class provides support for: 
Windows, Linux, Cygwin and WSL platforms, where the latter two are
adaptations of Linux which run hybrid on Windows and have idiosyncrasies around
how host filesystems are mounted.

In addition, UNC paths are supported, particularly given the lack of support 
for this format in modules deployed to CPAN.

Some notes around how particular platforms present directories:

	WSL root directory \\wsl$\Ubuntu	(from Windows)

	Windows system drive /mnt/c		(from WSL)

	WSL user directory \\wsl$\Ubuntu\home\userwsl	(from Windows)

	Windows user directory /mnt/c/Users/userwin	(from WSL)

	Windows user directory C:\Users\userwin	(from Windows)

	Cygwin mounts under /cygdrive 		(from Cygwin)

	Conventional user directories under /home	(Linux-like)

Note that the username in hybrid deployments may not relate to that of the 
host platform, so this can be challenging for establishing a user's "home"
directory.  In addition, conventions above can be overridden by administrators.

Network fileshares are parsed according to protocol conventions, e.g.

	SMB / CIFS	//server/share	(Linux-like platforms)
	SMB / CIFS	\\server\share	(Windows)
	NFS		server:/share	(all platforms)

Currently the NFS convention is only supported for symbolic hostnames
(as opposed to IP addresses).

=head2 ATTRIBUTES

=over 4

=item OBJ->abs

Boolean which indicates an absolute path.
Reinitialised and conditionally set by the B<parse> method.
No default applies.
Subsequently utilised by the B<joiner> method.

=item OBJ->behaviour

Set or get the path rendering behaviour to one of "w" (Windows-like) or
"u" (Unix-like).
A platform-dependent default applies.

=item OBJ->deu

=item OBJ->dew

The component delimeters for a pathname, respectively forward-slash for unices
and backslash for MSWin platforms.
Both get or set operations for which defaults apply.
See the correlating attribute B<reu>.

=item OBJ->drive

Boolean which indicates an absolute path.
Reinitialised and conditionally set by the B<parse> method.
No default applies.
Subsequently utilised by the B<joiner> method.

=item OBJ->folders

The list of folders in a local filesystem hierarchy.
Reinitialised and conditionally set by the B<parse> method.
Defaults to an empty array.
Subsequently utilised by the B<joiner> method.

=item OBJ->reu

=item OBJ->rew

The regular expressions which separate components of a pathname,
respectively for unices and MSWin platforms.
Both get or set operations for which defaults apply.
See the correlating attribute B<deu>.

=item OBJ->shellify(BOOLEAN)

Useful when converting paths for shell-calls to Windows-like interpreters
backslashes are appropriately delimeted, e.g. \ becomes \\.
Default is 0 (off = do not shellify).

=item OBJ->volumes

The list of components comprising an addressable local or networked filesytem.
Reinitialised and conditionally set by the B<parse> method.
Defaults to an empty array.
Subsequently utilised by the B<joiner> method.

=back

=cut

use strict;

use parent 'Batch::Exec';

# --- includes ---
use Carp qw(cluck confess);
use Data::Dumper;

#use File::Spec;
#use Logfer qw/ :all /;
#use File::Spec::Unix qw/ :ALL /;
#require File::Spec::Win32;
require File::HomeDir;
#require Path::Class;
require Path::Tiny;
use Parse::Lex;

#use Log::Log4perl qw(:levels);	# debugging


# --- package constants ---
use constant ENV_WSL_DISTRO => $ENV{'WSL_DISTRO_NAME'};

use constant DN_MOUNT_WSL => "mnt";
use constant DN_MOUNT_CYG => "cygdrive";

use constant DN_ROOT_ALL => '/';	# the default root
use constant DN_ROOT_WSL => 'wsl$';	# this is a WSL location only
					# e.g. \\wsl$\Ubuntu\home (from DOS)
use constant FN_HOME => "home";

use constant RE_DELIM_U => qr[\/];	# the forward-slash regexp for unix
use constant RE_DELIM_W => qr[\\];	# the back-slash regexp for windows
use constant RE_SHELLIFY => qr=[\s\$\\\/\']=;	# norty characters for shells

use constant STR_DELIM_U => '/';	# the forward-slash for unix
use constant STR_DELIM_W => '\\';	# the back-slash for windows
use constant STR_PREMATURE => "FATAL method called prematurely; have you called parse() method";			# error message for method ordering
use constant STR_UNKNOWN => "_unknown_";



# --- package globals ---
our $AUTOLOAD;
#our @EXPORT = qw();
#our @ISA = qw(Exporter);
our @ISA;
our $VERSION = '0.001';


# --- package locals ---
#my $_n_objects = 0;

my %_attribute = (	# _attributes are restricted; no direct get/set
	_home => undef,		# a reliable version of user's home directory
	_lexer => undef,
	abs => undef,
	behaviour => undef,	# platform-dependent default, one of: w, u.
	deu => STR_DELIM_U,
	dew => STR_DELIM_W,
	drive => undef,
	folders => [],
	homed => undef,
	hybrid => undef,
	letter => undef,
	mount => undef,
	msg => STR_PREMATURE,
	raw => undef,		# the raw path passed into a parse function
	res => RE_SHELLIFY,
	reu => RE_DELIM_U,
	rew => RE_DELIM_W,
	root => undef,		# placeholder for root component
	server => undef,
	shellify => 0,		# converts \ to \\ for DOS-like shell exits
	type => undef,
	unc => undef,
	unknown => STR_UNKNOWN,	# stringy failsafe
	volumes => [],
);

#sub INIT { };

sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $attr = $AUTOLOAD;
	$attr =~ s/.*://;   # strip fully−qualified portion

	confess "FATAL older attribute model"
		if (exists $self->{'_permitted'} || !exists $self->{'_have'});

	confess "FATAL no attribute [$attr] in class [$type]"
		unless (exists $self->{'_have'}->{$attr} && $self->{'_have'}->{$attr});
	if (@_) {
		return $self->{$attr} = shift;
	} else {
		return $self->{$attr};
	}
}


sub DESTROY {
#	local($., $@, $!, $^E, $?);
	my $self = shift;

#	$self->SUPER::DESTROY;
}


sub new {
	my ($class) = shift;
	my %args = @_;	# parameters passed via a hash structure

	my $self = $class->SUPER::new;	# for sub-class
	my %attr = ('_have' => { map{$_ => ($_ =~ /^_/) ? 0 : 1 } keys(%_attribute) }, %_attribute);

	bless ($self, $class);

	while (my ($attr, $dfl) = each %attr) { 

		unless (exists $self->{$attr} || $attr eq '_have') {
			$self->{$attr} = $dfl;
			$self->{'_have'}->{$attr} = $attr{'_have'}->{$attr};
		}
	}
#	$self->{'_id'} = ++${ $self->{'_n_objects'} };
#	$self->{'_id'} = ++$_n_objects;
	$self->behaviour(($self->on_windows) ? "w" : "u");
	$self->home;
	if ($self->on_cygwin) {

		$self->mount(DN_MOUNT_CYG);

	} elsif ($self->on_wsl) {

		$self->mount(DN_MOUNT_WSL);

	} else {
		$self->mount(DN_ROOT_ALL);
	}
	while (my ($method, $value) = each %args) {

		confess "SYNTAX new(, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	return $self;
}

=head2 METHODS

=over 4

=item OBJ->connector

Return the connector string relevant to the specified behaviour.
This is the correlating method to B<separator>.

=cut

sub connector {
	my $self = shift;

	return $self->deu if ($self->behaviour eq 'u' || $self->type eq 'nfs');

	return $self->dew;
}

=item OBJ->default(ATTRIBUTE, VALUE)

Default the attribute to the value.  Defaulting only sets the value if it
hasn't already been set.

=cut

sub default {
	my $self = shift;
	my $prop = shift;
	my $value = shift;
	confess "SYNTAX default(EXPR, EXPR)" unless (
		defined($prop) && defined($value));

	$self->cough("attribute [$prop] does not exist")
		unless (exists $self->{$prop});

	return $self->{$prop}
		unless (defined $value);

	return $self->{$prop}
		if (defined $self->{$prop});

	$self->log->debug("prop [$prop] value [$value]");

	$self->{$prop} = $value;

	return $value;
}

=item OBJ->drive_letter(EXPR)

Assign a letter and a drive name based on EXPR, trimming any trailing special
character from the end of the string if necessary.
The letter is a stripped version of a drive; a drive could be "C:" or "C$"
so the letter in either case is "C".
If you are running on Windows, append the colon if it is missing.

=cut

sub drive_letter {
	my $self = shift;
	my $str = shift;
	confess "SYNTAX drive_letter(EXPR)" unless defined($str);
#	$self->log->logconfess($self->msg) unless defined($self->type);

	my $drive = $str;

	unless ($drive =~ /\$$/) {	# special drive '$'
#		$drive .= ":" if ($self->on_windows && ! $drive =~ /:$/);
		$drive .= ":" unless ($drive =~ /:$/);
	}

	my $letter = $str;

	$self->log->debug(sprintf "letter [$letter] on_windows [%d]", $self->on_windows);

#	$letter =~ s/[:\$]$//;
	$letter =~ s/:$//;	# a trailing $ is important; do not strip

#	if ($self->on_linux && ! $self->on_wsl) {
#		$drive = $self->unknown;
#		$letter = $self->unknown;
#	}
	$self->log->debug("drive [$drive] letter [$letter]");

	$self->drive($drive);
	$self->letter($letter);

	return $letter;
}

=item OBJ->extant(PATH, [TYPE])

Checks if the file specified by PATH exists. Subject to fatal processing.

=cut

sub extant {
	my $self = shift;
	my $pn = shift;
	my $type = shift; $type = 'f' unless defined($type);
	confess "SYNTAX extant(EXPR)" unless defined($pn);

	return $self->SUPER::extant($pn, $type);
}

=item OBJ->home

Read-only method advises a generally failsafe home directory for user.

=cut

sub home {
	my $self = shift;

	my $dn; if (@_) {

		$dn = shift;

		$self->{'_home'} = $dn;
	}
	if (defined $self->{'_home'}) {

		$dn = $self->{'_home'};
	} else {
		my $env = ($self->on_windows) ? $ENV{'USERPROFILE'} : $ENV{'HOME'};
		$dn = ($env eq '') ? File::HomeDir->my_home : $env;

		$self->{'_home'} = $dn;
	}
	return $dn;
}

=item OBJ->is_known(EXPR)

Check if the EXPR is "known", i.e. something other than the value referred to
by the B<unknown> method.

=cut

sub is_known {
	my $self = shift;
	my $expr = shift;
	confess "SYNTAX is_known(EXPR)" unless defined($expr);

	return 0 if ($expr eq $self->unknown);

	return 1;
}

=item OBJ->joiner

Joins components together into a pathname.  This method assumes that 
the B<parse> method has already been called.

=cut

sub joiner {
	my $self = shift;
	$self->log->logconfess($self->msg) unless ( defined($self->type)
		&& defined($self->abs)
		&& defined($self->unc)
	);
	$self->log->debug(sprintf "abs [%d]", $self->abs);
	$self->log->debug(sprintf "type [%s] unc [%s]", $self->type, $self->unc);
	my @parts;

	if ($self->unc || $self->type eq 'wsl') {  # file-share or WSL format

		push @parts, undef;

		push @parts, $self->server if (defined($self->server));

		push @parts, @{ $self->volumes };

	} elsif ($self->type eq 'nfs') {

		push @parts, $self->server . ':';

	} elsif ($self->type eq 'win') {# && $self->behaviour eq 'w') {

		push @parts, $self->drive;

	} else {		# local format (no server component)

		push @parts, undef if ($self->abs);

		push @parts, @{ $self->volumes };
	}

	push @parts, @{ $self->folders };

	$self->log->debug(sprintf "parts [%s]", Dumper(\@parts));

	for (my $ss = 0; $ss < @parts; $ss++) {

		$parts[$ss] = $self->connector
			unless(defined $parts[$ss]);
	}
	$self->log->debug(sprintf "parts [%s]", Dumper(\@parts));

	my $pn = join($self->connector, @parts);

	unless (defined $self->server || $self->type eq 'wsl') {

		my $re = $self->separator;

		$pn =~ s/^$re// if ($pn =~ /^$re$re/);
	}

	$self->log->debug("pn [$pn]");

	return $pn;
}

=item OBJ->dump_struct

Dump debugging information about the current structure.

=cut

sub dump_struct {
	my $self = shift;

	my $null = '(undef)';

	$self->log->debug(sprintf "DDD drive [%s]", (defined $self->drive) ? $self->drive : $null);
	$self->log->debug(sprintf "FFF folders [%s]", Dumper($self->folders));
	$self->log->debug(sprintf "HHH homed [%s]", (defined $self->homed) ? $self->homed : $null);
	$self->log->debug(sprintf "SSS server [%s]", (defined $self->server) ? $self->server : $null);
	$self->log->debug(sprintf "VVV volumes [%s]", Dumper($self->volumes));
}

=item OBJ->lexer

Create and return a lexer object with a path parsing text.  Only one parser
is maintained for the object, and is re-used on subsequent calls (which will
also handle a reset of the parser).

=cut

sub lexer {
	my $self = shift;
	my $lexer; if (defined $self->{'_lexer'}) {

		$lexer = $self->{'_lexer'};

		$lexer->reset;
		$lexer->end('cyg');
		$lexer->end('share');
		$lexer->end('unchost');
		$lexer->end('wsl');

		return $lexer;
	}
	my @token = (
	qw(cyg:CYG_DRIVE	\w), sub {

		$lexer->end('cyg');

		my $drive = $_[1];

		push @{ $self->volumes }, $drive;

		$self->drive_letter($drive);

		$drive;
	},
	qw{wsl:WSL_DISTRO  [\s\d\w]+}, sub {

		$lexer->end('wsl');

		push @{ $self->volumes }, $_[1];

		$_[1];
  	},
	qw{unchost:WSL_ROOT  [Ww][Ss][Ll]\$}, sub {

		$lexer->end('unchost');
		$lexer->start('wsl');

		$self->hybrid(1);
		$self->type("wsl");
		$self->unc(0);

		push @{ $self->volumes }, $_[1];

		$_[1];
  	},
	qw(share:NET_SHARE  [\w\d\-\_]+\$?), sub {

		$lexer->end('unchost');
		$lexer->end('share');

		my $folder = $_[1];

		push @{ $self->volumes }, $folder;

		$self->dump_struct;
		$folder;
  	},
	qw(unchost:UNC_HOST  [\w\d\-\_]+), sub {

		my $host = $_[1];

		$self->server($host);

		$lexer->start('share');

		$self->dump_struct;
		$host;
  	},
	"NET_PREFIX_L", "\/\/", sub {  

		$self->default('abs', 1);
		$self->default('type', "lux");
		$self->default('unc', 1);

		$lexer->start('unchost');
		$_[1];
	},
#	qw(NET_PREFIX_W	\\{2}), sub {  
	qw(NET_PREFIX_W \x5c{2}), sub {  	# \x5c = win backslash

		$self->default('abs', 1);
		$self->default('type', "win");
		$self->default('unc', 1);

		$lexer->start('unchost');

		$_[1];
	},
	qw(PATHSEP	[\\\/]), sub {

		$self->default('abs', 1);

		if ($_[1] =~ /\\/) {

			$self->default('type', "win");
		} else {
			$self->default('type', "lux");
		}
		$_[1];
	},
	qw(DOS_DRIVE	\w:), sub {	# for DOS drive format, i.e. C:

		my $drive = $_[1];

		$self->default('type', "win");

		$self->drive_letter($drive);

		push @{ $self->volumes }, $drive;

		$self->dump_struct;

		$drive;
	},
	qw(NET_HOST	[^\s:]+:), sub {	# for nfs format, i.e. server:
#	qw(NET_HOST	[\w\.\d\-_]+:+), sub {	# for nfs format, i.e. server:

		my $server = $self->trim($_[1], qr/:$/);

		$self->default('type', "nfs");

		$self->server($server);

		$self->dump_struct;

		$_[1];
	},
	qw(HOME  ~), sub {

		# tilde is a symbolic reference to an absolute path
		# but is still treated as a relative path
#		$self->default('abs', 1);
		$self->abs(0);
#		$self->default('type', "lux");

		push @{ $self->folders }, $_[1];

		$self->homed(1);

		$self->dump_struct;

		$_[1];
	},
	qw{CYG_ROOT  [Cc][Yy][Gg][Dd]\w+}, sub {

		$self->type("cyg");
		$self->hybrid(1);

		push @{ $self->volumes }, $_[1];

		$lexer->start('cyg');

		$_[1];
  	},
	qw(FOLDER  [\s\'\.\w]+), sub {

		my $folder = $_[1];

		$self->log->debug("folder [$folder]");

		$self->homed(1) if ($folder =~ /^home$/i);
		$self->homed(1) if ($folder =~ /^Users$/);

		$self->default('abs', 0);

		my $fpf = 1; if (scalar(@{ $self->folders }) == 1) {

			my $parent = $self->folders->[0];
			my $sre = sprintf "(%s)", join('|', DN_MOUNT_WSL, DN_MOUNT_CYG);
			$self->log->debug("sre [$sre]");

			if ($parent =~ qr/^$sre$/) {

				$self->drive_letter($folder);

				shift @{ $self->folders };

				push @{ $self->volumes }, $parent;
				push @{ $self->volumes }, $folder;

				$fpf = 0;

				$self->hybrid(1);
			}
		}
		push @{ $self->folders }, $folder if ($fpf);

		$self->dump_struct;

		$folder;
	},
	qw(ERROR  .*), sub {

		$self->cough(sprintf("parse path token failed [%s]\n", $_[1]));
	},
	);
	$self->log->trace(sprintf "token [%s]", Dumper(\@token));

	Parse::Lex->inclusive(qw/ cyg share unchost wsl /);

	Parse::Lex->trace(1) if ($ENV{'DEBUG'});

	$lexer = Parse::Lex->new(@token);

	$self->{'_lexer'} = $lexer;

	return $lexer;
}
 
=item OBJ->parse(EXPR)

Parse a path into its various components and update and metadata where possible.

=cut

sub parse {
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX parse(PATH)" unless (defined $pn);

	$self->log->info("parsing [$pn]");

	$self->abs(undef);
	$self->drive(undef);
	$self->homed(undef);
	$self->hybrid(undef);
	$self->letter(undef);
	$self->folders([]);
	$self->server(undef);
	$self->type(undef);
	$self->unc(undef);
	$self->volumes([]);

	my $lex = $self->lexer;

	$lex->from($pn);

	my $count; for ($count = 1; $count; $count++) {

		my $token = $lex->next;

		last if ($lex->eoi);
	}

	# failsafe value following undef above
	$self->default('abs', 0);
	$self->default('homed', 0);
	$self->default('hybrid', 0);
	$self->default('type', "lux");
	$self->default('unc', 0);

	return $count;
}

=item OBJ->separator

Return the connector string relevant to the specified behaviour.
This is the correlating method to B<connector>.

=cut

sub separator {
	my $self = shift;

	return $self->reu if ($self->behaviour eq 'u');

	return $self->rew;
}

=item OBJ->slash([EXPR])

Based on expected behaviour optionally convert / to \\

=cut

sub slash {
	my $self = shift;
#	if (@_) { $self->converted(shift) };
#	confess "SYNTAX slash(EXPR)" unless defined($self->converted);

	my $pni;# = $self->converted;

	my $pno = $pni;
	my $de = ($self->behaviour eq 'u') ?  $self->deu : $self->dew;
	my $reu = $self->reu;

	$pno =~ s/$reu/$de/g;

	$self->log->debug("pni [$pni] pno [$pno]");

	return $pno unless ($self->shellify);

	my $res = $self->res;

	$pno =~ s/$res/\\$&/g;	# slash all occurrences within

	$self->log->debug("slashed pno [$pno]");

	return $pno;
}

=item OBJ->tld([TYPE], [SERVER])

Return the top-level directory component for a hybrid OS, e.g. cygwin or mnt.
This returns the root directory for a standalone linux platform.
You can override the behaviour, particularly for WSL by passing a TYPE.
Specifying the SERVER argument will override any top-level behaviour as it 
will expect to return a network path.

=cut

sub tld {
	my $self = shift;
	my $type = shift ; $self->type($type) if defined($type);
	my $server = shift ; $self->server($server) if defined($server);
	$self->log->logconfess($self->msg) unless defined($self->type);

	my $hostpath = join($self->deu, $self->deu, $self->server)
		if (defined $self->server);

	$self->log->debug(sprintf "hostpath [%s]", (defined $hostpath) ? $hostpath : "(undef)");

	my $tld; if ($self->on_cygwin) {

		$tld = ($hostpath) ? $hostpath : $self->deu . DN_MOUNT_CYG;

	} elsif ($self->on_wsl) {

		if (defined $hostpath) {
			$tld = $hostpath;
		} else {
			if ($self->type eq 'wsl') {
				$tld = join($self->deu, $self->deu, $self->_wslroot);
			} else {
				$tld = $self->deu . DN_MOUNT_WSL;
			}
		}
	} elsif ($self->on_windows) {

		if (defined $hostpath) {
			$tld = $hostpath;
		} else {
			if ($self->type eq 'wsl') {
				$tld = join($self->deu, $self->deu, $self->_wslroot);
			}
		}
	} else {
		$tld = $hostpath if (defined $hostpath);
	}
	$tld = '' unless defined($tld);
#		$self->cough("unable to determine platform [$^O]");
	$self->log->debug(sprintf "type [%s] tld [$tld]", $self->type);

	return $tld;
}

=item OBJ->volume([DRIVE])

Generate a volume string which is platform depedent, e.g C: or /cygdrive/c.
NOTE: this routine is fatal if no drive has been defined (see the B<drive_letter> method, and since not all paths will have a volume, this check should be
made first.

=cut

sub volume {
	my $self = shift;
	$self->drive_letter(shift) if (@_);
	$self->log->logconfess($self->msg) unless (
		defined($self->type) && defined($self->unc));
	confess "SYNTAX volume(DRIVE)" unless defined($self->drive);

	$self->log->debug(sprintf "type [%s] unc [%d]", $self->type, $self->unc);
	$self->log->debug(sprintf "on_windows [%d] on_wsl [%d]", $self->on_windows, $self->on_wsl);
	$self->dump_struct;

	my $volume; if ($self->on_windows) {

		if ($self->type eq 'wsl') {

			$volume = join($self->deu, $self->deu, $self->_wslroot);

		} else {
			if (defined $self->server) {
				$volume = join($self->deu, $self->tld, $self->letter);
			} else {
				$volume = $self->drive;
			}
		}
	} else {
		$self->log->debug(sprintf "deu [%s]", $self->deu);

		$self->log->debug(sprintf "letter [%s]", $self->letter);

		if ($self->on_wsl && $self->type eq 'wsl') {

			$volume = join($self->deu, $self->deu, $self->_wslroot);

		} else {
			if (defined $self->letter) {

				$volume = join($self->deu, $self->tld, $self->letter);
#				if ($self->letter eq $self->unknown) {
#				} else {
#					$volume = $self->tld . $self->letter;
#				}
			} else {
				$volume = $self->tld;
			}
		}
	}
	$self->log->debug("volume [$volume]");

	return $volume;
}

=item OBJ->winuser

Returns the name of the current Windows user (Windows-like platforms only).
This makes a call to Powershell.  If that is not possible or returns no
value then a failsafe PERL-native call is made.

=cut

sub winuser {
	my $self = shift;

	$self->echo(1);	# debugging
	my $cmd; if ($self->on_windows) {

		$cmd = q{powershell.exe "$env:UserName"};

	} elsif ($self->like_windows) {

		$cmd = q{powershell.exe '$env:UserName'};
	} else {
		$cmd = q{pwsh '$env:UserName'};
	}
	my @result = $self->c2a($cmd);

	unless (scalar @result) {

		$self->log->warn("[$cmd] produced no result, defaulting via PERL");
		$result[0] = getpwuid($<);

	}
	$self->log->debug(sprintf "result [%s]", Dumper(\@result));

	return $result[0] if (@result);

	return undef;
}

=item OBJ->wslhome

Determine the host location of the WSL user home.
Returns undef if the current process is not executing within a WSL context.

=cut

sub wslhome {	# determine the host location of the WSL user home
	my $self = shift;

	return undef unless ($self->like_windows);

	my $root = $self->_wslroot;

	return undef unless defined($root);

	my $home = $self->joiner($self->_wslroot, FN_HOME);

	return undef unless(-d $home);

	return $self->slash($home);
}

=item OBJ->_wslroot

INTERNAL ROUTINE ONLY.  Determine the host location of the WSL distro root.

=cut

sub _wslroot {
#	note that this only has relevance on a Windows-like system, but
#	not really within the WSL itself, so the latter is contrived.
#	this routine generates a likely WSL root, regardless of its existence.
	my $self = shift;

	$self->log->logwarn("WSL does not exist on this platform")
		unless ($self->like_windows);

	my $dist = $self->wsl_dist;

	$dist = $self->unknown unless defined($dist);

	$self->log->debug(sprintf "dist [%s]", $dist);
	$self->log->debug(sprintf "DN_ROOT_WSL [%s]", DN_ROOT_WSL);

	my $root = join($self->deu, DN_ROOT_WSL, $dist);

	$self->log->debug(sprintf "root [%s]", $root);

	return $root;
}

=item OBJ->wslroot

Determine the host's directory location of the current WSL distribution root.

=cut

sub wslroot {	# determine the host location of the WSL distro root
	my $self = shift;

	my $root = $self->_wslroot;

	return undef unless(-d $root);

	return $self->slash($root);
}

#sub END { }

1;

__END__

=back

=head1 VERSION

_IDE_REVISION_

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 3 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=head1 SEE ALSO

L<perl>.

=cut

