package Harness;
#########################
# This module assist in testing the Path functions, by having pre-defined
# directory names
#
# Harness.pm - test harness for module Batch::Exec::Path
# Version: ___EUMM_VERSION___
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published
# by the Free Software Foundation; either version 2 of the License,
# or any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
#########################
use strict;
use warnings;

use Carp qw(cluck confess);     # only use stack backtrace within class
use Data::Dumper;
#use Log::Log4perl qw/ :easy /;
use Logfer qw/ :all /;
use Test::More;

our $AUTOLOAD;

my %attribute = (
	_header => undef,
	_path => undef,
	_planned => 0,
	_cycle => { 'default' => 0 },
	executed => 0,
	log => get_logger(__FILE__),
	msg => 'field [%s] does not exist in hash [%s]',
	obs => ord("\\"),	# windows backslash
	ofs => ord("/"),	# unix [forward]slash
	osp => ord(" "),
	osq => ord("'"),
	this => undef,
);


sub AUTOLOAD {
	my $self = shift;
	my $type = ref($self) or confess "$self is not an object";

	my $name = $AUTOLOAD;
	$name =~ s/.*://;   # strip fully−qualified portion

	unless (exists $self->{_permitted}->{$name} ) {
		confess "no attribute [$name] in class [$type]";
	}

	if (@_) {
		return $self->{$name} = shift;
	} else {
		return $self->{$name};
	}
}


sub new {
	my ($class) = shift;
	my ($test_class) = shift;
	my $self = { _permitted => \%attribute, %attribute };

	bless ($self, $class);

	confess "SYNTAX new(TEST_CLASS) value not specified" unless (defined $test_class);

	my %args = @_;  # start processing any parameters passed
	my ($method,$value);
	while (($method, $value) = each %args) {

		confess "SYNTAX new(method => value, ...) value not specified"
			unless (defined $value);

#		$self->log->debug("method [self->$method($value)]");

		$self->$method($value);
	}
	$self->{'this'} = $test_class;
	$self->{'_path'} = $self->parse_me;

	return $self;
}


sub poll {
	my $self = shift; 
	my $what = shift;

	$what = "default" unless defined($what);

	$self->logconfess("blank cycle label") if ($what =~ /^$/);

	$self->{'_cycle'}->{$what} = 0
		unless exists($self->{'_cycle'}->{$what});

	my $cycle = $self->{'_cycle'}->{$what};

	$self->log->trace("what [$what] cycle [$cycle]");

	return ($what, $cycle);
}


sub cycle {
	my $self = shift; 

	my ($what, $cycle) = $self->poll(shift);

	++$cycle;

	$self->{'_cycle'}->{$what} = $cycle;

	$self->log->trace(sprintf "_cycle [%s]", Dumper($self->{'_cycle'}));

	return $cycle;
}


sub cond {
	my $self = shift; 

	my ($what, undef) = $self->poll(shift);

	my $cycle = $self->cycle($what);

	my $cond = "$what cycle=$cycle";

	return $cond;
}


sub done {
	my $self = shift; 
	my $extra = shift;
 
	$self->{'executed'} += $extra
		if (defined $extra);

	done_testing($self->executed);
}


sub planned {
	my $self = shift;
	my $n_tests = shift;

	confess "SYNTAX: plan(tests)" unless defined ($n_tests);

	$self->_planned($n_tests);

	plan tests => $n_tests;
}


sub parse_me {
	my $self = shift;
#	confess "SYNTAX: parse_me(tests)" unless defined ($n_tests);

	my $pn = __FILE__;
	$self->log->trace("reading lines from pn [$pn]");

	open(my $fh, "<$pn") || $self->logcroak("open($pn) failed");

	my @path;

	my $ok = 0; while (<$fh>) {

		next if ($_ =~ /^$/);

		if ($_ =~ /^__END__/) {

			$ok = 1;
			next;
		}
		next unless($ok);

		chomp; $self->log->trace("$_");

		my $header = ($_ =~ /^#/) ? 1 : 0;
		my @values = split(/[#=]/, $_);

		$self->log->trace(sprintf "@values [%s]", Dumper(\@values));

		if ($header) {
			shift @values;
			$self->_header([ @values ]);
			next;
		}

		confess("no header defined") unless defined($self->_header);

		my %rec; map { $rec{$_} = shift @values; } @{ $self->_header };
		push @path, { %rec };
	}
	close($fh);

	$self->log->trace(sprintf "path [%s]", Dumper(\@path));

	$self->_path([ @path ]);
}


sub all {
	my $self = shift;

	confess "FATAL: no paths defined" unless defined($self->_path);

	my @all; for my $in (@{ $self->_path }) {

		if (@_) {
			my %rec = map { $_ => $self->select($in, $_); } @_;

			push @all, { %rec };
		} else {
			push @all, $in;
		}
	}
	$self->log->trace(sprintf "all [%s]", Dumper(\@all));

	return @all;
}


sub select {
	my $self = shift;
	my $rh = shift;
	my $field = shift;

	confess "SYNTAX: select(HASHREF, EXPR)" unless (
		defined($rh) && ref($rh) eq 'HASH' && defined($field));

	$self->log->logconfess(sprintf $self->msg, $field, Dumper($rh))
		unless exists ($rh->{$field});

	return $rh->{$field};
}


sub filter {
	my $self = shift;
	my $field = shift;
	my $wanted = shift;
	confess "SYNTAX: filter(EXPR, EXPR)" unless (
		defined ($field) && defined ($field));

	confess "FATAL: no paths defined" unless defined($self->_path);

#	my @match; while (my ($pn, $status) = each %{ $self->_path }) {

	my @match; for ($self->all) {

		my $value = $self->select($_, $field);

		push @match, $_ if ($wanted eq $value);
	}
	$self->log->trace(sprintf "match [%s]", Dumper(\@match));

	return @match;
}


sub invalid {
	my $self = shift;

	return $self->filter("valid", 0); # valid flag is OFF
}


sub valid {
	my $self = shift;

	return $self->filter("valid", 1); # valid flag is ON
}


sub all_paths {
	my $self = shift;

	my @paths; for ($self->all('path')) {

		push @paths, values %$_;
	}

	return @paths;
}


sub fs2bs {	# byte-level conversion of forward-slash to back-slash
	my $self = shift;
	my $str = shift;
	confess "SYNTAX: fs2bs(EXPR)" unless defined($str);
	my $shell = shift; $shell = 0 unless defined($shell);
	# if true, shell will insert a backslash

	my $obs = $self->obs;
	my $ofs = $self->ofs;
	my $osp = $self->osp;
	my $osq = $self->osq;

	$self->log->trace("obs [$obs] ofs [$ofs]");

	my @str = unpack "C*", $str;

	$self->log->trace(sprintf "str [$str] str [%s]", Dumper(\@str));

	my @new; for my $c (@str) {

		if ( $c == $ofs || $c == $osp || $c == $osq ) {
			push @new, $obs		# insert shellified backslash
				if ($shell);
		}

		if ($c == $ofs) {
			push @new, $obs;	# convert slash to backslash
		} else {
			push @new, $c;
		}
	}

#	for (my $i = 0; $i < @str; $i++) {
#
#		$str[$i] = $obs if ($str[$i] == $ofs);
#	}
#
#	$str = pack "C*", @str;
	$str = pack "C*", @new;

	$self->log->trace(sprintf "str [$str] new [%s]", Dumper(\@new));

	return $str;
}


DESTROY {
        my $self = shift;

};

#END { }

1;

__END__

#valid=abs=volume=root=levels=path
1=1=none=/=0=/
1=1=none=/=1=/tmp
1=1=none=/=2=/root/xxx
1=1=none=/=1=.
1=0=none=none=1=foo
1=0=none=none=2=foo/bar
1=0=none=none=1=./bar
1=0=none=none=2=./foo/bar
1=1=none=none=1=~
1=1=none=none=1=~/tmp
1=1=hostname=/=1=//hostname/xxx
1=1=server=/=1=//server/Temp03b
1=1=c=/=2=/cygdrive/c/windows/temp08
1=1=c=/=1=/cygdrive/c/xxx
1=1=d=/=2=/cygdrive/d/Users/abc
1=1=none=/=2=/dir/xxx
1=1=c=/=2=/mnt/c//windows/temp06
1=1=d=/=2=/mnt/d/Users/abc
1=1=C=\=2=C:\Users\abc
1=1=D=\=2=D:\Users\abc
1=1=C=/=1=C:/Temp01
1=1=C=\=1=C:\Temp00
1=1=server=\=1=\\\\server\\Temp05
1=1=hostname=\=1=\\hostname\xxx
1=1=server=\=1=\\server\Temp03a
1=1=server=\=1=\\server\\Temp04
1=1=wsl$=\=3=\\wsl$\Ubuntu\home\tomby
1=1=none=\=2=\mnt\c\window\temp07
0=1=9=\=1=/cygdrive/9/hello.txt
0=1=1=\=1=1:\hello.txt
1=1=this=\=3=\\\\\\\\this\\\is\\wierd\\\\now
0=1=none=\=1=\server\Temp02
0=1=none=none=4=this/path has/some spaces/and'apostrophe
