-- Deploy function-get_player_symbol
-- requires: table-player

BEGIN;

CREATE OR REPLACE FUNCTION GET_PLAYER_SYMBOL(check_username name) RETURNS character(1) AS $get_player_symbol$
	SELECT symbol FROM public.player WHERE username=$1;
$get_player_symbol$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION GET_PLAYER_SYMBOL(check_player_id integer) RETURNS character(1) AS $get_player_symbol$
	SELECT symbol FROM public.player WHERE id=$1;
$get_player_symbol$ LANGUAGE sql STABLE SECURITY DEFINER;

COMMIT;
