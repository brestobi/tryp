import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  CreditCard,
  Download,
  Building2,
  Search,
  Loader2,
} from 'lucide-react';
import { verifyPaystackTransaction } from '../lib/queries';

export const FinancialPayouts: React.FC = () => {
  const { payouts, verifyPayout, addNotification } = useAdmin();

  const [searchTerm, setSearchTerm] = useState<string>('');
  const [verifyingId, setVerifyingId] = useState<string | null>(null);
  
  // Paystack Auditor lookup state
  const [paystackTxRef, setPaystackTxRef] = useState<string>('pstk_tx_99812401');
  const [paystackAuditResult, setPaystackAuditResult] = useState<{
    reference: string;
    amount: number;
    currency: string | null;
    channel: string;
    status: string;
    paidAt: string | null;
    customerEmail: string;
  } | null>(null);
  const [isAuditingPaystack, setIsAuditingPaystack] = useState(false);

  const filteredPayouts = payouts.filter(p => {
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      return (
        p.driverName.toLowerCase().includes(term) ||
        p.accountNumber.includes(term) ||
        p.bankName.toLowerCase().includes(term)
      );
    }
    return true;
  });

  const totalGross = payouts.reduce((sum, p) => sum + p.grossEarnings, 0);
  const totalCommission = payouts.reduce((sum, p) => sum + p.platformFee, 0);
  const totalNet = payouts.reduce((sum, p) => sum + p.netPayout, 0);
  const pendingPayouts = payouts.filter(p => p.status === 'pending');

  const handleAuditLookup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!paystackTxRef.trim() || isAuditingPaystack) return;
    setIsAuditingPaystack(true);
    try {
      const result = await verifyPaystackTransaction(paystackTxRef.trim());
      setPaystackAuditResult(result);
    } catch (err) {
      setPaystackAuditResult(null);
      addNotification({
        type: 'error',
        title: 'Paystack Lookup Failed',
        message: err instanceof Error ? err.message : 'Transaction could not be verified.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setIsAuditingPaystack(false);
    }
  };

  const handleVerifyPayout = async (payoutId: string) => {
    if (verifyingId === payoutId) return;
    setVerifyingId(payoutId);
    try {
      await verifyPayout(payoutId);
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Payout Verification Failed',
        message: err instanceof Error ? err.message : 'Failed to verify payout.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setVerifyingId(null);
    }
  };

  const handleExportCSV = () => {
    const csvHeader = 'Payout ID,Driver Name,Bank Name,Branch Code,Account Number,Account Holder,Gross Earnings,Platform Fee,Net Payout,Status,Period\n';
    const csvRows = payouts
      .map(
        p =>
          `"${p.id}","${p.driverName}","${p.bankName}","${p.branchCode}","${p.accountNumber}","${p.accountHolder}",${p.grossEarnings},${p.platformFee},${p.netPayout},"${p.status}","${p.period}"`
      )
      .join('\n');

    const blob = new Blob([csvHeader + csvRows], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.setAttribute('download', `TRYP_Driver_Payouts_Batch_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-cyan-400 mb-1 font-mono">
            <CreditCard className="w-4 h-4 text-cyan-400" />
            <span>Module 4 Financial Engine</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Financial Operations & Driver Payouts</h1>
          <p className="text-slate-400 text-xs mt-1">
            Weekly driver settlement calculation, South African bank verification, batch SEPA/CSV export, and Paystack reconciliation.
          </p>
        </div>

        <button
          onClick={handleExportCSV}
          className="px-5 py-2.5 rounded-xl bg-gradient-to-r from-cyan-600 to-blue-600 text-white text-xs font-bold shadow-lg shadow-cyan-500/20 hover:from-cyan-500 hover:to-blue-500 transition-all flex items-center space-x-2 shrink-0"
        >
          <Download className="w-4 h-4" />
          <span>Export SA Bank Batch (CSV/SEPA)</span>
        </button>
      </div>

      {/* Settlement Summary KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Gross Platform Earnings</span>
          <div className="text-2xl font-extrabold text-white font-mono">R{totalGross.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}</div>
          <div className="text-[10px] text-slate-500 font-mono">Weekly Fleet Fare Sum</div>
        </div>

        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">TRYP Platform Revenue</span>
          <div className="text-2xl font-extrabold text-cyan-400 font-mono">R{totalCommission.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}</div>
          <div className="text-[10px] text-slate-500 font-mono">Commission Retained</div>
        </div>

        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Net Driver Payout Pool</span>
          <div className="text-2xl font-extrabold text-emerald-400 font-mono">R{totalNet.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}</div>
          <div className="text-[10px] text-slate-500 font-mono">Ready for Bank Disbursement</div>
        </div>

        <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
          <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">Pending Audit Queue</span>
          <div className="text-2xl font-extrabold text-amber-400 font-mono">{pendingPayouts.length} Settlements</div>
          <div className="text-[10px] text-amber-400/80 font-mono">Requires Admin Verification</div>
        </div>
      </div>

      {/* Main Grid: Settlement Table + Paystack Auditor */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Settlement Table (8 cols) */}
        <div className="lg:col-span-8 space-y-4">
          <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-lg text-white">Driver Settlement Ledger</h3>
              <div className="flex items-center space-x-2">
                <div className="relative">
                  <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-2.5" />
                  <input
                    type="text"
                    placeholder="Search driver or account..."
                    value={searchTerm}
                    onChange={e => setSearchTerm(e.target.value)}
                    className="pl-8 pr-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-cyan-500 w-44 sm:w-56"
                  />
                </div>
              </div>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
                    <th className="py-3 px-3">Driver Name</th>
                    <th className="py-3 px-3">Bank & Account</th>
                    <th className="py-3 px-3">Branch</th>
                    <th className="py-3 px-3">Gross</th>
                    <th className="py-3 px-3">Net Payout</th>
                    <th className="py-3 px-3">Status</th>
                    <th className="py-3 px-3 text-right">Action</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60">
                  {filteredPayouts.map(pay => (
                    <tr key={pay.id} className="hover:bg-slate-900/60 transition-colors text-slate-300">
                      <td className="py-3 px-3 font-semibold text-slate-100">{pay.driverName}</td>
                      <td className="py-3 px-3">
                        <div className="font-medium text-slate-200">{pay.bankName}</div>
                        <div className="text-[10px] text-slate-400 font-mono">Acct: ****{pay.accountNumber.slice(-4)}</div>
                      </td>
                      <td className="py-3 px-3 font-mono text-slate-400">{pay.branchCode}</td>
                      <td className="py-3 px-3 font-mono text-slate-400">R{pay.grossEarnings.toFixed(2)}</td>
                      <td className="py-3 px-3 font-mono font-bold text-emerald-400">R{pay.netPayout.toFixed(2)}</td>
                      <td className="py-3 px-3">
                        <span
                          className={`px-2 py-0.5 rounded-full text-[10px] font-mono font-bold uppercase border ${
                            pay.status === 'verified'
                              ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                              : pay.status === 'pending'
                              ? 'bg-amber-500/20 text-amber-400 border-amber-500/30'
                              : 'bg-slate-800 text-slate-400 border-slate-700'
                          }`}
                        >
                          {pay.status}
                        </span>
                      </td>
                      <td className="py-3 px-3 text-right">
                        {pay.status === 'pending' ? (
                          <button
                            onClick={() => handleVerifyPayout(pay.id)}
                            disabled={verifyingId === pay.id}
                            className="px-3 py-1 rounded-lg bg-emerald-600/20 border border-emerald-500/40 text-emerald-300 hover:bg-emerald-600/40 text-xs font-semibold disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-1.5"
                          >
                            {verifyingId === pay.id ? (
                              <Loader2 className="w-3 h-3 animate-spin" />
                            ) : null}
                            <span>{verifyingId === pay.id ? 'Verifying...' : 'Verify Payout'}</span>
                          </button>
                        ) : (
                          <span className="text-[10px] text-slate-500 font-mono">✓ Audit Passed</span>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>

        {/* Paystack Auditor (4 cols) */}
        <div className="lg:col-span-4 space-y-4">
          <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
            <div className="border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-lg text-white flex items-center space-x-2">
                <Building2 className="w-5 h-5 text-cyan-400" />
                <span>Paystack Gateway Auditor</span>
              </h3>
              <p className="text-xs text-slate-400 mt-1">Cross-reference Paystack payment transaction reference tokens.</p>
            </div>

            <form onSubmit={handleAuditLookup} className="space-y-3 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Transaction Reference Token</label>
                <div className="flex space-x-2">
                  <input
                    type="text"
                    value={paystackTxRef}
                    onChange={e => setPaystackTxRef(e.target.value)}
                    placeholder="e.g. pstk_tx_99812401"
                    className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 font-mono text-xs focus:outline-none focus:border-cyan-500"
                  />
                  <button
                    type="submit"
                    disabled={isAuditingPaystack}
                    className="px-3 py-2 rounded-xl bg-cyan-600 text-white font-bold hover:bg-cyan-500 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {isAuditingPaystack ? 'Checking...' : 'Lookup'}
                  </button>
                </div>
              </div>
            </form>

            {paystackAuditResult && (
              <div className="p-4 rounded-xl glass-card border border-cyan-500/30 space-y-2.5 text-xs">
                <div className="flex items-center justify-between border-b border-slate-800 pb-2">
                  <span className="font-bold text-white font-mono">{paystackAuditResult.reference}</span>
                  <span className="px-2 py-0.5 rounded bg-emerald-500/20 text-emerald-400 font-mono text-[10px] border border-emerald-500/30">
                    {paystackAuditResult.status.toUpperCase()}
                  </span>
                </div>

                <div className="space-y-1.5 font-mono text-[11px]">
                  <div className="flex justify-between text-slate-400">
                    <span>Processed Amount:</span>
                    <span className="text-white font-bold">{paystackAuditResult.currency ?? ''} {paystackAuditResult.amount.toFixed(2)}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Payment Channel:</span>
                    <span className="text-slate-200">{paystackAuditResult.channel}</span>
                  </div>
                  <div className="flex justify-between text-slate-400">
                    <span>Rider Email:</span>
                    <span className="text-slate-200">{paystackAuditResult.customerEmail}</span>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
