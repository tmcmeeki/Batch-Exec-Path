#!/usr/bin/perl
#
# 02_parse.t - test harness for the Batch::Exec::Path.pm module: path join
#
use strict;

use Data::Compare;
use Data::Dumper;
#use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($ERROR);
use Logfer qw/ :all /;

use Test::More; # tests => 45;
use lib 't';
use Harness;


# -------- constants --------


# -------- global variables --------
my $harness = Harness->new('Batch::Exec::Path');

#BEGIN { use_ok('Batch::Exec::Path') };
use_ok($harness->this);

my $log = get_logger(__FILE__);



# -------- sub-routines --------


# -------- main --------
$harness->planned(210);
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harness->this,	"class check $cycle"); $cycle++;

#$o1 = ();
my $o2 = Batch::Exec::Path->new('shellify' => 1);
isa_ok($o1, $harness->this,	"class check $cycle"); $cycle++;


# -------- parse (specific) --------
is($o1->parse("./tmp"), 4,		"parse tmp");
is($o1->abs, 0,				"abs $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->unc, 0,				"unc $cycle");
is_deeply($o1->folders, [ '.', 'tmp' ],	"folders $cycle");

$cycle++;


is($o1->parse('foo/bar'), 4,		"parse foo_bar");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->abs, 0,				"abs $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'lux',			"type $cycle");
is_deeply($o1->folders, [ 'foo', 'bar' ],	"folders $cycle");
is($o1->drive, undef,			"drive $cycle");

$cycle++;


is($o1->parse('c:\tmp'), 4,		"parse cdrv_tmp");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, 'c:',			"drive $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->letter, 'c',			"letter $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->type, 'win',			"type $cycle");
is($o1->unc, 0,				"unc $cycle");
is_deeply($o1->folders, [ 'tmp' ],	"folders $cycle");

$cycle++;


is($o1->parse('/cygdrive/c/tmp'), 7,		"parse cygdrive_c_tmp");
is($o1->abs, 1,				"abs $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'cyg',			"type $cycle");
is_deeply($o1->folders, [ 'cygdrive', 'c', 'tmp' ],	"folders $cycle");
is($o1->drive, 'c:',			"drive $cycle");
is($o1->letter, 'c',			"letter $cycle");
is($o1->server, undef,			"server $cycle");

$cycle++;


is($o1->parse('/tmp'), 3,		"parse tmp_2");
is($o1->server, undef,			"server $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, undef,			"drive $cycle");
is_deeply($o1->folders, [ 'tmp' ],		"folders $cycle");

$cycle++;


is($o1->parse('\\\\wsl$\\Ubuntu'), 6,	"parse wsl8_ubuntu");
is($o1->server, undef,			"server $cycle");
is($o1->letter, 'wsl',			"letter $cycle");
is($o1->drive, 'wsl$',			"drive $cycle");
is_deeply($o1->folders, [ 'Ubuntu' ],	"folders $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'wsl',			"type $cycle");
is($o1->unc, 1,				"unc $cycle");
is($o1->abs, 1,				"abs $cycle");

$cycle++;


is($o1->parse('\\\\server\\c$'), 6,	"parse server_c8");
is($o1->type, 'win',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->unc, 1,				"unc $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, 'c$',			"drive $cycle");
is_deeply($o1->folders, [],		"folders $cycle");
is($o1->server, 'server',		"server $cycle");
is($o1->letter, 'c',			"letter $cycle");

$cycle++;


is($o1->parse('\\\\server\\c$\\tmp'), 8,	"parse server_c8_tmp");
is($o1->server, 'server',		"server $cycle");
is($o1->letter, 'c',			"letter $cycle");
is($o1->drive, 'c$',			"drive $cycle");
is_deeply($o1->folders, [ 'tmp' ],		"folders $cycle");
is($o1->unc, 1,				"unc $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'win',			"type $cycle");
is($o1->abs, 1,				"abs $cycle");

$cycle++;


is($o1->parse('C:\Temp'), 4,		"parse cdrv_temp");
is($o1->server, undef,			"server $cycle");
is($o1->letter, 'C',			"letter $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->type, 'win',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, 'C:',			"drive $cycle");
is_deeply($o1->folders, [ 'Temp' ],	"folders $cycle");

$cycle++;


is($o1->parse('C:/Temp'), 4,		"parse cdrv_temp_2");
is($o1->server, undef,			"server $cycle");
is($o1->letter, 'C',			"letter $cycle");
is($o1->drive, 'C:',			"drive $cycle");
is_deeply($o1->folders, [ 'Temp' ],	"folders $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->abs, 1,				"abs $cycle");

$cycle++;


is($o1->parse('\server\Temp'), 5,	"parse server_temp");
is($o1->drive, undef,			"drive $cycle");
is_deeply($o1->folders, [ 'server', 'Temp' ],	"folders $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'win',			"type $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->letter, undef,			"letter $cycle");

$cycle++;


is($o1->parse('\\\\server\\Temp'), 6,	"parse server_temp_2");
is($o1->abs, 1,				"abs $cycle");
is($o1->unc, 1,				"unc $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'win',			"type $cycle");
is_deeply($o1->folders, [ 'Temp' ],	"folders $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, 'server',		"server $cycle");

$cycle++;


is($o1->parse('//server/Temp'), 6,	"parse server_temp_3");
is($o1->server, 'server',		"server $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->drive, undef,			"drive $cycle");
is_deeply($o1->folders, [ 'Temp' ],	"folders $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->unc, 1,				"unc $cycle");
is($o1->abs, 1,				"abs $cycle");

$cycle++;


is($o1->parse('\\\\server\\Temp'), 6,	"parse server_temp_5");
is($o1->abs, 1,				"abs $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->type, 'win',			"type $cycle");
is($o1->unc, 1,				"unc $cycle");
is_deeply($o1->folders, [ 'Temp' ],	"folders $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, 'server',		"server $cycle");

$cycle++;


is($o1->parse('/mnt/c//windows/temp'), 10,	"parse mnt_c_windows_temp");
is($o1->server, undef,			"server $cycle");
is($o1->letter, 'c',			"letter $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, 'c:',			"drive $cycle");
is_deeply($o1->folders, [ 'mnt', 'c', 'windows', 'temp' ],		"folders $cycle");

$cycle++;


is($o1->parse('\\mnt\\c\\window\\temp'), 9,	"parse mnt_c_window_temp");
is($o1->server, undef,			"server $cycle");
is($o1->letter, 'c',			"letter $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->type, 'win',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, 'c:',			"drive $cycle");
is_deeply($o1->folders, [ 'mnt', 'c', 'window', 'temp' ],		"folders $cycle");

$cycle++;


is($o1->parse('/cygdrive/c/windows/temp'), 9,	"parse cygdrive_c_windows_temp");
is($o1->server, undef,			"server $cycle");
is($o1->letter, 'c',			"letter $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->type, 'cyg',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->drive, 'c:',			"drive $cycle");
is_deeply($o1->folders, [ 'cygdrive', 'c', 'windows', 'temp' ],	"folders $cycle");

$cycle++;


is($o1->parse('//wsl$/Ubuntu/home/user'), 10,	"parse wsl8_ubuntu_home_user");
is($o1->letter, 'wsl',			"letter $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->unc, 1,				"unc $cycle");
is($o1->homed, 1,			"homed $cycle");
is($o1->type, 'wsl',			"type $cycle");
is_deeply($o1->folders, [ 'Ubuntu', 'home', 'user' ],	"folders $cycle");
is($o1->drive, 'wsl$',			"drive $cycle");

$cycle++;


is($o1->parse('~/tmp'), 4,		"parse home_tmp");
is($o1->abs, 1,				"abs $cycle");
is($o1->homed, 1,			"homed $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->unc, 0,				"unc $cycle");
is_deeply($o1->folders, [ 'tmp' ],		"folders $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");

$cycle++;


is($o1->parse('/tmp'), 3,		"parse tmp_3");
is_deeply($o1->folders, [ 'tmp' ],		"folders $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->abs, 1,				"abs $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");

$cycle++;


is($o1->parse("."), 2,			"parse cwd");
is($o1->abs, 0,				"abs $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->unc, 0,				"unc $cycle");
is_deeply($o1->folders, [ '.' ],	"folders $cycle");

$cycle++;


is($o1->parse(".."), 2,			"parse parent");
is($o1->abs, 0,				"abs $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->homed, 0,			"homed $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");
is($o1->type, 'lux',			"type $cycle");
is($o1->unc, 0,				"unc $cycle");
is_deeply($o1->folders, [ '..' ],	"folders $cycle");

$cycle++;


is($o1->parse('~'), 2,			"parse tilde");
is($o1->abs, 1,				"abs $cycle");
is($o1->unc, 0,				"unc $cycle");
is($o1->homed, 1,			"homed $cycle");
is($o1->type, 'lux',			"type $cycle");
is_deeply($o1->folders, [],		"folders $cycle");
is($o1->drive, undef,			"drive $cycle");
is($o1->letter, undef,			"letter $cycle");
is($o1->server, undef,			"server $cycle");


# -------- parse (harness) --------
for my $pn ($harness->all_paths) {

	isnt($o1->homed, undef,		$harness->cond("homed $pn");
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

