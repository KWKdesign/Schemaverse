-- Deploy function-update_ships_near_planets
-- requires: table-ships_near_planets
-- requires: table-planet
-- requires: table-ship
-- requires: sequence-tic_seq

BEGIN;

CREATE OR REPLACE FUNCTION update_ships_near_planets()
  RETURNS boolean AS
$BODY$
declare
        new record;
        current_tic integer;
begin
        SELECT last_value INTO current_tic FROM tic_seq;
        
        FOR NEW IN SELECT id, range, location, player_id FROM ship
                WHERE last_move_tic between current_tic-5 and current_tic
                LOOP


         delete from ships_near_planets where ship = NEW.id;
         -- Record the 10 planets that are nearest to the specified ship
         insert into ships_near_planets (ship, player_id, planet, ship_location, planet_location, distance)
         select NEW.id, NEW.player_id, p.id, NEW.location, p.location, NEW.location <-> p.location
         from planets p
                where CIRCLE(NEW.location, NEW.range) <@ CIRCLE(p.location,100000)
         order by NEW.location <-> p.location desc limit 10;
     END LOOP;
        return 't';
end
$BODY$
  LANGUAGE plpgsql VOLATILE SECURITY DEFINER
  COST 100;

COMMIT;
