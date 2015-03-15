#********************************************************************************************************
#* CREATION OF MOH 731 INDICATORS TABLE ****************************************************************************
#********************************************************************************************************

# Need to first create this temporary table to sort the data by person,encounterdateime. 
# This allows us to use the previous row's data when making calculations.
# It seems that if you don't create the temporary table first, the sort is applied 
# to the final result. Any references to the previous row will not an ordered row. 


drop table if exists derived_encounter_0;
create temporary table derived_encounter_0(index encounter_id (encounter_id), index person_enc (person_id,encounter_datetime))
(select *
	from amrs.encounter e
		join flat_new_person_data t0 on e.patient_id = t0.person_id
	where encounter_type in (1,2,3,4,10,13,14,15,17,19,22,23,26,43,47,21)
		and voided=0
	order by t0.person_id, e.encounter_datetime
);

select @prev_id := null;
select @cur_id := null;
select @prev_encounter_datetime := null;
select @cur_encounter_datetime := null;
select @next_encounter_type := null;
select @cur_encounter_type := null;

drop table if exists derived_encounter_1;
create temporary table derived_encounter_1(
	next_encounter_type int,
	next_encounter_datetime datetime,
	index encounter_id (encounter_id), 
	index person_enc (person_id,encounter_datetime))
(select
	*,
	@prev_id := @cur_id as prev_id,
	@cur_id := person_id as cur_id,

	case
		when @prev_id = @cur_id then @prev_encounter_datetime := @cur_encounter_datetime
		else @prev_encounter_datetime := null
	end as next_encounter_datetime,

	@cur_encounter_datetime := encounter_datetime as cur_encounter_datetime,

	case
		when @prev_id=@cur_id then @next_encounter_type := @cur_encounter_type
		else @next_encounter_type := null
	end as next_encounter_type,

	@cur_encounter_type := encounter_type as cur_encounter_type

	from derived_encounter_0
	order by person_id, encounter_datetime desc
);

alter table derived_encounter_1 drop prev_id, drop cur_id, drop cur_encounter_type, drop cur_encounter_datetime;

select @prev_id := null;
select @cur_id := null;
select @prev_encounter_type := null;
select @cur_encounter_type := null;

drop temporary table if exists derived_encounter_2;
create temporary table derived_encounter_2 (prev_encounter_datetime datetime, prev_encounter_type int, index person_enc (person_id, encounter_datetime desc))
(select 
	*,
	@prev_id := @cur_id as prev_id, 
	@cur_id := t1.patient_id as cur_id,

	case
        when @prev_id=@cur_id then @prev_encounter_type := @cur_encounter_type
        else @prev_encounter_type:=null
	end as prev_encounter_type,

	@cur_encounter_type := encounter_type as cur_encounter_type,

	case
        when @prev_id=@cur_id then @prev_encounter_datetime := @cur_encounter_datetime
        else @prev_encounter_datetime := null
	end as prev_encounter_datetime,
	@cur_encounter_datetime := encounter_datetime as cur_encounter_datetime

	from derived_encounter_1 t1
	order by person_id, encounter_datetime
);		
	

#drop table if exists derived_encounter;
create table if not exists derived_encounter(
	person_id int,
    encounter_id int,
	prev_encounter_datetime datetime,
	next_encounter_datetime datetime,
	prev_encounter_type int,
	next_encounter_type int,
    primary key encounter_id (encounter_id),
    index person_id (person_id)
);

delete t1
from derived_encounter t1
join flat_new_person_data t2 using (person_id);

insert into derived_encounter
(select 
	person_id,
    encounter_id,
	prev_encounter_datetime,
	next_encounter_datetime,
	prev_encounter_type,
	next_encounter_type
from derived_encounter_2
order by person_id, encounter_datetime);

/*
select t1.person_id, t1.prev_encounter_datetime, t2.encounter_datetime,t1.next_encounter_datetime, t1.prev_encounter_type, t2.encounter_type, t1.next_encounter_type#
	from derived_encounter t1
	join amrs.encounter t2 using (encounter_id)
	order by person_id, prev_encounter_datetime;
*/
