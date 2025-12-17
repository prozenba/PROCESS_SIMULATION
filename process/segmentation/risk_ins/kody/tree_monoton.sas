/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */




libname t (wyj);
%let kat_tree=%sysfunc(pathname(wyj));
%put &kat_tree;



proc sql noprint;
select upcase(zmienna) into :zmienne_int_ord separated by ' '
from &em_data_variableset where typ in ('ord','int');
quit;
%let il_zm=&sqlobs;


%put ***&il_zm***&zmienne_int_ord;





data _null_;
set &zb(obs=1) nobs=il;
min_il=int(&min_percent*il/100);
call symput('min_il',trim(put(min_il,best12.-L)));
run;
%put &min_il;
/*%let min_il=2000;*/
/*kyterium albo h albo g;*/
%let crit=h;


/*obcinanie skrajnych*/
%let cent=1;
%let dop=%eval(100-&cent);




%macro zrob_podz(zm,kolejnosc);

proc means data=&zb nway noprint;
var &zm;
output out=cen p&cent=p1 p&dop=p99;
run;
data _null_;
set cen;
call symput("p1",put(p1,best12.));
call symput("p99",put(p99,best12.));
run;
%put ***&p1***&p99***;

proc means data=&zb nway noprint;
class &zm;
/*class &zm / missing;*/
var &tar;
output out=t.stat(drop= _freq_ _type_) sum()=sum n()=n;
/*where &zm between &p1 and &p99;*/
run;

/*Tu w tym zbiorze bed¹ liœcie*/
data t.warunki;
length g_l g_p war $300 zmienna $32;
g_l='low'; g_p='high'; criterion=0; dzielic=1;nrobs=1;glebokosc=1;
%if &kolejnosc=R %then %do;
length  il_jed_at il_at 8; br_poww=0; br_pon=1; br=1;
%end; %else %do;
length  il_jed_at il_at 8; br_poww=1; br_pon=0; br=1;
%end;
war="not missing(&zm)";
zmienna="&zm";
run;


%macro krok(nr_war,kolejnosc);
proc sql noprint;
select war,criterion,br_poww,br_pon into :war,:c,:br_poww,:br_pon
from t.warunki(obs=&nr_war firstobs=&nr_war);

%let zb_krok=t.stat(where=(&war));

select sum(n) as il,sum(sum) as il_jed, calculated il - calculated il_jed
into :il,:il_jed,:il_zer
from &zb_krok;
quit;
%put &il;
%put &war;
%global jest;
%let jest=.;
data krok;
retain il_zer &il_zer il_jed &il_jed il &il;
retain br_poww_old &br_poww br_pon_old &br_pon;


set &zb_krok end=e;

cum_sum+sum;
cum_n+n;
il_jed_poww=cum_sum;
il_jed_pon=il_jed-cum_sum;
il_zer_poww=cum_n-cum_sum;
il_zer_pon=il_zer-il_zer_poww;
il_poww=cum_n;
il_pon=il-cum_n;

g_poww=(1-((il_jed_poww/il_poww)**2+(il_zer_poww/il_poww)**2));
g_pon=(1-((il_jed_pon/il_pon)**2+(il_zer_pon/il_pon)**2));
g=1-((il_jed/il)**2+(il_zer/il)**2)
-g_poww*il_poww/il
-g_pon*il_pon/il;


h_poww=-((il_jed_poww/il_poww)*log2(il_jed_poww/il_poww)+(il_zer_poww/il_poww)*log2(il_zer_poww/il_poww));
h_pon=-((il_jed_pon/il_pon)*log2(il_jed_pon/il_pon)+(il_zer_pon/il_pon)*log2(il_zer_pon/il_pon));
h=-((il_jed/il)*log2(il_jed/il)+(il_zer/il)*log2(il_zer/il))     
-h_poww*il_poww/il
-h_pon*il_pon/il;


if il_poww<&min_il or il_pon<&min_il then do;
h=.;
g=.;
end;

br_poww=il_jed_poww/il_poww;
br_pon=il_jed_pon/il_pon;



if _error_=1 then _error_=0;


run;
%put jest***&jest;

data k;
set krok;
/*dla nie monotonicznoœci*/
/*where &crit is not missing;*/
/*dla monotonicznoœci*/
/*od 0 do 1*/
%if &kolejnosc=R %then %do;
where &crit is not missing and br_poww_old<=br_poww and br_poww<=br_pon and br_pon<=br_pon_old;
%put 'wdzedl do R';
%end; %else %do;
/*od 1 do 0*/
where &crit is not missing and br_poww_old>=br_poww and br_poww>=br_pon and br_pon>=br_pon_old;
%put 'wdzedl do R';
%end;
run;
%put kolejnosc=&kolejnosc;

proc sort data=k;
by descending &crit;
run;

%let jest=.;

data _null_;
set k(obs=1);
if &crit._poww>=&c or &crit._pon>=&c then call symput('jest','ok');
else call symput('jest','.');
run;



%if "&jest" ne "." %then %do; 

data t.warunki;
length prawy $300;
obs=&nr_war;
modify t.warunki point=obs;
prawy=g_p;
set k(obs=1);
g_p=put(&zm,best12.-L);
criterion=&crit._poww;
if g_l ne 'low' then war=trim(g_l)||" < &zm <= "||trim(g_p);
else war="not missing(&zm) and &zm <= "||trim(g_p);
dzielic=1;
glebokosc=glebokosc/2;

il_jed_at=il_jed_poww;
il_at=il_poww;

br=il_jed_at/il_at;

zap=br_poww;
br_poww=&br_poww;

replace;
g_l=put(&zm,best12.-L);
g_p=trim(prawy);
criterion=&crit._pon;
if g_p ne 'high' then war=trim(g_l)||" < &zm <= "||trim(g_p);
else war=trim(g_l)||" < &zm ";
dzielic=1;
nrobs=nrobs+0.5;

il_jed_at=il_jed_pon;
il_at=il_pon;

br_poww=zap;
br_pon=&br_pon;

br=il_jed_at/il_at;

output;
stop;
run;

proc sort data=t.warunki;
by nrobs;
run;

data t.warunki;
modify t.warunki;
nrobs=_n_;
replace;
run;

%end; %else %do;
data t.warunki;
obs=&nr_war;
modify t.warunki point=obs;
dzielic=0;
replace;
stop;
run;
%end;

%mend;

%macro podzialy(kolejnosc);
%do i=1 %to &max_il_podz;

%let nr_war=pusty;
proc sql noprint;
select nrobs into :nr_war
from t.warunki
where dzielic=1
order by glebokosc desc, criterion;
quit;
%if "&nr_war" ne "pusty" %then %do;
%krok(&nr_war,&kolejnosc);
%end;

%end;
%mend;

%podzialy(&kolejnosc);
%mend;



%macro dla_wszystkich_zm(kolejnosc);


data t.podzialy;
length g_l g_p war $300 zmienna $32;
g_l='low'; g_p='high'; criterion=0; dzielic=1;nrobs=1;glebokosc=1; br_poww=0; br_pon=1; br=1;
length  il_jed_at il_at 8;
delete;
run;

/*%do nr_zm=1 %to 1;*/
%do nr_zm=1 %to &il_zm;


%zrob_podz(%upcase(%scan(&zmienne_int_ord,&nr_zm,%str( ))),&kolejnosc);

proc append base=t.podzialy data=t.warunki;
run;
%end;

/*doliczenie woe*/
proc sql noprint;
select count(&tar),sum(&tar) into :il,:il_jed
from &zb;
quit;
%put &il***&il_jed;

data t.podzialy;
set t.podzialy;
/*ta poprawka do zastanowienia*/
woe=log(((il_at-il_jed_at)/(&il-&il_jed))/((il_jed_at+0.001)/&il_jed));
run;

/*na razie missing wrzucamy do najliczniejszego atrybutu*/
proc sort data=t.podzialy out=p;
by zmienna descending il_at;
run;


%mend;



%dla_wszystkich_zm(R);
data t.podzialy_int_r;
set t.podzialy;
keep war zmienna nrobs;
rename nrobs=grp;
where criterion ne 0;
run;

%dla_wszystkich_zm(M);
data t.podzialy_int_m;
set t.podzialy;
keep war zmienna nrobs;
rename nrobs=grp;
where criterion ne 0;
run;

proc sql;
create table m as
select zmienna, max(grp) as maxm from t.podzialy_int_m
group by 1
order by 1;

create table r as
select zmienna, max(grp) as maxr from t.podzialy_int_r
group by 1
order by 1;
quit;
data wspolne;
merge m r;
by zmienna;
if maxr>maxm then wybor='r'; else wybor='m';
run;
proc sql;
create table pm as
select * from t.podzialy_int_m 
where zmienna in (select zmienna from wspolne where wybor='m');

create table pr as
select * from t.podzialy_int_r
where zmienna in (select zmienna from wspolne where wybor='r');
quit;
data t.podzialy_int_mon_&cent;
set pr pm;
run;

