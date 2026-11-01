# TextXslate function table.
#
# This file is editable from the TextXslate plugin settings page.  The code
# below is evaluated once per formatting call.  $_[0] is not used; the fields
# hash is provided by the plugin in
# $Plugins::TextXslate::API::CURRENT_FIELDS.
#
# Add or replace entries in the returned hash.  Every function receives the
# evaluated template arguments and returns a string/number.
package Plugins::TextXslate::Functions;

use strict;
use warnings;

my $fields = $Plugins::TextXslate::API::CURRENT_FIELDS || {};
my %fields = %$fields;
my %vars;
my $meta = sub {
	my $name = lc(Plugins::TextXslate::API::_string(shift));
	$name =~ s/^_//;
	$name =~ s/[^a-z0-9_]+/_/g;
	return Plugins::TextXslate::API::_string($fields{$name});
};

	return {
		tx_num       => sub { my ($v,$w)=@_; $w=Plugins::TextXslate::API::_number($w)||1; return sprintf('%0*d', $w, Plugins::TextXslate::API::_number($v)); },
		tx_pad       => sub { my ($v,$w,$c)=@_; $w=Plugins::TextXslate::API::_number($w); $c=defined $c && $c ne '' ? Plugins::TextXslate::API::_string($c) : ' '; my $s=Plugins::TextXslate::API::_string($v); return length($s)>=$w ? $s : ($c x ($w-length($s))).$s; },
		tx_pad_right => sub { my ($v,$w,$c)=@_; $w=Plugins::TextXslate::API::_number($w); $c=defined $c && $c ne '' ? Plugins::TextXslate::API::_string($c) : ' '; my $s=Plugins::TextXslate::API::_string($v); return length($s)>=$w ? $s : $s.($c x ($w-length($s))); },
		tx_padcut    => sub { my ($v,$w,$c)=@_; $w=Plugins::TextXslate::API::_number($w); $c=defined $c && $c ne '' ? Plugins::TextXslate::API::_string($c) : ' '; my $s=Plugins::TextXslate::API::_string($v); $s=($c x ($w-length($s))).$s if length($s)<$w; return substr($s,0,$w); },
		tx_padcut_right => sub { my ($v,$w,$c)=@_; $w=Plugins::TextXslate::API::_number($w); $c=defined $c && $c ne '' ? Plugins::TextXslate::API::_string($c) : ' '; my $s=Plugins::TextXslate::API::_string($v); $s=$s.($c x ($w-length($s))) if length($s)<$w; return substr($s,0,$w); },
		tx_left      => sub { my ($v,$n)=@_; return substr(Plugins::TextXslate::API::_string($v),0,Plugins::TextXslate::API::_number($n)); },
		tx_right     => sub { my ($v,$n)=@_; my $s=Plugins::TextXslate::API::_string($v); $n=Plugins::TextXslate::API::_number($n); return $n>=length($s) ? $s : substr($s,-$n); },
		tx_cut       => sub { my ($v,$n)=@_; return substr(Plugins::TextXslate::API::_string($v),0,Plugins::TextXslate::API::_number($n)); },
		tx_substr    => sub { my ($v,$start,$end)=@_; my $s=Plugins::TextXslate::API::_string($v); $start=Plugins::TextXslate::API::_number($start); $end=Plugins::TextXslate::API::_number($end); return substr($s,$start,$end-$start); },
		tx_len       => sub { return length(Plugins::TextXslate::API::_string(shift)); },
		tx_len2      => sub { return length(Plugins::TextXslate::API::_string(shift)); },
		tx_lower     => sub { return lc(Plugins::TextXslate::API::_string(shift)); },
		tx_upper     => sub { return uc(Plugins::TextXslate::API::_string(shift)); },
		tx_caps      => sub { my $s=lc(Plugins::TextXslate::API::_string(shift)); $s =~ s/\b([a-z])/\u$1/g; return $s; },
		tx_caps2     => sub { my $s=Plugins::TextXslate::API::_string(shift); $s =~ s/\b([a-z])/\u$1/g; return $s; },
		tx_trim      => sub { my $s=Plugins::TextXslate::API::_string(shift); $s =~ s/^\s+|\s+$//g; return $s; },
		tx_replace   => sub { my ($v,@args)=@_; my $s=Plugins::TextXslate::API::_string($v); while (@args>=2) { my $from=shift @args; my $to=shift @args; next if !defined $from || $from eq ''; $s =~ s/\Q$from\E/$to/g; } return $s; },
		tx_repeat    => sub { my ($v,$n)=@_; return Plugins::TextXslate::API::_string($v) x Plugins::TextXslate::API::_number($n); },
		tx_select    => sub { my ($n,@args)=@_; $n=Plugins::TextXslate::API::_number($n); return defined $args[$n] ? Plugins::TextXslate::API::_string($args[$n]) : ''; },
		tx_if2       => sub { for my $v (@_) { return Plugins::TextXslate::API::_string($v) if Plugins::TextXslate::API::_truthy($v); } return ''; },
		tx_if3       => sub { for my $v (@_) { return Plugins::TextXslate::API::_string($v) if Plugins::TextXslate::API::_truthy($v); } return ''; },
		tx_ifgreater => sub { my ($a,$b,$x,$y)=@_; return Plugins::TextXslate::API::_number($a)>Plugins::TextXslate::API::_number($b) ? Plugins::TextXslate::API::_string($x) : Plugins::TextXslate::API::_string($y); },
		tx_iflonger  => sub { my ($a,$b,$x,$y)=@_; return length(Plugins::TextXslate::API::_string($a))>Plugins::TextXslate::API::_number($b) ? Plugins::TextXslate::API::_string($x) : Plugins::TextXslate::API::_string($y); },
		tx_greater   => sub { my ($a,$b)=@_; return Plugins::TextXslate::API::_number($a)>Plugins::TextXslate::API::_number($b) ? 1 : 0; },
		tx_longer    => sub { my ($a,$b)=@_; return length(Plugins::TextXslate::API::_string($a))>length(Plugins::TextXslate::API::_string($b)) ? 1 : 0; },
		tx_strcmp    => sub { my ($a,$b)=@_; return Plugins::TextXslate::API::_string($a) cmp Plugins::TextXslate::API::_string($b); },
		tx_stricmp   => sub { my ($a,$b)=@_; return lc(Plugins::TextXslate::API::_string($a)) cmp lc(Plugins::TextXslate::API::_string($b)); },
		tx_add       => sub { my $n=0; $n += Plugins::TextXslate::API::_number($_) for @_; return $n; },
		tx_sub       => sub { my ($a,$b)=@_; return Plugins::TextXslate::API::_number($a)-Plugins::TextXslate::API::_number($b); },
		tx_mul       => sub { my $n=1; $n *= Plugins::TextXslate::API::_number($_) for @_; return $n; },
		tx_div       => sub { my ($a,$b)=@_; $b=Plugins::TextXslate::API::_number($b); return $b ? int(Plugins::TextXslate::API::_number($a)/$b) : 0; },
		tx_mod       => sub { my ($a,$b)=@_; $b=Plugins::TextXslate::API::_number($b); return $b ? Plugins::TextXslate::API::_number($a)%$b : 0; },
		tx_muldiv    => sub { my ($a,$b,$c)=@_; $c=Plugins::TextXslate::API::_number($c); return $c ? int(Plugins::TextXslate::API::_number($a)*Plugins::TextXslate::API::_number($b)/$c) : 0; },
		tx_min       => sub { my $n=Plugins::TextXslate::API::_number(shift); $n=Plugins::TextXslate::API::_number($_)<$n?Plugins::TextXslate::API::_number($_):$n for @_; return $n; },
		tx_max       => sub { my $n=Plugins::TextXslate::API::_number(shift); $n=Plugins::TextXslate::API::_number($_)>$n?Plugins::TextXslate::API::_number($_):$n for @_; return $n; },
		tx_not       => sub { return Plugins::TextXslate::API::_truthy(shift) ? 0 : 1; },
		tx_and       => sub { for (@_) { return 0 unless Plugins::TextXslate::API::_truthy($_) } return 1; },
		tx_or        => sub { for (@_) { return 1 if Plugins::TextXslate::API::_truthy($_) } return 0; },
		tx_xor       => sub { my ($a,$b)=@_; return (Plugins::TextXslate::API::_truthy($a) xor Plugins::TextXslate::API::_truthy($b)) ? 1 : 0; },
		tx_hex       => sub { my ($v,$w)=@_; return defined $w ? sprintf('%0*x',$w,Plugins::TextXslate::API::_number($v)) : sprintf('%x',Plugins::TextXslate::API::_number($v)); },
		tx_roman     => sub { my $n=Plugins::TextXslate::API::_number(shift); return '' if $n<=0; my @v=(1000,900,500,400,100,90,50,40,10,9,5,4,1); my @r=qw(M CM D CD C XC L XL X IX V IV I); my $o=''; for my $i (0..$#v) { while ($n >= $v[$i]) { $o.=$r[$i]; $n-=$v[$i]; } } return $o; },
		tx_char      => sub { return chr(Plugins::TextXslate::API::_number(shift)); },
		tx_crlf      => sub { return "\n"; },
		tx_tab       => sub { my $n=Plugins::TextXslate::API::_number(shift); $n=1 if $n<1; return "\t" x $n; },
		tx_directory => sub { my ($v,$n)=@_; my $p=Plugins::TextXslate::API::_string($v); my $d=File::Basename::dirname($p); if (Plugins::TextXslate::API::_number($n)>1) { for (2..Plugins::TextXslate::API::_number($n)) { $d=File::Basename::dirname($d); } } return $d; },
		tx_filename  => sub { return File::Basename::basename(Plugins::TextXslate::API::_string(shift)); },
		tx_ext       => sub { my $s=Plugins::TextXslate::API::_string(shift); return $s =~ /\.([^.\/]+)$/ ? $1 : ''; },
		tx_meta      => $meta,
		tx_meta_test => sub { return length($meta->(shift)) ? 1 : 0; },
		tx_extra     => $meta,
		tx_strchr    => sub { my ($s,$c)=@_; my $i=index(Plugins::TextXslate::API::_string($s),Plugins::TextXslate::API::_string($c)); return $i<0?0:$i; },
		tx_strrchr   => sub { my ($s,$c)=@_; my $i=rindex(Plugins::TextXslate::API::_string($s),Plugins::TextXslate::API::_string($c)); return $i<0?0:$i; },
		tx_strstr    => sub { my ($s,$c)=@_; my $i=index(Plugins::TextXslate::API::_string($s),Plugins::TextXslate::API::_string($c)); return $i<0?0:$i; },
		tx_insert    => sub { my ($s,$v,$n)=@_; my $p=Plugins::TextXslate::API::_string($s); $n=Plugins::TextXslate::API::_number($n); return substr($p,0,$n).Plugins::TextXslate::API::_string($v).substr($p,$n); },
		tx_abbr      => sub { my ($v,$n)=@_; my $s=Plugins::TextXslate::API::_string($v); return $s if defined $n && length($s)<=Plugins::TextXslate::API::_number($n); my @w=grep { length } split /\s+/, $s; return join('', map { uc(substr($_,0,1)) } @w) || $s; },
		tx_fix_eol   => sub { my ($v,$suffix)=@_; my $s=Plugins::TextXslate::API::_string($v); $suffix=' (...)' unless defined $suffix; $s =~ s/[\r\n].*//s; return $s.$suffix; },
		tx_longest   => sub { my $best=''; for (@_) { my $s=Plugins::TextXslate::API::_string($_); $best=$s if length($s)>length($best) } return $best; },
		tx_shortest  => sub { my $best; for (@_) { my $s=Plugins::TextXslate::API::_string($_); $best=$s if !defined $best || length($s)<length($best) } return defined $best?$best:''; },
		tx_put       => sub { my ($name,$value)=@_; $vars{lc(Plugins::TextXslate::API::_string($name))}=Plugins::TextXslate::API::_string($value); return Plugins::TextXslate::API::_string($value); },
		tx_puts      => sub { my ($name,$value)=@_; $vars{lc(Plugins::TextXslate::API::_string($name))}=Plugins::TextXslate::API::_string($value); return ''; },
		tx_get       => sub { return Plugins::TextXslate::API::_string($vars{lc(Plugins::TextXslate::API::_string(shift))}); },
		tx_ansi      => sub { return Plugins::TextXslate::API::_string(shift); },
		tx_set_color => sub { return ''; },
		tx_rgb       => sub { return ''; },
		tx_blend     => sub { return Plugins::TextXslate::API::_string(shift); },
		transition=> sub { return Plugins::TextXslate::API::_string(shift); },
		tx_progress  => sub { my ($pos,$range,$width,$fill,$empty)=@_; $width=Plugins::TextXslate::API::_number($width)||10; $range=Plugins::TextXslate::API::_number($range); $range=1 if $range<1; my $n=int(Plugins::TextXslate::API::_number($pos)*$width/$range); $n=0 if $n<0; $n=$width if $n>$width; $fill=defined $fill?$fill:'#'; $empty=defined $empty?$empty:'-'; return ($fill x $n).($empty x ($width-$n)); },
		tx_progress2 => sub { my ($pos,$range,$width,$fill,$empty)=@_; $width=Plugins::TextXslate::API::_number($width)||10; $range=Plugins::TextXslate::API::_number($range); $range=1 if $range<1; my $n=int(Plugins::TextXslate::API::_number($pos)*$width/$range); $n=0 if $n<0; $n=$width if $n>$width; $fill=defined $fill?$fill:'='; $empty=defined $empty?$empty:'-'; return ($fill x $n).($empty x ($width-$n)); },
		tx_rand      => sub { return int(rand(4294967296)); },
	};
