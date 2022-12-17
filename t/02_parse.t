#!/usr/bin/perl
#
# 02_parse.t - test harness for the Batch::Exec::Path.pm module: path join
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

#BEGIN { use_ok('Batch::Exec::Path') };
use_ok($harn->this);

my $log = get_logger(__FILE__);



# -------- sub-routines --------


# -------- main --------
$harn->planned(462);
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harn->this,		$harn->cond("class check"));

my $o2 = Batch::Exec::Path->new;
isa_ok($o2, $harn->this,		$harn->cond("class check"));


# -------- volume --------
is($o2->type("win"), "win",		$harn->cond("type overrride"));
is($o2->unc(0), 0,			$harn->cond("unc overrride"));
$harn->cwul($o2, qw[ volume  x  /cygdrive/x  x:  /mnt/x  / ]);

is($o2->server("host"), "host",		$harn->cond("server overrride"));
$harn->cwul($o2, qw[ volume  x  //host/x  //host/x  //host/x  //host/x ]);

is($o2->type("wsl"), "wsl",		$harn->cond("type overrride"));
is($o2->server(undef), undef,		$harn->cond("server overrride"));
$harn->cwul($o2, qw[ volume  x  /cygdrive/x  //wsl$/Ubuntu  //wsl$/Ubuntu  /x ]);
exit -1;

is($o2->type("lux"), "lux",		$harn->cond("type overrride"));
$harn->cwul($o2, qw[ volume  /  /cygdrive/x  x:  /mnt/x  /x ]);
exit -1;


# -------- parse (specific) --------
is($o1->parse("./tmp"), 4,		$harn->cond("parse tmp"));
is($o1->abs, 0,				$harn->cond("abs $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ '.', 'tmp' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('foo/bar'), 4,		$harn->cond("parse foo_bar"));
is($o1->abs, 0,				$harn->cond("abs $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'foo', 'bar' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('c:\tmp'), 4,		$harn->cond("parse cdrv_tmp"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'c:',			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders $cycle"));
$harn->cwul($o1, qw[  volume  /cygdrive/c  c:  /mnt/c  /c ]);

$cycle++;


is($o1->parse('/cygdrive/c/tmp'), 7,		$harn->cond("parse cygdrive_c_tmp"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'cyg',			$harn->cond("type $cycle"));
is_deeply($o1->folders, [ 'cygdrive', 'c', 'tmp' ],	$harn->cond("folders $cycle"));
is($o1->drive, 'c:',			$harn->cond("drive $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
$harn->cwul($o1, qw[  volume  /cygdrive/c  c:  /mnt/c  /c ]);

$cycle++;


is($o1->parse('/tmp'), 3,		$harn->cond("parse tmp_2"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('\\\\wsl$\\Ubuntu'), 6,	$harn->cond("parse wsl8_ubuntu"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'wsl$',			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, 'wsl',			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'wsl',			$harn->cond("type $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'Ubuntu' ],	$harn->cond("folders $cycle"));
$harn->cwul($o1, qw[  volume  /cygdrive/wsl  wsl$  /mnt/wsl  / ]);

is($o2->parse('\\\\wsl$\\Ubuntu'), 6,	$harn->cond("parse wsl8_ubuntu"));
$harn->cwul($o2, qw[  volume  /cygdrive/wsl  //wsl$/Ubuntu  //wsl$/Ubuntu  //wsl ]);

$cycle++;
exit -1;


is($o1->parse('\\\\server\\c$'), 6,	$harn->cond("parse server_c8"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'c$',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [],		$harn->cond("folders $cycle"));
is($o1->server, 'server',		$harn->cond("server $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));

$cycle++;


is($o1->parse('\\\\server\\c$\\tmp'), 8,	$harn->cond("parse server_c8_tmp"));
is($o1->server, 'server',		$harn->cond("server $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));
is($o1->drive, 'c$',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'tmp' ],		$harn->cond("folders $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));

$cycle++;


is($o1->parse('C:\Temp'), 4,		$harn->cond("parse cdrv_temp"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->letter, 'C',			$harn->cond("letter $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'C:',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('C:/Temp'), 4,		$harn->cond("parse cdrv_temp_2"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->letter, 'C',			$harn->cond("letter $cycle"));
is($o1->drive, 'C:',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));

$cycle++;


is($o1->parse('\server\Temp'), 5,	$harn->cond("parse server_temp"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'server', 'Temp' ],	$harn->cond("folders $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));

$cycle++;


is($o1->parse('\\\\server\\Temp'), 6,	$harn->cond("parse server_temp_2"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, 'server',		$harn->cond("server $cycle"));

$cycle++;


is($o1->parse('//server/Temp'), 6,	$harn->cond("parse server_temp_3"));
is($o1->server, 'server',		$harn->cond("server $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));

$cycle++;


is($o1->parse('\\\\server\\Temp'), 6,	$harn->cond("parse server_temp_5"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, 'server',		$harn->cond("server $cycle"));

$cycle++;


is($o1->parse('/mnt/c//windows/temp'), 10,	$harn->cond("parse mnt_c_windows_temp"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'c:',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'mnt', 'c', 'windows', 'temp' ],		$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('\\mnt\\c\\window\\temp'), 9,	$harn->cond("parse mnt_c_window_temp"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->type, 'win',			$harn->cond("type $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'c:',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'mnt', 'c', 'window', 'temp' ],		$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('/cygdrive/c/windows/temp'), 9,	$harn->cond("parse cygdrive_c_windows_temp"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->letter, 'c',			$harn->cond("letter $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->type, 'cyg',			$harn->cond("type $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'c:',			$harn->cond("drive $cycle"));
is_deeply($o1->folders, [ 'cygdrive', 'c', 'windows', 'temp' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('//wsl$/Ubuntu/home/user'), 10,	$harn->cond("parse wsl8_ubuntu_home_user"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->drive, 'wsl$',			$harn->cond("drive $cycle"));
is($o1->homed, 1,			$harn->cond("homed $cycle"));
is($o1->letter, 'wsl',			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'wsl',			$harn->cond("type $cycle"));
is($o1->unc, 1,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'Ubuntu', 'home', 'user' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('~/tmp'), 4,		$harn->cond("parse home_tmp"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->homed, 1,			$harn->cond("homed $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ 'tmp' ],		$harn->cond("folders $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));

$cycle++;


is($o1->parse('/tmp'), 3,		$harn->cond("parse tmp_3"));
is_deeply($o1->folders, [ 'tmp' ],		$harn->cond("folders $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));

$cycle++;


is($o1->parse("."), 2,			$harn->cond("parse cwd"));
is($o1->abs, 0,				$harn->cond("abs $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ '.' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse(".."), 2,			$harn->cond("parse parent"));
is($o1->abs, 0,				$harn->cond("abs $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->homed, 0,			$harn->cond("homed $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is_deeply($o1->folders, [ '..' ],	$harn->cond("folders $cycle"));

$cycle++;


is($o1->parse('~'), 2,			$harn->cond("parse tilde"));
is($o1->abs, 1,				$harn->cond("abs $cycle"));
is($o1->unc, 0,				$harn->cond("unc $cycle"));
is($o1->homed, 1,			$harn->cond("homed $cycle"));
is($o1->type, 'lux',			$harn->cond("type $cycle"));
is_deeply($o1->folders, [],		$harn->cond("folders $cycle"));
is($o1->drive, undef,			$harn->cond("drive $cycle"));
is($o1->letter, undef,			$harn->cond("letter $cycle"));
is($o1->server, undef,			$harn->cond("server $cycle"));


# -------- parse (harness) --------
for my $pn ($harn->all_paths) {

	ok($o1->parse($pn) > 1,		$harn->cond("all parse"));
	ok(scalar($o1->folders),	$harn->cond("all folders"));

	no strict;

	for my $meth (qw/ homed type unc abs /) {

		isnt($o1->$meth, undef,		$harn->cond("all $meth"));
	}

	use strict;

	if ($o1->unc && $o1->type ne 'wsl') {
		isnt($o1->server, undef,	$harn->cond("server value"));
	} else {
		is($o1->server, undef,		$harn->cond("server undef"));
	}
}

__END__

=head1 DESCRIPTION

02_parse.t - test harness for the Batch::Exec::Path.pm module: path join

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

