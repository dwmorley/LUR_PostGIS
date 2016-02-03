-- TRAFMAJORLOAD
-- TRAFLOAD
-- HEAVYTRAFMAJORLOAD
-- HEAVYTRAFLOAD
-- ROADLENGTH
-- MAJORROADLENGTH
do $$
declare 
	recpt text := 'pem_addresses';
	roads text := 'routed_nor_bng'; --constant_nor_lur_bng, all_vehsum, allmv
	radii text[] = array['1000', '500', '300', '100', '50'];
	i text;
	sql text;
begin
	drop table if exists buffers;

	--Make buffers
	sql := 'create table buffers as	select ';
	foreach i in array radii
	loop 
		sql := sql || 'st_buffer(r.geom, ' || i || ') as b' || i || ',';
	end loop;
	sql := sql || 'r.gid from ' || recpt || ' as r';
	execute sql;

	--Perform intersections
	foreach i in array radii
	loop 
		raise notice '%', i;
		execute 'create index buf_indx_' || i || ' on buffers' || ' using gist (b' || i || ')';

		sql := '
		drop table if exists trafload' || i || ';
		create table trafload' || i || ' as
		select b.gid, coalesce(d.roadlength, 0) as roadlength, coalesce(d.heavytrafload, 0) as heavytrafload,
		coalesce(d.majorroadlength, 0) as majorroadlength, coalesce(d.heavytrafmajorload, 0) as heavytrafmajorload,
		coalesce(d.trafload, 0) as trafload, coalesce(d.trafmajorload, 0) as trafmajorload
		from buffers as b left join
		(with intsct as (
			select r.gid as road, b.gid, st_length(st_intersection(r.geom, b.b'|| i ||')) as length, r.allmv, 
			r.c3 as heavy
			from '|| roads ||' as r, buffers as b
			where st_intersects(r.geom, b.b'|| i ||')
		)
		select RLN.gid, coalesce(RLN.roadlength, 0) as roadlength, coalesce(RLN.heavytrafload, 0) as heavytrafload, 
		coalesce(MRLN.majorroadlength, 0) as majorroadlength, coalesce(MRLN.heavytrafmajorload, 0) as heavytrafmajorload,
		coalesce(RLN.trafload, 0) as trafload, coalesce(MRLN.trafmajorload, 0) as trafmajorload
		from 
			(select intsct.gid, sum(intsct.length) as roadlength, sum(intsct.length * intsct.heavy) as heavytrafload,
			sum(intsct.length * intsct.allmv) as trafload
			from intsct 
			group by intsct.gid
			) as RLN
		left join
			--TODO: MajorRoads on FRC or all_mv > 5000?
			(select intsct.gid, sum(intsct.length) as majorroadlength, sum(intsct.length * intsct.heavy) as heavytrafmajorload,
			sum(intsct.length * intsct.allmv) as trafmajorload
			from intsct 
			where allmv > 5000
			group by intsct.gid
			) as MRLN 
		on RLN.gid = MRLN.gid) as d on b.gid = d.gid';
		execute sql;
	end loop;
end;
$$language plpgsql;