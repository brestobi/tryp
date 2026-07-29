import React, { Component } from 'react';
import type { ErrorInfo, ReactNode } from 'react';
import { AuthProvider, useAuth } from './context/AuthContext';
import { AdminProvider } from './context/AdminContext';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { LoginPage } from './components/LoginPage';
import { DashboardOverview } from './components/DashboardOverview';
import { DriverKYCInspector } from './components/DriverKYCInspector';
import { FleetCommandCenter } from './components/FleetCommandCenter';
import { FarePricingEngine } from './components/FarePricingEngine';
import { FinancialPayouts } from './components/FinancialPayouts';
import { UserDirectory } from './components/UserDirectory';
import { AuditLogsView } from './components/AuditLogsView';
import { useAdmin } from './context/AdminContext';
import { Loader2, AlertTriangle, RefreshCw } from 'lucide-react';

interface ErrorBoundaryProps {
  children: ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends Component<ErrorBoundaryProps, ErrorBoundaryState> {
  public state: ErrorBoundaryState = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-slate-950 text-slate-100 flex items-center justify-center p-6">
          <div className="max-w-md w-full glass-panel p-8 rounded-2xl border border-red-500/30 text-center space-y-4 shadow-2xl">
            <div className="w-12 h-12 rounded-full bg-red-500/10 border border-red-500/30 flex items-center justify-center mx-auto text-red-400">
              <AlertTriangle className="w-6 h-6" />
            </div>
            <div>
              <h2 className="text-xl font-bold font-heading text-white">Application Error</h2>
              <p className="text-xs text-slate-400 mt-1">
                An unexpected exception occurred during rendering.
              </p>
            </div>
            <div className="p-3 bg-slate-900 rounded-xl border border-slate-800 text-left text-xs font-mono text-red-400 overflow-x-auto max-h-32">
              {this.state.error?.message || 'Unknown Error'}
            </div>
            <button
              onClick={() => window.location.reload()}
              className="w-full py-2.5 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs transition-all flex items-center justify-center space-x-2"
            >
              <RefreshCw className="w-4 h-4" />
              <span>Reload Console</span>
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

const MainContent: React.FC = () => {
  const { activeTab } = useAdmin();
  return (
    <main className="flex-1 p-6 overflow-y-auto max-w-[1600px] mx-auto w-full">
      {activeTab === 'dashboard' && <DashboardOverview />}
      {activeTab === 'kyc'       && <DriverKYCInspector />}
      {activeTab === 'fleet'     && <FleetCommandCenter />}
      {activeTab === 'fares'     && <FarePricingEngine />}
      {activeTab === 'payouts'   && <FinancialPayouts />}
      {activeTab === 'users'     && <UserDirectory />}
      {activeTab === 'audit'     && <AuditLogsView />}
    </main>
  );
};

const AppShell: React.FC = () => {
  const { session, user, isAdmin, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
      </div>
    );
  }

  if (!session || !user || !isAdmin) {
    return <LoginPage initialError={user && !isAdmin ? 'Access denied: Account does not have admin permissions.' : undefined} />;
  }

  return (
    <AdminProvider>
      <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col font-sans selection:bg-purple-500 selection:text-white">
        <Header />
        <div className="flex-1 flex overflow-hidden">
          <Sidebar />
          <MainContent />
        </div>
      </div>
    </AdminProvider>
  );
};

export function App() {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <AppShell />
      </AuthProvider>
    </ErrorBoundary>
  );
}

export default App;
