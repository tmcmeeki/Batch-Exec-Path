#!/usr/bin/perl
#
# 02volume.t - test harness for the Batch::Exec::Path.pm module: pathnames
#
use strict;

use Data::Compare;
use Data::Dumper;
use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($DEBUG);
#use Logfer qw/ :all /;
use Test::More tests => 45;

BEGIN { use_ok('Batch::Exec::Path') };


# -------- constants --------
use constant RE_PATH_DELIM => qr/[\\\/]+/;


# -------- global variables --------
my $log = get_logger(__FILE__);


# -------- main --------
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, "Batch::Exec::Path",	"class check $cycle"); $cycle++;


# ---- splitdir ----
$log->info("hello");

$o1->splitdir('C:\Temp00');
$o1->splitdir("\\\\server\\Temp05");
$o1->splitdir('//server/Temp03b');
# ---- volume ----
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

02volume.t - test harness for the Batch::Exec::Path.pm module: pathnames

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

