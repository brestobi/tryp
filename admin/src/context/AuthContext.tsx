import React, { createContext, useContext, useState, useEffect } from 'react';
import type { User, Session } from '@supabase/supabase-js';
import { supabase } from '../lib/supabase';
import type { AdminRole } from '../types/admin';
import { normalizeAdminRole } from '../lib/rbac';
interface AuthUser {
  id: string;
  email: string;
  fullName: string;
  role: string;
  adminRole: AdminRole | null;
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
  const profileResult = await supabase
    .from('profiles')
    .select('full_name, role, admin_role, avatar_url')
    .eq('id', supabaseUser.id)
    .maybeSingle();

  // Keep existing admin accounts usable until the admin_role migration has
  // been applied to the project database.
  const data = profileResult.error
    ? (await supabase
        .from('profiles')
        .select('full_name, role, avatar_url')
        .eq('id', supabaseUser.id)
        .maybeSingle()).data
    : profileResult.data;

  const userRole = data?.role ?? 'none';
  const adminRole = profileResult.error ? null : profileResult.data?.admin_role;

  return {
    id: supabaseUser.id,
    email: supabaseUser.email ?? '',
    fullName: data?.full_name ?? supabaseUser.email?.split('@')[0] ?? 'User',
    role: userRole,
    adminRole: normalizeAdminRole(userRole, adminRole),
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
      if (!profile.adminRole) {
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

  const isAdmin = Boolean(user?.adminRole);

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
