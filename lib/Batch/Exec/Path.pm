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

=item 10a.  OBJ->behaviour(EXPR)

Set the path parsing behaviour to one of "w" (Windows-like) or "u" (Unix-like).
A platform-dependent default applies.


=item 10a.  OBJ->shellify(BOOLEAN)

Useful when converting paths for shell-calls to Windows-like interpreters
backslashes are appropriately delimeted, e.g. \ becomes \\.
Default is 0 (off = do not shellify).


=item 10d.  OBJ->parse(PATH)

Converts a Windows-style path, e.g. C:\WINDOWS to that of a hybrid OS platform.
E.g. for Cygwin this might be /cygrive/c/WINDOWS
and for WSL this might be /mnt/c/WINDOWS.


=item 10e.  OBJ->tld

Return the top-level directory component for a hybrid OS, e.g. cygwin or mnt.


=item 10g.  OBJ->winpath(PATH)

Converts a Cygwin-like path to a DOS/Windows-style path,
e.g. /cygdrive/c/Windows becomes c:/Windows.


=item 10i.  OBJ->wslhome

Determine the host location of the WSL user home.
Returns undef if the current process is not executing within a WSL context.


=item 10j.  OBJ->wslroot

Determine the host's directory location of the current WSL distribution root.


=item 5e.  OBJ->home

Read-only method advises a generally failsafe home directory for user.


=item 9b.  OBJ->extant(PATH)

Checks if the file specified by PATH exists. Subject to fatal processing.

=back

=cut

use strict;

use parent 'Batch::Exec';

# --- includes ---
use Carp qw(cluck confess);
use Data::Dumper;

require File::HomeDir;
require Path::Class;
require Path::Tiny;

#use Log::Log4perl qw(:levels);	# debugging


# --- package constants ---
use constant ENV_WSL_DISTRO => $ENV{'WSL_DISTRO_NAME'};

use constant DN_MOUNT_WSL => "/mnt";
use constant DN_MOUNT_CYG => "/cygdrive";
use constant DN_ROOT_WSL => '//wsl$';	# this is a WSL location only

use constant RE_DELIM_U => qr[\/];	# the forward-slash regexp for unix
use constant RE_DELIM_W => qr[\\];	# the back-slash regexp for windows
use constant RE_SHELLIFY => qr=[\s\$\\\/\']=;	# norty characters for shells

use constant STR_DELIM_U => '/';	# the forward-slash for unix
use constant STR_DELIM_W => '\\';	# the back-slash for windows



# --- package globals ---
our $AUTOLOAD;
#our @EXPORT = qw();
#our @ISA = qw(Exporter);
our @ISA;
our $VERSION = '0.001';


# --- package locals ---
my $_n_objects = 0;

my %_attribute = (	# _attributes are restricted; no direct get/set
	_home => undef,		# a reliable version of user's home directory
	behaviour => undef,	# platform-dependent default, one of: w, u.
	converted => undef,	# a normalised, cleansed and converted path
	deu => STR_DELIM_U,
	dew => STR_DELIM_W,
	normal => undef,	# the normalised path
	parts => undef,		# the constituent components of the path
	raw => undef,		# the raw path passed into a parse function
	res => RE_SHELLIFY,
	reu => RE_DELIM_U,
	rew => RE_DELIM_W,
	root => undef,		# placeholder for root component
	shellify => 0,		# converts \ to \\ for DOS-like shell exits
	volume => undef,	# placeholder for volume component
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
	local($., $@, $!, $^E, $?);
	my $self = shift;

	#printf "DEBUG destroy object id [%s]\n", $self->{'_id'});

	-- ${ $self->{_n_objects} };
}


sub new {
	my ($class) = shift;
	my %args = @_;	# parameters passed via a hash structure

	my $self = $class->SUPER::new;	# for sub-class
	my %attr = ('_have' => { map{$_ => ($_ =~ /^_/) ? 0 : 1 } keys(%_attribute) }, %_attribute);

	bless ($self, $class);

	map { push @{$self->{'_inherent'}}, $_ if ($attr{"_have"}->{$_}) } keys %{ $attr{"_have"} };

	while (my ($attr, $dfl) = each %attr) { 

		unless (exists $self->{$attr} || $attr eq '_have') {
			$self->{$attr} = $dfl;
			$self->{'_have'}->{$attr} = $attr{'_have'}->{$attr};
		}
	}

	$self->behaviour(($self->on_windows) ? "w" : "u");
	$self->home;

	while (my ($method, $value) = each %args) {

		confess "SYNTAX new(, ...) value not specified"
			unless (defined $value);

		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	# ___ additional class initialisation here ___

	return $self;
}


sub _wslroot {	# determine the host location of the WSL distro root raw value
	my $self = shift;

	return undef unless ($self->on_wsl);

	my $pt = path("/" . DN_ROOT_WSL)->child(ENV_WSL_DISTRO);

	my $dn = $pt->canonpath;

	$self->log->debug("dn [$dn]");

	return $dn;
}


sub extant {
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX: extant(EXPR)" unless defined ($pn);

	return 1
		if (-e $pn);

	$self->cough("does not exist [$pn]");

	return 0;	# reverse polarity
}


sub slash { # based on expected behaviour optionally convert / to \\
	my $self = shift;
#	if (@_) { $self->converted(shift) };

	confess "SYNTAX: slash(EXPR)" unless defined($self->converted);

	my $pni = $self->converted;

	$self->log->debug("pni [$pni]");

	my $lei = length($pni);
	my $pno = $pni;
	my $de = ($self->behaviour eq 'u') ?  $self->deu : $self->dew;
	my $reu = $self->reu;

	$pno =~ s/$reu/$de/g;

	my $lno = length($pno);

	$self->log->debug("lei [$lei] pni [$pni] lno [$lno] pno [$pno]");

	$self->cough("slashed length [$lei] differs from [$lno]")
		if ($lno != $lei);

	return $pno unless ($self->shellify);

	my $res = $self->res;
	$pno =~ s/$res/\\$&/g;

	$self->log->debug("slashed pno [$pno]");

	$lno = length($pno);

	$self->cough("slashed length [$lei] less than [$lno]")
		if ($lno < $lei);

	return $pno;
}


sub home {	# provide a value for a home directory
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


sub catdir {	# split a DOS or path into tokens and return array
	my $self = shift;
	confess "SYNTAX: catdir(EXPR, EXPR)" unless (@_);

	my @dn = $self->splitdir(@_);

	use Path::Class;

	my $pn = join('/', @dn);

	my $pc = file($pn);	# Path::Class constructor
	my $dos = $pc->as_foreign('Win32');

	$self->log->debug("dos [$dos]");


	my $dn = join('\\', @dn);

	$self->log->debug(sprintf "dn [$dn] dn [%s]", Dumper(\@dn));

	return $self->slash($dn);
}


sub parse {
	my $self = shift;
	my $pn = shift;
	confess "SYNTAX: parse(PATH)" unless defined ($pn);

	return $pn unless ($self->like_windows);

	return $pn if ($self->on_windows);

	my @pn = $self->splitdir($pn);

	return $pn unless (@pn);

	my $drive = lc(shift @pn);

	$self->log->warn("unusual drive letter [$drive]")
		unless ($drive =~ /[a-z]:/i);

	$drive =~ s/://g;

	$pn = File::Spec->catdir("", $self->tld, $drive, @pn);

	$self->log->debug("pn [$pn]");

	return $pn;
}


sub normalise {	# normalise a path to consistent unix-format
	my $self = shift;
	my $pni = shift;
	confess "SYNTAX: normalise(PATH, ...)" unless (defined $pni);

	$self->raw($pni);

	my $lei = length($pni);
	my $pno = $pni;
	my $deu = $self->deu;
	my $rew = $self->rew;

	$pno =~ s/$rew/$deu/g;

	my $lno = length($pno);

	$self->log->debug("lei [$lei] pni [$pni] lno [$lno] pno [$pno]");

	$self->cough("normalised length [$lei] differs from [$lno]")
		if ($lno != $lei);

	$self->normal($pno);

	return $pno;
}


sub splitter {	# normalise a path to unix delimeters and split into components
	my $self = shift;
	my $pni = shift;
	confess "SYNTAX: splitter(PATH)" unless defined($pni);

	# cannot use File::Spec->splitdir as cygwin paths are unix-like
	# and we may want to explicitly convert windows-like paths
	# note that Path::Tiny thinks c:\temp is relative to the CWD and is a file!
	my $reu = $self->reu;

	my @pn = split(/$reu/, $self->normalise($pni));

	$self->log->debug(sprintf "pn [%s]", Dumper(\@pn));

	$self->parts([ @pn ]);

	return @pn;
}


sub splitdir {	# split a path into tokens and return array
	my $self = shift;
	my $pni = shift;
	confess "SYNTAX: splitdir(PATH)" unless defined($pni);

	my @dn = $self->splitter($pni);

	if ($dn[0] =~ /:/) {	# a DOS drive letter and thus root directory

		my $prepend = $self->tld;

		if (defined $prepend) {

			$dn[0] = lc $dn[0];
			$dn[0] =~ s/://;

			unshift @dn, "", $prepend;
		}
	} elsif ($dn[0] =~ /\$/) {	# DOS special drive, possibly share

		unshift @dn, "";
	}

	my $dn = join('/', @dn);

	# Path::Tiny which gets rid of rubbish duplicates
	my $pn = path($dn);	# a Path::Tiny object now only forward slashes

	$self->log->debug(sprintf "canonpath [%s]", $pn->canonpath);
	$self->log->debug(sprintf "absolute [%s]", $pn->absolute);

#	@dn = split(/$re/, $pn->canonpath);

	$self->log->debug(sprintf "dn [%s]", Dumper(\@dn));

	return @dn;
}


sub tld {	# determine the mountpoint for hybrid OS
	my $self = shift;

	my $mount; if ($self->on_cygwin) {

		$mount = DN_MOUNT_CYG;

	} elsif ($self->on_wsl) {

		$mount = DN_MOUNT_WSL;

#	} elsif ($self->on_linux) {

#		$mount = '/';

#	} elsif ($self->on_windows) {

#		$mount = '\\';
	} else {
		$mount = '/';
#		$self->cough("unable to determine platform [$^O]");
	}

	return $mount;
}


sub winpath {
	my $self = shift;
	my $pn = shift;
	my $convert = shift;
	confess "SYNTAX: winpath(PATH, [EXPR])" unless defined ($pn);

	return $pn unless ($self->like_windows);

	return $pn if ($self->on_windows);

	my @pn = $self->splitdir($pn);

	return $pn unless (@pn);

	my $mount = $self->tld;

	if ($self->on_cygwin || $self->on_wsl) {

		# example input paths:
		#  /cygdrive/c/xxx
		#  //hostname/xxx
		#  xxx			will not get this far!
		#  /root/xxx

		if ($pn =~ /$mount/) {	# this looks like a drive

			shift @pn 	# remove the root prefix
				if ($self->is_blank($pn[0]));

			my $drive = ""; if ($pn[0] =~ /^$mount$/i) {

				shift @pn;	# remove the cygdrive bit

				$drive = uc(shift @pn) . ':';
			}

			$self->log->warn("unusual drive letter [$drive]")
				unless ($drive =~ /[a-z]:/i);

			$pn = $self->catdir($drive, @pn);

		} else {
			$pn = $self->catdir(@pn);
		}
	}
	return $self->slash($pn);
}


sub wslhome {	# determine the host location of the WSL user home
	my $self = shift;

	return undef unless ($self->on_wsl);

#	Slash actually works natively in Powershell: //wsl$/Ubuntu/home/jbloggs
#	However, not sure we need this context so use Windows-friendly
#	backslashes, i.e. \\wsl$\Ubuntu\home\jbloggs

	#return $self->slash($self->winpath($self->wslroot . '\\' . $self->home)) ;
	my @dnh = $self->splitdir($self->home); # e.g. /home/jbloggs
	$self->log->debug(sprintf "dnh [%s]", Dumper(\@dnh));

	shift @dnh;	# get rid of the root prefix, e.g. home/jbloggs

	my $dn = join('/', $self->_wslroot, @dnh);

	my @dn = $self->splitdir($dn);

	$dn = $self->catdir(@dn);

	return $self->slash($dn);
}


sub wslroot {	# determine the host location of the WSL distro root
	my $self = shift;

	return undef unless ($self->on_wsl);

	return $self->slash($self->_wslroot);
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

