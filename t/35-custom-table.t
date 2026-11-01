use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;

use File::Spec::Functions qw(catfile);
use Slim::Utils::Prefs;

# The custom table must be in place before the plugin loads it, because a
# loaded table is intentionally cached for the lifetime of the LMS process.

my $prefs_dir = TXTest::temp_dir('textxslate-custom');
Slim::Utils::Prefs->set_dir($prefs_dir);

my $custom_file = catfile( $prefs_dir, 'textxslate_functions.pl' );
my $custom_source = <<'CUSTOM';
package Plugins::TextXslate::Functions;

use strict;
use warnings;

sub shout {
	my ($value) = @_;
	return uc $value;
}

sub build {
	my ( $class, $fields ) = @_;
	return {
		shout => \&shout,
	};
}

1;
CUSTOM

open my $handle, '>:raw', $custom_file
    or die "cannot write $custom_file: $!";
print {$handle} $custom_source
    or die "cannot write $custom_file: $!";
close $handle
    or die "cannot close $custom_file: $!";

require Plugins::TextXslate::API;

my $custom = Plugins::TextXslate::API->format( {}, '<: shout("hello") :>' );
is( $custom->{text},  'HELLO', 'the saved custom table is used' );
is( $custom->{error}, '',      'the custom table renders without error' );

my $missing = Plugins::TextXslate::API->format( {}, '<: number(7, 3) :>' );
ok( $missing->{error} ne '', 'only the functions of the custom table exist' );

done_testing();
