import React, { createContext, useContext, useState, useEffect } from 'react';
import type { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';

interface AuthUser {
  id: string;
  email: string;
  fullName: string;
  role: string;
  avatarUrl: string;
}

interface AuthContextType {
  session: Session | null;
  user: AuthUser | null;
  isAdmin: boolean;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<{ error: string | null }>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

async function fetchProfile(supabaseUser: User): Promise<AuthUser> {
  const { data } = await supabase
    .from('profiles')
    .select('full_name, role, avatar_url')
    .eq('id', supabaseUser.id)
    .maybeSingle();

  const userRole = data?.role ?? 'none';

  return {
    id: supabaseUser.id,
    email: supabaseUser.email ?? '',
    fullName: data?.full_name ?? supabaseUser.email?.split('@')[0] ?? 'User',
    role: userRole,
    avatarUrl:
      data?.avatar_url ??
      `https://ui-avatars.com/api/?name=${encodeURIComponent(data?.full_name ?? 'User')}&background=111111&color=ffffff`,
  };
}

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [session, setSession] = useState<Session | null>(null);
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Restore existing session
    supabase.auth.getSession().then(async ({ data: { session: s } }) => {
      setSession(s);
      if (s?.user) {
        const profile = await fetchProfile(s.user);
        setUser(profile);
      }
      setLoading(false);
    });

    // Listen for auth state changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, s) => {
      setSession(s);
      if (s?.user) {
        const profile = await fetchProfile(s.user);
        setUser(profile);
      } else {
        setUser(null);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  const signIn = async (email: string, password: string): Promise<{ error: string | null }> => {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) return { error: error.message };

    if (data.user) {
      const profile = await fetchProfile(data.user);
      if (!['admin', 'super_admin'].includes(profile.role)) {
        await supabase.auth.signOut();
        setUser(null);
        setSession(null);
        return { error: 'Access denied: Account does not have admin privileges.' };
      }
      setUser(profile);
    }
    return { error: null };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
    setUser(null);
    setSession(null);
  };

  const isAdmin = Boolean(user && ['admin', 'super_admin'].includes(user.role));

  return (
    <AuthContext.Provider value={{ session, user, isAdmin, loading, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
};
