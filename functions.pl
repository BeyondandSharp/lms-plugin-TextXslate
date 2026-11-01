# Text::Xslate template functions for the TextXslate plugin.
#
# This single file is the complete template-function library.  It is the file
# you edit from the plugin's settings page in the LMS web UI, so it is kept as
# plain and readable as possible.
#
# Contract with the plugin:
#   * build($fields) returns the table of template functions for one render.
#   * $fields is the hash of track fields templates see as <: $title :>.
#   * every function listed in build() receives the evaluated template
#     arguments and returns a string or a number.
#   * state written by set() is visible to get() during the same render only.
#
# To add a function: write the sub, then list it in build().
# To remove one: delete both places.
#
# The file is loaded once with require(), so edits take effect after
# restarting LMS.
#
## no critic (Modules::RequireFilenameMatchesPackage)
package Plugins::TextXslate::Functions;

use strict;
use warnings;

use File::Basename ();

# ---------------------------------------------------------------------------
# Argument helpers
# ---------------------------------------------------------------------------

# Turn any template value into a string: undef and unusable references become
# "", arrays are joined with ", ".
sub _text {
	my ($value) = @_;

	return '' if !defined $value;
	return $value if !ref $value;

	if ( ref $value eq 'ARRAY' ) {
		return join ', ', map { _text($_) } @{$value};
	}

	return "$value";
}

# Turn any template value into an integer, or 0 when it has no leading digits.
sub _integer {
	my ($value) = @_;

	return 0 if !defined $value || "$value" !~ m{ ^ \s* -? \d+ }x;

	return int $value;
}

# Perl truthiness plus the template layer's rules: undef, "" and strings made
# only of zeroes are false.
sub _truthy {
	my ($value) = @_;

	return 0 if !defined $value;
	return 0 if !ref $value && "$value" eq '';
	return 0 if !ref $value && "$value" =~ m{ ^ \s* 0+ \s* $ }x;

	return 1;
}

# Look up a foobar2000-style field name in the current track fields.
sub _meta {
	my ( $fields, $name ) = @_;

	my $key = lc _text($name);
	$key =~ s{ ^ _ }{}x;
	$key =~ s{ [^a-z0-9_]+ }{_}gx;

	return _text( $fields->{$key} );
}

# Pad or truncate to a width; $align is where the text itself goes.
sub _pad {
	my ( $value, $width, $char, $align ) = @_;

	$width = _integer($width);
	$char  = defined $char && $char ne '' ? _text($char) : ' ';

	my $text    = _text($value);
	my $missing = $width - length $text;

	return $text if $missing <= 0;

	my $padding = $char x $missing;

	return defined $align && $align eq 'left'
		? $text . $padding
		: $padding . $text;
}

# ---------------------------------------------------------------------------
# Numbers and padding
# ---------------------------------------------------------------------------

sub number {
	my ( $value, $width ) = @_;

	$width = _integer($width) || 1;

	return sprintf '%0*d', $width, _integer($value);
}

# pad($value, $width, $char, $align)
#   $align is 'right' (default) to right-align the text, 'left' for the other
#   side.  The pad character defaults to a space.
sub pad {
	my ( $value, $width, $char, $align ) = @_;

	return _pad( $value, $width, $char, $align );
}

# Like pad() but the result is truncated to exactly $width characters.
sub pad_cut {
	my ( $value, $width, $char, $align ) = @_;

	my $padded = _pad( $value, $width, $char, $align );

	return substr $padded, 0, _integer($width);
}

sub hexadecimal {
	my ( $value, $width ) = @_;

	return defined $width
		? sprintf '%0*x', $width, _integer($value)
		: sprintf '%x', _integer($value);
}

sub roman {
	my ($value) = @_;

	my $number = _integer($value);
	return '' if $number <= 0;

	my @values = ( 1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1 );
	my @digits = qw( M CM D CD C XC L XL X IX V IV I );

	my $result = '';
	for my $index ( 0 .. $#values ) {
		while ( $number >= $values[$index] ) {
			$result .= $digits[$index];
			$number -= $values[$index];
		}
	}

	return $result;
}

sub character {
	my ($value) = @_;

	return chr _integer($value);
}

# ---------------------------------------------------------------------------
# Slicing
# ---------------------------------------------------------------------------

# The first $length characters.
sub prefix {
	my ( $value, $length ) = @_;

	return substr _text($value), 0, _integer($length);
}

# The last $length characters.
sub suffix {
	my ( $value, $length ) = @_;

	my $text = _text($value);
	$length = _integer($length);

	return $length >= length $text ? $text : substr $text, -$length;
}

sub substring {
	my ( $value, $start, $end ) = @_;

	my $text = _text($value);
	$start = _integer($start);
	$end   = _integer($end);

	return substr $text, $start, $end - $start;
}

sub insert {
	my ( $value, $inserted, $offset ) = @_;

	my $text = _text($value);
	$offset = _integer($offset);

	return substr( $text, 0, $offset ) . _text($inserted) . substr( $text, $offset );
}

sub position {
	my ( $value, $needle ) = @_;

	my $position = index _text($value), _text($needle);

	return $position < 0 ? 0 : $position;
}

sub last_position {
	my ( $value, $needle ) = @_;

	my $position = rindex _text($value), _text($needle);

	return $position < 0 ? 0 : $position;
}

# ---------------------------------------------------------------------------
# Case and whitespace
# ---------------------------------------------------------------------------

sub len {
	my ($value) = @_;

	return length _text($value);
}

sub lower {
	my ($value) = @_;

	return lc _text($value);
}

sub upper {
	my ($value) = @_;

	return uc _text($value);
}

# Capitalise the first letter of every word.  A truthy second argument keeps
# the rest of the text as it is; otherwise it is lowercased first.
sub title_case {
	my ( $value, $keep_existing ) = @_;

	my $text = _text($value);
	$text = lc $text if !_truthy($keep_existing);
	$text =~ s/ \b ([a-z]) /\u$1/gx;

	return $text;
}

sub trim {
	my ($value) = @_;

	my $text = _text($value);
	$text =~ s{ ^ \s+ | \s+ $ }{}gx;

	return $text;
}

sub replace {
	my ( $value, @pairs ) = @_;

	my $text = _text($value);
	while ( @pairs >= 2 ) {
		my $from = shift @pairs;
		my $to   = shift @pairs;
		next if !defined $from || $from eq '';
		$text =~ s{ \Q$from\E }{$to}gx;
	}

	return $text;
}

sub repeat {
	my ( $value, $count ) = @_;

	return _text($value) x _integer($count);
}

sub abbreviate {
	my ( $value, $width ) = @_;

	my $text = _text($value);
	return $text if defined $width && length $text <= _integer($width);

	my @initials;
	for my $word ( split m{ \s+ }x, $text ) {
		push @initials, uc substr $word, 0, 1 if length $word;
	}

	my $abbreviation = join '', @initials;

	return $abbreviation || $text;
}

sub first_line {
	my ( $value, $suffix ) = @_;

	my $text = _text($value);
	$suffix = ' (...)' if !defined $suffix;
	$text =~ s{ [\r\n] .* }{}sx;

	return $text . $suffix;
}

# ---------------------------------------------------------------------------
# Selection and comparison
# ---------------------------------------------------------------------------

sub choose {
	my ( $index, @values ) = @_;

	$index = _integer($index);

	return defined $values[$index] ? _text( $values[$index] ) : '';
}

# The first argument that is true; handy for optional fields.
sub first_value {
	my (@values) = @_;

	for my $value (@values) {
		return _text($value) if _truthy($value);
	}

	return '';
}

sub if_greater {
	my ( $lhs, $rhs, $when_greater, $when_not ) = @_;

	return _integer($lhs) > _integer($rhs)
		? _text($when_greater)
		: _text($when_not);
}

sub if_longer {
	my ( $value, $length, $when_longer, $when_not ) = @_;

	return length _text($value) > _integer($length)
		? _text($when_longer)
		: _text($when_not);
}

sub greater {
	my ( $lhs, $rhs ) = @_;

	return _integer($lhs) > _integer($rhs) ? 1 : 0;
}

sub longer {
	my ( $lhs, $rhs ) = @_;

	return length _text($lhs) > length _text($rhs) ? 1 : 0;
}

sub compare {
	my ( $lhs, $rhs ) = @_;

	return _text($lhs) cmp _text($rhs);
}

sub compare_ignore_case {
	my ( $lhs, $rhs ) = @_;

	return lc _text($lhs) cmp lc _text($rhs);
}

sub longest {
	my (@values) = @_;

	my $longest = '';
	for my $value (@values) {
		my $text = _text($value);
		$longest = $text if length $text > length $longest;
	}

	return $longest;
}

sub shortest {
	my (@values) = @_;

	my $shortest;
	for my $value (@values) {
		my $text = _text($value);
		$shortest = $text if !defined $shortest || length $text < length $shortest;
	}

	return defined $shortest ? $shortest : '';
}

# ---------------------------------------------------------------------------
# Arithmetic
# ---------------------------------------------------------------------------

sub sum {
	my (@values) = @_;

	my $total = 0;
	$total += _integer($_) for @values;

	return $total;
}

sub subtract {
	my ( $lhs, $rhs ) = @_;

	return _integer($lhs) - _integer($rhs);
}

sub multiply {
	my (@values) = @_;

	my $total = 1;
	$total *= _integer($_) for @values;

	return $total;
}

sub divide {
	my ( $lhs, $rhs ) = @_;

	$rhs = _integer($rhs);

	return $rhs ? int( _integer($lhs) / $rhs ) : 0;
}

sub modulo {
	my ( $lhs, $rhs ) = @_;

	$rhs = _integer($rhs);

	return $rhs ? _integer($lhs) % $rhs : 0;
}

sub multiply_divide {
	my ( $lhs, $rhs, $divisor ) = @_;

	$divisor = _integer($divisor);

	return $divisor ? int( _integer($lhs) * _integer($rhs) / $divisor ) : 0;
}

sub min {
	my (@values) = @_;

	my $minimum = _integer( shift @values );
	for my $value (@values) {
		my $number = _integer($value);
		$minimum = $number if $number < $minimum;
	}

	return $minimum;
}

sub max {
	my (@values) = @_;

	my $maximum = _integer( shift @values );
	for my $value (@values) {
		my $number = _integer($value);
		$maximum = $number if $number > $maximum;
	}

	return $maximum;
}

# ---------------------------------------------------------------------------
# Logic
# ---------------------------------------------------------------------------

sub negate {
	my ($value) = @_;

	return _truthy($value) ? 0 : 1;
}

sub all {
	my (@values) = @_;

	for my $value (@values) {
		return 0 if !_truthy($value);
	}

	return 1;
}

sub any {
	my (@values) = @_;

	for my $value (@values) {
		return 1 if _truthy($value);
	}

	return 0;
}

sub exactly_one {
	my ( $lhs, $rhs ) = @_;

	return ( _truthy($lhs) xor _truthy($rhs) ) ? 1 : 0;
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

sub directory {
	my ( $path, $levels ) = @_;

	my $result  = File::Basename::dirname( _text($path) );
	my $upwards = _integer($levels) - 1;

	while ( $upwards > 0 ) {
		$result = File::Basename::dirname($result);
		$upwards--;
	}

	return $result;
}

sub filename {
	my ($path) = @_;

	return File::Basename::basename( _text($path) );
}

sub ext {
	my ($path) = @_;

	my ($extension) = _text($path) =~ m{ \. ([^./]+) $ }x;

	return defined $extension ? $extension : '';
}

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

sub crlf {

	return "\n";
}

sub tab {
	my ($count) = @_;

	$count = _integer($count);
	$count = 1 if $count < 1;

	return "\t" x $count;
}

# Placeholder for visual functions that have no meaning in a text file.
sub identity {
	my ($value) = @_;

	return _text($value);
}

sub color {

	return '';
}

sub progress {
	my ( $position, $range, $width, $fill, $empty ) = @_;

	$width = _integer($width) || 10;
	$range = _integer($range);
	$range = 1 if $range < 1;

	my $filled = int( _integer($position) * $width / $range );
	$filled = 0 if $filled < 0;
	$filled = $width if $filled > $width;

	$fill  = defined $fill  ? $fill  : '#';
	$empty = defined $empty ? $empty : '-';

	return ( $fill x $filled ) . ( $empty x ( $width - $filled ) );
}

sub random {

	return int( rand(4294967296) );
}

# ---------------------------------------------------------------------------
# Functions that need the track fields or per-render state
# ---------------------------------------------------------------------------

sub _stateful {
	my ( $fields, $vars ) = @_;

	return {
		meta => sub {
			return _meta( $fields, shift );
		},
		has_meta => sub {
			return length _meta( $fields, shift ) ? 1 : 0;
		},
		set => sub {
			my ( $name, $value, $quiet ) = @_;
			$vars->{ lc _text($name) } = _text($value);
			return _truthy($quiet) ? '' : _text($value);
		},
		get => sub {
			return _text( $vars->{ lc _text(shift) } );
		},
	};
}

# ---------------------------------------------------------------------------
# The function table exposed to templates
# ---------------------------------------------------------------------------

sub build {
	my ( $class, $fields ) = @_;

	$fields ||= {};
	my %vars;

	return {
		# Numbers and padding
		number      => \&number,
		pad         => \&pad,
		pad_cut     => \&pad_cut,
		hexadecimal => \&hexadecimal,
		roman       => \&roman,
		character   => \&character,

		# Slicing
		prefix        => \&prefix,
		suffix        => \&suffix,
		substring     => \&substring,
		insert        => \&insert,
		position      => \&position,
		last_position => \&last_position,

		# Strings
		len        => \&len,
		lower      => \&lower,
		upper      => \&upper,
		title_case => \&title_case,
		trim       => \&trim,
		replace    => \&replace,
		repeat     => \&repeat,
		abbreviate => \&abbreviate,
		first_line => \&first_line,

		# Selection and comparison
		choose              => \&choose,
		first_value         => \&first_value,
		if_greater          => \&if_greater,
		if_longer           => \&if_longer,
		greater             => \&greater,
		longer              => \&longer,
		compare             => \&compare,
		compare_ignore_case => \&compare_ignore_case,
		longest             => \&longest,
		shortest            => \&shortest,

		# Arithmetic
		sum             => \&sum,
		subtract        => \&subtract,
		multiply        => \&multiply,
		divide          => \&divide,
		modulo          => \&modulo,
		multiply_divide => \&multiply_divide,
		min             => \&min,
		max             => \&max,

		# Logic
		negate      => \&negate,
		all         => \&all,
		any         => \&any,
		exactly_one => \&exactly_one,

		# Paths
		directory => \&directory,
		filename  => \&filename,
		ext       => \&ext,

		# Output helpers
		crlf     => \&crlf,
		tab      => \&tab,
		identity => \&identity,
		color    => \&color,
		progress => \&progress,
		random   => \&random,

		# Fields and per-render state
		%{ _stateful( $fields, \%vars ) },
	};
}

1;
