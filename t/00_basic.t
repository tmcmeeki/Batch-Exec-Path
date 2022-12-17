#!/usr/bin/perl
#
# 00basic.t - test harness for the Batch::Exec::Path.pm module: basics
#
use strict;

#use Data::Compare;
use Data::Dumper;
use Log::Log4perl qw/ :easy /;
#use Logfer qw/ :all /;
use Test::More tests => 123;

BEGIN { use_ok('Batch::Exec::Path') };


# -------- constants --------
#use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
Log::Log4perl->easy_init($ERROR);
#Log::Log4perl->easy_init($DEBUG);
my $log = get_logger(__FILE__);


# -------- main --------
my $cycle = 1;

my $obc = Batch::Exec::Path->new;
isa_ok($obc, "Batch::Exec::Path",	"class check $cycle"); $cycle++;

my $obp = Batch::Exec->new;
isa_ok($obp, "Batch::Exec",		"class check $cycle"); $cycle++;

#$log->debug(sprintf "obc [%s]", Dumper($obc));


# -------- attributes --------
my @cttr = $obc->Attributes;
my @pttr = $obp->Attributes;
is(scalar(@cttr) - scalar(@pttr), 20,	"class attributes");
is(shift @cttr, 'Batch::Exec::Path',	"class okay");

for my $attr (@cttr) {

	my $dfl = $obc->$attr;

	next if (ref($dfl) ne "");	# skip attributes which aren't scalars

	my ($set, $type); if (defined $dfl && $dfl =~ /^[\-\d\.]+$/) {
		$set = -1.1;
		$type = "f`";
	} else {
		$set = "_dummy_";
		$type = "s";
	}

	is($obc->$attr($set), $set,	"$attr set cycle $cycle");
	isnt($obc->$attr, $dfl,	"$attr check cycle $cycle");

	$log->debug(sprintf "attr [$attr]=%s", $obc->$attr);

	if ($type eq "s") {
		my $ck = (defined $dfl) ? $dfl : "_null_";

		ok($obc->$attr ne $ck, "$attr string cycle $cycle");
	} else {
		ok($obc->$attr < 0,	"$attr number cycle $cycle");
	}
	is($obc->$attr($dfl), $dfl,	"$attr reset cycle $cycle");

        $cycle++;
}


# -------- behaviour defaults --------
like($obc->behaviour, qr/[uw]/,		"valid behaviour defined");

if ($obc->on_windows) {
	is($obc->behaviour, "w",	"windows behaviour on_windows");

} else {
	is($obc->behaviour, "u",	"unix behaviour off windows");
}

if ($obc->like_windows) {

	my $like = ($obc->on_cygwin || $obc->on_wsl) ? 'u' : 'w';
	
	is($obc->behaviour, $like,	"$like-like behaviour like_windows");
} else {
	is($obc->behaviour, "u",	"unix behaviour unlike windows");
}

if ($obc->like_unix) {
	is($obc->behaviour, "u",	"unix behaviour like_unix");
} else {
	is($obc->behaviour, "w",	"windows behaviour unlike unix");
}


# -------- home --------
my $o1 = Batch::Exec::Path->new;
isa_ok($o1, "Batch::Exec::Path",	"class check $cycle"); $cycle++;

my $reh = qr/(home|users)/i;

isnt($o1->home, "",			"home defined");
like($o1->home, $reh,			"home matches");

is($o1->home("foo"), "foo",		"home override set");
is($o1->home, "foo",			"home override query");
like($o1->home(undef), $reh,		"home default");

$log->info(sprintf "HOME is [%s]", $o1->home);


# -------- extant --------
is(-d ".", $o1->extant(".", 'd'),			"dot extant");
is(-d $o1->dn_start, $o1->extant($o1->dn_start, 'd'),	"dn_start extant");
is(-d $o1->home, $o1->extant($o1->home, 'd'),		"home extant");


# -------- tld --------
if ($o1->on_wsl) {

	$log->info("platform: WSL");

	is($o1->tld, "/mnt",		"default tld");

} elsif ($o1->on_cygwin) {

	$log->info("platform: CYGWIN");

	is($o1->tld, "/cygdrive",	"default tld");

} else {

	$log->info("platform: OTHER");

	is($o1->tld, "/",		"default tld");
}


__END__

=head1 DESCRIPTION

00basic.t - test harness for the Batch::Exec::Path.pm module: basics

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

