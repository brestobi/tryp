import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import { MapContainer, TileLayer, Marker, Popup, Polyline } from 'react-leaflet';
import L from 'leaflet';
import {
  MapPin,
  Radio,
  UserCheck,
  XCircle,
  Filter,
  Loader2,
} from 'lucide-react';

// Custom Leaflet Icons using SVG Data URIs
const createCustomIcon = (color: string) => {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="${color}" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.5 2.8C1.4 11.3 1 12.1 1 13v3c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>`;
  return L.icon({
    iconUrl: `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`,
    iconSize: [32, 32],
    iconAnchor: [16, 16],
    popupAnchor: [0, -16]
  });
};

const driverIconOnline = createCustomIcon('#d4d4d4');
const driverIconBusy = createCustomIcon('#777777');
const pickupIcon = L.icon({
  iconUrl: `data:image/svg+xml;utf8,${encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 24 24" fill="#777777" stroke="#ffffff" stroke-width="2"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4" fill="#ffffff"/></svg>')}`,
  iconSize: [28, 28],
  iconAnchor: [14, 14]
});

export const FleetCommandCenter: React.FC = () => {
  const { rides, drivers, assignDriverToRide, cancelRide } = useAdmin();

  const [statusFilter, setStatusFilter] = useState<string>('All');
  const [selectedRideId, setSelectedRideId] = useState<string | null>(rides[0]?.id || null);

  // Dispatcher modals
  const [assignRideModalId, setAssignRideModalId] = useState<string | null>(null);
  const [selectedAssignDriverId, setSelectedAssignDriverId] = useState<string>('');

  const [cancelRideModalId, setCancelRideModalId] = useState<string | null>(null);
  const [cancelReason, setCancelReason] = useState<string>('Dispatcher manual cancellation override');

  // In-flight modal submission state
  const [busyModal, setBusyModal] = useState<null | 'assign' | 'cancel'>(null);
  const [modalError, setModalError] = useState<{
    modal: 'assign' | 'cancel';
    message: string;
  } | null>(null);

  const filteredRides = rides.filter(r => {
    if (statusFilter !== 'All' && r.status !== statusFilter) return false;
    return true;
  });

  const selectedRide = rides.find(r => r.id === selectedRideId);
  const availableDrivers = drivers.filter(d => d.isOnline && d.driverStatus === 'approved');

  const defaultCenter: [number, number] = [-26.1200, 28.0500]; // Johannesburg / Sandton

  const handleAssignSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!assignRideModalId || !selectedAssignDriverId || busyModal) return;
    setBusyModal('assign');
    setModalError(null);
    try {
      await assignDriverToRide(assignRideModalId, selectedAssignDriverId);
      setAssignRideModalId(null);
      setSelectedAssignDriverId('');
    } catch (err) {
      setModalError({
        modal: 'assign',
        message: err instanceof Error ? err.message : 'Failed to assign driver',
      });
    } finally {
      setBusyModal(null);
    }
  };

  const handleCancelSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!cancelRideModalId || busyModal) return;
    setBusyModal('cancel');
    setModalError(null);
    try {
      await cancelRide(cancelRideModalId, cancelReason);
      setCancelRideModalId(null);
    } catch (err) {
      setModalError({
        modal: 'cancel',
        message: err instanceof Error ? err.message : 'Failed to cancel ride',
      });
    } finally {
      setBusyModal(null);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-emerald-400 mb-1 font-mono">
            <Radio className="w-4 h-4 text-emerald-400 animate-pulse" />
            <span>Module 2 Dispatch Operations</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Realtime Fleet Command Center</h1>
          <p className="text-slate-400 text-xs mt-1">
            Live telemetry tracking of active driver locations, ongoing trips, and dispatch override controls.
          </p>
        </div>

        {/* Filter controls */}
        <div className="flex items-center space-x-3">
          <div className="flex items-center space-x-2 bg-slate-900/80 p-1.5 rounded-xl border border-slate-800 text-xs">
            <Filter className="w-3.5 h-3.5 text-slate-400 ml-1" />
            <select
              value={statusFilter}
              onChange={e => setStatusFilter(e.target.value)}
              className="bg-transparent text-slate-200 focus:outline-none font-medium pr-2"
            >
              <option value="All">All Trip Statuses</option>
              <option value="requested">Requested</option>
              <option value="accepted">Accepted</option>
              <option value="in_trip">In Trip</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
            </select>
          </div>
        </div>
      </div>

      {/* Map + Trip Drawer Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Leaflet Interactive Fleet Map (8 cols) */}
        <div className="lg:col-span-8 space-y-4">
          <div className="glass-panel rounded-2xl p-4 border border-slate-800 space-y-3 relative overflow-hidden">
            <div className="flex items-center justify-between text-xs px-2">
              <div className="flex items-center space-x-2">
                <MapPin className="w-4 h-4 text-emerald-400" />
                <span className="font-bold text-slate-200 uppercase tracking-wider">
                  Live Fleet Radar Stream
                </span>
              </div>

              {/* Map Legend */}
              <div className="flex items-center space-x-4 text-[11px] text-slate-400">
                <span className="flex items-center space-x-1">
                  <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 inline-block"></span>
                  <span>Driver Available</span>
                </span>
                <span className="flex items-center space-x-1">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-500 inline-block"></span>
                  <span>Driver In-Trip</span>
                </span>
                <span className="flex items-center space-x-1">
                  <span className="w-2.5 h-2.5 rounded-full bg-purple-500 inline-block"></span>
                  <span>Pickup Location</span>
                </span>
              </div>
            </div>

            {/* Map Canvas */}
            <div className="h-[480px] rounded-xl overflow-hidden border border-slate-800 z-10">
              <MapContainer
                center={defaultCenter}
                zoom={12}
                scrollWheelZoom={true}
                className="w-full h-full"
              >
                <TileLayer
                  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                />

                {/* Render Online Drivers */}
                {drivers
                  .filter(d => d.isOnline)
                  .map(drv => {
                    const isBusy = rides.some(r => r.driverId === drv.id && (r.status === 'in_trip' || r.status === 'accepted'));
                    return (
                      <Marker
                        key={drv.id}
                        position={[drv.currentLat, drv.currentLng]}
                        icon={isBusy ? driverIconBusy : driverIconOnline}
                      >
                        <Popup>
                          <div className="text-xs space-y-1 p-1">
                            <div className="font-bold text-slate-900 flex items-center space-x-1">
                              <span>{drv.fullName}</span>
                              <span className="text-[10px] text-slate-600 font-mono">({drv.vehiclePlate})</span>
                            </div>
                            <div className="text-[11px] text-slate-600">{drv.vehicleMake} {drv.vehicleModel}</div>
                            <div className="text-[10px] font-mono text-purple-700 font-bold">
                              Status: {isBusy ? 'In Active Trip' : 'Online & Available'}
                            </div>
                          </div>
                        </Popup>
                      </Marker>
                    );
                  })}

                {/* Render Selected Ride Pickup / Destination Pins & Vector Line */}
                {selectedRide && (
                  <>
                    <Marker position={[selectedRide.pickupLat, selectedRide.pickupLng]} icon={pickupIcon}>
                      <Popup>
                        <div className="text-xs font-bold text-slate-900">
                          Pickup: {selectedRide.pickupAddress}
                        </div>
                      </Popup>
                    </Marker>

                    <Marker position={[selectedRide.destLat, selectedRide.destLng]} icon={pickupIcon}>
                      <Popup>
                        <div className="text-xs font-bold text-slate-900">
                          Destination: {selectedRide.destAddress}
                        </div>
                      </Popup>
                    </Marker>

                    <Polyline
                      positions={[
                        [selectedRide.pickupLat, selectedRide.pickupLng],
                        [selectedRide.destLat, selectedRide.destLng]
                      ]}
                      pathOptions={{ color: '#d4d4d4', weight: 4, dashArray: '8, 8' }}
                    />
                  </>
                )}
              </MapContainer>
            </div>
          </div>
        </div>

        {/* Selected Trip Detail Panel (4 cols) */}
        <div className="lg:col-span-4 space-y-4">
          <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4 min-h-[520px] flex flex-col justify-between">
            <div>
              <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-3">
                <div>
                  <span className="text-[11px] font-mono font-bold text-purple-400 uppercase tracking-wider">
                    Inspect Trip Telemetry
                  </span>
                  <h3 className="font-heading font-bold text-lg text-white">
                    {selectedRide ? `Trip ${selectedRide.rideReference || selectedRide.id}` : 'Select a Trip'}
                  </h3>
                </div>
                {selectedRide && (
                  <span
                    className={`text-xs px-2.5 py-1 rounded-full font-mono uppercase font-bold border ${
                      selectedRide.status === 'in_trip'
                        ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                        : selectedRide.status === 'accepted'
                        ? 'bg-indigo-500/20 text-indigo-400 border-indigo-500/30'
                        : selectedRide.status === 'requested'
                        ? 'bg-amber-500/20 text-amber-400 border-amber-500/30'
                        : 'bg-slate-800 text-slate-400 border-slate-700'
                    }`}
                  >
                    {selectedRide.status}
                  </span>
                )}
              </div>

              {selectedRide ? (
                <div className="space-y-4 text-xs">
                  {/* Passenger & Driver details */}
                  <div className="p-3 rounded-xl bg-slate-900/80 border border-slate-800 space-y-2">
                    <div className="flex items-center justify-between">
                      <span className="text-slate-400 font-medium">Passenger</span>
                      <span className="text-slate-100 font-semibold">{selectedRide.passengerName}</span>
                    </div>
                    <div className="flex items-center justify-between">
                      <span className="text-slate-400 font-medium">Driver</span>
                      <span className="text-emerald-400 font-semibold font-mono">
                        {selectedRide.driverName || 'Unassigned (Searching...)'}
                      </span>
                    </div>
                    {selectedRide.driverPlate && (
                      <div className="flex items-center justify-between">
                        <span className="text-slate-400 font-medium">Vehicle Plate</span>
                        <span className="text-purple-400 font-mono">{selectedRide.driverPlate}</span>
                      </div>
                    )}
                  </div>

                  {/* Route Info */}
                  <div className="space-y-2 p-3 rounded-xl bg-slate-900/80 border border-slate-800">
                    <div className="flex items-start space-x-2">
                      <div className="w-2 h-2 rounded-full bg-purple-500 mt-1.5"></div>
                      <div>
                        <div className="text-[10px] text-slate-500 uppercase font-bold">Pickup</div>
                        <div className="text-slate-200">{selectedRide.pickupAddress}</div>
                      </div>
                    </div>
                    <div className="border-l border-dashed border-slate-700 ml-1 pl-3 my-1"></div>
                    <div className="flex items-start space-x-2">
                      <div className="w-2 h-2 rounded-full bg-pink-500 mt-1.5"></div>
                      <div>
                        <div className="text-[10px] text-slate-500 uppercase font-bold">Destination</div>
                        <div className="text-slate-200">{selectedRide.destAddress}</div>
                      </div>
                    </div>
                  </div>

                  {/* Pricing Breakdown */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800">
                      <span className="text-slate-500 text-[10px] uppercase font-bold">Calculated Fare</span>
                      <div className="text-base font-extrabold text-white font-mono mt-0.5">
                        R{selectedRide.fare.toFixed(2)}
                      </div>
                    </div>
                    <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800">
                      <span className="text-slate-500 text-[10px] uppercase font-bold">Surge Multiplier</span>
                      <div className="text-base font-extrabold text-amber-400 font-mono mt-0.5">
                        {selectedRide.surgeMultiplier}x
                      </div>
                    </div>
                  </div>
                </div>
              ) : (
                <div className="text-slate-500 text-xs text-center py-12">Click a trip from the live table below</div>
              )}
            </div>

            {/* Override Action Buttons */}
            {selectedRide && (
              <div className="space-y-2 pt-3 border-t border-slate-800">
                {!selectedRide.driverId && selectedRide.status === 'requested' && (
                  <button
                    onClick={() => {
                      setAssignRideModalId(selectedRide.id);
                      setSelectedAssignDriverId(availableDrivers[0]?.id || '');
                    }}
                    className="w-full py-2.5 rounded-xl bg-slate-100 text-slate-950 text-xs font-bold shadow-lg shadow-white/10 hover:bg-white transition-all flex items-center justify-center space-x-2"
                  >
                    <UserCheck className="w-4 h-4" />
                    <span>Manually Assign Driver</span>
                  </button>
                )}

                {selectedRide.status !== 'completed' && selectedRide.status !== 'cancelled' && (
                  <button
                    onClick={() => setCancelRideModalId(selectedRide.id)}
                    className="w-full py-2 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 hover:bg-red-500/20 text-xs font-semibold transition-all flex items-center justify-center space-x-1.5"
                  >
                    <XCircle className="w-4 h-4" />
                    <span>Emergency Cancel Ride</span>
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Active Trips Live Table */}
      <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
        <div className="flex items-center justify-between">
          <h3 className="font-heading font-bold text-lg text-white">Live Rides Directory</h3>
          <span className="text-xs text-slate-400 font-mono">Showing {filteredRides.length} active entries</span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-800 text-slate-400 font-mono uppercase text-[10px]">
                <th className="py-3 px-4">Trip ID</th>
                <th className="py-3 px-4">Passenger</th>
                <th className="py-3 px-4">Driver</th>
                <th className="py-3 px-4">Tier</th>
                <th className="py-3 px-4">Fare (ZAR)</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4">Requested At</th>
                <th className="py-3 px-4 text-right">Dispatcher Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {filteredRides.map(ride => {
                const isSelected = selectedRideId === ride.id;
                return (
                  <tr
                    key={ride.id}
                    onClick={() => setSelectedRideId(ride.id)}
                    className={`cursor-pointer transition-colors ${
                      isSelected ? 'bg-purple-950/40 text-white' : 'hover:bg-slate-900/60 text-slate-300'
                    }`}
                  >
                    <td className="py-3 px-4 font-mono font-bold text-purple-400">
                      {ride.rideReference || `#${ride.id.replace('ride-', '')}`}
                    </td>
                    <td className="py-3 px-4 font-semibold text-slate-100">{ride.passengerName}</td>
                    <td className="py-3 px-4">
                      {ride.driverName ? (
                        <div>
                          <div className="font-medium text-slate-200">{ride.driverName}</div>
                          <div className="text-[10px] text-purple-400 font-mono">{ride.driverPlate}</div>
                        </div>
                      ) : (
                        <span className="text-amber-400 italic">Searching...</span>
                      )}
                    </td>
                    <td className="py-3 px-4">
                      <span className="px-2 py-0.5 rounded bg-slate-900 border border-slate-800 font-mono text-[11px]">
                        {ride.tier}
                      </span>
                    </td>
                    <td className="py-3 px-4 font-mono font-bold text-emerald-400">
                      R{ride.fare.toFixed(2)}
                    </td>
                    <td className="py-3 px-4">
                      <span
                        className={`px-2.5 py-1 rounded-full text-[10px] font-mono font-bold uppercase border ${
                          ride.status === 'in_trip'
                            ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                            : ride.status === 'accepted'
                            ? 'bg-indigo-500/20 text-indigo-400 border-indigo-500/30'
                            : ride.status === 'requested'
                            ? 'bg-amber-500/20 text-amber-400 border-amber-500/30'
                            : 'bg-slate-800 text-slate-400 border-slate-700'
                        }`}
                      >
                        {ride.status}
                      </span>
                    </td>
                    <td className="py-3 px-4 font-mono text-slate-400">
                      {new Date(ride.requestedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                    </td>
                    <td className="py-3 px-4 text-right">
                      <button
                        onClick={e => {
                          e.stopPropagation();
                          setSelectedRideId(ride.id);
                        }}
                        className="px-3 py-1 rounded-lg bg-purple-600/20 border border-purple-500/30 text-purple-300 hover:bg-purple-600/40 text-xs font-semibold"
                      >
                        Inspect
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Manual Driver Assignment Modal */}
      {assignRideModalId && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-md rounded-2xl p-6 border border-slate-800 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-white flex items-center space-x-2">
                <UserCheck className="w-5 h-5 text-purple-400" />
                <span>Manual Driver Dispatch Assignment</span>
              </h3>
              <button onClick={() => setAssignRideModalId(null)} className="text-slate-400 hover:text-white">
                ✕
              </button>
            </div>

            <form onSubmit={handleAssignSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Select Available Online Driver</label>
                <select
                  value={selectedAssignDriverId}
                  onChange={e => setSelectedAssignDriverId(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-purple-500"
                >
                  {availableDrivers.map(d => (
                    <option key={d.id} value={d.id}>
                      {d.fullName} ({d.operatingCity}) — {d.vehicleMake} {d.vehicleModel} [{d.vehiclePlate}]
                    </option>
                  ))}
                </select>
              </div>

              {modalError?.modal === 'assign' && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                  {modalError.message}
                </div>
              )}

              <div className="flex justify-end space-x-3 pt-2">
                <button
                  type="button"
                  onClick={() => setAssignRideModalId(null)}
                  disabled={busyModal === 'assign'}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={busyModal === 'assign'}
                  className="px-4 py-2 rounded-xl bg-purple-600 text-white font-bold hover:bg-purple-500 shadow-lg shadow-purple-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                >
                  {busyModal === 'assign' && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{busyModal === 'assign' ? 'Assigning...' : 'Assign & Dispatch Trip'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Emergency Cancellation Modal */}
      {cancelRideModalId && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-md rounded-2xl p-6 border border-slate-800 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-white flex items-center space-x-2">
                <XCircle className="w-5 h-5 text-red-400" />
                <span>Emergency Ride Cancellation</span>
              </h3>
              <button onClick={() => setCancelRideModalId(null)} className="text-slate-400 hover:text-white">
                ✕
              </button>
            </div>

            <form onSubmit={handleCancelSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Reason for Cancellation</label>
                <textarea
                  rows={3}
                  value={cancelReason}
                  onChange={e => setCancelReason(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500"
                />
              </div>

              {modalError?.modal === 'cancel' && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                  {modalError.message}
                </div>
              )}

              <div className="flex justify-end space-x-3 pt-2">
                <button
                  type="button"
                  onClick={() => setCancelRideModalId(null)}
                  disabled={busyModal === 'cancel'}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={busyModal === 'cancel'}
                  className="px-4 py-2 rounded-xl bg-red-600 text-white font-bold hover:bg-red-500 shadow-lg shadow-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                >
                  {busyModal === 'cancel' && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{busyModal === 'cancel' ? 'Cancelling...' : 'Confirm Ride Cancellation'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
