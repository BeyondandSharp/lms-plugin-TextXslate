use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use TXTest;
use TXFixture;

use Plugins::TextXslate::API;

# ---------------------------------------------------------------------------
# Templates that do not use the custom function table
# ---------------------------------------------------------------------------

my $fixtures   = TXFixture::load_file( TXTest::fixture_file('format.json') );
my @field_sets = map { TXFixture::decode_hash($_) } @{ $fixtures->{field_sets} };

Plugins::TextXslate::API->register;

for my $case ( @{ $fixtures->{cases} } ) {
    my $fields = $field_sets[ $case->{fields} ];

    my $result = Plugins::TextXslate::API->format( $fields, $case->{template} );

    if ( $case->{error} ) {
        ok( $result->{error} ne '', "reports an error: $case->{name}" )
            or diag explain $result;
        is( $result->{text}, '', "no text on error: $case->{name}" );
        next;
    }

    is( $result->{error}, '', "renders without error: $case->{name}" )
        or diag $result->{error};

    ok(
        TXFixture::matches_fixture( $result->{text}, $case->{text} ),
        "text matches HEAD: $case->{name}",
    ) or diag 'expected: ' . TXFixture::describe( $case->{text} );
}

# ---------------------------------------------------------------------------
# Every template function is reachable through Text::Xslate and returns the
# value the function-level oracle expects
# ---------------------------------------------------------------------------

for my $case ( @{ $fixtures->{function_cases} } ) {
    my $fields = $field_sets[ $case->{fields} ];

    my $result = Plugins::TextXslate::API->format( $fields, $case->{template} );

    is( $result->{error}, '', "renders without error: $case->{name}" )
        or diag $result->{error};

    ok(
        TXFixture::matches_fixture( $result->{text}, $case->{text} ),
        "template output matches HEAD: $case->{name}",
    ) or diag 'expected: ' . TXFixture::describe( $case->{text} );
}

# ---------------------------------------------------------------------------
# A few guarantees the fixtures cannot express
# ---------------------------------------------------------------------------

my $fields = {
    filename  => '08. The Birthday.flac',
    directory => '/music/Final',
    title     => 'The Birthday',
};

is(
    Plugins::TextXslate::API->format( $fields, '<: $directory :>/<: $filename :>' )->{text},
    '/music/Final/08. The Birthday.flac',
    'plain fields render',
);

is(
    Plugins::TextXslate::API->format( $fields, '<: number(7) :>' )->{text},
    '7',
    'a function with one argument renders',
);

is(
    Plugins::TextXslate::API->format( {}, '<: pad("x", 3) :>' )->{text},
    '  x',
    'pad() defaults to right-aligned text',
);

done_testing();
