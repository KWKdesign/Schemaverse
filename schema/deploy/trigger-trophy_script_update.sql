-- Deploy trigger-trophy_script_update
-- requires: table-trophy
-- requires: type-trophy_winner

begin;


create or replace function trophy_script_update()
  returns trigger as
$body$
declare
    current_round integer;
	secret character varying;
	player_id integer;
begin

	player_id := get_player_id( session_user );

	if  session_user = 'schemaverse' then
        if new.approved = 't' and old.approved = 'f' then
            if new.round_started = 0 then
				select last_value into new.round_started from round_seq;
			end if;

            secret := 'trophy_script_' || (random()*1000000)::integer;
            execute 'create or replace function trophy_script_'|| new.id ||'(_round_id integer) returns setof trophy_winner as $'||secret||'$
            declare
            this_trophy_id integer;
            this_round integer; -- deprecated, use _round_id in your script instead
            winner trophy_winner%rowtype;
            ' || new.script_declarations || '
            begin
            this_trophy_id := '|| new.id||';
            select last_value into this_round from round_seq; 
            ' || new.script || '
            return;
            end $'||secret||'$ language plpgsql;'::text;

            execute 'revoke all on function trophy_script_'|| new.id ||'(integer) from public'::text;
            execute 'revoke all on function trophy_script_'|| new.id ||'(integer) from players'::text;
            execute 'grant execute on function trophy_script_'|| new.id ||'(integer) to schemaverse'::text;
		end if;
	elseif not player_id = old.creator then
		return old;
	else 
		if not old.approved = new.approved then
			new.approved = 'f';
		end if;

		if not ( ( new.script = old.script ) and ( new.script_declarations = old.script_declarations ) ) then
			new.approved = 'f';	         
	       end if;
	end if;

       return new;
end $body$ language plpgsql volatile
cost 100;

create trigger trophy_script_update
  before update
  on trophy
  for each row
  execute procedure trophy_script_update();
alter table trophy enable trigger trophy_script_update;

commit;
