use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Test::More;
use File::Spec;
use TXTest;
use TXFixture;
use TXFakeTrack;

use Plugins::TextXslate::API;

# ---------------------------------------------------------------------------
# fields_for_track() against the oracle generated from git HEAD
# ---------------------------------------------------------------------------

my $fixtures = TXFixture::load_file( TXTest::fixture_file('fields.json') );

for my $case ( @{ $fixtures->{cases} } ) {
    my $track;

    if ( $case->{kind} eq 'track' ) {
        $track = TXFakeTrack->new( TXFakeTrack::decode_config( $case->{config} ) );
    }
    elsif ( $case->{kind} eq 'undef' ) {
        $track = undef;
    }
    elsif ( $case->{kind} eq 'scalar' ) {
        $track = TXFixture::decode_value( $case->{value} );
    }
    else {
        BAIL_OUT("unknown track kind '$case->{kind}'");
    }

    my $fields = Plugins::TextXslate::API->fields_for_track($track);

    ok(
        TXFixture::matches_encoded_hash( $fields, $case->{fields} ),
        "fields_for_track: $case->{name}",
    ) or diag 'got: ' . TXFixture::describe( TXFixture::encode_hash($fields) );
}

# ---------------------------------------------------------------------------
# Public API surface
# ---------------------------------------------------------------------------

ok( !Plugins::TextXslate::API->available, 'not available before register()' );
is( Plugins::TextXslate::API->register, 1, 'register() returns 1' );
ok( Plugins::TextXslate::API->available, 'available after register() with Text::Xslate installed' );
is( Plugins::TextXslate::API->register, 1, 'register() is idempotent' );

my $track = TXFakeTrack->new(
    {
        name    => 'consistency',
        methods => {
            title      => 'The Birthday',
            artistName => 'VINCENT SAID',
        },
    },
);

my $template = '<: $artist :> - <: $title :>';
my $fields   = Plugins::TextXslate::API->fields_for_track($track);
my $direct   = Plugins::TextXslate::API->format( $fields, $template );
my $tracked  = Plugins::TextXslate::API->format_track( $track, $template );

is( $tracked->{text},  $direct->{text}, 'format_track() uses fields_for_track()' );
is( $tracked->{error}, '',              'format_track() renders without error' );
is( $direct->{text},   'VINCENT SAID - The Birthday', 'fields reach the template' );

# ---------------------------------------------------------------------------
# Error handling and defensive behaviour
# ---------------------------------------------------------------------------

my $broken = Plugins::TextXslate::API->format( {}, '<: :' );
is( $broken->{text}, '', 'a template that cannot compile returns no text' );
ok( $broken->{error} ne '', 'a template that cannot compile reports an error' );

my @odd_fields = ( [], 'not a hash', 42 );
for my $odd (@odd_fields) {
    my $result = eval { Plugins::TextXslate::API->format( $odd, 'plain' ) };
    my $error  = $@;
    is( $error, '', "format() survives non-hashref fields (" . ref($odd) . ')' );
    ok( ref $result eq 'HASH', 'format() still returns a result hash' );
}

# ---------------------------------------------------------------------------
# Tag scanning of a readable, non-audio file must be harmless
# ---------------------------------------------------------------------------

my $scratch = TXTest::temp_dir('textxslate-tags');
my $audio_path = "$scratch/not-really-audio.flac";
open my $audio_handle, '>:raw', $audio_path
    or die "cannot write $audio_path: $!";
print {$audio_handle} 'not audio data';
close $audio_handle
    or die "cannot close $audio_path: $!";

my $file_track = TXFakeTrack->new(
    {
        name    => 'readable-path',
        methods => {
            title => 'Tag Scan',
            path  => $audio_path,
        },
    },
);

my $file_fields;
{
    # Audio::Scan writes its "not a valid ..." complaint straight to STDERR and
    # that is expected here, so silence the whole descriptor for the call.
    my $saved_stderr = _mute_stderr();
    $file_fields = eval { Plugins::TextXslate::API->fields_for_track($file_track) };
    _restore_stderr($saved_stderr);
}
is( $@, '', 'scanning a readable file does not die' );
ok( ref $file_fields eq 'HASH', 'scanning a readable file still returns fields' );
is( $file_fields->{filename_ext}, 'not-really-audio.flac', 'file name is derived from the path' );
is( $file_fields->{directory}, $scratch, 'directory is derived from the path' );

# A second call hits the tag cache and returns the same fields.
my $again;
{
    my $saved_stderr = _mute_stderr();
    $again = Plugins::TextXslate::API->fields_for_track($file_track);
    _restore_stderr($saved_stderr);
}
is_deeply( $again, $file_fields, 'tag cache is consistent' );

sub _mute_stderr {
    open my $saved, '>&', \*STDERR
        or die "cannot duplicate STDERR: $!";
    open STDERR, '>', File::Spec->devnull
        or die "cannot redirect STDERR: $!";

    return $saved;
}

sub _restore_stderr {
    my ($saved) = @_;
    open STDERR, '>&', $saved
        or die "cannot restore STDERR: $!";

    return;
}

done_testing();
