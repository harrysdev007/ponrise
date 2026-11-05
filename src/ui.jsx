import React from'react';import{ArrowUpRight,LoaderCircle}from'lucide-react';import{EXPLORER,formatUnits}from'./chain';
export const fmtUnits=(n,d=18,max=5)=>Number(formatUnits(n??0n,d)).toLocaleString('en-US',{maximumFractionDigits:max});
export function Field({label,hint,children}){return <label className="field"><span>{label}</span>{children}{hint&&<small>{hint}</small>}</label>}
export function Busy({children}){return <div className="busy" role="status"><LoaderCircle size={16} className="spin"/>{children}</div>}
export const urlOK=s=>{try{return ['https:','ipfs:'].includes(new URL(s).protocol)}catch{return false}};
export function download(name,data){const url=URL.createObjectURL(new Blob([JSON.stringify(data,(_,v)=>typeof v==='bigint'?v.toString():v,2)],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)}
export function Tx({hash,children}){return <a className="tx-link" href={`${EXPLORER}/tx/${hash}`} target="_blank" rel="noopener noreferrer">{children||'View transaction'} <ArrowUpRight size={14}/></a>}
