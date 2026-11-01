package Slim::Utils::Misc;

use strict;
use warnings;

# Minimal stand-in for LMS's URL to path conversion.  Handles the subset the
# plugin relies on: file:// URLs, localhost authorities and %XX escapes.
sub pathFromFileURL {
    my ($url) = @_;

    return '' unless defined $url;

    my $path = $url;
    $path =~ s{\Afile://}{}x;
    $path =~ s{\Alocalhost(?=/)}{}x;
    $path =~ s{%([0-9A-Fa-f]{2})}{chr hex $1}gex;
    $path =~ s{\A/+}{/}x if $path =~ m{\A/+}x;

    return $path;
}

1;
