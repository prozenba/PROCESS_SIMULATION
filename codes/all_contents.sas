/*Process of project calculation*/
/*Credit Scoring and macroprogramming in SAS*/

/* (c) Karol Przanowski */
/* kprzan@sgh.waw.pl */
  ;*';*";*/;run;quit;ods html5(id=vscode) close;

options mprint;
options nomprint;

%let dir=&WORKSPACE_PATH./PROCESS_SIMULATION/;

libname dataP parquet "&dir.process/data/" ;
libname abtP parquet "&dir.process/abt/" ;
libname potP parquet  "&dir.potential" ;

libname data  "&dir.process/data/" ;
libname abt  "&dir.process/abt/" ;
libname pot   "&dir.potential" ;

%include "&dir.codes/abt_behavioral_columns.sas" / source2;
%include "&dir.process/codes/decision_engine.sas" / source2;


proc copy in=potP out=pot noclone;
run;

sasfile pot.default load;
sasfile pot.Production load;
sasfile pot.transactions load;


proc datasets lib=data nolist kill;
quit;

proc datasets lib=abt nolist kill;
quit;

%let apr_ins=0.01;
%let apr_css=0.18;
%let lgd_ins=0.45;
%let lgd_css=0.55;
%let provision_ins=0;
%let provision_css=0;

/*maximal data period in months*/
%let max_length=12;


data data.transactions;
length cid $10 aid $16 product $3 period fin_period $6 status $1
due_installments paid_installments pay_days n_installments
installment spendings income leftn_installments 8;
delete;
run;
proc datasets lib=data nolist;
modify transactions;
/* index delete _all_; */
index create period;
index create status;
index create comp=(status period);
index create comp2=(aid period);
index create comp3=(cid period);
index create comp4=(product aid cid period);
index create cid;
index create aid;
index create product;
quit;

sasfile data.transactions load;


data data.decisions;
length cid $10 aid $16 product $3 period $6 decision $1 decline_reason $20
app_loan_amount app_n_installments pd cross_pd pr 8;
delete;
format pd cross_pd pr nlpct12.2;
run;
proc datasets lib=data nolist;
modify decisions;
/* index delete _all_; */
index create period;
index create comp2=(aid period);
index create comp3=(cid period);
index create comp4=(product aid cid period);
index create cid;
index create aid;
index create product;
quit;

sasfile data.decisions load;


%macro cust_level(version);
/*%let version=ins;*/
proc sql;
create table tmp_cus_&version as
select * from data.transactions
where cid in
(select cid from cust_uni) and period<="&proc_period1" and product="&version"
;
quit;

proc means data=tmp_cus_&version nway noprint;
class cid;
var paid_installments n_installments leftn_installments
	due_installments income spendings;
output out=tmp_cus_&version._agr(drop=_type_ _freq_)
sum(paid_installments n_installments due_installments installment)=
paid_installments n_installments due_installments installment 
max(income spendings)=income spendings n(income)=act_c&version._n_loans_act
max(due_installments)=act_c&version._maxdue
min(paid_installments)=act_c&version._min_pninst
min(leftn_installments)=act_c&version._min_lninst;
where period="&proc_period1";
run;
data tmp_cus_&version._agr;
set tmp_cus_&version._agr;
act_c&version._utl=paid_installments/n_installments;
act_c&version._dueutl=due_installments/n_installments;
act_c&version._cc=(installment+spendings)/income;
keep cid act:;
label
act_c&version._utl="Customer actual utilization rate on product &version"
act_c&version._dueutl="Customer due installments over all installments rate on product &version"
act_c&version._cc="Customer credit capacity (installment plus spendings) over income on product &version"
act_c&version._maxdue="Customer actual maximal due installments on product &version"
act_c&version._min_pninst="Customer minimal number of paid installments on product &version"
act_c&version._min_lninst="Customer minimal number of left installments on product &version"
act_c&version._n_loans_act="Customer actual number of loans on product &version"
;
run;
proc sort data=tmp_cus_&version._agr;
by cid;
run;

proc sql;
create table tmp_cus_&version._hist as
select cid, 
max(intck('month',input(fin_period,yymmn6.),input("&proc_period1",yymmn6.))+1)
as act_c&version._seniority
label="Customer seniority on product &version",
min(intck('month',input(fin_period,yymmn6.),input("&proc_period1",yymmn6.))+1)
as act_c&version._min_seniority
label="Customer minimal seniority on product &version",
count(distinct aid) as act_c&version._n_loans_hist
label="Customer historical number of loans on product &version",
sum((status='C')) as act_c&version._n_statC
label="Customer historical number of finished loans with status C on product &version",
sum((status='B')) as act_c&version._n_statB
label="Customer historical number of finished loans with status B on product &version"
from tmp_cus_&version
group by 1
order by 1;
quit;
%mend cust_level;

%macro licz_transpose(naz,war);
proc means data=abt_tmp_cus nway noprint;
class cid period;
var days due;
output out=abt_maxy(drop=_type_ _freq_)
max(days due)= &naz._days &naz._due;
where &war;
run;
proc transpose data=abt_maxy prefix=&naz._days_
out=abt_&naz._days(drop=_name_ );
var &naz._days;
id period;
by cid;
run;
proc transpose data=abt_maxy prefix=&naz._due_
out=abt_&naz._due(drop=_name_ );
var &naz._due;
id period;
by cid;
run;
%mend licz_transpose;

%macro processing(proc_period,proc_period1);
/*%let proc_period=197002;*/
/*%let proc_period1=197001;*/
proc sql;
create table month_prod as
select * from pot.Production where period="&proc_period";
quit;
/*proc sql;*/
/*create table month_trans as*/
/*select * from pot.transactions where aid in*/
/*(select aid from month_prod);*/
/*quit;*/
proc sql;
create table month_trans as
select * from pot.transactions where fin_period="&proc_period";
quit;
proc sql;
create table cust_uni as
select distinct cid from month_prod;
quit;

/*czy klient z nowej produkcji css by� aktywny*/
proc sql;
create table cust_uni_active as
select distinct cid, 1 as act_cus_active 
label="Customer had active (status=A) loans one month before"
from data.transactions where period="&proc_period1"
and status='A';
quit;
/*czy klient z nowej produkcji css by� aktywny*/


%cust_level(ins);
%cust_level(css);

proc sql;
create table tmp_cus_all as
select * from data.transactions
where cid in
(select cid from cust_uni) and period="&proc_period" and status='A'
;
quit;
data tmp_cus_all;
set tmp_cus_all Month_prod(rename=(
app_installment=installment
app_spendings=spendings
app_income=income));
time=substr(aid,4,8);
run;

proc sort data=tmp_cus_all;
by cid time aid;
run;

data tmp_cus_nloan;
set tmp_cus_all;
by cid;
if first.cid then do;
	installment_cum=0;
	n_all=0;
	n_ins=0;
	n_css=0;
end;
installment_cum+installment;
if product='ins' then n_ins+1;
if product='css' then n_css+1;
n_all+1;

act_call_cc=(installment_cum+spendings)/income;
act_cins_n_loan=n_ins;
act_ccss_n_loan=n_css;
act_call_n_loan=n_all;

label
act_call_cc="Customer credit capacity (all installments plus spendings) over income"
act_cins_n_loan="Actual customer loan number of Ins product"
act_ccss_n_loan="Actual customer loan number of Css product"
act_call_n_loan="Actual customer loan number"
;
keep aid cid act_call: act_cins: act_ccss:;
run;
proc sort data=tmp_cus_nloan;
by aid;
run;


data _null_;
proc_periodf=put(intnx('month',input("&proc_period1",yymmn6.),-&max_length-2,'end')
,yymmn6.);
call symput('proc_periodf',trim(proc_periodf));
run;
%put &proc_periodf;


proc sql;
create table abt_tmp_cus as
select cid,period,product,pay_days+15 as days,due_installments as due
from data.transactions
where cid in
(select cid from cust_uni) and "&proc_periodf"<=period<="&proc_period1";
quit;

%licz_transpose(cmaxi,%str(product='ins'));
%licz_transpose(cmaxc,%str(product='css'));
%licz_transpose(cmaxa,%str(1=1));

data abt_beh;
merge 
Abt_cmaxa_days Abt_cmaxa_due
Abt_cmaxi_days Abt_cmaxi_due
Abt_cmaxc_days Abt_cmaxc_due
;
by cid;
if not missing(cid);
run;

%let data_wej=abt_beh;
%let data_wyj=abt_beh_fin;
%let id_account=cid;
%make_abt(&proc_period1);
proc sort data=abt_beh_fin;
by cid;
run;
proc sort data=month_prod;
by aid;
run;

data abt.abt_&proc_period;
merge month_prod(in=z) Tmp_cus_nloan;
by aid;
if z;
run;

proc sort data=abt.abt_&proc_period;
by cid;
run;
data abt.abt_&proc_period;
merge abt.abt_&proc_period(in=z) Tmp_cus_ins_hist Tmp_cus_ins_agr
Tmp_cus_css_hist Tmp_cus_css_agr cust_uni_active abt_beh_fin;
by cid;
if z;
run;

/*proc sort data=abt.abt_&proc_period;*/
/*by aid;*/
/*run;*/

%scoring_engine(abt.abt_&proc_period,decision);


proc sort data=decision;
by aid;
run;
proc sort data=month_trans;
by aid;
run;

data month_trans_dec;
merge month_trans(in=z) decision(keep=aid decision);
by aid;
if z and decision='A';
drop decision;
run;

proc sort data=month_trans_dec;
by cid;
run;

proc append base=data.decisions data=decision;
run;
proc append base=data.transactions data=month_trans_dec;
run;


%mend processing;

%macro monthly_processing;
proc sql noprint;
select distinct period into :prod_periods separated by '#'
from pot.Production order by period;
quit;
%let n_prod_periods=&sqlobs;
/*%put &n_prod_periods***&prod_periods;*/

%let proc_period=%scan(&prod_periods,1,#);
%put proc_period;
/*pierwszy period wyj�tkowo zawsze ca�y akceptowany*/
proc sql;
create table month_prod as
select aid from pot.Production where period="&proc_period";
quit;
/*proc sql;*/
/*create table month_trans as*/
/*select * from pot.transactions where aid in*/
/*(select aid from month_prod);*/
/*quit;*/
proc sql;
create table month_trans as
select * from pot.transactions where fin_period="&proc_period";
quit;
proc append base=data.transactions data=month_trans;
run;
/*pierwszy period wyj�tkowo zawsze ca�y akceptowany*/


/*%do n_month=2 %to 3;*/
%do n_month=2 %to &n_prod_periods;
	%let proc_period=%scan(&prod_periods,&n_month,#);
	%let proc_period1=%scan(&prod_periods,%eval(&n_month-1),#);
	%processing(&proc_period,&proc_period1);
%end;
%mend monthly_processing;
%monthly_processing;

%let response_condition=%str(Decision='A' and product='css');
%let response_n_months=6;



proc sql noprint;
select 
'abt.'||memname
into :periods separated by ' '
from dictionary.tables where libname='ABT'
and (memname like 'ABT_1%' or memname like 'ABT_2%');
quit;
/*%put &periods;*/

data abt;
set &periods;
run;
proc sort data=abt;
by aid;
run;
proc sort data=data.decisions out=decision(keep=aid decision);
by aid;
run;
data decision;
merge abt(in=z) decision;
by aid;
if z;
run;


proc sort data=Decision(keep=cid aid period Decision product) 
out=res(keep=cid aid period);
by cid period aid;
where &response_condition;
run;
proc sort data=res nodupkey;
by cid period;
run;
proc transpose data=res out=response(drop=_name_ ) prefix=res_;
by cid;
id period;
var aid;
run;

proc sql noprint;
select distinct 'res_'||trim(period) into :res_periods separated by ' '
from pot.Production order by period;
quit;
%let n_res_periods=&sqlobs;
/*%put &n_res_periods***&res_periods;*/

%let first_period=%substr(%scan(&res_periods,1,%str( )),5);
%put &first_period;

proc sort data=Decision out=prod(keep=cid aid period);
by cid;
run;
data response_cal;
length cross_aid &res_periods $16 cross_response 8;
array res_aid(&n_res_periods) &res_periods;
merge prod(in=z) response;
by cid;
if z;
index=intck('month',input("&first_period",yymmn6.),input(period,yymmn6.))+2;
max_index=index+&response_n_months-2;
cross_aid='';
cross_response=0;
cross_after_monhs=.;
if 1<=index<=&n_res_periods and 1<=max_index<=&n_res_periods then 
	do i=max_index to index by -1;
		if not missing(res_aid(i)) then do;
			cross_response=1;
			cross_aid=res_aid(i);
			cross_after_monhs=i-index+1;
		end;
/*		zm_index=vname(res_aid(index));*/
/*		zm_max_index=vname(res_aid(max_index));*/
	end;
keep aid cid period cross_aid cross_response cross_after_monhs;
run;

proc sort data=response_cal;
by aid;
run;
data response_cal2;
merge response_cal(in=z) pot.default(keep=aid default:);
by aid;
if z;
run;


proc sort data=decision;
by aid;
run;
proc sort data=response_cal2;
by cross_aid;
run;
data response_cal3;
merge response_cal2(in=z) 
	pot.default(keep=aid default:
		rename=(aid=cross_aid 
		default3=default_cross3
		default6=default_cross6
		default9=default_cross9
		default12=default_cross12))
	decision(keep=aid app_loan_amount app_n_installments
	rename=(aid=cross_aid 
	app_loan_amount=cross_app_loan_amount 
	app_n_installments=cross_app_n_installments))
;
by cross_aid;
if z;
run;

proc sort data=response_cal3;
by aid;
run;

data data.abt_app;
merge decision(in=z) response_cal3;
by aid;
if z;
run;

sasfile data.Decisions close;
proc sort data=data.Decisions force;
by aid;
run;
data data.Decisions;
merge data.Decisions(in=z) data.abt_app(keep=aid default: cross:);
by aid;
if z;
year=compress(put(input(period,yymmn6.),year4.));
run;
sasfile data.Decisions load;

data data.profit;
set data.decisions;
if product='ins' then do;
	lgd=&lgd_ins;
	apr=&apr_ins/12;
	provision=&provision_ins;
end;
if product='css' then do;
	lgd=&lgd_css;
	apr=&apr_css/12;
	provision=&provision_css;
end;

if default12 in (0,.i,.d) then default12=0;
EL=0;
if default12=1 then EL=app_loan_amount*lgd;
installment=app_loan_amount*apr*((1+apr)**app_n_installments)/
(((1+apr)**app_n_installments)-1);
Income=0;
if default12=0 then Income=app_n_installments*installment
	+app_loan_amount*(provision-1);
Profit=income-el;
run;


proc format;
picture procent (round)
low- -0.005='00 000 000 009,99%'
(decsep=',' 
dig3sep=' '
fill=' '
prefix='-')
-0.005-high='00 000 000 009,99%'
(decsep=',' 
dig3sep=' '
fill=' ')
;
run;


%macro make_reports(years,yeare);
data ass;
label2="Somers' D"; nvalue2=0;
do i=1 to 8;
output;
end;
drop i;
run;
ods listing close;
ods output Association(persist=proc)=ass;
proc logistic data=data.decisions;
model default12=pd;
where product='css' and "&years"<=year<="&yeare";
run;
proc logistic data=data.decisions;
model default12=pd;
where product='ins' and "&years"<=year<="&yeare";
run;
proc logistic data=data.decisions;
model default_cross12=cross_pd;
where "&years"<=year<="&yeare";
run;
proc logistic data=data.decisions;
model cross_response=pr;
where "&years"<=year<="&yeare";
run;

proc logistic data=data.decisions;
model default12=pd;
where product='css' and "&years"<=year<="&yeare" and decision='A';
run;
proc logistic data=data.decisions;
model default12=pd;
where product='ins' and "&years"<=year<="&yeare" and decision='A';
run;
proc logistic data=data.decisions;
model default_cross12=cross_pd;
where "&years"<=year<="&yeare" and decision='A';
run;
proc logistic data=data.decisions;
model cross_response=pr;
where "&years"<=year<="&yeare" and decision='A';
run;
ods output close;
ods listing;
data ass2;
length des $20 Gini 8 type $10;
set ass;
Gini=nvalue2;
if _n_=1 then do; des='PD on css'; type='All'; end;
if _n_=2 then do; des='PD on ins'; type='All'; end;
if _n_=3 then do; des='Cross PD on cross'; type='All'; end;
if _n_=4 then do; des='PR on cross'; type='All'; end;
if _n_=5 then do; des='PD on css'; type='Accepted'; end;
if _n_=6 then do; des='PD on ins'; type='Accepted'; end;
if _n_=7 then do; des='Cross PD on cross'; type='Accepted'; end;
if _n_=8 then do; des='PR on cross'; type='Accepted'; end;
format gini nlpct12.2;
keep Gini des type;
where label2="Somers' D";
run;


ods listing close;
ods html path="&dir.process/reports/" (url=none)
body="profit_&years._&yeare..html" style=statistical;

title "Production and risk";
proc tabulate data=data.profit;
class decision year product;
var app_loan_amount default12;
table year='' all, 
n='N'*(product='' all)*decision=''*app_loan_amount=''*f=nlnum14.
pctn<decision>='Pct'*(product='' all)*decision=''*app_loan_amount=''*f=procent.
sum='Amount'*(product='' all)*decision=''*app_loan_amount=''*f=nlnum14.
mean='Risk'*(product='' all)*decision=''*default12=''*f=nlpct12.2
/ box='Year';
where "&years"<=year<="&yeare";
run;

title "Profit, income and loss";
proc tabulate data=data.profit;
class decision year product;
var profit income el;
table year='' all, 
sum='Profit'*(product='' all)*decision=''*profit=''*f=nlnum14.
sum='Income'*(product='' all)*decision=''*income=''*f=nlnum14.
sum='Loss'*(product='' all)*decision=''*el=''*f=nlnum14.
/ box='Year';
where "&years"<=year<="&yeare";
run;

title "Decline reasons, risk rules";
proc tabulate data=data.profit;
class decline_reason product;
var app_loan_amount default12 profit;
table product,decline_reason='' all, 
n='N'*app_loan_amount=''*f=nlnum14.
colpctn='Pct'*app_loan_amount=''*f=procent.
sum='Amount'*app_loan_amount=''*f=nlnum14.
mean='Risk'*default12=''*f=nlpct12.2
sum='Profit'*profit=''*f=nlnum14.
/ box='Decline reason';
where "&years"<=year<="&yeare";
run;

title "Probabilities of default and response";
proc tabulate data=data.profit;
class decision year product;
var pd cross_pd pr;
table year='' all, 
mean=''*(pd='PD' cross_pd='Cross PD' pr='PR')*(decision='' all)*f=nlpct12.2
/ box='Year';
where "&years"<=year<="&yeare";
run;

title "Predictive measures for models";
proc tabulate data=ass2;
class type des;
var gini;
table des='', max=''*type='Gini'*gini=''*f=nlpct12.2 / box='Model';
run;

ods html close;
ods listing;

%mend;

%make_reports(1975,1987);
/*%make_reports(1988,1998);*/
