use strict;
use warnings;

package MT::Plugin::GroongaSearch::App::Core;

use File::Spec;
use File::Path;
use MT::Plugin::GroongaSearch::Util qw(:ALL);

sub on_init_app {
    my ( $cb, $app ) = @_;

    my $handlers = $app->registry('groonga_search', 'sync_handlers');
    foreach my $key ( keys %$handlers ) {
        my $handler = $handlers->{$key};
        next if !$handler || ref $handler ne 'HASH';
        my $database = $handler->{database} || $key;

        # Object and model
        my $object = $handler->{object}
            || die translate('groonga_search/sync_handlers entry requires object');
        my $model = MT->model($object)
            || die translate('Unknown model [_1] in groonga_search/sync_handlers/[_2]', $object, $key);

        # Attach handlers to callback
        foreach my $event ( qw/post_save post_remove/ ) {
            my $code = $handler->{$event} || next;
            $code = MT->handler_to_coderef($code) if ref $code ne 'CODE';
            die translate('[_1] in groonga_search/sync_handlers must be valid code reference')
                if ref $code ne 'CODE';

            $model->add_trigger( $event => sub {
                my ( $object, $before ) = @_;
                my $driver = database_driver($database);
                $code->($driver, $object);
            });
        }
    }
}

1;
__END__
