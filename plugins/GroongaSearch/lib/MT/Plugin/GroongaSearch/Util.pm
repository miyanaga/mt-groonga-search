package MT::Plugin::GroongaSearch::Util;
use strict;
use warnings;

use base 'Exporter';

use Encode;
use Lingua::JA::Regular::Unicode qw/alnum_z2h space_z2h katakana_h2z katakana2hiragana/;
use MT::Util qw/decode_html/;

our @EXPORT_OK = qw/
                    plugin translate registry_group system_config load_config
                    database_driver_class database_driver require_database_driver database_path
                    html_to_text normalize_text
                /;
our %EXPORT_TAGS = ( ALL => \@EXPORT_OK );

sub plugin { MT->component('groongasearch') }

sub translate { plugin->translate(@_) }

sub registry_group { 'groonga_search' }

sub database_default_path { 'data/groonga' }

sub database_default_driver { 'MT::Groonga::Database::GeneralTexts' }

sub load_config {
    my $pkg = shift;
    my ( $blog_id ) = @_;
    $blog_id = $blog_id->id if $blog_id && ref $blog_id;

    my $scope = $blog_id? "blog:$blog_id": 'system';
    my %config;
    plugin->load_config( \%config, $scope );
    \%config;
}

sub database_path {
    my $database = pop;
    die translate('database name must be consisted with alphabates or numbers')
        unless $database =~ /^[a-z0-9_\-\/]+$/i;

    # Build database path
    my $path = load_config->{groonga_search_database_path} || database_default_path;
    $path = File::Spec->catdir(plugin->path, $path) if $path !~ m!^/!;
    $path = File::Spec->catdir($path, $database);

    # Check and keep parent
    my @parent = File::Spec->splitdir($path);
    pop @parent;
    my $parent = File::Spec->catdir(@parent);

    die translate('[_1] already exists as file', $parent) if -f $parent;
    File::Path::mkpath($parent) unless -d $parent;
    die translate('Can not make directory [_1]', $parent) unless -d $parent;

    # Die if already directory
    die translate('[_1] already exists as directory', $path) if -d $path;

    $path;
}

sub database_driver_class {
    my $database = pop;

    # Get package name from registry
    my $reg = MT->app->registry( 'groonga_search', 'database_drivers' );
    my $pkg = $reg->{$database} || database_default_driver;

    eval "require $pkg;" || die $@;
    $pkg;
}

sub database_driver {
    my $database = pop;

    # Path and class
    my $path = database_path($database);
    my $class = database_driver_class($database);

    # Migrate if not exists
    my $driver;
    unless ( -f $path ) {
        $driver = $class->new($database, $path);
        $driver->migrate;
    }
    $driver ||= $class->new($database, $path);

    $driver;
}

sub require_database_driver {
    my $database = pop;

    # Path and class
    my $path = database_path($database);
    my $class = database_driver_class($database);

    return unless -f $path;
    $class->new($database, $path);
}

sub normalize_text {
    my ( $text, $ignore_space, $ignore_kana ) = @_;

    # Zen to han: alphabet, numeric and space
    # To lower case: alphabet
    # Han to zen: katakana
    # Katakana to hiragana
    $text = Encode::decode_utf8($text) unless Encode::is_utf8($text);
    $text = lc(alnum_z2h($text));
    $text = katakana_h2z($text);
    $text = space_z2h($text) unless $ignore_space;
    $text = katakana2hiragana($text) unless $ignore_kana;
    $text = Encode::encode_utf8($text);

    $text;
}

sub html_to_text {
    my ( $text, $ignore_space, $ignore_kana ) = @_;

    # Copied from MT::Util::remove_html because no need encoding.
    $text =~ s/(<\!\[CDATA\[(.*?)\]\]>)|(<[^>]+>)/
        defined $1 ? $1 : ''
        /geisx;
    $text =~ s/<(?!\!\[CDATA\[)/&lt;/gis;

    # Decode html and normalize
    $text = decode_html($text);
    $text = normalize_text($text, $ignore_space, $ignore_kana);

    $text;
}


1;
__END__
