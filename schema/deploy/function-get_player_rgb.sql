-- Deploy function-get_player_rgb
-- requires: table-player

BEGIN;

CREATE OR REPLACE FUNCTION GET_PLAYER_RGB(check_username name) RETURNS character(6) AS $get_player_rgb$
	SELECT rgb FROM public.player WHERE username=$1;
$get_player_rgb$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION GET_PLAYER_RGB(check_player_id integer) RETURNS character(6) AS $get_player_rgb$
	SELECT rgb FROM public.player WHERE id=$1;
$get_player_rgb$ LANGUAGE sql STABLE SECURITY DEFINER;

COMMIT;
