import React, { useMemo, useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import {
  CheckCircle2,
  Clock3,
  FileBadge,
  Loader2,
  ShieldCheck,
  UserRoundCheck,
  XCircle,
} from 'lucide-react';

export const PassengerVerificationInspector: React.FC = () => {
  const { passengerVerifications, reviewPassengerVerification, addNotification } = useAdmin();
  const [selectedId, setSelectedId] = useState<string>(passengerVerifications[0]?.id ?? '');
  const [notes, setNotes] = useState('');
  const [busy, setBusy] = useState<'approved' | 'rejected' | null>(null);
  const [filter, setFilter] = useState<'all' | 'pending' | 'under_review' | 'approved' | 'rejected'>('pending');

  const filtered = useMemo(
    () => passengerVerifications.filter((v) => filter === 'all' || v.status === filter),
    [filter, passengerVerifications],
  );
  const active = filtered.find((v) => v.id === selectedId) ?? filtered[0];

  const handleReview = async (status: 'approved' | 'rejected') => {
    if (!active || busy) return;
    if (status === 'rejected' && !notes.trim()) {
      addNotification({
        type: 'warning',
        title: 'Review note required',
        message: 'Tell the passenger what must be corrected before rejecting the submission.',
        timestamp: new Date().toISOString(),
      });
      return;
    }
    setBusy(status);
    try {
      await reviewPassengerVerification(active.id, status, notes.trim() || undefined);
      setNotes('');
    } catch (error) {
      addNotification({
        type: 'error',
        title: 'Verification review failed',
        message: error instanceof Error ? error.message : 'Could not update verification.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setBusy(null);
    }
  };

  const statusClass = (status: string) => {
    if (status === 'approved') return 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
    if (status === 'rejected') return 'bg-red-500/20 text-red-400 border-red-500/30';
    return 'bg-amber-500/20 text-amber-400 border-amber-500/30';
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      <div className="glass-panel rounded-2xl border border-slate-800 p-6 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-cyan-400 font-mono">
            <UserRoundCheck className="w-4 h-4" />
            <span>Passenger Safety Review</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white mt-1">Passenger Identity Verification</h1>
          <p className="text-xs text-slate-400 mt-1">Compare the ID card with the live selfie before granting ride access.</p>
        </div>
        <div className="flex gap-2 overflow-x-auto">
          {(['pending', 'under_review', 'approved', 'rejected', 'all'] as const).map((item) => (
            <button
              key={item}
              onClick={() => setFilter(item)}
              className={`px-3 py-1.5 rounded-lg border text-xs font-semibold uppercase whitespace-nowrap ${filter === item ? 'bg-cyan-600 text-white border-cyan-500' : 'bg-slate-900 text-slate-400 border-slate-800 hover:text-white'}`}
            >
              {item.replace('_', ' ')}
            </button>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        <div className="lg:col-span-4 glass-panel rounded-2xl border border-slate-800 p-4 space-y-3">
          <div className="flex items-center justify-between border-b border-slate-800 pb-3">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-300">Review queue ({filtered.length})</span>
            <Clock3 className="w-4 h-4 text-slate-500" />
          </div>
          <div className="space-y-2 max-h-[580px] overflow-y-auto">
            {filtered.length === 0 ? (
              <div className="py-12 text-center text-xs text-slate-500">No submissions match this filter.</div>
            ) : filtered.map((verification) => (
              <button
                key={verification.id}
                onClick={() => setSelectedId(verification.id)}
                className={`w-full text-left p-3 rounded-xl border transition-all ${active?.id === verification.id ? 'bg-cyan-950/40 border-cyan-500/60' : 'bg-slate-900/60 border-slate-800 hover:border-slate-700'}`}
              >
                <div className="flex items-center justify-between gap-2">
                  <span className="text-sm font-semibold text-white truncate">{verification.passengerName}</span>
                  <span className={`text-[10px] px-2 py-0.5 rounded-full border uppercase font-mono ${statusClass(verification.status)}`}>{verification.status}</span>
                </div>
                <div className="text-[11px] text-slate-400 mt-1 truncate">{verification.passengerEmail}</div>
                <div className="text-[10px] text-slate-500 mt-2 font-mono">Submitted {new Date(verification.submittedAt).toLocaleString()}</div>
              </button>
            ))}
          </div>
        </div>

        <div className="lg:col-span-8 glass-panel rounded-2xl border border-slate-800 p-5 space-y-5">
          {!active ? (
            <div className="h-[580px] flex items-center justify-center text-sm text-slate-500">Select a passenger submission to inspect.</div>
          ) : (
            <>
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-4">
                <div>
                  <div className="text-xs uppercase tracking-wider text-cyan-400 font-mono font-bold">Identity submission</div>
                  <h2 className="text-xl font-bold text-white mt-1">{active.passengerName}</h2>
                  <p className="text-xs text-slate-400">{active.passengerEmail}</p>
                </div>
                <span className={`text-xs px-3 py-1 rounded-full border uppercase font-mono font-bold ${statusClass(active.status)}`}>{active.status}</span>
              </div>

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div className="rounded-xl border border-slate-800 bg-slate-950/80 p-3">
                  <div className="flex items-center gap-2 text-xs font-bold text-slate-300 mb-3"><FileBadge className="w-4 h-4 text-cyan-400" /> Government ID card</div>
                  {active.idDocumentUrl ? <img src={active.idDocumentUrl} alt="Passenger government ID" className="w-full h-72 object-contain rounded-lg bg-slate-900" /> : <div className="h-72 flex items-center justify-center text-xs text-slate-500">Preview unavailable</div>}
                </div>
                <div className="rounded-xl border border-slate-800 bg-slate-950/80 p-3">
                  <div className="flex items-center gap-2 text-xs font-bold text-slate-300 mb-3"><ShieldCheck className="w-4 h-4 text-emerald-400" /> Live selfie holding ID</div>
                  {active.selfieUrl ? <img src={active.selfieUrl} alt="Passenger live selfie holding ID" className="w-full h-72 object-contain rounded-lg bg-slate-900" /> : <div className="h-72 flex items-center justify-center text-xs text-slate-500">Preview unavailable</div>}
                </div>
              </div>

              <div>
                <label className="block text-xs font-semibold text-slate-300 mb-2">Review notes {active.status === 'rejected' ? '(required for rejection)' : '(optional)'}</label>
                <textarea
                  value={notes}
                  onChange={(event) => setNotes(event.target.value)}
                  rows={3}
                  placeholder="Record what you checked or what the passenger must correct..."
                  className="w-full rounded-xl bg-slate-900 border border-slate-800 px-3 py-2 text-sm text-slate-200 focus:outline-none focus:border-cyan-500"
                />
              </div>

              {active.reviewNotes && <div className="rounded-xl border border-amber-500/30 bg-amber-500/10 p-3 text-xs text-amber-300">Previous review: {active.reviewNotes}</div>}

              <div className="flex flex-col sm:flex-row justify-end gap-3 border-t border-slate-800 pt-4">
                <button onClick={() => handleReview('rejected')} disabled={busy !== null} className="px-4 py-2.5 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 hover:bg-red-500/20 text-xs font-bold disabled:opacity-50 flex items-center justify-center gap-2">
                  {busy === 'rejected' ? <Loader2 className="w-4 h-4 animate-spin" /> : <XCircle className="w-4 h-4" />}
                  Reject & request new captures
                </button>
                <button onClick={() => handleReview('approved')} disabled={busy !== null} className="px-5 py-2.5 rounded-xl bg-slate-100 text-slate-950 text-xs font-bold hover:bg-white disabled:opacity-50 flex items-center justify-center gap-2">
                  {busy === 'approved' ? <Loader2 className="w-4 h-4 animate-spin" /> : <CheckCircle2 className="w-4 h-4" />}
                  Approve & allow rides
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
};
