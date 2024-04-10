package Batch::Exec::Path;

=head1 NAME

Batch::Exec::Path - cross-platform path handling for the batch executive.

=head1 AUTHOR

Copyright (C) 2022  B<Tom McMeekin> tmcmeeki@cpan.org

=head1 SYNOPSIS

  use Batch::Exec::Path;

  my $bep = Batch::Exec::Path->new;

  printf "%s\n", $bep->home;

	# on linux, returns:	/home/jbloggs
	# on Windows, returns:	C:\Users\jbloggs


  # parsing and joining:
  $bep->parse('c:\\Users\\jbloggs');	# an MSWin format;

  printf "%s\n", $bep->joiner;		# native representation
	# returns: c:/Users/jbloggs

  printf "%s\n", $bep->convert('wsl');	# convert to another representation
	# returns: \\wsl$\Ubuntu\Users\jbloggs


  # preparing for shell calls: escape() must follow parse...
  printf "%s\n", $bep->escape;
	# returns: \\\\wsl\$\\Ubuntu\\Users\\jbloggs


  # simple adaptation to current platform:
  $bep->parse($bep->home);

  printf "%s\n", $bep->adapt;
	# on Cygwin returns:		/cygdrive/c/Users/jbloggs/cygwin
	# on Ubuntu/WSL returns:	\\wsl$\Ubuntu\home\jbloggs
	# on MSWin returns:		C:\Users\jbloggs


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

Note that the host program should verify the existence of a particular path,
as this is neither performant or reliable from within this package.  However,
the B<extant> method is available if such a check is required.

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

=item OBJ->distro

Get or set the default WSL distribution name.  A default applies.

=item OBJ->dosdrive

Get or set the default DOS drive.  A default applies.
This attribute remains unchanged during a B<parse> operation, as distinct
from the B<drive> attribute below.

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

use File::Spec;
#use Logfer qw/ :all /;
use File::Basename;
#require File::Spec::Win32;
require File::HomeDir;
#require Path::Class;
#require Path::Tiny;
use Parse::Lex;

#use Log::Log4perl qw(:levels);	# debugging


# --- package constants ---
use constant ENV_WINHOME => $ENV{'HOMEDRIVE'};
use constant ENV_WINPATH => $ENV{'HOMEPATH'};

use constant DN_DISTWSL_DFL => "Ubuntu";# add if missing (certain contexts)
use constant DN_DRIVE_DFL => "c";	# add if missing (certain contexts)
use constant DN_MOUNT_CYG => "cygdrive";
use constant DN_MOUNT_HYB => "mnt";
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
use constant STR_PREMATURE => "method called prematurely; have you called parse() method";			# error message for method ordering
use constant STR_TILDE => '~';		# correlates to home directory
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
my %_userhome;

my %_attribute = (	# _attributes are restricted; no direct get/set
	_home => undef,		# a reliable version of user's home directory
	abs => undef,
	behaviour => undef,	# platform-dependent default, one of: w, u.
	deu => STR_DELIM_U,
	dew => STR_DELIM_W,
	distro => DN_DISTWSL_DFL,
	drive => undef,
	dosdrive => DN_DRIVE_DFL,
	folders => [],
	homed => undef,
	hybrid => undef,
	letter => undef,
	msg => STR_PREMATURE,
	raw => undef,		# the raw path passed into a parse function
	res => RE_SHELLIFY,
	reu => RE_DELIM_U,
	rew => RE_DELIM_W,
#	root => undef,		# placeholder for root component
	server => undef,
	type => undef,
	unc => undef,
	unknown => STR_UNKNOWN,	# stringy failsafe
	userhome => \%_userhome,	# see homes() method
	user => undef,		# populated during parse
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
	$self->behaviour(($self->on_windows) ? "w" : "u");
	$self->home;
	$self->homes;

	while (my ($method, $value) = each %args) {

		confess "SYNTAX new(, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	$self->lov("_register", 'abs', { 0 => "relative", 1 => "absolute" });

	$self->lov("_register", 'homed', { 0 => "no reference to home directory", 1 => "home directory referenced" });

	$self->lov("_register", 'hybrid', { 0 => "path does not indicate a hybrid platform", 1 => "path indicates a hybrid platform" });

	my %types = ('cyg' => "Cygwin (hybrid)", 'lux' => "linux or unix", 'nfs' => "networked file system", 'win' => "MSWin-related", 'wsl' => "WSL on MSWin", 'hyb' => "Other hybrid (e.g. WSL)");

	$self->lov("_register", 'type', \%types);

	$self->lov("_register", 'unc', { 0 => "this is not a UNC path", 1 => "this is a UNC path" });

	return $self;
}

=head2 METHODS

=over 4

=item OBJ->adapt

Attempt to convert a previously parsed path to a format compatible with the
current platform.  This is basically a convenience wrapper for the 
B<convert> method.

=cut

sub adapt {
	my $self = shift;
	$self->cough($self->msg) unless defined($self->type);
#	confess "SYNTAX adapt(EXPR)" unless (@_);

	my $to; if ($self->on_cygwin) {

		$to = 'cyg';

	} elsif ($self->on_wsl) {

		$to = 'wsl';

	} elsif ($self->on_windows) {

		$to = 'win';
	} else {
		$to = 'lux';
	}
	$self->log->debug("selected [$to] for this platform");

	return $self->convert($to);
}

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

	$self->log->trace("str [$str]");

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

=item OBJ->convert_home(USER)

Determine a user's home directory and re-parse.

=cut

sub convert_home {
	my $self = shift;
	my $user = shift; $user = $self->user unless defined($user);
	$self->cough($self->msg) unless defined($self->type);
	confess "SYNTAX convert_home(USER)" unless defined($user);

#	$self->log->debug($self->dump($self->userhome, "userhome"));

	$self->log->info("attempting home directory conversion ($user)");

	my $dnh; if (exists $self->userhome->{$self->user}) {

		$dnh = $self->userhome->{$self->user};

	} else {

		my $homes = ($self->type eq 'win') ? $self->winhome : File::Spec->catdir("", FN_HOME);

		$dnh = File::Spec->catdir($homes, $self->user);
	}

	$self->parse($dnh);

	return $self->joiner("convert_home()");
}

=item OBJ->convert_volumes(TYPE_FROM, TYPE_TO)

Attempt to convert volumes according to the type passed.  Volumes are important
for a number of target types, e.g. cyg, hyb, win, wsl and for UNC paths.
Key pre-requisites are checked, e.g. drive letter and/or server.

=cut

sub convert_volumes {
	my $self = shift;
	my $typA = shift;	# from (previously $self-type (now cleared!)
	my $typB = shift;	# to be type
#	$self->cough($self->msg) unless defined($self->type);
	confess "SYNTAX convert_volumes(TYPE)" unless (
		defined($typA) && defined($typB));

	$self->log->info("converting volumes from [$typA] to [$typB]");

	my $n_vol = scalar(@{ $self->volumes });
	my $rav = $self->volumes;
	my $reh = $self->cat_re(1, DN_MOUNT_HYB, DN_MOUNT_CYG);
	my $msg = "WARNING unassigned %s";
	my $e_typ = "ERROR unexpected type [$typB]";

	my $f_hve = (@$rav && $rav->[0] =~ $reh) ? 1 : 0; # hybrid volumes exist
	$self->log->debug("f_hve [$f_hve] n_vol [$n_vol]");

	$self->default("type", $typB);

	# check some pre-requisites

	if ($self->unc) {

		$self->log->warn($self->dump($msg, "server"))
			unless (defined $self->server);

		$self->log->warn($self->dump($msg, "volume (UNC)"))
			unless ($n_vol);

		return;

	} elsif ($n_vol > 2) {
#		($n_vol != 2 && $self->type ne 'win'
#		&& $self->type ne 'nfs'
#		&& $self->type ne 'lux')

		# considerations for < two volumes
		# win:  c:\Temp\abc.txt		volumes array ['c:']
		# nfs:  hosty:/tmp		volumes array []
		# lux:  /home/jbloggs		volumes array []

		$self->cough("unexpected volume count [$n_vol]");

	} elsif (!defined($self->letter)) {

		# different path types may not have a drive letter
#		$self->type ne 'nfs' && $self->type ne 'wsl' && $self->type ne 'lux'
		if ($typB eq 'cyg' || $typB eq 'hyb') {

#			$self->cough($self->dump($msg, "drive letter"));
			$self->log->warn($self->dump($msg, "drive letter, assigning default"));
			$self->drive_letter($self->dosdrive);
		}
	}

	if ($typB eq 'cyg') {

		# special case:  cygwin recognises wslroot!

		unless ($typA eq 'wsl') {

			# we're going to re-write the volumes
			# if you don't want this then use 'lux' type!

			$self->volumes([]);

			push @{ $self->volumes }, DN_MOUNT_CYG;
			push @{ $self->volumes }, $self->letter;
		}

	} elsif ($typB eq 'hyb') {

		# we're going to re-write the volumes
		# if you don't want this then use 'lux' type!
		$self->volumes([]);

		# special case:  hybrid does not know about wslroot, so
		# we're going to keep volumes empty

		unless ($typA eq 'wsl') {

			push @{ $self->volumes }, DN_MOUNT_HYB;
			push @{ $self->volumes }, lc($self->letter); # LOWERCASE
		}

	} elsif ($typB eq 'lux') {

		# use cases to clear volumes:
		# /wsl$/Ubuntu/home/jbloggs	volumes array ['wsl$', 'Ubuntu']

		$self->volumes([]);

	} elsif ($typB eq "nfs") {

		# watching for \\server\c$\tmp --> server:/c$/tmp
		# watching for /hybrid/c/tmp --> undefined (maybe just /tmp)
		# watching for c:\tmp --> just /tmp
		# watching for \\wsl$\Ubuntu --> just / (i.e. WSL unknown)

		if ($f_hve) {
			shift @$rav;

			shift @$rav
				if (@$rav && $rav->[0] eq $self->letter);

		} elsif ($n_vol && $rav->[0] eq DN_ROOT_WSL) {

			$self->volumes([]);

		} elsif ($n_vol && defined($self->drive) && $rav->[0] eq $self->drive) { # C:

			shift @$rav;
		}

	} elsif ($typB eq 'win') {

		# special case:  win knows that wslroot is special

		if ($typA eq 'wsl') {

			$self->set("type", 'wsl');
		} else {

			# we're going to re-write the volumes
			$self->volumes([]);

			push @{ $self->volumes }, DN_MOUNT_CYG;
			push @{ $self->volumes }, $self->letter;
		}

	} elsif ($typB eq 'wsl') {

		if (defined $self->server) {

		} elsif ($f_hve) {

			shift @$rav;

			shift @$rav
				if (@$rav && $rav->[0] eq $self->letter);

			$self->set("type", "win");

		} elsif ($typA eq 'lux' || $typA eq 'win') {

			# interesting scenarios: c:\tmp > \\wsl$\Ubuntu\tmp
			$self->volumes([]);

			my $dn_dist = $self->wsl_dist;
			$dn_dist = $self->distro unless defined($dn_dist);

			push @{ $self->volumes }, DN_ROOT_WSL;
			push @{ $self->volumes }, $dn_dist;

		} elsif ($n_vol && defined($self->drive) && $rav->[0] eq $self->drive) { # C:
#		} elsif ($n_vol && $rav->[0] eq $self->drive) { # C:

			shift @$rav;
		}
	} else {
		$self->cough($e_typ);
	}
	return $self->type;
}

=item OBJ->convert(TYPE, [PATH])

Converts the set of parsed path components to a pathname compatible with TYPE.
This method assumes that the B<parse> method has already been called.
The TYPE parameter must be one of: { cyg, lux, nfs, win, wsl }.

=cut

sub convert {
	my $self = shift;
	my $typB = shift;	# NOT TO BE CONFUSED WITH $self->type
	$self->cough($self->msg) unless defined($self->type);
	confess "SYNTAX convert(TYPE)" unless defined($typB);

	$self->behaviour(($typB eq 'win' || $typB eq 'wsl') ? 'w' : 'u');
	$self->log->info($self->dump("to type [%s] behaviour [%s]", $typB, $self->behaviour));

	my $old = $self->joiner("convert(old)");
#	$self->log->debug("==== xxxx ==== xxxx ==== xxxx ====");
	my $typA = $self->type;
	my $ret = STR_TILDE;
	my $raf = $self->folders;
	my $f_tll = (@$raf && $raf->[0] =~ qr/^$ret/) ? 1 : 0; # home dir like

	$self->log->debug("ret [$ret] f_tll [$f_tll]");

	# handle special conversions and exclusions

	my $skip = 1; if ($self->homed && $f_tll) {

		return $self->convert_home;

	} elsif ($typB eq $typA) {

		$self->log->info("skipping conversion of same type [$typB]");

	} elsif (!$self->abs) {

		$self->log->info("relative behaviour conversion only");

	} else {
		$skip = 0;

	};
	return $old if ($skip); # conversion is redundant

	$self->type(undef); # force this to be populated during conversion

	my $desA = $self->lov("_lookup", "type", $typA);
	my $desB = $self->lov("_lookup", "type", $typB);

	$self->log->info("converting [$typA] ($desA) to [$typB] ($desB)");

	my $msg; if ($typB eq "cyg") {

		$self->convert_volumes($typA, $typB);

#		$self->set("type", $typB);

		# special case:  cygwin recognises wslroot!

		$self->set("type", 'wsl') if ($typA eq 'wsl');

	} elsif ($typB eq "hyb") {

		$self->convert_volumes($typA, $typB);

#		$self->set("type", $typB);

	} elsif ($typB eq "lux") {

		$self->convert_volumes($typA, $typB);

#		$self->set("type", $typB);

	} elsif ($typB eq "nfs") {

		$self->convert_volumes($typA, $typB);

		if (defined $self->server) {
			$self->set("type", $typB)
		} else {
			$self->set("type", "lux");
		}

	} elsif ($typB eq "win") {

		$self->convert_volumes($typA, $typB);

#		$self->set("type", $typB);

	} elsif ($typB eq "wsl") {

		$self->convert_volumes($typA, $typB);
	}
	if (defined $msg) {

		my $err = sprintf "WARNING cannot convert [$old] to [$typB]";

		$self->log->warn(join ": ", $err, $msg);

		return $old;
	}
	return $self->joiner("convert(new)");
}

=item OBJ->default(ATTRIBUTE, VALUE)

Default the attribute to the value passed.
Defaulting only sets the value if it hasn't already been set.
This is the correlating method to B<set>.

=cut

sub default {
	my $self = shift;
	my $prop = shift;
	my $value = shift;
	confess "SYNTAX default(ATTRIBUTE, VALUE)" unless (
		defined($prop) && defined($value));

	return $self->lov("_default", $prop, $prop, $value);
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
#	$self->cough($self->msg) unless defined($self->type);

	my $drive = $str;

	unless ($drive =~ /\$$/) {	# special drive '$'
		$drive .= ":" unless ($drive =~ /:$/);
	}

	my $letter = $str;

	$self->log->debug(sprintf "letter [$letter] on_windows [%d]", $self->on_windows);

	$letter =~ s/:$//;	# a trailing $ is important; do not strip

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
	$self->cough($self->msg) unless defined($self->type);
	confess "SYNTAX escape(METHOD)" unless defined($method);

	my $pni = $self->joiner("escape()");

	my $pno; if ($method eq 'q') {

		$pno = "\"$pni\"";

	} elsif ($method eq 's') {

		$pno = "\'$pni\'";

	} elsif ($method eq 'b') {

		$pno = $pni;

		#my $de = $self->dew;
		my $res = $self->res;

	#	$pno =~ s/$res/$de/g;

		$pno =~ s/$res/\\$&/g;	# slash all occurrences within
#		$pno =~ s/$res/\\/g;	# slash all occurrences within

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

=item OBJ->home([USER], ...)

Read-only method advises a generally failsafe home directory for the current
or specified user.  Any additional arguments are assumed to be path-related
and will be assembled to produce a path that is subordinate to the targetted
home directory, e.g.

  home('jbloggs', "foo", "bar");	# returns /home/jbloggs/foo/bar

=cut

sub home {
	my $self = shift;
	my $user = shift;

	my $dn; if (defined($user)) {

		unless (exists $self->userhome->{$user}) {

			$self->log->warn("no home entry for user [$user]");

			return undef;
		}
		$dn = $self->userhome->{$user};
	} else {
		if (defined $self->{'_home'}) {

			$dn = $self->{'_home'};
		} else {
			my $env = ($self->on_windows) ? $ENV{'USERPROFILE'} : $ENV{'HOME'};
			$dn = ($env eq '') ? File::HomeDir->my_home : $env;

		}
	}
	$self->{'_home'} = $dn;

	my $rv = (@_) ? $dn = File::Spec->catfile($dn, @_) : $dn;

	$self->log->debug("home folder [$rv]");

	return $dn;
}

=item OBJ->homes([BOOLEAN])

For the unices, cache a table of user's home directories.  This is done
once for the whole class during construction, but can be called at anytime for
the purpose of refreshing the cache, by passing a true boolean.
Returns a count of records cached.

=cut

sub homes {
	my $self = shift;
	my $force = shift; $force = 0 unless defined($force);

	my $rau = $self->userhome;
	my $users = scalar(keys %$rau);

	$self->log->debug("users [$users] force [$force]");

	if ($users && !$force) {
		$self->log->info("skipping home directory fetch");

		return $users;
	}
	%{ $self->userhome } = ();
	$self->log->info("fetching user home directories");

	my $count = 0; if ($self->like_unix) {

		while (my ($user, undef, undef, undef, undef, undef, undef, $home) = getpwent) {
#			next unless (-d $home);

			unless (exists $rau->{$user}) {

				$rau->{$user} = $home;

				$count++;
			}
		}
		endpwent;
	} else {
		my $home = ENV_WINHOME . ENV_WINPATH;
		my @home = split($self->rew, $home);

		pop @home;
		$home = join $self->dew, @home, '*';

        	$self->log->trace(sprintf "home [$home] home [%s]", Dumper(\@home));
		my @homes = glob($home);

		$self->log->trace(sprintf "homes [%s]", Dumper(\@homes));

		for $home (@homes) {

			next unless (-d $home);

			@home = split($self->rew, $home);

			my $user = pop @home;

        		$self->log->trace("home [$home] user [$user]");

	                $rau->{$user} = $home;

			$count++;
		}
	}
        $self->log->trace(sprintf "rau [%s]", Dumper($rau));
	$self->log->info("$count user home directories fetched");

	return $count;
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

=item OBJ->joiner([EXPR])

Joins the set of parsed path components together into a pathname, and
checks for existence.
The EXPR parameter can be used to supply some debugging context, as this 
routine is called multiple times within this package.
This method assumes that the B<parse> method has already been called.

=cut

sub joiner {
	my $self = shift;
	my $context = shift; $context = "joiner()" unless defined($context);
	$self->cough($self->msg) unless ( defined($self->type)
		&& defined($self->abs)
		&& defined($self->unc)
	);
	my @parts;

	$self->dump_me(undef, $context);

	if ($self->type eq 'nfs') {

		push @parts, $self->server . ':' if (defined($self->server));

		push @parts, @{ $self->volumes };

	} elsif ($self->unc || $self->type eq 'wsl') {  # file-share or WSL format

		push @parts, undef;

		push @parts, $self->server if (defined($self->server));

		push @parts, @{ $self->volumes };

	} elsif ($self->type eq 'win') {

		if (defined $self->drive) {

			push @parts, $self->drive;

		} elsif ($self->abs) {

			push @parts, undef;
		}
	} else {		# local format (no server component)

		push @parts, undef if ($self->abs);

		push @parts, @{ $self->volumes };
	}

	push @parts, @{ $self->folders };

	for (my $ss = 0; $ss < @parts; $ss++) {

		$parts[$ss] = $self->connector
			unless(defined $parts[$ss]);
	}
	my $pn = join($self->connector, @parts);

	unless (defined $self->server || $self->type eq 'wsl') {

		my $re = $self->separator;

		$pn =~ s/^$re// if ($pn =~ /^$re$re/);
	}
	$self->log->info("joined [$pn]");

	return $pn;
}

=item OBJ->dump_me(Parse::Token)

Dump debugging information about the current token and structure.
Returns the token object.

=cut

sub dump_me {
	my $self = shift;
	my $token = shift;
	my $context = (@_) ? join(' ', @_) : undef;

#	my $null = '(-)';
	my $null = "";
	my $fdt = (defined($token) && ref($token) =~ /^Parse::Token/) ? 1 : 0;
#	my @attr = qw/ abs drive letter exists homed hybrid type unc behaviour server user /;
	my @attr = qw/ abs drive letter unc homed hybrid type behaviour user server /;

	unless (defined $context) {
		$context = ($fdt) ? $token->name : $self->unknown;
	}

	$self->log->trace(sprintf "==== START attributes $context ====");

	$self->log->trace($self->dump($self->folders, "folders"));
	$self->log->trace($self->dump($self->volumes, "volumes"));

	my $count = 0;
	my $str = "";

	for my $attr (@attr) {

		no strict 'refs';

		$str .= sprintf "%6s [%s]  ", $attr, (defined $self->$attr) ? $self->$attr : $null;
		if (++$count % 3 == 0) {

			$self->log->trace($str);

			$str = "";
		}
	}
	$self->log->trace($str) unless ($str eq "");

	my $rv; if ($fdt) {

		$self->log->trace(sprintf "name [%s] regexp >%s< status [%s] text [%s]", $token->name, $token->regexp, $token->status, $token->text);

		$rv = $token->text;
	} else {
		$rv = undef;
	}
	$self->log->trace(sprintf "==== END attributes $context ====");

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

		$self->set("hybrid", 1);
		$self->set("type", "wsl");
		$self->set("unc", 0);

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
		$self->default("type", "lux");
		$self->default('unc', 1);

		$lexer->start('unchost');

		$token;
	},
	qw(LEX_NET_PREFIX_W \x5c{2}), sub {  	# \x5c = win backslash

		my $token = $self->dump_me(shift @_);

		$self->default('abs', 1);
		$self->default("type", "win");
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

			$self->default("type", "win");
		} else {
			$self->default("type", "lux");
		}

		$token;
	},
	qw(LEX_DOS_DRIVE	\w:), sub {	# for DOS drive format, i.e. C:

		my $drive = $self->dump_me(shift @_);

		$self->default("type", "win");

		$self->drive_letter($drive);

		push @{ $self->volumes }, $drive;

		$drive;
	},
	qw(LEX_NET_HOST	[^\s:]+:), sub {	# for nfs format, i.e. server:
#	qw(LEX_NET_HOST	[\w\.\d\-_]+:+), sub {	# for nfs format, i.e. server:

		my $token = $self->dump_me(shift @_);

		my $server = $self->trim($token, qr/:$/);

		$self->default("type", "nfs");

		$self->server($server);

		$token;
	},
#	qw(LEX_HOME  ~), sub {
	qw(LEX_HOME  ~[\.\w\d\s\-\_]*), sub {

		my $token = $self->dump_me(shift @_);

		my $user = $token; $user =~ s/^\~//;

		$self->user(($user eq '') ? $self->whoami : $user);

		# tilde is a symbolic reference to an absolute path
		# but is still treated as a relative path
		$self->set("abs", 0);
		$self->set("homed", 1);

		push @{ $self->folders }, $token;

		$token;
	},
	qw{LEX_CYG_ROOT  [Cc][Yy][Gg][Dd]\w+}, sub {

		my $token = $self->dump_me(shift @_);

		$self->set("type", "cyg");
		$self->set("hybrid", 1);

#		push @{ $self->volumes }, $token;
		push @{ $self->folders }, $token;
#		$self->folders->[0] = $token;

		$lexer->start('cyg');

		$token;
  	},
#	qw(LEX_FOLDER  [\s\'\.\w]+), sub {
#	qw(LEX_FOLDER  [\s\.\w]+), sub {
	qw(LEX_FOLDER  [\.\'\s\w\d\-\_]+), sub {

		my $dn = $self->dump_me(shift @_);
		my $n_folders = scalar(@{ $self->folders });
		my $re_hom = $self->cat_re(1, FN_HOME, FN_USER);

		$self->log->debug("dn [$dn] n_folders [$n_folders] re_hom [$re_hom]");
		$self->default('abs', 0);

		if ($dn =~ $re_hom) {

			$self->set("homed", 1);

		} elsif ($self->homed) {

			$self->user($dn) if ($n_folders &&
				$self->folders->[$n_folders - 1] =~ $re_hom);
		}

		my $fpf = 1; if ($n_folders == 1) {

			my $parent = $self->folders->[0];

			my $re = $self->cat_re(1, DN_MOUNT_HYB, DN_MOUNT_CYG);

			if ($parent =~ $re) {

				$self->drive_letter($dn);

				shift @{ $self->folders };

				push @{ $self->volumes }, $parent;
				push @{ $self->volumes }, $dn;

				$fpf = 0;

#				$self->set("hybrid", 1);
				$self->default("hybrid", 1);
			}
		}
		push @{ $self->folders }, $dn if ($fpf);

		$dn;
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
	$self->homed(undef);
	$self->hybrid(undef);
	$self->letter(undef);
	$self->folders([]);
	$self->server(undef);
	$self->type(undef);
	$self->unc(undef);
	$self->user(undef);
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
	$self->log->trace("$purge [$rel] symbols purged");

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

=item OBJ->set(ATTRIBUTE, VALUE)

Set the attribute to the value passed.
This is the correlating method to B<default>.

=cut

sub set {
	my $self = shift;
	my $prop = shift;
	my $value = shift;
	confess "SYNTAX set(ATTRIBUTE, VALUE)" unless (
		defined($prop) && defined($value));

	return $self->lov("_set", $prop, $prop, $value);
}

=item OBJ->tld([TYPE])

Return the top-level path component for a hybrid OS, e.g. cygwin or mnt.
This returns the root directory for a standalone linux platform, or
You can override the behaviour, particularly for WSL by passing a TYPE.

=cut

sub tld {
	my $self = shift;
	$self->lov("_set", "type", "type", shift) if (@_);
#	$self->type(shift) if (@_);

	my $type = (defined $self->type) ? $self->type : $self->unknown;
	my $wslr = $self->wslroot;	# this does a parse/joiner combo

	return $wslr if ($type eq 'wsl'	&& $self->is_known($wslr));

	$self->log->debug(sprintf "wslr [$wslr] is unknown");

	if ($self->on_cygwin) {

		$self->parse($self->deu . DN_MOUNT_CYG);

	} elsif ($self->on_wsl) {

		$self->parse($self->deu . DN_MOUNT_HYB);

	} elsif ($self->on_windows) {

		$self->parse($self->winhome);

	} else {
		$self->parse(DN_ROOT_ALL);
	}
	return $self->joiner("tld()");
}

=item OBJ->winhome

Returns the name of the default "home" drive (as opposed to directory)
for Windows users.
See also B<home>.

=cut

sub winhome {
	my $self = shift;

	my $drv = DN_WINHOME;

#	$self->log->debug(sprintf "drv [$drv] ENV_WINHOME [%s]", ENV_WINHOME);
	$self->log->debug(sprintf "drv [$drv]");

	return DN_WINHOME;
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

	my $home = $self->joiner("wslhome()");

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

	$self->log->warn("WSL does not exist on this platform")
		unless ($self->like_windows);

	my $dist = $self->wsl_dist;

	$dist = $self->unknown unless defined($dist);

	$self->log->debug(sprintf "dist [%s]", $dist);
	$self->log->debug(sprintf "DN_ROOT_WSL [%s]", DN_ROOT_WSL);

	my $root = join('', $self->dew, $self->dew, DN_ROOT_WSL, $self->dew, $dist);
	$self->parse($root);

	return $self->joiner("wslroot()");
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

L<perl>.  B<Batch::Exec>, B<File::Basename>, B<File::Spec>, B<Parse::Lex>.

=cut

