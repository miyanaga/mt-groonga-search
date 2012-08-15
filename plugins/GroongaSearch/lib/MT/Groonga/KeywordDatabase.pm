use strict;
use warnings;

package MT::Groonga::KeywordDatabase;
use base 'MT::ErrorHandler';

use Encode;
use Data::Recursive::Encode;
use JSON;
use Groonga::Console;

sub new {
    my $pkg = shift;
    my $self = $pkg->SUPER::new;
    my ( $dbpath ) = @_;
    $self->{__groonga} = Groonga::Console->new($dbpath);

    $self;
}

sub groonga { shift->{__groonga} }

sub plugin { MT->component('groongasearch' ) }

sub table { 'texts' }

sub command {
    my $self = shift;
    my ( $command, $args, $body ) = @_;
    $args ||= {};
    $args->{table} = table;

    # Check strictly command name
    die plugin->translate('invalid command [_1]', $command)
        unless $command =~ /^(select|load|delete)$/;

    # Filter and build arguments
    my @partials = map {
        my $value = $args->{$_};
        $value =~ s/'/\\'/;
        $_? qq{--$_ '$value'}: qq{'$value'};
    } sort {
        $a cmp $b
    } grep {
        /^[a-z0-9]*/i && !ref $args->{$_}
    } keys %$args;
    unshift @partials, $command;

    my $line = join(' ', @partials);
    my $result = $self->groonga->console($line);
    if ( $body ) {
        $result = $self->groonga->console($body);
    }

    $result;
}

sub json_command {
    my $result = shift->command(@_);
    my $json = decode_json($result);
    $json;
}

sub select {
    my $self = shift;
    my ( $args ) = @_;
    $self->json_command('select', @_);
}

sub parse_select_result {
    my $self = shift;
    my ( $raw_result, $index ) = @_;
    $index ||= 0;
    my $tupples = $raw_result->[$index] || [0, [], []];

    my @results;
    my @headers = map { $_->[0] } @{$tupples->[1]};
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

    my @decoded;
    foreach my $object ( @$objects ) {
        next if ref $object ne 'HASH';
        foreach my $key ( keys %$object ) {
            my $value = $object->{$key} || next;
            if ( ref $value eq 'ARRAY' ) {
                $value = [ map {
                    Encode::is_utf8($_)
                        ? $_
                        : Encode::decode_utf8($_)
                } grep {
                    $_ && ref $_ eq ''
                } @$value ];
            } elsif ( ref $value eq '' ) {
                $value = Encode::decode_utf8($value) unless Encode::is_utf8($_);
            } else {
                next;
            }
            $object->{$key} = $value;
        }

        push @decoded, $object;
    }

    my $json = encode_json(\@decoded);
    $self->command('load', $args, $json);
}

sub delete {
    my $self = shift;
    my ( $arg ) = @_;
    my $line = join( ' ', 'delete', $self->table, qq{"$arg"} );
    $self->groonga->console($line);
}

sub migrate {
    my $self = shift;

    my $script = <<'GROONGA';
table_create --name keywords --flags TABLE_HASH_KEY --key_type ShortText
table_create --name terms --flags TABLE_PAT_KEY|KEY_NORMALIZE --key_type ShortText --default_tokenizer TokenBigramIgnoreBlankSplitSymbolAlphaDigit

column_create --table keywords --name object_ds --flags COLUMN_SCALAR --type ShortText
column_create --table keywords --name object_id --flags COLUMN_SCALAR --type Int32
column_create --table keywords --name text1 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text2 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text3 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text4 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text5 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text6 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text7 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text8 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text9 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name text10 --flags COLUMN_VECTOR --type LongText
column_create --table keywords --name timestamp --flags COLUMN_SCALAR --type Float
column_create --table keywords --name crated_on --flags COLUMN_SCALAR --type Time
column_create --table keywords --name modified_on --flags COLUMN_SCALAR --type Time


column_create --table terms --name text1 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text1
column_create --table terms --name text2 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text2
column_create --table terms --name text3 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text3
column_create --table terms --name text4 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text4
column_create --table terms --name text5 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text5
column_create --table terms --name text6 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text6
column_create --table terms --name text7 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text7
column_create --table terms --name text8 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text8
column_create --table terms --name text9 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text9
column_create --table terms --name text10 --flags COLUMN_INDEX|WITH_POSITION --type keywords --source text10
GROONGA

    $self->groonga->console($script);
}

1;
__END__
