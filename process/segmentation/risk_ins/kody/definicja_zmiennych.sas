/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */


%let zb=abt.train;

/*definicja zmiennych*/
proc sql noprint;
	create table wyj.zmienne_definicja as
	select 
			name as zmienna, 
			'int' as typ, 
			'y' as wer
	from dictionary.columns 
	where
		libname=upcase("%scan(&zb,1,.)") 
		and memname=upcase("%scan(&zb,2,.)")
		and 
		(
		    upcase(name) like 'AGR%'
		 or upcase(name) like 'ACT%'
		 or upcase(name) like 'AGS%'
		 or upcase(name) like 'APP%')
		and  type='num'
		; 
quit; 

proc sql noprint;
	create table nom as
	select 
		name as zmienna, 
		'nom' as typ, 
		'y' as wer
	from dictionary.columns 
	where
		libname=upcase("%scan(&zb,1,.)") 
		and memname=upcase("%scan(&zb,2,.)")
		and (upcase(name) like 'APP%' 
		  or upcase(name) like 'AGR%'
		  or upcase(name) like 'AGS%'
		  or upcase(name) like 'ACT%')
		and  type='char'; 

	select zmienna 
	into :zm separated by ' '
	from nom;
quit; 
%let il=&sqlobs;
%put &il***&zm;

%macro licz;
	data uni;
		length zmienna $32 il 8;
		delete;
	run;

	%do i=1 %to &il;
		%let z=%scan(&zm,&i,%str( ));
		proc sql;
			insert into uni
			select "&z" as zmienna, count(distinct &z) as il
			from &zb;
		quit;
	%end;
%mend;
%licz;

proc sql;
	insert into wyj.zmienne_definicja 
	select 
		zmienna, 
		'nom' as typ, 
		'y' as wer
	from uni 
/*	where il>=2*/
	where il<=200 and il>=2
	;
quit;

proc sort data=wyj.zmienne_definicja;
by zmienna;
run;
