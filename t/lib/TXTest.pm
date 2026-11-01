package TXTest;

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir catfile rel2abs);
use File::Temp ();

# The plugin keeps the classic flat LMS layout: this repository is the
# Plugins/TextXslate directory, so Plugins::TextXslate::Foo is Foo.pm at the
# repository root.  t/lib/Plugins/TextXslate is a symlink back to the root, so
# `use lib "$Bin/lib"` makes every plugin package load with an absolute
# __FILE__, exactly like LMS loads it.
my $LIB  = rel2abs( dirname(__FILE__) );
my $ROOT = rel2abs( catfile( $LIB, '..', '..' ) );

my $PLUGIN_LIB = catdir( $LIB, 'Plugins', 'TextXslate' );

if ( !-e catfile( $PLUGIN_LIB, 'API.pm' ) ) {
    die "TXTest: $PLUGIN_LIB is not linked to the plugin root.\n"
      . "Run: ln -s ../../.. t/lib/Plugins/TextXslate\n";
}

sub root        { return $ROOT }
sub lib_dir     { return $LIB }
sub plugin_file { return catfile( $ROOT, @_ ) }

# Create a scratch directory that is removed when the process exits.
sub temp_dir {
    my ($label) = @_;
    return File::Temp::tempdir(
        ( defined $label ? $label : 'textxslate' ) . '-XXXXXX',
        TMPDIR  => 1,
        CLEANUP => 1,
    );
}

sub fixture_file {
    return catfile( $ROOT, 't', 'fixtures', @_ );
}

1;
