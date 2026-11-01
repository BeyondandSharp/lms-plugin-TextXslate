package TXFakeTrack;

use strict;
use warnings;

use TXFixture ();

# A configurable stand-in for an LMS track object.
#
# The config knows which LMS accessors exist ("methods"), which of them return
# values (absent key means "cannot"), and optionally a database result source
# ("columns" + "column_values").  TXFakeTrack::can() reports exactly those
# accessors so the plugin's `$track->can(...)` guards behave as in LMS.
#
# Configs are stored in the fixtures, so they must survive encode_config() /
# decode_config().

sub new {
    my ($class, $config) = @_;
    return bless { config => $config }, $class;
}

sub config {
    my ($self) = @_;
    return $self->{config};
}

sub can {
    my ($self, $method) = @_;

    my $config = $self->{config};
    return 1 if exists $config->{methods}{$method};
    return 1 if defined $config->{columns} && $method eq 'result_source';
    return 1 if defined $config->{columns} && $method eq 'get_column';

    return undef;
}

our $AUTOLOAD;

sub AUTOLOAD {
    my ($self, @args) = @_;

    my ($method) = $AUTOLOAD =~ m{::([^:]+)\z}x;
    return if !defined $method || $method eq 'DESTROY';

    my $config = $self->{config};

    if ( $method eq 'result_source' ) {
        return bless { columns => $config->{columns} }, 'TXFakeTrack::ResultSource';
    }

    if ( $method eq 'get_column' ) {
        my ($column) = @args;
        return $config->{column_values}{$column};
    }

    return $config->{methods}{$method};
}

# ---------------------------------------------------------------------------
# Fixture encoding
# ---------------------------------------------------------------------------

sub encode_config {
    my ($config) = @_;

    my %encoded = ( name => $config->{name} );

    if ( $config->{methods} ) {
        $encoded{methods} = {
            map { $_ => TXFixture::encode_value( $config->{methods}{$_} ) }
                keys %{ $config->{methods} }
        };
    }

    if ( $config->{columns} ) {
        $encoded{columns} = [ @{ $config->{columns} } ];
    }

    if ( $config->{column_values} ) {
        $encoded{column_values} = TXFixture::encode_hash( $config->{column_values} );
    }

    return \%encoded;
}

sub decode_config {
    my ($encoded) = @_;

    my %config = ( name => $encoded->{name} );

    if ( $encoded->{methods} ) {
        $config{methods} = {
            map { $_ => TXFixture::decode_value( $encoded->{methods}{$_} ) }
                keys %{ $encoded->{methods} }
        };
    }

    if ( $encoded->{columns} ) {
        $config{columns} = [ @{ $encoded->{columns} } ];
    }

    if ( $encoded->{column_values} ) {
        $config{column_values} = TXFixture::decode_hash( $encoded->{column_values} );
    }

    return \%config;
}

package TXFakeTrack::ResultSource;

use strict;
use warnings;

sub columns {
    my ($self) = @_;
    return @{ $self->{columns} };
}

1;
