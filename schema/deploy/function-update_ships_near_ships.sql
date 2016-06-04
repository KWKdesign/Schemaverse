-- Deploy function-update_ships_near_ships
-- requires: table-ships_near_ships
-- requires: table-planet
-- requires: table-ship
-- requires: sequence-tic_seq

BEGIN;

CREATE FUNCTION update_ships_near_ships() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
declare
        new record;
        current_tic integer;
begin
        SELECT last_value INTO current_tic FROM tic_seq;

        CREATE TEMPORARY TABLE sns (
                first_ship integer,
                player_id integer,
                second_ship integer,
                location_first point,
                location_second point,
                distance double precision
        );
        
        FOR NEW IN SELECT id, range, location, player_id FROM ship
                WHERE last_move_tic between current_tic-5 and current_tic
                LOOP

                delete from ships_near_ships where NEW.id IN (first_ship, second_ship);
                delete from sns where NEW.id IN (first_ship, second_ship);
                
         insert into sns (first_ship, player_id, second_ship, location_first, location_second, distance)
         select NEW.id, NEW.player_id, s2.id, NEW.location, s2.location, NEW.location <-> s2.location
              from ship s2
              where s2.id <> NEW.id AND s2.player_id <> NEW.player_id and CIRCLE(NEW.location,NEW.range) @> CIRCLE(s2.location,1) ;
         insert into sns (first_ship, player_id, second_ship, location_first, location_second, distance)
         select s1.id, s1.player_id, NEW.id, s1.location, NEW.location, NEW.location <-> s1.location
              from ship s1
              where s1.id <> NEW.id and s1.player_id <> NEW.player_id and CIRCLE(s1.location,s1.range) @> CIRCLE(NEW.location,1);
        end LOOP;

        INSERT INTO ships_near_ships(first_ship, player_id, second_ship, location_first, location_second, distance) SELECT first_ship, player_id, second_ship, location_first, location_second, distance FROM sns;
        return 't';
end
$$;

COMMIT;
