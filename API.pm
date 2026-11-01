package Plugins::TextXslate::API;

use strict;
use warnings;

use Encode qw(FB_CROAK);
use File::Basename ();

our $REGISTERED = 0;

sub register {
	my ($class) = @_;
	$REGISTERED = 1;
	return 1;
}

sub available {
	my ($class) = @_;
	return 0 unless $REGISTERED;
	my $ok = eval { require Text::Xslate; 1 };
	return $ok ? 1 : 0;
}

sub format {
	my ($class, $fields, $template) = @_;

	my $ok = eval { require Text::Xslate; 1 };
	return { text => '', error => 'Text::Xslate is not installed' } unless $ok;

	$fields ||= {};
	$template = '' unless defined $template;

	my $out = eval {
		my $tx = Text::Xslate->new(
			syntax => 'Kolon',
			cache  => 0,
			module => [],
		);
		$tx->render_string($template, $fields);
	};

	return { text => $out, error => '' } if defined $out && !$@;
	return { text => '', error => $@ || 'Text::Xslate render failed' };
}

sub format_track {
	my ($class, $track, $template) = @_;
	my $fields = $class->fields_for_track($track);
	return $class->format($fields, $template);
}

sub fields_for_track {
	my ($class, $track) = @_;

	my %fields;
	return \%fields unless $track && ref $track;

	my %methods = (
		title       => 'title',
		artist      => 'artistName',
		album       => 'albumname',
		albumartist => 'albumartistName',
		tracknumber => 'tracknum',
		discnumber  => 'disc',
		year        => 'year',
		genre       => 'genre',
	);

	foreach my $key (keys %methods) {
		my $method = $methods{$key};
		my $value = eval { $track->$method };
		$fields{$key} = "$value" if defined $value && "$value" ne '';
	}

	# Convenience fields used by the default filename templates.
	for my $key (qw(discnumber tracknumber)) {
		next unless defined $fields{$key} && $fields{$key} =~ /^\s*(\d+)/;
		my $number = $1;
		$fields{$key . '_padded'} = $key eq 'discnumber'
			? sprintf('%d', $number)
			: sprintf('%02d', $number);
	}
	for my $method (qw(originalartist origartist)) {
		next unless $track->can($method);
		my $value = eval { $track->$method };
		if ( defined $value && "$value" ne '' ) {
			$fields{origartist} = "$value";
			last;
		}
	}
	if ( !defined $fields{origartist} && $track->can('get_column') ) {
		my $value = eval { $track->get_column('origartist') };
		$fields{origartist} = "$value" if defined $value && "$value" ne '';
	}

	my $url = eval { $track->url } || '';
	$fields{url} = $url if $url ne '';

	if ( $url =~ m{^file://} ) {
		require Slim::Utils::Misc;
		my $path = eval { Slim::Utils::Misc::pathFromFileURL($url) };
		if ( defined $path && !utf8::is_utf8($path) ) {
			my $decoded = eval { Encode::decode('UTF-8', $path, FB_CROAK) };
			$path = $decoded if defined $decoded && !$@;
		}
		if ( defined $path && $path ne '' ) {
			$fields{path} = $path;
			$fields{filename_ext} = File::Basename::basename($path);
			$fields{filename} = $fields{filename_ext};
			$fields{filename} =~ s/\.[^.]*$//;
			$fields{directory} = File::Basename::dirname($path);
		}
	}

	return \%fields;
}

1;
