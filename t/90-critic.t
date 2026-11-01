use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;

# ---------------------------------------------------------------------------
# Perl::Critic gate: the whole point of the rewrite is that this is silent.
# ---------------------------------------------------------------------------

my $have_critic = system( $^X, '-MPerl::Critic', '-e', '1' ) == 0;
plan skip_all => 'Perl::Critic is not installed' if !$have_critic;

my $have_cli = system( 'sh', '-c', 'command -v perlcritic >/dev/null 2>&1' ) == 0;
plan skip_all => 'perlcritic is not on PATH' if !$have_cli;

my $root = TXTest::root();
chdir $root or die "cannot chdir to $root: $!";

my @files = qw(API.pm functions.pl Plugin.pm Settings.pm);
my @output = qx{perlcritic --quiet --severity 3 @files 2>&1};
my $status = $?;

is( $status >> 8, 0, 'perlcritic --severity 3 exits successfully' )
    or diag @output;
is_deeply( \@output, [], 'perlcritic --severity 3 reports no violations' );

done_testing();
