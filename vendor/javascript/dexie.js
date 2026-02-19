// dexie@4.0.11 downloaded from https://ga.jspm.io/npm:dexie@4.0.11/import-wrapper-prod.mjs

import e from"./dist/dexie.min.js";import"process";const r=Symbol.for("Dexie");const o=globalThis[r]||(globalThis[r]=e);if(e.semVer!==o.semVer)throw new Error(`Two different versions of Dexie loaded in the same app: ${e.semVer} and ${o.semVer}`);const{liveQuery:i,mergeRanges:s,rangesOverlap:a,RangeSet:t,cmp:n,Entity:m,PropModification:d,replacePrefix:l,add:p,remove:f}=o;export{o as Dexie,m as Entity,d as PropModification,t as RangeSet,p as add,n as cmp,o as default,i as liveQuery,s as mergeRanges,a as rangesOverlap,f as remove,l as replacePrefix};

