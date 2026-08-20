import React, { useEffect, useMemo, useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import type { SafetyIncident, IncidentType } from '../types/admin';
import {
  MapContainer,
  TileLayer,
  Marker,
  Popup,
  useMap,
} from 'react-leaflet';
import L from 'leaflet';
import {
  ShieldAlert,
  AlertTriangle,
  Search,
  CheckCircle2,
  Eye,
  Siren,
  MapPin,
  MessageSquare,
  Phone,
  Mail,
  UserRound,
  StickyNote,
  RefreshCw,
  Loader2,
  Clock,
  X,
  LayoutList,
  Map as MapIcon,
} from 'lucide-react';

type StatusFilter = 'all' | 'open' | 'acknowledged' | 'resolved';

const INCIDENT_TYPE_LABEL: Record<IncidentType, string> = {
  emergency: 'Emergency',
  unsafe_driving: 'Unsafe driving',
  medical: 'Medical assistance',
  harassment: 'Harassment',
  other: 'Other',
};

const INCIDENT_TYPE_BADGE: Record<IncidentType, string> = {
  emergency: 'bg-red-500/20 text-red-300 border-red-500/40',
  unsafe_driving: 'bg-orange-500/20 text-orange-300 border-orange-500/40',
  medical: 'bg-rose-500/20 text-rose-300 border-rose-500/40',
  harassment: 'bg-fuchsia-500/20 text-fuchsia-300 border-fuchsia-500/40',
  other: 'bg-slate-500/20 text-slate-300 border-slate-500/40',
};

const STATUS_BADGE = {
  open: 'bg-red-500/20 text-red-300 border-red-500/40',
  acknowledged: 'bg-amber-500/20 text-amber-300 border-amber-500/40',
  resolved: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
} as const;

const STATUS_ICON = {
  open: Siren,
  acknowledged: Eye,
  resolved: CheckCircle2,
} as const;

const STATUS_COLOR = {
  open: '#fca5a5',
  acknowledged: '#fbbf24',
  resolved: '#34d399',
} as const;

// SOS marker icons. A small radiating alarm ring communicates urgency
// at a glance even on dark map tiles.
const createIncidentMarker = (status: 'open' | 'acknowledged' | 'resolved') => {
  const fill = STATUS_COLOR[status];
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="36" height="44" viewBox="0 0 36 44">
    <defs>
      <radialGradient id="g" cx="50%" cy="50%" r="50%">
        <stop offset="0%" stop-color="${fill}" stop-opacity="0.55"/>
        <stop offset="80%" stop-color="${fill}" stop-opacity="0"/>
      </radialGradient>
    </defs>
    <circle cx="18" cy="18" r="18" fill="url(#g)"/>
    <path d="M18 4 C 9 4 4 10 4 18 c 0 12 14 22 14 22 s 14 -10 14 -22 c 0 -8 -5 -14 -14 -14 z"
      fill="${fill}" stroke="#0f172a" stroke-width="2"/>
    <circle cx="18" cy="17" r="5" fill="#0f172a"/>
    <path d="M18 12 v -3 M25 17 h 3 M18 22 v 3 M11 17 h -3"
      stroke="#0f172a" stroke-width="2" stroke-linecap="round" fill="none"/>
  </svg>`;
  return L.icon({
    iconUrl: `data:image/svg+xml;utf8,${encodeURIComponent(svg)}`,
    iconSize: [36, 44],
    iconAnchor: [18, 36],
    popupAnchor: [0, -32],
  });
};

const incidentIconCache: Record<'open' | 'acknowledged' | 'resolved', L.Icon> = {
  open: createIncidentMarker('open'),
  acknowledged: createIncidentMarker('acknowledged'),
  resolved: createIncidentMarker('resolved'),
};

const incidentIconFor = (status: SafetyIncident['status']): L.Icon => {
  if (status === 'acknowledged') return incidentIconCache.acknowledged;
  if (status === 'resolved') return incidentIconCache.resolved;
  return incidentIconCache.open;
};

const FALLBACK_CENTER: [number, number] = [-26.2041, 28.0473]; // Johannesburg

const computeCenter = (incidents: SafetyIncident[]): [number, number] => {
  const located = incidents.filter(
    (i) => i.latitude !== null && i.longitude !== null,
  ) as Array<SafetyIncident & { latitude: number; longitude: number }>;
  if (located.length === 0) return FALLBACK_CENTER;
  const lat = located.reduce((sum, i) => sum + i.latitude, 0) / located.length;
  const lng = located.reduce((sum, i) => sum + i.longitude, 0) / located.length;
  return [lat, lng];
};

/** Programmatic relocation: changes the map's view whenever the focus changes. */
const FlyToFocus: React.FC<{ position: [number, number] | null }> = ({ position }) => {
  const map = useMap();
  useEffect(() => {
    if (!position) return;
    map.flyTo(position, 15, { duration: 0.8 });
  }, [map, position]);
  return null;
};

export const IncidentReview: React.FC = () => {
  const {
    incidents,
    can,
    acknowledgeSafetyIncident,
    resolveSafetyIncident,
    addIncidentNote,
    refresh,
    currentRole,
  } = useAdmin();

  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [search, setSearch] = useState('');
  const [selected, setSelected] = useState<SafetyIncident | null>(null);
  const [noteDraft, setNoteDraft] = useState('');
  const [pendingAction, setPendingAction] = useState<string | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [view, setView] = useState<'list' | 'map'>('list');
  const [mapFocus, setMapFocus] = useState<[number, number] | null>(null);

  const canResolve = can('fleet:write');
  const canView = can('fleet:read');

  const counts = useMemo(() => {
    const c = { open: 0, acknowledged: 0, resolved: 0 };
    for (const i of incidents) {
      if (i.status === 'open') c.open += 1;
      else if (i.status === 'acknowledged') c.acknowledged += 1;
      else c.resolved += 1;
    }
    return c;
  }, [incidents]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    return incidents.filter((i) => {
      if (statusFilter !== 'all' && i.status !== statusFilter) return false;
      if (!term) return true;
      return (
        i.reporterName.toLowerCase().includes(term) ||
        (i.reporterEmail ?? '').toLowerCase().includes(term) ||
        (i.reporterPhone ?? '').toLowerCase().includes(term) ||
        (i.rideReference ?? '').toLowerCase().includes(term) ||
        (i.message ?? '').toLowerCase().includes(term) ||
        INCIDENT_TYPE_LABEL[i.incidentType].toLowerCase().includes(term)
      );
    });
  }, [incidents, statusFilter, search]);

  if (!canView) {
    return (
      <div className="glass-panel border border-slate-800 rounded-2xl p-8 max-w-2xl mx-auto text-center">
        <div className="w-12 h-12 mx-auto rounded-full bg-amber-500/10 border border-amber-500/40 flex items-center justify-center text-amber-300">
          <ShieldAlert className="w-6 h-6" />
        </div>
        <h2 className="text-xl font-bold font-heading text-white mt-4">
          Incident review restricted
        </h2>
        <p className="text-xs text-slate-400 mt-2">
          Only fleet dispatchers and super admins can review safety incidents.
          Your role ({currentRole}) does not include the fleet:read permission.
        </p>
      </div>
    );
  }

  const handleAcknowledge = async () => {
    if (!selected) return;
    setPendingAction('acknowledge');
    setErrorMessage(null);
    try {
      await acknowledgeSafetyIncident(selected.id);
      setSelected(null);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Could not acknowledge incident.');
    } finally {
      setPendingAction(null);
    }
  };

  const handleResolve = async () => {
    if (!selected) return;
    setPendingAction('resolve');
    setErrorMessage(null);
    try {
      await resolveSafetyIncident(selected.id);
      setSelected(null);
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Could not resolve incident.');
    } finally {
      setPendingAction(null);
    }
  };

  const handleAppendNote = async () => {
    if (!selected) return;
    const note = noteDraft.trim();
    if (note.length < 4) {
      setErrorMessage('Notes must be at least 4 characters.');
      return;
    }
    setPendingAction('note');
    setErrorMessage(null);
    try {
      await addIncidentNote(selected.id, note);
      setNoteDraft('');
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Could not save note.');
    } finally {
      setPendingAction(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex items-start justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold font-heading text-white flex items-center space-x-2">
            <ShieldAlert className="w-6 h-6 text-red-400" />
            <span>Incident Review</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            SOS reports and safety escalations. Internal operator notes stay behind the
            admin-only RPC and are surfaced here.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <div className="inline-flex rounded-xl bg-slate-900 border border-slate-800 p-1">
            <button
              onClick={() => {
                setView('list');
                setMapFocus(null);
              }}
              className={`px-3 py-1.5 rounded-lg text-[11px] font-bold flex items-center space-x-1.5 ${
                view === 'list'
                  ? 'bg-slate-100 text-slate-950'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              <LayoutList className="w-3.5 h-3.5" />
              <span>List</span>
            </button>
            <button
              onClick={() => setView('map')}
              className={`px-3 py-1.5 rounded-lg text-[11px] font-bold flex items-center space-x-1.5 ${
                view === 'map'
                  ? 'bg-slate-100 text-slate-950'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              <MapIcon className="w-3.5 h-3.5" />
              <span>Map</span>
            </button>
          </div>
          <button
            onClick={() => refresh()}
            className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold flex items-center space-x-1.5"
          >
            <RefreshCw className="w-4 h-4" />
            <span>Refresh</span>
          </button>
        </div>
      </div>

      {counts.open > 0 && (
        <div className="flex items-start space-x-3 p-4 rounded-xl border border-red-500/40 bg-red-500/10 text-red-200">
          <Siren className="w-5 h-5 mt-0.5 shrink-0" />
          <div>
            <p className="text-sm font-bold">{counts.open} open incidents need attention</p>
            <p className="text-xs text-red-100/80 mt-1">
              Acknowledge to take ownership. Resolve once the response is complete.
            </p>
          </div>
        </div>
      )}

      {/* Status filters */}
      <div className="flex flex-wrap gap-2">
        {(['all', 'open', 'acknowledged', 'resolved'] as StatusFilter[]).map((key) => {
          const label = key === 'all' ? 'All' :
            key === 'open' ? 'Open' :
            key === 'acknowledged' ? 'Acknowledged' : 'Resolved';
          const count = key === 'all' ? incidents.length : counts[key];
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
          placeholder="Search by reporter, ride reference, message..."
          className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400"
        />
      </div>

      {/* Incident table OR map */}
      {view === 'map' ? (
        <IncidentMapView
          incidents={filtered}
          mapFocus={mapFocus}
          onSelect={(incident) => setSelected(incident)}
        />
      ) : (
      <div className="glass-panel border border-slate-800 rounded-2xl overflow-hidden">
        <table className="w-full text-xs">
          <thead className="bg-slate-900/80 border-b border-slate-800 text-slate-400 uppercase tracking-wider">
            <tr>
              <th className="text-left px-4 py-3 font-bold">Type</th>
              <th className="text-left px-4 py-3 font-bold">Reporter</th>
              <th className="text-left px-4 py-3 font-bold">Ride</th>
              <th className="text-left px-4 py-3 font-bold">Status</th>
              <th className="text-left px-4 py-3 font-bold">Reported</th>
              <th className="text-right px-4 py-3 font-bold">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center py-12 text-slate-500">
                  No incidents match the current filters.
                </td>
              </tr>
            ) : (
              filtered.map((inc) => {
                const StatusIcon = STATUS_ICON[inc.status];
                return (
                  <tr
                    key={inc.id}
                    className="border-t border-slate-800/80 hover:bg-slate-900/40 cursor-pointer"
                    onClick={() => setSelected(inc)}
                  >
                    <td className="px-4 py-3">
                      <span
                        className={`text-[10px] px-2 py-1 rounded-full border font-mono uppercase ${INCIDENT_TYPE_BADGE[inc.incidentType]}`}
                      >
                        {INCIDENT_TYPE_LABEL[inc.incidentType]}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <div className="font-bold text-slate-100">{inc.reporterName || 'Unknown'}</div>
                      <div className="text-[11px] text-slate-400">
                        {inc.reporterEmail || inc.reporterPhone || inc.reporterId.slice(0, 8)}
                      </div>
                    </td>
                    <td className="px-4 py-3 text-slate-300">
                      {inc.rideReference ? (
                        <div>
                          <div className="font-mono text-slate-100">{inc.rideReference}</div>
                          <div className="text-[11px] text-slate-500">{inc.rideStatus}</div>
                        </div>
                      ) : (
                        <span className="text-slate-500 italic">Standalone report</span>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`inline-flex items-center space-x-1.5 text-[10px] px-2.5 py-1 rounded-full border font-mono uppercase ${STATUS_BADGE[inc.status]}`}
                      >
                        <StatusIcon className="w-3 h-3" />
                        <span>{inc.status}</span>
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-300">
                      {new Date(inc.createdAt).toLocaleString('en-ZA', {
                        dateStyle: 'medium',
                        timeStyle: 'short',
                      })}
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          setSelected(inc);
                        }}
                        className="px-2.5 py-1.5 rounded-lg bg-slate-900 border border-slate-700 hover:border-slate-500 text-slate-200 text-[11px] font-bold flex items-center space-x-1 ml-auto"
                      >
                        <Eye className="w-3.5 h-3.5" />
                        <span>Open</span>
                      </button>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
      )}

      {/* Detail modal */}
      {selected && (
        <IncidentDetailModal
          incident={selected}
          onClose={() => {
            setSelected(null);
            setNoteDraft('');
            setErrorMessage(null);
          }}
          canResolve={canResolve}
          pendingAction={pendingAction}
          noteDraft={noteDraft}
          setNoteDraft={setNoteDraft}
          errorMessage={errorMessage}
          onAcknowledge={handleAcknowledge}
          onResolve={handleResolve}
          onAppendNote={handleAppendNote}
          onFocusOnMap={(focus) => {
            setSelected(null);
            setView('map');
            setMapFocus(focus);
          }}
        />
      )}
    </div>
  );
};

interface IncidentMapViewProps {
  incidents: SafetyIncident[];
  mapFocus: [number, number] | null;
  onSelect: (incident: SafetyIncident) => void;
}

const IncidentMapView: React.FC<IncidentMapViewProps> = ({
  incidents,
  mapFocus,
  onSelect,
}) => {
  const located = incidents.filter(
    (i) => i.latitude !== null && i.longitude !== null,
  );
  const center = useMemo(() => computeCenter(located), [located]);
  const focusKey = mapFocus?.join(',') ?? '';
  return (
    <div className="glass-panel border border-slate-800 rounded-2xl overflow-hidden">
      <div className="px-4 py-3 border-b border-slate-800 flex items-center justify-between">
        <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-2">
          <MapPin className="w-3.5 h-3.5" />
          <span>{located.length} geotagged incidents</span>
          <span className="text-slate-500">·</span>
          <span className="text-slate-500">
            {incidents.length - located.length} without GPS
          </span>
        </div>
        <div className="flex items-center space-x-2">
          {(['open', 'acknowledged', 'resolved'] as const).map((s) => (
            <span
              key={s}
              className="inline-flex items-center space-x-1 text-[10px] uppercase font-bold text-slate-300"
            >
              <span
                className="w-2 h-2 rounded-full"
                style={{ backgroundColor: STATUS_COLOR[s] }}
              />
              <span>{s}</span>
            </span>
          ))}
        </div>
      </div>
      <div className="h-[600px]">
        <MapContainer
          center={center}
          zoom={mapFocus ? 16 : 12}
          scrollWheelZoom
          className="w-full h-full"
          key={focusKey}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          {mapFocus && <FlyToFocus position={mapFocus} />}
          {located.map((incident) => {
            const reporterLabel = incident.reporterName
              ? `${incident.reporterName} · ${INCIDENT_TYPE_LABEL[incident.incidentType]}`
              : INCIDENT_TYPE_LABEL[incident.incidentType];
            return (
              <Marker
                key={incident.id}
                position={[incident.latitude as number, incident.longitude as number]}
                icon={incidentIconFor(incident.status)}
                eventHandlers={{
                  click: () => {
                    onSelect(incident);
                  },
                }}
              >
                <Popup>
                  <div className="text-xs space-y-1 p-1 min-w-[180px]">
                    <div className="font-bold text-slate-900">{reporterLabel}</div>
                    <div className="text-[11px] text-slate-700">
                      {new Date(incident.createdAt).toLocaleString('en-ZA', {
                        dateStyle: 'medium',
                        timeStyle: 'short',
                      })}
                    </div>
                    <div className="text-[10px] font-mono uppercase text-slate-700">
                      Status: {incident.status}
                    </div>
                    {incident.rideReference && (
                      <div className="text-[10px] font-mono text-purple-800">
                        Ride: {incident.rideReference}
                      </div>
                    )}
                  </div>
                </Popup>
              </Marker>
            );
          })}
        </MapContainer>
      </div>
    </div>
  );
};

interface IncidentDetailModalProps {
  incident: SafetyIncident;
  onClose: () => void;
  canResolve: boolean;
  pendingAction: string | null;
  noteDraft: string;
  setNoteDraft: (s: string) => void;
  errorMessage: string | null;
  onAcknowledge: () => Promise<void>;
  onResolve: () => Promise<void>;
  onAppendNote: () => Promise<void>;
  onFocusOnMap: (focus: [number, number]) => void;
}

const IncidentDetailModal: React.FC<IncidentDetailModalProps> = ({
  incident,
  onClose,
  canResolve,
  pendingAction,
  noteDraft,
  setNoteDraft,
  errorMessage,
  onAcknowledge,
  onResolve,
  onAppendNote,
  onFocusOnMap,
}) => {
  const StatusIcon = STATUS_ICON[incident.status];
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
            <div className="flex items-center space-x-2">
              <span
                className={`text-[10px] px-2 py-1 rounded-full border font-mono uppercase ${INCIDENT_TYPE_BADGE[incident.incidentType]}`}
              >
                {INCIDENT_TYPE_LABEL[incident.incidentType]}
              </span>
              <span
                className={`inline-flex items-center space-x-1.5 text-[10px] px-2.5 py-1 rounded-full border font-mono uppercase ${STATUS_BADGE[incident.status]}`}
              >
                <StatusIcon className="w-3 h-3" />
                <span>{incident.status}</span>
              </span>
            </div>
            <h3 className="text-sm font-bold text-white">Incident {incident.id.slice(0, 8)}</h3>
            <p className="text-[11px] text-slate-400">
              Reported {new Date(incident.createdAt).toLocaleString('en-ZA', {
                dateStyle: 'medium',
                timeStyle: 'short',
              })}
            </p>
          </div>
          <button onClick={onClose} className="p-1 text-slate-500 hover:text-white">
            <X className="w-4 h-4" />
          </button>
        </div>

        <div className="grid grid-cols-2 gap-3 text-xs">
          <DetailItem
            icon={UserRound}
            label="Reporter"
            primary={incident.reporterName || 'Unknown'}
            secondary={[incident.reporterEmail, incident.reporterPhone, incident.reporterRole].filter(Boolean).join(' · ')}
          />
          <DetailItem
            icon={MapPin}
            label="Ride"
            primary={incident.rideReference ?? 'Standalone report'}
            secondary={incident.rideStatus ?? ''}
          />
          {incident.latitude !== null && incident.longitude !== null && (
            <DetailItem
              icon={MapPin}
              label="GPS"
              primary={`${incident.latitude.toFixed(5)}, ${incident.longitude.toFixed(5)}`}
              secondary="Captured at report time"
            />
          )}
          {incident.message && (
            <div className="col-span-2 glass-card border border-slate-800 rounded-xl p-3">
              <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-1.5 mb-1">
                <MessageSquare className="w-3 h-3" />
                <span>Reporter message</span>
              </div>
              <p className="text-[12px] text-slate-100 whitespace-pre-wrap break-words">
                {incident.message}
              </p>
            </div>
          )}
        </div>

        {/* Lifecycle */}
        <div className="grid grid-cols-2 gap-3 text-xs">
          <div className="glass-card border border-slate-800 rounded-xl p-3">
            <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-1.5 mb-1">
              <Clock className="w-3 h-3" />
              <span>Acknowledged</span>
            </div>
            {incident.acknowledgedAt ? (
              <div>
                <div className="text-slate-100 font-bold">{incident.acknowledgedByName || incident.acknowledgedBy?.slice(0, 8) || 'Unknown'}</div>
                <div className="text-[11px] text-slate-400">
                  {new Date(incident.acknowledgedAt).toLocaleString('en-ZA', {
                    dateStyle: 'medium',
                    timeStyle: 'short',
                  })}
                </div>
              </div>
            ) : (
              <span className="text-slate-500 italic">Not yet acknowledged</span>
            )}
          </div>
          <div className="glass-card border border-slate-800 rounded-xl p-3">
            <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-1.5 mb-1">
              <CheckCircle2 className="w-3 h-3" />
              <span>Resolved</span>
            </div>
            {incident.resolvedAt ? (
              <div>
                <div className="text-slate-100 font-bold">{incident.resolvedByName || incident.resolvedBy?.slice(0, 8) || 'Unknown'}</div>
                <div className="text-[11px] text-slate-400">
                  {new Date(incident.resolvedAt).toLocaleString('en-ZA', {
                    dateStyle: 'medium',
                    timeStyle: 'short',
                  })}
                </div>
              </div>
            ) : (
              <span className="text-slate-500 italic">Not yet resolved</span>
            )}
          </div>
        </div>

        {/* Contact shortcuts */}
        {(incident.reporterEmail || incident.reporterPhone) && (
          <div className="flex flex-wrap gap-2">
            {incident.reporterEmail && (
              <a
                href={`mailto:${incident.reporterEmail}`}
                className="px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 hover:border-slate-500 text-slate-200 text-[11px] font-bold flex items-center space-x-1.5"
              >
                <Mail className="w-3 h-3" />
                <span>Email reporter</span>
              </a>
            )}
            {incident.reporterPhone && (
              <a
                href={`tel:${incident.reporterPhone}`}
                className="px-3 py-1.5 rounded-lg bg-slate-900 border border-slate-700 hover:border-slate-500 text-slate-200 text-[11px] font-bold flex items-center space-x-1.5"
              >
                <Phone className="w-3 h-3" />
                <span>Call {incident.reporterPhone}</span>
              </a>
            )}
            {incident.latitude !== null && incident.longitude !== null && (
              <button
                onClick={() =>
                  onFocusOnMap([incident.latitude as number, incident.longitude as number])
                }
                className="px-3 py-1.5 rounded-lg bg-emerald-500/10 border border-emerald-500/40 text-emerald-200 text-[11px] font-bold flex items-center space-x-1.5 hover:bg-emerald-500/20"
              >
                <MapIcon className="w-3.5 h-3.5" />
                <span>Show on map</span>
              </button>
            )}
          </div>
        )}

        {/* Mini-map when GPS is known */}
        {incident.latitude !== null && incident.longitude !== null && (
          <div className="rounded-xl overflow-hidden border border-slate-800 h-56">
            <MapContainer
              center={[incident.latitude as number, incident.longitude as number]}
              zoom={15}
              scrollWheelZoom
              className="w-full h-full"
            >
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <Marker
                position={[incident.latitude as number, incident.longitude as number]}
                icon={incidentIconFor(incident.status)}
              >
                <Popup>
                  <div className="text-xs font-bold text-slate-900">
                    {INCIDENT_TYPE_LABEL[incident.incidentType]}
                  </div>
                </Popup>
              </Marker>
            </MapContainer>
          </div>
        )}

        {/* Internal notes */}
        <div>
          <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-1.5 mb-2">
            <StickyNote className="w-3 h-3" />
            <span>Operator notes</span>
          </div>
          {incident.internalNotes.length === 0 ? (
            <div className="p-3 rounded-xl bg-slate-900/40 border border-slate-800 text-[11px] text-slate-500 italic">
              No operator notes yet.
            </div>
          ) : (
            <div className="space-y-2">
              {incident.internalNotes.map((note, idx) => (
                <div
                  key={`${note.appended_at}-${idx}`}
                  className="p-3 rounded-xl bg-slate-900/60 border border-slate-800"
                >
                  <p className="text-[12px] text-slate-100 whitespace-pre-wrap">{note.note}</p>
                  <p className="text-[10px] text-slate-500 mt-1 flex items-center space-x-2">
                    <span>{note.operator_email}</span>
                    <span>·</span>
                    <span>{note.operator_role}</span>
                    <span>·</span>
                    <span>
                      {new Date(note.appended_at).toLocaleString('en-ZA', {
                        dateStyle: 'medium',
                        timeStyle: 'short',
                      })}
                    </span>
                  </p>
                </div>
              ))}
            </div>
          )}
          {incident.status !== 'resolved' && (
            <div className="space-y-2 mt-3">
              <textarea
                value={noteDraft}
                onChange={(e) => setNoteDraft(e.target.value)}
                rows={3}
                placeholder="Add an internal note for the audit trail (visible to admins only)..."
                className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400 resize-none"
              />
              <button
                onClick={onAppendNote}
                disabled={pendingAction === 'note' || noteDraft.trim().length < 4}
                className="px-3 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
              >
                {pendingAction === 'note' ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <StickyNote className="w-4 h-4" />
                )}
                <span>Save Note</span>
              </button>
            </div>
          )}
        </div>

        {errorMessage && (
          <div className="flex items-start space-x-2 p-3 rounded-xl border border-red-500/40 bg-red-500/10 text-red-200 text-xs">
            <AlertTriangle className="w-4 h-4 mt-0.5 shrink-0" />
            <span>{errorMessage}</span>
          </div>
        )}

        {/* Actions */}
        <div className="flex items-center justify-end space-x-2 pt-2 border-t border-slate-800">
          <button
            onClick={onClose}
            className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
          >
            Close
          </button>
          {incident.status === 'open' && (
            <button
              onClick={onAcknowledge}
              disabled={pendingAction === 'acknowledge'}
              className="px-3 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
            >
              {pendingAction === 'acknowledge' ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <Eye className="w-4 h-4" />
              )}
              <span>Acknowledge</span>
            </button>
          )}
          {incident.status !== 'resolved' && (
            <button
              onClick={onResolve}
              disabled={!canResolve || pendingAction === 'resolve'}
              className="px-3 py-2 rounded-xl bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
            >
              {pendingAction === 'resolve' ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <CheckCircle2 className="w-4 h-4" />
              )}
              <span>{canResolve ? 'Resolve' : 'Resolve (needs fleet:write)'}</span>
            </button>
          )}
        </div>
      </div>
    </div>
  );
};

interface DetailItemProps {
  icon: React.FC<{ className?: string }>;
  label: string;
  primary: string;
  secondary: string;
}

const DetailItem: React.FC<DetailItemProps> = ({ icon: Icon, label, primary, secondary }) => (
  <div className="glass-card border border-slate-800 rounded-xl p-3">
    <div className="text-[11px] uppercase tracking-wider text-slate-400 font-bold flex items-center space-x-1.5 mb-1">
      <Icon className="w-3 h-3" />
      <span>{label}</span>
    </div>
    <div className="text-slate-100 font-bold">{primary}</div>
    {secondary && <div className="text-[11px] text-slate-400">{secondary}</div>}
  </div>
);
