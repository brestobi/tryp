import React, { useState } from 'react';
import { useAuth } from '../context/AuthContext';
import { useTheme } from '../context/ThemeContext';
import { ShieldCheck, Mail, Lock, Loader2, AlertCircle, Sun, Moon } from 'lucide-react';

interface LoginPageProps {
  initialError?: string;
}

export const LoginPage: React.FC<LoginPageProps> = ({ initialError }) => {
  const { signIn } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(initialError ?? null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    const { error: err } = await signIn(email.trim(), password);
    if (err) setError(err);
    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4 relative overflow-hidden">
      {/* Ambient background blobs */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-white/[0.03] rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 w-80 h-80 bg-white/[0.02] rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-md z-10">
        <div className="flex justify-end mb-4">
          <button
            type="button"
            onClick={toggleTheme}
            title={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
            aria-label={`Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`}
            className="inline-flex items-center gap-2 rounded-lg border border-slate-700 bg-slate-900 px-3 py-1.5 text-xs font-semibold text-slate-300 transition-colors hover:bg-slate-800 hover:text-white"
          >
            {theme === 'dark' ? <Sun className="h-3.5 w-3.5 text-amber-400" /> : <Moon className="h-3.5 w-3.5 text-indigo-500" />}
            {theme === 'dark' ? 'Light mode' : 'Dark mode'}
          </button>
        </div>
        {/* Brand */}
        <div className="text-center mb-8 space-y-3">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-slate-100 text-slate-950 shadow-xl shadow-white/10 mb-2">
            <ShieldCheck className="w-7 h-7 text-slate-950" />
          </div>
          <div>
            <h1 className="text-3xl font-extrabold text-white font-heading tracking-tight">
              TRYP Admin
            </h1>
            <p className="text-slate-400 text-sm mt-1">Back-Office Operations Console</p>
          </div>
        </div>

        {/* Login card */}
        <div className="glass-panel rounded-2xl border border-slate-800 p-8 shadow-2xl shadow-slate-950/60 space-y-6">
          <div>
            <h2 className="text-lg font-bold text-white font-heading">Sign in to your account</h2>
            <p className="text-slate-400 text-xs mt-1">
              Access is restricted to authorised TRYP administrators.
            </p>
          </div>

          {error && (
            <div className="flex items-start space-x-2 p-3 rounded-xl bg-slate-800 border border-slate-700 text-slate-200 text-xs">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span>{error}</span>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Email */}
            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-slate-300">
                Email Address
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
                <input
                  id="admin-email"
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="you@tryp.co.za"
                  required
                  autoComplete="email"
                  className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400 transition-colors"
                />
              </div>
            </div>

            {/* Password */}
            <div className="space-y-1.5">
              <label className="block text-xs font-semibold text-slate-300">
                Password
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-3" />
                <input
                  id="admin-password"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••"
                  required
                  autoComplete="current-password"
                  className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400 transition-colors"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading || !email || !password}
              className="w-full py-3 rounded-xl bg-indigo-600 text-white font-bold text-sm shadow-lg shadow-indigo-500/20 hover:bg-indigo-500 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center space-x-2"
            >
              {loading ? (
                <>
                  <Loader2 className="w-4 h-4 animate-spin" />
                  <span>Authenticating...</span>
                </>
              ) : (
                <span>Sign In to Console</span>
              )}
            </button>
          </form>

          <p className="text-center text-[11px] text-slate-500">
            All sessions are logged in the admin audit trail.
          </p>
        </div>

        <p className="text-center text-xs text-slate-600 mt-6">
          TRYP Platform v2.4.0-ZA &nbsp;·&nbsp; Back-Office Operations
        </p>
      </div>
    </div>
  );
};
