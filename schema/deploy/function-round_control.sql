-- Deploy function-round_control

begin;

create or replace function round_control()
  returns boolean as
$body$
declare
	new_planet record;
	trophies record;
	players record;
	p record;
    
    -- map generation variables
    r numeric;
    a numeric;
    b numeric;
    turns int := 1; -- values >= 1
    arms int := 4;
    loc point;
begin

	if not session_user = 'schemaverse' then
		return 'f';
	end if;	

	if not date_trunc( 'minutes',current_timestamp )::timestamp - get_char_variable( upper( 'round_start_date' ) )::timestamp > get_char_variable( upper( 'round_length' ) )::interval then
		return 'f';
	end if;

    -- test server speedup hack
    delete from round_stats where round_id < ( select last_value - get_numeric_variable( upper( 'stats_window' ) )::bigint from round_seq );
    analyze round_stats;
    delete from player_round_stats where round_id < ( select last_value - get_numeric_variable( upper( 'stats_window' ) )::bigint from round_seq );
    analyze player_round_stats;

	update round_stats set
        	avg_damage_taken = current_round_stats.avg_damage_taken,
                avg_damage_done = current_round_stats.avg_damage_done,
                avg_planets_conquered = current_round_stats.avg_planets_conquered,
                avg_planets_lost = current_round_stats.avg_planets_lost,
                avg_ships_built = current_round_stats.avg_ships_built,
                avg_ships_lost = current_round_stats.avg_ships_lost,
                avg_ship_upgrades = current_round_stats.avg_ship_upgrades,
                avg_fuel_mined = current_round_stats.avg_fuel_mined
        from current_round_stats
        where round_stats.round_id = ( select last_value from round_seq );

	for players in
        select player.id, sum( case when s.id is null then 0 else 1 end )
        from player
        left join player_round_stats prs on prs.player_id = player.id
        left join ship s on s.player_id = player.id
        where round_id = ( select last_value from round_seq )
        group by player.id, prs.ships_built
        having 1=0
            or prs.ships_built > 0
            or sum( case when s.id is null then 0 else 1 end ) > 0
    loop
        update player_round_stats set
			damage_taken = least( 2147483647, current_player_stats.damage_taken ),
			damage_done = least( 2147483647, current_player_stats.damage_done ),
			planets_conquered = least( 32767, current_player_stats.planets_conquered ),
			planets_lost = least( 32767, current_player_stats.planets_lost ),
			ships_built = least( 32767, current_player_stats.ships_built ),
			ships_lost = least( 32767, current_player_stats.ships_lost ),
			ship_upgrades = least( 2147483647, current_player_stats.ship_upgrades ),
			fuel_mined = current_player_stats.fuel_mined,
			last_updated = now()
		from current_player_stats
        where 1=1
            and player_round_stats.player_id = players.id
            and current_player_stats.player_id = players.id
            and player_round_stats.round_id = ( select last_value from round_seq );

		update player_overall_stats por set 
			damage_taken = por.damage_taken + player_round_stats.damage_taken,
			damage_done = por.damage_done + player_round_stats.damage_done,
			planets_conquered = por.planets_conquered + player_round_stats.planets_conquered,
			planets_lost = por.planets_lost + player_round_stats.planets_lost,
			ships_built = por.ships_built + player_round_stats.ships_built,
			ships_lost = por.ships_lost + player_round_stats.ships_lost,
			ship_upgrades = por.ship_upgrades + player_round_stats.ship_upgrades,
			fuel_mined = por.fuel_mined + player_round_stats.fuel_mined
		from player_round_stats
		where por.player_id = player_round_stats.player_id 
			and por.player_id = players.id
            and player_round_stats.round_id = ( select last_value from round_seq );
	end loop;


	for trophies in select id from trophy where approved = 't' order by run_order asc loop
		execute 'insert into player_trophy select * from trophy_script_' || trophies.id ||'( ( select last_value from round_seq )::integer );';
	end loop;

	alter table planet disable trigger all;
	alter table fleet disable trigger all;
	alter table planet_miners disable trigger all;
	alter table ship_flight_recorder disable trigger all;
	alter table ship_control disable trigger all;
	alter table ship disable trigger all;
	alter table event disable trigger all;

	--Deactive all fleets
    update fleet set runtime =  '0 minutes', enabled = 'f';

	--add archives of stats and events
	create temp table tmp_current_round_archive as select ( select last_value from round_seq ), event.* from event;
	execute 'copy tmp_current_round_archive to ''/hell/schemaverse_round_' || ( select last_value from round_seq ) || '.csv''  with delimiter ''|''';

	--Delete everything else
    delete from planet_miners;
    delete from ship_flight_recorder;
    delete from ship_control;
    delete from ship;
    delete from event;
    delete from planet where id != 1;

	update fleet set last_script_update_tic = 0;

    alter sequence event_id_seq restart with 1;
    alter sequence ship_id_seq restart with 1;
    alter sequence tic_seq restart with 1;
	alter sequence planet_id_seq restart with 2;


	--Reset player resources
    update player set balance = 10000, fuel_reserve = 100000 where username != 'schemaverse';
    update fleet set runtime = '1 minute', enabled = 't' from player where player.starting_fleet = fleet.id and player.id = fleet.player_id;
 

	update planet set fuel = 20000000 where id = 1;
    
    -- while ( select count(1) from planet ) < ( select count(1) from player ) * 1.05 loop
    -- while ( select count(1) from planet ) < 2000 loop
        -- for new_planet in
            -- select nextval( 'planet_id_seq' ) as id,
            -- case ( random() * 11 )::integer % 12
                -- when 0 then 'Aethra_' || generate_series
                -- when 1 then 'Mony_' || generate_series
                -- when 2 then 'Semper_' || generate_series
                -- when 3 then 'Voit_' || generate_series
                -- when 4 then 'Lester_' || generate_series 
                -- when 5 then 'Rio_' || generate_series 
                -- when 6 then 'Zergon_' || generate_series 
                -- when 7 then 'Cannibalon_' || generate_series
                -- when 8 then 'Omicron Persei_' || generate_series
                -- when 9 then 'Urectum_' || generate_series
                -- when 10 then 'Wormulon_' || generate_series
                -- when 11 then 'Kepler_' || generate_series
            -- end as name,
            -- greatest( ( random() * 100 )::integer, 30 ) as mine_limit,
            -- greatest( ( random() * 1000000000 )::integer, 100000000 ) as fuel,
            -- greatest( ( random() * 10 )::integer , 2 ) as difficulty,
            -- ( NULL )::point as location
        -- from generate_series( 1, 500 )
        -- loop
            -- <<location>>
            -- while 1=1 loop
                -- new_planet.location := point(
                    -- case ( random() * 1 )::integer % 2
                        -- when 0 then ( random() * get_numeric_variable( upper( 'universe_creator' ) ) )::integer 
                        -- when 1 then ( random() * get_numeric_variable( upper( 'universe_creator' ) ) * -1 )::integer
                    -- end,
                    -- case ( random() * 1 )::integer % 2
                        -- when 0 then ( random() * get_numeric_variable( upper( 'universe_creator' ) ) )::integer
                        -- when 1 then ( random() * get_numeric_variable( upper( 'universe_creator' ) ) * -1 )::integer		
                    -- end
                -- );
                -- exit location when 1=1
                    -- and new_planet.location <@ circle( point( 0, 0 ), get_numeric_variable( upper( 'universe_creator' ) ) )
                    -- and not exists ( select 1 from planet where ( location <-> new_planet.location ) <= 3000 )
                -- ;
            -- end loop;
            -- insert into planet ( id, name, mine_limit, difficulty, fuel, location, location_x, location_y )
            -- values( new_planet.id, new_planet.name, new_planet.mine_limit, new_planet.difficulty, new_planet.fuel, new_planet.location, new_planet.location[0], new_planet.location[1] );
        -- end loop;
    -- end loop;
    -- select
        -- 100000::numeric radius,
        -- 0::numeric y,
        -- 0::numeric a,
        -- 0::numeric b,
        -- null::point ta,
        -- null::point tb,
        -- 0::numeric angle,
        -- 1::int i,
        -- 0::int cnt,
        -- 2000::int target,
        -- -- ( select count(1) * 1.05 from player )::int target,
        -- null::point loc
    -- into new_planet;
    -- <<planet>>
    -- while 1=1 loop
        -- new_planet.y := new_planet.i * ( 2 * new_planet.radius );
        -- new_planet.a := asin( new_planet.radius / pow( new_planet.y, 2 ) );
        -- new_planet.b := pi() / 2;
        -- new_planet.ta := point(
            -- new_planet.radius * sin( new_planet.b - new_planet.a ),
            -- new_planet.radius * -cos( new_planet.b - new_planet.a )
        -- );
        -- new_planet.tb := point(
            -- new_planet.radius * -sin( new_planet.b + new_planet.a ),
            -- new_planet.radius * cos( new_planet.b +  new_planet.a )
        -- );
        -- new_planet.angle := sqrt( pow( new_planet.y, 2 ) * 3 / 4 );
        -- new_planet.angle := 2 * asin( ( ( new_planet.ta <-> new_planet.tb ) / 2 ) / new_planet.angle );
        -- new_planet.angle := 2 * pi() / round( ( 2 * pi() ) / new_planet.angle );
        -- for div in 1 .. round( ( 2 * pi() ) / new_planet.angle ) loop
            -- new_planet.loc := point(
                -- round( new_planet.y * sin( div * new_planet.angle ) ),
                -- round( new_planet.y * cos( div * new_planet.angle ) )
            -- );
            -- continue when exists ( select 1 from planet where location <-> new_planet.loc <= new_planet.radius );
            -- new_planet.cnt := new_planet.cnt + 1;
            -- insert into planet ( id, fuel, mine_limit, difficulty, location, location_x, location_y )
            -- values (
                -- nextval( 'planet_id_seq' ),
                -- greatest( ( random() * 1000000000 )::integer, 100000000 ),
                -- greatest( ( random() * 100 )::integer, 30 ),
                -- greatest( ( random() * 10 )::integer , 2 ),
                -- new_planet.loc, new_planet.loc[0], new_planet.loc[1]
            -- );
            -- exit planet when new_planet.cnt >= new_planet.target;
        -- end loop;
        -- new_planet.i := new_planet.i + 1;
    -- end loop;
    
    
/*
-- map generation variable declarations
r numeric;
a numeric;
b numeric;
turns int := 1; -- values >= 1
arms int := 2;
loc point;
*/
-- map generation script
a := coalesce( get_numeric_variable( 'UNIVERSE_CREATOR' ), 6750000 )::numeric;
<<planet>>
while 1=1 loop
    r := random() * ( a - ( a / turns / arms ) );
    if r > a / 2 / pi() then -- point on spiral
        -- get angle from r and seperation ( reverse r = b * theta )
        b := r / ( 2 * a / turns / arms ) * pi();
        -- convert polar to cartesian
        loc := point( r * cos( b ), r * sin( b ) );
        -- get random angle for scattering along arm
        b := random() * 2 * pi();
        -- get random distance from arm
        -- cluster towards center of arm by squaring random value
        r := pow( random(), 2 ) * a / turns / arms / 2;
        -- apply transform
        loc := loc + point( r * cos( b ), r * sin( b ) );
        -- get angle of rotation for random arm
        b := 2 * pi() * ceil( random() * arms ) / arms;
        -- apply 2d rotation
        loc := point(
            loc[0] * cos( b ) - loc[1] * sin( b ),
            loc[1] * cos( b ) + loc[0] * sin( b )
        );
    else -- point on center disc
        b := random() * 2 * pi();
        loc := point( r * cos( b ), r * sin( b ) );
    end if;
    loc := point( round( loc[0] ), round( loc[1] ) );
    continue when exists (
        select 1 from planet
        where circle( location, 1 ) <@ circle( loc, 2 * get_numeric_variable( 'MAX_SHIP_RANGE' ) )
    );
    insert into planet ( id, fuel, mine_limit, difficulty, location, location_x, location_y )
    values (
        nextval( 'planet_id_seq' ),
        greatest( ( random() * 1000000000 )::int, 100000000 ),
        greatest( ( random() * 100 )::int, 30 ),
        greatest( ( random() * 10 )::int , 2 ),
        loc, loc[0], loc[1]
    );
    -- exit planet when ( select count(1) from planet ) >= ( select count(1) * 1.05 from player );
    exit planet when ( select count(1) from planet ) = 2100;
end loop;

-- give names to new planets in non-repeating series
update planet
set name = ( case row_number % 12
    when 0 then 'Aethra'
    when 1 then 'Mony'
    when 2 then 'Semper'
    when 3 then 'Voit'
    when 4 then 'Lester'
    when 5 then 'Rio'
    when 6 then 'Zergon'
    when 7 then 'Cannibalon'
    when 8 then 'Omicron Persei'
    when 9 then 'Urectum'
    when 10 then 'Wormulon'
    when 11 then 'Kepler'
end ) || '_' || ( ( row_number / 12 ) + 1 )::text        
from (
    select row_number() over ( order by random() ) - 1 row_number, id
    from planet
    where id <> 1
    and name is null
)a
where planet.id = a.id;

	update planet set conqueror_id = null where planet.id = 1;
    -- for p in select player.id as id from player order by player.id loop
	for p in
        select player.id as id from player where id = any( array[ 1, 502, 14003, 28991 ] )
    loop
		update planet set conqueror_id = p.id, mine_limit = 30, fuel = 500000000, difficulty = 2 
			where planet.id = ( select id from planet where planet.id != 1 and conqueror_id is null order by random() limit 1 );
	end loop;
    for p in
        select player.id as id from player where id <> any( array[ 1, 502, 14003, 28991 ] ) limit 1600
    loop
		update planet set conqueror_id = p.id, mine_limit = 30, fuel = 500000000, difficulty = 2 
			where planet.id = ( select id from planet where planet.id != 1 and conqueror_id is null order by random() limit 1 );
	end loop;

	alter table event enable trigger all;
	alter table planet enable trigger all;
	alter table fleet enable trigger all;
	alter table planet_miners enable trigger all;
	alter table ship_flight_recorder enable trigger all;
	alter table ship_control enable trigger all;
	alter table ship enable trigger all;

	perform nextval( 'round_seq' );

	update variable set
        char_value = date_trunc( 'minutes', current_timestamp )::timestamp
        where name = upper( 'round_start_date' );

    for players in select * from player where id <> 0 loop
		insert into player_round_stats( player_id, round_id ) values ( players.id, ( select last_value from round_seq ) );
	end loop;
    insert into round_stats( round_id ) values( ( select last_value from round_seq ) );

    return 't';
end;
$body$
  language plpgsql volatile
  cost 100;

commit;
