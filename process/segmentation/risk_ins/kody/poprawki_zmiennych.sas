/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */


/*poprwaki dla zmiennych*/


/*data adj.;*/
/*length grp 8 war $300 zmienna $32;*/
/*zmienna="";*/
/*input;*/
/*war=_infile_;*/
/*grp=_n_;*/
/*cards;*/
/*;*/
/*run;*/

data adj.ACT_AGE;
length grp 8 war $300 zmienna $32;
zmienna="ACT_AGE";
input;
war=_infile_;
grp=_n_;
cards;
not missing(ACT_AGE) and ACT_AGE <= 35
35 < ACT_AGE <= 44
44 < ACT_AGE <= 56
56 < ACT_AGE <= 65
65 < ACT_AGE <= 68
68 < ACT_AGE
;
run;


