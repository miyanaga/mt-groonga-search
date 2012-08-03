use strict;
use warnings;

package MT::Groonga::Database::GeneralTexts;
use base 'MT::Groonga::Database';

sub main_table { 'data' }

sub default_limit { 100 }

sub query {
    my $self = shift;
    my ( $q, $offset, $limit, $params ) = @_;
    $offset = 0 unless defined $limit;
    $limit = default_limit unless defined $limit;

    $params ||= {};
    $params->{limit} = int($limit);
    $params->{offset} = int($offset);
    $params->{output_columns} ||= '_key,_score';
    $params->{match_columns} ||= join(',', map { "text$_*$_" } (1..10) );
    $params->{query} ||= qq{"$q"};
    $params->{sortby} ||= '-_score';

    my $json = $self->select($params);
    $self->pivot_select_results($json);
}

sub migrate {
    my $self = shift;

    my $script = <<'GROONGA';
table_create --name data --flags TABLE_HASH_KEY --key_type ShortText
table_create --name terms --flags TABLE_PAT_KEY|KEY_NORMALIZE --key_type ShortText --default_tokenizer TokenBigramIgnoreBlankSplitSymbolAlphaDigit

column_create --table data --name blog_id --flags COLUMN_SCALAR --type Int32
column_create --table data --name text1 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text2 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text3 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text4 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text5 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text6 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text7 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text8 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text9 --flags COLUMN_VECTOR --type LongText
column_create --table data --name text10 --flags COLUMN_VECTOR --type LongText
column_create --table data --name timestamp --flags COLUMN_SCALAR --type Float

column_create --table terms --name text1 --flags COLUMN_INDEX|WITH_POSITION --type data --source text1
column_create --table terms --name text2 --flags COLUMN_INDEX|WITH_POSITION --type data --source text2
column_create --table terms --name text3 --flags COLUMN_INDEX|WITH_POSITION --type data --source text3
column_create --table terms --name text4 --flags COLUMN_INDEX|WITH_POSITION --type data --source text4
column_create --table terms --name text5 --flags COLUMN_INDEX|WITH_POSITION --type data --source text5
column_create --table terms --name text6 --flags COLUMN_INDEX|WITH_POSITION --type data --source text6
column_create --table terms --name text7 --flags COLUMN_INDEX|WITH_POSITION --type data --source text7
column_create --table terms --name text8 --flags COLUMN_INDEX|WITH_POSITION --type data --source text8
column_create --table terms --name text9 --flags COLUMN_INDEX|WITH_POSITION --type data --source text9
column_create --table terms --name text10 --flags COLUMN_INDEX|WITH_POSITION --type data --source text10
GROONGA

    $self->groonga->console($script);
}

1;
__END__
