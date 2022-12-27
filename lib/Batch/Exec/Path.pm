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

=item OBJ->exists

Boolean which indicates if the associated path refers to an extant file.
This is reset by the B<parse> method and assigned by the B<joiner> method.

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
#require Path::Tiny;
use Parse::Lex;

#use Log::Log4perl qw(:levels);	# debugging


# --- package constants ---
use constant ENV_WINHOME => $ENV{'HOMEDRIVE'};

use constant DN_MOUNT_WSL => "mnt";
use constant DN_MOUNT_CYG => "cygdrive";
use constant DN_WINHOME => (ENV_WINHOME) ? ENV_WINHOME : "c:";

use constant DN_ROOT_ALL => '/';	# the default root
use constant DN_ROOT_WSL => 'wsl$';	# this is a WSL location only
					# e.g. \\wsl$\Ubuntu\home (from DOS)
use constant FN_HOME => "home";	#	indicates a Linux-like home
use constant FN_USER => "Users";	# indicates a Windows-like home

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
#our $VERSION = '0.001';
our $VERSION = sprintf "%d.%03d", q[_IDE_REVISION_] =~ /(\d+)/g;


# --- package locals ---
#my $_n_objects = 0;

my %_attribute = (	# _attributes are restricted; no direct get/set
	_home => undef,		# a reliable version of user's home directory
	abs => undef,
	behaviour => undef,	# platform-dependent default, one of: w, u.
	deu => STR_DELIM_U,
	dew => STR_DELIM_W,
	drive => undef,
	exists => undef,
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

=item OBJ->cat_re(BOOLEAN, EXPR, ...)

Concatenate (join) the EXPR parameters passed to create a REGEXP.  
The BOOLEAN flag will cause the REGEXP to be book-ended as a start/finish
expression, which is the default behaviour.

=cut

sub cat_re {
	my $self = shift;
	my $f_bookend = shift; $f_bookend = 1 unless defined($f_bookend);
	confess "SYNTAX cat_re(BOOLEAN, EXPR)" unless (@_);

	my $str = $self->cat_str(@_);

	my $regexp = ($f_bookend) ? qr/^$str$/ : qr/$str/;

	$self->log->trace("regexp [$regexp]");
	
	return $regexp;
}

=item OBJ->cat_str(EXPR, ...)

Concatenate (join) the EXPR parameter(s) using a pipe as the delimeter,
and surround with parenthesis.  Returns a string.

=cut

sub cat_str {
	my $self = shift;
	confess "SYNTAX cat_str(EXPR)" unless (@_);

	my @valid; map {
		push @valid, $_ if defined($_);
	} @_;

	my $str = sprintf "(%s)", join('|', @valid);

	$self->log->debug("str [$str]");

	return $str;
}

=item OBJ->connector

Return the connector string relevant to the specified behaviour.
This is the correlating method to B<separator>.

=cut

sub connector {
	my $self = shift;

	my $type = (defined $self->type) ? $self->type : $self->unknown;

	return $self->deu if ($self->behaviour eq 'u' || $type eq 'nfs');

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

=item OBJ->escape([METHOD])

Convert a path into a format which can traverse a shell call.  Utilise the
method parameter to control the way this is done: 'b' back-slash (\), the 
default, or 'q' double-quote (") or 's' single-quote (').

Will call the B<joiner> method prior to the call, so therefore assumes a
pre-requisite B<parse>.

=cut

sub escape {
	my $self = shift;
#	if (@_) { $self->dummy(shift) };
	my $method = shift ; $method = 'b' unless defined($method);
	$self->log->logconfess($self->msg) unless defined($self->type);
	confess "SYNTAX escape(METHOD)" unless defined($method);

	my $pni = $self->joiner;

	my $pno; if ($method eq 'q') {

		$pno = "\"$pni\"";

	} elsif ($method eq 's') {

		$pno = "\'$pni\'";

	} elsif ($method eq 'b') {

		$pno = $pni;

		my $de = $self->dew;
		my $res = $self->res;

		$pno =~ s/$res/$de/g;

#		$pno =~ s/$res/\\$&/g;	# slash all occurrences within

	} else {
		$self->cough("invalid method [$method]");
	}
	$self->log->debug("pni [$pni] pno [$pno]");

	return $pno;
}

=item OBJ->extant(PATH, [TYPE])

Checks if the file specified by PATH exists. Unlike the parent method this is
a non-fatal check.

=cut

sub extant {
	my $self = shift;
	my $pn = shift;
	my $type = shift; $type = 'e' unless defined($type);
	confess "SYNTAX extant(EXPR)" unless defined($pn);

	my $previous = $self->fatal;

	$self->fatal(0);

	my $rv =  $self->SUPER::extant($pn, $type);

	$self->fatal($previous);

	return $rv;
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

Check if the EXPR is "known" or effectively so, per the B<unknown> attribute.
Returns 1 is exact match or -1 for regexp match, or 0 for no match.
The correlating method to B<is_unknown>.

=cut

sub is_known {
	my $self = shift;
	my $expr = shift;
	confess "SYNTAX is_known(EXPR)" unless defined($expr);

	my $rv = $self->is_unknown($expr);

	return 1 unless ($rv);	# value is NOT unknown!

	return 0;
}

=item OBJ->is_unknown(EXPR)

Check if the EXPR is "unknown" or effectively so, per the B<unknown> attribute.
Returns 1 is exact match or -1 for regexp match, or 0 for no match.
The correlating method to B<is_known>.

=cut

sub is_unknown {
	my $self = shift;
	my $expr = shift;
	confess "SYNTAX is_unknown(EXPR)" unless defined($expr);

	my $suk = $self->unknown;

	$self->log->trace("expr [$expr] suk [$suk]");

	return 1 if ($expr eq $suk);

	return -1 if ($expr =~ /$suk/);

	return 0;
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
	my @parts;

	$self->dump_me(undef, "joiner()");

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

	$self->exists($self->extant($pn));

	return $pn;
}

=item OBJ->dump_nice(EXPR)

A wrapper for Data::Dumper to flatten the output.
Self-referencial call to EXPR method.

=cut

sub dump_nice {
	my $self = shift;
	my $attr = shift;

	no strict 'refs';

	my $struct = Dumper($self->$attr);

	$struct =~ s/.+VAR[^\[]+//;
	$struct =~ s/[\;\n]//gm;
	$struct =~ s/\s+/ /g;

#	$self->log->debug("struct =$struct=");

	my $nice = "$attr $struct";

	return $nice;
}

=item OBJ->dump_me(Parse::Token)

Dump debugging information about the current token and structure.
Returns the token object.

=cut

sub dump_me {
	my $self = shift;
	my $token = shift;
	my $context = (@_) ? join(' ', @_) : undef;
#	confess "SYNTAX dump_me(Parse::Token)" unless (
#		defined($token) && ref($token) eq 'Parse::Token');

	my $null = '(undef)';
	my $fdt = (defined($token) && ref($token) =~ /^Parse::Token/) ? 1 : 0;
#	$self->log->debug(sprintf "ref [%s]", ref($token));

	unless (defined $context) {
		$context = ($fdt) ? $token->name : $self->unknown;
	}

	$self->log->debug(sprintf "==== PARSE ATTRIBUTES $context ====");

	$self->log->debug($self->dump_nice("folders"));
	$self->log->debug($self->dump_nice("volumes"));
	$self->log->debug(sprintf "abs [%s]", (defined $self->abs) ? $self->abs : $null);
	$self->log->debug(sprintf "drive [%s]", (defined $self->drive) ? $self->drive : $null);
	$self->log->debug(sprintf "exists [%s]", (defined $self->exists) ? $self->exists : $null);
	$self->log->debug(sprintf "homed [%s]", (defined $self->homed) ? $self->homed : $null);
	$self->log->debug(sprintf "hybrid [%s]", (defined $self->hybrid) ? $self->hybrid : $null);
	$self->log->debug(sprintf "mount [%s]", (defined $self->mount) ? $self->mount : $null);
	$self->log->debug(sprintf "server [%s]", (defined $self->server) ? $self->server : $null);
	$self->log->debug(sprintf "type [%s]", (defined $self->type) ? $self->type : $null);
	$self->log->debug(sprintf "unc [%s]", (defined $self->unc) ? $self->unc : $null);

	my $rv; if ($fdt) {

		$self->log->debug(sprintf "name [%s] regexp >%s< status [%s] text [%s]", $token->name, $token->regexp, $token->status, $token->text);

		$rv = $token->text;
	} else {
		$rv = undef;
	}
	$self->log->debug(sprintf "==== END OF ATTRIBUTES ====");

	return $rv;
}

=item OBJ->lexer

Create and return a lexer object with a path parsing text.  Only one parser
is maintained for the object, and is re-used on subsequent calls (which will
also handle a reset of the parser).

For reference, valid pathnames are discussed here:  https://stackoverflow.com/questions/1976007/what-characters-are-forbidden-in-windows-and-linux-directory-names

=cut

sub lexer {
	my $self = shift;
	my $lexer;
	my @token = (
	qw(cyg:LEX_CYG_DRIVE	^\w$), sub {

		$lexer->end('cyg');

		my $drive = $self->dump_me(shift @_);

		push @{ $self->volumes }, $drive;

		$self->drive_letter($drive);

		$drive;
	},
	qw{wsl:LEX_WSL_DISTRO  [\s\d\w]+}, sub {

		$lexer->end('wsl');

		my $token = $self->dump_me(shift @_);

		push @{ $self->volumes }, $token;

		$token;
  	},
	qw{unchost:LEX_WSL_ROOT  [Ww][Ss][Ll]\$}, sub {

		$lexer->end('unchost');

		my $token = $self->dump_me(shift @_);

		$self->hybrid(1);
		$self->type("wsl");
		$self->unc(0);

		push @{ $self->volumes }, $token;

		$lexer->start('wsl');

		$token;
  	},
	qw(share:LEX_NET_SHARE  [\w\d\-\_]+\$?), sub {

		$lexer->end('unchost');
		$lexer->end('share');

		my $folder = $self->dump_me(shift @_);

		push @{ $self->volumes }, $folder;

		$folder;
  	},
	qw(unchost:LEX_UNC_HOST  [\w\d\-\_]+), sub {

		my $host = $self->dump_me(shift @_);

		$self->server($host);

		$lexer->start('share');

		$host;
  	},
	"LEX_NET_PREFIX_L", "\/\/", sub {  

		my $token = $self->dump_me(shift @_);

		$self->default('abs', 1);
		$self->default('type', "lux");
		$self->default('unc', 1);

		$lexer->start('unchost');

		$token;
	},
	qw(LEX_NET_PREFIX_W \x5c{2}), sub {  	# \x5c = win backslash

		my $token = $self->dump_me(shift @_);

		$self->default('abs', 1);
		$self->default('type', "win");
		$self->default('unc', 1);

		$lexer->start('unchost');

		$token;
	},
	qw(LEX_PATHSEP	[\\\/]), sub {
#	"LEX_PATHSEP",	$self->cat_str($self->reu, $self->rew), sub {

#		$self->log->debug(sprintf "argv [%s]", Dumper(\@_));

		my $token = $self->dump_me(shift @_);

		$self->default('abs', 1);

#		if ($token =~ /\\/) {
		if ($token =~ $self->rew) {

			$self->default('type', "win");
		} else {
			$self->default('type', "lux");
		}

		$token;
	},
	qw(LEX_DOS_DRIVE	\w:), sub {	# for DOS drive format, i.e. C:

		my $drive = $self->dump_me(shift @_);

		$self->default('type', "win");

		$self->drive_letter($drive);

		push @{ $self->volumes }, $drive;

		$drive;
	},
	qw(LEX_NET_HOST	[^\s:]+:), sub {	# for nfs format, i.e. server:
#	qw(LEX_NET_HOST	[\w\.\d\-_]+:+), sub {	# for nfs format, i.e. server:

		my $token = $self->dump_me(shift @_);

		my $server = $self->trim($token, qr/:$/);

		$self->default('type', "nfs");

		$self->server($server);

		$token;
	},
	qw(LEX_HOME  ~), sub {

		my $token = $self->dump_me(shift @_);

		# tilde is a symbolic reference to an absolute path
		# but is still treated as a relative path
#		$self->default('abs', 1);
		$self->abs(0);
		$self->homed(1);
#		$self->default('type', "lux");

		push @{ $self->folders }, $token;

		$token;
	},
	qw{LEX_CYG_ROOT  [Cc][Yy][Gg][Dd]\w+}, sub {

		my $token = $self->dump_me(shift @_);

		$self->type("cyg");
		$self->hybrid(1);

#		push @{ $self->volumes }, $token;
		push @{ $self->folders }, $token;
#		$self->folders->[0] = $token;

		$lexer->start('cyg');

		$token;
  	},
#	qw(LEX_FOLDER  [\s\'\.\w]+), sub {
#	qw(LEX_FOLDER  [\s\.\w]+), sub {
	qw(LEX_FOLDER  [\.\'\s\w\d\-\_]+), sub {

		my $folder = $self->dump_me(shift @_);

		$self->log->debug("folder [$folder]");

		if ($folder =~ $self->cat_re(1, FN_HOME, FN_USER)) {

			$self->log->debug("GOT A HOME DIR");

			$self->homed(1);
		}
		$self->default('abs', 0);

		my $fpf = 1; if (scalar(@{ $self->folders }) == 1) {

			my $parent = $self->folders->[0];

			my $re = $self->cat_re(1, DN_MOUNT_WSL, DN_MOUNT_CYG);
			if ($parent =~ $re) {

				$self->log->debug("got here FOLDER");

				$self->drive_letter($folder);

				shift @{ $self->folders };

				push @{ $self->volumes }, $parent;
				push @{ $self->volumes }, $folder;

				$fpf = 0;

				$self->hybrid(1);
			}
		}
		push @{ $self->folders }, $folder if ($fpf);

		$folder;
	},
	qw(LEX_ERROR  .*), sub {

		$self->cough(sprintf("parse path token failed [%s]\n", $_[1]));
	},
	);
	$self->log->trace(sprintf "token [%s]", Dumper(\@token));

	Parse::Lex->inclusive(qw/ cyg share unchost wsl /);
	Parse::Lex->trace(1) if ($ENV{'DEBUG'});

	$lexer = Parse::Lex->new(@token);

	return ("LEX_", $lexer);
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
	$self->exists(0);
	$self->homed(undef);
	$self->hybrid(undef);
	$self->letter(undef);
	$self->folders([]);
	$self->server(undef);
	$self->type(undef);
	$self->unc(undef);
	$self->volumes([]);

	my ($rel, $lex) = $self->lexer;

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

	$self->dump_me(undef, "AFTER parse($count)");

	# bug in Parse::Lex raised [rt.cpan.org #145702], per the following:
	# 'Batch::Exec::Path::_TOKEN_' token is already defined at .../Parse/ALex.pm line nnn
	# refer: https://rt.cpan.org/Ticket/Display.html?id=145702
	# workaround this by manually deleting LEX_ symbols from this package.

	my $purge = 0; foreach my $symbol (keys %Batch::Exec::Path::) {

		if ($symbol =~ /$rel/) {

			$self->log->trace("purging symbol [$symbol]");

			delete $Batch::Exec::Path::{$symbol};

			$purge++;
		}
	}
	$self->log->debug("$purge [$rel] symbols purged");

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

=item OBJ->tld([TYPE])

Return the top-level path component for a hybrid OS, e.g. cygwin or mnt.
This returns the root directory for a standalone linux platform, or
You can override the behaviour, particularly for WSL by passing a TYPE.

=cut

sub tld {
	my $self = shift;
	$self->type(shift) if (@_);

	my $type = (defined $self->type) ? $self->type : $self->unknown;
	my $wslr = $self->wslroot;	# this does a parse/joiner combo

	return $wslr if ($type eq 'wsl'	&& $self->is_known($wslr));

	$self->log->debug(sprintf "wslr [$wslr] is unknown");

	if ($self->on_cygwin) {

		$self->parse($self->deu . DN_MOUNT_CYG);

	} elsif ($self->on_wsl) {

		$self->parse($self->deu . DN_MOUNT_WSL);

	} elsif ($self->on_windows) {

		$self->parse($self->winhome);

	} else {
		$self->parse(DN_ROOT_ALL);
	}
	return $self->joiner;
}

=item OBJ->winhome

Returns the name of the default "home" drive (as opposed to directory)
for Windows users.  See also B<home>.

=cut

sub winhome {
	my $self = shift;

	my $drv = DN_WINHOME;

#	$self->log->debug(sprintf "drv [$drv] ENV_WINHOME [%s]", ENV_WINHOME);
	$self->log->debug(sprintf "drv [$drv]");

	return DN_WINHOME;
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

=cut

sub wslhome {
	my $self = shift;

#	return undef unless ($self->like_windows);

	my $root = $self->wslroot;

	return undef unless defined($root);

	push @{ $self->folders }, FN_HOME;

	my $home = $self->joiner;

#	return undef unless(-d $home);

#	return $self->slash($home);
	return $home;
}

=item OBJ->wslroot

Determine the host location of the WSL distro root.

=cut

sub wslroot {
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

	my $root = join('', $self->dew, $self->dew, DN_ROOT_WSL, $self->dew, $dist);
	$self->parse($root);

	return $self->joiner;
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

