package TXCases;

use strict;
use warnings;

use utf8;

# Behaviour cases that the oracle fixtures are generated from.
#
# The generator (t/tools/generate-oracle.pl) runs these against a pristine
# git HEAD tree, whose function table still uses the old "tx_*" names, and
# stores the results in t/fixtures/*.json.  The tests replay the fixtures
# against the current implementation.
#
# The function library was renamed and several pairs were merged, so every new
# function declares which HEAD function (and which argument translation)
# produces its expected value.

my $UTF8_TEXT = "\x{00e9}t\x{00e9} \x{4e2d}\x{6587}";

sub utf8_text { return $UTF8_TEXT }

# ---------------------------------------------------------------------------
# New function name -> HEAD function name (identical argument lists)
# ---------------------------------------------------------------------------

my %SAME_ARGUMENTS = (
	number              => 'tx_num',
	hexadecimal         => 'tx_hex',
	roman               => 'tx_roman',
	character           => 'tx_char',
	prefix              => 'tx_left',
	suffix              => 'tx_right',
	substring           => 'tx_substr',
	insert              => 'tx_insert',
	position            => 'tx_strchr',
	last_position       => 'tx_strrchr',
	len                 => 'tx_len',
	lower               => 'tx_lower',
	upper               => 'tx_upper',
	trim                => 'tx_trim',
	replace             => 'tx_replace',
	repeat              => 'tx_repeat',
	abbreviate          => 'tx_abbr',
	first_line          => 'tx_fix_eol',
	choose              => 'tx_select',
	if_greater          => 'tx_ifgreater',
	if_longer           => 'tx_iflonger',
	greater             => 'tx_greater',
	longer              => 'tx_longer',
	compare             => 'tx_strcmp',
	compare_ignore_case => 'tx_stricmp',
	longest             => 'tx_longest',
	shortest            => 'tx_shortest',
	sum                 => 'tx_add',
	subtract            => 'tx_sub',
	multiply            => 'tx_mul',
	divide              => 'tx_div',
	modulo              => 'tx_mod',
	multiply_divide     => 'tx_muldiv',
	min                 => 'tx_min',
	max                 => 'tx_max',
	negate              => 'tx_not',
	all                 => 'tx_and',
	any                 => 'tx_or',
	exactly_one         => 'tx_xor',
	meta                => 'tx_meta',
	has_meta            => 'tx_meta_test',
	get                 => 'tx_get',
	directory           => 'tx_directory',
	filename            => 'tx_filename',
	ext                 => 'tx_ext',
	crlf                => 'tx_crlf',
	tab                 => 'tx_tab',
	identity            => 'tx_ansi',
	color               => 'tx_set_color',
	progress            => 'tx_progress',
);

# Merged functions: translate the new argument list into the HEAD call.
my %ADAPTERS = (
	pad => sub {
		my ( $value, $width, $char, $align ) = @_;
		my $old = _is_left($align) ? 'tx_pad_right' : 'tx_pad';
		return ( $old, $value, $width, $char );
	},
	pad_cut => sub {
		my ( $value, $width, $char, $align ) = @_;
		my $old = _is_left($align) ? 'tx_padcut_right' : 'tx_padcut';
		return ( $old, $value, $width, $char );
	},
	title_case => sub {
		my ( $value, $keep_existing ) = @_;
		return ( $keep_existing ? 'tx_caps2' : 'tx_caps', $value );
	},
	set => sub {
		my ( $name, $value, $quiet ) = @_;
		return ( $quiet ? 'tx_puts' : 'tx_put', $name, $value );
	},
	first_value => sub {
		return ( 'tx_if2', @_ );
	},
);

sub _is_left {
	my ($align) = @_;
	return defined $align && $align eq 'left' ? 1 : 0;
}

# Return a coderef mapping new function arguments to the HEAD call:
# ($old_name, @old_args).
sub function_oracle {
	my ($name) = @_;

	return $ADAPTERS{$name} if $ADAPTERS{$name};

	if ( $SAME_ARGUMENTS{$name} ) {
		my $old = $SAME_ARGUMENTS{$name};
		return sub { return ( $old, @_ ); };
	}

	die "TXCases: no oracle for function '$name'\n";
}

# Every function the user-editable table must expose (random is special).
sub function_names {
	return sort( keys %SAME_ARGUMENTS, keys %ADAPTERS );
}

# ---------------------------------------------------------------------------
# Track scenarios for fields_for_track()
# ---------------------------------------------------------------------------

sub track_cases {
	return (
		{
			name => 'accessor-only',
			kind => 'track',
			config => {
				name    => 'accessor-only',
				methods => {
					title           => 'The Birthday',
					artistName      => 'VINCENT SAID',
					albumartistName => 'VINCENT SAID',
					albumname       => 'NOMAD',
					tracknum        => '08',
					disc            => 1,
					year            => 2007,
					genre           => 'Rock',
					comment         => undef,
					compilation     => 0,
					originalartist  => 'ORIGINAL FACE',
					origartist      => 'OTHER',
					url             => 'file:///music/Final/The%20Birthday/08.flac',
					path            => '/music/Final/The Birthday/08. The Birthday.flac',
				},
			},
		},
		{
			name => 'database-columns',
			kind => 'track',
			config => {
				name    => 'database-columns',
				methods => {
					title      => 'Column Title',
					artistName => 'Column Artist',
				},
				columns       => [qw(id title bitrate bpm musicbrainz_id work virtual)],
				column_values => {
					title          => 'Title From Column',
					bitrate        => 320,
					bpm            => 0,
					musicbrainz_id => 'abc-123',
					work           => undef,
					virtual        => 1,
				},
			},
		},
		{
			name => 'url-only',
			kind => 'track',
			config => {
				name    => 'url-only',
				methods => {
					title => 'URL Only',
					url   => 'file:///music/Some%20Artist/Some%20Track.flac',
				},
			},
		},
		{
			name => 'filename-derivation',
			kind => 'track',
			config => {
				name    => 'filename-derivation',
				methods => {
					title => 'Name Parts',
					path  => '/music/Album/01 - Track.Two.flac',
				},
			},
		},
		{
			name => 'no-track',
			kind => 'undef',
		},
		{
			name  => 'not-a-reference',
			kind  => 'scalar',
			value => 'not a track',
		},
	);
}

# ---------------------------------------------------------------------------
# Function-level cases
# ---------------------------------------------------------------------------

sub function_field_sets {
	return (
		{},
		{
			title       => 'The Birthday',
			artist      => 'VINCENT SAID',
			album       => 'NOMAD',
			tracknumber => '08',
			discnumber  => 1,
			year        => 2007,
			genre       => 'Rock',
			path        => '/music/Final/08. The Birthday.flac',
			filename    => '08. The Birthday',
			directory   => '/music/Final',
			compilation => 0,
		},
		{
			_private    => 'hidden',
			'Upper Key' => 'value',
			mood        => [ 'calm', 'happy' ],
			empty       => '',
			zero        => 0,
			utf8        => $UTF8_TEXT,
		},
	);
}

sub generic_arg_sets {
	return (
		[],
		[undef],
		[''],
		[0],
		[1],
		[-5],
		[42],
		['08'],
		['abc'],
		['The birthday'],
		[$UTF8_TEXT],
		[ [ 1, 2, 3 ] ],
		[ [ undef, 'a' ] ],
		[ 'abc', 2 ],
		[ 'abc', 5, '.' ],
		[ 'abc', 0 ],
		[ 'abc', -2 ],
		[ 5, 3 ],
		[ 255, 4 ],
		[ 'x', 'y', 'a', 'b' ],
		[ 1, 2, 3 ],
		[ 'one', 'two', 'three' ],
		[ 100, 50, 20, '#', '.' ],
		[ 'a,b,c', ',', ';' ],
	);
}

sub extra_args {
	my ($name) = @_;

	my %extra = (
		number      => [ [7], [ 7, 3 ], [ 7, 0 ], [ -3, 4 ] ],
		pad         => [ [ 'abc', 6 ], [ 'abc', 6, '.' ], [ 'abc', 2 ], [ '', 3 ], [ 'abc', 6, '.', 'left' ], [ 'abc', 6, '.', 'right' ] ],
		pad_cut     => [ [ 'abc', 6 ], [ 'abcdefgh', 4 ], [ 'abc', 6, '.', 'left' ], [ 'abcdefgh', 4, '.', 'left' ] ],
		hexadecimal => [ [255], [ 255, 8 ], [0] ],
		roman       => [ [4], [9], [40], [0], [3999] ],
		abbreviate  => [ [ 'hello world', 40 ], [ 'hello world', 5 ] ],
		directory   => [ [ '/a/b/c.flac', 1 ], [ '/a/b/c.flac', 2 ], [ '/a/b/c.flac', 3 ], [ '/a/b/c.flac', 0 ] ],
		ext         => [ ['/x/y.tar.gz'], ['/x/y'], ['x'], [''], ['/a/b.c/d'] ],
		progress    => [ [ 0, 100, 10 ], [ 50, 100, 10 ], [ -5, 100, 10 ], [ 200, 100, 10 ], [ 50, 100, 10, '#', '.' ], [ 50, 100, 0 ] ],
		first_line  => [ ["line1\nline2"], [ 'line1', ' [more]' ], [ '', '...' ] ],
		choose      => [ [ 0, 'zero', 'one' ], [ 2, 'zero', 'one' ], [ 1, 'only' ], [ 'x', 'a', 'b' ] ],
		min         => [ [ 5, 3, 9 ], [ '10', '9' ] ],
		max         => [ [ 5, 3, 9 ], [ '10', '9' ] ],
		character   => [ [65], [ 0x4e2d ], [ 0x1F600 ] ],
		crlf        => [ [''], ['x'] ],
		title_case  => [ ['hELLO wORLD'], [ 'hELLO wORLD', 1 ], [ 'hello world', 0 ] ],
		set         => [ [ 'k', 'v' ], [ 'k', 'v', 1 ], [ '', 'v' ] ],
		first_value => [ [ '', 'a' ], [ '', 'b', 'c' ], [ 'x', 'y' ] ],
	);

	return $extra{$name} ? $extra{$name} : [];
}

sub function_sequences {
	return (
		{
			name   => 'set-get',
			fields => {},
			steps  => [
				[ 'set', 'x', 'hello' ],
				[ 'get', 'x' ],
				[ 'get', 'missing' ],
				[ 'set', 'X', 'second' ],
				[ 'get', 'x' ],
			],
		},
		{
			name   => 'set-quiet-get',
			fields => {},
			steps  => [
				[ 'set', 'y', 'value', 1 ],
				[ 'get', 'y' ],
				[ 'set', 'empty', '', 1 ],
				[ 'get', 'empty' ],
			],
		},
		{
			name   => 'set-utf8',
			fields => {},
			steps  => [
				[ 'set', 'n', $UTF8_TEXT ],
				[ 'get', 'n' ],
			],
		},
		{
			name   => 'get-before-set',
			fields => {},
			steps  => [
				[ 'get', 'nope' ],
				[ 'set', 'nope', 'now' ],
				[ 'get', 'nope' ],
			],
		},
	);
}

# ---------------------------------------------------------------------------
# End-to-end (template) cases
# ---------------------------------------------------------------------------

sub format_fields {
	return {
		title       => 'The Birthday',
		artist      => 'VINCENT SAID',
		album       => 'NOMAD',
		tracknumber => '08',
		discnumber  => 1,
		year        => 2007,
		genre       => 'Rock',
		path        => '/music/Final/The Birthday/08. The Birthday.flac',
		filename    => '08. The Birthday',
		directory   => '/music/Final/The Birthday',
		url         => 'file:///music/Final/The%20Birthday/08.%20The%20Birthday.flac',
		compilation => 0,
	};
}

# Scalar argument lists used to build "<: function(...) :>" template cases.
sub format_call_args {
	return (
		number              => [ 7, 3 ],
		pad                 => [ 'abc', 6, '.' ],
		pad_cut             => [ 'abcdefgh', 4 ],
		hexadecimal         => [ 255, 4 ],
		roman               => [1994],
		character           => [65],
		prefix              => [ 'abcdef', 3 ],
		suffix              => [ 'abcdef', 3 ],
		substring           => [ 'abcdef', 1, 4 ],
		insert              => [ 'abcdef', 'XY', 2 ],
		position            => [ 'abcdef', 'cd' ],
		last_position       => [ 'abab', 'ab' ],
		len                 => ['hello'],
		lower               => ['HeLLo'],
		upper               => ['HeLLo'],
		title_case          => [ 'hello world' ],
		trim                => [ '  padded  ' ],
		replace             => [ 'a-b-c', '-', '+' ],
		repeat              => [ 'ab', 3 ],
		abbreviate          => [ 'hello world', 40 ],
		first_line          => ['single line'],
		choose              => [ 1, 'one', 'two' ],
		first_value         => [ '', 'fallback' ],
		if_greater          => [ 5, 3, 'yes', 'no' ],
		if_longer           => [ 'abcdef', 3, 'yes', 'no' ],
		greater             => [ 5, 3 ],
		longer              => [ 'abc', 'ab' ],
		compare             => [ 'a', 'b' ],
		compare_ignore_case => [ 'A', 'b' ],
		longest             => [ 'a', 'bbb', 'cc' ],
		shortest            => [ 'a', 'bbb', 'cc' ],
		sum                 => [ 1, 2, 3 ],
		subtract            => [ 5, 3 ],
		multiply            => [ 2, 3, 4 ],
		divide              => [ 7, 2 ],
		modulo              => [ 7, 2 ],
		multiply_divide     => [ 5, 4, 2 ],
		min                 => [ 5, 3, 9 ],
		max                 => [ 5, 3, 9 ],
		negate              => [0],
		all                 => [ 1, 1 ],
		any                 => [ 0, 0 ],
		exactly_one         => [ 1, 0 ],
		meta                => ['title'],
		has_meta            => ['title'],
		set                 => [ 'key', 'value', 1 ],
		get                 => ['key'],
		directory           => [ '/a/b/c.flac', 1 ],
		filename            => ['/a/b/c.flac'],
		ext                 => ['/a/b/c.flac'],
		crlf                => [''],
		tab                 => [2],
		identity            => ['text'],
		color               => ['red'],
		progress            => [ 50, 100, 10 ],
	);
}

# Template cases that do not call the custom function table; they must behave
# the same before and after the rewrite.
sub general_format_cases {
	return (
		{
			name     => 'field-interpolation',
			fields   => format_fields(),
			template => '<: $directory :>/<: $artist :> - <: $title :>',
		},
		{
			name     => 'missing-fields',
			fields   => { title => 'Only Title' },
			template => '<: $title :>|<: $artist :>|<: $year :>',
		},
		{
			name     => 'empty-fields',
			fields   => {},
			template => 'literal text only',
		},
		{
			name     => 'condition-true',
			fields   => format_fields(),
			template => '<: if $artist { :>has artist<: } else { :>no artist<: } :>',
		},
		{
			name     => 'condition-false',
			fields   => { title => 'T' },
			template => '<: if $artist { :>has artist<: } else { :>no artist<: } :>',
		},
		{
			name     => 'foreach-loop',
			fields   => format_fields(),
			template => '<: for ["a","b","c"] -> $item { :>[<: $item :>]<: } :>',
		},
		{
			name     => 'utf8-output',
			fields   => { title => "\x{00e9}t\x{00e9} \x{4e2d}\x{6587}", artist => 'Art' },
			template => '<: $artist :> - <: $title :>',
		},
		{
			name     => 'escaped-output',
			fields   => { title => '<b>&amp;</b>' },
			template => '<: $title :>',
		},
		{
			name     => 'error-unknown-function',
			fields   => {},
			template => '<: no_such_function() :>',
		},
		{
			name     => 'error-syntax',
			fields   => {},
			template => '<: :',
		},
		{
			name     => 'empty-template',
			fields   => {},
			template => '',
		},
	);
}

1;
