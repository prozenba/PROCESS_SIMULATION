/*silnik decyzyjny modyfikowany przez studenta*/
/* pierwsza wersja wzorcowa*/
/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */
/* pierwsza wersja wzorcowa*/
%macro silnik_decyzyjny(wej,wyj);

data kal;
set &wej;
run;

%let zbior=kal;
%include "&dir.students\&nr_albumu.\kalibracja\model_ins_risk\kod_do_skorowania.sas";

data kal1;
set kal_score;
risk_ins_score=.;
if product='ins' then risk_ins_score=SCORECARD_POINTS;
pd_ins=1/(1+exp(-(-0.032205144*risk_ins_score+9.4025558419)));
drop psc: SCORECARD_POINTS;
run;

%let zbior=kal1;
%include "&dir.students\&nr_albumu.\kalibracja\model_css_risk\kod_do_skorowania.sas";


data kal2;
set kal1_score;
risk_css_score=.;
if product='css' then risk_css_score=SCORECARD_POINTS;
pd_css=1/(1+exp(-(-0.028682728*risk_css_score+8.1960829753)));
drop psc: SCORECARD_POINTS;
run;


%let zbior=kal2;
%include "&dir.students\&nr_albumu.\kalibracja\model_cross_css_risk\kod_do_skorowania.sas";


data kal3;
set kal2_score;
risk_cross_css_score=SCORECARD_POINTS;
pd_cross_css=1/(1+exp(-(-0.028954669*risk_cross_css_score+8.2497434934)));
drop psc: SCORECARD_POINTS;
run;


%let zbior=kal3;
%include "&dir.students\&nr_albumu.\kalibracja\model_response\kod_do_skorowania.sas";


data kal4;
set kal3_score;
response_score=SCORECARD_POINTS;
pr=1/(1+exp(-(-0.035007455*response_score+10.492092793)));
drop psc: SCORECARD_POINTS;
run;

/*%let pd_css=0.1913;*/
%let pd_css=0.2724;
/*%let pd_css=0.3654;*/


%let pd_ins1=0.0819;
%let pd_ins2=0.0218; %let pr2=0.028;
/*%let pd_ins1=0.0795;*/
/*%let pd_ins2=0.0225; %let pr2=0.028;*/



data &wyj;
length cid $10 aid $16 product $3 period $6 decision $1 decline_reason $20
app_loan_amount app_n_installments pd cross_pd pr 8;

set kal4;
decision='A';
decline_reason='999ok';

cross_pd=pd_cross_css;
pd=.;
if product='ins' then pd=pd_ins;
if product='css' then pd=pd_css;


if product='css' and pd_css>&pd_css then do;
	decision='D';
	decline_reason="1 PD cut-off on css";
end;
if product='ins' and pd_ins>0.0461 then do;
	decision='D';
	decline_reason="2 PD cut-off on ins";
end;

/*if product='ins' and &pd_ins1>=pd_ins>&pd_ins2 */
/*	and (pr<&pr2 or pd_cross_css>&pd_css) then do;*/
/*	decision='D';*/
/*	decline_reason="3 PD,PDCross and PR cut-offs on ins";*/
/*end;*/

/*if (act_cins_n_statB>0 or act_ccss_n_statB>0) then do;*/
/*	decision='D';*/
/*	decline_reason='0 bad customer';*/
/*end;*/


/*if agr12_Max_CMaxA_Due>3 then do;*/
/*	decision='D';*/
/*	decline_reason='0 bad customer';*/
/*end;*/

if period<'197501' then do;
	decision='A';
	decline_reason='999ok';
end;

if product='css' and act_cus_active ne 1 then do;
	decision='N';
	decline_reason='998 not active customer';
end;

keep
cid aid product period decision decline_reason app_loan_amount 
app_n_installments pd cross_pd pr;
format pd cross_pd pr nlpct12.2;
run;
%mend;
