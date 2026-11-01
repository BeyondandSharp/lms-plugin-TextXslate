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
	my $class = shift;

	$VERSION = $class->_pluginDataFor('version') || '0.0.0';

	Plugins::TextXslate::API->register;

	if (main::WEBUI) {
		require Plugins::TextXslate::Settings;
		Plugins::TextXslate::Settings->new();
	}

	return 1;
}

sub playerMenu {}

1;
