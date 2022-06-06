#!/usr/bin/perl
#
# 01_primitive.t - test harness for the Batch::Exec::Path.pm module: primitives
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


# -------- home --------
my $reh = qr/(home|users)/i;
isnt($o1->home, "",			"home defined");
like($o1->home, $reh,			"home matches");

is($o1->home("foo"), "foo",		"home override set");
is($o1->home, "foo",			"home override query");
like($o1->home(undef), $reh,		"home default");

$log->info(sprintf "HOME is [%s]", $o1->home);


# -------- extant --------
is(-d ".", $o1->extant("."),				"dot extant");
is(-d $o1->dn_start, $o1->extant($o1->dn_start),	"dn_start extant");
is(-d $o1->home, $o1->extant($o1->home),		"home extant");


# -------- tld and wslroot --------
if ($o1->on_wsl) {

	$log->info("platform: WSL");

	like($o1->_wslroot, qr/wsl/,	"_wslroot defined");

	is($o1->wslroot, undef,		"wslroot undefined");
	is($o1->tld, "/mnt",		"default tld");

} elsif ($o1->on_cygwin) {

	$log->info("platform: CYGWIN");

	isnt($o1->_wslroot, undef,	"_wslroot defined");
	if ($o1->wsl_active) {
		isnt($o1->wslroot, undef,	"wslroot defined");
	} else {
		is($o1->wslroot, undef,	"wslroot defined");
	}
	is($o1->tld, "/cygdrive",	"default tld");

} elsif ($o1->on_windows) {

	$log->info("platform: Windows");

	isnt($o1->_wslroot, undef,	"_wslroot defined");
	if ($o1->wsl_active) {
		isnt($o1->wslroot, undef,	"wslroot defined");
	} else {
		is($o1->wslroot, undef,	"wslroot defined");
	}
	is($o1->tld, "/",		"default tld");

} else {

	$log->info("platform: OTHER");

	is($o1->_wslroot, undef,	"_wslroot undefined");
	is($o1->wslroot, undef,		"wslroot undefined");
	is($o1->tld, "/",		"default tld");
}


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
  'a' => { 'base' => 'foo',		'us' => 'foo',
					'wd' => 'foo',
					'ws' => 'foo',
	},
  'b' => { 'base' => 'foo bar',		'us' => q{foo\ bar},
					'wd' => 'foo bar',
					'ws' => q{foo\ bar},
	},
  'c' => { 'base' => 'foo/bar',		'us' => q{foo\/bar},
					'wd' => q{foo\bar},
					'ws' => q{foo\\bar},
	},
  'd' => { 'base' => '/foo/bar',	'us' => q{\/foo\/bar},
					'wd' => q{\foo\bar},
					'ws' => q{\\foo\\bar},
	},
  'e' => { 'base' => '/foo/bar/',	'us' => q{\/foo\/bar\/},
#					'wd' => q{\foo\bar\},
# these are causing syntax errors so the windows tests are delegated to "Harness"
					'ws' => q{\\foo\\bar\\},
	},
  'f' => { 'base' => q{foo'bar},	'us' => q{foo\'bar},
					'wd' => q{foo'bar},
					'ws' => q{foo\'bar},
	},
  'g' => { 'base' => '/fu/man/chu',	'us' => q{\/fu\/man\/chu},
					'wd' => q{\fu\man/chu},
					'ws' => q{\\fu\\man\\chu},
	},
  'h' => { 'base' => ' fu man chu ',	'us' => q{\ fu\ man\ chu\ },
					'wd' => ' fu man chu ',
					'ws' => q{\ fu\ man\ chu\ },
	},
);
#while (my ($cond, $rh) = each %uxp) {
for my $cond (sort keys %uxp) {
	my $rh = $uxp{$cond};
	my $base = $rh->{'base'};
	my $shell = $rh->{'us'};

	is($os0->slash($base), $base,	$harness->cond("slash shellify OFF unix cond=$cond"));

	is($os1->slash($base), $shell,	$harness->cond("slash shellify ON unix cond=$cond"));
}


# -------- slash and shellify: windows behaviour --------
$os0->behaviour('w');
$os1->behaviour('w');
is($os0->behaviour, 'w',		$harness->cond("behaviour wind"));
is($os0->behaviour, $os1->behaviour,	$harness->cond("behaviour match"));

for my $cond (sort keys %uxp) {
	my $rh = $uxp{$cond};
	my $base = $rh->{'base'};
	my $wd = $rh->{'wd'};
	my $ws = $rh->{'ws'};

#	wd and ws testing does not naturally parse correctly so
#	have delegate to the t/Harness.pm module

	my $hd = $harness->fs2bs($base);
	my $hs = $harness->fs2bs($base, 1);

	is(length($hd), length($base),	$harness->cond("fs2bs length"));

#	is($os0->slash($base), $wd,	$harness->cond("slash shellify OFF wd cond=$cond"));
	is($os0->slash($base), $hd,	$harness->cond("slash shellify OFF hd cond=$cond"));

#	is($os1->slash($base), $ws,	$harness->cond("slash shellify ON ws cond=$cond"));
#	$log->debug("wd [$wd] ws [$ws]") if ($cond eq 'c');
	is($os1->slash($base), $hs,	$harness->cond("slash shellify ON hs cond=$cond"));
}

exit -1;

# -------- wslhome --------
my $o3 = Batch::Exec::Path->new;
isa_ok($o3, $harness->this,	"class check $cycle"); $cycle++;

if ($o3->on_windows) {
	like($o1->wslroot, qr/wsl/,	"wslroot IS on_wsl raw");
	like($o3->wslroot, qr/wsl/,	"wslroot IS on_wsl convert");

	like($o1->wslhome, qr/wsl.*home/,	"wslhome IS on_wsl raw");
	like($o3->wslhome, qr/wsl.*home/,	"wslhome IS on_wsl convert");
} else {
	is($o1->wslroot, undef,	"wslroot ISNT on_wsl raw");
	is($o3->wslroot, undef,	"wslroot ISNT on_wsl convert");

	is($o1->wslhome, undef,	"wslhome ISNT on_wsl raw");
	is($o3->wslhome, undef,	"wslhome ISNT on_wsl convert");
}


__END__

=head1 DESCRIPTION

01_primitive.t - test harness for the Batch::Exec::Path.pm module: primitives

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

