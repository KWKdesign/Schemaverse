-- deploy function-refuel_ship
-- requires: table-ship

begin;


create or replace function refuel_ship(ship_id integer)
  returns integer as
$body$
declare
	current_fuel_reserve bigint;
	new_fuel_reserve bigint;
	
	current_ship_fuel bigint;
	new_ship_fuel bigint;
	
	max_ship_fuel bigint;
begin
	set search_path to public;

	select fuel_reserve into current_fuel_reserve from player where username=session_user;
	select current_fuel, max_fuel into current_ship_fuel, max_ship_fuel from ship where id=ship_id;

	
	new_fuel_reserve = current_fuel_reserve - ( max_ship_fuel - current_ship_fuel );
	if new_fuel_reserve < 0 then
		new_ship_fuel = max_ship_fuel - ( @new_fuel_reserve );
		new_fuel_reserve = 0;
	else
		new_ship_fuel = max_ship_fuel;
	end if;
	
	update ship set current_fuel = new_ship_fuel where id = ship_id;
	update player set fuel_reserve = new_fuel_reserve where username = session_user;

	insert into event( action, player_id_1, ship_id_1, descriptor_numeric, public, tic )
    values( 'REFUEL_SHIP', get_player_id( session_user ), ship_id , new_ship_fuel, 'f', ( select last_value from tic_seq ) );

	return new_ship_fuel;
end
$body$
  language plpgsql volatile security definer
  cost 100;

commit;
