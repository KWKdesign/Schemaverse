-- The Schemaverse 
-- Trophy Creation Script
-- Created by Josh McDougall
--
-- Trophy Goal: Most Damage Done

INSERT INTO trophy (name, description, weight, run_order, script_declarations, script ) 
VALUES(

-- Trophy Common Name
'The Space Jerk' ,

-- Trophy Description
'You might get picked on after winning this trophy. This goes to the player who dealt the most damage throughout the round.'::TEXT,

-- Weight
-- This is the amount of points the trophy is worth. Can be any value between -32768 to +32767
100,

-- Run Order
-- This is the order the trophy will be calculated in (In ascending order). 
-- Unless the trophy relies on the amount of other trophies won, this should likely be 0
0, 

-- Trophy Script Definition
-- DECLARE
'
players RECORD; 
winning_total bigint;
',
--BEGIN
'
winning_total := 0;

FOR players IN 
	SELECT 
		player_id, 
		damage_done as total
	FROM 
		player_round_stats 
	WHERE 
		round_id=_round_id
	ORDER BY total DESC 
LOOP
	IF winning_total = 0 OR winning_total = players.total THEN
		winning_total := players.total; 
		winner.round  := _round_id; 
		winner.trophy_id := this_trophy_id; 
		winner.player_id := players.player_id; 
		RETURN NEXT winner;
	ELSE
		RETURN;
	END IF;
END LOOP;
'
);

