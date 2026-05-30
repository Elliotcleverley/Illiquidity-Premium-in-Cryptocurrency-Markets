* The Economics of Alternative Investments

* Student number 100424212

clear all


** Section 1: Dataset construction


cd "/Users/Elliot/Library/CloudStorage/OneDrive-UniversityofEastAnglia/Universitiy third year/Semester two/The Economics of Alternative Investments/First Assesment/Summative 001 Data"

* Append all coin CSVs into one dataset
local coins Aave BinanceCoin Bitcoin Cardano ChainLink Cosmos CryptocomCoin Dogecoin EOS Ethereum Iota Litecoin Monero NEM Polkadot Solana Stellar Tether Tron Uniswap USDCoin WrappedBitcoin XRP
local first = 1
foreach coin of local coins {
    import delimited "coin_`coin'.csv", clear
    if `first' == 1 {
        save "combined_crypto.dta", replace
        local first = 0
    }
    else {
        append using "combined_crypto.dta"
        save "combined_crypto.dta", replace
    }
}


** Section 2: Data cleaning


* Convert date string to Stata date format
gen date2 = date(substr(date, 1, 10), "YMD")
format date2 %td
drop date
rename date2 date

* Encode string identifiers as numeric with labels
encode name, gen(name_id)
encode symbol, gen(symbol_id)
drop name symbol
rename name_id name
rename symbol_id symbol

* Declare unbalanced panel structure
xtset name date


** Section 3: Daily log returns


* Compute log return within each coin
by name: gen log_return = ln(close) - ln(L.close)

* Confirm missing observation at coin boundaries
by name: assert missing(log_return) if _n == 1

summarize log_return, detail

* winsorised dependent variable at 1% and 99%
winsor2 log_return, cuts(1 99) suffix(_w)


** Section 4: Return plots


xtline log_return_w, ytitle("Log Return") xtitle("Date") tlabel(01jan2014 01jan2017 01jan2020, format(%tdCY)) byopts(title("Cryptocurrency Daily Log Returns (2013-2021)"))


** Section 5: Liquidity measures


* Clean volume variable
sum volume
count if volume == 0

* Zero volume observations are concentrated in the early 2013 period (Aave has one anomaly)
* These reflect absent CoinMarketCap reporting, not genuine zero-volume days
bysort name: list date volume if volume == 0, sepby(name) noobs

* Recoded as missing to avoid division by zero in calculations
replace volume = . if volume == 0

* Core measure Amihud (2002)

gen amihud = abs(log_return) / volume
replace amihud = amihud * 1000000

* Amihud: skewness = 190, kurtosis = 36,376
sum amihud, detail

* use Ln(X+1) due to values of 0 
count if amihud == 0
gen log_amihud = ln(amihud + 1)

* High-to-Low Amihud motivated by Lacava et al. (2026)
gen hl_return = (high / low) - 1
gen amihud_hl = abs(hl_return) / volume
replace amihud_hl = amihud_hl * 1000000

* Skewness = 179, kurtosis = 33,26
sum amihud_hl, detail 

* use Ln(X+1) due to values of 0
count if amihud_hl == 0
gen log_amihud_hl = ln(amihud_hl + 1)

* Turnover inspired by (Datar et al., 1998)

gen turnover = volume / marketcap

* No zero values. Skewness = 8, kurtosis = 88
sum turnover, detail

* use ln(X) 
gen log_turnover = ln(turnover)

* winsorised liquidity measures at 1% and 99%
winsor2 log_amihud log_amihud_hl log_turnover, cuts(1 99) suffix(_w)


** Section 6: Liquidity plots


* Amihud (2002) - Evidence of outliers and right skewness
xtline amihud, ytitle("Amihud Illiquidity") xtitle("Date") tlabel(01jan2014 01jan2017 01jan2020, format(%tdCY)) byopts(title("Cryptocurrency Amihud Illiquidity (2013-2021)"))

* Log Amihud 
xtline log_amihud_w, ytitle("Log Amihud Illiquidity") xtitle("Date") tlabel(01jan2014 01jan2017 01jan2020, format(%tdCY)) byopts(title("Cryptocurrency Log Amihud Illiquidity (2013-2021)"))

* Log High-to-Low Amihud
xtline log_amihud_hl_w, ytitle("Log High-to-Low Amihud Illiquidity") xtitle("Date") tlabel(01jan2014 01jan2017 01jan2020, format(%tdCY)) byopts(title("Cryptocurrency Log High-to-Low Amihud Illiquidity (2013-2021)"))

* Log Turnover
xtline log_turnover_w, ytitle("Log Turnover") xtitle("Date") tlabel(01jan2014 01jan2017 01jan2020, format(%tdCY)) byopts(title("Cryptocurrency Log Turnover (2013-2021)"))


** Section 7: Illiquidity premium 


* Portfolio sorts iliquidity measures

* Lag liquidity measures by one day within each coin (Ali et al., 2025)
bysort name (date): gen log_amihud_w_lag    = log_amihud_w[_n-1]
bysort name (date): gen log_amihud_hl_w_lag = log_amihud_hl_w[_n-1]
bysort name (date): gen log_turnover_w_lag  = log_turnover_w[_n-1]

* Illiquidity measures: P1 = most liquid, P3 = most illiquid
* Premium = P3 - P1, tested with Newey-West HAC standard errors (8 lags)
local measures log_amihud_w_lag log_amihud_hl_w_lag
foreach measure of local measures {

    bysort date: egen rank_`measure'    = rank(`measure')
    bysort date: egen n_coins_`measure' = count(`measure')
    gen portfolio_`measure' = .
    replace portfolio_`measure' = 1 if rank_`measure' <= n_coins_`measure'/3
    replace portfolio_`measure' = 2 if rank_`measure' >  n_coins_`measure'/3   & rank_`measure' <= 2*n_coins_`measure'/3
    replace portfolio_`measure' = 3 if rank_`measure' >  2*n_coins_`measure'/3

    display "Portfolio sorts: `measure'"
    tabstat log_return_w, by(portfolio_`measure') stats(mean sd n)

    preserve
        drop if missing(portfolio_`measure')
        collapse (mean) log_return_w, by(portfolio_`measure' date)
        reshape wide log_return_w, i(date) j(portfolio_`measure')
        gen premium = log_return_w3 - log_return_w1
        keep if !missing(premium)
        sort date
        gen t = _n
        tsset t
        display "Newey-West premium test: `measure'"
        newey premium, lag(8)
    restore
}

* Turnover is a liquidity measure: reverse labels so P3 = least liquid (lowest turnover)
bysort date: egen rank_turnover_w_lag    = rank(log_turnover_w_lag)
bysort date: egen n_coins_turnover_w_lag = count(log_turnover_w_lag)
gen portfolio_turnover = .
replace portfolio_turnover = 3 if rank_turnover_w_lag <= n_coins_turnover_w_lag/3
replace portfolio_turnover = 2 if rank_turnover_w_lag >  n_coins_turnover_w_lag/3   & rank_turnover_w_lag <= 2*n_coins_turnover_w_lag/3
replace portfolio_turnover = 1 if rank_turnover_w_lag >  2*n_coins_turnover_w_lag/3

display "Portfolio sorts: log_turnover_w_lag"
tabstat log_return_w, by(portfolio_turnover) stats(mean sd n)

preserve
    drop if missing(portfolio_turnover)
    collapse (mean) log_return_w, by(portfolio_turnover date)
    reshape wide log_return_w, i(date) j(portfolio_turnover)
    gen premium = log_return_w3 - log_return_w1
    keep if !missing(premium)
    sort date
    gen t = _n
    tsset t
    display "Newey-West premium test: log_turnover_w_lag"
    newey premium, lag(8)
restore

* Fama-Macbeth regression

* Generate control variables

* Log market capitalisation (size control)
bysort name (date): gen log_mcap = ln(marketcap)

* Lag size control 
gen log_mcap_lag = L.log_mcap

* winsorised market capitalisation at 1% and 99%
winsor2 log_mcap_lag, cuts(1 99) suffix(_w)

* Lagged return (momentum control)
bysort name (date): gen log_return_w_lag = L.log_return_w

* Stage 1: Cross-sectional regression at each date
* Stage 2: Average coefficients over time with Newey-West standard errors
* * 8 lags included following Newey and west (1994) for t = 2,747 

* Model 1 — Naive Amihud
asreg log_return_w log_amihud_w_lag, fmb newey(8)
estimates store m1

* Model 2 — Naive High-to-Low Amihud
asreg log_return_w log_amihud_hl_w_lag, fmb newey(8)
estimates store m2

* Controlled models 

* Model 3 — Amihud with controls 
asreg log_return_w log_amihud_w_lag log_mcap_lag_w log_return_w_lag, fmb newey(8)
estimates store m3

* Model 4 — High-to-Low Amihud with controls 
asreg log_return_w log_amihud_hl_w_lag log_mcap_lag_w log_return_w_lag, fmb newey(8)
estimates store m4

* Model 5 — Turnover with controls (robustness)
asreg log_return_w log_turnover_w_lag log_mcap_lag_w log_return_w_lag, fmb newey(8)
estimates store m5

* Output 
esttab m1 m2 m3 m4 m5 using workshop5.rtf, replace star(* 0.1 ** 0.05 *** 0.01) se mtitles r2 obslast compress 
