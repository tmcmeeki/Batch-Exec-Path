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

$harness->planned(15);
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


exit -1;
# -------- slash --------
my $pn_rel = "foo/bar";

my $ou = Batch::Exec::Path->new('behaviour' => 'u');
is($ou->behaviour, 'u',			$harness->cond("override behaviour"));
for my $pn ($harness->all_paths) {

	$ou->slash($pn);
}
exit -1;


my $ow = Batch::Exec::Path->new('behaviour' => 'w');
is($ow->behaviour, 'w',			$harness->cond("override behaviour"));

isnt($ou->slash($pn_rel), $ow->slash($pn_rel),	"slash differs with behaviour");


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

