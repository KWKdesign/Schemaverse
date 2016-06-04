-- Deploy view-player_list

BEGIN;

CREATE OR REPLACE VIEW player_list AS 
 SELECT player.id, player.username, player.created, player.symbol, player.rgb
   FROM player;

COMMIT;
