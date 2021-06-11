*SET THE DATA DIRECTORY

cd 

clear

*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*AI Paper Master File
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************
*************************************************************************************************************************************************

*Construct the AIOE - Data Appendix A

*Set up the input slopes
use application_list, clear

keep applications binary_all

rename binary_all score

*The file mturk_mapping_matrix is the AI Application-Occupational Ability Matrix and is presented in Data Appendix D
merge 1:1 applications using mturk_mapping_matrix

drop _merge

*Replace each of the matrix scores w/ the score from the "EFF". In this case these are the random numbers.
foreach x of varlist oralcomprehension-writtenexpression {
replace `x' = score*`x'
}

*Now transpose the data and create a variable for the variable name so we get the ONET abilities.
xpose, clear varname

*Drop the observations of blanks and the score variable for the EFF scores (_varname="applications" or "score" or "application_id")
drop if (_varname=="application_id")| (_varname=="applications")| (_varname=="score")

*Now I need to aggregate an impact score for all of these. If the matrix had been made up of values other than one, there would have already been some weighting, either way, I will create an overall score.
egen onet_score=rowtotal(v1-v10)

*Rename varname to element to match the onet dataset.
rename _varname onet_element

save _binary_all, replace


*Generate the ability level scores
keep onet_element onet_score
rename onet_element ability

egen ability_exposure=std(onet_score)

keep ability ability_exposure

*This is the ability-level exposure presented in Data Appendix E
save ability_exposure, replace 

use abilities_2020, clear

*At this point, I want to merge this data with the ONET data. Rename the element to match and lower case it and remove all spaces and hyphens. 
rename elementname onet_element

replace onet_element=lower(onet_element)

replace onet_element=subinstr(onet_element," ", "", .)

replace onet_element=subinstr(onet_element,"-", "", .)

*Create scaled version of the scores and create the values across each occupation-element combo.
gen scale_importance=datavalue/5 if scaleid=="IM"

gen scale_level=datavalue/7 if scaleid=="LV"

egen level_scaled=max(scale_level), by(onetsoccode elementid)

egen importance_scaled=max(scale_importance), by(onetsoccode elementid)

gen scalar=level_scaled*importance_scaled

keep onetsoccode onetsoccode onet_element importance_scaled level_scaled scalar

duplicates drop

egen ability_base=sum(scalar), by(onetsoccode)

*I want to generate a score for how much an occupation relies on cognitive abilities. Flag cognitive abilities
gen cognitive=0
replace cognitive=1 if onet_element=="categoryflexibility"
replace cognitive=1 if onet_element=="deductivereasoning"
replace cognitive=1 if onet_element=="flexibilityofclosure"
replace cognitive=1 if onet_element=="fluencyofideas"
replace cognitive=1 if onet_element=="inductivereasoning"
replace cognitive=1 if onet_element=="informationordering"
replace cognitive=1 if onet_element=="mathematicalreasoning"
replace cognitive=1 if onet_element=="memorization"
replace cognitive=1 if onet_element=="numberfacility"
replace cognitive=1 if onet_element=="oralcomprehension"
replace cognitive=1 if onet_element=="oralexpression"
replace cognitive=1 if onet_element=="originality"
replace cognitive=1 if onet_element=="perceptualspeed"
replace cognitive=1 if onet_element=="problemsensitivity"
replace cognitive=1 if onet_element=="selectiveattention"
replace cognitive=1 if onet_element=="spatialorientation"
replace cognitive=1 if onet_element=="speedofclosure"
replace cognitive=1 if onet_element=="timesharing"
replace cognitive=1 if onet_element=="visualization"
replace cognitive=1 if onet_element=="writtencomprehension"
replace cognitive=1 if onet_element=="writtenexpression"


*Do the same for sensory
gen sensory=0
replace sensory=1 if onet_element=="auditoryattention"
replace sensory=1 if onet_element=="depthperception"
replace sensory=1 if onet_element=="farvision"
replace sensory=1 if onet_element=="glaresensitivity"
replace sensory=1 if onet_element=="hearingsensitivity"
replace sensory=1 if onet_element=="nearvision"
replace sensory=1 if onet_element=="nightvision"
replace sensory=1 if onet_element=="peripheralvision"
replace sensory=1 if onet_element=="soundlocalization"
replace sensory=1 if onet_element=="speechclarity"
replace sensory=1 if onet_element=="speechrecognition"
replace sensory=1 if onet_element=="visualcolordiscrimination"

gen cognitive_scalar=cognitive*scalar
gen sensory_scalar=sensory*scalar

egen cognitive_ability_base=sum(cognitive_scalar), by(onetsoccode)
gen cognitive_perc_ability=cognitive_ability_base/ability_base

egen sensory_ability_base=sum(sensory_scalar), by(onetsoccode)
gen sensory_perc_ability=sensory_ability_base/ability_base

*Generate the remaining percent sensory
gen remaining_sensory_perc=sensory_ability_base/(ability_base-cognitive_ability_base)


egen importance_base=sum(importance_scaled), by(onetsoccode)
egen level_base=sum(level_scaled), by(onetsoccode)


merge m:1 onet_element using _binary_all

*Drop the v1-v10 from the matrix and the _merge value.
drop _merge v*

*Create an impact*onet score variable
gen wtd_element_impact= scalar*onet_score
gen imp_wtd_element_impact= importance_scaled*onet_score
gen lvl_element_impact= level_scaled*onet_score

*Sum by occupation
egen total_weighted_impact=sum(wtd_element_impact), by(onetsoccode)
egen imp_weighted_impact=sum(imp_wtd_element_impact), by(onetsoccode)
egen lvl_weighted_impact=sum(lvl_element_impact), by(onetsoccode)

*I now have a dataset we can use to take to the BLS data. Drop everything but the total_weighted score and the identifier information. Drop dupes.
drop onet_element level_scaled importance_scaled scalar onet_score wtd_element_impact imp_wtd_element_impact lvl_element_impact

duplicates drop

*Change the occ code to match the BLS data then save to combine w/ the BLS
gen onet_soc_map=substr(onetsoccode, 1, 7)

*This creates an average for the mappable soc code
egen avg_wtd_impact=mean( total_weighted_impact), by(onet_soc_map)
egen avg_imp_wtd_impact=mean( imp_weighted_impact), by(onet_soc_map)
egen avg_lvl_wtd_impact=mean( lvl_weighted_impact), by(onet_soc_map)
egen avg_ability_base=mean( ability_base), by(onet_soc_map)
egen avg_importance_base=mean( importance_base), by(onet_soc_map)
egen avg_level_base=mean( level_base), by(onet_soc_map)
egen avg_cognitive_ability_base=mean( cognitive_ability_base), by(onet_soc_map)
egen avg_cognitive_perc_ability=mean( cognitive_perc_ability), by(onet_soc_map)
egen avg_sensory_ability_base=mean( sensory_ability_base), by(onet_soc_map)
egen avg_sensory_perc_ability=mean( sensory_perc_ability), by(onet_soc_map)
egen avg_remaining_sensory_perc=mean( remaining_sensory_perc), by(onet_soc_map)

keep onet_soc_map avg_wtd_impact avg_imp_wtd_impact avg_lvl_wtd_impact avg_ability_base avg_importance_base avg_level_base avg_cognitive_perc_ability avg_sensory_perc_ability avg_remaining_sensory_perc


gen ability_base_impact= avg_wtd_impact/ avg_ability_base

duplicates drop


rename onet_soc_map occ_code
merge 1:1 occ_code using occ_title_2020
keep if _merge==3
drop _merge

egen aioe=std(ability_base_impact)


keep occ_code occ_title aioe



save aioe_2020, replace



*************************************************************************************************************************************************
*************************************************************************************************************************************************
*Construct the AIIE - Data Appendix B


clear 
*Import the 4dig NAICS data
*Occupation employment statistics database
use oes_4dig_naics, clear

*Only keep the granular occupations
keep if o_group=="detailed"

*drop not needed variables
keep tot_emp occ_code naics naics_title

*Will weight by employment
destring tot_emp, replace force

*Merge in the AIOE
merge m:1 occ_code using aioe_2020

*I will drop those that I cannot merge -- either removed from ONET or not listed within industry. 
keep if _merge==3
drop _merge

*Gen total employment within a NAICS based on what's left as well as a share of NAICS emp
egen naics_emp=sum(tot_emp), by(naics)
gen naics_emp_share=tot_emp/naics_emp

*Scale AIOI for occupation by NAICS emp share and then aggregate to NAICS
gen naics_occ_aioe_contrib=aioe*naics_emp_share
egen naics_raw_aiie=sum(naics_occ_aioe_contrib), by(naics)

*keep naics code, description, and score then de-dupe
keep naics naics_title naics_raw_aiie

duplicates drop

*Standardize
egen aiie=std(naics_raw_aiie)

drop naics_raw_aiie 

compress 

save aiie_2020, replace

*Generate this a to merge file to construct the AIGE and help with bringing in the BG data later
*These four digita NAICS classifications provided by QCEW do not map cleanly -- there are some duplicates I am dealing with here
gen naics4=substr(naics, 1, 4)

destring naics4, replace force


egen check=count(naics4), by(naics4)

drop if check>1
drop check

save aiie_data_merge, replace

*************************************************************************************************************************************************
*************************************************************************************************************************************************
*Construct the AIGE (Data Appendix C)

use  county_naics_2019, clear

*Remove those that don't map
gen unknown_tag=substr(area_fips, length(area_fips)-2, 3)

drop if unknown_tag=="999"
drop unknown_tag

gen start_tag=substr(area_fips, 1, 2)
drop if start_tag=="78"
drop start_tag

rename industry_code naics

keep naics area_fips annual_avg_emplvl

egen tot_emp=sum(annual_avg_emplvl), by(naics area_fips)

keep naics area_fips tot_emp

duplicates drop

destring naics, replace force

rename naics naics4

merge m:1 naics4 using aiie_data_merge
keep if _merge==3
drop _merge


*Gen total employment within a NAICS based on what's left as well as a share of NAICS emp
egen fips_emp=sum(tot_emp), by(area_fips)
gen naics_share=tot_emp/fips_emp

*Scale AIOI for occupation by NAICS emp share and then aggregate to NAICS
gen scaled_industry_county=aiie*naics_share
egen county_raw_ai=sum(scaled_industry_county), by(area_fips)


egen aige=std(county_raw_ai)

keep area_fips aige
duplicates drop


save aige_2020, replace




