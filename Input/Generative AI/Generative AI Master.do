cd 
set processors 2

ssc install binscatter 
ssc install egen

foreach sample in  binary_all only_generatingimages only_languagemodeling {

clear

use application_variations, replace

keep applications `sample'

rename `sample' score

merge 1:1 applications using mturk_mapping_matrix

drop _merge

*Replace each of the matrix scores w/ the score from the "EFF". In this case these are the random numbers.
foreach x of varlist oralcomprehension-writtenexpression {
replace `x' = score*`x'
}

*Now transpose the data and create a variable for the variable name so we get the ONET abilities.
xpose, clear varname

*Drop the observations of blanks and the score variable for the EFF scores 
drop if (_varname=="application_id")| (_varname=="applications")| (_varname=="score")

*Now I need to aggregate an impact score for all of these. If the matrix had been made up of values other than one, there would have already been some weighting, either way, I will create an overall score.
egen onet_score=rowtotal(v1-v10)

*Rename varname to element to match the onet dataset.
rename _varname onet_element

save _`sample', replace



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
egen importance_base=sum(importance_scaled), by(onetsoccode)
egen level_base=sum(level_scaled), by(onetsoccode)


merge m:1 onet_element using _`sample'

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

keep onet_soc_map avg_wtd_impact avg_imp_wtd_impact avg_lvl_wtd_impact avg_ability_base avg_importance_base avg_level_base


gen ability_base_impact= avg_wtd_impact/ avg_ability_base

duplicates drop


rename onet_soc_map occ_code
merge 1:1 occ_code using occ_title_2020
keep if _merge==3
drop _merge


egen `sample'_aioe=std(ability_base_impact)

rename ability_base_impact raw_`sample'_aioe

save _`sample', replace

}

*binary all is the aioe
use _binary_all, clear

foreach sample in only_languagemodeling only_generatingimages {

merge 1:1 occ_code using _`sample'
drop _merge

}

drop avg_wtd_impact avg_imp_wtd_impact avg_lvl_wtd_impact avg_importance_base avg_level_base

rename binary_all_aioe aggregate_aioe
rename only_languagemodeling_aioe lm_aioe
rename only_generatingimages_aioe ig_aioe
rename raw_only_languagemodeling_aioe raw_lm_aioe
rename raw_only_generatingimages_aioe raw_ig_aioe


*Bring in the salary data

save generative_ai_aioe, replace

*Generate summary statistics of raw measures
summ raw_lm_aioe, detail
summ raw_ig_aioe
ttest raw_lm_aioe=raw_ig_aioe

*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*FIGURE 1
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************

use generative_ai_aioe, clear

merge 1:1 occ_code using occ_salary_data_2021
drop if _merge==2
drop _merge

merge 1:1 occ_code using occ_required_education
drop _merge

merge 1:1 occ_code using occ_creative_weight
drop _merge


keep occ_code occ_req_education median_salary_2021 avg_creative_weight lm_aioe ig_aioe

*Rename to reshape -- extra underscore for LM so it shows up first
rename ig_aioe aioe_ig
rename lm_aioe aioe__lm

reshape long aioe, i(occ_code) j(application, string)

binscatter aioe median_salary_2021, by(application) line(none) xtitle("Median Salary 2021" "(Thousands of Dollars)") ytitle("Exposure to Generative AI") legend(lab(1 "Language Modeling")lab(2 "Image Generation") ) msymbol(O D) mcolor(dknavy blue*.5) yline(0, lcolor(black))

binscatter aioe occ_req_education, by(application) line(none) xtitle("Occupation Required Education Level") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black)) xlabel(0(2)12)

binscatter aioe avg_creative_weight, by(application) line(none) xtitle("Relative Weight of Creative Abilities") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black)) xlabel(0 "0%" .02 "2%" .04 "4%" .06 "6%" .08 "8%" .1 "10%")


*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*FIGURE 2
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
use generative_ai_aioe, clear

merge 1:1 occ_code using occ_representation
drop if _merge==2
drop _merge

keep occ_code lm_aioe ig_aioe mean_female mean_nonwhite mean_black mean_asian mean_hispanic mean_male mean_white

*Rename to reshape -- extra underscore for LM so it shows up first
rename ig_aioe aioe_ig
rename lm_aioe aioe__lm

reshape long aioe, i(occ_code) j(application, string)

binscatter aioe mean_male, by(application) line(none) xtitle("Percent Male Employment") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black))

binscatter aioe mean_female, by(application) line(none) xtitle("Percent Female Employment") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black))

binscatter aioe mean_white, by(application) line(none) xtitle("Percent White Employment") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black))

binscatter aioe mean_black, by(application) line(none) xtitle("Percent Black Employment") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black))

binscatter aioe mean_asian, by(application) line(none) xtitle("Percent Asian Employment") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black))

binscatter aioe mean_hispanic, by(application) line(none) xtitle("Percent Hispanic Employment") ytitle("Exposure to Generative AI") msymbol(O D) legend(lab(1 "Language Modeling AIOE")lab(2 "Image Generation AIOE") )  mcolor(dknavy blue*.5) yline(0, lcolor(black))


*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*SUPPLEMENTARY MATERIALS 
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************
*******************************************************************************************************************************************************************************

*******************************************************************************************************************************************************************************
*COMPARISON ACROSS MEASURES
*******************************************************************************************************************************************************************************

use generative_ai_aioe, clear

scatter lm_aioe aggregate_aioe, ytitle("Image Generation AIOE") xtitle("All Applications AIOE") graphregion(fcolor(white)) ylabel(-3(1)3) xlabel(-3(1)2)

scatter ig_aioe aggregate_aioe, ytitle("Image Generation AIOE") xtitle("All Applications AIOE") graphregion(fcolor(white)) ylabel(-3(1)3) xlabel(-3(1)2)

scatter ig_aioe lm_aioe, ytitle("Image Generation AIOE") xtitle("Language Modeling AIOE") graphregion(fcolor(white)) ylabel(-3(1)3) xlabel(-3(1)3)


*******************************************************************************************************************************************************************************
*REGRESSION ANALYSIS
*******************************************************************************************************************************************************************************


merge 1:1 occ_code using occ_salary_data_2021
drop if _merge==2
drop _merge

merge 1:1 occ_code using occ_required_education
drop _merge

merge 1:1 occ_code using occ_creative_weight
drop _merge

gen broad_category=substr(occ_code, 1, 2)
destring broad_category, replace force



foreach var in median_salary_2021 occ_req_education avg_creative_weight {
	
	reghdfe `var' lm_aioe c.avg_ability_base, absorb(broad_category) cluster(occ_code)
		outreg2 using "SupplementalTable1.xls", dec(3) append 
		
}


foreach var in median_salary_2021 occ_req_education avg_creative_weight {
	
	reghdfe `var' ig_aioe c.avg_ability_base, absorb(broad_category) cluster(occ_code)
		outreg2 using "SupplementalTable1.xls", dec(3) append 

}




use generative_ai_aioe, clear

merge 1:1 occ_code using occ_representation
drop if _merge==2
drop _merge

gen broad_category=substr(occ_code, 1, 2)
destring broad_category, replace force


foreach var in mean_male mean_female mean_white mean_black mean_asian mean_hispanic {
	
	reghdfe `var' lm_aioe c.avg_ability_base, absorb(broad_category) cluster(occ_code)
		outreg2 using "SupplementalTable2.xls", dec(3) append 

}


foreach var in mean_male mean_female mean_white mean_black mean_asian mean_hispanic {
	
	reghdfe `var' ig_aioe c.avg_ability_base, absorb(broad_category) cluster(occ_code)
		outreg2 using "SupplementalTable2.xls", dec(3) append 

}
