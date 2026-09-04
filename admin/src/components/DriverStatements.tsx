/**
 * Driver Statements Module
 * Generate, download, and send weekly earnings statements to drivers
 */

import React, { useState, useCallback } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  FileText,
  Download,
  Send,
  Calendar,
  Loader2,
  CheckCircle,
  AlertCircle,
  TrendingUp,
  Clock,
} from 'lucide-react';
import {
  fetchAllDriverStatements,
  sendDriverStatements,
} from '../lib/queries';
import { downloadStatementPDF, downloadAllStatementsPDF } from '../lib/pdfGenerator';
import type { DriverStatementSummary, StatementPeriod } from '../types/admin';

// Helper to get last Monday
function getLastMonday(date: Date = new Date()): Date {
  const d = new Date(date);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  d.setDate(diff);
  d.setHours(0, 0, 0, 0);
  return d;
}

// Helper to format date for input
function formatDateForInput(date: Date): string {
  return date.toISOString().split('T')[0];
}

function getPreviousWeekPeriod(date: Date = new Date()): StatementPeriod {
  const thisMonday = getLastMonday(date);
  const previousMonday = new Date(thisMonday);
  previousMonday.setDate(previousMonday.getDate() - 7);
  const previousSunday = new Date(thisMonday);
  previousSunday.setDate(previousSunday.getDate() - 1);
  return {
    start: formatDateForInput(previousMonday),
    end: formatDateForInput(previousSunday),
    label: 'Last Week (Mon-Sun)',
  };
}

// Statement period options
const PERIOD_OPTIONS: StatementPeriod[] = [
  {
    start: formatDateForInput(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)),
    end: formatDateForInput(new Date()),
    label: 'Last 7 Days',
  },
  {
    start: formatDateForInput(getLastMonday()),
    end: formatDateForInput(new Date()),
    label: 'This Week (Mon-Today)',
  },
  getPreviousWeekPeriod(),
  {
    start: formatDateForInput(
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    ),
    end: formatDateForInput(new Date()),
    label: 'Last 30 Days',
  },
];

export const DriverStatements: React.FC = () => {
  const { addNotification } = useAdmin();

  // State
  const [selectedPeriod, setSelectedPeriod] = useState<StatementPeriod>(PERIOD_OPTIONS[0]);
  const [customStartDate, setCustomStartDate] = useState(formatDateForInput(new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)));
  const [customEndDate, setCustomEndDate] = useState(formatDateForInput(new Date()));
  const [useCustomDates, setUseCustomDates] = useState(false);

  const [statements, setStatements] = useState<DriverStatementSummary[]>([]);
  const [loading, setLoading] = useState(false);
  const [generating, setGenerating] = useState(false);
  const [sending, setSending] = useState(false);
  const [selectedDriverIds, setSelectedDriverIds] = useState<Set<string>>(new Set());
  const selectedStatements = statements.filter((statement) => selectedDriverIds.has(statement.driverId));

  // Fetch statements
  const handleGenerateStatements = useCallback(async () => {
    setGenerating(true);
    try {
      const startDate = useCustomDates ? customStartDate : selectedPeriod.start;
      const endDate = useCustomDates ? customEndDate : selectedPeriod.end;

      if (!startDate || !endDate || startDate > endDate) {
        throw new Error('Choose a valid statement period where the start date is before the end date.');
      }
      const data = await fetchAllDriverStatements(startDate, endDate);
      setStatements(data);
      setSelectedDriverIds(new Set());

      addNotification({
        type: 'success',
        title: 'Statements Generated',
        message: `Generated ${data.length} driver statements for ${startDate} to ${endDate}`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Generation Failed',
        message: err instanceof Error ? err.message : 'Failed to generate statements',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setGenerating(false);
    }
  }, [useCustomDates, customStartDate, customEndDate, selectedPeriod, addNotification]);

  // Download single statement
  const handleDownloadStatement = async (statement: DriverStatementSummary) => {
    try {
      await downloadStatementPDF(statement);
      addNotification({
        type: 'success',
        title: 'Download Started',
        message: `Statement for ${statement.driverName} is downloading`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Download Failed',
        message: err instanceof Error ? err.message : 'Failed to download statement',
        timestamp: new Date().toISOString(),
      });
    }
  };

  // Download the selected statements, or the full batch when none are selected.
  const handleDownloadAll = async () => {
    const downloads = selectedStatements.length > 0 ? selectedStatements : statements;
    if (downloads.length === 0) return;

    setLoading(true);
    try {
      await downloadAllStatementsPDF(downloads);
      addNotification({
        type: 'success',
        title: 'Statements Downloaded',
        message: `Downloaded ${downloads.length} statement${downloads.length === 1 ? '' : 's'}`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Download Failed',
        message: err instanceof Error ? err.message : 'Failed to download statements',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setLoading(false);
    }
  };

  // Send the selected statements, or all statements when none are selected.
  const handleSendAllStatements = async () => {
    const recipients = selectedStatements.length > 0 ? selectedStatements : statements;
    if (recipients.length === 0) return;

    setSending(true);
    try {
      const result = await sendDriverStatements(recipients);
      addNotification({
        type: result.failed === 0 ? 'success' : 'warning',
        title: 'Statements Sent',
        message: `Successfully sent ${result.success} of ${recipients.length} statements${result.failed > 0 ? ` (${result.failed} failed)` : ''}`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Send Failed',
        message: err instanceof Error ? err.message : 'Failed to send statements',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setSending(false);
    }
  };

  // Toggle driver selection
  const toggleDriverSelection = (driverId: string) => {
    setSelectedDriverIds(prev => {
      const next = new Set(prev);
      if (next.has(driverId)) {
        next.delete(driverId);
      } else {
        next.add(driverId);
      }
      return next;
    });
  };

  // Select all drivers
  const selectAllDrivers = () => {
    if (selectedDriverIds.size === statements.length) {
      setSelectedDriverIds(new Set());
    } else {
      setSelectedDriverIds(new Set(statements.map(s => s.driverId)));
    }
  };

  // Calculate totals
  const totalEarnings = statements.reduce((sum, s) => sum + s.totalNetEarnings, 0);
  const totalTrips = statements.reduce((sum, s) => sum + s.totalTrips, 0);
  const totalCash = statements.reduce((sum, s) => sum + s.cashCollected, 0);
  const totalOnline = statements.reduce((sum, s) => sum + s.onlineEarnings, 0);

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-green-400 mb-1 font-mono">
            <FileText className="w-4 h-4 text-green-400" />
            <span>Module 5 Driver Statements</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">
            Weekly Earnings Statements
          </h1>
          <p className="text-slate-400 text-xs mt-1">
            Generate, download, and send weekly earnings statements to all drivers.
            Statements auto-generate every Monday and can be manually triggered.
          </p>
        </div>

        <div className="flex items-center space-x-3">
          <button
            onClick={handleGenerateStatements}
            disabled={generating}
            className="px-5 py-2.5 rounded-xl bg-green-600 text-white text-xs font-bold shadow-lg shadow-green-500/20 hover:bg-green-500 transition-all flex items-center space-x-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {generating ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <FileText className="w-4 h-4" />
            )}
            <span>{generating ? 'Generating...' : 'Generate Statements'}</span>
          </button>
        </div>
      </div>

      {/* Date Selection */}
      <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
        <div className="flex items-center space-x-2 text-sm font-bold text-white">
          <Calendar className="w-4 h-4 text-green-400" />
          <span>Statement Period</span>
        </div>

        {/* Quick Period Selection */}
        <div className="flex flex-wrap gap-2">
          {PERIOD_OPTIONS.map((period) => (
            <button
              key={period.label}
              onClick={() => {
                setSelectedPeriod(period);
                setUseCustomDates(false);
              }}
              className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
                !useCustomDates && selectedPeriod.label === period.label
                  ? 'bg-green-600 text-white'
                  : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
              }`}
            >
              {period.label}
            </button>
          ))}
          <button
            onClick={() => setUseCustomDates(true)}
            className={`px-4 py-2 rounded-xl text-xs font-semibold transition-all ${
              useCustomDates
                ? 'bg-green-600 text-white'
                : 'bg-slate-800 text-slate-300 hover:bg-slate-700'
            }`}
          >
            Custom Range
          </button>
        </div>

        {/* Custom Date Inputs */}
        {useCustomDates && (
          <div className="flex items-center space-x-4 mt-4">
            <div>
              <label className="block text-xs text-slate-400 mb-1">Start Date</label>
              <input
                type="date"
                value={customStartDate}
                onChange={(e) => setCustomStartDate(e.target.value)}
                className="px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-sm text-slate-200 focus:outline-none focus:border-green-500"
              />
            </div>
            <div>
              <label className="block text-xs text-slate-400 mb-1">End Date</label>
              <input
                type="date"
                value={customEndDate}
                onChange={(e) => setCustomEndDate(e.target.value)}
                className="px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-sm text-slate-200 focus:outline-none focus:border-green-500"
              />
            </div>
          </div>
        )}

        <div className="text-xs text-slate-500">
          {useCustomDates
            ? `Custom period: ${customStartDate} to ${customEndDate}`
            : `Period: ${selectedPeriod.start} to ${selectedPeriod.end}`}
        </div>
      </div>

      {/* Summary Cards */}
      {statements.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
              Total Drivers
            </span>
            <div className="text-2xl font-extrabold text-white font-mono">
              {statements.length}
            </div>
            <div className="text-[10px] text-slate-500 font-mono">Active Drivers</div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
              Total Trips
            </span>
            <div className="text-2xl font-extrabold text-cyan-400 font-mono">{totalTrips}</div>
            <div className="text-[10px] text-slate-500 font-mono">Completed Rides</div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
              Cash Collected
            </span>
            <div className="text-2xl font-extrabold text-amber-400 font-mono">
              R{totalCash.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}
            </div>
            <div className="text-[10px] text-slate-500 font-mono">By Drivers</div>
          </div>

          <div className="glass-card p-5 rounded-2xl border border-slate-800 space-y-1">
            <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
              Online Payments
            </span>
            <div className="text-2xl font-extrabold text-green-400 font-mono">
              R{totalOnline.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}
            </div>
            <div className="text-[10px] text-slate-500 font-mono">Held by TRYP</div>
          </div>
        </div>
      )}

      {/* Statements Table */}
      {statements.length > 0 ? (
        <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
            <div className="flex items-center space-x-3">
              <h3 className="font-heading font-bold text-lg text-white">Driver Statements</h3>
              <span className="text-xs text-slate-400">
                ({statements.length} drivers)
              </span>
            </div>

            <div className="flex items-center space-x-2">
              <button
                onClick={selectAllDrivers}
                className="px-3 py-1.5 rounded-lg bg-slate-800 text-slate-300 text-xs font-semibold hover:bg-slate-700 transition-colors"
              >
                {selectedDriverIds.size === statements.length ? 'Deselect All' : 'Select All'}
              </button>
              <button
                onClick={handleDownloadAll}
                disabled={loading}
                className="px-3 py-1.5 rounded-lg bg-cyan-600/20 border border-cyan-500/40 text-cyan-300 text-xs font-semibold hover:bg-cyan-600/40 transition-colors flex items-center space-x-1.5 disabled:opacity-50"
              >
                {loading ? (
                  <Loader2 className="w-3 h-3 animate-spin" />
                ) : (
                  <Download className="w-3 h-3" />
                )}
                <span>{selectedStatements.length > 0 ? `Download Selected (${selectedStatements.length})` : 'Download All'}</span>
              </button>
              <button
                onClick={handleSendAllStatements}
                disabled={sending || statements.length === 0}
                className="px-3 py-1.5 rounded-lg bg-green-600 text-white text-xs font-bold hover:bg-green-500 transition-colors flex items-center space-x-1.5 disabled:opacity-50"
              >
                {sending ? (
                  <Loader2 className="w-3 h-3 animate-spin" />
                ) : (
                  <Send className="w-3 h-3" />
                )}
                <span>{selectedStatements.length > 0 ? `Send to Selected (${selectedStatements.length})` : 'Send to All Drivers'}</span>
              </button>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead>
                <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
                  <th className="py-3 px-3 w-8">
                    <input
                      type="checkbox"
                      checked={selectedDriverIds.size === statements.length && statements.length > 0}
                      onChange={selectAllDrivers}
                      className="rounded border-slate-600 bg-slate-800 text-green-500 focus:ring-green-500"
                    />
                  </th>
                  <th className="py-3 px-3">Driver</th>
                  <th className="py-3 px-3">Trips</th>
                  <th className="py-3 px-3">Cash</th>
                  <th className="py-3 px-3">Online</th>
                  <th className="py-3 px-3">Net Earnings</th>
                  <th className="py-3 px-3">Rating</th>
                  <th className="py-3 px-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/60">
                {statements.map((statement) => (
                  <tr
                    key={statement.driverId}
                    className="hover:bg-slate-900/60 transition-colors text-slate-300"
                  >
                    <td className="py-3 px-3">
                      <input
                        type="checkbox"
                        checked={selectedDriverIds.has(statement.driverId)}
                        onChange={() => toggleDriverSelection(statement.driverId)}
                        className="rounded border-slate-600 bg-slate-800 text-green-500 focus:ring-green-500"
                      />
                    </td>
                    <td className="py-3 px-3">
                      <div className="font-semibold text-slate-100">{statement.driverName}</div>
                      <div className="text-[10px] text-slate-400">{statement.vehiclePlate}</div>
                    </td>
                    <td className="py-3 px-3 font-mono text-slate-400">
                      <div className="flex items-center space-x-1">
                        <TrendingUp className="w-3 h-3 text-green-400" />
                        <span>{statement.totalTrips}</span>
                      </div>
                      <div className="text-[10px] text-slate-500">
                        {statement.cashTrips} cash / {statement.onlineTrips} card
                      </div>
                    </td>
                    <td className="py-3 px-3 font-mono text-amber-400">
                      R{statement.cashCollected.toFixed(2)}
                    </td>
                    <td className="py-3 px-3 font-mono text-cyan-400">
                      R{statement.onlineEarnings.toFixed(2)}
                    </td>
                    <td className="py-3 px-3 font-mono font-bold text-green-400">
                      R{statement.totalNetEarnings.toFixed(2)}
                    </td>
                    <td className="py-3 px-3">
                      <span className="text-amber-400">⭐</span> {statement.rating.toFixed(1)}
                    </td>
                    <td className="py-3 px-3 text-right">
                      <div className="flex items-center justify-end space-x-2">
                        <button
                          onClick={() => handleDownloadStatement(statement)}
                          className="px-2 py-1 rounded-lg bg-cyan-600/20 border border-cyan-500/40 text-cyan-300 hover:bg-cyan-600/40 text-[10px] font-semibold flex items-center space-x-1"
                        >
                          <Download className="w-3 h-3" />
                          <span>PDF</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Footer Summary */}
          <div className="flex items-center justify-between pt-3 border-t border-slate-800 text-xs">
            <div className="text-slate-400">
              Selected: {selectedDriverIds.size} of {statements.length} drivers
            </div>
            <div className="font-mono text-green-400 font-bold">
              Total Net Earnings: R{totalEarnings.toLocaleString('en-ZA', { minimumFractionDigits: 2 })}
            </div>
          </div>
        </div>
      ) : (
        <div className="glass-panel rounded-2xl p-12 border border-slate-800 text-center">
          <FileText className="w-16 h-16 text-slate-600 mx-auto mb-4" />
          <h3 className="text-xl font-bold text-white mb-2">No Statements Generated</h3>
          <p className="text-slate-400 text-sm max-w-md mx-auto">
            Select a date range and click "Generate Statements" to create weekly earnings statements for all active drivers.
          </p>
        </div>
      )}

      {/* Info Panel */}
      <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
        <div className="flex items-center space-x-2 text-sm font-bold text-white">
          <Clock className="w-4 h-4 text-green-400" />
          <span>Auto-Generation Schedule</span>
        </div>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs text-slate-400">
          <div className="space-y-2">
            <div className="flex items-start space-x-2">
              <CheckCircle className="w-4 h-4 text-green-400 mt-0.5" />
              <span>Statements auto-generate every Monday at 08:00 SAST</span>
            </div>
            <div className="flex items-start space-x-2">
              <CheckCircle className="w-4 h-4 text-green-400 mt-0.5" />
              <span>Auto-delivery to all drivers via email on Monday mornings</span>
            </div>
            <div className="flex items-start space-x-2">
              <CheckCircle className="w-4 h-4 text-green-400 mt-0.5" />
              <span>Covers Monday 00:00 to Sunday 23:59 of the preceding week</span>
            </div>
          </div>
          <div className="space-y-2">
            <div className="flex items-start space-x-2">
              <AlertCircle className="w-4 h-4 text-amber-400 mt-0.5" />
              <span>Card/Online payouts processed every Monday and Friday</span>
            </div>
            <div className="flex items-start space-x-2">
              <AlertCircle className="w-4 h-4 text-amber-400 mt-0.5" />
              <span>Cash earnings retained by driver after passenger collection</span>
            </div>
            <div className="flex items-start space-x-2">
              <AlertCircle className="w-4 h-4 text-amber-400 mt-0.5" />
              <span>Manual generation available for custom date ranges</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
