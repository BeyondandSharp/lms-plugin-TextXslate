use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;
use TXFixture;
use TXCases;

my $functions_file = TXTest::plugin_file('functions.pl');
require $functions_file;

ok( Plugins::TextXslate::Functions->can('build'), 'functions.pl provides build()' );

# ---------------------------------------------------------------------------
# The table exposes exactly the documented functions
# ---------------------------------------------------------------------------

my $empty_table = Plugins::TextXslate::Functions->build( {} );

my @expected_names = sort( TXCases::function_names(), 'random' );
is_deeply( [ sort keys %{$empty_table} ], \@expected_names,
    'build() exposes exactly the documented functions' );
is( scalar keys %{$empty_table}, 56, '56 functions are exposed' );

for my $name ( sort keys %{$empty_table} ) {
    is( ref $empty_table->{$name}, 'CODE', "$name is a coderef" );
}

# ---------------------------------------------------------------------------
# Function results, replayed from the oracle generated on git HEAD
# ---------------------------------------------------------------------------

my $fixtures   = TXFixture::load_file( TXTest::fixture_file('functions.json') );
my @field_sets = map { TXFixture::decode_hash($_) } @{ $fixtures->{field_sets} };

for my $case ( @{ $fixtures->{cases} } ) {
    my $fields = $field_sets[ $case->{fields} ];
    my @args   = map { TXFixture::decode_value($_) } @{ $case->{args} };

    my $table = Plugins::TextXslate::Functions->build($fields);
    my $result;
    {
        local $SIG{__WARN__} = sub { };
        $result = $table->{ $case->{name} }->(@args);
    }

    ok(
        TXFixture::matches_fixture( $result, $case->{result} ),
        sprintf( '%s(%s)', $case->{name}, _describe_args(@args) ),
    ) or diag 'expected: ' . TXFixture::describe( $case->{result} );
}

# ---------------------------------------------------------------------------
# Stateful set() / get() sequences
# ---------------------------------------------------------------------------

for my $sequence ( @{ $fixtures->{sequences} } ) {
    my $fields = TXFixture::decode_hash( $sequence->{fields} );
    my $table  = Plugins::TextXslate::Functions->build($fields);

    for my $index ( 0 .. $#{ $sequence->{steps} } ) {
        my ( $name, @encoded_args ) = @{ $sequence->{steps}[$index] };
        my @args = map { TXFixture::decode_value($_) } @encoded_args;

        my $result;
        {
            local $SIG{__WARN__} = sub { };
            $result = $table->{$name}->(@args);
        }

        ok(
            TXFixture::matches_fixture( $result, $sequence->{results}[$index] ),
            "sequence $sequence->{name} step " . ( $index + 1 ) . " ($name)",
        ) or diag 'expected: ' . TXFixture::describe( $sequence->{results}[$index] );
    }
}

# ---------------------------------------------------------------------------
# random() is intentionally non-deterministic
# ---------------------------------------------------------------------------

for my $special ( @{ $fixtures->{special} } ) {
    next if $special->{check} ne 'range';

    my $in_range = 1;
    for ( 1 .. 200 ) {
        my $value = $empty_table->{ $special->{name} }->();
        $in_range = 0 if $value < 0 || $value > 4294967295;
    }
    ok( $in_range, "$special->{name} stays within 32 bits" );
}

sub _describe_args {
    my (@args) = @_;

    return join ', ', map { _describe_value($_) } @args;
}

sub _describe_value {
    my ($value) = @_;

    return 'undef' if !defined $value;

    if ( ref $value eq 'ARRAY' ) {
        return '[' . join( ',', map { _describe_value($_) } @{$value} ) . ']';
    }

    my $text = "$value";
    $text =~ s/([^\x20-\x7e])/sprintf '\\x{%x}', ord $1/ge;

    return $text;
}

done_testing();
