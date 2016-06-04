-- Deploy function-attack
-- requires: table-ship
-- requires: function-in_range_ship

begin;


create or replace function attack ( attacker integer, enemy_ship integer )
  returns integer as $body$
declare
	damage integer;
	attack_rate integer;
	defense_rate integer;
	attacker_name character varying;
	attacker_player_id integer;
	enemy_name character varying;
	enemy_player_id integer;
	defense_efficiency numeric;
	loc point;
BEGIN
	set search_path to public;
	damage = 0;
	--check range
	if action_permission_check( attacker ) and in_range_ship( attacker, enemy_ship ) then

		defense_efficiency := get_numeric_variable( upper( 'defense_efficiency' ) )::numeric / 100;

		--FINE, I won't divide by zero
		select attack + 1, player_id, name, location into attack_rate, attacker_player_id, attacker_name, loc from ship where id = attacker;
		select defense + 1, player_id, name into defense_rate, enemy_player_id, enemy_name from ship where id = enemy_ship;

		damage := ( attack_rate * ( defense_efficiency / defense_rate + defense_efficiency ) )::integer;		
		update ship set future_health = future_health - damage where id = enemy_ship;
		update ship set last_action_tic = ( select last_value from tic_seq ) where id = attacker;

		insert into event( action, player_id_1,ship_id_1, player_id_2, ship_id_2, descriptor_numeric, location, public, tic )
        values( 'ATTACK', attacker_player_id, attacker, enemy_player_id, enemy_ship , damage, loc, 't', ( select last_value from tic_seq ) );
	else 
        execute 'notify ' || get_player_error_channel() ||', ''Attack from ' || attacker || ' to '|| enemy_ship ||' failed'';';
	end if;	

	return damage;
end
$body$
  language plpgsql volatile security definer
  cost 100;

commit;
