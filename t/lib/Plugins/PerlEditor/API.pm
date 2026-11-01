package Plugins::PerlEditor::API;

use strict;
use warnings;

our $AVAILABLE = 0;

sub reset {
    $AVAILABLE = 0;
    return;
}

sub set_available {
    my ($class, $value) = @_;
    $AVAILABLE = $value ? 1 : 0;
    return;
}

sub available {
    return $AVAILABLE;
}

1;
