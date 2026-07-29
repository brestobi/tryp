import React from 'react';
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
import { Loader2 } from 'lucide-react';

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
  const { session, loading } = useAuth();

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center">
        <Loader2 className="w-8 h-8 animate-spin text-purple-400" />
      </div>
    );
  }

  if (!session) {
    return <LoginPage />;
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
    <AuthProvider>
      <AppShell />
    </AuthProvider>
  );
}

export default App;
