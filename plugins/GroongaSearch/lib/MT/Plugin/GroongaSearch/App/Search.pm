package MT::Plugin::GroongaSearch::App::Search;
use strict;
use warnings;

use MT::Plugin::GroongaSearch::Util qw/:ALL/;

sub groonga_search {
    my $app = shift;
    my %hash = $app->param_hash;
    my $database = delete $hash{database} || delete $hash{db}
        || return $app->json_error('database required');

    my $driver = require_database_driver($database)
        || return $app->json_error('unknown database [_1]', $database);

    # Prepare hook
    my $handlers = $app->registry( registry_group, 'search_handlers', $database ) || {};
    my %hooks;
    foreach my $cb ( qw/query_param query_result/ ) {
        my $code = $handlers->{$cb} || next;
        $code = MT->handler_to_coderef($code);
        next if ref $code ne 'CODE';

        $hooks{$cb} = $code;
    }

    delete $hash{__mode};
    $hooks{query_param}->($database, $driver, \%hash)
        if $hooks{query_param};

    my $q = delete $hash{q} || '';
    $q = normalize_text($q);

    my $result = $driver->query( $q, \%hash );
    $hooks{query_result}->($database, $driver, $result, \%hash)
        if $hooks{query_result};

    $app->json_result($result);
}

1;
__END__
