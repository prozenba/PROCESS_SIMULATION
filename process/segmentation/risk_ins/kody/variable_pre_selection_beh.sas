/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */



/*options mprint;*/
libname d (wyj);

proc sql;
create table &em_lib..zmienne_wej as
select upcase(zmienna) as name from wyj.karta_duza
group by 1
having max(grp)>1;
quit;


data zmienne_stat_beh;
length _VARIABLE_ $32 ar_train 8;
format ar_train percent12.2;
delete;
run;

%macro validuj_zmienne(train,lista,max_il=1);

data _null_;
set &lista(obs=1) nobs=il;
call symput('il',put(il,best12.-L));
run;
%if (&max_il eq 0 or &max_il>&il) %then %let max_il=&il;
%do i=1 %to &max_il;


data _null_;
set &lista(obs=&i firstobs=&i);
call symput('z_org',name);
run;

%let z_woe=WOE_&z_org;
%let z_grp=GRP_&z_org;
%put &z_woe &z_org &z_grp;

data train_zm;
set &train(keep=&tar &z_woe &z_org &z_grp);
run;

%let ar_train=.;

%if %sysfunc(exist(a)) %then %do;
proc delete data=a;
run;
%end;

ods listing close;
ods output Association=a;
	proc logistic data=train_zm desc;
	model &tar=&z_woe;
	run;
ods output close;
ods listing;

%if %sysfunc(exist(a)) %then %do;
data _null_;
set a;
where label2='c';
ar=2*nvalue2-1;
if _n_=1 then call symput("ar_train",put(ar,best12.-L));
run;
%end;

data z;
length _VARIABLE_ $32 ar_train 8;
format ar_train percent12.2;
_variable_="&z_woe";
ar_train=&ar_train;
run;


proc append base=zmienne_stat_beh data=z;
run;

%end;
%mend;

%validuj_zmienne(&em_import_data,&em_lib..zmienne_wej,max_il=0);

proc sort data=zmienne_stat_beh out=&em_lib..zmienne_stat_beh;
by descending AR_Train ;
/*by descending _gini_;*/
run;





