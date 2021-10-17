use lib 't';

use Test::More;
use Log::Log4perl qw/ :easy /;

use Harness;

# --- main ---
Log::Log4perl->easy_init($DEBUG);

my $harn = Harness->new("hello");
#$harn->log->error("HELLO");
$harn->planned(57);

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
is(ref($harn->_path), "ARRAY",	"path hash");
is(scalar(@{ $harn->_path }), 32,	"hash entries");

for(@{ $harn->_path }) {

	is(keys(%{ $_ }), 6,		$harn->cond("keys"));
}


# --- filtering ---
my @paths = $harn->filter('root', "/");
is(scalar(@paths), 13,				"filter root");

my @paths = $harn->filter("volume", "C");
is(scalar(@paths), 3,				$harn->cond("volume"));
is(scalar($harn->filter("volume", "C")), 3,	$harn->cond("volume"));
is(scalar($harn->filter("volume", "c")), 3,	$harn->cond("volume"));
is(scalar($harn->filter("volume", "D")), 1,	$harn->cond("volume"));

@paths = $harn->invalid;
is(scalar(@paths), 3,				$harn->cond("invalid"));
@paths = $harn->valid;
is(scalar(@paths), 29,				$harn->cond("valid"));

