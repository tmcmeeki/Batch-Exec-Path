#!/usr/bin/perl
#
# 00_basic.t - test harness for the Batch::Exec::Path.pm module: basics
#
use strict;

use Data::Dumper;
use Test::More; # tests => 45;
use lib 't';
use Harness;



# -------- constants --------


# -------- global variables --------
my $harn = Harness->new('Batch::Exec::Path');
my $log = $harn->log;


# -------- main --------
$harn->planned(126);

use_ok($harn->this);

my $obp = Batch::Exec->new;
isa_ok($obp, "Batch::Exec",		$harn->cond("class check parent"));

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harn->this,		$harn->cond("class check"));

my $o2 = Batch::Exec::Path->new;
isa_ok($o2, $harn->this,		$harn->cond("class check"));


# -------- attributes --------
my @cttr = $o1->Attributes;
my @pttr = $obp->Attributes;
is(scalar(@cttr) - scalar(@pttr), 22,	$harn->cond("class attributes"));
is(shift @cttr, 'Batch::Exec::Path',	$harn->cond("class okay"));

for my $attr (@cttr) {

	my $dfl = $o1->$attr;

	next if (ref($dfl) ne "");	# skip attributes which aren't scalars

	my ($set, $type); if (defined $dfl && $dfl =~ /^[\-\d\.]+$/) {
		$set = -1.1;
		$type = "f`";
	} else {
		$set = "_dummy_";
		$type = "s";
	}

	is($o1->$attr($set), $set,	$harn->cond("$attr set"));
	isnt($o1->$attr, $dfl,		$harn->cond("$attr check"));

	$log->debug(sprintf "attr [$attr]=%s", $o1->$attr);

	if ($type eq "s") {
		my $ck = (defined $dfl) ? $dfl : "_null_";

		ok($o1->$attr ne $ck, 	$harn->cond("$attr string"));
	} else {
		ok($o1->$attr < 0,	$harn->cond("$attr number"));
	}
	is($o1->$attr($dfl), $dfl,	$harn->cond("$attr reset"));
}


# -------- behaviour defaults --------
like($o1->behaviour, qr/[uw]/,	$harn->cond("valid behaviour defined"));

if ($o1->on_windows) {
	is($o1->behaviour, "w",	$harn->cond("windows behaviour on_windows"));

} else {
	is($o1->behaviour, "u",	$harn->cond("unix behaviour off windows"));
}

if ($o1->like_windows) {

	my $lp = ($o1->on_cygwin || $o1->on_wsl) ? 'u' : 'w';
	
	is($o1->behaviour, $lp,	$harn->cond("$lp behaviour like_windows"));
} else {
	is($o1->behaviour, "u",	$harn->cond("unix behaviour unlike windows"));
}

if ($o1->like_unix) {
	is($o1->behaviour, "u",	$harn->cond("unix behaviour like_unix"));
} else {
	is($o1->behaviour, "w",	$harn->cond("windows behaviour unlike unix"));
}


# -------- home --------
my $reh = qr/(home|users)/i;

isnt($o2->home, "",			$harn->cond("home defined"));
like($o2->home, $reh,			$harn->cond("home matches"));

is($o2->home("foo"), "foo",		$harn->cond("home override set"));
is($o2->home, "foo",			$harn->cond("home override query"));
like($o2->home(undef), $reh,		$harn->cond("home default"));

$log->info(sprintf "HOME is [%s]", $o2->home);

$harn->cwul($o1, "home", qr/cygdrive/, qr/Users/, qr/home/, qr/home/);


# -------- extant --------
is(-d ".", $o2->extant(".", 'd'),			$harn->cond("dot extant"));
is(-d $o2->dn_start, $o2->extant($o2->dn_start, 'd'),	$harn->cond("dn_start extant"));
is(-d $o2->home, $o2->extant($o2->home, 'd'),		$harn->cond("home extant"));


# -------- winhome --------
isnt($o2->winhome, "",			$harn->cond("winhome non-blank"));
like($o2->winhome, qr/\w+:/,		$harn->cond("winhome regexp"));


#-------- winuser --------
#isnt($o2->winuser, undef,	$harn->cond("winuser simple"));
my $re_wu = qr/\w+/;
$harn->cwul($o2, "winuser", $re_wu, $re_wu, $re_wu, $re_wu);


__END__

=head1 DESCRIPTION

00_basic.t - test harness for the Batch::Exec::Path.pm module: basics

=head1 VERSION

_IDE_REVISION_

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

