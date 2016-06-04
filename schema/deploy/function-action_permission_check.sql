-- Deploy function-action_permission_check

begin;


create or replace function action_permission_check( ship_id integer )
  returns boolean as
$body$
declare 
	ships_player_id integer;
	lat integer;
	exploded boolean;
	ch integer;
begin
	set search_path to public;
	select player_id, last_action_tic, destroyed, current_health into ships_player_id, lat, exploded, ch from ship where id = ship_id;
	if ( 1=1
		and lat != ( select last_value from tic_seq )
		and exploded = 'f'
		and ch > 0 
	)
    and ( 1=0
        or ships_player_id = get_player_id( session_user ) 
        or ( ships_player_id > 0 and ( session_user = 'schemaverse' or current_user = 'schemaverse' ) )  
    )
	then	
		return 't';
	else 
		return 'f';
	end if;
end
$body$
  language plpgsql volatile security definer
  cost 100;

commit;
