import React, { useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import type { DriverProfile, DriverDocument } from '../types/admin';
import {
  UserCheck,
  CheckCircle2,
  XCircle,
  AlertTriangle,
  FileText,
  ZoomIn,
  ZoomOut,
  RotateCw,
  Download,
  ShieldCheck,
  Check,
  AlertCircle,
  Loader2,
} from 'lucide-react';

export const DriverKYCInspector: React.FC = () => {
  const { drivers, approveDriver, rejectDriver, flagDriverDocument, approveDriverDocument, addNotification } = useAdmin();

  const [filterStatus, setFilterStatus] = useState<'all' | 'pending' | 'under_review' | 'approved' | 'rejected'>('pending');
  const [selectedDriverId, setSelectedDriverId] = useState<string>(drivers[0]?.id || '');
  const [selectedDocId, setSelectedDocId] = useState<string>('');
  
  // Image viewer state
  const [zoomLevel, setZoomLevel] = useState<number>(1);
  const [rotation, setRotation] = useState<number>(0);

  // Modal states
  const [showFlagModal, setShowFlagModal] = useState<boolean>(false);
  const [flagTag, setFlagTag] = useState<string>('Blurry / Low-Resolution Scan');
  const [flagNotes, setFlagNotes] = useState<string>('');

  const [showRejectModal, setShowRejectModal] = useState<boolean>(false);
  const [rejectReason, setRejectReason] = useState<string>('Documents failed verification standard compliance');

  // In-flight action state (prevents double submits & shows progress)
  const [busyAction, setBusyAction] = useState<null | 'doc' | 'flag' | 'reject' | 'driver'>(null);
  const [actionError, setActionError] = useState<{
    action: 'doc' | 'flag' | 'reject' | 'driver';
    message: string;
  } | null>(null);

  const filteredDrivers = drivers.filter(d => {
    if (filterStatus === 'all') return true;
    return d.driverStatus === filterStatus;
  });

  const activeDriver: DriverProfile | undefined =
    filteredDrivers.find(d => d.id === selectedDriverId) || filteredDrivers[0];

  const activeDocument: DriverDocument | undefined = activeDriver?.documents.find(
    doc => doc.id === selectedDocId
  ) || activeDriver?.documents[0];

  const predefinedFlagTags = [
    'Blurry / Low-Resolution Scan',
    'Expired Document',
    'Name Mismatch with SA ID',
    'Obscured Text / Flash Reflection',
    'Missing Official Stamp / Signature'
  ];

  const docTypeLabels: Record<string, string> = {
    prdp_license: 'PrDP Driving License',
    selfie: 'Selfie Capture',
    vehicle_registration: 'Vehicle Registration (RC)',
    insurance: 'Passenger Comprehensive Insurance',
    roadworthiness: 'DEKRA Roadworthiness Certificate'
  };

  const handleFlagSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeDriver || !activeDocument || busyAction) return;
    const finalReason = `${flagTag}: ${flagNotes.trim() || 'No additional note provided'}`;
    setBusyAction('flag');
    setActionError(null);
    try {
      await flagDriverDocument(activeDriver.id, activeDocument.id, finalReason);
      setShowFlagModal(false);
      setFlagNotes('');
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to flag document';
      setActionError({ action: 'flag', message });
      addNotification({
        type: 'error',
        title: 'Document Flag Failed',
        message,
        timestamp: new Date().toISOString(),
      });
    } finally {
      setBusyAction(null);
    }
  };

  const handleRejectSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!activeDriver || busyAction) return;
    setBusyAction('reject');
    setActionError(null);
    try {
      await rejectDriver(activeDriver.id, rejectReason);
      setShowRejectModal(false);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reject application';
      setActionError({ action: 'reject', message });
      addNotification({
        type: 'error',
        title: 'Application Reject Failed',
        message,
        timestamp: new Date().toISOString(),
      });
    } finally {
      setBusyAction(null);
    }
  };

  const handleApproveDoc = async () => {
    if (!activeDriver || !activeDocument || busyAction) return;
    setBusyAction('doc');
    setActionError(null);
    try {
      await approveDriverDocument(activeDriver.id, activeDocument.id);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to approve document';
      setActionError({ action: 'doc', message });
      addNotification({
        type: 'error',
        title: 'Document Approval Failed',
        message,
        timestamp: new Date().toISOString(),
      });
    } finally {
      setBusyAction(null);
    }
  };

  const handleApproveDriver = async () => {
    if (!activeDriver || busyAction) return;
    setBusyAction('driver');
    setActionError(null);
    try {
      await approveDriver(activeDriver.id);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to approve driver';
      setActionError({ action: 'driver', message });
      addNotification({
        type: 'error',
        title: 'Driver Approval Failed',
        message,
        timestamp: new Date().toISOString(),
      });
    } finally {
      setBusyAction(null);
    }
  };

  return (
    <div className="space-y-6 animate-in fade-in duration-300">
      {/* Header Banner */}
      <div className="glass-panel p-6 rounded-2xl border border-slate-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center space-x-2 text-xs font-bold uppercase tracking-wider text-purple-400 mb-1 font-mono">
            <UserCheck className="w-4 h-4 text-purple-400" />
            <span>Module 1 Operations</span>
          </div>
          <h1 className="text-2xl font-bold font-heading text-white">Driver KYC Verification Engine</h1>
          <p className="text-slate-400 text-xs mt-1">
            Split-screen document inspector & compliance badge manager with instant push alert dispatch.
          </p>
        </div>

        {/* Status Filter Pills */}
        <div className="flex items-center space-x-2 overflow-x-auto pb-1 md:pb-0">
          {(['pending', 'under_review', 'approved', 'rejected', 'all'] as const).map(st => (
            <button
              key={st}
              onClick={() => setFilterStatus(st)}
              className={`px-3 py-1.5 rounded-lg text-xs font-semibold uppercase tracking-wider transition-all border ${
                filterStatus === st
                  ? 'bg-purple-600 text-white border-purple-500 shadow-lg shadow-purple-500/20'
                  : 'bg-slate-900/80 text-slate-400 border-slate-800 hover:border-slate-700'
              }`}
            >
              {st.replace('_', ' ')}
            </button>
          ))}
        </div>
      </div>

      {/* Main Split-Screen Inspector Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Driver Queue & Application Details (4 cols) */}
        <div className="lg:col-span-4 space-y-4">
          {/* Driver Selection Queue Card */}
          <div className="glass-panel rounded-2xl p-4 border border-slate-800 space-y-3">
            <div className="flex items-center justify-between text-xs border-b border-slate-800 pb-2">
              <span className="font-bold text-slate-300 uppercase tracking-wider">
                Verification Queue ({filteredDrivers.length})
              </span>
              <span className="text-purple-400 font-mono text-[11px]">Realtime Queue</span>
            </div>

            <div className="space-y-2 max-h-56 overflow-y-auto pr-1">
              {filteredDrivers.length === 0 ? (
                <div className="text-center py-6 text-xs text-slate-500">No applications match this filter</div>
              ) : (
                filteredDrivers.map(drv => {
                  const isSelected = activeDriver?.id === drv.id;
                  return (
                    <div
                      key={drv.id}
                      onClick={() => {
                        setSelectedDriverId(drv.id);
                        setSelectedDocId(drv.documents[0]?.id || '');
                        setZoomLevel(1);
                        setRotation(0);
                      }}
                      className={`p-3 rounded-xl border transition-all cursor-pointer flex items-center justify-between ${
                        isSelected
                          ? 'bg-purple-950/40 border-purple-500/60 shadow-md shadow-purple-500/10'
                          : 'bg-slate-900/60 border-slate-800/80 hover:bg-slate-800/60'
                      }`}
                    >
                      <div className="flex items-center space-x-3">
                        <img
                          src={drv.avatarUrl}
                          alt={drv.fullName}
                          className="w-9 h-9 rounded-full object-cover border border-slate-700"
                        />
                        <div>
                          <div className="text-xs font-semibold text-white flex items-center space-x-1.5">
                            <span>{drv.fullName}</span>
                            {drv.driverStatus === 'approved' && (
                              <ShieldCheck className="w-3.5 h-3.5 text-emerald-400 inline" />
                            )}
                          </div>
                          <div className="text-[11px] text-slate-400">{drv.operatingCity} • {drv.vehicleMake} {drv.vehicleModel}</div>
                        </div>
                      </div>

                      <span
                        className={`text-[10px] px-2 py-0.5 rounded-full font-mono uppercase font-bold border ${
                          drv.driverStatus === 'approved'
                            ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                            : drv.driverStatus === 'rejected'
                            ? 'bg-red-500/20 text-red-400 border-red-500/30'
                            : drv.driverStatus === 'flagged'
                            ? 'bg-amber-500/20 text-amber-400 border-amber-500/30'
                            : 'bg-indigo-500/20 text-indigo-400 border-indigo-500/30'
                        }`}
                      >
                        {drv.driverStatus}
                      </span>
                    </div>
                  );
                })
              )}
            </div>
          </div>

          {/* Active Driver Profile Summary */}
          {activeDriver && (
            <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4">
              <div className="flex items-center space-x-4 border-b border-slate-800 pb-4">
                <img
                  src={activeDriver.avatarUrl}
                  alt={activeDriver.fullName}
                  className="w-14 h-14 rounded-2xl object-cover border-2 border-purple-500/40 shadow-lg"
                />
                <div>
                  <h3 className="font-heading font-bold text-lg text-white flex items-center space-x-2">
                    <span>{activeDriver.fullName}</span>
                    {activeDriver.driverStatus === 'approved' && (
                      <span className="text-xs bg-emerald-500/20 text-emerald-400 px-2 py-0.5 rounded-full border border-emerald-500/30 font-sans">
                        ✓ Verified Badge
                      </span>
                    )}
                  </h3>
                  <div className="text-xs text-slate-400 flex items-center space-x-2 mt-0.5">
                    <span>{activeDriver.email}</span>
                    <span>•</span>
                    <span>{activeDriver.phone}</span>
                  </div>
                </div>
              </div>

              {/* Data Grid */}
              <div className="grid grid-cols-2 gap-3 text-xs">
                <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 space-y-0.5">
                  <span className="text-slate-500 text-[10px] uppercase font-bold">SA ID Number</span>
                  <div className="font-mono text-slate-200">{activeDriver.saIdNumber}</div>
                </div>
                <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 space-y-0.5">
                  <span className="text-slate-500 text-[10px] uppercase font-bold">License Number</span>
                  <div className="font-mono text-slate-200">{activeDriver.licenseNumber}</div>
                </div>
                <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 space-y-0.5">
                  <span className="text-slate-500 text-[10px] uppercase font-bold">Vehicle Details</span>
                  <div className="text-slate-200">{activeDriver.vehicleYear} {activeDriver.vehicleMake} {activeDriver.vehicleModel}</div>
                  <div className="text-[10px] text-purple-400 font-mono">{activeDriver.vehiclePlate}</div>
                </div>
                <div className="p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 space-y-0.5">
                  <span className="text-slate-500 text-[10px] uppercase font-bold">Bank Account</span>
                  <div className="text-slate-200">{activeDriver.bankName}</div>
                  <div className="text-[10px] text-slate-400 font-mono">Acct: ****{activeDriver.bankAccount.slice(-4)}</div>
                </div>
              </div>

              {/* Document Check List */}
              <div className="space-y-2">
                <span className="text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                  Required Document Audits
                </span>
                <div className="space-y-1.5">
                  {activeDriver.documents.map(doc => {
                    const isDocSelected = (selectedDocId || activeDriver.documents[0]?.id) === doc.id;
                    return (
                      <div
                        key={doc.id}
                        onClick={() => {
                          setSelectedDocId(doc.id);
                          setZoomLevel(1);
                          setRotation(0);
                        }}
                        className={`p-2.5 rounded-xl border text-xs flex items-center justify-between cursor-pointer transition-all ${
                          isDocSelected
                            ? 'bg-purple-900/30 border-purple-500/70 text-white'
                            : 'bg-slate-900/60 border-slate-800 text-slate-300 hover:bg-slate-800'
                        }`}
                      >
                        <div className="flex items-center space-x-2">
                          {doc.status === 'approved' ? (
                            <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                          ) : doc.status === 'flagged' ? (
                            <AlertTriangle className="w-4 h-4 text-amber-400" />
                          ) : (
                            <FileText className="w-4 h-4 text-slate-400" />
                          )}
                          <span className="font-medium">{docTypeLabels[doc.docType] || doc.title}</span>
                        </div>
                        <span className="text-[10px] font-mono text-slate-400">
                          {doc.expiresAt ? `Exp: ${doc.expiresAt}` : ''}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Right Column: Split-Screen High-Res Document Viewer & Inspector Controls (8 cols) */}
        <div className="lg:col-span-8 space-y-4">
          <div className="glass-panel rounded-2xl p-5 border border-slate-800 space-y-4 min-h-[580px] flex flex-col justify-between">
            {/* Toolbar Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-800 pb-3">
              <div>
                <span className="text-xs text-purple-400 font-mono font-bold uppercase tracking-wider">
                  Inspecting Document
                </span>
                <h3 className="text-lg font-bold text-white">
                  {activeDocument ? docTypeLabels[activeDocument.docType] || activeDocument.title : 'No Document Selected'}
                </h3>
              </div>

              {/* View Controls */}
              <div className="flex items-center space-x-2">
                <button
                  onClick={() => setZoomLevel(prev => Math.max(0.5, prev - 0.25))}
                  className="p-2 rounded-lg bg-slate-900 border border-slate-800 text-slate-300 hover:text-white hover:border-slate-700 transition-colors"
                  title="Zoom Out"
                >
                  <ZoomOut className="w-4 h-4" />
                </button>
                <span className="text-xs font-mono text-slate-400 px-2">{Math.round(zoomLevel * 100)}%</span>
                <button
                  onClick={() => setZoomLevel(prev => Math.min(3, prev + 0.25))}
                  className="p-2 rounded-lg bg-slate-900 border border-slate-800 text-slate-300 hover:text-white hover:border-slate-700 transition-colors"
                  title="Zoom In"
                >
                  <ZoomIn className="w-4 h-4" />
                </button>
                <button
                  onClick={() => setRotation(prev => (prev + 90) % 360)}
                  className="p-2 rounded-lg bg-slate-900 border border-slate-800 text-slate-300 hover:text-white hover:border-slate-700 transition-colors"
                  title="Rotate Image"
                >
                  <RotateCw className="w-4 h-4" />
                </button>
                {activeDocument && (
                  <a
                    href={activeDocument.fileUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="p-2 rounded-lg bg-purple-600/20 border border-purple-500/40 text-purple-300 hover:bg-purple-600/40 transition-colors flex items-center space-x-1 text-xs"
                  >
                    <Download className="w-4 h-4" />
                    <span className="hidden sm:inline">High-Res</span>
                  </a>
                )}
              </div>
            </div>

            {/* Document Image Viewport */}
            <div className="relative w-full h-[380px] rounded-xl bg-slate-950/90 border border-slate-800/90 overflow-hidden flex items-center justify-center p-4">
              {activeDocument ? (
                <div className="overflow-auto max-w-full max-h-full flex items-center justify-center">
                  <img
                    src={activeDocument.fileUrl}
                    alt={activeDocument.title}
                    style={{
                      transform: `scale(${zoomLevel}) rotate(${rotation}deg)`,
                      transition: 'transform 0.2s ease-out'
                    }}
                    className="max-h-[340px] rounded-lg object-contain shadow-2xl border border-slate-800"
                  />
                </div>
              ) : (
                <div className="text-slate-500 text-sm">No verification document preview available</div>
              )}

              {/* Status Badge Overlay */}
              {activeDocument && (
                <div className="absolute top-4 left-4">
                  <span
                    className={`text-xs px-3 py-1 rounded-full font-mono uppercase font-bold border backdrop-blur-md shadow-lg ${
                      activeDocument.status === 'approved'
                        ? 'bg-emerald-500/30 text-emerald-300 border-emerald-500/50'
                        : activeDocument.status === 'flagged'
                        ? 'bg-amber-500/30 text-amber-300 border-amber-500/50'
                        : 'bg-purple-500/30 text-purple-300 border-purple-500/50'
                    }`}
                  >
                    Document Status: {activeDocument.status}
                  </span>
                </div>
              )}
            </div>

            {/* Flag Note Banner if flagged */}
            {activeDocument?.issueNotes && (
              <div className="p-3 rounded-xl bg-amber-950/30 border border-amber-500/40 text-amber-300 text-xs flex items-center space-x-2">
                <AlertCircle className="w-4 h-4 text-amber-400 shrink-0" />
                <span>
                  <strong>Flag Reason:</strong> {activeDocument.issueNotes}
                </span>
              </div>
            )}

            {/* Verification Action Bar */}
            {activeDriver && (
              <div className="flex flex-col sm:flex-row items-center justify-between gap-3 pt-3 border-t border-slate-800">
                <div className="flex items-center space-x-2 w-full sm:w-auto">
                  {activeDocument && activeDocument.status !== 'approved' && (
                    <button
                      onClick={handleApproveDoc}
                      disabled={busyAction !== null}
                      className="px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 text-xs font-semibold transition-colors flex items-center space-x-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      {busyAction === 'doc' ? (
                        <Loader2 className="w-4 h-4 animate-spin text-emerald-400" />
                      ) : (
                        <Check className="w-4 h-4 text-emerald-400" />
                      )}
                      <span>{busyAction === 'doc' ? 'Approving...' : 'Approve This Doc'}</span>
                    </button>
                  )}
                  {activeDocument && (
                    <button
                      onClick={() => setShowFlagModal(true)}
                      disabled={busyAction !== null}
                      className="px-3.5 py-2 rounded-xl bg-amber-500/10 border border-amber-500/30 text-amber-300 hover:bg-amber-500/20 text-xs font-semibold transition-colors flex items-center space-x-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                      <AlertTriangle className="w-4 h-4 text-amber-400" />
                      <span>Flag Doc For Re-upload</span>
                    </button>
                  )}
                </div>

                <div className="flex items-center space-x-3 w-full sm:w-auto justify-end">
                  <button
                    onClick={() => setShowRejectModal(true)}
                    disabled={busyAction !== null}
                    className="px-4 py-2.5 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 hover:bg-red-500/20 text-xs font-bold transition-all flex items-center space-x-1.5 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    <XCircle className="w-4 h-4" />
                    <span>Reject Application</span>
                  </button>

                  <button
                    onClick={handleApproveDriver}
                    disabled={busyAction !== null}
                    className="px-5 py-2.5 rounded-xl bg-slate-100 text-slate-950 text-xs font-bold shadow-lg shadow-white/10 hover:bg-white transition-all flex items-center space-x-2 disabled:opacity-50 disabled:cursor-not-allowed"
                  >
                    {busyAction === 'driver' ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <ShieldCheck className="w-4.5 h-4.5" />
                    )}
                    <span>{busyAction === 'driver' ? 'Approving...' : 'Approve Driver & Grant Badge'}</span>
                  </button>
                </div>
              </div>
            )}

            {actionError && (actionError.action === 'doc' || actionError.action === 'driver') && (
              <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                {actionError.message}
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Flag Modal */}
      {showFlagModal && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-md rounded-2xl p-6 border border-slate-800 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-white flex items-center space-x-2">
                <AlertTriangle className="w-5 h-5 text-amber-400" />
                <span>Flag Document For Re-upload</span>
              </h3>
              <button
                onClick={() => setShowFlagModal(false)}
                disabled={busyAction === 'flag'}
                className="text-slate-400 hover:text-white disabled:opacity-40"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleFlagSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Standard Violation Tag</label>
                <select
                  value={flagTag}
                  onChange={e => setFlagTag(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500"
                >
                  {predefinedFlagTags.map(tag => (
                    <option key={tag} value={tag}>
                      {tag}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-slate-300 font-semibold mb-1">Additional Compliance Notes</label>
                <textarea
                  rows={3}
                  value={flagNotes}
                  onChange={e => setFlagNotes(e.target.value)}
                  placeholder="Specify why re-upload is required..."
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-amber-500"
                />
              </div>

              <div className="p-3 rounded-xl bg-amber-500/10 border border-amber-500/20 text-amber-300 text-[11px]">
                This action flags the document and sends the driver an immediate re-upload notification.
              </div>

              {actionError?.action === 'flag' && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                  {actionError.message}
                </div>
              )}

              <div className="flex justify-end space-x-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowFlagModal(false)}
                  disabled={busyAction === 'flag'}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 font-medium disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={busyAction === 'flag'}
                  className="px-4 py-2 rounded-xl bg-amber-500 text-slate-950 font-bold hover:bg-amber-400 shadow-lg shadow-amber-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                >
                  {busyAction === 'flag' && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{busyAction === 'flag' ? 'Dispatching...' : 'Confirm & Dispatch Flag'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Reject Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-slate-950/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="glass-panel w-full max-w-md rounded-2xl p-6 border border-slate-800 shadow-2xl space-y-4 animate-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h3 className="font-heading font-bold text-white flex items-center space-x-2">
                <XCircle className="w-5 h-5 text-red-400" />
                <span>Reject Driver Application</span>
              </h3>
              <button
                onClick={() => setShowRejectModal(false)}
                disabled={busyAction === 'reject'}
                className="text-slate-400 hover:text-white disabled:opacity-40"
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleRejectSubmit} className="space-y-4 text-xs">
              <div>
                <label className="block text-slate-300 font-semibold mb-1">Rejection Reason & Audit Log</label>
                <textarea
                  rows={3}
                  value={rejectReason}
                  onChange={e => setRejectReason(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-slate-900 border border-slate-800 text-slate-200 focus:outline-none focus:border-red-500"
                />
              </div>

              {actionError?.action === 'reject' && (
                <div className="p-3 rounded-xl bg-red-500/10 border border-red-500/30 text-red-400 text-[11px]">
                  {actionError.message}
                </div>
              )}

              <div className="flex justify-end space-x-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowRejectModal(false)}
                  disabled={busyAction === 'reject'}
                  className="px-4 py-2 rounded-xl bg-slate-800 text-slate-300 hover:bg-slate-700 font-medium disabled:opacity-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={busyAction === 'reject'}
                  className="px-4 py-2 rounded-xl bg-red-600 text-white font-bold hover:bg-red-500 shadow-lg shadow-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed flex items-center space-x-2"
                >
                  {busyAction === 'reject' && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{busyAction === 'reject' ? 'Rejecting...' : 'Reject & Update Status'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
