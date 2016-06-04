-- Deploy trigger-update_planet
-- requires: table-planet

begin;

create or replace function update_planet()
  returns trigger as
$body$
begin
	if new.conqueror_id != old.conqueror_id then
		insert into event( action, player_id_1, player_id_2, referencing_id, location, public, tic )
			values( 'CONQUER', new.conqueror_id, old.conqueror_id, new.id , new.location, 't',( select last_value from tic_seq ) );
	end if;
	return new;	
end
$body$
  language plpgsql volatile security definer
  cost 100;

create trigger update_planet
  after update
  on planet
  for each row
  execute procedure update_planet();

commit;
