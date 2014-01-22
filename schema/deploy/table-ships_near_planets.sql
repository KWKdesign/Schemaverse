-- Deploy table-ships_near_planets
-- requires: table-planet
-- requires: table-ship

BEGIN;

create unlogged table ships_near_planets (
       ship integer references ship(id) on delete cascade,
        player_id integer references player(id) on delete cascade,
       planet integer references planet(id) on delete cascade,
       primary key (ship,planet),
       ship_location point,
       planet_location point,
       distance float
);
create index snp_ship on ships_near_planets (ship);
create index snp_planet on ships_near_planets (planet);
create index snp_distance on ships_near_planets (distance);
--create index snp_loc1 on ships_near_planets using GIST (ship_location);
--create index snp_loc2 on ships_near_planets using GIST (planet_location);

COMMIT;
