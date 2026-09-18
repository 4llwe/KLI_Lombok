import {json} from './lib/supabase.mjs';
export const handler=async()=>json(200,{supabaseUrl:process.env.SUPABASE_URL||'',supabaseAnonKey:process.env.SUPABASE_ANON_KEY||'',siteUrl:process.env.PUBLIC_SITE_URL||'',bank:{name:process.env.BANK_NAME||'',accountNumber:process.env.BANK_ACCOUNT_NUMBER||'',accountHolder:process.env.BANK_ACCOUNT_HOLDER||''}});
