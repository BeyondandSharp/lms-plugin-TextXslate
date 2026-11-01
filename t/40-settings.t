use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;

use Encode ();
use File::Spec::Functions qw(catfile);
use Plugins::PerlEditor::API;
use Slim::Utils::Prefs;

use Plugins::TextXslate::Settings;

# ---------------------------------------------------------------------------
# Settings page metadata
# ---------------------------------------------------------------------------

is( Plugins::TextXslate::Settings->name, 'PLUGIN_TEXTXSLATE_SETTINGS', 'page name' );
is( Plugins::TextXslate::Settings->page, 'plugins/TextXslate/settings.html', 'page template' );
is_deeply( [ Plugins::TextXslate::Settings->prefs ], [], 'no preferences of its own' );

# ---------------------------------------------------------------------------
# Default table fallback
# ---------------------------------------------------------------------------

Slim::Utils::Prefs::reset;
my $prefs_dir = TXTest::temp_dir('textxslate-prefs');
Slim::Utils::Prefs->set_dir($prefs_dir);

my $default_source = _slurp( TXTest::plugin_file('functions.pl') );

my $params = {};
my $result = Plugins::TextXslate::Settings->handler( undef, $params );
is( $result, $params, 'handler returns the params hash reference' );
is( $params->{functionsSource}, $default_source,
    'the shipped functions.pl is shown when nothing is saved' );
is( $params->{perlEditorAvailable}, 0, 'perl editor reported unavailable' );

Plugins::PerlEditor::API->set_available(1);
$params = {};
Plugins::TextXslate::Settings->handler( undef, $params );
is( $params->{perlEditorAvailable}, 1, 'perl editor availability comes from PerlEditor' );
Plugins::PerlEditor::API::reset;

# ---------------------------------------------------------------------------
# Save round-trip, including UTF-8
# ---------------------------------------------------------------------------

my $custom_source = "my \$table = do '/wherever/functions.pl';\n"
    . "# \x{00e9}t\x{00e9} \x{4e2d}\x{6587}\n"
    . "return \$table;\n";
my $custom_file = catfile( $prefs_dir, 'textxslate_functions.pl' );

$params = { saveSettings => 1, functionsSource => $custom_source };
Plugins::TextXslate::Settings->handler( undef, $params );

is( $params->{functionsSource}, $custom_source, 'saved source is read back decoded' );
ok( -f $custom_file, 'the custom table file was written' );

my $raw = _slurp($custom_file);
ok( $raw eq Encode::encode( 'UTF-8', $custom_source ), 'the custom table is stored as UTF-8' );

$params = {};
Plugins::TextXslate::Settings->handler( undef, $params );
is( $params->{functionsSource}, $custom_source, 'a saved table is preferred over the default' );

# ---------------------------------------------------------------------------
# Degenerate input
# ---------------------------------------------------------------------------

unlink $custom_file;
$params = { saveSettings => 1 };
Plugins::TextXslate::Settings->handler( undef, $params );
is( $params->{functionsSource}, '', 'a missing functionsSource degrades to an empty string' );

open my $handle, '>:raw', $custom_file
    or die "cannot write $custom_file: $!";
print {$handle} "\xff\xfe\x00not utf8";
close $handle
    or die "cannot close $custom_file: $!";

$params = {};
Plugins::TextXslate::Settings->handler( undef, $params );
is( $params->{functionsSource}, "\xff\xfe\x00not utf8",
    'an undecodable table is passed through as raw bytes' );

sub _slurp {
    my ($path) = @_;

    open my $handle, '<:raw', $path
        or die "cannot read $path: $!";
    local $/ = undef;
    my $content = <$handle>;
    close $handle
        or die "cannot close $path: $!";

    return $content;
}

done_testing();
