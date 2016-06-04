-- deploy function-charge
-- requires: table-player

begin;


create or replace function charge( price_code text, quantity bigint )
  returns boolean as $body$
declare 
	amount bigint;
	current_balance bigint;
begin
	set search_path to public;

	select cost into amount from price_list where code = upper( price_code );
	select balance into current_balance from player where username = session_user;
	if quantity < 0 or ( current_balance - ( amount * quantity ) ) < 0 then
		return 'f';
	else 
		update player set balance = ( balance - ( amount * quantity ) ) where username = session_user;
	end if;
	return 't'; 
end $body$ language plpgsql volatile security definer
cost 100;

commit;
