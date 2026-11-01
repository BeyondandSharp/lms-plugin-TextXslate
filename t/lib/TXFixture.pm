package TXFixture;

use strict;
use warnings;

use JSON::PP ();
use English qw(-no_match_vars $INPUT_RECORD_SEPARATOR);

my $SAVE = JSON::PP->new->canonical->utf8;
my $CMP  = JSON::PP->new->canonical->utf8;

# ---------------------------------------------------------------------------
# Value encoding
#
# Fixtures are JSON, so values that Perl distinguishes but JSON does not need
# an explicit type tag: undef, strings (with their UTF-8 flag), numbers and
# arrays.  encode_value()/decode_value() round-trip a Perl value losslessly
# enough to compare template function results.
# ---------------------------------------------------------------------------

sub encode_value {
    my ($value) = @_;

    return { t => 'undef' } if !defined $value;

    if ( ref $value eq 'ARRAY' ) {
        return {
            t => 'arr',
            v => [ map { encode_value($_) } @{$value} ],
        };
    }

    if ( ref $value ) {
        return { t => 'str', v => "$value" };
    }

    if ( !utf8::is_utf8($value) && $value =~ m{\A-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)\z}x ) {
        my $number = 0 + $value;
        # Only a value that round-trips through stringification is a number;
        # "08" and "3.90" keep their string form and must stay strings.
        return { t => 'num', v => $number } if "$value" eq "$number";
    }

    return {
        t => 'str',
        v => "$value",
        u => ( utf8::is_utf8($value) ? 1 : 0 ),
    };
}

sub decode_value {
    my ($encoded) = @_;

    return undef if !defined $encoded;

    my $type = $encoded->{t} || "str";

    return undef if $type eq "undef";

    if ( $type eq 'arr' ) {
        return [ map { decode_value($_) } @{ $encoded->{v} } ];
    }

    if ( $type eq 'num' ) {
        return 0 + $encoded->{v};
    }

    my $value = $encoded->{v};
    $value = '' if !defined $value;

    if ( $encoded->{u} ) {
        utf8::upgrade($value);
    }
    else {
        utf8::downgrade( $value, 1 );
    }

    return $value;
}

# ---------------------------------------------------------------------------
# Whole-file helpers
# ---------------------------------------------------------------------------

sub load_file {
    my ($path) = @_;

    open my $handle, '<:raw', $path
        or die "TXFixture: cannot read $path: $!\n";

    my $raw = '';
    {
        local $INPUT_RECORD_SEPARATOR = undef;
        $raw = <$handle>;
    }
    close $handle
        or die "TXFixture: cannot close $path: $!\n";

    return $SAVE->decode($raw);
}

sub save_file {
    my ($path, $data) = @_;

    open my $handle, '>:raw', $path
        or die "TXFixture: cannot write $path: $!\n";

    print {$handle} $SAVE->encode($data)
        or die "TXFixture: cannot write $path: $!\n";
    close $handle
        or die "TXFixture: cannot close $path: $!\n";

    return 1;
}

# A canonical, comparable representation of a Perl value.
sub canonical {
    my ($value) = @_;
    return $CMP->encode( encode_value($value) );
}

# Compare an actual Perl value with an already-encoded fixture value.
sub matches_fixture {
    my ( $actual, $expected_encoded ) = @_;
    return canonical($actual) eq $CMP->encode($expected_encoded);
}

# Compare an actual hashref with an already-encoded fixture hash.
sub matches_encoded_hash {
    my ( $actual, $expected_encoded ) = @_;
    return $CMP->encode( encode_hash($actual) ) eq $CMP->encode($expected_encoded);
}

sub describe {
    my ($encoded) = @_;
    return $CMP->encode($encoded);
}

# ---------------------------------------------------------------------------
# Encoded hashrefs (track field sets, fake track configs)
# ---------------------------------------------------------------------------

sub encode_hash {
    my ($hash) = @_;
    return { map { $_ => encode_value( $hash->{$_} ) } keys %{$hash} };
}

sub decode_hash {
    my ($encoded) = @_;
    return { map { $_ => decode_value( $encoded->{$_} ) } keys %{$encoded} };
}

1;
