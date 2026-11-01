use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;

use_ok('Plugins::TextXslate::API');
use_ok('Plugins::TextXslate::Plugin');
require_ok('Plugins::TextXslate::Settings');

ok( -f TXTest::plugin_file('functions.pl'), 'functions.pl is present' );
ok( !-f TXTest::plugin_file('Functions.pm'), 'the split Functions.pm is gone' );
ok( -f TXTest::plugin_file('.perlcriticrc'), '.perlcriticrc is present' );

my $functions_file = TXTest::plugin_file('functions.pl');
require_ok($functions_file);

ok( Plugins::TextXslate::Functions->can('build'), 'functions.pl defines build()' );

done_testing();
