package Plugins::TextXslate::Settings;

use strict;
use warnings;

use English qw(-no_match_vars);

use base qw(Slim::Web::Settings);

use Encode qw(FB_CROAK);
use File::Basename qw(dirname);
use File::Spec;
use File::Spec::Functions qw(catfile);
use Slim::Utils::Prefs;

sub name {
	return 'PLUGIN_TEXTXSLATE_SETTINGS';
}

sub page {
	return 'plugins/TextXslate/settings.html';
}

sub prefs {
	return ();
}

sub handler {
	my ( $class, $client, $paramRef, $pageSetup ) = @_;

	$paramRef->{perlEditorAvailable} = eval {
		require Plugins::PerlEditor::API;
		Plugins::PerlEditor::API->available;
	} ? 1 : 0;
	$paramRef->{perlEditorScript} = eval {
		require Plugins::PerlEditor::API;
		Plugins::PerlEditor::API->editor_js;
	} || 'plugins/PerlEditor/editor.js';

	my $custom_file  = _custom_file();
	my $default_file = _default_file();
	my $source       = _read_file($custom_file);

	$source = _read_file($default_file) if !defined $source;

	# Keep the textarea and the on-disk file in sync on save.  Do this before
	# SUPER::handler renders the settings page.
	if ( $paramRef->{saveSettings} ) {
		_write_file( $custom_file, $paramRef->{functionsSource} );
		$source = _read_file($custom_file);
	}

	$paramRef->{functionsSource} = defined $source ? $source : '';

	return $class->SUPER::handler( $client, $paramRef, $pageSetup );
}

sub _custom_file {
	my $dir = eval { Slim::Utils::Prefs::dir() } || '';

	return if $dir eq '';

	return File::Spec->rel2abs(
		catfile( $dir, 'textxslate_functions.pl' ) );
}

sub _default_file {
	my $path = catfile( dirname(__FILE__), 'functions.pl' );

	return File::Spec->rel2abs($path);
}

sub _read_file {
	my ($target) = @_;

	return if !defined $target;

	my $path = File::Spec->rel2abs($target);

	return if !-f $path;

	my $opened = open( my $fh, '<:raw', $path );

	return if !$opened;

	local $INPUT_RECORD_SEPARATOR = undef;

	my $raw    = <$fh>;
	my $closed = close $fh;

	return if !$closed || !defined $raw;

	my $decoded = eval { Encode::decode( 'UTF-8', $raw, FB_CROAK ) };

	return defined $decoded ? $decoded : $raw;
}

sub _write_file {
	my ( $target, $content ) = @_;

	return if !defined $target || !defined $content;

	my $path = File::Spec->rel2abs($target);
	my $dir  = dirname($path);

	return if !-d $dir;

	my $tmp    = "$path.tmp.$PROCESS_ID";
	my $opened = open( my $fh, '>:raw', $tmp );

	return if !$opened;

	my $bytes   = Encode::encode( 'UTF-8', $content );
	my $printed = print {$fh} $bytes;
	my $closed  = close $fh;

	if ( !$printed || !$closed ) {
		unlink $tmp;
		return;
	}

	if ( !rename( $tmp, $path ) ) {
		unlink $tmp;
		return;
	}

	return;
}

1;
