* Turn on SYBMBOLGEN option to see how macro variables are resolved in log;
* global system option MPRINT to view the macro code with the 
macro variables resolved;
options SYMBOLGEN MPRINT;
/********-*********-*********-*********-*********-*********-*********/
/* Description of Program                                           */
/********-*********-*********-*********-*********-*********-*********/
* program:    RDC3-master.SAS
* task:       Run all do-files associated with project
* project:    Texas Census Research Data Center Workshop on 
*             project management
* author:     Nathanael Rosenheim \ Jan 21 2015*;
/*-------------------------------------------------------------------*/
/* Important Folder Locations                                        */
/*-------------------------------------------------------------------*/
%LET rootdir = C:\Users\Nathanael\Dropbox\MyProjects\RDC3\;
* Where is the source data?;
%LET dd_data = &rootdir.Source\;
* Where will the sas7bdat files be saved?;
%LET dd_SASLib = &rootdir.;
/*-------------------------------------------------------------------*/
/* Define SAS Library                                                */
/*-------------------------------------------------------------------*/
%let library = Derived;
LIBNAME &library "&dd_SASLib.SAS_Derived";

/********-*********-*********-*********-*********-*********-*********/
/* Obtain Data                                                      */
/********-*********-*********-*********-*********-*********-*********/
* Data downloaded and located in RootDir/Source/;
/********-*********-*********-*********-*********-*********-*********/
/* Scrub Data - Derive Stata Files from Sources                     */
/********-*********-*********-*********-*********-*********-*********/
* Create Population Estimates SAS file from CSV;
PROC IMPORT DATAFile = "&dd_data.SAIPE_est10ALL.xls" 
	DBMS = XLS OUT = &library..SAIPE_est10ALL REPLACE;
	DATAROW=3;
	GETNAMES = NO;
	MIXED = YES;
RUN;
* Clean SAIPE Excel Files;
DATA &library..SAIPE_2010_All_messy REPLACE;
	SET &library..SAIPE_est10ALL;
	IF A = "" THEN DELETE;
	IF B = "" THEN DELETE;
	stfips = input(A, Best12.); 
	County = input(B,Best12.);
	State = input(C,$CHAR2.);
	CountyName = input(D,$CHAR20.);
	Year = 2010;
	PALL = input(H,comma15.);
	PALLLB = input(I,comma15.);
	PALLUB = input(J,comma15.);
RUN;
* Drop the original variables to create an unsorted or messy temp file;
DATA &library..SAIPE_2010_All REPLACE;
	SET &library..SAIPE_2010_All_messy (DROP = A B C D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE);
RUN;
* Add Merge ID - FIPS County SAIPE Data;
DATA &library..SAIPE_2010_All_id REPLACE;
	SET &library..SAIPE_2010_All;
	 If stfips LT 10 Then do;
	 	StateFP = "0" || PUT(stfips, 1.);
		If County LT 10  Then 
			FIPS_County =  "0" || PUT(stfips, 1.) || "00" || PUT(County, 1.);
		ELSE If County LT 100  Then  
			FIPS_County =  "0" || PUT(stfips, 1.) || "0" || PUT(County, 2.);
		ELSE If County LT 1000  Then  
			FIPS_County =  "0" || PUT(stfips, 1.) || PUT(County, 3.);
		End;
	Else If stfips LT 100 Then do;
		StateFP = PUT(stfips, 2.);
		If County LT 10  Then 
			FIPS_County =  PUT(stfips, 2.) || "00" || PUT(County, 1.);
		ELSE If County LT 100  Then  
			FIPS_County =  PUT(stfips, 2.) || "0" || PUT(County, 2.);
		ELSE If County LT 1000  Then  
			FIPS_County =  PUT(stfips, 2.) || PUT(County, 3.);
		End;
RUN;
* Add labels;
Data &library..SAIPE_2010_All_labeled;
	Set &library..SAIPE_2010_All_id;
	LABEL 
		StateFP = "State FIPS"
		FIPS_County = "County FIPS"
		State = "Postal"
		CountyName = "Name"
		PALL = "Estimated percent of people of all ages in poverty"
		PALLLB = "90% CI LB of estimate of percent of people of all ages in poverty"
		PALLUB = "90% CI UB of estimate of percent of people of all ages in poverty"
run;
* Sort Data;
DATA &library..SAIPE_2010_All_labeled REPLACE;
	Retain
		FIPS_County
		Year;
	SET &library..SAIPE_2010_All_labeled;
RUN;
/*------------------------------------------------------------------*/
/* Clean Data - Final scrub - Save File to Clean Folder             */
/*------------------------------------------------------------------*/
%let library = Cleaned;
LIBNAME &library "&dd_SASLib.SAS_Clean";

Proc Sort data = Derived.SAIPE_2010_All_labeled
	out = &library..RDC3_SAIPE_POP_2010_TX;
	by FIPS_county year;
Run;
