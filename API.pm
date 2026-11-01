package Plugins::TextXslate::API;

use strict;
use warnings;

use Encode qw(FB_CROAK);
use File::Basename ();
use File::Spec::Functions qw(catfile);

our $REGISTERED = 0;
our $CURRENT_FIELDS;

my %TAG_CACHE;

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
			syntax   => 'Kolon',
			cache    => 0,
			module   => [],
			function => _functions($fields),
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

	# LMS's well-known accessors.  These also work for the RemoteTrack
	# emulation, which does not expose the database result source.
	my %methods = (
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

	foreach my $key (sort keys %methods) {
		my $method = $methods{$key};
		next unless $track->can($method);
		my $value = eval { $track->$method };
		_set_field(\%fields, $key, $value);
	}

	for my $method (qw(originalartist origartist)) {
		next unless $track->can($method);
		my $value = eval { $track->$method };
		_set_field(\%fields, 'origartist', $value);
	}

	for my $method (qw(url path)) {
		next unless $track->can($method);
		my $value = eval { $track->$method };
		_set_field(\%fields, $method, $value);
	}
	if ( (!defined $fields{path} || $fields{path} eq '') && defined $fields{url} && $fields{url} =~ m{^file://} ) {
		require Slim::Utils::Misc;
		my $path = eval { Slim::Utils::Misc::pathFromFileURL($fields{url}) };
		_set_field(\%fields, 'path', $path) if defined $path;
	}

	# Every database column is metadata too (bitrate, bpm, musicbrainz_id,
	# virtual, work, performance, ...).  This keeps custom fields available
	# without maintaining a second hard-coded list.
	my @columns = eval {
		$track->result_source ? $track->result_source->columns : ();
	};
	$@ = '';
	for my $column (@columns) {
		next if $column eq 'id';
		my $value = eval { $track->get_column($column) };
		_set_field(\%fields, $column, $value) if defined $value;
	}

	# Tags not represented in the database schema (ORIGARTIST, Mood, TXXX
	# style custom tags, ...) are read from the source file.
	my $path = $fields{path};
	if ( defined $path && $path ne '' && -r $path ) {
		my %tags = _scan_tags($path);
		foreach my $key (keys %tags) {
			my $name = lc $key;
			$name =~ s/[^a-z0-9_]+/_/g;
			$name =~ s/^_+|_+$//g;
			next if $name eq '';
			_set_field(\%fields, $name, $tags{$key});
		}
	}

	# Common aliases for the two number columns.
	$fields{discnumber} = $fields{disc} if (!defined $fields{discnumber} || $fields{discnumber} eq '') && defined $fields{disc};
	$fields{tracknumber} = $fields{tracknum} if (!defined $fields{tracknumber} || $fields{tracknumber} eq '') && defined $fields{tracknum};

	# File/path convenience fields, matching foobar2000's tech-info names.
	if ( defined $fields{path} && $fields{path} ne '' ) {
		$fields{filename_ext} = File::Basename::basename($fields{path});
		$fields{filename} = $fields{filename_ext};
		$fields{filename} =~ s/\.[^.]*$//;
		$fields{directory} = File::Basename::dirname($fields{path});
	}

	return \%fields;
}

sub _set_field {
	my ($fields, $name, $value) = @_;
	return unless defined $name && $name ne '' && defined $value;
	if ( ref $value eq 'ARRAY' ) {
		$value = join(', ', map { defined $_ ? "$_" : '' } @$value);
	}
	return if ref $value || $value eq '';
	$name = lc $name;
	$fields->{$name} = "$value"
		if !exists $fields->{$name} || $fields->{$name} eq '';
}

sub _scan_tags {
	my $path = shift;
	return unless defined $path && $path ne '';

	my $mtime = (stat($path))[9] || 0;
	my $key = "$path\0$mtime";
	return %{ $TAG_CACHE{$key} } if $TAG_CACHE{$key};

	my $scan = eval {
		require Audio::Scan;
		Audio::Scan->scan_tags($path);
	};
	my $tags = $scan && ref $scan eq 'HASH' && ref $scan->{tags} eq 'HASH'
		? $scan->{tags}
		: {};

	# Do not let artwork/binary blobs leak into formatting.
	my %out;
	foreach my $tag (keys %$tags) {
		my $value = $tags->{$tag};
		if ( ref $value eq 'ARRAY' ) {
			$value = join(', ', map { defined $_ && !ref $_ ? "$_" : '' } @$value);
		}
		next if ref $value;
		$out{$tag} = $value if defined $value && $value ne '';
	}
	$TAG_CACHE{$key} = \%out;
	return %out;
}

sub _string {
	my $value = shift;
	return '' unless defined $value;
	return $value if !ref $value;
	if ( ref $value eq 'ARRAY' ) {
		return join(', ', map { _string($_) } @$value);
	}
	return "$value";
}

sub _number {
	my $value = shift;
	return 0 unless defined $value && "$value" =~ /^\s*-?\d+/;
	return int($value);
}

sub _numeric_arg {
	my $value = shift;
	return 0 unless defined $value && "$value" =~ /^\s*(-?\d+)/;
	return int($1);
}

sub _truthy {
	my $value = shift;
	return 0 unless defined $value;
	return 0 if !ref $value && "$value" eq '';
	return 0 if !ref $value && "$value" =~ /^\s*0+\s*$/;
	return 1;
}

sub _functions_file {
	my $custom = eval { require Slim::Utils::Prefs; Slim::Utils::Prefs::dir() . '/textxslate_functions.pl' };
	return $custom if defined $custom && $custom ne '' && -f $custom;
	return catfile(File::Basename::dirname(__FILE__), 'functions.pl');
}

sub _functions {
	my $fields = shift;
	my $file = _functions_file();
	if ( $file && -f $file ) {
		local $CURRENT_FIELDS = $fields;
		my $table = eval { do $file };
		return $table if ref $table eq 'HASH';
	}
	return _builtin_functions($fields);
}

sub _builtin_functions {
	my $fields = shift || {};
	my %fields = %$fields;

	my %vars;
	my $meta = sub {
		my $name = lc(_string(shift));
		$name =~ s/^_//;
		$name =~ s/[^a-z0-9_]+/_/g;
		return _string($fields{$name});
	};

	return {
		tx_num       => sub { my ($v,$w)=@_; $w=_number($w)||1; return sprintf('%0*d', $w, _number($v)); },
		tx_pad       => sub { my ($v,$w,$c)=@_; $w=_number($w); $c=defined $c && $c ne '' ? _string($c) : ' '; my $s=_string($v); return length($s)>=$w ? $s : ($c x ($w-length($s))).$s; },
		tx_pad_right => sub { my ($v,$w,$c)=@_; $w=_number($w); $c=defined $c && $c ne '' ? _string($c) : ' '; my $s=_string($v); return length($s)>=$w ? $s : $s.($c x ($w-length($s))); },
		tx_padcut    => sub { my ($v,$w,$c)=@_; $w=_number($w); $c=defined $c && $c ne '' ? _string($c) : ' '; my $s=_string($v); $s=($c x ($w-length($s))).$s if length($s)<$w; return substr($s,0,$w); },
		tx_padcut_right => sub { my ($v,$w,$c)=@_; $w=_number($w); $c=defined $c && $c ne '' ? _string($c) : ' '; my $s=_string($v); $s=$s.($c x ($w-length($s))) if length($s)<$w; return substr($s,0,$w); },
		tx_left      => sub { my ($v,$n)=@_; return substr(_string($v),0,_number($n)); },
		tx_right     => sub { my ($v,$n)=@_; my $s=_string($v); $n=_number($n); return $n>=length($s) ? $s : substr($s,-$n); },
		tx_cut       => sub { my ($v,$n)=@_; return substr(_string($v),0,_number($n)); },
		tx_substr    => sub { my ($v,$start,$end)=@_; my $s=_string($v); $start=_number($start); $end=_number($end); return substr($s,$start,$end-$start); },
		tx_len       => sub { return length(_string(shift)); },
		tx_len2      => sub { return length(_string(shift)); },
		tx_lower     => sub { return lc(_string(shift)); },
		tx_upper     => sub { return uc(_string(shift)); },
		tx_caps      => sub { my $s=lc(_string(shift)); $s =~ s/\b([a-z])/\u$1/g; return $s; },
		tx_caps2     => sub { my $s=_string(shift); $s =~ s/\b([a-z])/\u$1/g; return $s; },
		tx_trim      => sub { my $s=_string(shift); $s =~ s/^\s+|\s+$//g; return $s; },
		tx_replace   => sub { my ($v,@args)=@_; my $s=_string($v); while (@args>=2) { my $from=shift @args; my $to=shift @args; next if !defined $from || $from eq ''; $s =~ s/\Q$from\E/$to/g; } return $s; },
		tx_repeat    => sub { my ($v,$n)=@_; return _string($v) x _number($n); },
		tx_select    => sub { my ($n,@args)=@_; $n=_number($n); return defined $args[$n] ? _string($args[$n]) : ''; },
		tx_if2       => sub { for my $v (@_) { return _string($v) if _truthy($v); } return ''; },
		tx_if3       => sub { for my $v (@_) { return _string($v) if _truthy($v); } return ''; },
		tx_ifgreater => sub { my ($a,$b,$x,$y)=@_; return _number($a)>_number($b) ? _string($x) : _string($y); },
		tx_iflonger  => sub { my ($a,$b,$x,$y)=@_; return length(_string($a))>_number($b) ? _string($x) : _string($y); },
		tx_greater   => sub { my ($a,$b)=@_; return _number($a)>_number($b) ? 1 : 0; },
		tx_longer    => sub { my ($a,$b)=@_; return length(_string($a))>length(_string($b)) ? 1 : 0; },
		tx_strcmp    => sub { my ($a,$b)=@_; return _string($a) cmp _string($b); },
		tx_stricmp   => sub { my ($a,$b)=@_; return lc(_string($a)) cmp lc(_string($b)); },
		tx_add       => sub { my $n=0; $n += _number($_) for @_; return $n; },
		tx_sub       => sub { my ($a,$b)=@_; return _number($a)-_number($b); },
		tx_mul       => sub { my $n=1; $n *= _number($_) for @_; return $n; },
		tx_div       => sub { my ($a,$b)=@_; $b=_number($b); return $b ? int(_number($a)/$b) : 0; },
		tx_mod       => sub { my ($a,$b)=@_; $b=_number($b); return $b ? _number($a)%$b : 0; },
		tx_muldiv    => sub { my ($a,$b,$c)=@_; $c=_number($c); return $c ? int(_number($a)*_number($b)/$c) : 0; },
		tx_min       => sub { my $n=_number(shift); $n=_number($_)<$n?_number($_):$n for @_; return $n; },
		tx_max       => sub { my $n=_number(shift); $n=_number($_)>$n?_number($_):$n for @_; return $n; },
		tx_not       => sub { return _truthy(shift) ? 0 : 1; },
		tx_and       => sub { for (@_) { return 0 unless _truthy($_) } return 1; },
		tx_or        => sub { for (@_) { return 1 if _truthy($_) } return 0; },
		tx_xor       => sub { my ($a,$b)=@_; return (_truthy($a) xor _truthy($b)) ? 1 : 0; },
		tx_hex       => sub { my ($v,$w)=@_; return defined $w ? sprintf('%0*x',$w,_number($v)) : sprintf('%x',_number($v)); },
		tx_roman     => sub { my $n=_number(shift); return '' if $n<=0; my @v=(1000,900,500,400,100,90,50,40,10,9,5,4,1); my @r=qw(M CM D CD C XC L XL X IX V IV I); my $o=''; for my $i (0..$#v) { while ($n >= $v[$i]) { $o.=$r[$i]; $n-=$v[$i]; } } return $o; },
		tx_char      => sub { return chr(_number(shift)); },
		tx_crlf      => sub { return "\n"; },
		tx_tab       => sub { my $n=_number(shift); $n=1 if $n<1; return "\t" x $n; },
		tx_directory => sub { my ($v,$n)=@_; my $p=_string($v); my $d=File::Basename::dirname($p); if (_number($n)>1) { for (2.._number($n)) { $d=File::Basename::dirname($d); } } return $d; },
		tx_filename  => sub { return File::Basename::basename(_string(shift)); },
		tx_ext       => sub { my $s=_string(shift); return $s =~ /\.([^.\/]+)$/ ? $1 : ''; },
		tx_meta      => $meta,
		tx_meta_test => sub { return length($meta->(shift)) ? 1 : 0; },
		tx_extra     => $meta,
		tx_strchr    => sub { my ($s,$c)=@_; my $i=index(_string($s),_string($c)); return $i<0?0:$i; },
		tx_strrchr   => sub { my ($s,$c)=@_; my $i=rindex(_string($s),_string($c)); return $i<0?0:$i; },
		tx_strstr    => sub { my ($s,$c)=@_; my $i=index(_string($s),_string($c)); return $i<0?0:$i; },
		tx_insert    => sub { my ($s,$v,$n)=@_; my $p=_string($s); $n=_number($n); return substr($p,0,$n)._string($v).substr($p,$n); },
		tx_abbr      => sub { my ($v,$n)=@_; my $s=_string($v); return $s if defined $n && length($s)<=_number($n); my @w=grep { length } split /\s+/, $s; return join('', map { uc(substr($_,0,1)) } @w) || $s; },
		tx_fix_eol   => sub { my ($v,$suffix)=@_; my $s=_string($v); $suffix=' (...)' unless defined $suffix; $s =~ s/[\r\n].*//s; return $s.$suffix; },
		tx_longest   => sub { my $best=''; for (@_) { my $s=_string($_); $best=$s if length($s)>length($best) } return $best; },
		tx_shortest  => sub { my $best; for (@_) { my $s=_string($_); $best=$s if !defined $best || length($s)<length($best) } return defined $best?$best:''; },
		tx_put       => sub { my ($name,$value)=@_; $vars{lc(_string($name))}=_string($value); return _string($value); },
		tx_puts      => sub { my ($name,$value)=@_; $vars{lc(_string($name))}=_string($value); return ''; },
		tx_get       => sub { return _string($vars{lc(_string(shift))}); },
		tx_ansi      => sub { return _string(shift); },
		tx_set_color => sub { return ''; },
		tx_rgb       => sub { return ''; },
		tx_blend     => sub { return _string(shift); },
		transition=> sub { return _string(shift); },
		tx_progress  => sub { my ($pos,$range,$width,$fill,$empty)=@_; $width=_number($width)||10; $range=_number($range); $range=1 if $range<1; my $n=int(_number($pos)*$width/$range); $n=0 if $n<0; $n=$width if $n>$width; $fill=defined $fill?$fill:'#'; $empty=defined $empty?$empty:'-'; return ($fill x $n).($empty x ($width-$n)); },
		tx_progress2 => sub { my ($pos,$range,$width,$fill,$empty)=@_; $width=_number($width)||10; $range=_number($range); $range=1 if $range<1; my $n=int(_number($pos)*$width/$range); $n=0 if $n<0; $n=$width if $n>$width; $fill=defined $fill?$fill:'='; $empty=defined $empty?$empty:'-'; return ($fill x $n).($empty x ($width-$n)); },
		tx_rand      => sub { return int(rand(4294967296)); },
	};
}

1;
