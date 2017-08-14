*! version 1.0.1  15may2017 based on permute.ado (version 2.7.3  16feb2015).
***** next revision, rename all "sampling" "resampling" to "[re]randomization"
* this might also include "resampvar"

cap program drop ritest
cap program drop RItest
cap program drop permute_extfile
cap program drop permute_simple
cap program drop rit_Results
cap program drop rit_GetResults
cap program drop rit_DisplayResults
cap program drop rit_GetEvent
cap program drop rit_TableFoot 
cap program drop ClearE

program ritest
	version 11

	set prefix ritest

	capture syntax [anything] using [, * ]
	if !c(rc) {
		if _by() {
			error 190
		}
		Results `0'
		exit
	}

	quietly ssd query
	if (r(isSSD)) {
		di as err " not possible with summary statistic data"
		exit 111
	}
	

	preserve
	`version' RItest `0'
end

program RItest, rclass
	version 11
	local ritestversion "0.0.5"
	// get name of variable to permute
	gettoken resampvar 0 : 0, parse(" ,:")
	confirm variable `resampvar'
	unab resampvar : `resampvar'

	// <my_stuff> : <command>
	_on_colon_parse `0'
	local command `"`s(after)'"'
	local 0 `"`s(before)'"'
	
	syntax anything(name=exp_list			///
		id="expression list" equalok)		///
		[fw iw pw aw] [if] [in] [,		///
			FORCE				///
			noDROP				///
			Level(passthru)			///
			*				/// other options
		]

	if "`weight'" != "" {
		local wgt [`weight'`exp']
	}

	// parse the command and check for conflicts
	// check all weights and stuff
	`version' _prefix_command ritest `wgt' `if' `in' , ///
		`efopt' `level': `command'

	if "`force'" == "" & `"`s(wgt)'"' != "" {
		// ritest does not allow weights unless force is used
		local 0 `s(wgt)'
		syntax [, NONOPTION ]
	}

	local version	`"`s(version)'"'
	local cmdname	`"`s(cmdname)'"'
	local cmdargs	`"`s(anything)'"'
	local wgt	`"`s(wgt)'"'
	local wtype	`"`s(wtype)'"'
	local wexp	`"`s(wexp)'"'
	local cmdopts	`"`s(options)'"'
	local rest	`"`s(rest)'"'
	local efopt	`"`s(efopt)'"'
	local level	`"`s(level)'"'
	// command initially executed using entire dataset
	local xcommand	`"`s(command)'"'
	if "`drop'" != "" {
		// command with [if] [in]
		local command	`"`s(command)'"'
	}
	else {
		// command without [if] [in]
		local command	`"`cmdname' `cmdargs' `wgt'"'
		if `"`cmdopts'"' != "" {
			local command `"`:list retok command', `cmdopts'`rest'"'
		}
		else	local command `"`:list retok command'`rest'"'
		local cmdif	`"`s(if)'"'
		local cmdin	`"`s(in)'"'
	}
	
	//now check the options
	local 0 `", `options'"'
	syntax  [,			///
		noDOTS			///
		Reps(integer 100)	///
		SAving(string)		///  
		SAVEResampling(string)		///  save resampvar for every round
		SAVERAndomization(string) ///  synonym for the above
		DOUBle			/// not documented (handles double precision)
		STRata(varlist)		///
		CLUster(varlist)        ///
		SEED(string)		///
		EPS(real 1e-7)		/// -Results- options
		SAMPLINGSourcefile(string)          ///
		RANDOMIZATIONSourcefile(string) ///syno ^
		SAMPLINGMatchvar(varlist)   ///
		RANDOMIZATIONMatchvar(string) ///syno ^
		SAMPLINGProgram(name)		///
		RANDOMIZATIONProgram(string) ///syno ^
		SAMPLINGPROGRAMOptions(string) ///
		RANDOMIZATIONPROGRAMOptions(string) ///syno ^
		null(string) ///
		NOIsily			/// "prefix" options
		LEft RIght		/// 
		STRict			///
		noHeader		///  not documented
		noLegend		///  not documented
		NOANALYtics		/// 
		COLLApse		/// not documented an not recommendet
		KDENSityplot	/// 
		KDENSITYOptions(string)	///  not documented
		*			///
	]
	_get_diopts diopts, `options' //this makes sure no false options are passed

	***AT version 1.0.1 I switched from calling things "Sampling*" to calling them "Randomization*". The following is to create backwardscompatibility and to make sure the code doesnt need to be changed
	if ("`saveresampling'"=="") {
		local saveresampling  `saverandomization'
	} 
	else {
		di as err "You're using deprecated syntax -saveresampling-, please use -saverandomization- instead"
	}
	if ("`samplingsourcefile'"=="") {
		local samplingsourcefile  `randomizationsourcefile'
	}
	else {
		di as err "You're using deprecated syntax -samplingsourcefile-, please use -randomizationsourcefile- instead"
	}
	if ("`samplingmatchvar'"=="") {
		local samplingmatchvar `randomizationmatchvar'
	}
	else {
		di as err "You're using deprecated syntax -samplingmatchvar-, please use -randomizationmatchvar- instead"
	}
	if ("`samplingprogram'"=="") {
		local samplingprogram  `randomizationprogram'
	}
	else {
		di as err "You're using deprecated syntax -samplingprogram-, please use -randomizationprogram- instead"
	}
	if ("`samplingprogramoptions'"=="") {
		local samplingprogramoptions  `randomizationprogramoptions'
	}
	else {
		di as err "You're using deprecated syntax -samplingprogramoptions-, please use -randomizationprogramoptions- instead"
	}
	
	if (("`strata'" != "" | "`cluster'" !=  "") + ("`samplingsourcefile'" != "" | "`samplingmatchvar'" !=  "")  + ("`samplingprogram'" != "" | "`samplingprogramoptions'" !=  "") )>1    {
		di as err "Alternative sampling methods may not be combined."
		exit 198
	}
	if "`saveresampling'"!="" {
		tempvar originalorder
		tempfile preservetemp
		gen `originalorder'=_n
		qui save `"`saveresampling'"'
	}
	if "`strata'" == "" {
            tempvar strata
            gen `strata' = 1
        }
    if "`cluster'" == "" {
            tempvar cluster 
            gen `cluster' = _n
    }

        
    // set the seed
	if "`seed'" != "" {
		`version' set seed `seed'
	}
	local seed `c(seed)'
   
	if "`noisily'" != "" {
		local dots nodots
	}
	local nodots `dots'
	local dots = cond("`dots'" != "", "*", "_dots")
	local noi = cond("`noisily'"=="", "*", "noisily")

	if "`samplingsourcefile'"!="" { //check if samplingsourcefile is okay and sort
            preserve
            qui use "`samplingsourcefile'", clear
            qui sort `samplingmatchvar', stable
            qui desc
            if (r(k)-1)<`reps' {
                di as err "Permutation dataset does not contain enough permutations to complete `reps' repetitions"
                exit 2001
            }
            qui save `"`samplingsourcefile'"', replace
            restore
    }

	// preliminary parse of <exp_list>
	_prefix_explist `exp_list', stub(_pm_)
	local eqlist	`"`s(eqlist)'"'
	local idlist	`"`s(idlist)'"'
	local explist	`"`s(explist)'"'
	local eexplist	`"`s(eexplist)'"'

	_prefix_note `cmdname', `nodots'
	if "`noisily'" != "" {
		di "ritest: First call to `cmdname' with data as is:" _n
	
	}
     
	// run the command using the entire dataset (for output)
	`command'

	preserve
	if ("`null'"!="") {
		di as text "User specified non-zero null hypothesis" 
		local vari : word 1 of `null'
		local valu : word 2 of `null'
		capture confirm variable `vari'
		if (_rc != 0) {
			di as err "Hypotheses seem to be misspecified, `vari' is not a variable in the current data set"
			exit 9
		}
		cap confirm number `valu'
		if (_rc!=0) {
			capture confirm variable `valu'
		}
		if (_rc != 0) {
			di as err "Hypotheses seem to be misspecified, second argument to hypothesis has to be numeric or a varialbe name"
			exit 9
		}
		di as text "Under the null hypothesis:" 
		di as text " `vari' has treatment effect: `resampvar'*`valu'"
		qui replace `vari' = `vari' - `resampvar'*`valu'
		di as text " (these values are being subtracted from the outcome)"
	}

				

	_prefix_clear, e r
	// run the command using the entire dataset (to get the estimate)
	qui `noisily'		///
                `command'
	// expand eexp's that may be in eexplist, and build a matrix of the
	// computed values from all expressions
	tempname b
	_prefix_expand `b' `explist',		///
		stub(_pm_)			///
		eexp(`eexplist')		///
		colna(`idlist')			///
		coleq(`eqlist')			///

    local k_eq	`s(k_eq)'
	local k_exp	`s(k_exp)'   //number of expressions
	local k_eexp	`s(k_eexp)'  //number of eexpressions
	local K = `k_exp' + `k_eexp' //number of expression + eexprsessions
	local k_extra	`s(k_extra)'
	local names	`"`s(enames)' `s(names)'"'
	local coleq	`"`s(ecoleq)' `s(coleq)'"'
	local colna	`"`s(ecolna)' `s(colna)'"'
	forval i = 1/`K' {
		local exp`i' `"`s(exp`i')'"'
	}
	// setup list of missings
	forvalues j = 1/`K' {
		local mis `mis' (.)
		if missing(`b'[1,`j']) {
			di as err ///
			`"'`exp`j''' evaluated to missing in full sample"'
			exit 322
		}
	}


	local ropts	eps(`eps')		///
			`left' `right'		///
			`strict'             ///
			level(`level')		///
			`header'		///
			`verbose'		///
			`title'			///
			`table'			///
			`diopts'

	// check options
	if `reps' < 1 {
		di as err "reps() must be a positive integer"
		exit 198
	}
	if `"`saving'"'=="" {
		tempfile saving
		local filetmp "yes"
	}
	else {
		_prefix_saving `saving'
		local saving	`"`s(filename)'"'
		if "`double'" == "" {
			local double	`"`s(double)'"'
		}
		local replace	`"`s(replace)'"'
	}
	if `"`strata'"' != "" {
		if `:list resampvar in strata' {
			di as err "permutation variable may not be specified in strata() option"
			exit 198
		}
		tempvar sflag touse
		mark `touse'
		markout `touse' `strata'
		sort `touse' `strata', stable
		by `touse' `strata': gen `sflag' = _n==1 if `touse'
		qui replace `sflag' = sum(`sflag')
		local nstrata = `sflag'[_N]
		local ustrata `strata'
		local strata `sflag'
		sort `strata' , stable
		
		qui loneway `resampvar' `strata'
		if (r(sd_w) == 0){
			di as err "Warning: some strata contain no variation in `resampvar'"
		}
	}
	if `"`cluster'"' != "" {
		if `:list resampvar in strata' {
			di as err "permutation variable may not be specified in strata() option"
			exit 198
		}
		tempvar cflag touse
		mark `touse'
		markout `touse' `strata' `cluster'  
		sort  `touse' `strata' `cluster' , stable
		by `touse' `strata' `cluster': gen `cflag' = _n==1 if `touse'
		qui replace `cflag' = sum(`cflag')
		local N_clust = `cflag'[_N]
		local clustvar `cluster'
		local cluster `cflag'
		sort  `strata' `cluster', stable
		
		qui loneway `resampvar' `cflag'
		if (r(sd_w) != 0 & !missing(r(sd_w))) {
			di as err "`resampvar' doesnt seem to be constant within clusters"
			exit 9999
		}
	}
    
	
	local obs = _N
	local method 0
	if "`samplingsourcefile'"!="" | "`samplingmatchvar'"!="" {
            local method extfile
	}
	else if "`samplingprogram'"!="" {
            local method program
			cap program list `samplingprogram'
			if _rc!=0 {
				di as err "proceedure -`samplingprogram'- does not exists"
				exit 198
			}
	}
	else {
            local method permute
    }

	if `eps' < 0 {
		di as err "eps() must be greater than or equal to zero"
		exit 198
	}
	
	// temp variables for post
	local stats
	forvalues j = 1/`K' {    //fore each expression generate a tempvar
		tempname x`j'
		local stats `stats' (`b'[1,`j'])
		local xstats `xstats' (`x`j'')
	}

	// prepare post
	tempname postnam
	postfile `postnam' `names' using `"`saving'"', ///
		`double' `every' `replace'
	post `postnam' `stats'

	//methods such as "external file" or "automatic permuations" are wrapped in the third one
	if "`method'"=="permute" {
		local samplingprogram permute_simple
		local samplingprogramoptions "strata(`strata')     cluster(`cluster')"
    }
	else if "`method'"=="extfile" {
		local samplingprogram permute_extfile
		local samplingprogramoptions `"file("`samplingsourcefile'")      matchvars(`samplingmatchvar')"'
    }
	
	if ("`noanalytics'"=="") 	{ //This is the GOOGLE-ANALYTICS bit
		set timeout1 1 //make sure this doesnt cause the code to halt for longer periods
		set timeout2 1
		tempfile foo
		cap copy "https://www.google-analytics.com/collect?payload_data&z=`:di round(runiform()*1000)'&v=1&tid=UA-65758570-2&cid=5555&t=pageview&dp=`method'&dt=Stata`di:  version'-$S_OS-$S_OSDTL&el=plain`kdensityplot'" `foo', replace
		set timeout1 30
		set timeout2 180
	}
	if "`dots'" == "*" {
		local noiqui noisily quietly
	}

	// do permutations
	if "`nodots'" == "" | "`noisily'" != "" {
		di
		_dots 0, title(Resampling replications) reps(`reps') `nodots'
	}
	local rejected 0
	forvalues i = 1/`reps' {
		cap `samplingprogram', run(`i') resampvar(`resampvar') `samplingprogramoptions'
		if _rc!=0 {
			di as err "Failed while calling resampling proceedure. Call was: " _n "{stata `samplingprogram', run(`i') resampvar(`resampvar') `samplingprogramoptions'}" _n as text "Error was: " 
			error _rc
		}	
     	if "`saveresampling'"!="" {
			qui 	 `preservetemp',replace
			rename `resampvar' `resampvar'`i'
			cap qui merge 1:1 `originalorder' using `"`saveresampling'"', gen(_m`i')
			rename `originalorder' keep`originalorder'
			drop __*
			rename keep`originalorder' `originalorder'
			cap order `resampvar'* _m*, last
			qui save `"`saveresampling'"', replace
			use `preservetemp', clear
		}
		
		// analyze permuted data
		`noi' di as inp `". `command'"'
		capture `noiqui' `noisily'  `command'
		if (c(rc) == 1) error 1
		local bad = c(rc) != 0
		if c(rc) {
			`noi' di in smcl as error `"{p 0 0 2}an error occurred when I executed `cmdname', "' ///
                                                  `"posting missing values{p_end}"'
			post `postnam' `mis'
		}
		else {
				forvalues j = 1/`K' {
					capture scalar `x`j'' = `exp`j''
					if (c(rc) == 1) error 1
					if c(rc) {
						local bad 1
						`noi' di in smcl as error ///
`"{p 0 0 2}captured error in `exp`j'', posting missing value{p_end}"'
						scalar `x`j'' = .
					}
					else if missing(`x`j'') {
						local bad 1
					}
				}
				post `postnam' `xstats'
//			}
		}
		`dots' `i' `bad'
	}
	`dots' `reps'

	// cleanup post
	postclose `postnam'

	// load file `saving' with permutation results and display output
	capture use `"`saving'"', clear
	if c(rc) {
		if c(rc) >= 900 & c(rc) <= 903 {
			di as err "insufficient memory to load file with permutation results"
		}
		error c(rc)
	}
	if ("`collapse'" != "") {
		di as err "collapsing"
		gen uh=0
		collapse uh,by(_*)
		drop uh
	}	
	
	label data `"ritest `resampvar' : `cmdname'"'
	// save permute characteristics and labels to data set
	forvalues i = 1/`K' {
		local name : word `i' of `names'
		local x = `name'[1]
		char `name'[permute] `x'
		local label = substr(`"`exp`i''"',1,80)
		label variable `name' `"`label'"'
		char `name'[expression] `"`exp`i''"'
		if `"`coleq'"' != "" {
			local na : word `i' of `colna'
			local eq : word `i' of `coleq'
			char `name'[coleq] `eq'
			char `name'[colname] `na'
			if `i' <= `k_eexp' {
				char `name'[is_eexp] 1
			}
		}
	}
	if ("`kdensityplot'" != "") {
		foreach var of varlist * {
			qui sum `var' in 1, meanonly
			local realization=r(mean)
			local kopt=subinstr(`"`kdensityoptions'"',"{realization}","`realization'",.)
			kdensity `var' in 2/-1, xline(`realization') name(`var', replace)  graphregion(color(white)) `kopt'
		}
	}

		
	char _dta[k_eq] `k_eq'
	char _dta[k_eexp] `k_eexp'
	char _dta[k_exp] `k_exp'
	char _dta[N_strata] `nstrata'
	char _dta[N_clust] `N_clust'
	char _dta[seed] "`seed'"
	char _dta[strata] `ustrata'
	char _dta[clustvar] `clustvar'
	char _dta[N] `obs'
	char _dta[resampvar] "`resampvar'"
	char _dta[command] "`command'"
	char _dta[sampling_method] "`method'"
	
	quietly drop in 1

	if `"`filetmp'"' == "" {
		quietly save `"`saving'"', replace
	}

	ClearE
	rit_Results, `ropts' 
	return add
	return scalar N_reps = `reps'
end
program permute_simple
    syntax , strata(varname) cluster(varname) resampvar(varname) *
    
    tempvar ind nn newt rorder
	//create a random variable
    gen `rorder'=runiform()
    qui {
		//mark first obs in each cluster
		sort `strata' `cluster', stable
		by `strata' `cluster': gen `ind' = 1 if _n==1
		sum `ind'
		if r(N)==_N { //this means that all clusters are of size 1
			sort `resampvar' //this is to shuffle all ovs
		}
		//across all first observations, generate a count variable
		sort `strata' `ind', stable
		by `strata' `ind': gen `nn'=_n if `ind'!=.
		//now, reshuffle and across all first observations, take the treatment status from the observation which was at this position before
		sort `strata' `ind' `rorder', stable
		by `strata' `ind': gen `newt'=`resampvar'[`nn']
		//place the first observations on top of each cluster
		sort `strata' `cluster' `ind', stable
		//copy down the treatment status
		by `strata' `cluster': replace `newt'=`newt'[_n-1] if missing(`newt')
		drop `resampvar'  `nn' `ind' `rorder'
		rename `newt' `resampvar' 
    }
end
program permute_extfile
    syntax ,file(string) matchvars(varlist) run(integer) resampvar(varlist)
    sort `matchvars'
    cap isid `matchvars'
    if c(rc) {
        capture qui merge m:1 `matchvars' using `file', keepusing(`resampvar'`run') nogen 
        if c(rc) {
            di as err "`resampvar'`run' does not exist in the permutation data set"
        }
    }
    else {
        capture qui merge 1:1 `matchvars' using `file', keepusing(`resampvar'`run') nogen 
        if c(rc) {
            di as err "`resampvar'`run' does not exist in the permutation data set"
        }
    }
    drop `resampvar'
    rename `resampvar'`run' `resampvar'
end
program rit_Results  //output the results in a nice table
	syntax [anything(name=namelist)]	///
		[using/] [,			///
			eps(real 1e-7)		/// -GetResults- options
			left			///
			right			///
			strict			///
			TItle(passthru)		///
			Level(cilevel)		/// -DisplayResults- options
			noHeader		///
			noLegend		///
			Verbose			///
			notable			/// not documented
			*			///
		]
	_get_diopts diopts, `options'
	if `"`using'"' != "" {
		preserve
		qui use `"`using'"', clear
	}
	else if `"`namelist'"' != "" {
		local namelist : list uniq namelist
		preserve
	}
	local 0 `namelist'
	syntax [varlist(numeric)]
	if "`namelist'" != "" {
		keep `namelist'
		local 0
		syntax [varlist]
	}
	
	rit_GetResults `varlist',	///
		eps(`eps')	///
		`left' `right'	`strict' ///
		level(`level')	///
		`title'
		
	rit_DisplayResults, `header' `table' `legend' `verbose' `diopts'
end


program rit_GetResults, rclass
	syntax varlist [,		///
		Level(cilevel)		///
		eps(real 1e-7)		/// -GetResults- options
		left			///
		right			///
		strict			///
		TItle(string asis)	///
	]

	// original number of observations
	local obs : char _dta[N]
	if "`obs'" != "" {
		capture confirm integer number `obs'
		if c(rc) {
			local obs
		}
		else if `obs' <= 0 {
			local obs
		}
	}
	// number of strata
	local nstrata : char _dta[N_strata]
	if "`nstrata'" != "" {
		capture confirm integer number `nstrata'
		if c(rc) {
			local nstrata
		}
	}
	// number of cluster
	local N_clust : char _dta[N_clust]
	if "`N_clust'" != "" {
		capture confirm integer number `N_clust'
		if c(rc) {
			local N_clust
		}
	}
	// strata variable
	if "`nstrata'" != "" {
		local strata : char _dta[strata]
		if "`strata'" != "" {
			capture confirm names `strata'
			if c(rc) {
				local strata
			}
		}
	}
	// cluster variable
	if "`N_clust'" != "" {
		local clustvar : char _dta[clustvar]
		if "`clustvar'" != "" {
			capture confirm names `clustvar'
			if c(rc) {
				local clustvar
			}
		}
	}
	// permutation method
	local sampling_method : char _dta[sampling_method]
	// permutation variable
	local resampvar : char _dta[resampvar]
	capture confirm name `resampvar'
	if c(rc) | `:word count `resampvar'' != 1 {
		local resampvar
	}
	if `"`resampvar'"' == "" {
		di as error ///
"permutation variable name not present as data characteristic"
		exit 9
	}

	// requested event
	rit_GetEvent, `left' `right' `strict' eps(`eps')
	local event `s(event)'
	local rel `s(rel)'
	local abs `s(abs)'
	local minus `"`s(minus)'"'

	tempvar diff //geqdiff
	gen `diff' = 0
	local K : word count `varlist'
	tempname b c reps p se ci
	matrix `b' = J(1,`K',0)
	matrix `c' = J(1,`K',0)
	matrix `reps' = J(1,`K',0)
	matrix `p' = J(1,`K',0)
	matrix `se' = J(1,`K',0)
	matrix `ci' = J(1,`K',0) \ J(1,`K',0)

	local seed : char _dta[seed]
	local k_eexp 0
	forvalues j = 1/`K' {
		local name : word `j' of `varlist'
		local value : char `name'[permute]
		capture matrix `b'[1,`j'] = `value'
		if c(rc) | missing(`value') {
			di as err ///
`"estimates of observed statistic for `name' not found"'
			exit 111
		}
		quietly replace ///
		`diff' = (`abs'(`name') `rel' `abs'(`value') `minus' `eps')
		
		sum `diff' if `name'<., meanonly
		if r(N) < c(N) {
			local missing missing
		}
		mat `c'[1,`j'] = r(sum)
		mat `reps'[1,`j'] = r(N)
		quietly cii `=`reps'[1,`j']' `=`c'[1,`j']', level(`level')
		mat `p'[1,`j'] = r(mean)
		mat `se'[1,`j'] = r(se)
		mat `ci'[1,`j'] = r(lb)
		mat `ci'[2,`j'] = r(ub)
		
		
		local coleq `"`coleq' `"`:char `name'[coleq]'"'"'
		local colname `colname' `:char `name'[colname]'
		local exp`j' : char `name'[expression]
		if `"`:char `name'[is_eexp]'"' == "1" {
			local ++k_eexp	
		}
	}
	local coleq : list clean coleq

	// command executed for each permutation
	local command : char _dta[command]
	local k_exp = `K' - `k_eexp'

	
	// put stripes on matrices
	if `"`coleq'"' == "" {
		version 11: matrix colnames `b' = `varlist'
	}
	else {
		version 11: matrix colnames `b' = `colname'
		if `"`coleq'"' != "" {
			version 11: matrix coleq `b' = `coleq'
		}
	}
	matrix rowname `b' = y1
	_copy_mat_stripes `c' `reps' `p' `se' `ci' : `b', novar
	matrix rowname `ci' = ll ul
	matrix roweq `ci' = _ _

	// Save results
	return clear
	if "`obs'" != "" {
		return scalar N = `obs'
	}
	return scalar level = `level'
	return scalar k_eexp = `k_eexp'
	return scalar k_exp = `k_exp'
	return matrix reps `reps'
	return matrix c `c'
	return matrix b `b'
	return matrix p `p'
	return matrix se `se'
	return matrix ci `ci'
	return hidden local seed `seed'
	return local rngstate `seed'
	return local missing `missing'
	return local resampvar `resampvar'
	if "`nstrata'" != "" {
		return scalar N_strata = `nstrata'
		if "`strata'" != "" {
			return local strata `strata'
		}
	}
	if "`N_clust'" != "" {
		return scalar N_clust = `N_clust'
		if "`clustvar'" != "" {
			return local clustvar `clustvar'
		}
	}
	return local event `event'
	return local left `left'
	return local right `right'
	return local strict `strict'
	forval i = 1/`K' {
		return local exp`i' `"`exp`i''"'
	}
	if `"`title'"' != "" {
		return local title `"`title'"'
	}
	else	return local title "Monte Carlo results"
	return local command `"`command'"'
	return local sampling_method `"`sampling_method'"'
	return local cmd ritest
end


program rit_DisplayResults, rclass
	syntax [,			///
		noHeader		///
		noLegend		///
		Verbose			///
		notable			///
		*			///
	]
	_get_diopts diopts, `options'
	if "`header'" == "" {
		//this is supposed to produce a nice header, but doesn't because _coef_table_header doesn't no ritest, so I do it manuallly
		//_coef_table_header, rclass
		
		_prefix_legend ritest, rclass `verbose'
		di as txt %`s(col1)'s "res. var(s)" ":  `r(resampvar)'"
		
		if "`r(sampling_method)'"=="extfile" {
			di as txt %`s(col1)'s "Resampling" as text ":  Using an external file"
		}
		else if "`r(sampling_method)'"=="program" {
			di as txt %`s(col1)'s "Resampling" as text ":  Using a user-specified program"
		}
		else if "`r(sampling_method)'"=="permute" {
			di as txt %`s(col1)'s "Resampling" as text ":  Permuting `r(resampvar)'"
			if !missing(r(N_clust)) & "`r(clustvar)'" != "" {
				di as txt %`s(col1)'s "Clust. var(s)" as res ":  `r(clustvar)'"
				di as txt %`s(col1)'s "Clusters" as res ":  `r(N_clust)'"
			}
			if !missing(r(N_strata)) & "`r(strata)'" != "" {
				di as txt %`s(col1)'s "Strata var(s)" as res ":  `r(strata)'"
				di as txt %`s(col1)'s "Strata" as res ":  `r(N_strata)'"
			}
		}
		else {
			di as txt %`s(col1)'s "Resampling" as text proper(":  `sampling_method'")
		}
		
	}

	// NOTE: _coef_table_header needs the results in r() to work properly,
	// thus the following line happens here instead of at the very top.
	return add

	if ("`table'" != "") {
		exit
	}
	else if "`header'" == "" {
		di
	}

	tempname Tab results
	.`Tab' = ._tab.new, col(8) lmargin(0) ignore(.b)
	ret list
	// column           1      2     3     4     5     6     7     8
	.`Tab'.width	   13    |12     8     8     8     8    10    10
	.`Tab'.titlefmt %-12s      .     .     .     .     .  %20s     .
	.`Tab'.pad	    .      2     0     0     0     0     0     1
	.`Tab'.numfmt       .  %9.0g     .     . %7.4f %7.4f     .     .

	local cil `=string(`return(level)')'
	local cil `=length("`cil'")'
	if `cil' == 2 {
		local cititle "Conf. Interval"
	}
	else {
		local cititle "Conf. Int."
	}
                                                                                
	// begin display
	.`Tab'.sep, top
	.`Tab'.titles "T" "T(obs)" "c" "n" "p=c/n" "SE(p)" ///
		"[`return(level)'% `cititle']" ""

	tempname b c reps p se ci
	matrix `b' = return(b)
	matrix `c' = return(c)
	matrix `reps' = return(reps)
	matrix `p' = return(p)
	matrix `se' = return(se)
	matrix `ci' = return(ci)
	local K = colsof(`b')
	local colname : colname `b'
	local coleq   : coleq `b', quote
	local coleq   : list clean coleq
	if `"`:list uniq coleq'"' == "_" {
		local coleq
		.`Tab'.sep
	}
	local error5 "  (omitted)"
	local error6 "  (base)   "
	local error7 "  (empty)  "
	gettoken start : colname
	local ieq 0
	local i 1
	local output 0
	local first	// starts empty
	forvalues j = 1/`K' {
		local curreq : word `j' of `coleq'
		if "`curreq'" != "`eq'" {
			.`Tab'.sep
			di as res %-12s abbrev("`curreq'",12) as txt " {c |}"
			local eq `curreq'
			local i 1
			local ++ieq
		}
		else if "`name'" == "`start'" {
			.`Tab'.sep
		}
		_ms_display, el(`i') eq(#`ieq') matrix(`b') `first' `diopts'
		if r(output) {
			local first
			if !`output' {
				local output 1
			}
		}
		else {
			if r(first) {
				local first first
			}
			local ++i
			continue
		}
		local note	`"`r(note)'"'
		local err 0
		if "`note'" == "(base)" {
			local err 6
		}
		if "`note'" == "(empty)" {
			local err 7
		}
		if "`note'" == "(omitted)" {
			local err 5
		}
		.`Tab'.width . 13 . . . . . ., noreformat
		if `err' {
			local note : copy local error`err'
			.`Tab'.row "" "`note'" .b .b .b .b .b .b
		}
		else {
			.`Tab'.row ""		///
				`b'[1,`j']	///
				`c'[1,`j']	///
				`reps'[1,`j']	///
				`p'[1,`j']	///
				`se'[1,`j']	///
				`ci'[1,`j']	///
				`ci'[2,`j']	///
				// blank
		}
		.`Tab'.width . |12 . . . . . ., noreformat
		local ++i
	}
	.`Tab'.sep, bottom
	rit_TableFoot "`return(event)'" `K' `return(missing)'
end

program ClearE, eclass
	ereturn clear
end

program rit_GetEvent, sclass
	sret clear
	syntax [, left right strict eps(string)]
	if "`left'"!="" & "`right'"!="" {
		di as err "only one of left or right can be specified"
		exit 198
	}
	local unstrict
	if "`strict'"=="" {
			local unstrict="="
	}
	if "`left'"!="" {
		sreturn local event "T <`unstrict' T(obs)"
		sreturn local rel "<`unstrict'"
		sreturn local minus "+"
	}
	else if "`right'"!="" {
		sreturn local event "T >`unstrict' T(obs)"
		sreturn local rel ">`unstrict'"
		sreturn local minus "-"
	}
	else {
		sreturn local event "|T| >`unstrict' |T(obs)|"
		sreturn local rel ">`unstrict'"
		sreturn local abs "abs"
		sreturn local minus "-"
	}
end


program rit_TableFoot 
	args event K missing
	if `K' == 1 {
		di as txt ///
"Note: Confidence interval is with respect to p=c/n."
	}
	else {
		di as txt ///
"Note: Confidence intervals are with respect to p=c/n."
	}
	if "`event'"!="" {
		di in smcl as txt "Note: c = #{`event'}"
	}
	if "`missing'" == "missing" {
		di as txt ///
"Note: Missing values observed in permutation replicates."
	}
end

exit
