package Harness;
#########################
# This module assist in testing the Path functions, by having pre-defined
# directory names
#
# Harness.pm - test harness for module Batch::Exec::Path
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
use Log::Log4perl qw/ :easy /;
use Test::More;

our $AUTOLOAD;

my %attribute = (
	_header => undef,
	_path => undef,
	_planned => 0,
	_cycle => { 'default' => 0 },
	dummy => "IGNORE overidden dummy exit routine\n",
	executed => 0,
	log => get_logger(__FILE__),
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
	$self->{'_path'} = $self->paths;

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


sub paths {
	my $self = shift;
#	confess "SYNTAX: paths(tests)" unless defined ($n_tests);

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


sub filter {
	my $self = shift;
	my $field = shift;
	my $value = shift;
	confess "SYNTAX: filter(EXPR, EXPR)" unless (
		defined ($field) && defined ($field));

	confess "FATAL: no paths defined" unless defined($self->_path);

	my $msg = 'field [%s] does not exist in hash [%s]';
#	my @match; while (my ($pn, $status) = each %{ $self->_path }) {

	my @match; for (@{ $self->_path }) {

		$self->log->logconfess(sprintf $msg, $field, Dumper($_))
			unless exists ($_->{$field});

		push @match, $_ if ($_->{$field} eq $value);
	}
	$self->log->trace(sprintf "match [%s]", Dumper(\@match));

	return @match;
}


sub invalid {
	my $self = shift;

	return $self->filter("valid", 0);
}


sub valid {
	my $self = shift;

	return $self->filter("valid", 1);
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