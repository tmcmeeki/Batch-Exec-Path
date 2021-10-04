#!/usr/bin/perl
#
# 00basic::Exec::Path-2.t - test harness for the Batch::Exec::Path.pm module: pathnames
#
use strict;

use Data::Compare;
use Data::Dumper;
use Logfer qw/ :all /;
use Test::More tests => 45;

BEGIN { use_ok('Batch::Exec::Path') };


# -------- constants --------
#use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
my $log = get_logger(__FILE__);


# -------- main --------
my $cycle = 1;

my $obc1 = Batch::Exec::Path->new;
isa_ok($obc1, "Batch::Exec::Path",	"class check $cycle"); $cycle++;

my $objp = Batch::Exec->new;
isa_ok($objp, "Batch::Exec",	"class check $cycle"); $cycle++;


# -------- attributes --------
my @cttr = $obc1->Attributes;
my @pttr = $objp->Attributes;
is(scalar(@cttr) - scalar(@pttr), 5,	"class attributes");
is(shift @cttr, 'Batch::Exec::Path',	"class okay");

for my $attr (@cttr) {

	my $dfl = $obc1->$attr;

	my ($set, $type); if (defined $dfl && $dfl =~ /^[\-\d\.]+$/) {
		$set = -1.1;
		$type = "f`";
	} else {
		$set = "_dummy_";
		$type = "s";
	}

	is($obc1->$attr($set), $set,	"$attr set cycle $cycle");
	isnt($obc1->$attr, $dfl,	"$attr check cycle $cycle");

	$log->debug(sprintf "attr [$attr]=%s", $obc1->$attr);

	if ($type eq "s") {
		my $ck = (defined $dfl) ? $dfl : "_null_";

		ok($obc1->$attr ne $ck, "$attr string cycle $cycle");
	} else {
		ok($obc1->$attr < 0,	"$attr number cycle $cycle");
	}
	is($obc1->$attr($dfl), $dfl,	"$attr reset cycle $cycle");

        $cycle++;
}


# -------- Inherit --------
my $obb1 = Batch::Exec->new;
my $obb2 = Batch::Exec->new('null' => "bar");
isa_ok( $obb1, "Batch::Exec",		"new no args");
isa_ok( $obb2, "Batch::Exec",		"new no args");

is($obc1->null, "Batch::Exec",	"null default");
is($obj2->null, "foo",	"null override");
is($obb1->null, "Batch::Exec",	"check null");
is($obb2->null("bar"), "bar",	"check null");

my @attb = $obb1->Attributes;	shift @attb;
$log->debug(sprintf "Batch::Exec attr [%s]", Dumper(\@attb));
my $cpa = scalar(@attb);
# fatal	$obc1->Inherit;
is($obc1->Inherit($obb1), $cpa,	"inherit attribute count similar");
is($obc1->null, "Batch::Exec",	"inherit ineffective attribute change");
is($obj2->Inherit($obb2), $cpa,	"inherit attribute count disparate");
is($obj2->null, $obb2->null,	"inherit effective attribute change");
for my $attr (@attb) {
	is($obc1->$attr, $obb1->$attr,	"first attribute match cycle $cycle");
	is($obj2->$attr, $obb2->$attr,	"second attribute match cycle $cycle");

	$cycle++;
}

__END__

=head1 DESCRIPTION

00basic.t - test harness for the Batch::Exec::Path.pm module: pathnames

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

