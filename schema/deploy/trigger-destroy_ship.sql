-- Deploy trigger-destroy_ship
-- requires: table-ship

begin;

create or replace function destroy_ship()
  returns trigger as
$body$
begin
	if ( not old.destroyed = new.destroyed ) and new.destroyed = 't' then
        update player set balance = balance + ( select cost from price_list where code = 'ship' ) where id = old.player_id;
		
		delete from ships_near_planets where ship = new.id;
	   	delete from ships_near_ships where first_ship = new.id;
	   	delete from ships_near_ships where second_ship = new.id;

		insert into event(action, player_id_1, ship_id_1, location, public, tic)
        values( 'explode', new.player_id, new.id, new.location, 't', ( select last_value from tic_seq ) );

	end if;
	return null;
end $body$ language plpgsql volatile security definer
cost 100;


create trigger destroy_ship
  after update
  on ship
  for each row
  execute procedure destroy_ship();

commit;
