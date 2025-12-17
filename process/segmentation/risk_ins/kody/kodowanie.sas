/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */



proc sort data=&inset out=podz;
by zmienna grp;
run;
data wyj.podzialy_interwalowe;
set 
podz
;
by zmienna;
if index(war,'is not missing')>0 then 
war='not missing('||compress(zmienna)||')';
output;
if last.zmienna then do;
grp=grp+1;
war='missing('||compress(zmienna)||')';
output;
end;
run;
proc sort data=wyj.podzialy_interwalowe;
by zmienna grp;
run;

data wyj.podzialy_nominalne;
set 
&jakie_podzialy_nominalne
;
run;
proc sort data=wyj.podzialy_nominalne;
by zmienna grp;
run;

/*kodowanie*/
/*od nowa siê liczy iloœci w atrybutach*/
/*zaklada siê ¿e mo¿na te warunki modyfikowaæ*/

/*libname t (wyj);*/
%let kat_kodowanie=%sysfunc(pathname(wyj));
%put &kat_kodowanie;




%let zb_int=wyj.podzialy_interwalowe;
%let zb_nom=wyj.Podzialy_nominalne;



data podzialy_org;
set &zb_int &zb_nom;
keep war zmienna grp;
run;

%let adjvars=;
%let adjnames='id';

proc sql noprint;
select "ADJ."||trim(memname),quote(memname) into :adjvars separated by ' ',
:adjnames separated by ','
from dictionary.tables where
libname='ADJ';
quit;
%put &adjvars;
%put &adjnames;

data podzialy;
set podzialy_org(where=(upcase(zmienna) not in (&adjnames)))
&adjvars
;
run;


proc sort data=podzialy;
by zmienna grp;
run;
data podzialy;
set podzialy;
by zmienna;
if first.zmienna and last.zmienna then delete; else output;

/*if last.zmienna and zmienna in (&zmienne_otherwise) then do;*/
/*grp=grp+1;*/
/*war='otherwise';*/
/*output;*/
/*end;*/

if last.zmienna then do;
grp=grp+1;
war='otherwise';
output;
end;

run;


filename kod "&kat_kodowanie.\kod_tym.sas";
/*potrzebujemy policzyæ il_at il_jed_at*/
data _null_;
length przed za $100 naz $32;
file kod;
if _n_=1 then do;
put "data grp;";
put "set &zb;";
end;

do i=1 to ilobs;
set podzialy nobs=ilobs;
by zmienna;
if first.zmienna then do;
	if substr(war,1,4)='when' then do;
	przed='';za='';
	put "select (" zmienna ");";
	end; else do;
	przed='when (';za=')';
	put "select;";
	end;
end;

if not last.zmienna then do;
put przed war za "do;";
naz="GRP_"||trim(zmienna);
put naz " = " grp ";";
put "end;";
end;

if last.zmienna and war='otherwise' then 
	put 'otherwise ' naz ' = ' grp '; end;';
if last.zmienna and war ne 'otherwise' then 
	put 'otherwise ' naz ' = ' '.; end;';

end;

put "run;";
run;

%include "&kat_kodowanie.\kod_tym.sas";

proc means data=grp noprint;
class grp: /missing;
ways 1;
var &tar;
output out=licz sum()=il_jed_at n()=il_at nmiss()=il_ind_at;
where &tar ne .;
run;

data licz;
length zmienna zmienna2 $32 grp 8;
set licz;
array t(*) grp:;
do i=1 to dim(t);
if not missing(t(i)) then do;
	grp=t(i);
	zmienna=vname(t(i));
end;
end;
zmienna=substr(zmienna,5);
zmienna2=zmienna;
il_zer_at=il_at-il_jed_at;
il_at=il_at+il_ind_at;
if not missing(zmienna);
keep zmienna zmienna2 grp il_at il_jed_at il_zer_at il_ind_at;
run;
proc sort data=licz;
by zmienna2 grp;
run;

/*specjalna wstawka*/
data podzialy;
set podzialy;
zmienna2=substr(zmienna,1,28);
run;
proc sort data=podzialy;
by zmienna2 grp;
run;


data podzialy_pol;
merge podzialy licz;
by zmienna2 grp;
run;


/*doliczenie woe logit*/
proc sql noprint;
select count(*),sum((&tar=1)),sum((&tar=0)),
sum((&tar=.i or &tar=.d)) into :il,:il_jed,:il_zer,:il_ind
from &zb;
quit;
%put &il***&il_jed***&il_zer***&il_ind;

/*podzialy ze statystykami*/
data wyj.karta_duza;
set podzialy_pol;
/*ta poprawka do zastanowienia*/
woe_org=log(((il_zer_at)/(&il_zer))/((il_jed_at)/&il_jed));
br=il_jed_at/il_at;

if br>0.99 or missing(br) then br=0.99;
if .<br<0.0003 then br=0.0003;

logit=log(il_jed_at/il_zer_at);
/*logit=log(br/(1-br));*/
/*liczê woe jako logit*/
woe=logit;
Percent=il_at/&il;
Percent_jed=coalesce(il_jed_at/&il_jed,0);
Percent_zer=coalesce(il_zer_at/&il_zer,0);
Percent_ind=coalesce(il_ind_at/&il_ind,0);
wi=log(percent_zer/percent_jed);
ivi=(percent_zer-percent_jed)*wi;
format percent percent_jed percent_zer percent_ind percent12.2;
if _error_=1 then _error_=0;
if missing(percent) then delete;
/*if not missing(war1) and not missing(war2) and .<=percent<0.005 then delete;*/
if .<=percent<0.005 then delete;
run;


proc sort data=wyj.karta_duza;
by zmienna descending br ;
run;
data wyj.karta_duza;
set wyj.karta_duza(drop=grp);
by zmienna;
if first.zmienna then grp=0;
grp+1;
otherwise_ind=(war='otherwise');
run;

/*na razie missing wrzucamy wed³ug porz¹dku 
zale¿nie od tego czy to jest model ryzyka czy response*/

proc sort data=wyj.karta_duza out=p;
by zmienna2 otherwise_ind &porz_tar br;
/*by zmienna il_at;*/
run;

/*teraz prawdziwe kodowanie*/


filename kod "&kat_kodowanie.\kod_do_kodowania.sas";
data _null_;
length przed za $100 naz $32;
file kod;
if _n_=1 then do;
put 'data &zbior._woe;';
put 'set &zbior;';
end;

do i=1 to ilobs;
set p nobs=ilobs;
by zmienna2;

if war ne 'otherwise' then do;
	if first.zmienna2 then do;
		if substr(war,1,4)='when' then do;
		przed='';za='';
		put "select (" zmienna ");";
		end; else do;
		przed='when (';za=')';
		put "select;";
		end;
	end;

	put przed war za "do;";
	naz="GRP_"||trim(zmienna);
	put naz " = " grp ";";
	naz="WOE_"||trim(zmienna);
	put naz " = " woe ";";
	put "end;";
end; 


if last.zmienna2 then do;
	put 'otherwise do;';
	naz="GRP_"||trim(zmienna);
	put naz " = " grp ";";
	naz="WOE_"||trim(zmienna);
	put naz " = " woe ";";
    put 'end; end;';
end;

end;
put 'keep &keep;';
put 'if _error_=1 then _error_=0;';
put "run;";
run;

%let zbior=&zb;
%let keep=_all_;
%include "&kat_kodowanie.\kod_do_kodowania.sas";

%let zbior=&zb_v;
%let keep=_all_;
%include "&kat_kodowanie.\kod_do_kodowania.sas";


