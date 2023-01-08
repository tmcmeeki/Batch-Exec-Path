use warnings;
use strict;

use lib 't';

use Data::Dumper;
use Test::More;
use Log::Log4perl qw/ :easy /;

use Harness;

# --- main ---
Log::Log4perl->easy_init($DEBUG);

my $harn = Harness->new("hello");
$harn->planned(726);

is($harn->this, "hello",		"this");


# --- poll ---
my ($grp, $val) = $harn->poll;
is($grp, 'default',			"default poll group");
is($val, 0,				"default poll value");
($grp, $val) = $harn->poll('group1');
is($grp, 'group1',			"group1 poll group");
is($val, 0,				"group1 poll value");
($grp, $val) = $harn->poll('group2');
is($grp, 'group2',			"group2 poll group");
is($val, 0,				"group2 poll value");


# --- cycle ---
is($harn->cycle, 1,			"default cycle");
is($harn->cycle('group1'), 1,		"group1 cycle");
is($harn->cycle('group2'), 1,		"group2 cycle");
is($harn->cycle('group2'), 2,		"group2 cycle");


# --- cond ---
is($harn->cond, "default cycle=2",	"default cond");
is($harn->cycle, 3,			"default third cycle");
is($harn->cond, "default cycle=4",	"default fourth cond");
is($harn->cond('group1'), "group1 cycle=2",	"group1 second cond");
is($harn->cond('group2'), "group2 cycle=3",	"group2 third cond");


# --- paths ---
is(ref($harn->_path), "ARRAY",		"path hash");
is(scalar(@{ $harn->_path }), 40,	"hash entries");

for(@{ $harn->_path }) {

	is(keys(%{ $_ }), 7,		$harn->cond("keys"));
}


# --- all ---
my @keys; for ($harn->all) {

	@keys = keys(%{ $_ });

	is(@keys, 7,			$harn->cond("all"));
}
#$harn->log->debug(sprintf "keys [%s]", Dumper(\@keys));


# --- all singleton select ---
for my $key (@keys) {

	for ($harn->all($key)) {

		is(scalar(keys %$_), 1,		$harn->cond("singleton $key"));
	}
}

# --- all multi select ---
while (@keys) {
	my $columns = scalar(@keys);

	for ($harn->all(@keys)) {

		is(scalar(keys %$_), $columns,	$harn->cond("multi $columns"));
	}
	shift @keys;
}


# --- filtering ---
my @paths = $harn->filter('root', "/");
is(scalar(@paths), 15,				"filter root");

@paths = $harn->filter("volume", "C");
is(scalar(@paths), 3,				$harn->cond("volume"));
is(scalar($harn->filter("volume", "C")), 3,	$harn->cond("volume"));
is(scalar($harn->filter("volume", "c")), 3,	$harn->cond("volume"));
is(scalar($harn->filter("volume", "D")), 1,	$harn->cond("volume"));

@paths = $harn->invalid;
is(scalar(@paths), 5,				$harn->cond("invalid"));
@paths = $harn->valid;
is(scalar(@paths), 35,				$harn->cond("valid"));


# --- path functions ---
is(scalar($harn->all_paths), 40,		$harn->cond("all_paths"));
is(scalar($harn->valid_paths), 35,		$harn->cond("valid_paths"));
is(scalar($harn->linux), 27,			$harn->cond("linux"));
is(scalar($harn->windows), 8,			$harn->cond("windows"));


# --- fs2bs ---
my $re_fs = qr[/];
my $re_bs = qr[\\];
for my $from (qw[ / // a/b/c  /a/b a/b/c ]) {

	# --- fs2bs (swap) ---
	my $to = $harn->fs2bs($from);

	is(length($from), length($to),	$harn->cond("fs2bs length"));

	like($from, $re_fs,		$harn->cond("fs2bs from LK re"));
	unlike($from, $re_bs,		$harn->cond("fs2bs from UL re"));

	like($to, $re_bs,		$harn->cond("fs2bs to LK re"));
	unlike($to, $re_fs,		$harn->cond("fs2bs to UL re"));


	# --- fs2bs (shell) ---
	$to = $harn->fs2bs($from, 1);

	ok(length($from) < length($to),	$harn->cond("fs2bs shell length"));

	like($from, $re_fs,		$harn->cond("fs2bs shell from LK re"));
	unlike($from, $re_bs,		$harn->cond("fs2bs shell from UL re"));

	like($to, $re_bs,		$harn->cond("fs2bs shell to LK re"));
	unlike($to, $re_fs,		$harn->cond("fs2bs shell to UL re"));
}


# --- fs2bs (shell, advanced) ---
is($harn->fs2bs(" "), " ",		$harn->cond("fs2bs space base"));
is($harn->fs2bs(" ", 1), "\\ ",		$harn->cond("fs2bs space shell"));

is($harn->fs2bs("'"), "'",		$harn->cond("fs2bs sq base"));
is($harn->fs2bs("'", 1), "\\'",		$harn->cond("fs2bs sq shell"));


# --- cwul ---
$harn->cwul($harn, qw[ fs2bs  dummy  dummy  dummy  dummy  dummy  ]);

my $red = qr/^dummy$/;

$harn->cwul($harn, "fs2bs", "dummy", $red, $red, $red, $red);

my $rad = [ qw/ dummy dummy / ];

$harn->cwul($harn, "fs2bs", $rad, $rad, $rad, $rad, $rad);

