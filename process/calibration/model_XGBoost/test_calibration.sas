/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */

/* model calibration process, cut-off calculation, to make a profitable products */

options mprint;
options nomprint;

%let dir=c:\karol\oferta_zajec\CS-AUT\software\PROCSS_SIMULATION\;

libname data "&dir.process\data\" compress=yes;

%let apr_ins=0.01;
%let apr_css=0.18;
%let lgd_ins=0.45;
%let lgd_css=0.55;
%let provision_ins=0;
%let provision_css=0;



data cal;
set data.abt_app;
if default12 in (0,.i,.d) then default12=0;
where '197501'<=period<='198712' and decision='A';
run;

%let zbior=cal;
%let scoring_dir=&dir.process\calibration\model_XGBoost\;
%include "&scoring_dir.scoring_code.sas";

data cal1;
set cal_score;
risk_ins_score=.;
if product='css' then risk_css_score=SCORECARD_POINTS;
drop SCORECARD_POINTS;
run;

proc logistic data=cal1 desc outest=bety;
model default12=risk_css_score;
output out=test p=p;
run;



