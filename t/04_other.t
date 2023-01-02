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
my ($pn, $er, $ty);


# -------- sub-routines --------


# -------- main --------
$harn->planned(166);

my $o0 = Batch::Exec::Path->new;
isa_ok($o0, $harn->this,		$harn->cond("class check"));

my $o1 = Batch::Exec::Path->new('shellify' => 0);
isa_ok($o1, "Batch::Exec::Path",	$harn->cond("class check"));

my $o2 = Batch::Exec::Path->new('shellify' => 1);
isa_ok($o2, "Batch::Exec::Path",	$harn->cond("class check"));


# -------- conversion (same type) --------
$pn = "/mnt/c/Temp/abc.txt";

$o1->parse($pn);
$ty = $o1->type;

is($o1->convert($ty), $pn,		$harn->cond("convert same type $ty"));


# -------- conversion (cyg to lux [root]) --------
$pn = '/cygdrive/c/';
$er = "/";
$ty = "lux";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (win to hyb) --------
$pn = 'c:\Temp\abc.txt';
$er = "/mnt/c/Temp/abc.txt";
$ty = "hyb";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (hyb to win) --------
$pn = "/mnt/c/Temp/abc.txt";
$er = 'c:\Temp\abc.txt';
$ty = "win";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (cyg to nfs) --------
$pn = '/cygdrive/c/tmp';
$er = "hostx:/tmp";
$ty = "nfs";

$o1->parse($pn);
$o1->server('hostx');
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (nfs to cyg) --------
$pn = "hosty:/tmp";
$er = '/cygdrive/c/tmp';
$ty = "cyg";

$o1->parse($pn);
$o1->drive_letter('c');
$o1->server(undef);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (nfs to lux) --------
$pn = "hosty:/tmp";
$er = '/tmp';
$ty = "lux";

$o1->parse($pn);
$o1->server(undef);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (wsl to lux) --------
$pn = '\\\\wsl$\\Ubuntu\\home\\jbloggs';
$er = "/home/jbloggs";
$ty = "lux";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (lux to wsl) --------
$pn = '/home/jbloggs';
$er = '\\\\wsl$\\Ubuntu\\home\\jbloggs';
$ty = "wsl";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (win to hyb) --------
$pn = 'C:\Users\jbloggs\foo';
$er = '/mnt/c/Users/jbloggs/foo';
$ty = "hyb";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (hyb to cyg) --------
$pn = '/mnt/c/Users/jbloggs';
$er = '/cygdrive/c/Users/jbloggs';
$ty = "cyg";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (cyg to hyb) --------
$pn = '/cygdrive/c/Users/jbloggs';
$er = '/mnt/c/Users/jbloggs';
$ty = "hyb";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (win to hyb) --------
$pn = '/cygdrive/c/Users/jbloggs';
$er = '/mnt/c/Users/jbloggs';
$ty = "hyb";

$o1->parse($pn);
is($o1->convert($ty), $er,	$harn->cond("convert [$pn] >> $ty >> [$er]"));


# -------- conversion (see: path_scenarios.xlsx) --------
my ($re_wsll, $re_wslw);
$re_wsll = '//wsl$/Ubuntu/tmp';
$re_wslw = '\\\\wsl$\\Ubuntu\\tmp';

my %convert;	# order:  cyg   hyb   lux   nfs   win   wsl 

$convert{'foo/bar'} = [qw{ foo/bar foo/bar foo/bar foo/bar foo\\bar foo\\bar }];
$convert{'tmp'} = [qw{ tmp tmp tmp tmp tmp tmp }];
$convert{'./tmp'} = [qw{ ./tmp ./tmp ./tmp ./tmp .\\tmp .\\tmp }];
$convert{'/tmp'} = [qw{ /cygdrive/c/tmp /mnt/c/tmp /tmp /tmp \\tmp \\\\wsl$\\Ubuntu\\tmp }];
$convert{'c:\\tmp'} = [qw{ /cygdrive/c/tmp /mnt/c/tmp /tmp /tmp c:\\tmp }, $re_wslw];

$convert{'/cygdrive/c/tmp'} = [qw{ /cygdrive/c/tmp /mnt/c/tmp /tmp /tmp c:\\tmp c:\\tmp }];

$convert{'\\\\server\\c$\\tmp'} = [qw{ //server/c$/tmp //server/c$/tmp //server/c$/tmp server:/c$/tmp \\\\server\\c$\\tmp \\\\server\\c$\\tmp }];

$convert{$re_wslw} = [ $re_wsll, qw[ /tmp /tmp /tmp ], $re_wslw, $re_wslw ];

$re_wsll = '//wsl$/Ubuntu';
$re_wslw = '\\\\wsl$\\Ubuntu';
$convert{$re_wslw} = [ $re_wsll, qw[ / / / ], $re_wslw, $re_wslw ];

my $re_lxh = $o0->cat_re(0, qw/ jbloggs home root /, $o0->whoami, $o0->winuser);
my $re_wih = $o0->cat_re(0, qw/ jbloggs Users/, $o0->whoami, $o0->winuser);
$convert{'~'} = [ $re_lxh, $re_lxh, $re_lxh, $re_lxh, $re_wih, $re_wih ];
$convert{'~jbloggs'} = [ $re_lxh, $re_lxh, $re_lxh, $re_lxh, $re_wih, $re_wih ];

$convert{'/'} = [qw{ /cygdrive/c /mnt/c / / \\ \\\\wsl$\\Ubuntu }];
$convert{'\\'} = [qw{ /cygdrive/c /mnt/c / / \\ \\\\wsl$\\Ubuntu }];

#$log->debug(sprintf "convert [%s]", Dumper(\%convert));


my @types = $o0->lov("_lov", "type");
$log->debug($o0->dump(\@types, "types"));
for my $pn (sort keys %convert) {

	my $ra = $convert{$pn};

	ok(scalar(@$ra) == @types,	$harn->cond("conversion types"));

	$o0->cough("convert hash [$pn] array size") unless (scalar(@$ra) == @types);

	$log->debug($o0->dump($ra, "ra xxxx xxxx xxxx xxxx xxxx xxxx xxxx"));

	my $fail; for (my $ss = 0; $ss < @types; $ss++) {

		my $ty = $types[$ss];
		my $er = $ra->[$ss];

		ok($o0->parse($pn),	$harn->cond("parse [$pn] convert to [$ty]"));

#		$log->debug("==== ==== $pn ==== $ty ==== ====");

		if (ref($er) eq 'Regexp') {
			#like($o0->convert($ty), $er, $harn->cond("convert $ty $pn"));
			$fail = ($o0->convert($ty) =~ $er) ? "" : "fail [$pn] to [$ty] expected [$er]";
		} else {
			#is($o0->convert($ty), $er, $harn->cond("convert $ty $pn"));
			$fail = ($o0->convert($ty) eq $er) ? "" : "fail [$pn] to [$ty] expected [$er]";
		}

		last unless ($fail eq "");
	}
	$log->logcroak($fail)
		if ($fail ne "");
}


# -------- escape --------
is($o1->shellify, 0,			$harn->cond("shellify off"));
is($o2->shellify, 1,			$harn->cond("shellify on"));

$o1->behaviour('u');
$o2->behaviour('u');
is($o1->behaviour, 'u',			$harn->cond("behaviour unix"));
is($o1->behaviour, $o2->behaviour,	$harn->cond("behaviour match"));

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

	SKIP: {
		skip "escape yet to be tested", 2;

		is($o1->escape($base), $base,	$harn->cond("escape shellify OFF unix cond=$cond"));

		is($o2->escape($base), $shell,	$harn->cond("escape shellify ON unix cond=$cond"));
	}
}


# -------- escape and shellify: windows behaviour --------
$o1->behaviour('w');
$o2->behaviour('w');
is($o1->behaviour, 'w',		$harn->cond("behaviour wind"));
is($o1->behaviour, $o2->behaviour,	$harn->cond("behaviour match"));

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

		is($o1->escape($base), $hd,	$harn->cond("escape shellify OFF hd cond=$cond"));

		is($o2->escape($base), $hs,	$harn->cond("escape shellify ON hs cond=$cond"));
	}
}


# -------- tld --------
is($o0->behaviour('u'), 'u',		$harn->cond("behaviour check"));
is($o1->behaviour('w'), 'w',		$harn->cond("behaviour check"));
$harn->cwul($o0, qw[  tld	 /cygdrive  C:   /mnt   /  ]);
$harn->cwul($o1, qw[  tld	\\cygdrive  C:  \\mnt  \\  ]);

$log->info("==== ==== ==== ==== ==== ==== ==== ==== ==== ====");
$harn->cwul($o0, qw[ tld wsl    //wsl$/Ubuntu    //wsl$/Ubuntu    //wsl$/Ubuntu  / ]);
$harn->cwul($o1, qw[ tld wsl \\\\wsl$\\Ubuntu \\\\wsl$\\Ubuntu \\\\wsl$\\Ubuntu \\ ]);
SKIP: {
	skip "invalid syntax tld", 2;

	$harn->cwul($o0, "tld", "xxx", qw[  /cygdrive  C:  /mnt    /  ]);
	$harn->cwul($o1, "tld", "xxx", qw[ \\cygdrive  C:  \\mnt  \\  ]);
}


# -------- wslroot and wslhome --------
#is($o1->parse("foo/bar/dummy"),	6,	$harn->cond("dummy parse"));
my $re_wsr = qr[wsl\$.\w+];

like($o1->wslroot, qr/.+/,		$harn->cond("wslroot has value"));

$harn->cwul($o1, "wslroot", $re_wsr, $re_wsr, $re_wsr, $re_wsr);


my $re_wsh = qr[wsl\$.\w+.home];

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

