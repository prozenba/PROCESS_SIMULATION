options set=MAS_M2PATH="C:\Program Files\SASHome\SASFoundation\9.4\tkmas\sasmisc\mas2py.py";
options set=MAS_PYPATH="C:\Users\splpir\Anaconda3\python.exe";

libname sclib "&scoring_dir";
data sclib.indata;
set &zbior;
run;

proc fcmp;
   declare object py(python);
   rc = py.rtinfile("&scoring_dir.score.py");
   put rc=;
   rc = py.publish();
   rc = py.call("model_call", 
		"&scoring_dir", "&scoring_dir", 'xgb1.model', "indata",0);
   Result = py.results["model_call"];
   put Result=;
run;

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
