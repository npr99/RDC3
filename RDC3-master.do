capture log close master  // suppress error and close any open logs
log using RDC3-master, name(master) replace text
// program:    RDC3-master.do
// task:       Demonstrate basic Stata Workflow
// version:    First draft
// project:    Texas Census Research Data Center Workshop on 
//             project management
// author:     Nathanael Rosenheim \ Jan 30 2015

clear all          // Clear existing data files
macro drop _all    // Drop macros from memory
version 10       // Set Version
set more off       // Tell Stata to not pause for --more-- messages

// What it is the root directory on your computer?
* NOTE * Use forward slash (/) - Recognized by all OS
* NOTE * MacOSX and Windows require different directory structures
// change to project directory
// example: cd c:/dropbox/myprojects/
// Install utility to automate changing directories 'fastcd'
// findit fastcd // to install


* Stata can create folders if they do not exist
capture mkdir RDC3             // Project directory
cd RDC3
capture mkdir Source           // Original, unchanged data sources
capture mkdir Derived          // Constructed from the source data
capture mkdir Clean            // Data to explore and interpret
capture mkdir Tables_Figures   // Output Tables and Figures
capture mkdir Text             // Text to share

/********-*********-*********-*********-*********-*********-*********/
/* Obtain Data - Populate Source Folder                             */
/********-*********-*********-*********-*********-*********-*********/
* US Census Bureau - Texas County Characteristics Datasets: 
* Annual County Resident Population Estimates by 
* Age, Sex, Race, and Hispanic Origin: April 1, 2010 to July 1, 2013
copy "http://www.census.gov/popest/data/counties/asrh/2013/files/CC-EST2013-ALLDATA-48.csv" ///
     "Source/POP_CC-EST2013-ALLDATA-48.csv", replace
copy "http://www.census.gov/popest/data/counties/asrh/2013/files/CC-EST2013-ALLDATA.pdf" ///
     "Source/POP_CC-EST2013-ALLDATA-48_Codebook.pdf", replace

* Small Area Income and Poverty Estimates
* Texas County Estimates for 2010
copy "http://www.census.gov/did/www/saipe/downloads/estmod10/est10ALL.xls" ///
     "source/SAIPE_est10ALL.xls", replace
copy "http://www.census.gov/did/www/saipe/downloads/estmod10/README.txt" ///
     "source/SAIPE_est10ALL_Codebook.txt", replace

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
save "derived/POP_CC-EST2013-ALLDATA-48.dta", replace 

* Create SAIPE Stata file from Excel
import excel "Source/SAIPE_est10ALL.xls", clear
save "derived/SAIPE_est10ALL.dta", replace 

* Drop and Add Variables Population File Files
use "derived/POP_CC-EST2013-ALLDATA-48.dta", clear
keep if year == 1   //  4/1/2010 Census population
keep if agegrp == 0 //  Total age groups
keep state county  tot_pop wa* ba* h_* // Keep white, black Hispanic totals
gen tot_wa = wa_male + wa_female // total white alone population
gen tot_ba = ba_male + ba_female // total black alone population
gen tot_h = h_male + h_female // total Hispanic alone population
keep state county tot*        // drop sex variables
save "derived/Pop_2010_TX", replace 

* Clean SAIPE Excel Files
use "derived/SAIPE_est10ALL.dta", clear
drop E-G K-AE      // Do not need variables
rename H PALL      // Poverty Percent All Ages
label variable PALL "Poverty Percent All Ages"
* Example of Stata native variables
drop if _n <= 3    // Drop first 3 rows
keep if A == "48"  // Keep Texas
destring, replace  // Convert Strings to numeric
save "derived/SAIPE_2010_TX", replace 

* Add Merge ID - FIPS County Pop Data
use "derived/Pop_2010_TX", clear 
// generated FIPS_Code from State and County Codes
gen str5 FIPS_County = string(state,"%02.0f")+string(county,"%03.0f")
sort FIPS_County
save "derived/Pop_2010_TX_id", replace 
* Add Merge ID - FIPS County SAIPE Data
use "derived/SAIPE_2010_TX", clear 
// generated FIPS_Code from State and County Codes
gen str5 FIPS_County = string(A,"%02.0f")+string(B,"%03.0f")
sort FIPS_County
save "derived/SAIPE_2010_TX_id", replace 

* Merge SAIPE and SEER Data
use "derived/Pop_2010_TX_id", clear 
merge FIPS_County using "derived/SAIPE_2010_TX_id" 
save "derived/SAIPE_POP_2010_TX", replace

* Drop uneeded variables and reorder
use "derived/SAIPE_POP_2010_TX", clear
drop state county A B _merge
order FIPS_County D C
save "derived/SAIPE_POP_2010_TX_fltr", replace

* Add pop percent variables, label new variables
use "derived/SAIPE_POP_2010_TX_fltr", clear
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
save "clean/RDC3-SAIPE_POP_2010_TX", replace
outsheet using ///
     "clean/RDC3-SAIPE_POP_2010_TX.csv", comma replace // To use in R
	 
/********-*********-*********-*********-*********-*********-*********/
/* Explore Data - Create Tables and Figures to Interpret            */
/********-*********-*********-*********-*********-*********-*********/
* ssc install estout, replace // to create tables install estout
* Create Table with Descriptive Statistics
use "clean/RDC3-SAIPE_POP_2010_TX", replace
local dscrb_vars PALL p_*  // Variables to describe
capture noisily eststo clear
capture noisily estpost tabstat `dscrb_vars', ///
		statistics(min max p50 mean sd count) columns(statistics)
capture noisily esttab using ///
`"tables_figures/RDC3-Tables.rtf"' ///
, alignment(r) replace label gaps modelwidth(6) nonumbers  ///
cells("count(fmt(%4.0f)) min(fmt(%4.2f)) max(fmt(%4.2f)) p50(fmt(%4.2f)) mean(fmt(%4.2f)) sd(fmt(%4.2f))") noobs ///
title(Basic Descriptive Statistics Poverty and Population Data for Texas Counties 2010) ///
addnote("`c(filename)' `c(current_date)'")
eststo clear

* Create Histogram of poverty
use "clean/RDC3-SAIPE_POP_2010_TX", replace
local graphcaption = "Histogram of Percent Poverty for Texas Counties 2010."
histogram PALL, frequency normal kdensity ///
	title(`graphcaption') ///
	caption("`c(filename)' `c(current_date)'", size(tiny))
graph export `"tables_figures/HistPall.pdf"', replace
notes: Poverty has a normal distribution
save "clean/RDC3-SAIPE_POP_2010_TX", replace
/********-*********-*********-*********-*********-*********-*********/
/* Model Data                                                       */
/********-*********-*********-*********-*********-*********-*********/
* Output Regression Table
use "clean/RDC3-SAIPE_POP_2010_TX", replace
capture noisily eststo: regress PALL p_*

capture noisily  esttab using ///
	`"tables_figures/RDC3-Tables.rtf"' ///
	, b(%4.3f) se(%4.3f) ar2 onecell append label modelwidth(6) nonumbers  /// 
	title(Parameter Estimates from Models of Poverty with Race and Ethnicity) ///
	alignment(c) parentheses ///
	addnote("`c(filename)' `c(current_date)'")
capture noisily eststo clear
notes: Race and ethnicity predictors have significant coef.
notes: Include median income? Will race still be significant?
save "clean/RDC3-SAIPE_POP_2010_TX", replace
/********-*********-*********-*********-*********-*********-*********/
/* Interpret Data                                                   */
/********-*********-*********-*********-*********-*********-*********/
notes  // View notes
// Example of how Stata stores regression results
tempname handel1
file open  `handel1' using "text/RDC3-Interpret.rtf", write replace
file write `handel1' "For Texas in 2010, " 
file write `handel1' "there is a significant association between " 
file write `handel1' "poverty and race." _n
file write `handel1' "The model had `e(N)' counties and " _n
file write `handel1' "an adjusted r-sqaure of `e(r2_a)'. " _n
file write `handel1' "See notes store in `c(filename)'"
file close `handel1' 

/********-*********-*********-*********-*********-*********-*********/
/* End Log                                                          */
/********-*********-*********-*********-*********-*********-*********/

log close master 
* Exit Program
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
