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
my $harn = Harness->new('Batch::Exec::Path');

$harn->planned(246);
use_ok($harn->this);
#require_ok($harn->this);


# -------- constants --------
#use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
#Log::Log4perl->easy_init($ERROR);
Log::Log4perl->easy_init($DEBUG);
my $log = get_logger(__FILE__);


# -------- main --------
my $os0 = Batch::Exec::Path->new('shellify' => 0);
isa_ok($os0, $harn->this,		$harn->cond("class check"));

my $os1 = Batch::Exec::Path->new('shellify' => 1);
isa_ok($os1, $harn->this,		$harn->cond("class check"));


# -------- drive_letter --------
is($os0->drive_letter("c"), "c",	$harn->cond("drive_letter simple"));
if ($os0->on_windows) {
	is($os0->drive, "c:",		$harn->cond("drive simple"));
} else {
	is($os0->drive, "c",		$harn->cond("drive simple"));
}
is($os0->letter, "c",			$harn->cond("letter simple"));

is($os0->drive_letter("c:"), "c",	$harn->cond("drive_letter colon"));
is($os0->drive, "c:",			$harn->cond("drive colon"));
is($os0->letter, "c",			$harn->cond("letter colon"));

is($os0->drive_letter('wsl$'), "wsl",	$harn->cond("drive_letter bucks"));
is($os0->drive, 'wsl$',			$harn->cond("drive bucks"));
is($os0->letter, "wsl",			$harn->cond("letter bucks"));


# -------- slash and shellify: unix behaviour --------
is($os0->shellify, 0,			$harn->cond("shellify off"));
is($os1->shellify, 1,			$harn->cond("shellify on"));

$os0->behaviour('u');
$os1->behaviour('u');
is($os0->behaviour, 'u',		$harn->cond("behaviour unix"));
is($os0->behaviour, $os1->behaviour,	$harn->cond("behaviour match"));

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

	is($os0->slash($base), $base,	$harn->cond("slash shellify OFF unix cond=$cond"));

	is($os1->slash($base), $shell,	$harn->cond("slash shellify ON unix cond=$cond"));
}


# -------- slash and shellify: windows behaviour --------
$os0->behaviour('w');
$os1->behaviour('w');
is($os0->behaviour, 'w',		$harn->cond("behaviour wind"));
is($os0->behaviour, $os1->behaviour,	$harn->cond("behaviour match"));

for my $cond (sort keys %uxp) {
	my $rh = $uxp{$cond};
	my $base = $rh->{'base'};
	my $wd = $rh->{'wd'};
	my $ws = $rh->{'ws'};

#	wd and ws testing does not naturally parse correctly so
#	have delegate to the t/Harness.pm module

	my $hd = $harn->fs2bs($base);
	my $hs = $harn->fs2bs($base, 1);

	is(length($hd), length($base),	$harn->cond("fs2bs length"));

#	is($os0->slash($base), $wd,	$harn->cond("slash shellify OFF wd cond=$cond"));
	is($os0->slash($base), $hd,	$harn->cond("slash shellify OFF hd cond=$cond"));

#	is($os1->slash($base), $ws,	$harn->cond("slash shellify ON ws cond=$cond"));
#	$log->debug("wd [$wd] ws [$ws]") if ($cond eq 'c');
	is($os1->slash($base), $hs,	$harn->cond("slash shellify ON hs cond=$cond"));
}


# -------- _wslroot --------
$harn->cwul($os1, "_wslroot", qr/wsl/, qr/wsl/, undef, undef);

if ($os1->on_wsl) {

	$log->info("platform: WSL");

	like($os1->_wslroot, qr/wsl/,	"_wslroot defined");

} elsif ($os1->on_cygwin) {

	$log->info("platform: CYGWIN");

	isnt($os1->_wslroot, undef,	"_wslroot defined");

} elsif ($os1->on_windows) {

	$log->info("platform: Windows");

	isnt($os1->_wslroot, undef,	"_wslroot defined");

} else {

	$log->info("platform: OTHER");

	is($os1->_wslroot, undef,	"_wslroot undefined");
}

__END__

=head1 DESCRIPTION

01_primitive.t - test harness for the Batch::Exec::Path.pm module: primitives

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

