-- Deploy view-leader_board
-- requires: table-player
-- requires: table-player_round_stats
-- requires: sequence-round_seq

BEGIN;

CREATE OR REPLACE VIEW leader_board AS 
SELECT player.id, player.username,
player.balance + player.fuel_reserve AS networth,
player_round_stats.ships_built - player_round_stats.ships_lost AS ships,
player_round_stats.planets_conquered - player_round_stats.planets_lost AS planets,
player.symbol, player.rgb
FROM player, player_round_stats
WHERE player.id <> 0 AND player.id = player_round_stats.player_id AND player_round_stats.round_id = (( SELECT round_seq.last_value
FROM round_seq))
ORDER BY player_round_stats.planets_conquered - player_round_stats.planets_lost DESC, player_round_stats.ships_built - player_round_stats.ships_lost DESC, player.balance + player.fuel_reserve DESC
LIMIT 10;

COMMIT;
