/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */



/*%let il_seed=100;*/
/*%let il_seed=10000;*/
/*%let il_seed=20000;*/


libname kal (modele);



data score;
set kal.score&nr_mod;
format &tar best12.;
keep &tar &zm;
run;
proc sort data=score;
by &tar;
where &tar in (0,1);
run;

%macro validuj;

proc sql noprint;
select sum((&tar=1)),sum((&tar=0)) into :jedynki,:zera
from score;
quit;
%put &jedynki***&zera;

data kal.bootstrap&nr_mod;
length seed 
/*ps */
ar ks 8;
delete;
run;

/*%let seed=1;*/

%do seed=1 %to &il_seed;


proc surveyselect data=score out=s(keep=&zm &tar) noprint
method=urs n=(&zera &jedynki) outhits seed=&seed;
strata &tar;
run;

/*%powerc(s,&zm,&tar);*/
/*data _null_;*/
/*set power;*/
/*call symput("ps",put(powerpercent,best12.-L));*/
/*run;*/



proc npar1way data=s edf wilcoxon noprint;
class &tar;
var &zm;
output out=ks(keep=_D_) wilcoxon edf;
run;

data a;
label2='c';
nValue2=.;
run;


ods listing close;
ods output Association(persist=proc)=a;
proc logistic data=s desc;
model &tar=&zm;
run;
ods output close;
ods listing;

data wynik;
set a(where=(label2='c'));
set ks;
/*set power(keep=powerpercent rename=(powerpercent=ps));*/
ar=2*nValue2-1;
seed=&seed;
ks=_d_;
keep seed 
/*ps */
ar ks;
run;

proc append base=kal.bootstrap&nr_mod data=wynik;
run;
%end;


proc means data=kal.bootstrap&nr_mod noprint nway;
var 
/*ps */
ks ar;
output out=kal.cross_stat&nr_mod(drop=_freq_ _type_) mean= p50= min= max= 
cv= range= qrange= uclm= lclm= / autoname;
run; 

%mend;
%validuj;

