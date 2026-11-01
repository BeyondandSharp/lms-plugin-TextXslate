package Plugins::TextXslate::Plugin;

use strict;
use warnings;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::TextXslate::API;

my $log = Slim::Utils::Log->addLogCategory({
	category     => 'plugin.textxslate',
	defaultLevel => 'ERROR',
	description  => 'Text::Xslate Format',
});

our $VERSION;

sub initPlugin {
	my ($class) = @_;

	$VERSION = $class->_pluginDataFor('version') || '0.0.0';

	Plugins::TextXslate::API->register;

	if ( defined &main::WEBUI && main::WEBUI() ) {
		require Plugins::TextXslate::Settings;
		Plugins::TextXslate::Settings->new();
	}

	return 1;
}

sub playerMenu {
	return;
}

1;
