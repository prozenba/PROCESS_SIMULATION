libname sclib "&scoring_dir";
data sclib.abt_tmp;
set &zbior;
run;

options noxwait;
x "&scoring_dir.score.bat";

data score;
	length SCORECARD_POINTS 8 period $6 aid $16;
	infile "&scoring_dir.outscore.csv" firstobs=2 dlm=',' dsd;
	input SCORECARD_POINTS period aid;
run;
proc sort data=score;
by aid period;
run;
proc datasets lib=work nolist;
modify score;
index create comm=(aid period) / unique;
quit;
data &zbior._score;
set &zbior;
set score key=comm / unique;
if _iorc_ ne 0 then do;
	SCORECARD_POINTS=.;
	_error_=0;
end;
run;
