SHELL = bash
# add TRANSITFEEDS api integration

DATABASE = 
PSQLFLAGS =
PSQL = psql $(DATABASE) $(PSQLFLAGS)

.PHONY: all load vacuum init drop_constraints add_constraints

all:

drop_constraints:
	$(PSQL) -f sql/drop_constraints.sql

add_constraints:
	$(PSQL) -f sql/constraints.sql

load: $(GTFS)
	$(SHELL) load.sh $(GTFS) $(DATABASE) $(PSQLFLAGS)
	$(PSQL) -f sql/shape_geoms.sql

vacuum: ; $(PSQL) -c "VACUUM ANALYZE"

init: sql/schema.sql
	-createdb $(DATABASE) && $(PSQL) -c "CREATE EXTENSION postgis"
	$(PSQL) -f $<
	$(PSQL) -c "\copy gtfs_route_types FROM 'data/route_types.txt'"
	$(PSQL) -f sql/constraints.sql
