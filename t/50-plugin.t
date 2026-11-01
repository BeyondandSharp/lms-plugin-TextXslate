use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;

use Slim::Plugin::Base;
use Slim::Utils::Log;

use Plugins::TextXslate::API;
use Plugins::TextXslate::Plugin;

# ---------------------------------------------------------------------------
# Plugin data and registration
# ---------------------------------------------------------------------------

Slim::Plugin::Base->set_plugin_data( version => "1.2.3" );

ok( !defined &main::WEBUI, 'no web UI is defined' );
ok( !$INC{'Plugins/TextXslate/Settings.pm'}, 'Settings is not loaded yet' );

is( Plugins::TextXslate::Plugin->initPlugin, 1, 'initPlugin returns 1' );
is( $Plugins::TextXslate::Plugin::VERSION, '1.2.3', 'VERSION comes from plugin metadata' );
ok( Plugins::TextXslate::API->available, 'initPlugin registers the API' );
ok( !$INC{'Plugins/TextXslate/Settings.pm'}, 'Settings stays unloaded without a web UI' );

# ---------------------------------------------------------------------------
# Web UI branch
# ---------------------------------------------------------------------------

*main::WEBUI = sub { return 1 };
Plugins::TextXslate::Plugin->initPlugin;
ok( $INC{'Plugins/TextXslate/Settings.pm'}, 'Settings is loaded when a web UI exists' );

# ---------------------------------------------------------------------------
# Miscellany
# ---------------------------------------------------------------------------

is( Plugins::TextXslate::Plugin->playerMenu, undef, 'playerMenu is empty' );

my $logger = Slim::Utils::Log->category_for('plugin.textxslate');
ok( $logger, 'the plugin registers its log category' );
is( $logger->{category}, 'plugin.textxslate', 'log category name' );

done_testing();
