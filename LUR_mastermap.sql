do $$
declare 
	recpt text := 'pem_addresses'; 
	mm text := 'nr_mastermap';
	radii text[] = array['5000', '1000', '500', '300', '100'];
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
		drop table if exists temp' || i || ';
		create table temp' || i || ' as
		with intsct as (
			select b.gid, c.legend, sum(st_area(st_intersection(c.geom, b.b'|| i ||'))) as area
			from '|| mm ||' as c, buffers as b
			where st_intersects(c.geom, b.b'|| i ||')
			group by b.gid, c.legend
		)
		select RDS.gid, coalesce(RDS.RoadSurface, 0) as roadsurface, 
		coalesce(MMS.Manmadesurface, 0) as manmadesurface,
		coalesce(BLD.Buildings, 0) as buildings,
		coalesce(WAT.Water, 0) as water,
		coalesce(WDL.Woodland, 0) as woodland,
		GRD.Garden as garden,
		coalesce(NAT.NaturalOpen, 0) as naturalopen
		from 
			(select b.gid, sum(intsct.area) as RoadSurface
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.legend = ''0000 Road''
			or intsct.legend = ''0000 Road traffic calming''
			group by b.gid
			) as RDS
		left join 
			(select b.gid, sum(intsct.area) as Manmadesurface
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.legend = ''0000 Manmade surface or step''
			or intsct.legend = ''0000 Path''
			or intsct.legend = ''0000 Railway''
			or intsct.legend = ''0000 Road''
			or intsct.legend = ''0000 Road traffic calming''
			or intsct.legend = ''0000 Track''
			group by b.gid
			) as MMS
		on RDS.gid = MMS.gid
		left join 
			(select b.gid, sum(intsct.area) as Buildings
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.legend = ''0000 Structure''
			or intsct.legend = ''0321 Building''
			or intsct.legend = ''0323 Glasshouse''
			or intsct.legend = ''0321 Archway''
			or intsct.legend = ''0395 Upper level communication''
			group by b.gid			
			) as BLD
		on RDS.gid = BLD.gid
		left join 
			(select b.gid, sum(intsct.area) as Water
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.legend = ''0000 Tidal water''
			or intsct.legend = ''0400 Inland water''
			group by b.gid			
			) as WAT
		on RDS.gid = WAT.gid
		left join 
			(select b.gid, sum(intsct.area) as Woodland
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.legend = ''0379 Coniferous trees''
			or intsct.legend = ''0380 Coniferous - scattered''
			or intsct.legend = ''0381 Coppice or osiers''
			or intsct.legend = ''0384 Nonconiferous trees''
			or intsct.legend = ''0385 Nonconiferous - scattered''
			or intsct.legend = ''0386 Orchard''								
			group by b.gid			
			) as WDL
		on RDS.gid = WDL.gid
		left join 
			(select b.gid, coalesce(intsct.area, 0) as Garden
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			and intsct.legend = ''0000 Multiple surface (garden)''
			group by b.gid, intsct.area			
			) as GRD
		on RDS.gid = GRD.gid
		left join 
			(select b.gid, sum(intsct.area) as NaturalOpen
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.legend = ''0000 Natural surface''
			or intsct.legend = ''0000 Foreshore''
			or intsct.legend = ''0382 Marsh reeds or saltmarsh''
			or intsct.legend = ''0387 Heath''
			or intsct.legend = ''0390 Rough grassland''
			or intsct.legend = ''0392 Scrub''								
			group by b.gid			
			) as NAT
		on RDS.gid = NAT.gid';
		execute sql;

		sql := '
		drop table if exists mastermap' || i || ';
		create table mastermap' || i || ' as
		select *, (water + woodland + garden + naturalopen) as greenspace,
		(manmadesurface + buildings + roadsurface) as concrete
		from temp' || i;
		execute sql;

		sql := 'drop table if exists temp' || i;
		execute sql;

	end loop;
end;
$$language plpgsql;