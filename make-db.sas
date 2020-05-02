libname hosp10 '...\hospital data\2010';
libname hosp11 '...\hospital data\2011';
libname hosp12 '...\hospital data\2012';
libname hosp13 '...\hospital data\2013';
libname hosp14 '...\hospital data\2014';
libname hosp15 '...\hospital data\2015';
libname hosp16 '...\hospital data\2016';
libname hosp17 '...\hospital data\2017';
libname hosp18 '...\hospital data\2018';
libname lookup '...\Lookup Tables';
libname project '...\Dashboard report';
%let curr_yr=2018;
%let curr_qtr=4;
%let curr_per=&curr_yr&curr_qtr;
%let icd9=3; 	* The last quarter when ICD-9-CM was active, for placing the ICD-9-CM lines on plots;
%macro start_qtr(cy, cq);
  %global first_yr first_qtr;
  %if &cq=4 %then %do;
    %let first_yr = %eval(&cy-3);
    %let first_qtr = 1;
   %end; 
  %else %do;
    %let first_yr = %eval(&cy-4);
    %let first_qtr = %eval(&cq+1);
  %end;
%mend;
%start_qtr(&curr_yr, &curr_qtr);
/*%put(&first_yr); %put(&first_qtr);*/
%global type; 
/*%let type=IP; %let heading=Hospital discharges; %let dsource=Inpatient Hospitalization Claims Files;*/
%let type=ED; %let heading=ED visits; %let dsource=Outpatient Services Claims Files;
*%let max_pop_yr=2013;
%let manner_list=('1','2','3','4');	* 6th digits (manner of injury) for ICD-10-CM injury codes;
%let encounter_list=('A','D'); * 7th digit (encounter type) for ICD-10-CM injury codes;

*********************;
** QUALITY CONTROL **;
*********************;

***********************;
** CREATE INDICATORS **;
***********************;

*** NUMERATORS - INPATIENTS ***

* Select current quarter of IP data plus the previous 11 quarters;
  data selectIP; set hosp18.inp2018 hosp17.inp2017 hosp16.inp2016 hosp15.inp2015 hosp13.inp2013 hosp14.inp2014;
    if pat_stat='21' && FACTYPE='A';
    *first_yr = %eval(&curr_yr-3);
    *first_qtr = mod(%eval(&curr_qtr+1),4);
	disch_yr = input(substr(to_date,5,4),8.); disch_qtr=input(to_qua,8.);
	*x = (disch_yr >= first_yr && disch_qtr >= first_qtr); *y=(disch_yr < &curr_yr OR (disch_yr = &curr_yr && disch_qtr <= &curr_qtr));
	*put disch_yr first_yr disch_qtr first_qtr x y;
	if (disch_yr > &first_yr OR (disch_yr=&first_yr && disch_qtr >= &first_qtr)) && (disch_yr < &curr_yr OR (disch_yr = &curr_yr && disch_qtr <= &curr_qtr)); 
   disch_per = put(disch_yr,4.) || put(disch_qtr,1.);
   ctyfips_c = pat_coun;
  run;
  proc freq data=selectIP; tables disch_yr * disch_qtr / nopct norow nocol; run;
  proc freq data=selectIP; tables disch_per / out=times; run;
  proc sort data=times; by disch_per; run;
  data times; set times; time=_N_; drop COUNT PERCENT; run;

***********************************************************************;
*** NUMERATORS - OUTPATIENTS ***;

* Select current quarter of OP data plus the previous 11 quarters;
  data selectIP; set hosp18.outp2018 hosp17.outp2017 hosp16.outp2016 
                     hosp15.outp2015 hosp13.outp2013 hosp14.outp2014;
    if sm_er='Y' && pat_stat='21' /*&& FACTYPE='A'*/;
    *first_yr = %eval(&curr_yr-3);
    *first_qtr = mod(%eval(&curr_qtr+1),4);
	disch_yr = input(substr(to_date,5,4),8.); disch_qtr=input(to_qua,8.);
	*x = (disch_yr >= first_yr && disch_qtr >= first_qtr); *y=(disch_yr < &curr_yr OR (disch_yr = &curr_yr && disch_qtr <= &curr_qtr));
	*put disch_yr first_yr disch_qtr first_qtr x y;
	if (disch_yr > &first_yr OR (disch_yr=&first_yr && disch_qtr >= &first_qtr)) && (disch_yr < &curr_yr OR (disch_yr = &curr_yr && disch_qtr <= &curr_qtr)); 
   disch_per = put(disch_yr,4.) || put(disch_qtr,1.);
   ctyfips_c = pat_coun;
  run;
  proc freq data=selectIP; tables disch_yr * disch_qtr / nopct norow nocol; run;
  proc freq data=selectIP; tables disch_per / out=times; run;
  proc sort data=times; by disch_per; run;
  data times; set times; time=_N_; drop COUNT PERCENT; run;

********************************************************************;

* Add NCHS rural-urban codes;
  proc sort data=selectIP; by ctyfips_c; run; proc sort data=lookup.nchsurcodes2013; by ctyfips_c; run;
  data selectIP; merge selectIP lookup.nchsurcodes2013; by ctyfips_c; run;
 
* Set indicators and define additional variables;
  data recodeIP; set selectIP; 

  	disch_dt = input(to_date, mmddyy10.); format disch_dt mmddyy10.;

   * Age group;
     length ageGroup $ 6;
     if pat_agey = . then ageGroup='';
	 else if 0 <= pat_agey <= 17 then ageGroup='_0_17';
	 else if 18 <= pat_agey <= 44 then ageGroup='_18_44';
	 else if 45 <= pat_agey <= 64 then ageGroup='_45_64';
	 else if 65 <= pat_agey <= 120 then ageGroup='_65_';
	 else ageGroup='';

   * Gender;
	 if pat_sex in ('M','F') then sex=pat_sex; else sex='';

   * Metro-nonmetro;
     if code2013=. then metro=.; 
     else if code2013 in (1,2,3,4) then metro=1; 
     else if code2013 in (5,6) then metro=0;
	 else metro=.E;

   * Indicators;
    array dx $ diag1-diag25 ecode1-ecode6;
    DO=0; PO=0; T400=0; T402=0; T404=0; T406=0; ME=0; AD=0; BZ=0; HR=0; CO=0; POxAD=0; POxBZ=0; POxHR=0; xALC=0; POxALC=0; ALC=0; NAS=0; HEPA=0; HEPC=0; HIV=0; ENDO=0;
    DD=0; NAD=0; DOxHEPA=0; DOxHEP=0; DOxHIV=0; DOxEND=0; DOxNAS=0; SA=0; SAHEPA=0; SAxHEP=0; SAxHIV=0; SAxEND=0; AP=0; UN=0; DOxAP=0;
	DD_0=0; DD_1=0; DD_2=0; DD_3=0; DD_4=0; DD_5=0; DD_6=0; DD_7=0; DD_8=0; DD_9=0; 
	NAD_2=0; NAD_3=0; NAD_4=0; NAD_5=0; NAD_6=0; NAD_7=0; NAD_8=0; NAD_9=0; OS=0; 	
    TUD=0; CP=0; NP=0; CPS=0; OP=0; DEP=0; ANX=0;
    do i = 1 to 31;		* For records coded in ICD-9-CM;
	  if disch_dt lt '01oct2015'd then do;
	    dx3=substr(dx{i},1,3); dx4=substr(dx{i},1,4); dx5=substr(dx{i},1,5);
		dx4th=substr(dx{i},4,1); dx5th=substr(dx{i},5,1);
  	    if ('960' <= dx3 <= '979') OR ('E850' <= dx4 <= 'E858') OR ('E9500' <= dx5 <= 'E9505') OR 
           ('E9800' <= dx5 <= 'E9805') OR dx5='E9620' then DO=1; 
	    if dx5 in ('96500','96502','96503','96504','96505','96506','96507','96508','96509','E8501','E8502') then PO=1;
        if dx5 in ('96502','E8501') then ME=1;
		ONS=.; OSY=.; * There are no ICD-9-CM equivalents for ICD-10-CM codes T40.2 and T40.4;
        if dx5 in ('96501','E8500') then HR=1;
        if dx4 = '9694' or dx5 = 'E8532' then BZ=1;
        if dx4 = '9685' OR dx5 in ('97081','E8543','E8552') then CO=1;
	    if dx4 = '9690' or dx5 = 'E8540' then AD=1;												* Antidepressants;
	    /*if dx4 in ('9778', '9779') or dx5 in ('E8587', 'E8588') then UN=1;*/					* Unspecified drugs;
	    if dx4 = '9800' or dx5 = 'E8600' then AP=1;												* Alcohol poisoning;
        if dx4 = '7795' then NAS=1;
		if dx4 in('0700','0701') then HEPA=1;
		if dx5 in('07070', '07071', '07041', '07044', '07051', '07054', 'V0262') then HEPC=1;
	    if dx3 in('042','V08') or dx{i}='79571' then HIV=1;
	    if dx4 in('4210','4211','4219','11281') then ENDO=1;
	    if dx3 in ('291','303') or dx4 in ('3050','7903','9800') then ALC=1;
	    if dx3='304' then do; 													* Drug dependence;
          DD=not DO; DD_code=dx{i};  							
	      if dx4th in ('0','7') then DD_0=not DO;
          else if dx4th='1' then DD_1=not DO;
	      else if dx4th='2' then DD_2=not DO;
	      else if dx4th='3' then DD_3=not DO;
	      else if dx4th='4' then DD_4=not DO;
	      else if dx4th='5' then DD_5=not DO;
	      else if dx4th='6' then DD_6=not DO;
	      /*else if dx4th='7' then DD_7=not DO;*/
	      else if dx4th='8' then DD_8=not DO;
	      else if dx4th='9' then DD_9=not DO;
	    end;
	    if dx3='305' && dx4th in ('2','3','4','5','6','7','8','9') then do; 		* Nondependent abuse of drugs (other than alcohol and tobacco);
		  NAD=not DO; NAD_code=dx{i}; 
		  if dx4th='2' then NAD_2=not DO;
	      else if dx4th='3' then NAD_3=not DO;
	      else if dx4th='4' then NAD_4=not DO;
	      else if dx4th='5' then NAD_5=not DO;
	      else if dx4th='6' then NAD_6=not DO;
	      else if dx4th='7' then NAD_7=not DO;
	      else if dx4th='8' then NAD_8=not DO;
	      else if dx4th='9' then NAD_9=not DO;
	    end;
	  end;
	  else do;	* For records coded in ICD-10-CM;
   	    dx3=substr(dx{i},1,3); dx4=substr(dx{i},1,4); dx5=substr(dx{i},1,5);
        dx5th=substr(dx{i},5,1); dx6th=substr(dx{i},6,1); dx7th=substr(dx{i},7,1);
  	    if ('T36' <= dx3 <= 'T50') then do;
		  if dx4 in ('T369','T379','T399','T414','T427','T439','T459','T479','T499') then do;
		    if dx5th in &manner_list then DO=1; 
		  end;
          else if (dx6th in &manner_list) && (dx7th in &encounter_list) then DO=1; 
		end;
	    if (dx4 in ('T400','T402','T403','T404') or dx5 in ('T4060','T4069')) && (dx6th in &manner_list) && (dx7th in &encounter_list) then PO=1;
	    if (dx4 = 'T403') && (dx6th in &manner_list) && (dx7th in &encounter_list) then ME=1;
		if (dx4 = 'T400')  && (dx6th in &manner_list) && (dx7th in &encounter_list) then T400=1; * Opium;
		if (dx4 = 'T402')  && (dx6th in &manner_list) && (dx7th in &encounter_list) then T402=1; * Other opioids;
		if (dx4 = 'T404')  && (dx6th in &manner_list) && (dx7th in &encounter_list) then T404=1; * Synthetic narcotics;
		if (dx4 = 'T406')  && (dx6th in &manner_list) && (dx7th in &encounter_list) then T406=1; * Other narcotics;
	    if (dx4 = 'T401') && (dx6th in &manner_list) && (dx7th in &encounter_list) then HR=1;
        if (dx4 = 'T424') && (dx6th in &manner_list) && (dx7th in &encounter_list) then BZ=1;
        if (dx4 in ('T413','T405')) && (dx6th in &manner_list) && (dx7th in &encounter_list) then CO=1;
	    if (dx4 ='T431' or dx5 in ('T4320','T4321','T4322','T4302','T4301','T4329')) && (dx6th in &manner_list) && (dx7th in &encounter_list) then AD=1;
		if (dx4 = 'T510')  && (dx6th in &manner_list) && (dx7th in &encounter_list) then AP=1;												* Alcohol poisoning;
        /*if dx4 = '7795' then NAS=1;*/
		if dx4 in ('B150','B159') then HEPA=1;
        if dx4 = 'B182' OR dx5 in('B1711', 'B1710', 'B182', 'B1920', 'B1921', 'Z2252') then HEPC=1;
	    if dx3 in('B20','Z21','R75') then HIV=1;
	    if dx3 = 'I39' OR dx4 in('I330','I339','I39') then ENDO=1;
	    /*if dx3 in ('291','303') or dx4 in ('3050','7903','9800') then ALC=1;*/
 		* Drug dependence;
		  if dx4 in ('F112','F122','F132','F142','F152','F162','F192') then DD=~DO; * Excludes alcohol dep F10.2;
		  if dx4 in ('F112') then DD_0 = ~DO;
		  if dx4 = 'F132' then DD_1 = ~DO;
		  if dx4 = 'F142' then DD_2 = ~DO;
		  if dx4 = 'F122' then DD_3 = ~DO;
		  if dx4 = 'F152' then DD_4 = ~DO;
		  if dx4 = 'F162' then DD_5 = ~DO;
		  /*if dx4 = 'F192' then DD_6 = ~DO;*/  * HUGE JUMP;
		* No equivalent for DD_7?;
		* No equivalent for DD_8?;
		* No equivalent for DD_9?;
		* Use or nondependent abuse of drugs;
  		  if dx4 in ('F111','F121','F131','F141','F151','F161','F191','F119','F129','F139','F149','F159','F169','F199') then NAD=~DO; 
		  if dx4 in ('F121','F129') then NAD_2 = ~DO; 		* Cannabis;
		  if dx4 in ('F161','F169') then NAD_3 = ~DO;		* Hallucinogens;
		  if dx4 in ('F131','F139') then NAD_4 = ~DO;		* Sedative, hypnotic, ...;
		  if dx4 in ('F111','F119') then NAD_5 = ~DO;		* Opioids;
		  if dx4 in ('F141','F149') then NAD_6 = ~DO;		* Cocaine;
		  if dx4 in ('F151','F159') then NAD_7 = ~DO;		* Other stimulant;
  		  * No equivalent for NAD_8?;
		* Drug use;
  		/*  if dx4 in ('F119','F129','F191','F149','F159','F169','F199') then USE=~DO;
		  if dx4 in ('F119') then USE_0 = ~DO;	* Opioid;
		  if dx4 = 'F139' then USE_1 = ~DO;		* Sedative, hypnotic ...;
		  if dx4 = 'F149' then USE_2 = ~DO;		* Cocaine;
		  if dx4 = 'F129' then USE_3 = ~DO;		* Cannabis;
		  if dx4 = 'F159' then USE_4 = ~DO;		* Other stimulant;
		  if dx4 = 'F169' then USE_5 = ~DO;		* Hallucinogen;
		  if dx4 = 'F199' then USE_6 = ~DO;	*/	* Other psychoactive substance;
	  end;
    end;

	* Other specified and unspecified drugs;
	  if DO && not (PO or ME or BZ or HR or CO or AD) then OS=1;

	* Overdoses with multiple substances mentioned;
	  if PO and BZ then POxBZ=1; 
      if PO and HR then POxHR=1;
  	  if PO and ALC then POxALC=1;
	  if ALC and (PO OR ME OR BZ OR HR OR CO) then xALC=1;

  	* Comorbid drug overdose and drug-related condition;
	   if DO and HEPA then DOxHEPA=1;
       if DO and HEPC then DOxHEP=1;
       if DO and HIV then DOxHIV=1;
	   if DO and ENDO then DOxEND=1;
       if DO and NAS then DOxNAS=1;

	* Substance abuse and comorbidity with drug-related conditions;
	   SA = (DO or DD or NAD);
	   if SA and HEPA then SAHEPA=1;
       if SA and HEPC then SAxHEP=1;
       if SA and HIV then SAxHIV=1;
	   if SA and ENDO then SAxEND=1;

    if DO or PO or T406 or AD or BZ or HR or CO or xALC or NAS or HEPA or HEPC or HIV or ENDO or TUD 
        or DD or CP or OP or NP or CPS or NAD or SA or OS or DEP or ANX;
  run;
  proc freq data=recodeIP; tables disch_per*(DO DD_0 PO ME ONS OSY AD BZ HR CO POxBZ POxHR xALC NAS HEPA HEPC HIV ENDO NAD) / nopct norow nocol; run;
  proc freq data=recodeIP; tables disch_per*(PO T400 T402 T404 T406) / nopct norow nocol; run;
  proc freq data=recodeIP; tables ageGroup; run;
  proc sort data=recodeIP; by disch_per; run;
  data recodeIP; merge recodeIP times; by disch_per; run;
  data project.recodeIP; set recodeIP; run;

  * ALCOHOL CODES;
* Alcohol related ICD-9-CM codes were considered to be 291.x (alcoholic psychoses), 303.x (alcohol
intoxication and dependence), 305.0 (alcohol abuse), 790.3 (elevated blood alcohol) and 980.0
(toxic effects of ethyl alcohol), with alcohol withdrawal codes excluded. alcoholic cirrhosis of the liver 571.2;

*** DENOMINATORS ***
* Get population data for currently available quarters;
* Project population data for unavailable quarters;
* Recode population file;
* Indicator denominators (population), by quarter;
* Age-adjusted rates for statewide indicators, by quarter (for sparkline plots);

**********************************************************************************;
*** SUMMARIZE INDICATORS BY QUARTER - BOTH OVERALL AND BY DRILL-DOWN VARIABLES ***;
**********************************************************************************;

*** INPATIENT INDICATORS, OVERALL: MOST RECENT QUARTER ***;
  data currIP; set recodeIP; curr_per = "&curr_yr" || "&curr_qtr"; if disch_per=curr_per; run;
  proc means data=currIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
    output out=IP_totals_tr sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  PROC TRANSPOSE data=IP_totals_tr out=IP_totals; run;
  data IP_totals; set IP_totals (rename=(_NAME_=ID COL1=curr_aar)); label ID=' '; if not (ID in ('_TYPE_','_FREQ_')); run;

*** INPATIENT INDICATORS, OVERALL: PAST TWELVE QUARTERS ***;
  proc sort data=recodeIP; by disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
    by disch_per; 
    output out=IP_num sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND;  
  run;
  data IP_num; set IP_num; time=_N_; run;

*** INPATIENT INDICATORS, DRILL-DOWN: MOST RECENT QUARTER ***;
  

*** INPATIENT INDICATORS, DRILL-DOWN: PAST TWELVE QUARTERS, by drill-down group ***;

* Age group;
  proc sort data=recodeIP; by ageGroup disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
    by ageGroup disch_per; 
    output out=IP_ageGroup sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  data IP_ageGroup; set IP_ageGroup; if ageGroup='.' then delete; label ageGroup='Age Group'; run;
  proc sort data=IP_ageGroup; by disch_per; run;
  data IP_ageGroup; merge IP_ageGroup times; by disch_per; run;
  proc sort data=IP_ageGroup; by ageGroup disch_per; run;

* Sex;
  proc sort data=recodeIP; by sex disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
  /*by ageGroup disch_per;*/ by sex disch_per; 
    output out=IP_sex sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD  sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  data IP_sex; set IP_sex; if sex=' ' then delete; label sex='Gender'; run;
  proc sort data=IP_sex; by disch_per; run;
  data IP_sex; merge IP_sex times; by disch_per; run;
  proc sort data=IP_sex; by sex disch_per; run;

* Metro/nonmetro;
  proc sort data=recodeIP; by metro disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
    /*by ageGroup disch_per;*/ by metro disch_per; 
    output out=IP_metro sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  data IP_metro; set IP_metro; if metro=. then delete; label metro='Metro level'; run;
  proc sort data=IP_metro; by disch_per; run;
  data IP_metro; merge IP_metro times; by disch_per; run;
  proc sort data=IP_metro; by metro disch_per; run;

***********************************;
** CREATE THE MAIN CONTROL TABLE **;
***********************************;

  DATA IP_main; 
   INPUT id $1-6 name $7-87 bg order;
   DATALINES;
BR1	  Acute drug poisonings            				 	                          		2 1
BR2   Individual drugs                   			 	                          		0 2
DO    Drug overdoses, Any drug                                                     		1 3
PO    Drug overdoses, Opioids other than heroin	    	                          		0 4
ME	  Drug overdoses, Methadone                         	                       		1 5
AD	  Drug overdoses, Antidepressants                   	                       		0 6
BZ    Drug overdoses, Benzodiazepines                  	                          		1 7
HR    Drug overdoses, Heroin                           	                          		0 8
CO    Drug overdoses, Cocaine                          	                          		1 9
OS    Drug overdoses, Other and unspecified drugs                                  		0 10
BR2   Drug combinations                   			 	                          		1 11
POxBZ Drug overdoses, Opioids other than heroin and benzodiazepines                   		0 12
POxHR Drug overdoses, Heroin in combination with other opioids    		                   		1 13
BR1   Drug dependence (excluding overdoses)             						  		2 16
DD    Drug dependence, Any substance                                               		0 17
DD_0  Opioid-type dependence                                                      		1 18
BR1   Nondependent abuse of drugs (excluding overdoses)                           		2 19
NAD   Nondependent abuse of drugs, Any substance                                   		0 20
NAD_3 Cannabis dependence                                                        		1 21
NAD_5 Opioid abuse                                                                		0 22
BR1   Infectious disease (with or without comorbid drug overdose, abuse, or dependence)	2 23
HEPA  Hepatitis A                                                                       0 24
HEPC  Hepatitis C                         				                          		1 25
HIV   HIV                                 				                          		0 26
ENDO  Endocarditis                        				                          		1 27
BR1   Infectious disease with comorbid drug overdose, abuse, or dependence         		2 28
SAHEPADrug overdose, abuse, or dependence with Hepatitis A                       		0 29 
SAxHEPDrug overdose, abuse, or dependence with Hepatitis C                       		1 30 
SAxHIVDrug overdose, abuse, or dependence with HIV	                              		0 31
SAxENDDrug overdose, abuse, or dependence with Endocarditis                       		1 32
; 
PROC PRINT; RUN; 
/*POxALCPharmaceutical opioids and alcohol                                          		0 14
xALC  Any drug x alcohol                  				                          		1 15*/


* Add current overall indicator value to the main control file;
proc sort data=IP_main; by id; run; proc sort data=IP_totals; by id; run;
data IP_main; merge IP_main IP_totals; by id; run;
proc sort data=IP_main; by order; run;

*******************************************************;
** PRE-PROCESSING OF INDICATORS FOR SENSITIVE VALUES **;
*******************************************************;

* For frequency tables, output the data to a file and count the number of values less than 5;
* Update the main control table with that number.;

* Age group;
  proc means data=IP_ageGroup sum noprint; by ageGroup; 
    output out=IP_ageGroup_freq sum(DO)=DO sum(DD_0)=DD_0 sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC */
                            sum(DD)=DD sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  data IP_ageGroup_freq; set IP_ageGroup_freq; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_ageGroup_freq out=IP_ageGroup_freq_tr; id ageGroup; run;
  data IP_ageGroup_freq_tr; set IP_ageGroup_freq_tr; 
    ageTable=(_0_17<5)+(_18_44<5)+(_45_64<5)+(_65_<5);
    length id $ 6; id=_NAME_; label id=; drop _NAME_;
  run;
   * Merge;
  proc sort data=IP_main; by id; run; proc sort data=IP_ageGroup_freq_tr; by id; run;
  data IP_main; merge IP_main IP_ageGroup_freq_tr; by id; drop _0_17 _18_44 _45_64 _65_; run;
  proc sort data=IP_main; by order; run;

* Sex; 
  proc means data=IP_sex sum noprint; by sex; 
    output out=IP_sex_freq sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  data IP_sex_freq; set IP_sex_freq; if sex='.' then delete; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_sex_freq out=IP_sex_freq_tr; id sex; run;
  data IP_sex_freq_tr; set IP_sex_freq_tr; 
    sexTable=(M<5)+(F<5);
    length id $ 6; id=_NAME_; label id=; drop _NAME_;
  run;
   * Merge;
  proc sort data=IP_main; by id; run; proc sort data=IP_sex_freq_tr; by id; run;
  data IP_main; merge IP_main IP_sex_freq_tr; by id; drop M F; run;
  proc sort data=IP_main; by order; run;

* Metro; 
  proc means data=IP_metro sum noprint; by metro; 
    output out=IP_metro_freq sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
  data IP_metro_freq; set IP_metro_freq; if metro=. then delete; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_metro_freq out=IP_metro_freq_tr; id metro; run;
  data IP_metro_freq_tr; set IP_metro_freq_tr; 
    metroTable=(_0<5)+(_1<5);
    length id $ 6; id=_NAME_; label id=; drop _NAME_;
  run;
   * Merge;
  proc sort data=IP_main; by id; run; proc sort data=IP_metro_freq_tr; by id; run;
  data IP_main; merge IP_main IP_metro_freq_tr; by id; drop _0 _1; run;
  proc sort data=IP_main; by order; run;

* For drill-down trend plots, if there are ANY sensitive values within a stratum of a drill-down variable, ;
* then set all indicator values in that stratum to missing. ;

* Age group;
  proc means data=IP_ageGroup min noprint; by ageGroup; 
    output out=IP_ageGroup_min min(DO)=DO min(PO)=PO min(ME)=ME min(BZ)=BZ min(HR)=HR min(CO)=CO min(AD)=AD
                            min(OS)=OS min(POxBZ)=POxBZ min(POxHR)=POxHR  /*min(POxALC)=POxALC min(xALC)=xALC*/ 
                            min(DD)=DD min(DD_0)=DD_0 min(NAD)=NAD min(NAD_3)=NAD_3 min(NAD_5)=NAD_5 
                            min(HEPA)=HEPA min(HEPC)=HEPC min(HIV)=HIV min(ENDO)=ENDO
                            min(SAHEPA)=SAHEPA min(SAxHEP)=SAxHEP min(SAxHIV)=SAxHIV min(SAxEND)=SAxEND; 
  run;
  data IP_ageGroup_min; set IP_ageGroup_min; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_ageGroup_min out=IP_ageGroup_min_tr; id ageGroup; run;
  data _null_; set IP_ageGroup_min_tr; 
    call symput('id', strip(_NAME_));
    if _0_17 < 5 then call execute("%nrstr(proc sql; update IP_ageGroup set &id=. where ageGroup='_0_17'; quit;)");
    if _18_44 < 5 then call execute("%nrstr(proc sql; update IP_ageGroup set &id=. where ageGroup='_18_44'; quit;)");
    if _45_64 < 5 then call execute("%nrstr(proc sql; update IP_ageGroup set &id=. where ageGroup='_45_64'; quit;)");
    if _65_ < 5 then call execute("%nrstr(proc sql; update IP_ageGroup set &id=. where ageGroup='_65_'; quit;)");
  run;

* Sex; 
  proc means data=IP_sex min noprint; by sex; 
    output out=IP_sex_min min(DO)=DO min(PO)=PO min(ME)=ME min(BZ)=BZ min(HR)=HR min(CO)=CO min(AD)=AD
                            min(OS)=OS min(POxBZ)=POxBZ min(POxHR)=POxHR  /*min(POxALC)=POxALC min(xALC)=xALC*/ 
                            min(DD)=DD min(DD_0)=DD_0 min(NAD)=NAD min(NAD_3)=NAD_3 min(NAD_5)=NAD_5 
                            min(HEPA)=HEPA min(HEPC)=HEPC min(HIV)=HIV min(ENDO)=ENDO
                            min(SAHEPA)=SAHEPA min(SAxHEP)=SAxHEP min(SAxHIV)=SAxHIV min(SAxEND)=SAxEND; 
  run;
  data IP_sex_min; set IP_sex_min; if sex='.' then delete; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_sex_min out=IP_sex_min_tr; id sex; run;
  data _null_; set IP_sex_min_tr; 
    call symput('id', strip(_NAME_));
    if M < 5 then call execute("%nrstr(proc sql; update IP_sex set &id=. where sex='M'; quit;)");
    if F < 5 then call execute("%nrstr(proc sql; update IP_sex set &id=. where sex='F'; quit;)");
  run;

* Metro; 
  proc means data=IP_metro min noprint; by metro; 
    output out=IP_metro_min min(DO)=DO min(PO)=PO min(ME)=ME min(BZ)=BZ min(HR)=HR min(CO)=CO min(AD)=AD
                            min(OS)=OS min(POxBZ)=POxBZ min(POxHR)=POxHR  /*min(POxALC)=POxALC min(xALC)=xALC*/ 
                            min(DD)=DD min(DD_0)=DD_0 min(NAD)=NAD min(NAD_3)=NAD_3 min(NAD_5)=NAD_5 
                            min(HEPA)=HEPA min(HEPC)=HEPC min(HIV)=HIV min(ENDO)=ENDO
                            min(SAHEPA)=SAHEPA min(SAxHEP)=SAxHEP min(SAxHIV)=SAxHIV min(SAxEND)=SAxEND; 
  run;
  data IP_metro_min; set IP_metro_min; if metro=. then delete; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_metro_min out=IP_metro_min_tr; id metro; run;
  data _null_; set IP_metro_min_tr; 
    call symput('id', strip(_NAME_));
    if _0 < 5 then call execute("%nrstr(proc sql; update IP_metro set &id=. where metro=0; quit;)");
    if _1 < 5 then call execute("%nrstr(proc sql; update IP_metro set &id=. where metro=1; quit;)");
  run;

* Update main contorl file with minimum count over past 12 quarters for each indicator. This variable ;
* will be used later to decide whether to produce a history plot or use an "Insufficient data" message instead.;
  proc means data=IP_num min noprint;
    output out=IP_num_min min(DO)=DO min(PO)=PO min(ME)=ME min(BZ)=BZ min(HR)=HR min(CO)=CO min(AD)=AD
                            min(OS)=OS min(POxBZ)=POxBZ min(POxHR)=POxHR  /*min(POxALC)=POxALC min(xALC)=xALC*/ 
                            min(DD)=DD min(DD_0)=DD_0 min(NAD)=NAD min(NAD_3)=NAD_3 min(NAD_5)=NAD_5 
                            min(HEPA)=HEPA min(HEPC)=HEPC min(HIV)=HIV min(ENDO)=ENDO
                            min(SAHEPA)=SAHEPA min(SAxHEP)=SAxHEP min(SAxHIV)=SAxHIV min(SAxEND)=SAxEND; 
  run;
  data IP_num_min; set IP_num_min; drop _TYPE_ _FREQ_; run;
  proc transpose data=IP_num_min out=IP_num_min_tr; run;
  data IP_num_min_tr; set IP_num_min_tr (rename=(col1=hist_min)); length id $ 6; id=_NAME_; label id=; drop _NAME_; run;
  * Merge;
  proc sort data=IP_main; by id; run; proc sort data=IP_num_min_tr; by id; run;
  data IP_main; merge IP_main IP_num_min_tr; by id; run;
  proc sort data=IP_main; by order; run;


*************************************************************************************;
** ASSESS CURRENT TRENDS FOR OVERALL INDICATORS, AND UPDATE THE MAIN CONTROL TABLE **;
*************************************************************************************;
* For trend assessment, use a t test on the estimated LOESS means for the current quarter ;
* and the previous (or twice previous) quarter. Run LOESS, extract estimated means and sigma, ;
* run t test, update control table;

* Add recent/current trend indicators;
  data IP_main; set IP_main; curr_trend=''; run;


********************************;
** CREATE MAIN DASHBOARD PAGE **;
********************************;

* Produce sparkline plots;

  %macro sparkline(var,bg);

    proc template;
     define style mystyle;
     parent=styles.sasweb;
       *class graphwalls / frameborder=off;
       class graphbackground / color=&bg;
	   class graphconfidence / color=cxfee6ce;
     end;
    run;

	ODS HTML CLOSE;
    ODS GRAPHICS / reset=index IMAGENAME = "&var" IMAGEFMT=PNG HEIGHT=0.5in WIDTH=2in NOBORDER;
    ODS LISTING GPATH = "...\Dashboard report\&type\dbtrend_&type" STYLE=mystyle;

    proc sgplot data=IP_num noautolegend noborder;
      loess x=time y=&var / clm clmtransparency=0.25;
      series x=time y=&var / lineattrs=graphdatadefault(pattern=solid);
	  refline &icd9 / axis=x lineattrs=(pattern=2) label='ICD-9-CM';
      xaxis display=none ;
	  *yaxis display=(nolabel);
  	  yaxis display=none;
      title ; footnote; 
    run;
  %mend sparkline;

  data _null_; set IP_main; 
    if bg=0 then call execute('%let back=white'); 
    else if bg=1 then call execute('%let back=cxdeebf7');    
    if not (id in ('BR1','BR2')) then call execute('%sparkline('||id||',&back)');
  run;

* Produce main dashboard table, with links to drill-down pages;
proc format; value mask 1-4 = '*' other=[comma8.]; run;    * Format to suppress small counts;

ods listing close;
ods html file="...\Dashboard report\&type\dbmain_&type..html";
ods escapechar='^';
title;
data _null_; 
  set IP_main end=done;
  if bg=0 then call execute('%let back=white'); 
  else if bg=1 then call execute('%let back=cxdeebf7');    * GRAYEE;
  else if bg=2 then call execute('%let back=cx9ecae1');    * GRAYCC;
  if _n_ eq 1 then
  do;
    declare odsout t();
    t.table_start(overrides: 'frame=void');
      t.row_start();
        t.format_cell(text: '', style_attr: 'bordercolor=white cellpadding=0 cellspacing=0', overrides: 'preimage="header&type..gif" just=l vjust=b', colspan:4);
	  t.row_end();
      t.row_start();
        t.format_cell(text: 'Indicator', style_attr: 'bordercolor=cxdeebf7', overrides: 'vjust=b just=l background=cx3182bd fontweight=bold fontsize=12pt color=cxdeebf7');
        t.format_cell(text: 'Count for current quarter', style_attr: 'bordercolor=cxdeebf7', overrides: 'vjust=b background=cx3182bd fontweight=bold fontsize=12pt color=cxdeebf7');
        *t.format_cell(text: 'Current trend', style_attr: 'bordercolor=white', overrides: 'fontweight=bold fontsize=12pt');
        t.format_cell(text: 'Four-year trend*', style_attr: 'bordercolor=cxdeebf7', overrides: 'vjust=b just=c background=cx3182bd fontweight=bold fontsize=12pt  color=cxdeebf7 cellwidth=4cm');
        t.format_cell(text: 'Detail', style_attr: 'bordercolor=cxdeebf7', overrides: 'vjust=b just=c background=cx3182bd fontweight=bold fontsize=12pt color=cxdeebf7');
      t.row_end();
  end;
  if id = 'BR1' then do;
    t.row_start();
      t.format_cell(text: name, style_attr: 'bordercolor=&back', overrides: 'just=l background=&back fontsize=12pt', colspan:4);
    t.row_end();
  end; else
  if id = 'BR2' then do;
      t.row_start();
        t.format_cell(text: name, style_attr: 'bordercolor=&back', overrides: 'fontstyle=italic just=l background=&back fontsize=12pt', colspan:4);
      t.row_end();
  end; else
  do;
    call symput('sparkpath', "dbtrend_&type/" || strip(id) || ".png");
    call symput('detailpath', "dbdetail_&type/" || strip(id) || ".html");
    t.row_start();
    t.format_cell(text: cat('-- ', name), style_attr: 'bordercolor=&back', overrides: 'just=l vjust=center background=&back  fontsize=12pt');
    t.format_cell(text: curr_aar, format: 'mask', style_attr: 'bordercolor=&back', overrides: 'just=c vjust=center background=&back fontsize=12pt fontweight=bold');
    *if curr_trend = 'UP' then   t.format_cell(text: '', style_attr: 'bordercolor=&back', overrides: "preimage='...\Dashboard report\images\up.png' background=&back");
    *else if curr_trend = 'DN' then   t.format_cell(text: '', style_attr: 'bordercolor=&back', overrides: "preimage='...\Dashboard report\images\down.png' background=&back");
    *else t.format_cell(text: '', style_attr: 'bordercolor=&back', overrides: ' background=&back' );
    if hist_min >=5 then t.format_cell(text: '', style_attr: 'bordercolor=&back', overrides: 'preimage="&sparkpath" background=&back cellwidth=4cm');
    *else t.format_cell(text: '', overrides: "preimage='...\Dashboard report\images\ISD.gif'");
    else t.format_cell(text: 'Insufficient data', overrides: 'vjust=c background=&back fontsize=12pt cellheight=1.75cm cellwidth=4cm');
    *t.image(file: "&&sparkpath");
    t.format_cell(text: 'View', style_attr: 'bordercolor=&back', overrides: /*preimage="magnify.png"*/ 'vjust=c background=&back fontsize=10pt', url: symget('detailpath'));
	*t.format_cell(text: 'Gender', overrides: 'vjust=c', url:"http://kentuckysportsradio.com");
    *t.format_cell(text: 'Urban-Rural', overrides: 'vjust=c', url:"http://kentuckysportsradio.com");
    t.row_end();
  end;
  if done then do;
    t.row_start();
      t.format_cell(colspan: 4, text: '   ', style_attr: 'bordercolor=cxdeebf7', overrides: 'vjust=b just=l background=cx3182bd  fontsize=12pt color=cxdeebf7');
    t.row_end();
	t.row_start();
      t.format_cell(colspan: 4, style_attr: 'bordercolor=white', text: '* Dashed lines on trend plots indicate the last quarter for which patient records were coded to ICD-9-CM. The United States transitioned to ICD-10-CM on October 1, 2015. This should be considered as a possible contributor to any trend changes observed immediately following the transition to ICD-10-CM. Note: ICD-10-CM indicator definitions are preliminary and subject to change.', overrides: 'vjust=b just=l fontsize=12pt');
	t.row_end();
    tday=today();
    month_name=PUT(tday,monname.);
    year=year(tday);
    t.row_start();
    t.format_cell(colspan: 4, style_attr: 'bordercolor=white', text: 'XXXXXXXXXXXXXXXXXXXXXXX', 
                  overrides: 'vjust=b just=l fontsize=12pt', inhibit: 'TLRB');
    t.row_end();
    t.table_end();
  end;
run;

ods html close;


*****************************; *************************************************************************************
*** FIX THE CENSORING     ***; *************************************************************************************
*****************************; ************************************************************************************;

data ip_num2;
	set ip_num;
	POxHR=.;
	SAxEND=.;							*Set censored indicators to missing so they are not plotted;
	SAHEPA=.;                    *Probably get these from IP_num, or running the whole program first;
run;

*AGE GROUP;
  proc sort data=recodeIP; by ageGroup disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
	where disch_yr=2018 && disch_qtr=4;                                                                                             *MAKE THIS THE CURRENT QTR FOR THE TABLES;
    by ageGroup disch_per; 
    output out=IP_ageGroup_tables sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
data IP_ageGroup_tables; 
	set IP_ageGroup_tables; 
	
	HR=.;
	DD_0=.;                              *SET CENSORED INDICATORS TO MISSING. THE BEST WAY TO DO THIS IS PROBABLY TO RUN THE PROCS ABOVE AND LOOK AT THE CREATED _TABLES DS;
	NAD_3=.;
	NAD_5=.;
	SAxHIV=.;
	SAxEND=.;


	if ageGroup='.' then delete; 
	label ageGroup='Age Group'; 
	run;

*SEX;
  proc sort data=recodeIP; by sex disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
	where disch_yr=2018 && disch_qtr=4;                                                                                             *MAKE THIS THE CURRENT QTR FOR THE TABLES;
  /*by ageGroup disch_per;*/ by sex disch_per; 
    output out=IP_sex_tables sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD  sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
data IP_sex_tables; 
	set IP_sex_tables; 
	
	/*ME=.;
	POxHR=.;                           *SET CENSORED INDICATORS TO MISSING. THE BEST WAY TO DO THIS IS PROBABLY TO RUN THE PROCS ABOVE AND LOOK AT THE CREATED _TABLES DS;
	NAD_3=.;*/

	if sex=' ' then delete; 
	label sex='Gender'; 
	run;

*METRO;
  proc sort data=recodeIP; by metro disch_per; run;
  proc means data=recodeIP sum noprint; 
    var DO PO ME AD BZ HR CO OS POxBZ POxHR POxALC xALC DD DD_0 NAD NAD_3 NAD_5 HEPA HEPC HIV ENDO SAHEPA SAxHEP SAxHIV SAxEND; 
	where disch_yr=2018 && disch_qtr=4;                                                                                             *MAKE THIS THE CURRENT QTR FOR THE TABLES;
    /*by ageGroup disch_per;*/ by metro disch_per; 
    output out=IP_metro_tables sum(DO)=DO sum(PO)=PO sum(ME)=ME sum(BZ)=BZ sum(HR)=HR sum(CO)=CO sum(AD)=AD
                            sum(OS)=OS sum(POxBZ)=POxBZ sum(POxHR)=POxHR  /*sum(POxALC)=POxALC sum(xALC)=xALC*/ 
                            sum(DD)=DD sum(DD_0)=DD_0 sum(NAD)=NAD sum(NAD_3)=NAD_3 sum(NAD_5)=NAD_5 
                            sum(HEPA)=HEPA sum(HEPC)=HEPC sum(HIV)=HIV sum(ENDO)=ENDO
                            sum(SAHEPA)=SAHEPA sum(SAxHEP)=SAxHEP sum(SAxHIV)=SAxHIV sum(SAxEND)=SAxEND; 
  run;
data IP_metro_tables; 
	set IP_metro_tables;

	/*ME=.;							*SET CENSORED INDICATORS TO MISSING. THE BEST WAY TO DO THIS IS PROBABLY TO RUN THE PROCS ABOVE AND LOOK AT THE CREATED _TABLES DS;
	POxHR=.;*/

 
	if metro=. then delete; 
	label metro='Metro level'; 
	run;


*****************************;
*** CREATE DETAIL REPORTS ***;
*****************************;

/*ods html; ods graphics /reset=all;*/

proc format; 
  value $ ageFMT '_0_17'='0-17' '_18_44'='18-44' '_45_64'='45-64' '_65_'='65+'; 
  value $ sexFMT 'M'='Male' 'F'='Female' ' '='Unknown'; 
  value metroFMT 1='Metropolitan' 0='Non-metropolitan'; 
  value mask 1-4='*' other=[comma8.];
  value timeFMT  1='15-Q1' 2='15-Q2' 3='15-Q3' 4='15-Q4' 5='16-Q1' 6='16-Q2' 
                 7='16-Q3' 8='16-Q4' 9='17-Q1' 10='17-Q2' 11='17-Q3' 12='17-Q4' 13='18-Q1' 14='18-Q2' 15='18-Q3' 16='18-Q4';
run;
/*%let ind=PO; %put &ind;*/
%macro makeDetailReport(ind, title);
  ods listing close;
  ODS HTML close;
  ODS GRAPHICS / RESET HEIGHT=4in WIDTH=5in /*NOBORDER*/ imagename="&ind";
  %LET date_ = %sysfunc(date(),worddate18.);
  * This is here to set legend options for the other plots. KEYLEGEND statement was giving trouble;
  proc sgplot data=IP_num; series x=time y=&ind; keylegend / autoitemsize title=""; run;

  *ods html file="...\Dashboard report\&type\dbdetail_&type\&ind..html" gpath="...\Dashboard report\&type\dbdetail_&type\";
  ods html path="...\Dashboard report\&type\dbdetail_&type\" file= "&ind..html" gpath="...\Dashboard report\&type\dbdetail_&type\" (url="");
  ODS escapechar='^';
  options orientation=portrait;
  *title "&title: Detail by Age Group, Gender, and Urban Level";
  title;
  ods layout gridded columns=3 column_widths=(2in 4in 3in);
    ods region;
	   *ods text = "^S={just=l preimage='...\logo-black.gif'}";
	   ods text = "^S={just=l vjust=b preimage='../logo-black.gif'}";
	ods region;
       ods text = "^S={font=('Arial',16pt,bold) color=black just=c vjust=t}&title^n&heading^nKentucky Residents";
       ods text = "^S={font=('Arial',12pt,bold) color=black just=c vjust=t}Detail by Age Group, Gender, and Metro Level^n^n";
    ods region;
	   ods text = "^S={just=r vjust=b postimage='../KDPH.gif'}";
   ods region column_span=2;
      proc sgplot noautolegend data=IP_num2;
      loess x=time y=&ind / clm clmtransparency=0.25 NOLEGCLM NOLEGFIT;
	  series x=time y=&ind / name="counts" /*/ lineattrs=graphdatadefault(pattern=solid)*/;
  	  refline &icd9 / axis=x lineattrs=(pattern=2) label='ICD-9-CM*';
	  xaxis values=(1 to 16 by 1) label='Quarter';
	  yaxis  min=0 label="&heading";
	  format time timeFMT.;
      title 'Four-year trend by quarter'; 
    run;

    ods region;
	  proc print data=IP_num noobs label; 
        var time &ind; 
        format &ind mask. time timeFMT.;
		label time='Quarter' &ind=&heading;
        title 'All quarters'; footnote; 
	run;  

    *ODS GRAPHICS / HEIGHT=4in;
  	ods region column_span=2;
      proc sgplot data=IP_ageGroup;
        loess x=time y=&ind / clm clmtransparency=0.5 group=ageGroup;
		series x=time y=&ind / group=ageGroup;
   	    refline &icd9 / axis=x lineattrs=(pattern=2) label='ICD-9-CM*';
        title 'Four-year trend by quarter by age group'; 
		xaxis values=(1 to 16 by 1) label='Quarter';
		yaxis min=0 label="&heading";
		format time timeFMT. ageGroup $ageFMT.;
      run;
    ods region;
	proc print data=IP_agegroup_tables noobs label; 
		where &ind ne .;
		var agegroup &ind;
		label &ind='ED Visits';
		format &ind mask. agegroup $ageFMT.;
		title 'Current quarter'; footnote;
      run;  



  	ods region column_span=2;
      proc sgplot data=IP_sex;
        loess x=time y=&ind / clm clmtransparency=0.5 group=sex;
		series x=time y=&ind / group=sex;
        refline &icd9 / axis=x lineattrs=(pattern=2) label='ICD-9-CM*';
        title 'Four-year trend by quarter by gender';
    	xaxis values=(1 to 16 by 1) label='Quarter';
		yaxis min=0 label="&heading";
		format time timeFMT. sex $sexFMT.;
      run;
    ods region;
	proc print data=IP_sex_tables noobs label; 
		where &ind ne .;
		var sex &ind;
		format &ind mask. sex $sexFMT.;
		label &ind='ED Visits';
		title 'Current quarter'; footnote;
      run;
 

  	ods region column_span=2;
      proc sgplot data=IP_metro;
        loess x=time y=&ind / clm clmtransparency=0.5 group=metro;
        series x=time y=&ind / group=metro;
        refline &icd9 / axis=x lineattrs=(pattern=2) label='ICD-9-CM*';
		format metro metroFMT.;
        title 'Four-year trend by quarter by metro level'; 
		xaxis values=(1 to 16 by 1) label='Quarter';
		yaxis min=0 label="&heading";
		format time timeFMT. metro metroFMT.;
        *keylegend / autoitemsize; 
      run;
    ods region;
	proc print data=IP_metro_tables noobs label; 
		where &ind ne .;
		var metro &ind;
		format &ind mask. metro metroFMT.;
		label &ind='ED Visits';
		title 'Current quarter'; footnote;
      run;


    ods region column_span=3;
	  ods text = "XXXXXXXXXXXXXXXXXXXX";

	 %if &ind = HR %then %do;	
       proc sort data=recodeIP; by comp_ID; run; 
       proc means data=recodeIP sum noprint;
         by comp_ID; var HR; output out=HR_by_hospital sum(HR)=sumHR; where disch_per="&curr_per";
       run; 
	   data HR_by_hospital; set HR_by_hospital; if sumHR = 0 then delete; run;
	   proc sort data=hosp16.faclook2016; by comp_id; run;
	   data mrg; merge HR_by_hospital hosp16.faclook2016; by comp_id; if _FREQ_ ne .; run;
	   proc sort data=mrg; by descending sumHR; run;
       *ods pdf startpage=now;
       ods region column_span=3;
       data _null_; set mrg end=done;
	     if _n_ eq 1 then do;
	       declare odsout t();		   
           t.title(data: "Heroin overdose &heading by hospital for current quarter");
           t.table_start();
           t.row_start();
           t.format_cell(text: 'Hospital', inhibit: 'LRTB', overrides: 'just=l');
           *t.format_cell(text: 'ID', inhibit: 'LRTB');
           t.format_cell(text: "&heading", inhibit: 'LRTB');
           t.row_end();
		 end;
         t.row_start();
		 if mod(_n_,2)=1 then do;
           t.format_cell(data: FULLNAME, overrides: 'background=lightgray just=l', inhibit: 'LRTB');
           *t.format_cell(data: comp_ID, overrides: 'background=lightgray', inhibit: 'LRTB');
           t.format_cell(data: sumHR, format: 'mask', overrides: 'background=lightgray', inhibit: 'LRTB');
		 end;
		 else do;
           t.format_cell(data: FULLNAME, inhibit: 'LRTB', overrides: 'just=l');
           *t.format_cell(data: comp_ID, inhibit: 'LRTB');
           t.format_cell(data: sumHR, format: 'mask', inhibit: 'LRTB');
		 end;
         t.row_end();
		 if done then t.table_end();
	   run;
	%end;
  ods layout end;
  ods html close;
%mend;

data _null_; set IP_main;
  if not (id in ('BR1','BR2')) then do;
  call execute('%makeDetailReport('||id||','||'%bquote('||name||'))');  * %bquote masks commas in category names;
   *%makeGenderReport();
   *%makeUrbanReport();
  end;
run;
*%makeDetailReport(HR, Any drug);


