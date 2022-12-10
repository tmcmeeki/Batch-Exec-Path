#!/usr/bin/perl
#
# 03_wsl.t - test harness for the Batch::Exec::Path.pm module: WSL handling
#
use strict;

use Data::Compare;
use Data::Dumper;
#use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($DEBUG);
use Logfer qw/ :all /;
use Test::More tests => 45;

BEGIN { use_ok('Batch::Exec::Path') };


# -------- constants --------


# -------- global variables --------
my $log = get_logger(__FILE__);


# -------- main --------
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, "Batch::Exec::Path",	"class check $cycle"); $cycle++;


# -------- wslroot --------
if ($o1->on_wsl) {

	$log->info("platform: WSL");

	like($o1->_wslroot, qr/wsl/,	"_wslroot defined");

	is($o1->wslroot, undef,		"wslroot undefined");

} elsif ($o1->on_cygwin) {

	$log->info("platform: CYGWIN");

	isnt($o1->_wslroot, undef,	"_wslroot defined");
	if ($o1->wsl_active) {
		isnt($o1->wslroot, undef,	"wslroot defined");
	} else {
		is($o1->wslroot, undef,	"wslroot defined");
	}

} elsif ($o1->on_windows) {

	$log->info("platform: Windows");

	isnt($o1->_wslroot, undef,	"_wslroot defined");
	if ($o1->wsl_active) {
		isnt($o1->wslroot, undef,	"wslroot defined");
	} else {
		is($o1->wslroot, undef,	"wslroot defined");
	}

} else {

	$log->info("platform: OTHER");

	is($o1->_wslroot, undef,	"_wslroot undefined");
	is($o1->wslroot, undef,		"wslroot undefined");
}


# -------- wslhome --------
my $o3 = Batch::Exec::Path->new;
isa_ok($o3, $harness->this,	"class check $cycle"); $cycle++;

if ($o3->like_windows) {
	like($o1->wslroot, qr/wsl/,	"wslroot IS on_wsl raw");
	like($o3->wslroot, qr/wsl/,	"wslroot IS on_wsl convert");

	like($o1->wslhome, qr/wsl.*home/,	"wslhome IS on_wsl raw");
	like($o3->wslhome, qr/wsl.*home/,	"wslhome IS on_wsl convert");
} else {
	is($o1->wslroot, undef,	"wslroot ISNT on_wsl raw");
	is($o3->wslroot, undef,	"wslroot ISNT on_wsl convert");

	is($o1->wslhome, undef,	"wslhome ISNT on_wsl raw");
	is($o3->wslhome, undef,	"wslhome ISNT on_wsl convert");
}


__END__

=head1 DESCRIPTION

03_wsl.t - test harness for the Batch::Exec::Path.pm module: WSL handling

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

