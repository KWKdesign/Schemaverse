-- Deploy view-player_stats

BEGIN;

CREATE OR REPLACE VIEW player_stats AS
 SELECT
        rs.player_id as player_id,
        GET_PLAYER_USERNAME(rs.player_id) as username,
        CASE WHEN (( SELECT count(online_players.id) AS count FROM online_players WHERE online_players.id = rs.player_id)) = 1 THEN true ELSE false END AS online,
        rs.damage_taken as round_damage_taken,
        coalesce(os.damage_taken,0)+rs.damage_taken as overall_damage_taken,
        rs.damage_done as round_damage_done,
        coalesce(os.damage_done,0)+rs.damage_done as overall_damamge_done,
        rs.planets_conquered as round_planets_conquered,
        coalesce(os.planets_conquered,0)+rs.planets_conquered as overall_planets_conquered,
        rs.planets_lost as round_planets_lost,
        coalesce(os.planets_lost,0)+rs.planets_lost as overall_planets_lost,
        rs.ships_built as round_ships_built,
        coalesce(os.ships_built,0)+rs.ships_built as overall_ships_built,
        rs.ships_lost as round_ships_lost,
        coalesce(os.ships_lost,0)+rs.ships_lost as overall_ships_lost,
        rs.ship_upgrades as round_ship_upgrades,
        coalesce(os.ship_upgrades,0)+rs.ship_upgrades as overall_ship_upgrades,
        rs.distance_travelled as round_distance_travelled,
        coalesce(os.distance_travelled,0)+rs.distance_travelled as overall_distance_travelled,
        rs.fuel_mined as round_fuel_mined,
        coalesce(os.fuel_mined,0)+rs.fuel_mined as overall_fuel_mined,
        coalesce(os.trophy_score,0) as overall_trophy_score,
        rs.last_updated as last_updated        
FROM
        player_round_stats rs, player_overall_stats os
WHERE
        rs.player_id=os.player_id
        and rs.round_id = (( SELECT round_seq.last_value FROM round_seq));

COMMIT;
