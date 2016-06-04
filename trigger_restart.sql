update variable set char_value = date_trunc('minutes',now() - get_char_variable(upper('round_length'))::interval - '1 minute'::interval )
where name = upper('round_start_date');