/*  (c) Karol Przanowski   */
/*    kprzan@sgh.waw.pl    */


/*%let design=non_mon;*/
/*%let design=mon_old;*/
/*%let design=mon_new;*/

data wyj.karta_duza&design;
set wyj.karta_duza;
run;
data wyj.Zmienne_stat_beh&design;
set wyj.Zmienne_stat_beh;
run;
data wyj.Zmienne_stat&design;
set wyj.Zmienne_stat;
run;
data wyj.Dobre_zmienne&design;
set wyj.Dobre_zmienne;
run;

