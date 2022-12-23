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

$harn->planned(39);
use_ok($harn->this);
#require_ok($harn->this);


# -------- constants --------
#use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
#Log::Log4perl->easy_init($ERROR);
Log::Log4perl->easy_init($DEBUG);
my $log = get_logger(__FILE__);


# -------- main --------
my $os0 = Batch::Exec::Path->new('behaviour' => 'w');
isa_ok($os0, $harn->this,		$harn->cond("class check"));

my $os1 = Batch::Exec::Path->new('behaviour' => 'u');
isa_ok($os1, $harn->this,		$harn->cond("class check"));

my $os2 = Batch::Exec::Path->new;
isa_ok($os2, $harn->this,		$harn->cond("class check"));

my $os3 = Batch::Exec::Path->new;
isa_ok($os2, $harn->this,		$harn->cond("class check"));


# -------- cat_re --------
SKIP: {
	skip "cat_re fatal", 2;

	is($os0->cat_re(undef), "xx",	$harn->cond("cat_re fatal"));
	is($os0->cat_re, "xx",		$harn->cond("cat_re fatal"));
}
isa_ok($os0->cat_re(1, "xx"), "Regexp",	$harn->cond("cat_re simple"));
ok(length($os0->cat_re(1, "xx")) > length($os0->cat_re(0, "xx")),	$harn->cond("cat_re length"));

isa_ok($os0->cat_re(1, "y", "z"), "Regexp",	$harn->cond("cat_re simple"));
ok(length($os0->cat_re(1, "y", "z")) > length($os0->cat_re(0, "y", "z")),	$harn->cond("cat_re length"));


# -------- connector and separator --------
$harn->cwul($os0, qw[ connector  \\  \\  \\  \\  ]);
$harn->cwul($os1, qw[ connector  /  /  /  /  ]);

is($os0->type('nfs'), 'nfs',			$harn->cond("connector type"));
$harn->cwul($os0, qw[ connector  /  /  /  /  ]);
$harn->cwul($os1, qw[ connector  /  /  /  /  ]);

my $re_win = qr[\\];
$harn->cwul($os0, "separator", $re_win, $re_win, $re_win, $re_win);

my $re_lux = qr[/];
$harn->cwul($os1, "separator", $re_lux, $re_lux, $re_lux, $re_lux);


# -------- drive_letter --------
is($os0->drive_letter("c"), "c",	$harn->cond("drive_letter simple"));
is($os0->drive, "c:",			$harn->cond("drive simple"));

is($os0->drive_letter("c:"), "c",	$harn->cond("drive_letter colon"));
is($os0->drive, "c:",			$harn->cond("drive colon"));

is($os0->drive_letter('wsl$'), 'wsl$',	$harn->cond("drive_letter bucks"));
is($os0->drive, 'wsl$',			$harn->cond("drive bucks"));


# -------- tld --------
is($os2->type("win"), "win",		$harn->cond("type override"));
$harn->cwul($os2, qw[  tld  /cygdrive  ], "", "/mnt",  "");

is($os2->type("wsl"), "wsl",		$harn->cond("type override"));
$harn->cwul($os2, qw[  tld  /cygdrive  //wsl$/Ubuntu  //wsl$/Ubuntu], "");
exit -1;


#-------- winuser --------
#isnt($os0->winuser, undef,	$harn->cond("winuser simple"));
my $re_wu = qr/\w+/;
$harn->cwul($os0, "winuser", $re_wu, $re_wu, $re_wu, $re_wu);


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

