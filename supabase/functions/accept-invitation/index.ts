import { createClient } from 'npm:@supabase/supabase-js@2';

const headers={
  'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Content-Type':'application/json'
};

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS') return new Response('ok',{headers});
  if(req.method!=='POST') return new Response(JSON.stringify({error:'Method not allowed'}),{status:405,headers});
  const authorization=req.headers.get('Authorization');
  if(!authorization) return new Response(JSON.stringify({error:'Authentication required'}),{status:401,headers});
  try{
    const body=await req.json(); const token=typeof body.token==='string'?body.token.trim():'';
    if(!/^[a-f0-9]{64}$/i.test(token)) return new Response(JSON.stringify({error:'Invalid invitation code'}),{status:400,headers});
    const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}}});
    const {data,error}=await client.rpc('accept_invitation',{p_token:token});
    if(error) throw error;
    return new Response(JSON.stringify({data}),{status:200,headers});
  }catch(error){
    // Never echo the body or raw invitation token.
    const message=error instanceof Error?error.message:'Unable to accept invitation';
    return new Response(JSON.stringify({error:message}),{status:400,headers});
  }
});
