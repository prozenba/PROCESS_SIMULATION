/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */



%let kat_kodowanie=%sysfunc(pathname(wyj));

/*na razie missing wrzucamy wed³ug porz¹dku 
zale¿nie od tego czy to jest model ryzyka czy response*/
data scorecard;
set modele.Scorecard_Scorecard&the_best_model(
rename=(_variable_=zmienna _label_=war));
otherwise_ind=(war='otherwise');
run;

proc sort data=scorecard
out=p;
by zmienna otherwise_ind &porz_tar br;
run;
proc sql;
create table wyj.Dobre_zmienne_model
as select distinct _variable_
from modele.Scorecard_Scorecard&the_best_model;
quit;
/*teraz prawdziwe skorowanie*/


filename kod "&kat_kodowanie.\kod_do_skorowania.sas";
data _null_;
length przed za $100 naz $300;
file kod;
if _n_=1 then do;
put 'data &zbior._score;';
put 'set &zbior;';
put "&zm = 0;";
end;

do i=1 to ilobs;
set p nobs=ilobs;
by zmienna;

if war ne 'otherwise' then do;
	if first.zmienna then do;
		if substr(war,1,4)='when' then do;
		przed='';za='';
		put "select (" zmienna ");";
		end; else do;
		przed='when (';za=')';
		put "select;";
		end;
	end;

	put przed war za "do;";
	naz="&zm=sum(&zm,"||trim(put(&zm,best12.-L))||');';
	put naz;

	naz="PSC_"||compress(zmienna)||"="||trim(put(&zm,best12.-L))||";";
	put naz;

	put "end;";
end;


if last.zmienna then do;
	put 'otherwise do;';
	naz="&zm=sum(&zm,"||trim(put(&zm,best12.-L))||');';
	put naz;

	naz="PSC_"||compress(zmienna)||"="||trim(put(&zm,best12.-L))||";";
	put naz;

    put 'end; end;';
end;

end;

put "run;";
run;

