#!/usr/bin/perl
#
# 03_joiner.t - test harness for the Batch::Exec::Path.pm module: join paths
#
use strict;

#use Data::Compare;
use Data::Dumper;
#use Log::Log4perl qw/ :easy /; Log::Log4perl->easy_init($DEBUG);
use Logfer qw/ :all /;
use Test::More; # tests => 45;
use lib 't';
use Harness;


# -------- constants --------


# -------- global variables --------
my $harn = Harness->new('Batch::Exec::Path');
use_ok($harn->this);
my $log = get_logger(__FILE__);


# -------- main --------
$harn->planned(472);

my $o1 = Batch::Exec::Path->new;
isa_ok($o1, $harn->this,		$harn->cond("class check"));


# ---- joiner ----
SKIP: {
	skip "joiner fatal", 1;

	is($o1->joiner, "/",		$harn->cond("joiner fatal"));
}

my $count = 0;
for my $pni ($harn->all_paths) {

	ok($o1->parse($pni) > 1,	$harn->cond("parse"));

	my $pno = $o1->joiner;

	ok(length($pno),		$harn->cond("joiner length"));

	$log->debug("pni [$pni] pno [$pno]");

	is($pno, $pni,			$harn->cond("joiner match"));

	last if ($count++ > 14);
}


__END__

=head1 DESCRIPTION

03_joiner.t - test harness for the Batch::Exec::Path.pm module: join paths

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

