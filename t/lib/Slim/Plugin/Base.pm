package Slim::Plugin::Base;

use strict;
use warnings;

our %PLUGIN_DATA;

sub reset {
    %PLUGIN_DATA = ();
    return;
}

sub set_plugin_data {
    my ($class, %data) = @_;
    %PLUGIN_DATA = %data;
    return;
}

sub new {
    my ($class, @args) = @_;
    return bless {}, $class;
}

sub _pluginDataFor {
    my ($class, $key) = @_;
    return $PLUGIN_DATA{$key};
}

sub playerMenu {
    return 1;
}

1;
