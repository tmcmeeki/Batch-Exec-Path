#!/usr/bin/perl
#
# 04_other.t - test harness for the Batch::Exec::Path.pm module: miscellaneous
#
use strict;

#use Data::Compare;
use Data::Dumper;
#use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($ERROR);
use Logfer qw/ :all /;
use Test::More;
use lib 't';
use Harness;


# -------- global variables --------
my $harn = Harness->new('Batch::Exec::Path');
my $log = get_logger(__FILE__);
my ($pn, $er, $ty);


# -------- sub-routines --------


# -------- main --------
$harn->planned(345);

use_ok($harn->this);

my $o0 = Batch::Exec::Path->new;
isa_ok($o0, $harn->this,		$harn->cond("class check"));

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, "Batch::Exec::Path",	$harn->cond("class check"));

my $o2 = Batch::Exec::Path->new;
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


# -------- escape basic --------
$o1->behaviour('u');
$o2->behaviour('u');
is($o1->behaviour, 'u',			$harn->cond("behaviour unix"));
is($o2->behaviour, $o1->behaviour,	$harn->cond("behaviour match"));

is($o1->parse('hello'), 2,		$harn->cond("parse hello"));
is($o1->escape, 'hello',		$harn->cond("escape no arg"));
is($o1->escape('b'), 'hello',		$harn->cond("escape no effect"));
is($o1->escape('q'), qw{ "hello" },	$harn->cond("escape double quotes"));
is($o1->escape('s'), qw{ 'hello' },	$harn->cond("escape single quotes"));

is($o1->parse('foo bar'), 2,		$harn->cond("parse foo bar"));
is($o1->escape, 'foo\\ bar',		$harn->cond("escape no arg"));
is($o1->escape('b'), 'foo\\ bar',	$harn->cond("escape no effect"));
is($o1->escape('q'), q{"foo bar"},	$harn->cond("escape double quotes"));
is($o1->escape('s'), q{'foo bar'},	$harn->cond("escape single quotes"));

is($o1->parse('foo/bar'), 4,		$harn->cond("parse foo/bar"));
is($o1->escape, 'foo\\/bar',		$harn->cond("escape no arg"));
is($o1->escape('b'), 'foo\\/bar',	$harn->cond("escape no effect"));
is($o1->escape('q'), q{"foo/bar"},	$harn->cond("escape double quotes"));
is($o1->escape('s'), q{'foo/bar'},	$harn->cond("escape single quotes"));


# -------- escape data structure --------
my %uxp = (	# first = path (unmodified), second = escape result
  'a' => { 'base' => 'foo',		'us' => 'foo' },
  'b' => { 'base' => 'foo bar',		'us' => q{foo\\ bar} },
  'c' => { 'base' => 'foo/bar',		'us' => q{foo\\/bar} },
  'd' => { 'base' => '/foo/bar',	'us' => q{\\/foo\\/bar} },
  'e' => { 'base' => q{foo'bar},	'us' => q{foo\\'bar} },
  'f' => { 'base' => '/fu/man/chu',	'us' => '\\/fu\\/man\\/chu' },
  'g' => { 'base' => 'fu man chu ',	'us' => "fu\\ man\\ chu\\ " },
);


# -------- escape behaviour for unices --------
for my $cond (sort keys %uxp) {
	my $rh = $uxp{$cond};
	my $base = $rh->{'base'};
	my $shell = $rh->{'us'};

	ok($o1->parse($base),		$harn->cond("escape parse"));
	is($o1->joiner, $base,		$harn->cond("joiner linux cond=$cond"));

	ok($o2->parse($base),		$harn->cond("escape parse"));
	is($o2->escape, $shell,		$harn->cond("escape linux cond=$cond"));
}

for my $rh ($harn->linux) {

	my ($pni) = $harn->select($rh, qw/ path /);
	my $shell = $harn->fs2bs($pni, 1, 1);

	ok($o1->parse($pni),		$harn->cond("escape parse"));
	is($o1->joiner, $pni,		$harn->cond("joiner linux harn $pni"));

	next if ($o1->type eq 'nfs');

	ok($o2->parse($pni),		$harn->cond("escape parse"));
	is($o2->escape, $shell,		$harn->cond("escape linux harn $pni"));

#	last unless($o1->escape eq $shell);	# DEBUGGING
}


# -------- escape: windows behaviour --------
$o1->behaviour('w');
$o2->behaviour('w');
is($o1->behaviour, 'w',			$harn->cond("behaviour wind"));
is($o1->behaviour, $o1->behaviour,	$harn->cond("behaviour match"));

for my $cond (sort keys %uxp) {

	my $rh = $uxp{$cond};
	my $base = $rh->{'base'};

	my $hd = $harn->fs2bs($base);

	is(length($hd), length($base),	$harn->cond("fs2bs length"));

	ok($o1->parse($base),		$harn->cond("escape parse"));
	is($o1->joiner, $hd,		$harn->cond("joiner hd cond=$cond"));

#	last unless($o1->escape eq $hd);	# DEBUGGING

	my $hs = $harn->fs2bs($base, 1);

	ok(length($hs) >= length($base),	$harn->cond("fs2bs length"));

	ok($o2->parse($base),		$harn->cond("escape parse"));
	is($o2->escape, $hs,		$harn->cond("escape hs cond=$cond"));
}

for my $rh ($harn->windows) {

	my ($pni) = $harn->select($rh, qw/ path /);
	my $shell = $harn->fs2bs($pni, 1);

	ok($o1->parse($pni),		$harn->cond("escape parse"));
	is($o1->joiner, $pni,		$harn->cond("joiner mswin harn $pni"));

	last unless($o1->joiner eq $pni);	# DEBUGGING

	next if ($o1->type eq 'nfs');

	ok($o2->parse($pni),		$harn->cond("escape parse"));
	is($o2->escape, $shell,		$harn->cond("escape mswin harn $pni"));

	last unless($o1->escape eq $shell);	# DEBUGGING
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

