#!/usr/bin/perl
#
# 02_joiner.t - test harness for the Batch::Exec::Path.pm module: path join
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
$harness->planned(36);
my $cycle = 1;

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harness->this,	"class check $cycle"); $cycle++;

my $o2 = Batch::Exec::Path->new('shellify' => 1);
isa_ok($o1, $harness->this,	"class check $cycle"); $cycle++;


# ---- joiner basic ----
is($o1->joiner(""), "/",			$harness->cond("join root");
is($o1->joiner("", ""), "//",			$harness->cond("join 2root");


# ---- joiner full ----
for my $pn ($harness->all_paths) {

	$log->info("pn [$pn]");

	my @split = $o1->splitter($pn);

	if ($pn eq '/') {
		ok(scalar(@split) == 0,		$harness->cond("spliter zero"));
	} else {
		ok(scalar(@split) > 0,		$harness->cond("spliter non-zero"));
		my $after = $o1->joiner(@split);

		$log->info("after [$after]");
	}
}


__END__

=head1 DESCRIPTION

02_joiner.t - test harness for the Batch::Exec::Path.pm module: path join

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

