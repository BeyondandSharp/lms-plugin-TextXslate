package Slim::Utils::Log;

use strict;
use warnings;

our %CATEGORIES;

sub reset {
    %CATEGORIES = ();
    return;
}

sub addLogCategory {
    my ($class, @arguments) = @_;

    # LMS accepts either a hashref or a plain key/value list.
    my %args = @arguments == 1 && ref $arguments[0] eq 'HASH'
        ? %{ $arguments[0] }
        : @arguments;

    my $name = $args{category} || 'unknown';
    $CATEGORIES{$name} ||= bless {
        category => $name,
        level    => $args{defaultLevel} || 'ERROR',
        messages => [],
    }, 'Slim::Utils::Log::Category';

    return $CATEGORIES{$name};
}

sub logger {
    my ($class, @arguments) = @_;

    my %args = @arguments == 1 && ref $arguments[0] eq 'HASH'
        ? %{ $arguments[0] }
        : @arguments;

    return $class->addLogCategory( category => $args{category} || 'unknown' );
}

sub category_for {
    my ($class, $name) = @_;
    return $CATEGORIES{$name};
}

package Slim::Utils::Log::Category;

use strict;
use warnings;

sub reset {
    my ($self) = @_;
    @{ $self->{messages} } = ();
    return;
}

sub messages { return $_[0]->{messages} }

sub _record {
    my ($self, $level, @parts) = @_;
    my $text = join '', map { defined $_ ? $_ : '' } @parts;
    push @{ $self->{messages} }, { level => $level, text => $text };
    return;
}

sub error { my $self = shift; $self->_record( 'ERROR', @_ ); return }
sub warn  { my $self = shift; $self->_record( 'WARN',  @_ ); return }
sub info  { my $self = shift; $self->_record( 'INFO',  @_ ); return }
sub debug { my $self = shift; $self->_record( 'DEBUG', @_ ); return }

sub is_error { return 1 }
sub is_warn  { return 1 }
sub is_info  { return 1 }
sub is_debug { return 0 }

1;
