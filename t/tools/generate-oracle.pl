#!/usr/bin/perl
# Regenerate the behaviour fixtures in t/fixtures from a pristine git HEAD tree.
#
# The rewrite must not change observable behaviour, so the fixtures are
# produced by the *old* implementation and replayed by the test suite against
# the new one.  The function library was renamed and merged, so TXCases
# declares for every new function which HEAD function and argument list
# produces its expected value.
#
#     rm -rf /tmp/tx-head && mkdir -p /tmp/tx-head/t
#     git archive HEAD | tar -x -C /tmp/tx-head
#     cp -a t/lib /tmp/tx-head/t/
#     perl t/tools/generate-oracle.pl --tree=/tmp/tx-head
#
# Options:
#   --tree=PATH   tree to read behaviour from (default: the repository root)
#   --out=PATH    directory to write fixtures to (default: t/fixtures)

use strict;
use warnings;

use FindBin qw($Bin);
use File::Spec;
use File::Spec::Functions qw(catfile);

use lib File::Spec->rel2abs( catfile( $Bin, '..', 'lib' ) );

use TXCases;
use TXFakeTrack;
use TXFixture;

my $tree = File::Spec->rel2abs( catfile( $Bin, '..', '..' ) );
my $out  = File::Spec->rel2abs( catfile( $Bin, '..', 'fixtures' ) );

for my $argument (@ARGV) {
	if ( $argument =~ m{\A--tree=(.+)\z}x ) {
		$tree = File::Spec->rel2abs($1);
	}
	elsif ( $argument =~ m{\A--out=(.+)\z}x ) {
		$out = File::Spec->rel2abs($1);
	}
	else {
		die "generate-oracle.pl: unknown argument '$argument'\n";
	}
}

die "generate-oracle.pl: $tree does not contain an API.pm\n"
	if !-f catfile( $tree, 'API.pm' );

unshift @INC, catfile( $tree, 't', 'lib' );

require Plugins::TextXslate::API;

if ( !Plugins::TextXslate::API->can('_functions') ) {
	die "generate-oracle.pl: $tree is not a HEAD tree (Plugins::TextXslate::API::_functions is missing)\n";
}

if ( !-d $out ) {
	mkdir $out
		or die "generate-oracle.pl: cannot create $out: $!\n";
}

print "oracle tree: $tree\n";
print "fixtures   : $out\n";

# The old implementation warns for out-of-range substr() arguments, for
# uninitialised preferences and for files Audio::Scan does not recognise.
# None of that is part of the behaviour under test.
local $SIG{__WARN__} = sub { };

sub head_table {
	my ($fields) = @_;
	return Plugins::TextXslate::API::_functions($fields);
}

# ---------------------------------------------------------------------------
# fields_for_track()
# ---------------------------------------------------------------------------

my @field_cases;
for my $case ( TXCases::track_cases() ) {
	my $track;
	if ( $case->{kind} eq 'track' ) {
		$track = TXFakeTrack->new( $case->{config} );
	}
	elsif ( $case->{kind} eq 'undef' ) {
		$track = undef;
	}
	elsif ( $case->{kind} eq 'scalar' ) {
		$track = $case->{value};
	}
	else {
		die "generate-oracle.pl: unknown track kind '$case->{kind}'\n";
	}

	my $fields = Plugins::TextXslate::API->fields_for_track($track);

	my %fixture = (
		name   => $case->{name},
		kind   => $case->{kind},
		fields => TXFixture::encode_hash($fields),
	);
	$fixture{config} = TXFakeTrack::encode_config( $case->{config} )
		if $case->{kind} eq 'track';
	$fixture{value} = TXFixture::encode_value( $case->{value} )
		if $case->{kind} eq 'scalar';

	push @field_cases, \%fixture;
}

TXFixture::save_file( catfile( $out, 'fields.json' ), { cases => \@field_cases } );
printf "fields.json      : %d cases\n", scalar @field_cases;

# ---------------------------------------------------------------------------
# Function table
# ---------------------------------------------------------------------------

my @field_sets         = TXCases::function_field_sets();
my @encoded_field_sets = map { TXFixture::encode_hash($_) } @field_sets;
my @tables             = map { head_table($_) } @field_sets;

# Only these read the track fields or the per-render variable state; the rest
# is field independent and is tested once against the rich field set.
my %FIELD_DEPENDENT = map { $_ => 1 } qw(meta has_meta get set);

my @function_cases;
my @arg_sets = TXCases::generic_arg_sets();

for my $name ( TXCases::function_names() ) {
	my $oracle         = TXCases::function_oracle($name);
	my @field_indices  = $FIELD_DEPENDENT{$name} ? ( 0 .. $#tables ) : (1);
	my @candidate_args = ( @arg_sets, @{ TXCases::extra_args($name) } );

	for my $field_index (@field_indices) {
		for my $args (@candidate_args) {
			my ( $old_name, @old_args ) = $oracle->( @{$args} );
			my $old_function = $tables[$field_index]{$old_name}
				or die "generate-oracle.pl: HEAD has no function '$old_name'\n";

			push @function_cases, {
				name   => $name,
				fields => $field_index,
				args   => [ map { TXFixture::encode_value($_) } @{$args} ],
				result => TXFixture::encode_value( $old_function->(@old_args) ),
			};
		}
	}
}

my @sequence_cases;
for my $sequence ( TXCases::function_sequences() ) {
	my $fields = $sequence->{fields} || {};
	my $table  = head_table($fields);

	my @encoded_steps;
	my @results;
	for my $step ( @{ $sequence->{steps} } ) {
		my @arguments = @{$step};
		my $name      = shift @arguments;

		my $oracle = TXCases::function_oracle($name);
		my ( $old_name, @old_args ) = $oracle->(@arguments);

		my $old_function = $table->{$old_name}
			or die "generate-oracle.pl: HEAD has no function '$old_name'\n";

		push @encoded_steps, [ $name, map { TXFixture::encode_value($_) } @arguments ];
		push @results, TXFixture::encode_value( $old_function->(@old_args) );
	}

	push @sequence_cases, {
		name    => $sequence->{name},
		fields  => TXFixture::encode_hash($fields),
		steps   => \@encoded_steps,
		results => \@results,
	};
}

my $random_case = {
	name   => 'random',
	fields => TXFixture::encode_hash( {} ),
	args   => [],
	check  => 'range',
};

TXFixture::save_file(
	catfile( $out, 'functions.json' ),
	{
		field_sets => \@encoded_field_sets,
		cases      => \@function_cases,
		sequences  => \@sequence_cases,
		special    => [$random_case],
	},
);
printf "functions.json   : %d cases, %d sequences\n", scalar @function_cases, scalar @sequence_cases;

# ---------------------------------------------------------------------------
# format() end to end
# ---------------------------------------------------------------------------

# Encode a Perl scalar as a Text::Xslate (Kolon) literal.
sub template_literal {
	my ($value) = @_;

	return '0' if !defined $value;

	if ( !ref $value && $value =~ m{\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?\z}x ) {
		my $number = 0 + $value;
		return "$value" if "$value" eq $number;
	}

	my $text = "$value";
	$text =~ s/([\\"])/\\$1/g;

	return '"' . $text . '"';
}

sub build_template {
	my ( $name, $args ) = @_;

	my @trimmed = @{$args};
	pop @trimmed while @trimmed && !defined $trimmed[-1];

	return '<: ' . $name . '(' . join( ', ', map { template_literal($_) } @trimmed ) . ') :>';
}

my %format_field_index;
my @format_field_sets;
my @general_cases;

for my $case ( TXCases::general_format_cases() ) {
	my $encoded_fields = TXFixture::encode_hash( $case->{fields} );
	my $key            = TXFixture::describe( TXFixture::encode_hash( $case->{fields} ) );

	if ( !exists $format_field_index{$key} ) {
		push @format_field_sets, $encoded_fields;
		$format_field_index{$key} = $#format_field_sets;
	}

	my $result = Plugins::TextXslate::API->format( $case->{fields}, $case->{template} );

	push @general_cases, {
		name     => $case->{name},
		fields   => $format_field_index{$key},
		template => $case->{template},
		text     => TXFixture::encode_value( $result->{text} ),
		error    => ( $result->{error} ne '' ? 1 : 0 ),
	};
}

my $format_fields = TXCases::format_fields();
my $format_key    = TXFixture::describe( TXFixture::encode_hash($format_fields) );

if ( !exists $format_field_index{$format_key} ) {
	push @format_field_sets, TXFixture::encode_hash($format_fields);
	$format_field_index{$format_key} = $#format_field_sets;
}
my $format_field_index = $format_field_index{$format_key};

my %call_args = TXCases::format_call_args();
my @function_cases_format;

for my $name ( sort keys %call_args ) {
	my $new_args = $call_args{$name};
	my $oracle   = TXCases::function_oracle($name);
	my ( $old_name, @old_args ) = $oracle->( @{$new_args} );

	my $old_template = build_template( $old_name, \@old_args );
	my $result       = Plugins::TextXslate::API->format( $format_fields, $old_template );

	die "generate-oracle.pl: $old_template failed: $result->{error}\n"
		if $result->{error} ne '';

	push @function_cases_format, {
		name     => "function-$name",
		fields   => $format_field_index,
		template => build_template( $name, $new_args ),
		text     => TXFixture::encode_value( $result->{text} ),
		error    => 0,
	};
}

TXFixture::save_file(
	catfile( $out, 'format.json' ),
	{
		field_sets     => \@format_field_sets,
		cases          => \@general_cases,
		function_cases => \@function_cases_format,
	},
);
printf "format.json      : %d general cases, %d function cases (%d error cases)\n",
	scalar @general_cases,
	scalar @function_cases_format,
	scalar grep { $_->{error} } @general_cases;

print "done\n";
