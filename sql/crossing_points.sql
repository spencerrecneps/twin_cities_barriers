
DROP TABLE IF EXISTS generated.railroads;

create table generated.railroads
  (id serial primary key,
  tdgid VARCHAR(36),
  osm_id int,
geom geometry (multilinestring, 26915),
geom_buffer geometry(multipolygon, 26915),
name VARCHAR (100),
tunnel int,
bridge int,
oneway int,
z_order int,
service varchar(50));

insert into generated.railroads(
id,
tdgid,
osm_id,
geom,
name,
tunnel,
bridge,
oneway,
z_order,
service
)

select id,
  tdgid,
  osm_id,
  geom,
  name,
  tunnel,
  bridge,
  oneway,
  z_order,
  service
from received.railroad_client_edits_20170630
where tunnel = 0 and bridge = 0;

--create spatial index on linestrings
create index sidx_rrgeom on generated.railroads uSING GIST (geom);
analyze generated.railroads;

--create buffer column and index it
update generated.railroads set geom_buffer = st_multi(st_buffer(geom,70,'endcap=flat'));
create index sidx_rrgeombuff on generated.railroads uSING GIST (geom_buffer);
analyze generated.railroads (geom_buffer);

ALTER TABLE generated.railroad_linedissolve ADD COLUMN barrier_type VARCHAR(30);
UPDATE generated.railroad_linedissolve
SET barrier_type = 'railroad'
;


    --create dissolved existing facilities layer (dissolve by fac type only where touching)
DROP TABLE IF EXISTS generated.railroad_dissolve;
CREATE TABLE generated.railroad_dissolve  (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    service VARCHAR(50),
    geom geometry(multilinestring,26915),
    geom_buffer geometry(multipolygon, 26915)
);

INSERT INTO generated.railroad_dissolve (geom)
SELECT      ST_CollectionExtract(
                ST_SetSRID(
                    unnest(ST_ClusterIntersecting(geom)),
                    26915
                ),
                2   --linestrings
            )
FROM        generated.railroads;

--create dissolved existing facilities layer (dissolve by fac type only where touching)
DROP TABLE IF EXISTS generated.railroad_linedissolve;
CREATE TABLE generated.railroad_linedissolve(
  id SERIAL PRIMARY KEY,
  geom geometry(multilinestring,26915)
);

insert into generated.railroad_linedissolve (geom)
select st_approximatemedialaxis(geom)::geometry(multilinestring,26915)
    as geom
    from scratch.railroad_dissolve;
