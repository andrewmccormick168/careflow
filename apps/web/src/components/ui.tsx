import { X, LoaderCircle, Search, Plus } from 'lucide-react';

export function PageHeader({title,description,action,onAction}:{title:string;description:string;action?:string;onAction?:()=>void}){
  return <div className="page-header"><div><h1>{title}</h1><p>{description}</p></div>{action&&<button className="btn primary" onClick={onAction}><Plus size={17}/>{action}</button>}</div>;
}
export function StatCard({label,value,hint,icon,color='blue'}:{label:string;value:string|number;hint:string;icon:React.ReactNode;color?:string}){
  return <article className="stat-card"><span className={`stat-icon ${color}`}>{icon}</span><div><p>{label}</p><strong>{value}</strong><small>{hint}</small></div></article>;
}
export function Status({value}:{value:string}){return <span className={`status ${value.toLowerCase().replaceAll(' ','_')}`}>{value.replaceAll('_',' ')}</span>}
export function Empty({text='No records found'}:{text?:string}){return <div className="empty"><Search size={28}/><p>{text}</p></div>}
export function Loading(){return <div className="loading"><LoaderCircle className="spin"/>Loading…</div>}
export function SearchBox({value,onChange,placeholder='Search…'}:{value:string;onChange:(v:string)=>void;placeholder?:string}){
  return <label className="search"><Search size={17}/><input value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder}/></label>
}
export function Modal({title,children,onClose,className=''}:{title:string;children:React.ReactNode;onClose:()=>void;className?:string}){
  return <div className="modal-backdrop" role="presentation" onMouseDown={onClose}><section className={`modal ${className}`.trim()} role="dialog" aria-modal="true" onMouseDown={e=>e.stopPropagation()}><header><h2>{title}</h2><button className="icon-btn" onClick={onClose} aria-label="Close"><X/></button></header>{children}</section></div>
}
export function Field({label,children}:{label:string;children:React.ReactNode}){return <label className="field"><span>{label}</span>{children}</label>}
export function DataError({message}:{message?:string|undefined}){return <div className="notice danger">Unable to load this section. {message}</div>}
