do $$
declare 
	recpt text := 'pem_addresses';
	popn text := 'pc01hc';
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
		drop table if exists popn' || i || ';
		create table popn' || i || ' as
		select b.gid, coalesce(sum(p.households), 0) as hhold, coalesce(sum(p.population), 0) as popeea 
		from buffers as b left join ' || popn || ' as p
		on st_contains(b.b'|| i ||', p.geom) 
		group by b.gid';		
		execute sql;
	end loop;
end;
$$language plpgsql;



