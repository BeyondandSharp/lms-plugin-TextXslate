package Plugins::TextXslate::API;

use strict;
use warnings;

use English qw(-no_match_vars);
use File::Basename ();
use File::Spec;
use File::Spec::Functions qw(catfile);

# Set by register(); the plugin is inert until LMS loads it.
our $REGISTERED = 0;

# Tag scanner results, keyed by "path\0mtime".
my %TAG_CACHE;

# LMS accessors for the fields templates are expected to provide.  These also
# work for the RemoteTrack emulation, which exposes no database result source.
my %ACCESSOR_METHOD = (
	title       => 'title',
	artist      => 'artistName',
	albumartist => 'albumartistName',
	album       => 'albumname',
	tracknumber => 'tracknum',
	discnumber  => 'disc',
	year        => 'year',
	genre       => 'genre',
	comment     => 'comment',
	compilation => 'compilation',
);

sub register {
	my ($class) = @_;

	$REGISTERED = 1;
	return 1;
}

sub available {
	my ($class) = @_;

	return 0 if !$REGISTERED;

	my $loaded = eval { require Text::Xslate; 1 };
	return $loaded ? 1 : 0;
}

# Public API: MusicArtistInfo calls ->format($fields, $template), so the name is
# part of the published plugin interface even though "format" is a Perl built-in.
## no critic (Subroutines::ProhibitBuiltinHomonyms)
sub format {
	my ( $class, $fields, $template ) = @_;

	my $loaded = eval { require Text::Xslate; 1 };
	if ( !$loaded ) {
		return { text => '', error => 'Text::Xslate is not installed' };
	}

	$fields   = {} if ref $fields ne 'HASH';
	$template = '' if !defined $template;

	my $table = $class->_function_table($fields);

	# Text::Xslate 3.5.9 on Perl 5.40 crashes while a template compilation
	# error unwinds when the Text::Xslate object was built in a frame deeper
	# than the eval that catches the error, so construction, render and eval
	# stay together in this frame.
	my $output;
	{
		local $EVAL_ERROR = '';
		my $rendered = eval {
			my $xslate = Text::Xslate->new(
				syntax   => 'Kolon',
				cache    => 0,
				module   => [],
				function => $table,
			);
			$output = $xslate->render_string( $template, $fields );
			1;
		};
		if ( !$rendered ) {
			return {
				text  => '',
				error => $EVAL_ERROR || 'Text::Xslate render failed',
			};
		}
	}

	return { text => $output, error => '' } if defined $output;
	return { text => '', error => 'Text::Xslate render failed' };
}

sub format_track {
	my ( $class, $track, $template ) = @_;

	my $fields = $class->fields_for_track($track);
	return $class->format( $fields, $template );
}

sub fields_for_track {
	my ( $class, $track ) = @_;

	my %fields;
	return \%fields if !$track || !ref $track;

	$class->_add_accessor_fields( \%fields, $track );
	$class->_add_location_fields( \%fields, $track );
	$class->_add_column_fields( \%fields, $track );
	$class->_add_tag_fields( \%fields );
	_apply_number_aliases( \%fields );
	_apply_file_fields( \%fields );

	return \%fields;
}

sub _add_accessor_fields {
	my ( $class, $fields, $track ) = @_;

	for my $field ( sort keys %ACCESSOR_METHOD ) {
		my $method = $ACCESSOR_METHOD{$field};
		next if !$track->can($method);
		_set_field( $fields, $field, _call_accessor( $track, $method ) );
	}

	# Both spellings are found in the wild; the first one that has a value wins.
	for my $method (qw(originalartist origartist)) {
		next if !$track->can($method);
		_set_field( $fields, 'origartist', _call_accessor( $track, $method ) );
	}

	return;
}

sub _call_accessor {
	my ( $track, $method ) = @_;

	my $value = eval { $track->$method };
	return $value;
}

sub _add_location_fields {
	my ( $class, $fields, $track ) = @_;

	for my $method (qw(url path)) {
		next if !$track->can($method);
		_set_field( $fields, $method, _call_accessor( $track, $method ) );
	}

	my $url = $fields->{url};
	return if !_is_blank( $fields->{path} );
	return if !defined $url;
	return if $url !~ m{\Afile://}x;

	_set_field( $fields, 'path', $class->_path_from_url($url) );
	return;
}

sub _path_from_url {
	my ( $class, $url ) = @_;

	my $loaded = eval { require Slim::Utils::Misc; 1 };
	return if !$loaded;

	my $path = eval { Slim::Utils::Misc::pathFromFileURL($url) };
	return $path;
}

sub _add_column_fields {
	my ( $class, $fields, $track ) = @_;

	for my $column ( $class->_column_names($track) ) {
		next if $column eq 'id';
		my $value = eval { $track->get_column($column) };
		_set_field( $fields, $column, $value ) if defined $value;
	}

	return;
}

sub _column_names {
	my ( $class, $track ) = @_;

	my $source = eval { $track->result_source };
	return () if !$source;

	my @columns = eval { $source->columns };
	return @columns;
}

sub _add_tag_fields {
	my ( $class, $fields ) = @_;

	my $path = $fields->{path};
	return if _is_blank($path);
	return if !-r $path;

	my %tags = $class->_scan_tags($path);
	for my $tag ( keys %tags ) {
		my $name = lc $tag;
		$name =~ s/[^a-z0-9_]+/_/gx;
		$name =~ s/\A_+|_+\z//gx;
		next if $name eq '';
		_set_field( $fields, $name, $tags{$tag} );
	}

	return;
}

sub _scan_tags {
	my ( $class, $path ) = @_;

	my $mtime = ( stat $path )[9];
	$mtime = 0 if !defined $mtime;

	my $cache_key = $path . "\0" . $mtime;
	return %{ $TAG_CACHE{$cache_key} } if $TAG_CACHE{$cache_key};

	my $scanned = eval { _scan_file_tags($path) };
	my $tags    = ref $scanned eq 'HASH' ? $scanned : {};

	my %found;
	for my $tag ( keys %{$tags} ) {
		my $value = _flatten( $tags->{$tag} );
		next if !defined $value || ref $value || $value eq '';
		$found{$tag} = $value;
	}

	$TAG_CACHE{$cache_key} = \%found;
	return %found;
}

sub _scan_file_tags {
	my ($path) = @_;

	require Audio::Scan;
	my $scanned = Audio::Scan->scan_tags($path);
	return {} if ref $scanned ne 'HASH';
	return {} if ref $scanned->{tags} ne 'HASH';

	return $scanned->{tags};
}

sub _set_field {
	my ( $fields, $name, $value ) = @_;

	return if !defined $name || $name eq '' || !defined $value;

	$value = _flatten($value);
	return if ref $value || $value eq '';

	my $key = lc $name;
	return if exists $fields->{$key} && $fields->{$key} ne '';

	$fields->{$key} = "$value";
	return;
}

sub _flatten {
	my ($value) = @_;

	if ( ref $value eq 'ARRAY' ) {
		return join ', ', map { defined $_ && !ref $_ ? $_ : '' } @{$value};
	}

	return $value;
}

sub _is_blank {
	my ($value) = @_;

	return 1 if !defined $value || $value eq '';
	return 0;
}

sub _apply_number_aliases {
	my ($fields) = @_;

	if ( _is_blank( $fields->{discnumber} ) && defined $fields->{disc} ) {
		$fields->{discnumber} = $fields->{disc};
	}
	if ( _is_blank( $fields->{tracknumber} ) && defined $fields->{tracknum} ) {
		$fields->{tracknumber} = $fields->{tracknum};
	}

	return;
}

sub _apply_file_fields {
	my ($fields) = @_;

	return if _is_blank( $fields->{path} );

	my $filename_ext = File::Basename::basename( $fields->{path} );
	my $filename     = $filename_ext;
	$filename =~ s/\.[^.]*\z//x;

	$fields->{filename_ext} = $filename_ext;
	$fields->{filename}     = $filename;
	$fields->{directory}    = File::Basename::dirname( $fields->{path} );

	return;
}

# Build the template function table for one render.  The user-editable file
# defines Plugins::TextXslate::Functions::build(); it is loaded once with
# require(), so the table is rebuilt cheaply for every render while the code is
# compiled only once per LMS process.
sub _function_table {
	my ( $class, $fields ) = @_;

	for my $file ( $class->_table_files() ) {
		my $table = $class->_load_table_file( $file, $fields );
		return $table if defined $table;
	}

	return {};
}

sub _table_files {
	my ($class) = @_;

	my @files;
	for my $file ( $class->_custom_table_file(), $class->_default_table_file() ) {
		next if !defined $file || !-f $file;
		push @files, $file;
	}

	return @files;
}

sub _custom_table_file {
	my ($class) = @_;

	my $dir = $class->_prefs_dir();
	return if !defined $dir || $dir eq '';

	return File::Spec->rel2abs( catfile( $dir, 'textxslate_functions.pl' ) );
}

sub _default_table_file {
	my ($class) = @_;

	my $plugin_dir = File::Basename::dirname(__FILE__);
	return File::Spec->rel2abs( catfile( $plugin_dir, 'functions.pl' ) );
}

sub _prefs_dir {
	my ($class) = @_;

	my $loaded = eval { require Slim::Utils::Prefs; 1 };
	return if !$loaded;

	my $dir = eval { Slim::Utils::Prefs::dir() };
	return $dir;
}

sub _load_table_file {
	my ( $class, $file, $fields ) = @_;

	my $loaded = eval { require $file; 1 };
	return if !$loaded;

	my $build = Plugins::TextXslate::Functions->can('build');
	return if !$build;

	return Plugins::TextXslate::Functions->build($fields);
}

1;
