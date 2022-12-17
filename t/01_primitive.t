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

$harn->planned(75);
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

my $os2 = Batch::Exec::Path->new;
isa_ok($os2, $harn->this,		$harn->cond("class check"));


# -------- drive_letter --------
is($os0->drive_letter("c"), "c",	$harn->cond("drive_letter simple"));
is($os0->drive, "c:",			$harn->cond("drive simple"));
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

	SKIP: {
		skip "slash yet to be tested", 2;

		is($os0->slash($base), $base,	$harn->cond("slash shellify OFF unix cond=$cond"));

		is($os1->slash($base), $shell,	$harn->cond("slash shellify ON unix cond=$cond"));
	}
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

	SKIP: {
		skip "slash yet to be tested", 2;

		is($os0->slash($base), $hd,	$harn->cond("slash shellify OFF hd cond=$cond"));

		is($os1->slash($base), $hs,	$harn->cond("slash shellify ON hs cond=$cond"));
	}
}


# -------- tld --------
is($os2->type("win"), "win",		$harn->cond("type override"));
$harn->cwul($os2, qw[  tld  /cygdrive  ], "", "/mnt",  "");

is($os2->type("wsl"), "wsl",		$harn->cond("type override"));
$harn->cwul($os2, qw[  tld  /cygdrive  //wsl$/Ubuntu  //wsl$/Ubuntu], "");


# -------- _wslroot --------
my $re_wsl = qr[wsl\$\/\w+];
like($os2->_wslroot, qr/.+/,		$harn->cond("_wslroot has value"));
$harn->cwul($os2, "_wslroot", $re_wsl, $re_wsl, $re_wsl, $re_wsl);


# -------- volume --------
is($os2->type("win"), "win",		$harn->cond("type override"));
is($os2->unc(0), 0,			$harn->cond("unc override"));
$harn->cwul($os2, qw[ volume  x  /cygdrive/x  x:  /mnt/x  /x ]);


is($os2->server("host"), "host",	$harn->cond("server override"));
$harn->cwul($os2, qw[ volume  x  //host/x  //host/x  //host/x  //host/x ]);


is($os2->type("wsl"), "wsl",		$harn->cond("type override"));
is($os2->server(undef), undef,		$harn->cond("server override"));
$harn->cwul($os2, qw[ volume  x  /cygdrive/x  //wsl$/Ubuntu  //wsl$/Ubuntu  /x ]);


is($os2->type("lux"), "lux",		$harn->cond("type override"));
$harn->cwul($os2, qw[ volume  ee  /cygdrive/ee  ee:  /mnt/ee  /ee ]);


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

