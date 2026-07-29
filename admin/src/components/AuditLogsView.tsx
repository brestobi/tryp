import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import { FileText, Search, Terminal } from 'lucide-react';

export const AuditLogsView: React.FC = () => {
  const { auditLogs } = useAdmin();
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [roleFilter, setRoleFilter] = useState<string>('All');

  const filteredLogs = auditLogs.filter(log => {
    if (roleFilter !== 'All' && log.adminRole !== roleFilter) return false;
    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      return (
        log.action.toLowerCase().includes(term) ||
        log.details.toLowerCase().includes(term) ||
        log.adminName.toLowerCase().includes(term) ||
        log.targetId.toLowerCase().includes(term)
      );
    }
    return true;
  });

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-purple-400 mb-1 font-mono">
            <FileText className="w-4 h-4 text-purple-400" />
            <span>Module 6 Governance & Security</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Administrative Audit Trail</h1>
          <p className="text-slate-400 text-xs mt-1">
            Immutable log feed auditing all back-office administrative actions, fare adjustments, and KYC overrides.
          </p>
        </div>

        {/* Filters */}
        <div className="flex items-center space-x-3">
          <div className="relative">
            <Search className="w-3.5 h-3.5 text-slate-400 absolute left-3 top-2.5" />
            <input
              type="text"
              placeholder="Search audit log..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="pl-8 pr-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 focus:outline-none focus:border-purple-500 w-56"
            />
          </div>

          <select
            value={roleFilter}
            onChange={e => setRoleFilter(e.target.value)}
            className="px-3 py-1.5 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-200 focus:outline-none font-medium"
          >
            <option value="All">All Admin Roles</option>
            <option value="super_admin">Super Admin</option>
            <option value="kyc_officer">KYC Officer</option>
            <option value="fleet_dispatcher">Fleet Dispatcher</option>
            <option value="finance_manager">Finance Manager</option>
          </select>
        </div>
      </div>

      {/* Log Feed Table */}
      <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="font-heading font-bold text-lg text-white flex items-center space-x-2">
            <Terminal className="w-4 h-4 text-purple-400" />
            <span>Audit Log Stream</span>
          </h3>
          <span className="text-xs text-slate-400 font-mono">Showing {filteredLogs.length} events</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
                <th className="py-3 px-4">Timestamp</th>
                <th className="py-3 px-4">Admin Agent</th>
                <th className="py-3 px-4">Action Event</th>
                <th className="py-3 px-4">Target ID</th>
                <th className="py-3 px-4">Event Details</th>
                <th className="py-3 px-4 text-right">IP Address</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60 font-mono">
              {filteredLogs.map(log => (
                <tr key={log.id} className="hover:bg-slate-900/60 transition-colors text-slate-300">
                  <td className="py-3 px-4 text-slate-400 text-[11px]">
                    {new Date(log.timestamp).toLocaleString()}
                  </td>
                  <td className="py-3 px-4 font-sans font-semibold text-slate-100">
                    <div>{log.adminName}</div>
                    <div className="text-[10px] text-purple-400 font-mono font-normal">{log.adminRole}</div>
                  </td>
                  <td className="py-3 px-4">
                    <span className="px-2 py-0.5 rounded bg-purple-500/10 text-purple-300 border border-purple-500/20 font-bold text-[10px]">
                      {log.action}
                    </span>
                  </td>
                  <td className="py-3 px-4 text-slate-400 text-[11px]">{log.targetId}</td>
                  <td className="py-3 px-4 font-sans text-slate-200 text-xs leading-relaxed">
                    {log.details}
                  </td>
                  <td className="py-3 px-4 text-right text-slate-500 text-[10px]">{log.ipAddress}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
