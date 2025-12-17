/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */

%let prefix_dir=c:\karol\analiza6_poziom_klienta\project\students\11111\modele\risk_ins\;
%let em_nodedir=&prefix_dir.modele\;

%let em_import_data=abt.train_woe;
%let em_import_validate=abt.valid_woe;

%let em_lib=wyj;

/*definicje zbiorów traningowego i walidacyjnego*/
%let zb=abt.train;
%let zb_v=abt.valid;
%let zb_vg=;

/*definicja zmiennych*/
%let em_data_variableset=wyj.Zmienne_definicja;

/*zmienna ze scorami*/
%let zm=SCORECARD_POINTS;
/*zmienna z defaultem*/
/*%let porz_tar=descending; dla response*/
%let porz_tar=; 
/*dla risk*/
%let tar=default12;

%let nr_mod=1;
%let the_best_model=1;

libname abt "&prefix_dir.abt" compress=yes;
libname wyj "&prefix_dir.wyj";

libname modele "&prefix_dir.modele";
libname freq "&prefix_dir.freq";
libname adj "&prefix_dir.adj";

libname inlib "c:\karol\analiza6_poziom_klienta\project\students\11111\data1_all\" compress=yes;

%macro power(dataset,variable,default); 
	data power;
		powerpercent=.;
	run;

	proc sort data=&dataset(keep=&default &variable) out=pow_tmp1;
		by &variable;
	run;

	data pow_tmp2 / view=pow_tmp2;
		set pow_tmp1;
		integd+&default;
		integpcurve+integd;
		count+1;
	run;

	/*wersja Karola*/
	data power;
	    retain first;
		set pow_tmp2 end=e;
		if e;
		powerabs=integpcurve-integd/2; 
		powerden=integd*(count-integd)/2;
		powerpercent=(powerabs-count*integd/2)/powerden;
		format powerpercent percent10.2;
	run;
%mend power;

%macro powerc(dataset,variable,default); 
	data power;
		powerpercent=.;
	run;
	data powertable;
		set &dataset(keep=&variable &default);
		crit=-&variable;
	run;
	proc rank data=powertable out=tmp1 ties=high descending;
		var crit;
		ranks rang;
	run;

	proc sql;
		create table tmp2 as
		select
			rang,
			sum(&default) as defaults,
			count(*) as nobs 
		from tmp1 
		group by rang;
	quit;

	data tmp3;
		set tmp2;
		cumdef+defaults;
	run;

	data power;
		set tmp3 end=e;
		format powerpercent percent5.2;
		powerabs+nobs*defaults/2+(cumdef-defaults)*nobs; 
		powerden=cumdef*cumdef/2+cumdef*(rang-cumdef)-rang*cumdef/2;
		powerpercent=(powerabs-rang*cumdef/2)/powerden;
		if _error_=1 then _error_=0;
		if e;
	run;
%mend powerc;

%macro dodatkowe_zmienne;
outstanding=app_loan_amount;
credit_limit=app_loan_amount;

where '197501'<=period<='198712' and product='ins';
%mend;

%let kat_kody=&prefix_dir.kody\;

%let in_abt=inlib.abt_app;
%let prop=0.8;

/*%let in_abt=inlib.abt_beh;*/
/*%let prop=0.04;*/

/**/
/*%let prop=2;*/
/*%let prop=0.02;*/
/*%let prop=0.25;*/
/*%let prop=0.08;*/

%include "&kat_kody.train_valid.sas" / source2;

proc sql;
create table inlib.labels as
select name, label from dictionary.columns
where libname='ABT' and memname='TRAIN';
quit;


%include "&kat_kody.definicja_zmiennych.sas" / source2;


/*maksymalna liczba podzia³ów minus 1*/
%let max_il_podz=5;
/*minimalna liczba obs w liœciu*/
%let min_percent=3;
%include "&kat_kody.sklejanie_jakosciowych.sas" / source2;

%let min_percent=3;
%include "&kat_kody.podzialy_bez_sklejania.sas" / source2;



/*maksymalna liczba podzia³ów minus 1*/
%let max_il_podz=5;
/*minimalna liczba obs w liœciu*/
%let min_percent=3;
%include "&kat_kody.tree.sas" / source2;


%macro calc_design;
%include "&kat_kody.kodowanie.sas" / source2;
%include "&kat_kody.variable_pre_selection_beh.sas" / source2;
data &em_lib..dobre_zmienne_beh;
set wyj.zmienne_stat_beh;
keep _variable_;
where ar_train>0.05;
run;
%include "&kat_kody.variable_pre_selection_full.sas" / source2;
data &em_lib..dobre_zmienne;
set wyj.zmienne_stat;
keep _variable_;
where ar_train>0.05 and .<abs(AR_Diff)<0.2 
and .<H_Br_GRP_TV<0.1 and .<H_GRP_TV<0.1
;
run;
%include "&kat_kody.kopiowanie_design.sas" / source2;
%mend;



%let jakie_podzialy_nominalne=wyj.Podzialy_nom_sklejane;
/*%let jakie_podzialy_nominalne=wyj.Podzialy_nom;*/

proc datasets lib=adj nolist kill;
quit;
%let inset=wyj.Podzialy_int_niem;
%let design=_non_mon;
/*%include "&kat_kody.poprawki_zmiennych.sas" / source2;*/
%calc_design;
data wyj.chosen_variables;
set wyj.Dobre_zmienne;
zmienna=upcase(_VARIABLE_);
keep zmienna;
run;
%include "&kat_kody.raporty_zmiennych.sas" / source2;


%include "&kat_kody.steps_selection.sas" / source2;
%include "&kat_kody.score_selection.sas" / source2;
/*%include "&kat_kody.modele_experckie.sas" / source2;*/

/*%let insets=wyj.Steps_models;*/
/*%let insets=wyj.Branch_expert;*/
%let insets=wyj.Branch_models;
/**/
%let zm=SCORECARD_POINTS;
%include "&kat_kody.ocena_modeli.sas" / source2;
%let zm=SCORECARD_POINTS;

%let il_seed=100;
/*%let il_seed=10000;*/
/*%let il_seed=20000;*/
%include "&kat_kody.Bootstrap_validation.sas" / source2;
%include "&kat_kody.CI_gini.sas" / source2;

%include "&kat_kody.final_report.sas" / source2;


%include "&kat_kody.kod_skorowanie.sas" / source2;
