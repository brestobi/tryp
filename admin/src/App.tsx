import React from 'react';
import { AdminProvider, useAdmin } from './context/AdminContext';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { DashboardOverview } from './components/DashboardOverview';
import { DriverKYCInspector } from './components/DriverKYCInspector';
import { FleetCommandCenter } from './components/FleetCommandCenter';
import { FarePricingEngine } from './components/FarePricingEngine';
import { FinancialPayouts } from './components/FinancialPayouts';
import { UserDirectory } from './components/UserDirectory';
import { AuditLogsView } from './components/AuditLogsView';

const MainContent: React.FC = () => {
  const { activeTab } = useAdmin();

  return (
    <main className="flex-1 p-6 overflow-y-auto max-w-[1600px] mx-auto w-full">
      {activeTab === 'dashboard' && <DashboardOverview />}
      {activeTab === 'kyc' && <DriverKYCInspector />}
      {activeTab === 'fleet' && <FleetCommandCenter />}
      {activeTab === 'fares' && <FarePricingEngine />}
      {activeTab === 'payouts' && <FinancialPayouts />}
      {activeTab === 'users' && <UserDirectory />}
      {activeTab === 'audit' && <AuditLogsView />}
    </main>
  );
};

export function App() {
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
}

export default App;
