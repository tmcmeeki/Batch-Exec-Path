#!/usr/bin/perl
#
# 04_other.t - test harness for the Batch::Exec::Path.pm module: miscellaneous
#
use strict;

#use Data::Compare;
use Data::Dumper;
#use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($ERROR);
use Logfer qw/ :all /;
use Test::More; # tests => 45;
use lib 't';
use Harness;


# -------- constants --------


# -------- global variables --------
my $harn = Harness->new('Batch::Exec::Path');
use_ok($harn->this);
my $log = get_logger(__FILE__);


# -------- sub-routines --------
# -------- main --------
$harn->planned(136);


my $o1 = Batch::Exec::Path->new;
isa_ok($o1, "Batch::Exec::Path",	$harn->cond("class check"));

#my $o2 = Batch::Exec::Path->new('shellify' => 1);
#isa_ok($o2, "Batch::Exec::Path",	$harn->cond("class check"));


# -------- escape --------
is($os0->shellify, 0,			$harn->cond("shellify off"));
is($os1->shellify, 1,			$harn->cond("shellify on"));

$os0->behaviour('u');
$os1->behaviour('u');
is($os0->behaviour, 'u',		$harn->cond("behaviour unix"));
is($os0->behaviour, $os1->behaviour,	$harn->cond("behaviour match"));

my %uxp = (	# first = path (unmodified), second = escape result
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

#	SKIP: {
#		skip "escape yet to be tested", 2;

		is($os0->escape($base), $base,	$harn->cond("escape shellify OFF unix cond=$cond"));

		is($os1->escape($base), $shell,	$harn->cond("escape shellify ON unix cond=$cond"));
#	}
}
exit -1;


# -------- escape and shellify: windows behaviour --------
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
		skip "escape yet to be tested", 2;

		is($os0->escape($base), $hd,	$harn->cond("escape shellify OFF hd cond=$cond"));

		is($os1->escape($base), $hs,	$harn->cond("escape shellify ON hs cond=$cond"));
	}
}




# -------- wslroot and wslhome --------
#is($o1->parse("foo/bar/dummy"),	6,	$harn->cond("dummy parse"));
my $re_wsr = qr[wsl\$\/\w+];

like($o1->wslroot, qr/.+/,		$harn->cond("wslroot has value"));

$harn->cwul($o1, "wslroot", $re_wsr, $re_wsr, $re_wsr, $re_wsr);


my $re_wsh = qr[wsl\$\/\w+\/home];

like($o1->wslhome, qr/.+/,		$harn->cond("wslhome has value"));

$harn->cwul($o1, "wslhome", $re_wsh, $re_wsh, $re_wsh, $re_wsh);


__END__

=head1 DESCRIPTION

04_other.t - test harness for the Batch::Exec::Path.pm module: miscellaneous

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

