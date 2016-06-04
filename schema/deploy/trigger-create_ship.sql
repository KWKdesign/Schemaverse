-- Deploy trigger-create_ship
-- requires: table-ship

begin;


create or replace function create_ship()
  returns trigger as $body$
begin
	-- check ship stats
	new.current_health = 100; 
	new.max_health = 100;
	new.current_fuel = 100; 
	new.max_fuel = 100;
	new.max_speed = 1000;

	IF ((SELECT COUNT(*) FROM ship WHERE player_id=NEW.player_id AND NOT destroyed) > 2000 ) THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''A player can only have 2000 ships in their fleet for this round'';';
		RETURN NULL;
	END IF; 

	IF (LEAST(NEW.attack, NEW.defense, NEW.engineering, NEW.prospecting) < 0 ) THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''When creating a new ship, Attack Defense Engineering and Prospecting cannot be values lower than zero'';';
		RETURN NULL;
	END IF; 

	IF (NEW.attack + NEW.defense + NEW.engineering + NEW.prospecting) > 20 THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''When creating a new ship, the following must be true (Attack + Defense + Engineering + Prospecting) > 20'';';
		RETURN NULL;
	END IF; 

	
	--Backwards compatibility
	IF NEW.location IS NULL THEN
		NEW.location := POINT(NEW.location_x, NEW.location_y);
	ELSE
		NEW.location_x := NEW.location[0];
		NEW.location_y := NEW.location[1];
	END IF;
	
	IF not exists (select 1 from planets p where p.location ~= NEW.location and p.conqueror_id = NEW.player_id) then
		SELECT location INTO NEW.location from planets where conqueror_id=NEW.player_id limit 1;
		NEW.location_x := NEW.location[0];
		NEW.location_y := NEW.location[1];
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''New ship MUST be created on a planet your player has conquered'';';
		--RETURN NULL;
	END IF;

	IF NEW.location is null THEN
		EXECUTE 'NOTIFY ' || get_player_error_channel() ||', ''Lost all your planets. Unable to create new ships.'';';
		return null;
	end if;
	--charge account	
	if not charge( 'ship', 1 ) then 
		perform pg_notify( get_player_error_channel(), 'Not enough funds to purchase ship' );
        -- execute 'notify ' || get_player_error_channel() ||', ''Not enough funds to purchase ship'';';
		return null;
	end if;

	new.last_move_tic := ( select last_value from tic_seq ); 


	return new; 
end $body$ language plpgsql volatile security definer cost 100;

create trigger create_ship before insert on ship
  for each row execute procedure create_ship(); 

commit;
