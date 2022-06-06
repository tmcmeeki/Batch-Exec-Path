#!/usr/bin/perl
#
# 03other::Exec::Path-2.t - test harness for the Batch::Exec::Path.pm module: pathnames
#
use strict;

use Data::Compare;
use Data::Dumper;
use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($ERROR);
#use Logfer qw/ :all /;
use Test::More tests => 45;

BEGIN { use_ok('Batch::Exec::Path') };


# -------- constants --------
use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
my $log = get_logger(__FILE__);


# -------- sub-routines --------
sub check_equiv {
	my ($s1, $s2, $cn, $cycle) = @_;
	my $rec = qr/(cygdrive|mnt)/i;
	my $res = RE_PATH_DELIM;

	$cycle = "na" unless defined($cycle);
	my $condition = sprintf('%s compare [cycle=%s]', $cn, $cycle);

	$s1 =~ s/://;
	my @a1 = split($res, lc $s1);
	my $n1 = scalar(@a1);
	$log->debug(sprintf "n1 [$n1] s1 [$s1] a1 [%s]", Dumper(\@a1));

	$s2 =~ s/://;
	my @a2 = split($res, lc $s2);
	my $n2 = scalar(@a2);
	$log->debug(sprintf "n2 [$n2] s2 [$s2] a2 [%s]", Dumper(\@a2));

	if ($n1 < $n2) {
		for (my $i = 0; $i < ($n2 - $n1); $i++) { shift @a2; }
		$log->debug(sprintf "s2 [$s2] a2 [%s]", Dumper(\@a2));

	} elsif ($n1 > $n2) {

		for (my $i = 0; $i < ($n1 - $n2); $i++) { shift @a1; }
		$log->debug(sprintf "s1 [$s1] a1 [%s]", Dumper(\@a1));
	}

	my $diff = new Data::Compare;

	my $result = $diff->Cmp(\@a1, \@a2);

	$log->debug("result [$result]");

	is($result, 1, $condition);
}


# -------- main --------
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, "Batch::Exec::Path",	"class check $cycle"); $cycle++;

my $o2 = Batch::Exec::Path->new('shellify' => 1);
isa_ok($o2, "Batch::Exec::Path",	"class check $cycle"); $cycle++;


# ---- splitdir basic ----
my $dn_winc = 'C:\Users\abc';
my $dn_wind = 'D:\Users\abc';
my $dn_cyg = '/cygdrive/d/Users/abc';
my $dn_wsl = '/mnt/d/Users/abc';

is_deeply([$o1->splitdir($dn_winc)], [qw/ C: Users abc/], "splitdir 1");
is_deeply([$o1->splitdir($dn_wind)], [qw/ D: Users abc/], "splitdir 2");
is_deeply([$o1->splitdir($dn_cyg)], ["", qw/ cygdrive d Users abc/], "splitdir 3");
is_deeply([$o1->splitdir($dn_wsl)], ["", qw/ mnt d Users abc/], "splitdir 4");
exit -1;


# ---- path basic ----

my $re_cyg = qr/cyg.+users.+abc/i;
my $re_win = qr/c.+users.+abc/i;
my $re_wsl = qr/mnt.+users.+abc/i;
if ($o1->on_cygwin) {
	is($o1->tld, "cygdrive",			"tld cygdrive");
	like($o1->path($dn_winc), $re_cyg,	"path path");
	like($o1->path($dn_wind), qr/cyg.+d.+abc/,	"path drive");

} elsif ($o1->on_wsl) {
	is($o1->tld, "mnt",			"tld mnt");
	like($o1->path($dn_winc), $re_wsl,	"path path");
	like($o1->path($dn_wind), qr/mnt.+d.+abc/,	"path drive");

} elsif ($o1->on_windows) {

	is($o1->tld, undef,			"tld windows");
	like($o1->path($dn_winc), $re_win,	"path path");
} else {
	is($o1->tld, undef,			"tld undef");
}


# ---- path other ----
like($o1->path('1:\hello.txt'), qr/txt/,	"path bad drive");
like($o1->path(''), qr/^$/,		"path null");
like($o1->path('xxx'), qr/xxx/,		"path not drive");


# ---- winpath ----
if ($o1->on_cygwin) {
	is($o1->winpath($dn_cyg), $dn_wind,		"winpath cyg convert");

	check_equiv($o1->winpath($dn_wsl), $dn_wsl, 	"winpath cyg leave");

} elsif ($o1->on_wsl) {
	check_equiv($o1->winpath($dn_cyg), $dn_cyg, 	"winpath wls convert");

	check_equiv($o1->winpath($dn_wsl), $dn_wind, 	"winpath wls convert");
}
like($o1->winpath('/cygdrive/9/hello.txt'), qr/txt/,	"winpath bad drive");
like($o1->winpath('/invalid/'), qr/invalid/,		"winpath invalid path");
is($o1->winpath(''), '',				"winpath blank");

my $dn0 = "/cygdrive/c/xxx";
check_equiv($o1->winpath($dn0), $dn0, 		"winpath dn0");
isnt($o1->winpath($dn0), $dn0, 			"winpath diff dn0");
check_equiv($o2->winpath($dn0), $dn0, 		"winpath conv dn0");
isnt($o1->winpath($dn0), $o2->winpath($dn0), 	"winpath dual dn0");

my $dn1 = "/dir/xxx";
check_equiv($o1->winpath($dn1), $dn1, 		"winpath dn1");
isnt($o1->winpath($dn1), $dn1, 			"winpath diff dn1");
check_equiv($o2->winpath($dn1), $dn1, 		"winpath conv dn1");
isnt($o1->winpath($dn1), $o2->winpath($dn1), 	"winpath dual dn1");

my $dn2 = "xxx";
check_equiv($o1->winpath($dn2), $dn2, 		"winpath dn2");
check_equiv($o2->winpath($dn2), $dn2, 		"winpath conv dn3");
is($o1->winpath($dn2), $dn2, 			"winpath diff dn2");
is($o1->winpath($dn2), $o2->winpath($dn2), 	"winpath dual dn2");

my $dn3 = "/root/xxx";
check_equiv($o1->winpath($dn3), $dn3,		"winpath dn3");
isnt($o1->winpath($dn3), $dn3, 			"winpath diff dn3");
check_equiv($o2->winpath($dn3), $dn3, 		"winpath conv dn3");
isnt($o1->winpath($dn3), $o2->winpath($dn3), 	"winpath dual dn3");

my $dn4 = "//hostname/xxx";
check_equiv($o1->winpath($dn4), $dn4, 		"winpath dn4");
isnt($o1->winpath($dn4), $dn4, 			"winpath diff dn4");
check_equiv($o2->winpath($dn4), $dn4, 		"winpath conv dn4");
isnt($o1->winpath($dn4), $o2->winpath($dn4), 	"winpath dual dn4");

my $dn5 = '\\hostname\xxx';
check_equiv($o1->winpath($dn5), $dn5, 		"winpath dn5");
is($o1->winpath($dn5), $dn5, 			"winpath diff dn5");
isnt($o1->winpath($dn5), $o2->winpath($dn5), 	"winpath dual dn5");

# more testing:  do the following
# ('C:\Temp00');
# ('C:/Temp01');
# ('\server\Temp02');
# ('\\server\Temp03a');
# ('//server/Temp03b');
# ("\\server\\Temp04");
# ("\\\\server\\Temp05");
# ("/mnt/c//windows/temp06");
# ('\mnt\c\window\temp07');
# ("/cygdrive/c/windows/temp08");
# ('\\wsl$\Ubuntu\home\tomby');
# ('\\\\\\\\this\\\is\\wierd\\\\now');
# ('~/tmp');
# "./tmp";

__END__

=head1 DESCRIPTION

03other.t - test harness for the Batch::Exec::Path.pm module: pathnames

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

