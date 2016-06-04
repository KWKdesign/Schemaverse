-- Deploy function-repair
-- requires: table-ship
-- requires: function-in_range_ship

begin;


create or replace function repair( repair_ship integer, repaired_ship integer )
  returns integer as
$body$
declare
	repair_rate integer;
	repair_ship_name character varying;
	repair_ship_player_id integer;
	repaired_ship_name character varying;
	loc point;
begin
	set search_path to public;

	repair_rate = 0;


	--check range
	if action_permission_check( repair_ship ) and in_range_ship( repair_ship, repaired_ship ) then

		select engineering, player_id, name, location into repair_rate, repair_ship_player_id, repair_ship_name, loc from ship where id = repair_ship;
		select name into repaired_ship_name from ship where id = repaired_ship;
		update ship set future_health = future_health + repair_rate where id = repaired_ship;
		update ship set last_action_tic = ( select last_value from tic_seq ) where id = repair_ship;

		insert into event( action, player_id_1, ship_id_1, ship_id_2, descriptor_numeric, location, public, tic )
        values( 'REPAIR', repair_ship_player_id, repair_ship, repaired_ship, repair_rate,loc, 't', ( select last_value from tic_seq ) );

	else 
		 execute 'notify ' || get_player_error_channel() ||', ''Repair from ' || repair_ship || ' to '|| repaired_ship ||' failed'';';
	end if;	

	return repair_rate;
end
$body$
  language plpgsql volatile security definer
  cost 100;

commit;
