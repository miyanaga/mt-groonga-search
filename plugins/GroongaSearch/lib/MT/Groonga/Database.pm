use strict;
use warnings;

package MT::Groonga::Database;
use base 'MT::ErrorHandler';

use Encode;
use JSON;
use Groonga::Console;

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new;
    my ( $name, $dbpath ) = @_;
    $self->{__name} = $name;
    $self->{__groonga} = Groonga::Console->new($dbpath);

    MT::log($dbpath);

    $self;
}

sub name { shift->{__name} }
sub groonga { shift->{__groonga} }

{
    sub _must_be_overridden {
        die translate('Do not use bare [_1]', __PACKAGE__);
    }
}

sub main_table { _must_be_overridden }
sub migrate { _must_be_overridden }
sub query { _must_be_overridden }

sub timestamp_column { 'timestamp' }
sub allowed_command { qw/^(select|load|delete)$/ }

sub plugin { MT->component('groongasearch' ) }

sub raw_command {
    my $self = shift;
    my ( $command, $args, $body ) = @_;

    # Normalize args
    $args = $args && ref $args eq 'HASH'
        ? $args # Retain
        : $args && !ref $args
            ? { '' => $args } # Hashalize scalar
            : {}; # Empty

    # Default table
    $args->{table} ||= $self->main_table;

    # Check strictly command name
    die plugin->translate('invalid command [_1]', $command)
        unless $command =~ $self->allowed_command;

    # Filter and build arguments
    use Data::Dumper;
    MT::log(Dumper($args));
    my @partials = map {
        # Format command line
        my $value = $args->{$_};
        $value =~ s/"/\\"/;
        $_? qq{--$_ "$value"}: qq{"$value"};
    } sort {
        # Precede '' and table
        return -1 if $a eq '';
        return 1 if $b eq '';
        return -1 if $a eq 'table';
        return 1 if $b eq 'table';
        $a cmp $b;
    } grep {
        # Avoid symbols
        /^[a-z0-9_]*$/i && !ref $args->{$_}
    } keys %$args;
    unshift @partials, $command;

    # Build and send a command line and body
    my $line = join(' ', @partials);
    MT::log($line);

    my $result = $self->groonga->console($line);

    MT::log($body) if $body;
    $result = $self->groonga->console($body) if $body;

    $result;
}

sub command {
    my $self = shift;
    my $result = $self->raw_command(@_);
    MT::log($result);
    my $json = eval { decode_json($result); };
    $json;
}

sub select {
    my $self = shift;
    my ( $args ) = @_;
    $self->command('select', @_);
}

sub pivot_select_results {
    my $self = shift;
    my ( $raw_result, $index ) = @_;
    $index ||= 0;
    my $tupples = $raw_result->[$index] || [0, [], []];

    # Headers as name array
    my @headers = map { $_->[0] } @{$tupples->[1]};

    # Results as hash array
    my @results;
    for ( my $i = 2; $i < scalar @$tupples; $i++ ) {
        my $row = $tupples->[$i];
        my %record;
        for ( my $j = 0; $j < scalar @headers; $j++ ) {
            my $header = $headers[$j];
            my $value = $row->[$j];
            $record{$header} = $value;
        }
        push @results, \%record;
    }

    ( \@headers, \@results );
}

sub load {
    my $self = shift;
    my ( $args, $objects ) = @_;
    $objects = [$objects] unless ref $objects eq 'ARRAY';

    # Decode hash deeply
    my @decoded;
    foreach my $object ( @$objects ) {
        next if ref $object ne 'HASH';
        foreach my $key ( keys %$object ) {
            my $value = $object->{$key} || next;
            if ( ref $value eq 'ARRAY' ) {

                # In the case of array
                $value = [ map {
                    utf8::is_utf8($_)
                        ? $_
                        : Encode::decode_utf8($_)
                } grep {
                    $_ && ref $_ eq ''
                } @$value ];
            } elsif ( ref $value eq '' ) {

                # In the case of scalar
                $value = Encode::decode_utf8($value) unless utf8::is_utf8($_);
            } else {

                # Unsuported
                next;
            }

            $object->{$key} = $value;
        }

        push @decoded, $object;
    }

    my $json = encode_json(\@decoded);
    $self->raw_command('load', $args, $json);
}

sub delete {
    my $self = shift;
    my $arg = pop;
    my ( $table ) = @_;
    $table ||= $self->table;

    my $line = join( ' ', 'delete', $table, qq{"$arg"} );
    MT::log($line);
    $self->groonga->console($line);
}

sub clear_before {
    my $self = shift;
    my $ts = pop;

    my $arg = $self->timestamp_column . '<' . $ts;
    $self->delete(@_, $arg);
}

1;
__END__
