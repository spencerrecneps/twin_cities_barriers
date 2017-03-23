
--create 50' buffer around bikeways
update received.bikeways_rbtn
set geombuff = st_multi(st_buffer(geom, 50,'endcap=round'));
create index sidx_bkwysgeombuff on received.bikeways_rbtn using GIST (geombuff);
  Analyze received.bikeways_rbtn(geombuff);

drop table if exists generated.bikebuff_dissolve;
create table generated.bikebuff_dissolve (
  id serial primary key,
  gen_typ varchar(25),
  regstat varchar(50),
  trail_name varchar(100),
  geombuff geometry(multipolygon, 26915)
);

--dissolve bike buffers by type and status
insert into generated.bikebuff_dissolve (
  gen_typ,
  regstat,
  geombuff)

select
  gen_typ,
  regstat,
  ST_Multi(ST_Union(geombuff)) as geom
from received.bikeways_rbtn
group by gen_typ, regstat;


--dissolve only connected features
--insert into generated.bikebuff_dissolve (
  --gen_typ,
  --regstat,
  --geombuff)

--select
  --gen_typ,
  --regstat,
  --ST_CollectionExtract(
    --              ST_SetSRID(
      --                unnest(ST_ClusterIntersecting(geombuff)),
        --              26915
          --        ),
            --      3   --polygons
              --)
--from received.bikeways_rbtn
--group by gen_typ, regstat;

create index sidx_bkwysdissolve on generated.bikebuff_dissolve using GIST (geombuff);
  Analyze generated.bikebuff_dissolve(geombuff);

--create centerline of polygon
  DROP TABLE IF EXISTS generated.bikeways_simple_centerline;
  CREATE TABLE generated.bikeways_simple_centerline(
    id SERIAL PRIMARY KEY,
    geom geometry(multilinestring,26915),
    gen_typ varchar(25),
    regstat varchar(50)
  );

  insert into generated.bikeways_simple_centerline (
    geom,
    gen_typ,
    regstat)
  select st_approximatemedialaxis(geombuff)::geometry(multilinestring,26915)
      as geom,
      gen_typ,
      regstat
      from generated.bikebuff_dissolve;

create index sidx_bikeways_simple_centerline on generated.bikeways_simple_centerline using GIST (geom);
  analyze generated.bikeways_simple_centerline;
