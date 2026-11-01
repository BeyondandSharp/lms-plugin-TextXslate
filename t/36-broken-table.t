use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;

use File::Spec::Functions qw(catfile);
use Slim::Utils::Prefs;

# A broken custom table must not break the plugin: the shipped functions.pl is
# still available as a fallback.  This has to run in its own process because a
# successfully loaded table is cached in Plugins::TextXslate::Functions.

my $prefs_dir = TXTest::temp_dir('textxslate-broken');
Slim::Utils::Prefs->set_dir($prefs_dir);

my $custom_file = catfile( $prefs_dir, 'textxslate_functions.pl' );
open my $handle, '>:raw', $custom_file
    or die "cannot write $custom_file: $!";
print {$handle} "this is not valid perl {{{\n";
close $handle
    or die "cannot close $custom_file: $!";

require Plugins::TextXslate::API;

my $result = Plugins::TextXslate::API->format( { title => 'T' }, '<: number(7, 3) :>|<: meta("title") :>' );

is( $result->{error}, '',             'a broken custom table falls back to the shipped one' );
is( $result->{text},  '007|T',        'the fallback table behaves normally' );

done_testing();
