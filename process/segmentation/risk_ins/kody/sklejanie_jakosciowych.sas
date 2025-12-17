/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */



libname t (wyj);
%let kat=%sysfunc(pathname(wyj));
%put &kat;


proc sql noprint;
select upcase(zmienna) into :zm_do_sklejenia separated by ' '
from &em_data_variableset where typ in ('nom');
quit;
%let il_zm=&sqlobs;



%put ***&il_zm***&zm_do_sklejenia;



data _null_;
set &zb(obs=1) nobs=il;
min_il=int(&min_percent*il/100);
call symput('min_il',trim(put(min_il,best12.-L)));
run;
%put &min_il;
/*%let min_il=2000;*/

data t.podzialy_nom_sklejane;
length zmienna $32 war $300 grp 8;
delete;
run;



%macro sklejaj;
%do nr_zm=1 %to &il_zm;
%let zm=%upcase(%scan(&zm_do_sklejenia,&nr_zm,%str( )));
%put &zm;

proc means data=&zb nway noprint;
var &tar;
class &zm;
output out=br(where=(_freq_ > &min_il)) mean()=br;
run;

proc cluster data=br method=ward outtree=tr noprint;  
id &zm; 
run; 

proc tree noprint data=tr out=podz nclusters=&max_il_podz; 
id &zm; 
run;

proc sql noprint;
select max(CLUSTER) into :il_podz from podz;
quit;
%put &il_podz;

%macro koduj;
%put &zb***&zm;
proc sql noprint;
select upcase(type) into :typ from dictionary.columns where
upcase(libname)="%upcase(%scan(&zb,1,.))"
and upcase(memname)="%upcase(%scan(&zb,2,.))"
and upcase(name)="%upcase(&zm)";
quit;
%put &typ;

%do i=1 %to &il_podz;
	%if &typ=CHAR %then %do;
		proc sql noprint;
		select "'"||trim(&zm)||"'" into :cl&i separated by ',' from podz
		where cluster=&i;
		quit;
	%end; %else %do;
		proc sql noprint;
		select &zm into :cl&i separated by ',' from podz
		where cluster=&i;
		quit;
	%end;
%put &&cl&i;
%end;

data podz_nom;
length zmienna $32 war $300;
%do i=1 %to &il_podz;
war="when (&&cl&i)";
grp=&i;
zmienna="&zm";
output;
%end;
/*war="otherwise";*/
/*grp=&miss;*/
/*zmienna="&zm";*/
/*output;*/
run;
%mend;

%koduj;

proc append base=t.podzialy_nom_sklejane data=podz_nom;
run;
%end;
%mend;

%sklejaj;


data t.podzialy_nom_sklejane;
set t.podzialy_nom_sklejane;
where war not like '%&cl%';
run;

