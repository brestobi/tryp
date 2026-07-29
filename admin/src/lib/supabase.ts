import { createClient } from '@supabase/supabase-js';

const supabaseUrl =
  (import.meta.env.VITE_SUPABASE_URL as string) ||
  'https://lapkfscxtkvbuojysygk.supabase.co';

const supabaseAnonKey =
  (import.meta.env.VITE_SUPABASE_ANON_KEY as string) ||
  'sb_publishable_58IwG0SXlZr276gxsc9W6Q_DEgpb-9q';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
