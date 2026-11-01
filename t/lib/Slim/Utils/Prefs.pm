package Slim::Utils::Prefs;

use strict;
use warnings;

our $DIRECTORY;
our %VALUES;

sub reset {
    $DIRECTORY = undef;
    %VALUES    = ();
    return;
}

sub set_dir {
    my ($class, $dir) = @_;
    $DIRECTORY = $dir;
    return;
}

# LMS exports dir() as a plain function, and the plugin calls it that way.
sub dir {
    return $DIRECTORY;
}

sub preferences {
    my ($class, $namespace) = @_;
    return bless { namespace => $namespace }, 'Slim::Utils::Prefs::Namespace';
}

sub get_global {
    my ($class, $key) = @_;
    return $VALUES{$key};
}

sub set_global {
    my ($class, $key, $value) = @_;
    $VALUES{$key} = $value;
    return;
}

package Slim::Utils::Prefs::Namespace;

use strict;
use warnings;

sub get {
    my ($self, $key) = @_;
    return $VALUES{ $self->{namespace} . '::' . $key };
}

sub set {
    my ($self, $key, $value) = @_;
    $VALUES{ $self->{namespace} . '::' . $key } = $value;
    return;
}

1;
