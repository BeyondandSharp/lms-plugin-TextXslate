package Slim::Web::Settings;

use strict;
use warnings;

our @HANDLER_CALLS;

sub reset {
    @HANDLER_CALLS = ();
    return;
}

sub new {
    my ($class, @args) = @_;
    return bless {}, $class;
}

sub prefs {
    return ();
}

sub handler {
    my ($class, $client, $paramRef, $pageSetup) = @_;
    push @HANDLER_CALLS, [ $class, $client, $paramRef, $pageSetup ];
    return $paramRef;
}

1;
