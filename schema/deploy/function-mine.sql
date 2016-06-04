-- Deploy function-mine
-- requires: table-ship
-- requires: table-planet
-- requires: function-in_range_planet

begin;


create or replace function mine(ship_id integer, planet_id integer)
    returns boolean as
$body$
begin
	set search_path to public;
	if action_permission_check( ship_id ) and in_range_planet( ship_id, planet_id ) then
		insert into planet_miners values( planet_id, ship_id );
		update ship set last_action_tic = ( select last_value from tic_seq ) where id = ship_id;
		return 't';
	else
		execute 'notify ' || get_player_error_channel() ||', ''Mining ' || planet_id || ' with ship '|| ship_id ||' failed'';';
		return 'f';
	end if;
end
$body$
language plpgsql volatile security definer
cost 100;

commit;
