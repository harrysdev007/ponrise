export const BPS=10000n;
export const out=(n,a,b)=>n*b/(a+n);
export function quoteBuy({quoteReserve,tokenReserve,sellable,feeBps,creatorTaxBps,snipeBps=0n},input){
 if(input<=0n||quoteReserve<=0n||tokenReserve<=0n||sellable<=0n)throw Error('Curve is not open for this purchase.');
 const max=BPS-feeBps-creatorTaxBps-100n;if(max<0n)throw Error('Invalid fee configuration.');const s=snipeBps>max?max:snipeBps;
 let spent=input;const net=input-input*feeBps/BPS-input*creatorTaxBps/BPS-input*s/BPS;let tokens=out(net,quoteReserve,tokenReserve);
 if(tokens>sellable){tokens=sellable;const n=tokens*quoteReserve/(tokenReserve-tokens)+1n;const d=BPS-feeBps-creatorTaxBps-s;const gross=(n*BPS+d-1n)/d;spent=gross<input?gross:input;}
 return{tokens,spent,refund:input-spent};
}
export function quoteSell({quoteReserve,tokenReserve,feeBps,creatorTaxBps},tokens){if(tokens<=0n)throw Error('Enter a positive token amount.');const gross=out(tokens,tokenReserve,quoteReserve);return gross-gross*feeBps/BPS-gross*creatorTaxBps/BPS;}
export function launchEstimate(config,seed,tax=0n){const q=BigInt(config.phantomQuote),s=BigInt(config.supply),threshold=BigInt(config.graduationThreshold);const reserved=s*q/(q+threshold);const buy=quoteBuy({quoteReserve:q,tokenReserve:s,sellable:s-reserved,feeBps:BigInt(config.curveFeeBps),creatorTaxBps:tax},seed);const fee=buy.spent*BigInt(config.curveFeeBps)/BPS;const creatorTax=buy.spent*tax/BPS;const qAfter=q+buy.spent-fee-creatorTax;const tAfter=s-buy.tokens;return{...buy,reserved,openingFdv:q,postFdv:qAfter*s/tAfter,teamBps:buy.tokens*BPS/s,liquidityReserveBps:reserved*BPS/s};}
export function normalizeTicker(symbol){const s=symbol.toUpperCase();if(!/^[A-Z0-9]{1,10}$/.test(s))throw Error('Ticker must contain 1–10 letters or numbers.');return s;}
export function slippageMinimum(value,bps){if(!Number.isInteger(bps)||bps<1||bps>500)throw Error('Slippage must be between 0.01% and 5%.');return value*BigInt(10000-bps)/10000n;}

export function percentBps(value){if(!/^\d{1,2}(\.\d{1,2})?$/.test(String(value)))throw Error("Enter a percentage with at most two decimal places.");const[a,b=""]=String(value).split(".");return Number(a)*100+Number(b.padEnd(2,"0"));}
