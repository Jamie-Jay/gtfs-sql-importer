DROP TABLE IF EXISTS gtfs_agency cascade;
DROP TABLE IF EXISTS gtfs_stops cascade;
DROP TABLE IF EXISTS gtfs_routes cascade;
DROP TABLE IF EXISTS gtfs_calendar cascade;
DROP TABLE IF EXISTS gtfs_calendar_dates cascade;
DROP TABLE IF EXISTS gtfs_fare_attributes cascade;
DROP TABLE IF EXISTS gtfs_fare_rules cascade;
DROP TABLE IF EXISTS gtfs_shapes cascade;
DROP TABLE IF EXISTS gtfs_trips cascade;
DROP TABLE IF EXISTS gtfs_stop_times cascade;
DROP TABLE IF EXISTS gtfs_frequencies cascade;
DROP TABLE IF EXISTS gtfs_shape_geoms CASCADE;
DROP TABLE IF EXISTS gtfs_transfers cascade;
DROP TABLE IF EXISTS gtfs_feed_info cascade;
DROP TABLE IF EXISTS gtfs_route_types cascade;
DROP TABLE IF EXISTS gtfs_pickup_dropoff_types cascade;
DROP TABLE IF EXISTS gtfs_payment_methods cascade;
DROP TABLE IF EXISTS gtfs_location_types cascade;
DROP TABLE IF EXISTS gtfs_wheelchair_boardings cascade;
DROP TABLE IF EXISTS gtfs_wheelchair_accessible cascade;
DROP TABLE IF EXISTS gtfs_transfer_types cascade;
DROP TABLE IF EXISTS service_combinations CASCADE;
DROP TABLE IF EXISTS service_combo_ids CASCADE;
DROP TABLE IF EXISTS gtfs_stop_distances_along_shape;

BEGIN;

CREATE TABLE gtfs_feed_info (
  feed_index serial PRIMARY KEY, -- tracks uploads, avoids key collisions
  feed_publisher_name text,
  feed_publisher_url text,
  feed_timezone text,
  feed_lang text,
  feed_version text,
  feed_start_date date,
  feed_end_date date,
  feed_download_date date,
  feed_file text
);

CREATE TABLE gtfs_agency (
  feed_index integer REFERENCES gtfs_feed_info (feed_index),
  agency_id text,
  agency_name text,
  agency_url text,
  agency_timezone text,
  -- optional
  agency_lang text,
  agency_phone text,
  agency_fare_url text,
  agency_email text,
  CONSTRAINT gtfs_agency_pkey PRIMARY KEY (feed_index, agency_id)
);

--related to gtfs_stops(wheelchair_accessible)
CREATE TABLE gtfs_wheelchair_accessible (
  wheelchair_accessible int PRIMARY KEY,
  description text
);

--related to gtfs_stops(wheelchair_boarding)
CREATE TABLE gtfs_wheelchair_boardings (
  wheelchair_boarding int PRIMARY KEY,
  description text
);

CREATE TABLE gtfs_pickup_dropoff_types (
  type_id int PRIMARY KEY,
  description text
);

-- The following two tables are not in the spec, but they make dealing with dates and services easier
CREATE TABLE service_combo_ids (
  combination_id serial PRIMARY KEY
);

CREATE TABLE gtfs_transfer_types (
  transfer_type int PRIMARY KEY,
  description text
);

--related to gtfs_stops(location_type)
CREATE TABLE gtfs_location_types (
  location_type int PRIMARY KEY,
  description text
);

-- related to gtfs_stop_times(timepoint)
CREATE TABLE gtfs_timepoints (
  timepoint int PRIMARY KEY,
  description text
);

CREATE TABLE gtfs_calendar (
  feed_index integer not null,
  service_id text,
  monday int NOT NULL,
  tuesday int NOT NULL,
  wednesday int NOT NULL,
  thursday int NOT NULL,
  friday int NOT NULL,
  saturday int NOT NULL,
  sunday int NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  CONSTRAINT gtfs_calendar_pkey PRIMARY KEY (feed_index, service_id),
  CONSTRAINT gtfs_calendar_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);
CREATE INDEX gtfs_calendar_service_id ON gtfs_calendar (service_id);

CREATE TABLE gtfs_service_combinations (
  feed_index int NOT NULL,
  combination_id int REFERENCES service_combo_ids (combination_id),
  service_id text,
  -- CONSTRAINT service_combinations_service_fkey FOREIGN KEY (feed_index, service_id)
  --  REFERENCES gtfs_calendar (feed_index, service_id)
  CONSTRAINT gtfs_service_combo_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

CREATE TABLE gtfs_stops (
  feed_index int NOT NULL,
  stop_id text,
  stop_name text NOT NULL,
  stop_desc text,
  stop_lat double precision,
  stop_lon double precision,
  zone_id text,
  stop_url text,
  stop_code text,
  stop_street text,
  stop_city text,
  stop_region text,
  stop_postcode text,
  stop_country text,
  stop_timezone text,
  location_type integer REFERENCES gtfs_location_types (location_type),
  direction text,
  position text,
  parent_station text,
  wheelchair_boarding integer REFERENCES gtfs_wheelchair_boardings (wheelchair_boarding),
  wheelchair_accessible integer REFERENCES gtfs_wheelchair_accessible (wheelchair_accessible),
  CONSTRAINT gtfs_stops_pkey PRIMARY KEY (feed_index, stop_id)
);
SELECT AddGeometryColumn('gtfs_stops', 'the_geom', 4326, 'POINT', 2);

-- trigger the_geom update with lat or lon inserted
CREATE OR REPLACE FUNCTION gtfs_stop_geom_update() RETURNS TRIGGER AS $stop_geom$
  BEGIN
    NEW.the_geom = ST_SetSRID(ST_MakePoint(NEW.stop_lon, NEW.stop_lat), 4326);
    RETURN NEW;
  END;
$stop_geom$ LANGUAGE plpgsql;

CREATE TRIGGER gtfs_stop_geom_trigger BEFORE INSERT OR UPDATE ON gtfs_stops
    FOR EACH ROW EXECUTE PROCEDURE gtfs_stop_geom_update();

CREATE TABLE gtfs_route_types (
  route_type int PRIMARY KEY,
  description text
);

CREATE TABLE gtfs_routes (
  feed_index int NOT NULL,
  route_id text,
  agency_id text,
  route_short_name text DEFAULT '',
  route_long_name text DEFAULT '',
  route_desc text,
  route_type int REFERENCES gtfs_route_types(route_type),
  route_url text,
  route_color text,
  route_text_color text,
  route_sort_order integer,
  CONSTRAINT gtfs_routes_pkey PRIMARY KEY (feed_index, route_id),
  -- CONSTRAINT gtfs_routes_fkey FOREIGN KEY (feed_index, agency_id)
  --   REFERENCES gtfs_agency (feed_index, agency_id),
  CONSTRAINT gtfs_routes_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

CREATE TABLE gtfs_calendar_dates (
  feed_index int NOT NULL,
  service_id text,
  date date NOT NULL,
  exception_type int NOT NULL --,
  -- CONSTRAINT gtfs_calendar_fkey FOREIGN KEY (feed_index, service_id)
    -- REFERENCES gtfs_calendar (feed_index, service_id)
);

CREATE INDEX gtfs_calendar_dates_dateidx ON gtfs_calendar_dates (date);

CREATE TABLE gtfs_payment_methods (
  payment_method int PRIMARY KEY,
  description text
);

CREATE TABLE gtfs_fare_attributes (
  feed_index int NOT NULL,
  fare_id text,
  price double precision NOT NULL,
  currency_type text NOT NULL,
  payment_method int REFERENCES gtfs_payment_methods,
  transfers int,
  transfer_duration int,
  -- unofficial features
  agency_id text,
  CONSTRAINT gtfs_fare_attributes_pkey PRIMARY KEY (feed_index, fare_id),
  -- CONSTRAINT gtfs_fare_attributes_fkey FOREIGN KEY (feed_index, agency_id)
  -- REFERENCES gtfs_agency (feed_index, agency_id),
  CONSTRAINT gtfs_fare_attributes_fare_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

CREATE TABLE gtfs_fare_rules (
  feed_index int NOT NULL,
  fare_id text,
  route_id text,
  origin_id text,
  destination_id text,
  contains_id text,
  -- unofficial features
  service_id text,
  -- CONSTRAINT gtfs_fare_rules_service_fkey FOREIGN KEY (feed_index, service_id)
  -- REFERENCES gtfs_calendar (feed_index, service_id),
  -- CONSTRAINT gtfs_fare_rules_fare_id_fkey FOREIGN KEY (feed_index, fare_id)
  -- REFERENCES gtfs_fare_attributes (feed_index, fare_id),
  -- CONSTRAINT gtfs_fare_rules_route_id_fkey FOREIGN KEY (feed_index, route_id)
  -- REFERENCES gtfs_routes (feed_index, route_id),
  CONSTRAINT gtfs_fare_rules_service_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

CREATE TABLE gtfs_shapes (
  feed_index int NOT NULL,
  shape_id text NOT NULL,
  shape_pt_lat double precision NOT NULL,
  shape_pt_lon double precision NOT NULL,
  shape_pt_sequence int NOT NULL,
  -- optional
  shape_dist_traveled double precision
);

CREATE INDEX gtfs_shapes_shape_key ON gtfs_shapes (shape_id);

-- Create new table to store the shape geometries
CREATE TABLE gtfs_shape_geoms (
  feed_index int NOT NULL,
  shape_id text NOT NULL,
  CONSTRAINT gtfs_shape_geom_pkey PRIMARY KEY (feed_index, shape_id)
);
-- Add the_geom column to the gtfs_shape_geoms table - a 2D linestring geometry
SELECT AddGeometryColumn('gtfs_shape_geoms', 'the_geom', 4326, 'LINESTRING', 2);

CREATE TABLE gtfs_trips (
  feed_index int NOT NULL,
  route_id text,
  service_id text,
  trip_id text,
  trip_headsign text,
  direction_id int,
  block_id text,
  shape_id text,
  trip_short_name text,
  wheelchair_accessible int REFERENCES gtfs_wheelchair_accessible(wheelchair_accessible),

  -- unofficial features
  trip_type text,
  CONSTRAINT gtfs_trips_pkey PRIMARY KEY (feed_index, trip_id),
  -- CONSTRAINT gtfs_trips_route_id_fkey FOREIGN KEY (feed_index, route_id)
  -- REFERENCES gtfs_routes (feed_index, route_id),
  -- CONSTRAINT gtfs_trips_calendar_fkey FOREIGN KEY (feed_index, service_id)
  -- REFERENCES gtfs_calendar (feed_index, service_id),
  CONSTRAINT gtfs_trips_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

CREATE INDEX gtfs_trips_trip_id ON gtfs_trips (trip_id);
CREATE INDEX gtfs_trips_service_id ON gtfs_trips (feed_index, service_id);

CREATE TABLE gtfs_stop_times (
  feed_index int NOT NULL,
  trip_id text,
  -- Check that casting to time interval works.
  arrival_time interval CHECK (arrival_time::interval = arrival_time::interval),
  departure_time interval CHECK (departure_time::interval = departure_time::interval),
  stop_id text,
  stop_sequence int NOT NULL,
  stop_headsign text,
  pickup_type int REFERENCES gtfs_pickup_dropoff_types(type_id),
  drop_off_type int REFERENCES gtfs_pickup_dropoff_types(type_id),
  shape_dist_traveled double precision,
  timepoint int REFERENCES gtfs_timepoints (timepoint),

  -- unofficial features
  -- the following are not in the spec
  arrival_time_seconds int,
  departure_time_seconds int,
  CONSTRAINT gtfs_stop_times_pkey PRIMARY KEY (feed_index, trip_id, stop_sequence),
  -- CONSTRAINT gtfs_stop_times_trips_fkey FOREIGN KEY (feed_index, trip_id)
  -- REFERENCES gtfs_trips (feed_index, trip_id),
  -- CONSTRAINT gtfs_stop_times_stops_fkey FOREIGN KEY (feed_index, stop_id)
  -- REFERENCES gtfs_stops (feed_index, stop_id),
  CONSTRAINT gtfs_stop_times_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);
CREATE INDEX gtfs_stop_times_key ON gtfs_stop_times (trip_id, stop_id);
CREATE INDEX arr_time_index ON gtfs_stop_times (arrival_time_seconds);
CREATE INDEX dep_time_index ON gtfs_stop_times (departure_time_seconds);

CREATE TABLE gtfs_stop_distances_along_shape (
  feed_index integer NOT NULL,
  shape_id text,
  stop_id text,
  pct_along_shape numeric,
  dist_along_shape numeric
);
CREATE INDEX gtfs_stop_dist_along_shape_index ON gtfs_stop_distances_along_shape
  (feed_index, shape_id);

CREATE TABLE gtfs_frequencies (
  feed_index int NOT NULL,
  trip_id text,
  start_time text NOT NULL,
  end_time text NOT NULL,
  headway_secs int NOT NULL,
  exact_times int,
  start_time_seconds int,
  end_time_seconds int,
  CONSTRAINT gtfs_frequencies_pkey PRIMARY KEY (feed_index, trip_id, start_time),
  -- CONSTRAINT gtfs_frequencies_trip_fkey FOREIGN KEY (feed_index, trip_id)
  --  REFERENCES gtfs_trips (feed_index, trip_id),
  CONSTRAINT gtfs_frequencies_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

CREATE TABLE gtfs_transfers (
  feed_index int NOT NULL,
  from_stop_id text,
  to_stop_id text,
  transfer_type int REFERENCES gtfs_transfer_types(transfer_type),
  min_transfer_time int,
  -- Unofficial fields
  from_route_id text,
  to_route_id text,
  service_id text,
  -- CONSTRAINT gtfs_transfers_from_stop_fkey FOREIGN KEY (feed_index, from_stop_id)
  --  REFERENCES gtfs_stops (feed_index, stop_id),
  --CONSTRAINT gtfs_transfers_to_stop_fkey FOREIGN KEY (feed_index, to_stop_id)
  --  REFERENCES gtfs_stops (feed_index, stop_id),
  --CONSTRAINT gtfs_transfers_from_route_fkey FOREIGN KEY (feed_index, from_route_id)
  --  REFERENCES gtfs_routes (feed_index, route_id),
  --CONSTRAINT gtfs_transfers_to_route_fkey FOREIGN KEY (feed_index, to_route_id)
  --  REFERENCES gtfs_routes (feed_index, route_id),
  --CONSTRAINT gtfs_transfers_service_fkey FOREIGN KEY (feed_index, service_id)
  --  REFERENCES gtfs_calendar (feed_index, service_id),
  CONSTRAINT gtfs_transfers_feed_fkey FOREIGN KEY (feed_index)
    REFERENCES gtfs_feed_info (feed_index) ON DELETE CASCADE
);

insert into gtfs_transfer_types (transfer_type, description) VALUES
  (0,'Preferred transfer point'),
  (1,'Designated transfer point'),
  (2,'Transfer possible with min_transfer_time window'),
  (3,'Transfers forbidden');

insert into gtfs_location_types(location_type, description) values 
  (0,'stop'),
  (1,'station'),
  (2,'station entrance');

insert into gtfs_wheelchair_boardings(wheelchair_boarding, description) values
   (0, 'No accessibility information available for the stop'),
   (1, 'At least some vehicles at this stop can be boarded by a rider in a wheelchair'),
   (2, 'Wheelchair boarding is not possible at this stop');

insert into gtfs_wheelchair_accessible(wheelchair_accessible, description) values
  (0, 'No accessibility information available for this trip'),
  (1, 'The vehicle being used on this particular trip can accommodate at least one rider in a wheelchair'),
  (2, 'No riders in wheelchairs can be accommodated on this trip');

insert into gtfs_route_types (route_type, description) values
  (0, 'Street Level Rail'),
  (1, 'Underground Rail'),
  (2, 'Intercity Rail'),
  (3, 'Bus'),
  (4, 'Ferry'),
  (5, 'Cable Car'),
  (6, 'Suspended Car'),
  (7, 'Steep Incline Mode');

insert into gtfs_pickup_dropoff_types (type_id, description) values
  (0,'Regularly Scheduled'),
  (1,'Not available'),
  (2,'Phone arrangement only'),
  (3,'Driver arrangement only');

insert into gtfs_payment_methods (payment_method, description) values
  (0,'On Board'),
  (1,'Prepay');

insert into gtfs_timepoints (timepoint, description) values
  (0, 'Times are considered approximate'),
  (1, 'Times are considered exact');

COMMIT;