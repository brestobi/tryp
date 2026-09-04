import React, { useMemo, useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import type { ScheduledRide } from '../types/admin';
import {
  CalendarClock,
  RefreshCw,
  Search,
  ArrowRight,
  XCircle,
  Clock,
  Edit3,
  Mail,
  Phone,
  CheckCircle2,
  AlertTriangle,
  Loader2,
  X,
} from 'lucide-react';
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  Polyline,
} from 'react-leaflet';
import L from 'leaflet';

type StatusFilter = 'all' | 'upcoming' | 'overdue' | 'accepted' | 'cancelled';

const pickupIcon = L.icon({
  iconUrl: `data:image/svg+xml;utf8,${encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="#22d3ee" stroke="#0f172a" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4" fill="#0f172a"/></svg>',
  )}`,
  iconSize: [28, 28],
  iconAnchor: [14, 14],
});

const destIcon = L.icon({
  iconUrl: `data:image/svg+xml;utf8,${encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="#f97316" stroke="#0f172a" stroke-width="2"><path d="M12 2 L 22 22 L 2 22 z"/><circle cx="12" cy="14" r="3" fill="#0f172a"/></svg>',
  )}`,
  iconSize: [28, 28],
  iconAnchor: [14, 28],
});

const STATUS_BADGE: Record<'requested' | 'accepted' | 'cancelled', string> = {
  requested: 'bg-indigo-500/20 text-indigo-300 border-indigo-500/40',
  accepted: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
  cancelled: 'bg-slate-500/20 text-slate-300 border-slate-500/40',
};

const FALLBACK_CENTER: [number, number] = [-26.2041, 28.0473];

const isUpcoming = (iso: string) => new Date(iso).getTime() > Date.now();
const isOverdue = (ride: ScheduledRide) =>
  ride.status === 'requested' && new Date(ride.scheduledFor).getTime() <= Date.now();

interface EditingDraft {
  ride: ScheduledRide;
  /** Local datetime input value (YYYY-MM-DDTHH:mm) — converted to ISO on submit. */
  newDateLocal: string;
  reason: string;
  error: string | null;
}

interface CancelDraft {
  ride: ScheduledRide;
  reason: string;
}

const padTwo = (n: number) => (n < 10 ? `0${n}` : `${n}`);

const toLocalInputValue = (iso: string): string => {
  const d = new Date(iso);
  return `${d.getFullYear()}-${padTwo(d.getMonth() + 1)}-${padTwo(d.getDate())}T${padTwo(
    d.getHours(),
  )}:${padTwo(d.getMinutes())}`;
};

const fromLocalInputValue = (local: string): string => {
  // The datetime-local input gives us a naive local timestamp; treat it as
  // local time and convert to an ISO string in UTC for the RPC.
  const parsed = new Date(local);
  return parsed.toISOString();
};

export const ScheduledRides: React.FC = () => {
  const {
    scheduledRides,
    can,
    rescheduleScheduledRide,
    cancelScheduledRideAction,
    refresh,
    addNotification,
  } = useAdmin();

  const canOperate = can('fleet:read');

  const [filter, setFilter] = useState<StatusFilter>('all');
  const [search, setSearch] = useState('');
  const [editing, setEditing] = useState<EditingDraft | null>(null);
  const [cancelling, setCancelling] = useState<CancelDraft | null>(null);
  const [submitting, setSubmitting] = useState<string | null>(null);

  const counts = useMemo(() => {
    const upcoming = scheduledRides.filter(
      (r) => r.status === 'requested' && isUpcoming(r.scheduledFor),
    ).length;
    const overdue = scheduledRides.filter(isOverdue).length;
    const accepted = scheduledRides.filter((r) => r.status === 'accepted').length;
    const cancelled = scheduledRides.filter((r) => r.status === 'cancelled').length;
    return { upcoming, overdue, accepted, cancelled };
  }, [scheduledRides]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return scheduledRides
      .filter((r) => {
        if (filter === 'upcoming' && !(r.status === 'requested' && isUpcoming(r.scheduledFor))) return false;
        if (filter === 'overdue' && !isOverdue(r)) return false;
        if (filter === 'accepted' && r.status !== 'accepted') return false;
        if (filter === 'cancelled' && r.status !== 'cancelled') return false;
        if (!term) return true;
        return (
          r.rideReference.toLowerCase().includes(term) ||
          r.passengerName.toLowerCase().includes(term) ||
          r.passengerEmail.toLowerCase().includes(term) ||
          r.passengerPhone.toLowerCase().includes(term) ||
          r.origin.toLowerCase().includes(term) ||
          r.destination.toLowerCase().includes(term) ||
          (r.driverName ?? '').toLowerCase().includes(term) ||
          (r.driverPlate ?? '').toLowerCase().includes(term)
        );
      })
      .sort((a, b) => new Date(a.scheduledFor).getTime() - new Date(b.scheduledFor).getTime());
  }, [scheduledRides, filter, search]);

  const handleSubmitReschedule = async () => {
    if (!editing) return;
    setSubmitting('reschedule');
    try {
      await rescheduleScheduledRide(
        editing.ride.id,
        fromLocalInputValue(editing.newDateLocal),
        editing.reason,
      );
      setEditing(null);
    } catch (err) {
      setEditing({
        ...editing,
        error: err instanceof Error ? err.message : 'Reschedule failed.',
      });
    } finally {
      setSubmitting(null);
    }
  };

  const handleConfirmCancel = async () => {
    if (!cancelling) return;
    setSubmitting('cancel');
    try {
      await cancelScheduledRideAction(cancelling.ride.id, cancelling.reason);
      setCancelling(null);
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Cancellation failed',
        message: err instanceof Error ? err.message : 'Could not cancel scheduled ride.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setSubmitting(null);
    }
  };

  if (!canOperate) {
    return (
      <div className="glass-panel border border-slate-800 rounded-2xl p-8 max-w-2xl mx-auto text-center">
        <CalendarClock className="w-10 h-10 mx-auto text-slate-500" />
        <h2 className="text-xl font-bold font-heading text-white mt-4">Scheduled rides restricted</h2>
        <p className="text-xs text-slate-400 mt-2">
          Only fleet operators and super admins can manage scheduled bookings.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold font-heading text-white flex items-center space-x-2">
            <CalendarClock className="w-6 h-6 text-indigo-400" />
            <span>Scheduled Rides</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Future-booked trips awaiting dispatch. Reschedule or cancel any booking
            ahead of its pickup window.
          </p>
        </div>
        <button
          onClick={() => refresh()}
          className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold flex items-center space-x-1.5"
        >
          <RefreshCw className="w-4 h-4" />
          <span>Refresh</span>
        </button>
      </div>

      {counts.overdue > 0 && (
        <div className="flex items-start space-x-3 p-4 rounded-xl border border-amber-500/40 bg-amber-500/10 text-amber-200">
          <AlertTriangle className="w-5 h-5 mt-0.5 shrink-0" />
          <div>
            <p className="text-sm font-bold">{counts.overdue} scheduled ride(s) are overdue</p>
            <p className="text-xs text-amber-100/80 mt-1">
              These bookings have passed their pickup time without a driver accepting. Review and
              either reschedule to a future slot or cancel.
            </p>
          </div>
        </div>
      )}

      {/* Status filters */}
      <div className="flex flex-wrap gap-2">
        {(
          [
            { key: 'all', label: 'All', count: scheduledRides.length },
            { key: 'upcoming', label: 'Upcoming', count: counts.upcoming },
            { key: 'overdue', label: 'Overdue', count: counts.overdue },
            { key: 'accepted', label: 'Accepted', count: counts.accepted },
            { key: 'cancelled', label: 'Cancelled', count: counts.cancelled },
          ] as Array<{ key: StatusFilter; label: string; count: number }>
        ).map(({ key, label, count }) => (
          <button
            key={key}
            onClick={() => setFilter(key)}
            className={`px-3 py-1.5 rounded-full text-[11px] font-bold border transition ${
              filter === key
                ? 'bg-slate-100 text-slate-950 border-slate-100'
                : 'bg-slate-900 border-slate-800 text-slate-300 hover:border-slate-600'
            }`}
          >
            <span>{label}</span>
            {count > 0 && <span className="ml-2 font-mono opacity-70">{count}</span>}
          </button>
        ))}
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by reference, passenger, origin, destination..."
          className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400"
        />
      </div>

      {/* List */}
      <div className="glass-panel border border-slate-800 rounded-2xl overflow-hidden">
        <table className="w-full text-xs">
          <thead className="bg-slate-900/80 border-b border-slate-800 text-slate-400 uppercase tracking-wider">
            <tr>
              <th className="text-left px-4 py-3 font-bold">Reference</th>
              <th className="text-left px-4 py-3 font-bold">Passenger</th>
              <th className="text-left px-4 py-3 font-bold">Pickup → Drop</th>
              <th className="text-left px-4 py-3 font-bold">Scheduled</th>
              <th className="text-left px-4 py-3 font-bold">Status</th>
              <th className="text-right px-4 py-3 font-bold">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center py-12 text-slate-500">
                  No scheduled rides match the current filters.
                </td>
              </tr>
            ) : (
              filtered.map((ride) => {
                const overdue = isOverdue(ride);
                return (
                  <tr
                    key={ride.id}
                    className={`border-t border-slate-800/80 hover:bg-slate-900/40 ${
                      overdue ? 'bg-amber-500/5' : ''
                    }`}
                  >
                    <td className="px-4 py-3">
                      <div className="font-mono font-bold text-slate-100">
                        {ride.rideReference || ride.id.slice(0, 8)}
                      </div>
                      <div className="text-[11px] text-slate-500 font-mono">
                        R {ride.fare.toFixed(2)} · {ride.rideType}
                      </div>
                      {ride.rescheduleCount > 0 && (
                        <div className="text-[10px] text-amber-300 uppercase font-bold mt-1">
                          Rescheduled {ride.rescheduleCount}×
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-bold text-slate-100">{ride.passengerName}</div>
                      <div className="text-[11px] text-slate-400">
                        {ride.passengerEmail || ride.passengerPhone || ride.passengerId.slice(0, 8)}
                      </div>
                    </td>
                    <td className="px-4 py-3 max-w-xs">
                      <div className="text-slate-100 truncate">{ride.origin}</div>
                      <div className="text-[11px] text-slate-400 flex items-center space-x-1 mt-0.5">
                        <ArrowRight className="w-3 h-3 text-slate-500" />
                        <span className="truncate">{ride.destination}</span>
                      </div>
                      {ride.driverName && (
                        <div className="text-[11px] text-emerald-300 mt-1 font-bold">
                          Driver: {ride.driverName}{' '}
                          {ride.driverPlate && (
                            <span className="font-mono text-slate-400">({ride.driverPlate})</span>
                          )}
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className={`font-bold ${overdue ? 'text-amber-300' : 'text-slate-100'}`}>
                        {new Date(ride.scheduledFor).toLocaleString('en-ZA', {
                          dateStyle: 'medium',
                          timeStyle: 'short',
                        })}
                      </div>
                      <div className="text-[11px] text-slate-500">
                        {new Date(ride.scheduledFor).toLocaleString('en-ZA', {
                          weekday: 'short',
                          hour: '2-digit',
                          minute: '2-digit',
                          timeZoneName: 'short',
                        })}
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`text-[10px] px-2 py-1 rounded-full border font-mono uppercase ${
                          STATUS_BADGE[ride.status as 'requested' | 'accepted' | 'cancelled'] ?? STATUS_BADGE.requested
                        }`}
                      >
                        {ride.status}
                      </span>
                      {overdue && (
                        <div className="text-[10px] uppercase font-bold text-amber-300 mt-1">
                          Awaiting dispatch
                        </div>
                      )}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex items-center justify-end space-x-2">
                        {ride.status !== 'cancelled' && (
                          <button
                            onClick={() =>
                              setEditing({
                                ride,
                                newDateLocal: toLocalInputValue(ride.scheduledFor),
                                reason: '',
                                error: null,
                              })
                            }
                            className="px-2.5 py-1.5 rounded-lg bg-slate-900 border border-slate-700 hover:border-slate-500 text-slate-200 text-[11px] font-bold flex items-center space-x-1"
                          >
                            <Edit3 className="w-3.5 h-3.5" />
                            <span>Reschedule</span>
                          </button>
                        )}
                        {ride.status !== 'cancelled' && (
                          <button
                            onClick={() => setCancelling({ ride, reason: '' })}
                            className="px-2.5 py-1.5 rounded-lg bg-red-500/10 border border-red-500/40 hover:bg-red-500/20 text-red-200 text-[11px] font-bold flex items-center space-x-1"
                          >
                            <XCircle className="w-3.5 h-3.5" />
                            <span>Cancel</span>
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Reschedule modal */}
      {editing && (
        <RescheduleModal
          draft={editing}
          submitting={submitting === 'reschedule'}
          onClose={() => setEditing(null)}
          onChange={(patch) => setEditing({ ...editing, ...patch })}
          onSubmit={handleSubmitReschedule}
        />
      )}

      {/* Cancel modal */}
      {cancelling && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setCancelling(null)}
        >
          <div
            className="w-full max-w-md glass-panel border border-red-500/40 rounded-2xl p-6 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start space-x-3">
              <XCircle className="w-6 h-6 text-red-300 shrink-0 mt-0.5" />
              <div>
                <h3 className="text-sm font-bold text-white">Cancel scheduled ride</h3>
                <p className="text-[11px] text-slate-400 mt-1">
                  {cancelling.ride.rideReference || cancelling.ride.id.slice(0, 8)} ·{' '}
                  {cancelling.ride.passengerName}
                </p>
              </div>
            </div>
            <div>
              <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
                Reason (visible in audit log)
              </label>
              <textarea
                value={cancelling.reason}
                onChange={(e) => setCancelling({ ...cancelling, reason: e.target.value })}
                rows={3}
                placeholder="Why is this booked ride being cancelled?"
                className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-red-400 resize-none"
              />
            </div>
            <div className="p-3 rounded-xl border border-amber-500/30 bg-amber-500/5 text-amber-100 text-xs">
              <div className="flex items-start space-x-2">
                <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
                <p>
                  If the ride has been paid online, head over to the
                  <span className="font-mono mx-1">Refunds</span>
                  tab afterwards to refund the passenger's Paystack charge.
                </p>
              </div>
            </div>
            <div className="flex items-center justify-end space-x-2 pt-2">
              <button
                onClick={() => setCancelling(null)}
                className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
              >
                Keep ride
              </button>
              <button
                onClick={handleConfirmCancel}
                disabled={submitting === 'cancel'}
                className="px-3 py-2 rounded-xl bg-red-500 hover:bg-red-400 text-white font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
              >
                {submitting === 'cancel' ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <XCircle className="w-4 h-4" />
                )}
                <span>Cancel Ride</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

interface RescheduleModalProps {
  draft: EditingDraft;
  submitting: boolean;
  onClose: () => void;
  onChange: (patch: Partial<EditingDraft>) => void;
  onSubmit: () => Promise<void>;
}

const RescheduleModal: React.FC<RescheduleModalProps> = ({
  draft,
  submitting,
  onClose,
  onChange,
  onSubmit,
}) => {
  const { ride, newDateLocal, reason, error } = draft;
  const minLocal = useMemo(() => {
    const d = new Date();
    d.setMinutes(d.getMinutes() + 11);
    return toLocalInputValue(d.toISOString());
  }, []);

  const pickupLat = Number(ride.pickupLat) || 0;
  const pickupLng = Number(ride.pickupLng) || 0;
  const destLat = Number(ride.destLat) || 0;
  const destLng = Number(ride.destLng) || 0;
  const hasMap =
    Math.abs(pickupLat) > 0.0001 ||
    Math.abs(pickupLng) > 0.0001 ||
    Math.abs(destLat) > 0.0001 ||
    Math.abs(destLng) > 0.0001;

  return (
    <div
      className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-2xl glass-panel border border-slate-800 rounded-2xl p-6 space-y-4 max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-start justify-between">
          <div className="space-y-2">
            <span className="text-[10px] font-mono uppercase text-indigo-300 tracking-wider px-2 py-1 rounded-full border border-indigo-500/40 bg-indigo-500/10">
              Reschedule
            </span>
            <h3 className="text-sm font-bold text-white">
              {ride.rideReference || ride.id.slice(0, 8)}
            </h3>
            <p className="text-[11px] text-slate-400">
              {ride.passengerName} · {ride.rideType}
            </p>
          </div>
          <button onClick={onClose} className="p-1 text-slate-500 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* History */}
        {ride.rescheduleCount > 0 && (
          <div className="p-3 rounded-xl border border-amber-500/30 bg-amber-500/5 text-xs text-amber-100">
            <div className="flex items-start space-x-2">
              <Clock className="w-4 h-4 mt-0.5 shrink-0" />
              <div>
                <p className="font-bold">Rescheduled {ride.rescheduleCount}× before</p>
                {ride.lastRescheduledAt && (
                  <p className="text-[11px] text-amber-100/80 mt-1">
                    Last: {new Date(ride.lastRescheduledAt).toLocaleString('en-ZA', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    })}{' '}
                    by {ride.lastRescheduledByName || 'another admin'}
                  </p>
                )}
                {ride.lastRescheduleReason && (
                  <p className="text-[11px] text-amber-100/80 mt-1 whitespace-pre-wrap">
                    Note: {ride.lastRescheduleReason}
                  </p>
                )}
              </div>
            </div>
          </div>
        )}

        {/* Contact */}
        <div className="grid grid-cols-2 gap-3 text-xs">
          <DetailCard icon={Mail} label="Email" primary={ride.passengerEmail} />
          <DetailCard icon={Phone} label="Phone" primary={ride.passengerPhone} />
        </div>

        <div className="text-xs text-slate-300 grid grid-cols-1 md:grid-cols-2 gap-2">
          <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800">
            <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold mb-1">
              Pickup
            </div>
            <div className="text-slate-100">{ride.origin}</div>
          </div>
          <div className="p-3 rounded-xl bg-slate-900/60 border border-slate-800">
            <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold mb-1">
              Destination
            </div>
            <div className="text-slate-100">{ride.destination}</div>
          </div>
        </div>

        {hasMap && (
          <div className="rounded-xl overflow-hidden border border-slate-800 h-56">
            <MapContainer
              center={[pickupLat || destLat || FALLBACK_CENTER[0], pickupLng || destLng || FALLBACK_CENTER[1]]}
              zoom={13}
              scrollWheelZoom={false}
              className="w-full h-full"
            >
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <Marker position={[pickupLat, pickupLng]} icon={pickupIcon}>
                <Popup>
                  <div className="text-xs font-bold text-slate-900">Pickup: {ride.origin}</div>
                </Popup>
              </Marker>
              <Marker position={[destLat, destLng]} icon={destIcon}>
                <Popup>
                  <div className="text-xs font-bold text-slate-900">Drop: {ride.destination}</div>
                </Popup>
              </Marker>
              {pickupLat !== destLat && (
                <Polyline
                  positions={[
                    [pickupLat, pickupLng],
                    [destLat, destLng],
                  ]}
                  pathOptions={{ color: '#22d3ee', weight: 4, dashArray: '8, 8' }}
                />
              )}
            </MapContainer>
          </div>
        )}

        {/* New datetime */}
        <div>
          <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
            New pickup window (local time)
          </label>
          <input
            type="datetime-local"
            value={newDateLocal}
            min={minLocal}
            onChange={(e) => onChange({ newDateLocal: e.target.value, error: null })}
            className="w-full px-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm font-mono placeholder-slate-500 focus:outline-none focus:border-slate-400"
          />
          <p className="text-[11px] text-slate-500 mt-1">
            Must be at least 10 minutes from now.
          </p>
        </div>

        <div>
          <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
            Reason for rescheduling (visible in audit + audit log)
          </label>
          <textarea
            value={reason}
            onChange={(e) => onChange({ reason: e.target.value, error: null })}
            rows={2}
            placeholder="Driver unavailable, weather delay, passenger request..."
            className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400 resize-none"
          />
        </div>

        {error && (
          <div className="flex items-start space-x-2 p-3 rounded-xl border border-red-500/40 bg-red-500/10 text-red-200 text-xs">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{error}</span>
          </div>
        )}

        <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
          <button
            onClick={onClose}
            className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
          >
            Close
          </button>
          <button
            onClick={onSubmit}
            disabled={submitting || newDateLocal.length === 0}
            className="px-3 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
          >
            {submitting ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <CheckCircle2 className="w-4 h-4" />
            )}
            <span>Apply reschedule</span>
          </button>
        </div>
      </div>
    </div>
  );
};

interface DetailCardProps {
  icon: React.FC<{ className?: string }>;
  label: string;
  primary: string;
}

const DetailCard: React.FC<DetailCardProps> = ({ icon: Icon, label, primary }) => (
  <div className="p-3 rounded-xl bg-slate-900/40 border border-slate-800 text-xs">
    <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-1.5 mb-1">
      <Icon className="w-3 h-3" />
      <span>{label}</span>
    </div>
    <div className="text-slate-100">{primary || '—'}</div>
  </div>
);
