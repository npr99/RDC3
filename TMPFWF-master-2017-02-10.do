* Preinstall the following programs:
* ssc install estout, replace // to create tables install estout
* ssc install fastcd, replace // great for changing working directory quickly
/*-------1---------2---------3---------4---------5---------6--------*/
/* Start Log File: Change working directory to project directory    */
/*-------1---------2---------3---------4---------5---------6--------*/

capture log close   // suppress error and close any open logs
log using work/TMPFWF-master-2017-02-10, replace text
/********-*********-*********-*********-*********-*********-*********/
/* Description of Program                                           */
/********-*********-*********-*********-*********-*********-*********/
// Do file name structure - where no spaces are included in file name:
	// 3-5 letter project mnemonic [-task] step [letter] [Vversion] 
	// [-description] yyyy-mm-dd.do
// program:    TMPFWF-master-2017-02-10.do
// task:       Demonstrate basic Stata Workflow
// version:    Major Revision Second Draft
// project:    Template Workflow
// author:     Nathanael Rosenheim \ Feb 10, 2017

/*------------------------------------------------------------------*/
/* Control Stata                                                    */
/*------------------------------------------------------------------*/
* Generic do file that sets up stata environment
clear all          // Clear existing data files
macro drop _all    // Drop macros from memory
version 12.1       // Set Version
set more off       // Tell Stata to not pause for --more-- messages
set varabbrev off  // Turn off variable abbreviations
set linesize 80    // Set Line Size - 80 Characters for Readability
*set matsize 5000   // Set Matrix Size if program has a large matrix
*set max_memory 2g  // if the file size is larger than 64M change size

/*-------------------------------------------------------------------*/
/* Set Provenance                                                    */
/*-------------------------------------------------------------------*/
// What is the do file name? What program is needed to replicate results?
global dofilename "TMPFWF-master-2017-02-10" 
global provenance "Provenance: ${dofilename}.do `c(filename)' `c(current_date)'"
global source "Nathanael Rosenheim" // what is the data source
global work workNPR // what is tha name of the Folder to save .do file output?

/*-------------------------------------------------------------------*/
/* Establish Project Directory Structure                             */
/*-------------------------------------------------------------------*/
// What it is the root directory on your computer?
* NOTE * Use forward slash (/) - Recognized by all OS
* NOTE * MacOSX and Windows require different directory structures
// change to project directory
// example: cd c:/dropbox/myprojects/
// Install utility to automate changing directories 'fastcd'
// findit fastcd // to install

* Stata can create folders if they do not exist
capture mkdir Work/${dofilename}     // Folder saves all outputs from do file
global savefolder Work/${dofilename} 

/********-*********-*********-*********-*********-*********-*********/
/* Obtain Data - Populate Source Folder                             */
/********-*********-*********-*********-*********-*********-*********/
* US Census Bureau - Texas County Characteristics Datasets: 
* Annual County Resident Population Estimates by 
* Age, Sex, Race, and Hispanic Origin: April 1, 2010 to July 1, 2013
copy "http://www.census.gov/popest/data/counties/asrh/2013/files/CC-EST2013-ALLDATA-48.csv" ///
     "SourceData/POP_CC-EST2013-ALLDATA-48.csv", replace
copy "http://www.census.gov/popest/data/counties/asrh/2013/files/CC-EST2013-ALLDATA.pdf" ///
     "SourceData/POP_CC-EST2013-ALLDATA-48_Codebook.pdf", replace

* Small Area Income and Poverty Estimates
* Texas County Estimates for 2010
copy "http://www.census.gov/did/www/saipe/downloads/estmod10/est10ALL.xls" ///
     "sourceData/SAIPE_est10ALL.xls", replace
copy "http://www.census.gov/did/www/saipe/downloads/estmod10/README.txt" ///
     "sourceData/SAIPE_est10ALL_Codebook.txt", replace

/********-*********-*********-*********-*********-*********-*********/
/* Scrub Data - Derive Stata Files from Sources                     */
/********-*********-*********-*********-*********-*********-*********/
/* Common scrubbing tasks
- Convert data from one format to another
- Filter observations
- Extract and replace values
- Split, merge, stack, or extract columns */

* Create Population Estimates Stata file from CSV
insheet using "Source/POP_CC-EST2013-ALLDATA-48.csv"
/* create a temporary file */
tempfile POP_CC-EST2013-ALLDATA-48
save "POP_CC-EST2013-ALLDATA-48"

* Create SAIPE Stata file from Excel
import excel "Source/SAIPE_est10ALL.xls", clear
/* create a temporary file */
tempfile SAIPE_est10ALL
save "SAIPE_est10ALL"

* Drop and Add Variables Population File Files
use "POP_CC-EST2013-ALLDATA-48", clear
keep if year == 1   //  4/1/2010 Census population
keep if agegrp == 0 //  Total age groups
keep state county  tot_pop wa* ba* h_* // Keep white, black Hispanic totals
gen tot_wa = wa_male + wa_female // total white alone population
gen tot_ba = ba_male + ba_female // total black alone population
gen tot_h = h_male + h_female // total Hispanic alone population
keep state county tot*        // drop sex variables
/* create a temporary file */
tempfile Pop_2010_TX
save "Pop_2010_TX"

* Clean SAIPE Excel Files
use "SAIPE_est10ALL", clear
drop E-G K-AE      // Do not need variables
rename H PALL      // Poverty Percent All Ages
label variable PALL "Poverty Percent All Ages"
* Example of Stata native variables
drop if _n <= 3    // Drop first 3 rows
keep if A == "48"  // Keep Texas
destring, replace  // Convert Strings to numeric
/* create a temporary file */
tempfile SAIPE_2010_TX
save "SAIPE_2010_TX"

* Add Merge ID - FIPS County Pop Data
use "Pop_2010_TX", clear 
// generated FIPS_Code from State and County Codes
gen str5 FIPS_County = string(state,"%02.0f")+string(county,"%03.0f")
sort FIPS_County
/* create a temporary file */
tempfile Pop_2010_TX_id
save "Pop_2010_TX_id"

* Add Merge ID - FIPS County SAIPE Data
use "SAIPE_2010_TX", clear 
// generated FIPS_Code from State and County Codes
gen str5 FIPS_County = string(A,"%02.0f")+string(B,"%03.0f")
sort FIPS_County
/* create a temporary file */
tempfile SAIPE_2010_TX_id
save "SAIPE_2010_TX_id"

* Merge SAIPE and SEER Data
use "${savefolder}/Pop_2010_TX_id", clear 
merge FIPS_County using "${savefolder}/SAIPE_2010_TX_id"
/* create a temporary file */
tempfile SAIPE_POP_2010_TX
save "SAIPE_POP_2010_TX"

* Drop uneeded variables and reorder
use "${savefolder}/SAIPE_POP_2010_TX", clear
drop state county A B _merge
order FIPS_County D C
/* create a temporary file */
tempfile SAIPE_POP_2010_TX_fltr
save "SAIPE_POP_2010_TX_fltr"

* Add pop percent variables, label new variables
use "SAIPE_POP_2010_TX_fltr", clear
* EXAMPLE OF LOOP
foreach re in wa ba h { // loop through white, black Hispanic
 gen p_`re' = tot_`re' / tot_pop * 100 
 format p_`re' %04.2f //
}
* Label variables
label variable p_wa "Percent White"
label variable p_ba "Percent Black"
label variable p_h  "Percent Hispanic" 
/*------------------------------------------------------------------*/
/* Clean Data - Final scrub - Save File to Clean Folder             */
/*------------------------------------------------------------------*/
saveold "${savefolder}/${dofilename}", replace
outsheet using ///
     "${savefolder}/${dofilename}.csv", comma replace // To use in R
	 
/********-*********-*********-*********-*********-*********-*********/
/* Explore Data - Create Tables and Figures to Interpret            */
/********-*********-*********-*********-*********-*********-*********/
* ssc install estout, replace // to create tables install estout
* Create Table with Descriptive Statistics
use "${savefolder}/${dofilename}", replace
local dscrb_vars PALL p_*  // Variables to describe
capture noisily eststo clear
capture noisily estpost tabstat `dscrb_vars', ///
		statistics(min max p50 mean sd count) columns(statistics)
capture noisily esttab using ///
`"${savefolder}/${dofilename}.rtf"' ///
, alignment(r) replace label gaps modelwidth(6) nonumbers  ///
cells("count(fmt(%4.0f)) min(fmt(%4.2f)) max(fmt(%4.2f)) p50(fmt(%4.2f)) mean(fmt(%4.2f)) sd(fmt(%4.2f))") noobs ///
title(Basic Descriptive Statistics Poverty and Population Data for Texas Counties 2010) ///
addnote("$provenance")
eststo clear

* Create Histogram of poverty
use "${savefolder}/${dofilename}", replace
local graphcaption = "Histogram of Percent Poverty for Texas Counties 2010."
histogram PALL, frequency normal kdensity ///
	title(`graphcaption') ///
	caption("$provenance", size(tiny))
graph export `"${savefolder}/${dofilename}_HistPALL.pdf"', replace
notes: Poverty has a normal distribution

saveold "${savefolder}/${dofilename}", replace
/********-*********-*********-*********-*********-*********-*********/
/* Model Data                                                       */
/********-*********-*********-*********-*********-*********-*********/
* Output Regression Table
use "${savefolder}/${dofilename}", replace
capture noisily eststo: regress PALL p_*

capture noisily  esttab using ///
	`"${savefolder}/${dofilename}.rtf"' ///
	, b(%4.3f) se(%4.3f) ar2 onecell append label modelwidth(6) nonumbers  /// 
	title(Parameter Estimates from Models of Poverty with Race and Ethnicity) ///
	alignment(c) parentheses ///
	addnote("$provenance")
capture noisily eststo clear
notes: Race and ethnicity predictors have significant coef.
notes: Include median income? Will race still be significant?
saveold "${savefolder}/${dofilename}", replace
/********-*********-*********-*********-*********-*********-*********/
/* Interpret Data                                                   */
/********-*********-*********-*********-*********-*********-*********/
notes  // View notes
// Example of how Stata stores regression results
tempname handel1
file open  `handel1' using "${savefolder}/${dofilename}_Interpret.rtf", write replace
file write `handel1' "For Texas in 2010, " 
file write `handel1' "there is a significant association between " 
file write `handel1' "poverty and race." _n
file write `handel1' "The model had `e(N)' counties and " _n
file write `handel1' "an adjusted r-sqaure of `e(r2_a)'. " _n
file write `handel1' "See notes store in ${Provenance}"
file close `handel1' 

/*-------------------------------------------------------------------*/
/* Notes on Data Sources                                             */
/*-------------------------------------------------------------------*/

notes: $provenance

/*-------------------------------------------------------------------*/
/* Generate Codebook                                                 */
/*-------------------------------------------------------------------*/
codebook, compact
notes

* Best option is to use saveold - otherwise collaborators using 
* an early version will not be able to open data files
saveold "${savefolder}/${dofilename}.dta", replace

/*-------------------------------------------------------------------*/
/* End Log                                                           */
/*-------------------------------------------------------------------*/

log close
exit


* NOTE * Nothing below "exit" will run or be included in the log file

eststo, esttab come from estout
For more information on estout see: Making Regression Tables in Stata
     http://repec.org/bocode/e/estout/

/********-*********-*********-*********-*********-*********-*********/
/* QUICK STATA REMINDERS                                            */
/********-*********-*********-*********-*********-*********-*********/
Good resources: 
1. http://data.princeton.edu/stata/
2. http://www.ats.ucla.edu/stat/stata/
3. Programming Stata - http://www.stata.com/manuals13/u18.pdf

Stata is case sensitive - for variable names as well as commands. 
Stata sees a return as then end of a line.

Create indents with spaces instead of tabs - if possible.
Avoid spaces in folder and file names.

Macros - See help macro
/********-*********-*********-*********-*********-*********-*********/
local name = expression      
     `name' defined by expression
      Use for numbers, strings, nested macros ie. name = "`var'`i'"
      During execute in the do-file where created

local name variable list 
     `name' contains list of variables * NOTE * Missing equal sign
      Great for model variables
      During execute in the do-file where created

global same options as local
      $name or ${name} - when using {} name can be nested ${`var'`i'}
	  Great for project name, filter options
      During current Stata session, across all do-files  
	  
STATA If Conditions 
Operator  Meaning
/********-*********-*********-*********/
==        equal to
>         greater than
>=        greater than or equal to
<         less than
<=        less than or equal to\
!= or ~=  not equal to
&         combine operators AND
|         combine operators OR

Stata has two built-in variables called _n and _N. 
_n is Stata notation for the current observation number. 
_n is 1 in the first observation, 2 in the second, 3 in the third, and so on.
_N is Stata notation for the total number of observations.


Comment types
  Comments may be added to programs in three ways:
        o begin the line with *;
        o begin the comment with //; or
        o place the comment between /* and */ delimiters.
		
/// is one way to make long lines more readable
Like the // comment indicator, the /// indicator must be preceded by one or
    more blanks.

Additional ways to control Stata
set varabbrev off  // Turn off variable abbreviations
set linesize 80    // Set Line Size - 80 Characters for Readability

Stata 12 can not read *.dta files saved in Stata 13 
saveold will fix this problem

To create a directory use the command capture mkdir

/********-*********-*********-*********-*********-*********-*********/
/* Excercises                                                       */
/********-*********-*********-*********-*********-*********-*********/
Add Median income and include a second model in the output.

Make the program more robust to run for different states.
