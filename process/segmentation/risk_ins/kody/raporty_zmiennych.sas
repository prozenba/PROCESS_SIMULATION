/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */



/*raporty o zmiennych new*/
options ls=256;
options mprint;
%let nr_cent=99;

proc format;
picture procent (round)
low- -0.005='00.000.000.009,99 %'
(decsep=',' 
dig3sep='.'
fill=' '
prefix='-')
-0.005-high='00.000.000.009,99 %'
(decsep=',' 
dig3sep='.'
fill=' ')
;
run;

proc format;
picture liczba (round)
low- -0.005='0 000 000 000 009,99'
(decsep=',' 
dig3sep=' '
fill=' '
prefix='-')
-0.005-high='0 000 000 000 009,99'
(decsep=',' 
dig3sep=' '
fill=' ')
;
run;



proc sql noprint;
select 
'WOE_'||
upcase(trim(_VARIABLE_)) 
into :zmienne separated by ' ' from wyj.dobre_zmienne;
quit;
%put &zmienne;

ods listing close;
ods output
Eigenvalues=Eigenvalues;
/*ods trace on / listing;*/
/*ods trace off;*/
proc princomp data=&em_import_data(keep=&zmienne);
var &zmienne;
run;
ods output close;
ods listing;



ods listing close;
ods output
ClusterQuality=ClusterQuality
RSquare(match_all)=RSquare2
ClusterSummary(match_all)=ClusterSummary1;
/*ods trace on / listing;*/
/*ods trace off;*/
proc varclus data=&em_import_data(keep=&zmienne) PROPORTION=0.8;
var &zmienne;
run;
ods output close;
ods listing;

data _null_;
set Clusterquality;
call symput('ncl',
trim(put(NumberOfClusters,best12.-L)));
run;
%put **&ncl**;


%let reportsdir=&prefix_dir.results\%sysfunc(compress(&design,_))\;
%let subdir=reports\;
%put &reportsdir;



ods listing close;
ods html body="&reportsdir.All_possible_variables.html" style=statistical;
data test;
set inlib.labels;
run;
proc sort data=test;
by label;
run;
data test;
set test;
Number=_n_;
run;
title "List of all possible variables";
proc print data=test label;
id Number name;
var label;
label
label='Variable description'
name='Variable name'
;
run;
ods html close;
ods listing;



ods listing close;
ods html body="&reportsdir.All_variables.html" style=statistical;
data test0;
set wyj.zmienne_stat&design;
gini_before=2*c_01_train-1;
gini_after=ar_train;
diff_gini=(gini_before-gini_after)/gini_before;
Number=_n_;
format gini_before gini_after diff_gini 
PR_Miss_Train PR_Moda_Train nlpct12.2;
if _error_=1 then _error_=0;
keep number _variable_ gini_before gini_after diff_gini
level PR_Miss_Train N_Uni_Train PR_Moda_Train Moda_Train
ar_diff H_GRP_TV H_Br_GRP_TV;
run;
proc sql;
create table test as
select test0.*,label
from test0, inlib.labels
where upcase(name)=upcase(_variable_)
order by gini_after desc;
quit;
data test;
set test;
Number=_n_;
run;

title "Report of all variables, after simple pre-selection";
proc print data=test label;
id Number _variable_;
var gini_before gini_after diff_gini label
level PR_Miss_Train N_Uni_Train PR_Moda_Train Moda_Train
ar_diff
H_GRP_TV
H_Br_GRP_TV
;
label
AR_Diff='Relative difference between Ginis between training and validating datasets'
H_GRP_TV='Kullback-Leibrer between attribute distributions on training and validating datasets'   
H_Br_GRP_TV='Kullback-Leibrer between attribute distributions only for bad cases on training and validating datasets'   
gini_before='Gini before binning' 
gini_after='Gini after binning' 
diff_gini='Difference of gini before and after binning'
_variable_='Variable name'
label='Variable description'
level='Measure'
PR_Miss_Train='Percent of missing valuses' 
N_Uni_Train='Number of distinct values'
PR_Moda_Train='Percent of the most frequent nonmissing value' 
Moda_Train='The most frequent nonmissing value' 
;
run;
ods html close;
ods listing;

proc sql;
create table karta as
select * from wyj.karta_duza&design where 
upcase(zmienna) in 
(select upcase(_VARIABLE_) from wyj.dobre_zmienne&design)
or upcase(zmienna) in 
(select upcase(zmienna) from wyj.Chosen_variables)
order by zmienna,grp;
quit;
proc sql noprint;
select count(*),sum((&tar=1)),
sum((&tar=0)),sum((&tar=.i or &tar=.d)) into 
:il,:il_jed,:il_zer,:il_ind
from &zb;
quit;
%put &il***&il_jed***&il_zer***&il_ind;


data karta;
set karta;
POP=il_at;
GD=il_zer_at;
BD=il_jed_at;
IND=il_ind_at;
pr_POP=POP/&il;
pr_GD=coalesce(GD/&il_zer,0);
pr_BD=coalesce(BD/&il_jed,0);
pr_IND=coalesce(IND/&il_ind,0);
wi=log(pr_GD/pr_BD);
ivi=(pr_GD-pr_BD)*wi;
if _error_=1 then _error_=0;
keep zmienna POP GD BD IND pr_POP pr_GD pr_BD pr_IND wi ivi br grp war;
format br pr_POP pr_GD pr_BD pr_IND nlpct12.2 ivi wi numx12.2;
run;

data clusters;
length cl cluster $ 20;
format cluster $20.;
retain cl;
set rsquare&ncl;
if not missing(Cluster) then cl=Cluster;
if missing(Cluster) then Cluster=cl;
cluster='Cluster '||put(input(compress(scan(cluster,-1,' ')),best12.),z3.);
Variable=substr(Variable,5);
keep Variable Cluster RSquareRatio;
run;

proc sql;
create table ivi as
select sum(ivi) as ivi format=numx12.2,zmienna from karta
group by zmienna;

create table test_det0 as
select test.*, ivi from test,ivi
where upcase(zmienna)=upcase(_variable_)
order by gini_after desc;

create table test_det as
select test_det0.*, Cluster, RSquareRatio from test_det0 left join clusters
on upcase(test_det0._variable_)=upcase(clusters.variable)
order by gini_after desc;
quit;

proc sql noprint;
select quote(zmienna) into :chosen separated by ','
from wyj.Chosen_variables;
quit;
%put &chosen;

data test_det;
length href $ 1000;
set test_det;
Number=_n_;
if _variable_ in (&chosen) then
href= 
'<a href="'||"&subdir."||compress(upcase(_VARIABLE_))
||'.html" '||'target="body">'||compress(upcase(_VARIABLE_))||'</a>'
;
else href=_VARIABLE_;
run;

proc sort data=test_det out=test_dets;
by cluster descending gini_after;
run;

ods listing close;
ods html path="&reportsdir" (url=none)
body="Chosen_variables.html" style=statistical;
title "Report of chosen variables";
proc print data=test_det label;
id Number href;
var gini_before gini_after diff_gini ivi label
level PR_Miss_Train N_Uni_Train PR_Moda_Train Moda_Train
ar_diff
H_GRP_TV
H_Br_GRP_TV 
Cluster RSquareRatio
;
label
AR_Diff='Relative difference between Ginis between training and validating datasets'
H_GRP_TV='Kullback-Leibrer between attribute distributions on training and validating datasets'   
H_Br_GRP_TV='Kullback-Leibrer between attribute distributions only for bad cases on training and validating datasets'   
href='Variable name (click on name to get details)'
ivi='Information value (iv)'
gini_before='Gini before binning' 
gini_after='Gini after binning' 
diff_gini='Difference of gini before and after binning'
_variable_='Variable name'
label='Variable description'
level='Measure'
PR_Miss_Train='Percent of missing valuses' 
N_Uni_Train='Number of distinct values'
PR_Moda_Train='Percent of the most frequent nonmissing value' 
Moda_Train='The most frequent nonmissing value' 
;
run;
ods html close;
ods listing;

ods listing close;
ods html path="&reportsdir" (url=none)
body="Clustered_variables.html" style=statistical;
title "Report of variable clusters";
proc print data=test_dets label width=minimum;
/*id cluster href;*/
by cluster;
var href Number gini_before gini_after diff_gini ivi label
level PR_Miss_Train N_Uni_Train PR_Moda_Train Moda_Train
ar_diff
H_GRP_TV
H_Br_GRP_TV 
RSquareRatio
;
label
AR_Diff='Relative difference between Ginis between training and validating datasets'
H_GRP_TV='Kullback-Leibrer between attribute distributions on training and validating datasets'   
H_Br_GRP_TV='Kullback-Leibrer between attribute distributions only for bad cases on training and validating datasets'   
href='Variable name (click on name to get details)'
ivi='Information value (iv)'
gini_before='Gini before binning' 
gini_after='Gini after binning' 
diff_gini='Difference of gini before and after binning'
_variable_='Variable name'
label='Variable description'
level='Measure'
PR_Miss_Train='Percent of missing valuses' 
N_Uni_Train='Number of distinct values'
PR_Moda_Train='Percent of the most frequent nonmissing value' 
Moda_Train='The most frequent nonmissing value' 
;
run;
ods html close;
ods listing;

ods listing close;
ods html path="&reportsdir" (url=none)
body="Cluster_reports.html" style=statistical;
title "Dimentional reports";
proc print data=Clusterquality label;
run;
proc print data=Clustersummary&ncl label;
run;
proc print data=Eigenvalues label;
run;
ods html close;
ods listing;




/*proc sql noprint;*/
/*select 'inlib.'||memname into :sets separated by " " */
/*from dictionary.tables where*/
/*libname=upcase("INLIB") and (memname like "ABT_1%" */
/*or memname like "ABT_2%"); */
/*quit; */
%let sets=&in_abt;
%put &sets;

proc sql noprint;
select 'GRP_'||compress(upcase(zmienna)),compress(upcase(zmienna))
into :zmienne_grp separated by ' ',
:zmienne separated by ' '
from wyj.Chosen_variables;
quit;
%put &zmienne***&sqlobs;

%let dodatkowe=credit_limit;
%let trzymaj=&tar outstanding period quarter year &dodatkowe;
data abt;
set &sets;
%dodatkowe_zmienne;
quarter=compress(put(input(period,yymmn6.),yyq10.));
year=compress(put(input(period,yymmn6.),year4.));
keep &zmienne &trzymaj;
run;

%let kat_kodowanie=%sysfunc(pathname(wyj));
%put &kat_kodowanie;
%let zbior=abt;
%let keep=&zmienne_grp &trzymaj;
%include "&kat_kodowanie.\kod_do_kodowania.sas";
/*data abt_woe;*/
/*set abt_woe;*/
/*if &tar in (.,.i,.d) then &tar=0;*/
/*run;*/




%macro make_details;
proc sql noprint;
select distinct upcase(zmienna) into :zmienne separated by ' '
from wyj.Chosen_variables;
quit;
%let il_zm=&sqlobs;
%put &il_zm***&zmienne;
/*%let i=1;*/

%do i=1 %to &il_zm;
/*%do i=1 %to 1;*/

%let zm=%scan(&zmienne,&i,%str( ));
%put &zm;
%let label=Not defined;
proc sql noprint;
select label into :label from test_det
where upcase(_variable_) eq "&zm"
and label not like "%'%" and label ne '';
quit;
%put &label;


ods listing close;
ods html path="&reportsdir.&subdir" (url=none)
body="&zm..html" style=statistical;
title "Attributes for variable &zm";
title2 "&label";
title3 'Table with statistics';
proc print data=karta label;
id grp;
var war br pr_POP pr_GD pr_BD pr_IND POP GD BD IND wi ivi;
where upcase(zmienna)="&zm";
label
ivi='Information value (ivi)'
POP='Population (POP)' 
GD='Number of goods (GD)' 
BD='Number of bads (BD)' 
IND='Number of indeterminated (IND)' 
pr_POP='Percent of population (%POP)' 
pr_GD='Percent of goods (%GD)' 
pr_BD='Percent of bads (%BD)' 
pr_IND='Percent of indeterminated (%IND)'
wi='Weight of evidence (wi)' 
br='Bad rate (br)'
grp='Attribute number'
war='Condition'
;
sum POP GD BD IND pr_POP ivi;
run;

goptions reset=all device=activex;

%let period=year;
/*%let period=period;*/
%let balvar=outstanding;
/*%let balvar=outstanding_&tar;*/
%let measure=&tar;

data br_am;
set abt_woe;
all=&balvar;
if (&measure in (.d,.i,0,1)) then all_ass=&balvar;
if (&measure in (0)) then good=&balvar;
if (&measure in (1)) then bad=&balvar;
keep GRP_&zm &period all good bad all_ass credit_limit;
run;


proc means data=br_am nway noprint;
class GRP_&zm &period;
var all good bad all_ass credit_limit;
output out=br_am_stat 
sum(all good bad all_ass credit_limit)=all good bad all_ass credit_limit
n(all)=n mean(all credit_limit)=sr credit_limit_sr
n(good bad all_ass)=good_n bad_n all_ass_n
;
run;

data br_am_stat;
set br_am_stat;
br=bad/all_ass;
br_n=bad_n/all_ass_n;
if _error_ then _error_=0;
run;


title "Numbers - all statistics for &measure by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc tabulate data=br_am_stat out=stat_am;
class GRP_&zm &period;
var all good bad good_n bad_n br br_n 
n all_ass credit_limit credit_limit_sr sr;
table
&period='' , GRP_&zm='GRP'*
( 
all='All'*sum=''*f=liczba.
sr='Average'*sum=''*f=liczba.
all='All percent'*rowpctsum=''*f=procent. 
all_ass='All assigned'*sum=''*f=liczba.
n='N'*sum=''*f=20.  
good='Good'*sum=''*f=liczba.
bad='Bad'*sum=''*f=liczba.
br='Bad rate'*sum=''*f=nlpct12.2  
n='All percent N'*rowpctsum=''*f=procent. 
good_n='Good N'*sum=''*f=12.
bad_n='Bad N'*sum=''*f=12.
br_n='Bad rate N'*sum=''*f=nlpct12.2  
credit_limit='Limit percent'*rowpctsum=''*f=procent. 
credit_limit_sr='Average limit'*sum=''*f=liczba.
)
/ box="&period";
run;

title "Chart - number distribution by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc gchart data=stat_am;
block GRP_&zm / discrete group=&period sumvar=n_PctSum_01 type=sum 
patternid=group subgroup=n_Sum;
label n_Sum='Number of accounts' GRP_&zm='GRP'
n_PctSum_01='Number percent';
format n_PctSum_01 procent. n_sum 12.;
run;
quit;


title "Chart - balance distribution by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc gchart data=stat_am;
block GRP_&zm / discrete group=&period sumvar=all_PctSum_01 type=sum 
patternid=group subgroup=all_Sum;
label all_Sum='Balance' GRP_&zm='GRP'
all_PctSum_01='Balance percent';
format all_PctSum_01 procent. all_sum liczba.;
run;
quit;


title "Chart - average balance for attributes by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc gchart data=stat_am;
block GRP_&zm / discrete group=&period sumvar=sr_sum type=sum 
patternid=group subgroup=all_Sum;
label all_Sum='Balance' GRP_&zm='GRP'
sr_sum='Average balance';
format sr_sum liczba. all_sum liczba.;
run;
quit;


title "Chart - average credit limit for attributes by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc gchart data=stat_am;
block GRP_&zm / discrete group=&period sumvar=credit_limit_sr_Sum
type=sum 
patternid=group subgroup=credit_limit_PctSum_01;
label credit_limit_PctSum_01='Limit percent' GRP_&zm='GRP'
credit_limit_sr_Sum='Average credit limit';
format credit_limit_PctSum_01 procent. credit_limit_sr_Sum liczba.;
run;
quit;


/*%let cent=0.001;*/
/*proc univariate data=stat_am noprint;*/
/*var bad_rate;*/
/*output out=cent max=p_&nr_cent;*/
/*where bad_rate < 1;*/
/*run;*/
/*data _null_;*/
/*set cent;*/
/*if p_&nr_cent<0.001 then p_&nr_cent=0.001;*/
/*call symput('cent',put(1.2*p_&nr_cent,best12.-L));*/
/*run;*/
/*%put &cent;*/
/**/
/**/
/*title "Chart - risk balance &desc_bal measure &measure for score bands by &period on state &state";*/
/*ods proclabel="Chart - risk balance &desc_bal measure &measure for score bands by &period on state &state";*/
/*proc gchart data=stat_am;*/
/*block band / discrete group=&period sumvar=Bad_rate type=sum */
/*patternid=group subgroup=bad axis=0 to &cent by 0.02;*/
/*label bad='Balance for bads' band='Score band'*/
/*bad_rate="&measure";*/
/*format bad_rate nlpct12.2 bad liczba.;*/
/*run;*/
/*quit;*/



title "Chart - Balance bad rate for &measure by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc gchart data=stat_am;
block GRP_&zm / discrete group=&period sumvar=br_sum
type=sum 
patternid=group subgroup=bad_sum;
label br_sum="Balance bad rate &measure" GRP_&zm='GRP'
bad_Sum='Balance for Bads';
format br_sum nlpct12.2 bad_sum liczba.;
run;
quit;


title "Chart - Number bad rate for &measure by &period on state EM";
title2 "Attributes for variable &zm";
title3 "&label";
proc gchart data=stat_am;
block GRP_&zm / discrete group=&period sumvar=br_n_sum
type=sum 
patternid=group subgroup=bad_n_sum;
label br_n_sum="Number bad rate &measure" GRP_&zm='GRP'
bad_n_Sum='Number of bad accounts';
format br_n_sum nlpct12.2 bad_n_sum liczba.;
run;
quit;
ods html close;
ods listing;
goptions reset=all device=win;


%end;

%mend;
%make_details;
