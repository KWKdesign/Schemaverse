-- Deploy function-in_range_planet
-- requires: table-ship
-- requires: table-planet

begin;

create or replace function in_range_planet( ship_id integer, planet_id integer )
  returns boolean as
$body$
	set search_path to public;
	select exists (select 1 from planet p, ship s
	      where 1=1
		  and s.id = $1
          and p.id = $2
          and not s.destroyed
          and circle( s.location, s.range ) @> circle( p.location, 1 ) )
      ;
$body$
language sql volatile security definer
cost 100;

commit;
