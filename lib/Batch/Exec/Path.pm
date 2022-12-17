package Batch::Exec::Path;

=head1 NAME

Batch::Exec::Path cross-platform path handling for the batch executive.

=head1 AUTHOR

Copyright (C) 2021  B<Tom McMeekin> tmcmeeki@cpan.org

=head1 SYNOPSIS

  use Batch::Exec::Path;


=head1 DESCRIPTION

___detailed_class_description_here___

=over 4

=item OBJ->behaviour(EXPR)

Set the path parsing behaviour to one of "w" (Windows-like) or "u" (Unix-like).
A platform-dependent default applies.

=item OBJ->shellify(BOOLEAN)

Useful when converting paths for shell-calls to Windows-like interpreters
backslashes are appropriately delimeted, e.g. \ becomes \\.
Default is 0 (off = do not shellify).

=item OBJ->winpath(PATH)

Converts a Cygwin-like path to a DOS/Windows-style path,
e.g. /cygdrive/c/Windows becomes c:/Windows.

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
#	log => get_logger("Batch::Exec::Path"),
	behaviour => undef,	# platform-dependent default, one of: w, u.
	deu => STR_DELIM_U,
	dew => STR_DELIM_W,
	raw => undef,		# the raw path passed into a parse function
	res => RE_SHELLIFY,
	reu => RE_DELIM_U,
	rew => RE_DELIM_W,
	root => undef,		# placeholder for root component
	shellify => 0,		# converts \ to \\ for DOS-like shell exits
	msg => STR_PREMATURE,
	unknown => STR_UNKNOWN,	# stringy failsafe
	abs => undef,
	drive => undef,
	folders => [],
	homed => undef,
	letter => undef,
	server => undef,
	type => undef,
	unc => undef,
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

	while (my ($method, $value) = each %args) {

		confess "SYNTAX new(, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	return $self;
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

	$letter =~ s/[:\$]$//;

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

=item OBJ->joiner

Joins components together into a pathname.  This method assumes that 
the B<parse> method has already been called.

=cut

sub joiner {
	my $self = shift;
	$self->log->logconfess($self->msg) unless defined($self->type);

#	my $reu = $self->reu;

#	$self->parse($pn);	# this should force a parse

#	my $pn = ($self->abs) ? $self->deu . $self->deu : ".";

	my $pn; if ($self->abs) {

		$pn = (defined $self->server) ? join($self->deu, $self->deu, $self->server) : "";

		if (defined $self->drive) {
			if ($self->type eq 'win') {
				$pn .= join($self->deu, $self->letter);
			} else {
				$pn .= join($self->deu, $self->tld, $self->drive);
			}
		} else {
			$pn .= $self->deu;
		}
	} else {
		$pn = "";
	}
	$self->log->debug("pn [$pn]");

	$pn .= join($self->deu, @{ $self->folders });

	$self->log->debug("pn [$pn]");

	return $pn;
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
		$lexer->end('unc');

		return $lexer;
	}
	my @token = (
#	qw(unc:NETPATH 	[\\\/]), sub {  
	"unc:NETPATH", '[\\\/]', sub {  

		$self->unc(1);

		$_[1];
  	},
	qw(unc:NETDRIVE  \w+\$), sub {

		$lexer->end('unc');

		$self->type("wsl")
			 if ($_[1] =~ /wsl/i);

		$self->drive_letter($_[1]);

		$_[1];
  	},
	qw(unc:SERVER  \w+), sub {

		# if you've already defined the server

		if ($self->unc && !defined($self->server)) {

			$self->server($_[1]);
		} else {
			push @{ $self->folders }, $_[1];

			$lexer->end('unc');
		}
		$_[1];
  	},
	qw(PATHSEP	[\\\/]), sub {

		my $decr = (defined $self->drive) ? length($self->drive) : 0;

		$self->log->debug(sprintf "decr [$decr] offset [%s]", $lexer->offset);
		my $abs; if ($lexer->offset - $decr == 1) {

			$abs = 1;

			$lexer->start('unc');

		} else {
			$abs = 0;
		}
		$self->log->debug("abs [$abs]");

		$self->default('abs', $abs);
		#$self->abs($abs);

		if ($_[1] =~ /\\/) {

			$self->default('type', "win");
		} else {
			$self->default('type', "lux");
		}

		$_[1];
	},
	qw(LOCALDRIVE	\w+:), sub {

		$self->default('type', "win");

		$self->drive_letter($_[1]);

		$_[1];
	},
	qw(HOME  ~), sub { # tilde is a symbolic reference to an absolute path

		$self->default('abs', 1);
		$self->default('type', "lux");

		$self->homed(1);
	},
	qw(FOLDER  [\s\'\.\w]+), sub {

		$self->homed(1) if ($_[1] =~ /^home$/i);

		my $raf = $self->folders;

		push @$raf, $_[1];

		$self->log->debug(sprintf "raf [%s]", Dumper($raf));

		if (@$raf > 1) {	# check for cygdrive / mnt

			if ($raf->[0] =~ /cygdrive/i) {

				$self->type('cyg');

				$self->drive_letter($raf->[1]);

			} elsif ($raf->[0] =~ /mnt/i) {

				$self->default('type', "wsl")
					if ($self->on_wsl);

				$self->drive_letter($raf->[1]);
			}
		}
		$lexer->end('unc');

		$_[1];
	},
	qw(ERROR  .*), sub {

		$self->cough(sprintf("parse path token failed [%s]\n", $_[1]));
	},
	);
	$self->log->trace(sprintf "token [%s]", Dumper(\@token));

	Parse::Lex->inclusive('unc');
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
	$self->letter(undef);
	$self->folders([]);
	$self->server(undef);
	$self->type(undef);
	$self->unc(undef);

	my $lex = $self->lexer;

	$lex->from($pn);

	my $count; for ($count = 1; $count; $count++) {

		my $token = $lex->next;

		last if ($lex->eoi);
	}

	# failsafe value following undef above
	$self->default('abs', 0);
	$self->default('homed', 0);
	$self->default('type', "lux");
	$self->default('unc', 0);

	return $count;
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

	my $tld;# = $self->deu;
	my $hostpath = join($self->deu, $self->deu, $self->server)
		if (defined $self->server);

	if ($self->on_cygwin) {

		$tld = ($hostpath) ? $hostpath : $self->deu . DN_MOUNT_CYG;

	} elsif ($self->on_wsl) {

		if (defined $hostpath) {
			$tld = $hostpath;
		} else {
			if ($self->type eq 'wsl') {
				$tld = $self->deu . $self->_wslroot;
			} else {
				$tld = $self->deu . DN_MOUNT_WSL;
			}
		}
	} else {
		$tld = $hostpath if (defined $hostpath);
	}
	$tld = '/' unless defined($tld);
#		$self->cough("unable to determine platform [$^O]");
	$self->log->debug("tld [$tld]");

	return $tld;
}

=item OBJ->volume([EXPR])

Generate a volume string which is platform depedent, e.g C: or /cygdrive/c

=cut

sub volume {
	my $self = shift;
	$self->drive_letter(shift) if (@_);
	$self->log->logconfess($self->msg) unless (
		defined($self->type) && defined($self->unc));
	confess "SYNTAX volume(EXPR)" unless defined($self->drive);

	$self->log->debug(sprintf "type [%s] unc [%d]", $self->type, $self->unc);
	$self->log->debug(sprintf "on_windows [%d] on_wsl [%d]", $self->on_windows, $self->on_wsl);

	my $volume; if ($self->on_windows) {

#		if ($self->on_wsl && $self->type eq 'wsl') {
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
			$self->log->debug("WSL PATH HERE XXXXXX");
#			$volume = $self->_wslroot;
			$volume = join($self->deu, $self->deu, $self->_wslroot);
		} else {
			$self->log->debug("NON-WSL PATH HERE ZZZZZZZZ");
			if (defined $self->letter) {

				if ($self->on_linux) {
#				if ($self->letter eq $self->unknown) {
					$volume = $self->tld;
				} else {
					$volume = join($self->deu, $self->tld, $self->letter);
				}
			} else {
				$volume = join($self->deu, $self->tld);
			}
		}
	}
	$self->log->debug("volume [$volume]");

	return $volume;
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

	unless ($self->like_windows) {

		$self->log->logwarn("WSL does not exist on this platform");

		return undef;
	}

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

	#return undef unless ($self->on_windows);
#	return undef unless ($self->like_windows);

	my $root = $self->_wslroot;

	return undef unless(-d $root);

	#my $files = readpipe(sprintf "%s %s", ($self->on_windows) ? "dir" : "ls", $root); $self->log->debug("files [$files]");

	return $self->slash($root);
}

#sub END { }

1;

__END__

=head1 VERSION

___EUMM_VERSION___

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

