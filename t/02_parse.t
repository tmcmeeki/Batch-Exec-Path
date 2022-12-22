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
use_ok($harn->this);

my $log = get_logger(__FILE__);


# -------- sub-routines --------


# -------- main --------
$harn->planned(546);

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harn->this,		$harn->cond("class check"));


# -------- parse (specific) --------
is($o1->parse("server:/this/is/nfs"), 8,	$harn->cond("parse nfs"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 0,			$harn->cond("hybrid"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, "server",		$harn->cond("server"));
is($o1->type, 'nfs',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [qw{ this is nfs }],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse("./tmp"), 4,		$harn->cond("parse tmp"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 0,			$harn->cond("hybrid"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ '.', 'tmp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse('foo/bar'), 4,		$harn->cond("parse foo_bar"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 0,			$harn->cond("hybrid"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'foo', 'bar' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse('c:\tmp'), 4,		$harn->cond("parse cdrv_tmp"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'c:',			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 0,			$harn->cond("hybrid"));
is($o1->letter, 'c',			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [ 'c:' ],	$harn->cond("volumes"));

$harn->cwul($o1, qw[  volume  /cygdrive/c  c:  /mnt/c  /c ]);


is($o1->parse('/cygdrive/c/tmp'), 7,	$harn->cond("parse cygdrive_c_tmp"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'c:',			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 1,			$harn->cond("hybrid"));
is($o1->letter, 'c',			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'cyg',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [ 'cygdrive', 'c' ],	$harn->cond("volumes"));

$harn->cwul($o1, qw[  volume  /cygdrive/c  c:  /mnt/c  /c ]);


is($o1->parse('/tmp'), 3,		$harn->cond("parse tmp_2"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 0,			$harn->cond("hybrid"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse('\\\\wsl$\\Ubuntu'), 5,	$harn->cond("parse wsl8_ubuntu"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->hybrid, 1,			$harn->cond("hybrid"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'wsl',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [],		$harn->cond("folders"));
is_deeply($o1->volumes, [ 'wsl$', 'Ubuntu' ],	$harn->cond("volumes"));

#$harn->cwul($o1, qw[ volume /cygdrive/wsl$ //wsl$/Ubuntu //wsl$/Ubuntu /wsl$ ]);
#$harn->cwul($o1, qw[ volume /cygdrive/wsl$ //wsl$ //wsl$/Ubuntu /wsl$ ]);


is($o1->parse('\\\\server\\c$'), 5,	$harn->cond("parse server_c8"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, 'server',		$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 1,				$harn->cond("unc"));
is_deeply($o1->folders, [],		$harn->cond("folders"));
is_deeply($o1->volumes, [ 'c$' ],	$harn->cond("volumes"));

#$harn->cwul($o1, qw[ volume //server/c$ //server/c$ //server/c$ //server/c$ ]);


is($o1->parse('\\\\server\\c$\\tmp'), 7,	$harn->cond("parse server_c8_tmp"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, 'server',		$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 1,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [ 'c$' ],	$harn->cond("volumes"));

#$harn->cwul($o1, qw[ volume //server/c$ //server/c$ //server/c$ //server/c$ ]);


is($o1->parse('C:\Temp'), 4,		$harn->cond("parse cdrv_temp"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'C:',			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, 'C',			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [ 'C:' ],	$harn->cond("volumes"));

$harn->cwul($o1, qw[ volume /cygdrive/C C: /mnt/C /C ]);


is($o1->parse('C:/Temp'), 4,		$harn->cond("parse cdrv_temp_2"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'C:',			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, 'C',			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'Temp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [ 'C:' ],	$harn->cond("volumes"));

$harn->cwul($o1, qw[ volume /cygdrive/C C: /mnt/C /C ]);


is($o1->parse('\server\Temp'), 5,	$harn->cond("parse server_temp"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'server', 'Temp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));

$harn->cwul($o1, qw[ volume x /cygdrive/x x: /mnt/x /x ]);


is($o1->parse('\\\\server\\Temp'), 5,	$harn->cond("parse server_temp_2"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, 'server',		$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 1,				$harn->cond("unc"));
is_deeply($o1->folders, [],		$harn->cond("folders"));
is_deeply($o1->volumes, [ 'Temp' ],	$harn->cond("volumes"));

$harn->cwul($o1, qw[ volume z //server/z //server/z //server/z //server/z ]);


is($o1->parse('//server/Temp'), 5,	$harn->cond("parse server_temp_3"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, 'server',		$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 1,				$harn->cond("unc"));
is_deeply($o1->folders, [],		$harn->cond("folders"));
is_deeply($o1->volumes, [ 'Temp' ],	$harn->cond("volumes"));


is($o1->parse('\\\\server\\Temp'), 5,	$harn->cond("parse server_temp_5"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, 'server',		$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 1,				$harn->cond("unc"));
is_deeply($o1->folders, [],		$harn->cond("folders"));
is_deeply($o1->volumes, [ 'Temp' ],	$harn->cond("volumes"));


is($o1->parse('\\\\wsl$\\Ubuntu/home/jbloggs'), 9,	$harn->cond("parse winwslhome"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 1,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'wsl',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [qw/ home jbloggs /],	$harn->cond("folders"));
is_deeply($o1->volumes, [qw/ wsl$ Ubuntu /],	$harn->cond("volumes"));


is($o1->parse('/mnt/c/Users/jbloggs'), 9,	$harn->cond("parse wslwinhome"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'c:',			$harn->cond("drive"));
is($o1->homed, 1,			$harn->cond("homed"));
is($o1->letter, 'c',			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [qw/ Users jbloggs /],	$harn->cond("folders"));
#is_deeply($o1->folders, [qw/ mnt c Users jbloggs /],	$harn->cond("folders"));
is_deeply($o1->volumes, [qw/ mnt c /],	$harn->cond("volumes"));
#is_deeply($o1->volumes, [],	$harn->cond("volumes"));


is($o1->parse('C:\\Users\\jbloggs'), 6,	$harn->cond("parse winhome"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'C:',			$harn->cond("drive"));
is($o1->homed, 1,			$harn->cond("homed"));
is($o1->letter, 'C',			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [qw/ Users jbloggs /],	$harn->cond("folders"));
is_deeply($o1->volumes, [ "C:" ],	$harn->cond("volumes"));


is($o1->parse('/mnt/c/windows/temp'), 9,	$harn->cond("parse mnt_c_windows_temp"));
is($o1->server, undef,			$harn->cond("server"));
#$harn->cwul($o1, "letter", undef, undef, "c", undef);
is($o1->letter, 'c',			$harn->cond("letter"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->unc, 0,				$harn->cond("unc"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'c:',			$harn->cond("drive"));
#$harn->cwul($o1, "drive", undef, undef, "c:", undef);
my $ran = [ 'mnt', 'c', 'windows', 'temp' ];
#$harn->cwul($o1, "folders", $ran, $ran, [ 'windows', 'temp' ], $ran);
is_deeply($o1->folders, [ qw/ windows temp / ],	$harn->cond("folders"));
is_deeply($o1->volumes, [qw/ mnt c /],		$harn->cond("volumes"));
#is_deeply($o1->volumes, [ 'mnt', 'c' ],		$harn->cond("volumes"));

$harn->cwul($o1, qw[ volume /cygdrive/c c: /mnt/c /c ]);


is($o1->parse('\\mnt\\c\\window\\temp'), 9,	$harn->cond("parse mnt_c_window_temp"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->letter, 'c',			$harn->cond("letter"));
is($o1->unc, 0,				$harn->cond("unc"));
is($o1->type, 'win',			$harn->cond("type"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'c:',			$harn->cond("drive"));
is_deeply($o1->folders, [qw/ window temp /],	$harn->cond("folders"));
is_deeply($o1->volumes, [qw/ mnt c /],		$harn->cond("volumes"));


is($o1->parse('/cygdrive/c/windows/temp'), 9,	$harn->cond("parse cygdrive_c_windows_temp"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->letter, 'c',			$harn->cond("letter"));
is($o1->unc, 0,				$harn->cond("unc"));
is($o1->type, 'cyg',			$harn->cond("type"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, 'c:',			$harn->cond("drive"));
is_deeply($o1->folders, [qw/ windows temp /],	$harn->cond("folders"));
is_deeply($o1->volumes, [qw/ cygdrive c /],		$harn->cond("volumes"));


is($o1->parse('~/tmp'), 4,		$harn->cond("parse home_tmp"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 1,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [qw/ ~ tmp /],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));

$harn->cwul($o1, qw[ volume y /cygdrive/y y: /mnt/y /y ]);


is($o1->parse('/tmp'), 3,		$harn->cond("parse tmp_3"));
is($o1->abs, 1,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ 'tmp' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse("."), 2,			$harn->cond("parse cwd"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ '.' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse(".."), 2,			$harn->cond("parse parent"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ '..' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse("../.."), 4,		$harn->cond("parse parent"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 0,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [qw/ .. .. /],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


is($o1->parse('~'), 2,			$harn->cond("parse tilde"));
is($o1->abs, 0,				$harn->cond("abs"));
is($o1->drive, undef,			$harn->cond("drive"));
is($o1->homed, 1,			$harn->cond("homed"));
is($o1->letter, undef,			$harn->cond("letter"));
is($o1->server, undef,			$harn->cond("server"));
is($o1->type, 'lux',			$harn->cond("type"));
is($o1->unc, 0,				$harn->cond("unc"));
is_deeply($o1->folders, [ '~' ],	$harn->cond("folders"));
is_deeply($o1->volumes, [],		$harn->cond("volumes"));


# -------- parse (harness) --------
for my $pn ($harn->all_paths) {

	ok($o1->parse($pn) > 1,		$harn->cond("all parse"));
	ok(scalar($o1->folders),	$harn->cond("all folders"));

	no strict;

	for my $meth (qw/ homed type unc abs /) {

		isnt($o1->$meth, undef,		$harn->cond("all $meth"));
	}

	use strict;

	if (($o1->unc && $o1->type ne 'wsl') || $o1->type eq 'nfs') {
		isnt($o1->server, undef,	$harn->cond("server value"));
	} else {
		is($o1->server, undef,		$harn->cond("server undef"));
	}
}

__END__

=head1 DESCRIPTION

02_parse.t - test harness for the Batch::Exec::Path.pm module: path join

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

