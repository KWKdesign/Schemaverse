#! /usr/bin/perl

use 5.010;
use strict;
use warnings;
use Data::Dump qw/dump dd ddx pp/;
use DBI;
use Benchmark qw/:hireswallclock/;
use POSIX qw/strftime/;
use AnyEvent;
my $cv = AnyEvent->condvar;

my $shutdown = 0;
$SIG{INT} = sub {
    if( $shutdown == 0 ) {
        say 'Caught Ctrl-C... Will shutdown after this tic.';
        $shutdown = 1;
    }
    else {
        say 'Forcing Shutdown';
        exit;
    }
};

my $t1 = Benchmark->new();

=for comment

update variable set char_value = ( char_value::timestamp + '00:10:00'::interval ) where name = upper('round_start_date');
update variable set char_value = date_trunc('minutes',now() - get_char_variable(upper('round_length'))::interval ) where name = upper('round_start_date');

=cut

my $dt_fmt = '%T %Z';
my $t_fmt = '%.5f';
my $db_name 	= 'schemaverse';
my $db_username = 'schemaverse';

my $tic_w = AnyEvent->idle( cb => sub { # don't wait -- testing
# my $tic_w = AnyEvent->timer( interval => 60, cb => sub { # wait 60 -- live

    my $dbh = DBI->connect( 'dbi:Pg:dbname='.$db_name.';host=localhost', $db_username );
    say strftime( 'vacuum analyze -- Start: '.$dt_fmt, localtime );
    my $t_vac1 = Benchmark->new();
    $dbh->do('vacuum analyze');
    say strftime( 'vacuum analyze -- Finish: '.$dt_fmt, localtime ),
        sprintf(' '.$t_fmt.' s', timediff(Benchmark->new(),$t_vac1)->[0] );

    my $round_time = $dbh->selectcol_arrayref(q/
         select ( date_trunc( 'minutes', current_timestamp )::timestamp - get_char_variable( upper( 'round_start_date' ) )::timestamp );
    /)->[0];
    $round_time ||= 'Starting';
    say 'Round Time: ', $round_time;

    say strftime( 'Round Control -- Start: '.$dt_fmt, localtime );
    my $t_r1 = Benchmark->new();
    {
        $dbh->{PrintError} = 0;
        $dbh->{RaiseError} = 1;
        $dbh->do(q/
            select pg_cancel_backend(pid)
            from pg_stat_activity
            where 1=1
                and usename = 'schemaverse'
                and state = 'active'
                and query = 'select round_control();'
                ;
        /);
        my $r = eval { $dbh->selectrow_arrayref(q/select round_control();/)->[0] };
        die "$@" if $@;
        if( $r == 1 ) {
            $dbh->do('vacuum full;');
            $dbh->do('reindex database schemaverse;');
            say '#' x 20 for ( 1..5 );
            print 'New Round: ';
            say $dbh->selectcol_arrayref(q/select last_value from round_seq;/)->[0];
            say '#' x 20 for ( 1..5 );
        }
    }
    say strftime( 'Round Control -- Finish: '.$dt_fmt, localtime ),
        sprintf(' '.$t_fmt.' s', timediff(Benchmark->new(),$t_r1)->[0] );

    say strftime( 'Move Ships -- Start: ' . $dt_fmt, localtime );
    my $t_s1 = Benchmark->new();
    $dbh->do(q/ -- Move Ships
        begin work;
        lock table ship, ship_control in exclusive mode;
            select move_ships();
        commit work;
    /);
    say sprintf('Move Ships -- Finish: '.$t_fmt.' s', timediff(Benchmark->new(),$t_s1)->[0] );


=for comment

Player Scripts

Retreive Fleet Scripts and run them as the user they belong to

=cut

    say strftime( 'Fleet Scripts -- Start: '.$dt_fmt, localtime );
    my $t_f1 = Benchmark->new();
    my $fleet_fail_event = $dbh->prepare(q/
        insert into event ( tic, action, player_id_1, referencing_id, descriptor_string )
        values ( ( select last_value from tic_seq ), 'FLEET_FAIL', ?, ?, ? );
    /);
    my $rs = $dbh->prepare(q/
        select 
            player.id as player_id,
            player.username as username,
            fleet.id as fleet_id,
            player.error_channel as error_channel
        from fleet, player
        where 1=1
            and fleet.player_id=player.id
            and fleet.enabled='t'
            and fleet.runtime > '0 minutes'::interval
        order by player.username;
    /);
    $rs->execute();
    my $temp_user = '';
    my $tmp_dbh;
    my( $player_id, $player_username, $fleet_id, $error_channel );
    while ( ( $player_id, $player_username, $fleet_id, $error_channel ) = $rs->fetchrow() ) {
        my $t_p1 = Benchmark->new();
        
        if( $temp_user ne $player_username )	{
            if( $temp_user ne '' ) {
                $tmp_dbh->disconnect();			
            }
            $temp_user = $player_username;
            $tmp_dbh = DBI->connect('dbi:Pg:dbname='.$db_name.';host=localhost', $player_username );
            $tmp_dbh->{PrintWarn} = 0;
            $tmp_dbh->{PrintError} = 0;
            $tmp_dbh->{RaiseError} = 1;
        }
        #$tmp_dbh->{application_name} = $fleet_id;
        $tmp_dbh->do(qq/set application_name TO ${fleet_id}/);
        eval { $tmp_dbh->do(q/select run_fleet_script(?);/, undef, $fleet_id ); };
        if( $@ ) {
            $tmp_dbh->do(qq/
                NOTIFY ${error_channel}, 'Fleet script ${fleet_id} has failed to fully execute during the tic';
            /);
            # $fleet_fail_event->execute($player_id,$fleet_id,$@);
        }
        
        my $t_p2 = Benchmark->new();
        say sprintf('%s #%0d -- Finish: '.$t_fmt.' s', $player_username, $fleet_id, timediff(Benchmark->new(),$t_p1)->[0] );
    }
    if( $temp_user ne '' ) {
        $tmp_dbh->disconnect();
    }
    $rs->finish;
    say sprintf('Fleet Scripts -- Finish: '.$t_fmt.' s', timediff(Benchmark->new(),$t_f1)->[0] );

=for comment

End Player Scripts

=cut



=for comment

Ship control

=cut

    $dbh->do(q/ -- Update Ships
        begin work;
        lock table ship, ship_control in exclusive mode;
        select
            case
                when ship_control.action = 'ATTACK' then
                    attack( ship.id,  ship_control.action_target_id )::integer
                when ship_control.action = 'REPAIR' then
                    repair( ship.id,  ship_control.action_target_id )::integer
                when ship_control.action = 'MINE' then
                    mine( ship.id,  ship_control.action_target_id )::integer
                else null
            end
        from ship, ship_control
        where 1=1
            and ship.id = ship_control.ship_id
            and ship_control.action is not null
            and ship_control.action_target_id is not null
            and ship.destroyed = 'f'
            and ship.last_action_tic != ( select last_value from tic_seq );
        commit work;
    /);

    # planets are mined
    $dbh->do(q/ -- Perform Mining
        begin work;
        lock table planet_miners in exclusive mode;
        select perform_mining();
        commit work;
    /);

    # dirty planet renewal hack
    $dbh->do(q/
        update planet set fuel = fuel + 1000000
        where id in (
            select id from planet where fuel < 10000000 order by random() limit 5000
        );
    /);

    $dbh->do(q/ -- Move Ships
        begin work;
        lock table ship, ship_control in exclusive mode;
        
        update ship set current_health = max_health
        where 1=1
            and future_health >= max_health
            and current_health <> max_health
        ;
        
        update ship set current_health = future_health
        where 1=1
            and future_health between 0 and max_health
            and current_health <> max_health
        ;
        
        update ship set current_health = 0 where future_health < 0;
        update ship set last_living_tic = ( select last_value from tic_seq )
        where current_health > 0;

        update ship set destroyed = 't'
        where 1=1
            and ( select last_value - last_living_tic from tic_seq ) > get_numeric_variable('EXPLODED')
            and player_id > 0;

        commit work;
    /);

    $dbh->do(q/vacuum ship;/);

=for comment

Update some stats now and then

Update stat_log table

=cut

    say strftime( 'Round Stats -- Start: '.$dt_fmt, localtime );
    my $t_ps1 = Benchmark->new();
    my $stats_sth = $dbh->prepare(q/
        select player_id, round_id
        from player_round_stats
        order by round_id desc, last_updated asc limit 1;
    /);
    $stats_sth->execute();
    my $round_id;
    while( ( $player_id, $round_id ) = $stats_sth->fetchrow() ) {
=for comment
        drop view player_stats; -- depends on column ship_upgrades, re deploy after alter
        alter table player_round_stats alter column ship_upgrades type bigint using ship_upgrades::bigint;
=cut
        $dbh->do(q/
            update player_round_stats set
                damage_taken = cps.damage_taken,
                damage_done = cps.damage_done,
                planets_conquered = least( cps.planets_conquered, 32767 ),
                planets_lost = least( cps.planets_lost, 32767 ),
                ships_built = least( cps.ships_built, 32767 ),
                ships_lost = least( cps.ships_lost, 32767 ),
                ship_upgrades = cps.ship_upgrades,
                fuel_mined = cps.fuel_mined,
                distance_travelled = cps.distance_travelled,
                last_updated = now()
            from current_player_stats cps
            where player_round_stats.player_id = cps.player_id
                and cps.player_id = ?::int
                and player_round_stats.round_id = ?::int;
        /, undef, $player_id, $round_id );

        if ( $player_id % 100 == 0 ) {
            $dbh->do(q/
                update round_stats set
                avg_damage_taken = crs.avg_damage_taken,
                avg_damage_done = crs.avg_damage_done,
                avg_planets_conquered = crs.avg_planets_conquered,
                avg_planets_lost = crs.avg_planets_lost,
                avg_ships_built = crs.avg_ships_built,
                avg_ships_lost = crs.avg_ships_lost,
                avg_ship_upgrades = crs.avg_ship_upgrades,
                avg_fuel_mined = crs.avg_fuel_mined,
                avg_distance_travelled = crs.avg_distance_travelled
                    from current_round_stats crs
                    where round_stats.round_id = ?::int;
            /, undef, $round_id );
        }
    }
    say sprintf('Round Stats -- Finish: '.$t_fmt.' s', timediff(Benchmark->new(),$t_ps1)->[0] );

    $dbh->do(q/
        insert into event ( player_id_1, action, tic, public )
        values ( 0, 'TIC' ,( select last_value from tic_seq ), 't' );
    /);

    # Begin next tic
    say '#' x 20 for ( 1..2 );
    print 'New tic: ';
    $dbh->do(q/select nextval('tic_seq');/);
    my $tic = $dbh->selectcol_arrayref(q/select last_value from tic_seq;/)->[0];
    say $tic;
    say '#' x 20 for ( 1..2 );

    # Update graphs
    if ( -e '/home/schemaverse/schemaverse-graphs' ) {
      system( 'cd /home/schemaverse/schemaverse-graphs ; perl update.pl' );
    }
    
    if ( $shutdown == 1 ) {
        say 'Shutting down.';
        exit;
    }
    
    if( $tic % 10 == 0 ) {
        say strftime( 'Reindexing -- Start: '.$dt_fmt, localtime );
        my $t_idx1 = Benchmark->new();
        $dbh->do('reindex database schemaverse;');
        say strftime( 'Reindexing -- Finish: '.$dt_fmt, localtime ),
            sprintf(' '.$t_fmt.' s', timediff(Benchmark->new(),$t_vac1)->[0] );
    }

});

$cv->recv;
