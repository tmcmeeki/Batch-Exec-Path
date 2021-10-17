#!/usr/bin/perl
#
# 01primitive.t - test harness for the Batch::Exec::Path.pm module: primitives
#
use strict;

#use Data::Compare;
use Data::Dumper;
use Log::Log4perl qw/ :easy /;
#use Logfer qw/ :all /;


# ---- test harness ----
#use Test::More tests => 68;
use Test::More;
use lib 't';
use Harness;


#BEGIN { use_ok('Batch::Exec::Path') };
my $harness = Harness->new('Batch::Exec::Path');

$harness->planned(256);
use_ok($harness->this);
#require_ok($harness->this);


# -------- constants --------
#use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
#Log::Log4perl->easy_init($ERROR);
Log::Log4perl->easy_init($DEBUG);
my $log = get_logger(__FILE__);


# -------- main --------
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harness->this,	"class check $cycle"); $cycle++;


# -------- home and overrides --------
my $reh = qr/(home|users)/i;
isnt($o1->home, "",			"home defined");
like($o1->home, $reh,			"home matches");

is($o1->home("foo"), "foo",		"home override set");
is($o1->home, "foo",			"home override query");
like($o1->home(undef), $reh,		"home default");


# -------- extant --------
is(-d ".", $o1->extant("."),				"dot extant");
is(-d $o1->dn_start, $o1->extant($o1->dn_start),	"dn_start extant");
is(-d $o1->home, $o1->extant($o1->home),		"home extant");


# -------- wsl-related --------
if ($o1->on_wsl) {

	like($o1->_wslroot, qr/wsl/,	"_wslroot defined");
	is($o1->tld, "/mnt",		"default tld");

} elsif ($o1->on_cygwin) {

	like($o1->_wslroot, qr/wsl/,	"_wslroot defined");
	is($o1->tld, "/cygwin",		"default tld");
} else {
	is($o1->_wslroot, undef,	"_wslroot undefined");
	is($o1->tld, "/",		"default tld");
}


$log->info(sprintf "HOME is [%s]", $o1->home);


# -------- normalise --------
for my $pn ($harness->all_paths) {
	my $o2 = Batch::Exec::Path->new;
	my $re = $o2->reu;

	like($o2->normalise($pn), $re,	$harness->cond("normalised to unix"));

	is($o2->raw, $pn,		$harness->cond("normalised raw"));

	isnt($o2->normal, "",		$harness->cond("normalised normal"));

	$o2 = ();
}


# -------- splitter --------
for my $pn ($harness->all_paths) {

	my $o3 = Batch::Exec::Path->new;

	my @pn = $o3->splitter($pn);

	ok(@pn >= 1, 			$harness->cond("splitter gt zero"));

	isnt($o3->raw, "", 		$harness->cond("raw not null"));

	is_deeply($o3->parts, \@pn,	$harness->cond("parts count"));

	$o3 = ();
}


# -------- slash and shellify: unix behaviour --------
my $os0 = Batch::Exec::Path->new('shellify' => 0);
is($os0->shellify, 0,			$harness->cond("shellify off"));

my $os1 = Batch::Exec::Path->new('shellify' => 1);
is($os1->shellify, 1,			$harness->cond("shellify on"));

$os0->behaviour('u');
$os1->behaviour('u');
is($os0->behaviour, 'u',		$harness->cond("behaviour unix"));
is($os0->behaviour, $os1->behaviour,	$harness->cond("behaviour match"));

my %uxp = (	# first = path (unmodified), second = slash result
	'foo' => 'foo',
	'foo bar' => q{foo\ bar},
	'foo/bar' => q{foo\/bar},
	'/foo/bar' => q{\/foo\/bar},
	'/foo/bar/' => q{\/foo\/bar\/},
	q{foo'bar} => q{foo\'bar},
	'/fu/man/chu' => q{\/fu\/man\/chu},
	' fu man chu ' => q{\ fu\ man\ chu\ },
);
while (my ($normal, $slash) = each %uxp) {

	is($os0->slash($normal), $normal,	$harness->cond("slash shellify off"));

	is($os1->slash($normal), $slash,	$harness->cond("slash shellify on"));
}


# -------- slash and shellify: windows behaviour --------
$os0->behaviour('w');
$os1->behaviour('w');
is($os0->behaviour, 'w',		$harness->cond("behaviour wind"));
is($os0->behaviour, $os1->behaviour,	$harness->cond("behaviour match"));

my $obs = ord("\\");	# windows backslash
my $ofs = ord("/");	# windows backslash

$harness->log->debug("obs [$obs] ofs [$ofs]");

while (my ($unix, $slash) = each %uxp) {

	my $normal = $harness->fs2bs($unix);

	is(length($normal), length($unix),	$harness->cond("fs2bs length"));

	is($os0->slash($normal), $normal,	$harness->cond("slash shellify off"));

	is($os1->slash($normal), $slash,	$harness->cond("slash shellify on"));
}


__END__

=head1 DESCRIPTION

01primitive.t - test harness for the Batch::Exec::Path.pm module: primitives

=head1 VERSION

___EUMM_VERSION___

=head1 AUTHOR

B<Tom McMeekin> tmcmeeki@cpan.org

=head1 LICENSE

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation; either version 2 of the License,
or any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

=head1 SEE ALSO

L<perl>, L<Batch::Exec::Path>.

=cut

