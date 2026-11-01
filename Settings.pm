package Plugins::TextXslate::Settings;

use strict;
use base qw(Slim::Web::Settings);

use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use Slim::Utils::Prefs;

use Encode qw(FB_CROAK);

sub name {
	return 'Text::Xslate Format';
}

sub page {
	return 'plugins/TextXslate/settings.html';
}

sub prefs {
	return ();
}

sub handler {
	my ($class, $client, $paramRef, $pageSetup) = @_;

	my $file = _custom_file();
	my $source = _read_file($file);
	$source = _read_file(_default_file()) if !defined $source;

	# Keep the textarea and the on-disk file in sync on save.  Do this before
	# SUPER::handler renders the settings page.
	if ( $paramRef->{saveSettings} ) {
		_write_file($file, $paramRef->{functionsSource});
		$source = _read_file($file);
	}
	$paramRef->{functionsSource} = defined $source ? $source : '';

	return $class->SUPER::handler($client, $paramRef, $pageSetup);
}

sub _custom_file {
	my $dir = eval { Slim::Utils::Prefs::dir() } || '';
	return $dir eq '' ? undef : catfile($dir, 'textxslate_functions.pl');
}

sub _default_file {
	return catfile(dirname(__FILE__), 'functions.pl');
}

sub _read_file {
	my $path = shift;
	return unless defined $path && -f $path;
	my $raw = '';
	if ( open(my $fh, '<:raw', $path) ) {
		local $/;
		$raw = <$fh>;
		close $fh;
	}
	else {
		return;
	}
	require Encode;
	my $text = eval { Encode::decode('UTF-8', $raw, FB_CROAK) };
	return defined $text && !$@ ? $text : $raw;
}

sub _write_file {
	my ($path, $content) = @_;
	return unless defined $path && defined $content;
	my $dir = dirname($path);
	return unless -d $dir;
	my $tmp = "$path.tmp.$$";
	return unless open(my $fh, '>:raw', $tmp);
	require Encode;
	print $fh Encode::encode('UTF-8', $content);
	close $fh;
	rename($tmp, $path) or unlink $tmp;
}

1;
