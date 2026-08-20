import React, { useEffect, useMemo, useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import { fetchRefundableRide } from '../lib/queries';
import type { Refund, RefundStatus } from '../types/admin';
import {
  CornerDownLeft,
  Search,
  ShieldAlert,
  ShieldCheck,
  PiggyBank,
  RefreshCw,
  X,
  Check,
  AlertTriangle,
  Loader2,
  ChevronRight,
  Clock,
} from 'lucide-react';

type StatusFilter = 'all' | RefundStatus;

const STATUS_LABEL: Record<RefundStatus, string> = {
  pending: 'Pending',
  processing: 'Processing',
  completed: 'Completed',
  failed: 'Failed',
  disputed: 'Disputed',
};

const STATUS_BADGE: Record<RefundStatus, string> = {
  pending: 'bg-slate-500/20 text-slate-300 border-slate-500/40',
  processing: 'bg-indigo-500/20 text-indigo-300 border-indigo-500/40',
  completed: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
  failed: 'bg-red-500/20 text-red-300 border-red-500/40',
  disputed: 'bg-amber-500/20 text-amber-300 border-amber-500/40',
};

const STATUS_ICON: Record<RefundStatus, React.FC<{ className?: string }>> = {
  pending: Clock,
  processing: RefreshCw,
  completed: ShieldCheck,
  failed: AlertTriangle,
  disputed: ShieldAlert,
};

interface RefundableRide {
  id: string;
  rideReference: string;
  fare: number;
  paymentMethod: string;
  paymentStatus: string;
  paymentReference: string;
  passengerId: string | null;
  passengerName: string;
  passengerEmail: string;
  driverName: string;
  status: string;
}

const PRESET_REASONS = [
  { value: 'driver_cancelled_after_pickup', label: 'Driver cancelled after pickup' },
  { value: 'fare_adjustment', label: 'Fare adjustment (overcharged)' },
  { value: 'service_not_received', label: 'Passenger disputes receiving service' },
  { value: 'duplicate_charge', label: 'Duplicate / accidental charge' },
  { value: 'safety_incident', label: 'Safety incident restitution' },
  { value: 'other', label: 'Other (write in reason box)' },
];

export const Refunds: React.FC = () => {
  const { refunds, rides, can, issueRefund, disputeRefund, addNotification, refresh } = useAdmin();
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [search, setSearch] = useState('');
  const [newOpen, setNewOpen] = useState(false);
  const [disputingRefund, setDisputingRefund] = useState<Refund | null>(null);
  const [disputeReason, setDisputeReason] = useState('');
  const [disputing, setDisputing] = useState(false);

  const canWrite = can('finance:write');

  const counts = useMemo(() => {
    const c: Record<RefundStatus, number> = {
      pending: 0,
      processing: 0,
      completed: 0,
      failed: 0,
      disputed: 0,
    };
    for (const r of refunds) c[r.status] += 1;
    return c;
  }, [refunds]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return refunds.filter((r) => {
      if (statusFilter !== 'all' && r.status !== statusFilter) return false;
      if (!term) return true;
      return (
        r.paymentReference.toLowerCase().includes(term) ||
        r.rideReference?.toLowerCase().includes(term) ||
        r.passengerName?.toLowerCase().includes(term) ||
        (r.passengerEmail ?? '').toLowerCase().includes(term) ||
        r.paystackRefundId?.toLowerCase().includes(term) ||
        r.reason.toLowerCase().includes(term)
      );
    });
  }, [refunds, statusFilter, search]);

  const summary = useMemo(() => {
    const completed = refunds
      .filter((r) => r.status === 'completed')
      .reduce((sum, r) => sum + (r.processedAmount || r.requestedAmount), 0);
    const failed = refunds.filter((r) => r.status === 'failed').length;
    const disputed = refunds.filter((r) => r.status === 'disputed').length;
    return { completed, failed, disputed };
  }, [refunds]);

  const handleDisputeSubmit = async () => {
    if (!disputingRefund) return;
    setDisputing(true);
    try {
      await disputeRefund(disputingRefund.id, disputeReason.trim() || 'Under review');
      setDisputingRefund(null);
      setDisputeReason('');
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Could not flag dispute',
        message: err instanceof Error ? err.message : 'Unknown error.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setDisputing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold font-heading text-white flex items-center space-x-2">
            <CornerDownLeft className="w-6 h-6 text-emerald-400" />
            <span>Refunds &amp; Disputes</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Issue Paystack refunds, monitor processing state, and flag disputes for follow-up.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={() => refresh()}
            className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold flex items-center space-x-1.5"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Refresh</span>
          </button>
          {canWrite && (
            <button
              onClick={() => setNewOpen(true)}
              className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 text-xs font-bold flex items-center space-x-2"
            >
              <PiggyBank className="w-4 h-4" />
              <span>Issue Refund</span>
            </button>
          )}
        </div>
      </div>

      {/* Summary tiles */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="glass-card border border-slate-800 rounded-xl p-4">
          <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold">Total Refunded</div>
          <div className="text-xl font-bold text-slate-100 mt-1 font-mono">
            R {summary.completed.toFixed(2)}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            {counts.completed} completed refunds
          </div>
        </div>
        <div className="glass-card border border-amber-500/40 rounded-xl p-4">
          <div className="text-[11px] uppercase tracking-wider text-amber-300 font-bold">In Disputes</div>
          <div className="text-xl font-bold text-amber-100 mt-1 font-mono">
            {summary.disputed}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            Routed to Paystack reconciliation
          </div>
        </div>
        <div className="glass-card border border-red-500/40 rounded-xl p-4">
          <div className="text-[11px] uppercase tracking-wider text-red-300 font-bold">Failed</div>
          <div className="text-xl font-bold text-red-100 mt-1 font-mono">
            {summary.failed}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            Paystack rejected or timed out
          </div>
        </div>
        <div className="glass-card border border-slate-800 rounded-xl p-4">
          <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold">Activity</div>
          <div className="text-xl font-bold text-slate-100 mt-1 font-mono">
            {refunds.length}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            Refund records on file
          </div>
        </div>
      </div>

      {/* Status filters */}
      <div className="flex flex-wrap gap-2">
        {(['all', 'pending', 'processing', 'completed', 'failed', 'disputed'] as StatusFilter[]).map((key) => {
          const label = key === 'all' ? 'All' : STATUS_LABEL[key];
          const count = key === 'all' ? refunds.length : counts[key];
          const active = statusFilter === key;
          return (
            <button
              key={key}
              onClick={() => setStatusFilter(key)}
              className={`px-3 py-1.5 rounded-full text-[11px] font-bold border transition ${
                active
                  ? 'bg-slate-100 text-slate-950 border-slate-100'
                  : 'bg-slate-900 border-slate-800 text-slate-300 hover:border-slate-600'
              }`}
            >
              <span>{label}</span>
              {count > 0 && <span className="ml-2 font-mono opacity-70">{count}</span>}
            </button>
          );
        })}
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by payment reference, ride reference, passenger name, email..."
          className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400"
        />
      </div>

      {/* Refund list */}
      <div className="glass-panel border border-slate-800 rounded-2xl overflow-hidden">
        <table className="w-full text-xs">
          <thead className="bg-slate-900/80 border-b border-slate-800 text-slate-400 uppercase tracking-wider">
            <tr>
              <th className="text-left px-4 py-3 font-bold">Ride &amp; Passenger</th>
              <th className="text-left px-4 py-3 font-bold">Amount</th>
              <th className="text-left px-4 py-3 font-bold">Reason</th>
              <th className="text-left px-4 py-3 font-bold">Status</th>
              <th className="text-right px-4 py-3 font-bold">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={5} className="text-center py-12 text-slate-500">
                  No refunds match the current filters.
                </td>
              </tr>
            ) : (
              filtered.map((refund) => {
                const StatusIcon = STATUS_ICON[refund.status];
                return (
                  <tr key={refund.id} className="border-t border-slate-800/80 hover:bg-slate-900/40">
                    <td className="px-4 py-3">
                      <div className="font-bold text-slate-100">
                        {refund.rideReference ?? refund.rideId.slice(0, 8)}
                      </div>
                      <div className="text-[11px] text-slate-400">
                        {refund.passengerName || refund.passengerEmail || 'Unknown passenger'}
                      </div>
                      <div className="text-[11px] text-slate-500 font-mono">
                        Paystack: {refund.paymentReference}
                      </div>
                      {refund.paystackRefundId && (
                        <div className="text-[11px] text-emerald-400 font-mono mt-0.5">
                          Refund ID: {refund.paystackRefundId}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-mono text-slate-100 font-bold">
                        R {(refund.processedAmount || refund.requestedAmount).toFixed(2)}
                      </div>
                      {refund.processedAmount > 0 && refund.processedAmount !== refund.requestedAmount && (
                        <div className="text-[11px] text-slate-400">
                          requested R {refund.requestedAmount.toFixed(2)}
                        </div>
                      )}
                      <div className="text-[11px] text-slate-500 font-mono">{refund.currency}</div>
                    </td>
                    <td className="px-4 py-3 max-w-md">
                      <div className="text-[11px] text-slate-200 line-clamp-2 break-words">
                        {refund.reason}
                      </div>
                      {refund.failureReason && (
                        <div className="text-[11px] text-red-300 mt-1 break-words">
                          Failure: {refund.failureReason}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center space-x-1.5 text-[10px] px-2.5 py-1 rounded-full border font-mono uppercase ${STATUS_BADGE[refund.status]}`}
                      >
                        <StatusIcon className="w-3 h-3" />
                        <span>{STATUS_LABEL[refund.status]}</span>
                      </span>
                      <div className="text-[11px] text-slate-500 mt-1">
                        {new Date(refund.createdAt).toLocaleString('en-ZA', {
                          dateStyle: 'medium',
                          timeStyle: 'short',
                        })}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-right">
                      {canWrite && refund.status !== 'disputed' && (
                        <button
                          onClick={() => setDisputingRefund(refund)}
                          className="px-2.5 py-1.5 rounded-lg bg-amber-500/10 border border-amber-500/40 text-amber-200 text-[11px] font-bold flex items-center space-x-1 ml-auto"
                        >
                          <ShieldAlert className="w-3.5 h-3.5" />
                          <span>Flag Dispute</span>
                        </button>
                      )}
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* New refund dialog */}
      {newOpen && (
        <NewRefundDialog
          onClose={() => setNewOpen(false)}
          onIssued={() => {
            setNewOpen(false);
            refresh();
          }}
          existingRefunds={refunds}
          rides={rides}
          issueRefundFn={issueRefund}
          addNotification={addNotification}
        />
      )}

      {/* Dispute dialog */}
      {disputingRefund && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setDisputingRefund(null)}
        >
          <div
            className="w-full max-w-md glass-panel border border-amber-500/40 rounded-2xl p-6 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start space-x-3">
              <ShieldAlert className="w-6 h-6 text-amber-300 shrink-0 mt-0.5" />
              <div>
                <h3 className="text-sm font-bold text-white">Flag refund dispute</h3>
                <p className="text-[11px] text-slate-400 mt-1">
                  {disputingRefund.paymentReference} · R {(disputingRefund.processedAmount || disputingRefund.requestedAmount).toFixed(2)}
                </p>
              </div>
            </div>
            <div>
              <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
                Dispute note (visible in audit log)
              </label>
              <textarea
                value={disputeReason}
                onChange={(e) => setDisputeReason(e.target.value)}
                rows={3}
                placeholder="Explain why finance is escalating this refund..."
                className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-amber-400 resize-none"
              />
            </div>
            <div className="flex items-center justify-end space-x-2 pt-2">
              <button
                onClick={() => setDisputingRefund(null)}
                className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
              >
                Cancel
              </button>
              <button
                onClick={handleDisputeSubmit}
                disabled={disputing}
                className="px-3 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
              >
                {disputing ? <Loader2 className="w-4 h-4 animate-spin" /> : <ShieldAlert className="w-4 h-4" />}
                <span>Flag for Investigation</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

interface NewRefundDialogProps {
  onClose: () => void;
  onIssued: () => void;
  existingRefunds: Refund[];
  rides: import('../types/admin').Ride[];
  issueRefundFn: (params: {
    rideId: string;
    amount: number;
    reason: string;
    notes?: Record<string, unknown>;
  }) => Promise<string>;
  addNotification: (n: {
    type: 'info' | 'success' | 'warning' | 'error';
    title: string;
    message: string;
    timestamp: string;
  }) => void;
}

const NewRefundDialog: React.FC<NewRefundDialogProps> = ({
  onClose,
  onIssued,
  existingRefunds,
  issueRefundFn,
  addNotification,
}) => {
  const [identifier, setIdentifier] = useState('');
  const [ride, setRide] = useState<RefundableRide | null>(null);
  const [amountText, setAmountText] = useState('');
  const [reasonPreset, setReasonPreset] = useState<string>(PRESET_REASONS[0].value);
  const [customReason, setCustomReason] = useState('');
  const [searchingRide, setSearchingRide] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Reset dependent fields when the user searches a new ride.
  useEffect(() => {
    setRide(null);
    setAmountText('');
    setError(null);
  }, [identifier]);

  const searchRide = async () => {
    if (!identifier.trim()) return;
    setSearchingRide(true);
    setError(null);
    try {
      const found = await fetchRefundableRide(identifier.trim());
      if (!found) {
        setError('No ride matches that id, payment_reference, or ride_reference.');
        return;
      }
      if (found.paymentMethod === 'Cash') {
        setError('Cash rides cannot be refunded. Use driver wallet adjustments instead.');
        return;
      }
      if (found.paymentStatus !== 'paid') {
        setError(`Only paid rides can be refunded (current: ${found.paymentStatus}).`);
        return;
      }
      if (!found.paymentReference) {
        setError('This ride has no payment_reference - Paystack cannot refund it.');
        return;
      }
      const already = existingRefunds.find((r) => r.rideId === found.id && r.status !== 'failed');
      if (already) {
        setError(`A ${already.status} refund already exists for this ride.`);
        return;
      }
      setRide(found);
      setAmountText(found.fare.toFixed(2));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load ride.');
    } finally {
      setSearchingRide(false);
    }
  };

  const handleSubmit = async () => {
    if (!ride) {
      setError('Search and confirm a ride first.');
      return;
    }
    const amount = parseFloat(amountText);
    if (!Number.isFinite(amount) || amount <= 0) {
      setError('Refund amount must be a positive number.');
      return;
    }
    if (amount > ride.fare + 0.01) {
      setError(`Refund amount cannot exceed ride fare (R ${ride.fare.toFixed(2)}).`);
      return;
    }
    const reason =
      reasonPreset === 'other'
        ? customReason.trim()
        : PRESET_REASONS.find((r) => r.value === reasonPreset)?.label ?? '';
    if (reason.length < 4) {
      setError('Please choose or write a reason of at least 4 characters.');
      return;
    }
    setSubmitting(true);
    setError(null);
    try {
      await issueRefundFn({
        rideId: ride.id,
        amount,
        reason,
        notes: {
          ride_reference: ride.rideReference,
          passenger_id: ride.passengerId,
          preset: reasonPreset,
        },
      });
      addNotification({
        type: 'success',
        title: 'Refund issued',
        message: `R ${amount.toFixed(2)} refunded for ride ${ride.rideReference || ride.id.slice(0, 8)}.`,
        timestamp: new Date().toISOString(),
      });
      onIssued();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Refund failed.');
    } finally {
      setSubmitting(false);
    }
  };

  const finalReason =
    reasonPreset === 'other'
      ? customReason
      : PRESET_REASONS.find((r) => r.value === reasonPreset)?.label ?? '';

  return (
    <div
      className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg glass-panel border border-slate-800 rounded-2xl p-6 space-y-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between">
          <div>
            <h3 className="text-sm font-bold text-white flex items-center space-x-2">
              <PiggyBank className="w-4 h-4 text-emerald-400" />
              <span>Issue a Refund</span>
            </h3>
            <p className="text-[11px] text-slate-400 mt-1">
              Refunds settle via Paystack and mark the ride's payment_status as refunded.
            </p>
          </div>
          <button onClick={onClose} className="p-1 text-slate-500 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Step 1: find the ride */}
        <div>
          <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
            Find a settled ride
          </label>
          <div className="flex items-center gap-2">
            <input
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              placeholder="Ride UUID, payment_reference, or ride_reference"
              className="flex-1 px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400"
            />
            <button
              onClick={searchRide}
              disabled={!identifier.trim() || searchingRide}
              className="px-3 py-2.5 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-1.5 disabled:opacity-40"
            >
              {searchingRide ? <Loader2 className="w-4 h-4 animate-spin" /> : <Search className="w-4 h-4" />}
              <span>Search</span>
            </button>
          </div>
        </div>

        {/* Step 2: confirm details */}
        {ride && (
          <div className="bg-slate-900/60 border border-slate-800 rounded-xl p-4 space-y-2 text-xs">
            <div className="flex justify-between">
              <span className="text-slate-400">Trip</span>
              <span className="text-slate-100 font-mono">{ride.rideReference || ride.id.slice(0, 8)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Passenger</span>
              <span className="text-slate-100">{ride.passengerName || ride.passengerEmail || ride.passengerId?.slice(0, 8)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Driver</span>
              <span className="text-slate-100">{ride.driverName || '—'}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Original fare</span>
              <span className="text-slate-100 font-mono">R {ride.fare.toFixed(2)}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Paystack reference</span>
              <span className="text-slate-100 font-mono">{ride.paymentReference}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-400">Payment state</span>
              <span className="text-emerald-300 font-mono">{ride.paymentStatus}</span>
            </div>
          </div>
        )}

        {/* Step 3: amount & reason */}
        {ride && (
          <>
            <div>
              <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
                Refund amount (ZAR)
              </label>
              <input
                value={amountText}
                onChange={(e) => setAmountText(e.target.value)}
                inputMode="decimal"
                placeholder="0.00"
                className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm font-mono placeholder-slate-500 focus:outline-none focus:border-slate-400"
              />
              <p className="text-[11px] text-slate-500 mt-1">
                Up to R {ride.fare.toFixed(2)} (the original fare).
              </p>
            </div>

            <div>
              <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
                Reason
              </label>
              <div className="grid grid-cols-2 gap-2">
                {PRESET_REASONS.map((r) => (
                  <button
                    key={r.value}
                    onClick={() => setReasonPreset(r.value)}
                    className={`px-3 py-2 rounded-xl border text-[11px] font-bold text-left ${
                      reasonPreset === r.value
                        ? 'bg-slate-100 text-slate-950 border-slate-100'
                        : 'bg-slate-900 border-slate-700 text-slate-300 hover:border-slate-500'
                    }`}
                  >
                    {r.label}
                  </button>
                ))}
              </div>
              {reasonPreset === 'other' && (
                <textarea
                  value={customReason}
                  onChange={(e) => setCustomReason(e.target.value)}
                  placeholder="Describe the reason for this refund..."
                  rows={2}
                  className="w-full mt-2 px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400 resize-none"
                />
              )}
              {finalReason && (
                <p className="text-[11px] text-slate-400 mt-2 flex items-center space-x-1">
                  <ChevronRight className="w-3 h-3" />
                  <span>This reason will be sent to Paystack and recorded in the audit log.</span>
                </p>
              )}
            </div>
          </>
        )}

        {error && (
          <div className="flex items-start space-x-2 p-3 rounded-xl border border-red-500/40 bg-red-500/10 text-red-200 text-xs">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <div className="flex items-center justify-end space-x-2 pt-2">
          <button
            onClick={onClose}
            className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={!ride || submitting}
            className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
          >
            {submitting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Check className="w-4 h-4" />}
            <span>Submit Refund</span>
          </button>
        </div>
      </div>
    </div>
  );
};
