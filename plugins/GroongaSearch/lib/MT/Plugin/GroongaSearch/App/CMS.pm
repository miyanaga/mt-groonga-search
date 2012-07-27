package MT::Plugin::GroongaSearch::App::CMS;
use strict;
use warnings;

use MT::Plugin::GroongaSearch::Util qw(:ALL);
use Time::HiRes;

sub system_config {
    my ( $app, $param ) = @_;

    # Defaults
    $param->{groonga_search_database_path} ||= database_default_path();

    # Supplements
    $param->{base_path} = plugin->path;

    plugin->load_tmpl('system_config.tmpl');
}

{
    sub _normalized_resync_handlers {
        my $app = shift;
        my $resyncs = $app->registry( registry_group, 'resync_handlers' );
        my @values;
        while ( my ( $key, $orig ) = each %$resyncs ) {
            my %value = %$orig;
            $value{handler} = $key;
            $value{database} ||= $key;
            $value{label} ||= $key;
            $value{estimate} = MT->handler_to_coderef($value{estimate});

            push @values, \%value;
        }

        $app->filter_conditional_list(\@values);
    }
}

sub resync_menu_condition {
    my $app = MT->app || return 0;
    my $user = $app->user || return 0;
    return 0 unless $user->can_do('resync_groonga_sync');

    my $resyncs = $app->registry( registry_group, 'resync_handlers' );
    keys %$resyncs? 1: 0;
}

{
    sub _resync_session_kind { '_G' }

    sub _has_resync_sessions {
        my $count = MT->model('session')->count( { kind => _resync_session_kind } );
        $count? 1: 0;
    }

    sub _get_resync_session {
        my ( $name ) = @_;
        if ( my $session = MT->model('session')->load( { kind => _resync_session_kind, id => $name } ) ) {
            return $session->start || 0;
        }

        0;
    }

    sub _start_resync_session {
        my ( $name ) = @_;
        my $now ||= time;
        my $session = MT->model('session')->load( { kind => _resync_session_kind, id => $name } )
            || MT->model('session')->new;

        $session->set_values({
            id  => $name,
            kind => _resync_session_kind,
            start => $now,
        });
        $session->save;

        $now;
    }

    sub _remove_resync_session {
        my ( $name ) = @_;
        MT->model('session')->remove( { kind => _resync_session_kind, id => $name } );
    }
}

sub resync {
    my $app = shift;
    my $blog = $app->blog && return $app->error( $app->translate('Invalid parameter') );
    my $user = $app->user || return $app->error( $app->translate('Invalid parameter') );
    return $app->error( $app->translate('Permission denied.') )
        unless $user->can_do('administer');

    my $handlers = _normalized_resync_handlers($app);

    foreach my $handler ( @$handlers ) {
        my $database = $handler->{database};
        my $estimate = $handler->{estimate};

        my $driver = database_driver($database);
        my ( $count, $steps ) = ref $estimate eq 'CODE'? $estimate->($app, $database, $driver): ( 0, 0 );
        $handler->{object_count} = $count;
        $handler->{steps} = $steps || 1;
        $handler->{src} = $app->uri( mode => 'groonga_search_resync_step', args => {
            handler => $handler->{handler},
            step => 0,
        });
    }

    plugin->load_tmpl('resync.tmpl', {
        handlers => $handlers,
        maybe_processing => _has_resync_sessions,
    });
}

sub resync_step {
    my $app = shift;
    my $blog = $app->blog && return $app->json_error( $app->translate('Invalid parameter') );
    my $user = $app->user || return $app->json_error( $app->translate('Invalid parameter') );
    return $app->json_error( $app->translate('Permission denied.') )
        unless $user->can_do('administer');

    my $q = $app->param;
    my $key = $q->param('handler')
        || return $app->json_error( $app->translate("Invalid parameter") );
    my $step = int($q->param('step'));
    my $started_from = $q->param('started_from');

    my $handler = $app->registry( registry_group, 'resync_handlers', $key )
        || return $app->json_error( $app->translate("Invalid parameter") );
    my $database = $handler->{database} || $key;

    if ( $started_from ) {
        if ( my $current_session = _get_resync_session($key) ) {
            return $app->json_error( translate('Another resync session started.') )
                if $current_session != $started_from;
        }
    } else {
        $started_from = _start_resync_session($key);
    }

    my $step_code = MT->handler_to_coderef($handler->{step});
    if ( ref $step_code ne 'CODE' ) {
        _remove_resync_session($key);
        return $app->json_error( plugin->translate('entry of registry groonga_search/resync_handlers requires step as code ref') );
    }

    my $driver = database_driver($database);
    unless ( $driver ) {
        _remove_resync_session($key);
        return $app->json_error( plugin->translate('Invalid groonga database [_1]', $database) );
    }

    local $@ = undef;
    my $continue = eval { $step_code->($app, $database, $driver, $step, $started_from); };

    if ( !$@ && defined($continue) ) {
        if ( $continue ) {
            my $next_step = $step + 1;
            return $app->json_result( {
                continue => 1,
                finished => 0,
                next_step => $next_step,
                next_src => $app->uri( mode => 'groonga_search_resync_step', args => {
                    handler => $key,
                    step => $next_step,
                    started_from => $started_from,
                }),
            } );
        } else {
            _remove_resync_session($key);
            return $app->json_result( {
                continue => 0,
                finished => 1,
            });
        }
    } else {
        _remove_resync_session($key);
        return $app->json_error( $@ || $app->errstr || 'An error occurred' );
    }
}

1;
__END__
