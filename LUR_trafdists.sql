-- TRAFNEAR
-- DISTINVNEAR1
-- INTINVDIST
-- TRAFMAJOR
-- DISTINVMAJOR1
-- INTMAJORINVDIST
-- HEAVYTRAFNEAR
-- HEAVYINTINVDIST
-- HEAVYTRAFMAJOR

--http://gis.stackexchange.com/questions/14456/finding-the-closest-geometry-in-postgis (modified)
create or replace function  nnid(nearto geometry, initialdistance real, distancemultiplier real, 
maxpower integer, nearthings text, nearthingsidfield text, nearthingsgeometryfield  text, roadtype text)
returns integer as $$
declare 
  sql text;
  result integer;
begin
  sql := ' select ' || quote_ident(nearthingsidfield) 
      || ' from '   || quote_ident(nearthings)
      || ' where '  || quote_ident(nearthings) || roadtype
      || ' and st_dwithin($1, ' 
      ||   quote_ident(nearthingsgeometryfield) || ', $2 * ($3 ^ $4))'
      || ' order by st_distance($1, ' || quote_ident(nearthingsgeometryfield) || ')'
      || ' limit 1';
  for i in 0..maxpower loop
     execute sql into result using nearto             -- $1
                                , initialdistance     -- $2
                                , distancemultiplier  -- $3
                                , i;                  -- $4
     if result is not null then return result; end if;
  end loop;
  return null;
end
$$ language 'plpgsql' stable;


do $$
declare 
	recpt text := 'pem_addresses';
	roads text := 'routed_nor_bng'; --constant_nor_lur_bng_dists, all_vehsum, allmv
	sql text;
begin
	--find nearest neighbours
	sql := '
	drop table if exists trafdists;
	create table trafdists as 
	with nn as (
		select distinct r.gid, r.geom, 
		nnid(r.geom, 1000, 2, 100, '''|| roads ||''', ''gid'', ''geom'', ''.allmv >= 0'') as nn_all,
		nnid(r.geom, 1000, 2, 100, '''|| roads ||''', ''gid'', ''geom'', ''.allmv >= 5000'') as nn_maj
		from '|| recpt ||' as r
	)
	select DAR.gid, (1 / DAR.distnear) as distinvnear1, ((1 / DAR.distnear) * DAR.allmv) as intinvdist, DAR.allmv as trafnear,
	DAR.heavy as heavytrafnear, ((1 / DAR.distnear) * DAR.heavy) as heavyintinvdist,
	DMR.allmv as trafmajor, (1 / DMR.distnear) as distinvmajornear1, ((1 / DMR.distnear) * DMR.allmv) as intmajorinvdist,
	DMR.heavy as heavytrafmajor
	from
		(select nn.gid, st_distance(nn.geom, t.geom) as distnear, t.allmv, t.c3 as heavy
		from nn left join '|| roads ||' as t 
		on nn.nn_all = t.gid
		) as DAR
	left join
		(select nn.gid, st_distance(nn.geom, t.geom) as distnear, t.allmv, t.c3 as heavy
		from nn left join '|| roads ||' as t 
		on nn.nn_maj = t.gid
		) as DMR
	on DAR.gid = DMR.gid';
	execute sql;
end;
$$language plpgsql;