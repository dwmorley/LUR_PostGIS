do $$
declare 
	recpt text := 'pem_addresses';
	corine text := 'clc06_100m_v16_gb5k';
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
		drop table if exists corine' || i || ';
		create table corine' || i || ' as
		with intsct as (
			select b.gid, c.code_06, sum(st_area(st_intersection(c.geom, b.b'|| i ||'))) as area
			from '|| corine ||' as c, buffers as b
			where st_intersects(c.geom, b.b'|| i ||')
			group by b.gid, c.code_06
		)
		select IND.gid, IND.Industry, PRT.Port, coalesce(UGR.Urbgreen, 0) as Urbgreen, 
		coalesce(NAT.Natural, 0) as Natural, AIR.Airport, LDR.Ldres, HDR.Hdres
		from 
			(select b.gid, coalesce(intsct.area, 0) as Industry
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			and intsct.code_06 = ''121''
			group by b.gid, intsct.area
			) as IND
		left join 
			(select b.gid, coalesce(intsct.area, 0) as Port
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			and intsct.code_06 = ''123''
			group by b.gid, intsct.area
			) as PRT
		on IND.gid = PRT.gid
		left join
			(select b.gid, sum(intsct.area) as Urbgreen
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			where intsct.code_06 = ''141'' or intsct.code_06 = ''142''
			group by b.gid
			) as UGR		
		on IND.gid = UGR.gid
		left join 
			(select b.gid, coalesce(intsct.area, 0) as Airport
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			and intsct.code_06 = ''124''
			group by b.gid, intsct.area
			) as AIR
		on IND.gid = AIR.gid	
		left join 
			(select b.gid, coalesce(intsct.area, 0) as Ldres
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			and intsct.code_06 = ''112''
			group by b.gid, intsct.area
			) as LDR
		on IND.gid = LDR.gid	
		left join 
			(select b.gid, coalesce(intsct.area, 0) as Hdres
			from buffers as b left join intsct 
			on b.gid = intsct.gid 
			and intsct.code_06 = ''111''
			group by b.gid, intsct.area
			) as HDR
		on IND.gid = HDR.gid	
		left join
			(select b.gid, sum(intsct.area) as Natural
			from buffers as b left join intsct
			on b.gid = intsct.gid 
			where intsct.code_06 = ''311'' or intsct.code_06 = ''312'' or intsct.code_06 = ''313'' or intsct.code_06 = ''321''
			or intsct.code_06 = ''322'' or intsct.code_06 = ''323'' or intsct.code_06 = ''324'' or intsct.code_06 = ''331''  
			or intsct.code_06 = ''332'' or intsct.code_06 = ''333'' or intsct.code_06 = ''334'' or intsct.code_06 = ''335'' 
			or intsct.code_06 = ''441'' or intsct.code_06 = ''412'' or intsct.code_06 = ''421'' or intsct.code_06 = ''422'' 
			or intsct.code_06 = ''423'' or intsct.code_06 = ''512'' or intsct.code_06 = ''521'' or intsct.code_06 = ''522'' 
			or intsct.code_06 = ''523''
			group by b.gid) as NAT
		on IND.gid = NAT.gid';
		execute sql;
	end loop;
end;
$$language plpgsql;



