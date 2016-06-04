-- Deploy table-ships_near_ships
-- requires: function-ships_near_ships
-- requires: table-planet
-- requires: table-ship

BEGIN;

create unlogged table ships_near_ships (
       first_ship integer references ship(id) on delete cascade,
        player_id integer references player(id) on delete cascade,
       second_ship integer references ship(id) on delete cascade,
       primary key (first_ship, second_ship),
       location_first point,
       location_second point,
       distance float
);
create index sns_first on ships_near_ships (first_ship);
create index sns_second on ships_near_ships (second_ship);
create index sns_distance on ships_near_ships (distance);

--Cannot create GIST index on unlogged table
--create index sns_loc1 on ships_near_ships using GIST (location_first);
--create index sns_loc2 on ships_near_ships using GIST (location_second);

COMMIT;
