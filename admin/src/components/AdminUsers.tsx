import React, { useMemo, useState } from 'react';
import { useAdmin } from '../context/AdminContext';
import { roleLabel } from '../lib/rbac';
import {
  ShieldCheck,
  Search,
  UserCog,
  AlertTriangle,
  Check,
  ArrowDownCircle,
  ChevronDown,
  Loader2,
  UserPlus,
  Crown,
} from 'lucide-react';
import type { AdminRole, AdminUser } from '../types/admin';

type RoleFilter = 'all' | AdminRole;

interface PromoteCandidate {
  id: string;
  fullName: string;
  email: string;
  sourceRole: 'driver' | 'passenger';
}

const ROLE_DESCRIPTIONS: Record<AdminRole, string> = {
  super_admin: 'Full access to all console modules including admin role management.',
  kyc_officer: 'Reviews driver KYC, passenger identity, and may update driver verification status.',
  fleet_dispatcher: 'Manages live fleet, reassigns rides, and performs emergency cancellations.',
  finance_manager: 'Owns fare schemas, payouts, and driver statements.',
};

const ROLE_BADGE: Record<AdminRole, string> = {
  super_admin: 'bg-purple-500/20 text-purple-300 border-purple-500/40',
  kyc_officer: 'bg-amber-500/20 text-amber-300 border-amber-500/40',
  fleet_dispatcher: 'bg-emerald-500/20 text-emerald-300 border-emerald-500/40',
  finance_manager: 'bg-cyan-500/20 text-cyan-300 border-cyan-500/40',
};

export const AdminUsers: React.FC = () => {
  const {
    admins,
    drivers,
    passengers,
    currentRole,
    user,
    assignAdminRole,
    demoteAdmin,
    promoteUserToAdminScoped,
    addNotification,
  } = useAdmin();

  const [search, setSearch] = useState('');
  const [roleFilter, setRoleFilter] = useState<RoleFilter>('all');

  const [pendingAction, setPendingAction] = useState<string | null>(null);
  const [roleEditor, setRoleEditor] = useState<{
    admin: AdminUser;
    selectedRole: AdminRole;
  } | null>(null);
  const [demoteEditor, setDemoteEditor] = useState<{
    admin: AdminUser;
    fallbackRole: 'driver' | 'passenger';
  } | null>(null);
  const [promoteOpen, setPromoteOpen] = useState(false);
  const [promoteSearch, setPromoteSearch] = useState('');
  const [promoteTargetId, setPromoteTargetId] = useState<string | null>(null);
  const [promoteRole, setPromoteRole] = useState<AdminRole>('kyc_officer');

  const isCurrentSuperAdmin = currentRole === 'super_admin';

  // Build promotion candidate pool from drivers + passengers that are not yet admins.
  const candidates = useMemo<PromoteCandidate[]>(() => {
    const adminIds = new Set(admins.map((a) => a.id));
    return [
      ...drivers
        .filter((d) => !adminIds.has(d.id))
        .map<PromoteCandidate>((d) => ({
          id: d.id,
          fullName: d.fullName,
          email: d.email,
          sourceRole: 'driver',
        })),
      ...passengers
        .filter((p) => !adminIds.has(p.id))
        .map<PromoteCandidate>((p) => ({
          id: p.id,
          fullName: p.fullName,
          email: p.email,
          sourceRole: 'passenger',
        })),
    ].sort((a, b) => a.fullName.localeCompare(b.fullName));
  }, [admins, drivers, passengers]);

  const filteredCandidates = useMemo(() => {
    const term = promoteSearch.trim().toLowerCase();
    if (!term) return candidates.slice(0, 12);
    return candidates
      .filter((c) =>
        c.fullName.toLowerCase().includes(term) ||
        c.email.toLowerCase().includes(term) ||
        c.id.toLowerCase().includes(term),
      )
      .slice(0, 20);
  }, [candidates, promoteSearch]);

  const filteredAdmins = useMemo(() => {
    const term = search.trim().toLowerCase();
    return admins.filter((a) => {
      if (roleFilter !== 'all' && a.adminRole !== roleFilter) return false;
      if (!term) return true;
      return (
        a.fullName.toLowerCase().includes(term) ||
        a.email.toLowerCase().includes(term) ||
        a.phone.toLowerCase().includes(term)
      );
    });
  }, [admins, search, roleFilter]);

  const counts = useMemo(() => {
    const c: Record<AdminRole, number> = {
      super_admin: 0,
      kyc_officer: 0,
      fleet_dispatcher: 0,
      finance_manager: 0,
    };
    for (const a of admins) c[a.adminRole] += 1;
    return c;
  }, [admins]);

  const handleAssignRole = async (admin: AdminUser, nextRole: AdminRole) => {
    setPendingAction(`role:${admin.id}`);
    try {
      await assignAdminRole(admin.id, nextRole);
      setRoleEditor(null);
      addNotification({
        type: 'success',
        title: 'Admin Role Updated',
        message: `${admin.fullName} is now ${roleLabel(nextRole)}.`,
        timestamp: new Date().toISOString(),
      });
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Role change failed',
        message: err instanceof Error ? err.message : 'Unknown error.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setPendingAction(null);
    }
  };

  const handleDemote = async () => {
    if (!demoteEditor) return;
    const { admin, fallbackRole } = demoteEditor;
    setPendingAction(`demote:${admin.id}`);
    try {
      await demoteAdmin(admin.id, fallbackRole);
      setDemoteEditor(null);
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Demote failed',
        message: err instanceof Error ? err.message : 'Unknown error.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setPendingAction(null);
    }
  };

  const handlePromote = async () => {
    const candidate = candidates.find((c) => c.id === promoteTargetId);
    if (!candidate) {
      addNotification({
        type: 'error',
        title: 'Pick a user',
        message: 'Select someone from the list before confirming.',
        timestamp: new Date().toISOString(),
      });
      return;
    }
    setPendingAction(`promote:${candidate.id}`);
    try {
      await promoteUserToAdminScoped(candidate.id, promoteRole, candidate.sourceRole);
      setPromoteOpen(false);
      setPromoteTargetId(null);
      setPromoteRole('kyc_officer');
      setPromoteSearch('');
    } catch (err) {
      addNotification({
        type: 'error',
        title: 'Promotion failed',
        message: err instanceof Error ? err.message : 'Unknown error.',
        timestamp: new Date().toISOString(),
      });
    } finally {
      setPendingAction(null);
    }
  };

  if (!isCurrentSuperAdmin) {
    return (
      <div className="glass-panel border border-amber-500/30 rounded-2xl p-8 max-w-2xl mx-auto text-center">
        <div className="w-12 h-12 mx-auto rounded-full bg-amber-500/10 border border-amber-500/40 flex items-center justify-center text-amber-300">
          <ShieldCheck className="w-6 h-6" />
        </div>
        <h2 className="text-xl font-bold font-heading text-white mt-4">
          Super Admin required
        </h2>
        <p className="text-xs text-slate-400 mt-2">
          Only super admins can manage the admin console roster. Contact an existing super admin
          if you need a role change.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h1 className="text-2xl font-bold font-heading text-white flex items-center space-x-2">
            <ShieldCheck className="w-6 h-6 text-purple-400" />
            <span>Admin Console Roster</span>
          </h1>
          <p className="text-xs text-slate-400 mt-1">
            Promote operators and assign scoped roles. Roles are enforced by Supabase
            triggers server-side.
          </p>
        </div>
        <button
          onClick={() => setPromoteOpen(true)}
          className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-2"
        >
          <UserPlus className="w-4 h-4" />
          <span>Promote a User</span>
        </button>
      </div>

      {/* Role summary tiles */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {(Object.keys(counts) as AdminRole[]).map((role) => (
          <div
            key={role}
            className="glass-card border border-slate-800 rounded-xl p-4 flex flex-col space-y-1"
          >
            <div className="flex items-center justify-between">
              <span className="text-[11px] text-slate-400 uppercase tracking-wider font-bold">
                {roleLabel(role)}
              </span>
              <span className={`text-[10px] px-2 py-0.5 rounded-full border font-mono ${ROLE_BADGE[role]}`}>
                {counts[role]}
              </span>
            </div>
            <p className="text-xs text-slate-300 leading-snug">
              {ROLE_DESCRIPTIONS[role]}
            </p>
          </div>
        ))}
      </div>

      {/* Safety guard */}
      {counts.super_admin <= 1 && (
        <div className="flex items-start space-x-3 p-4 rounded-xl border border-amber-500/40 bg-amber-500/10 text-amber-200">
          <AlertTriangle className="w-5 h-5 mt-0.5 shrink-0" />
          <div>
            <p className="text-sm font-bold">
              Only one super admin remains
            </p>
            <p className="text-xs text-amber-100/80 mt-1">
              Promote another operator to super admin before downgrading or demoting
              yourself — the console cannot run with zero super admins.
            </p>
          </div>
        </div>
      )}

      {/* Filters */}
      <div className="flex items-center gap-3 flex-wrap">
        <div className="relative flex-1 min-w-[220px]">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name, email or phone..."
            className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400"
          />
        </div>
        <div className="relative">
          <select
            value={roleFilter}
            onChange={(e) => setRoleFilter(e.target.value as RoleFilter)}
            className="appearance-none pl-9 pr-9 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm focus:outline-none focus:border-slate-400"
          >
            <option value="all">All roles</option>
            <option value="super_admin">{roleLabel('super_admin')}</option>
            <option value="kyc_officer">{roleLabel('kyc_officer')}</option>
            <option value="fleet_dispatcher">{roleLabel('fleet_dispatcher')}</option>
            <option value="finance_manager">{roleLabel('finance_manager')}</option>
          </select>
          <UserCog className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
          <ChevronDown className="absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400 pointer-events-none" />
        </div>
      </div>

      {/* Admin list */}
      <div className="glass-panel border border-slate-800 rounded-2xl overflow-hidden">
        <table className="w-full text-xs">
          <thead className="bg-slate-900/80 border-b border-slate-800 text-slate-400 uppercase tracking-wider">
            <tr>
              <th className="text-left px-4 py-3 font-bold">Operator</th>
              <th className="text-left px-4 py-3 font-bold">Scoped Role</th>
              <th className="text-left px-4 py-3 font-bold">Last Activity</th>
              <th className="text-right px-4 py-3 font-bold">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filteredAdmins.length === 0 ? (
              <tr>
                <td
                  colSpan={4}
                  className="text-center py-12 text-slate-500"
                >
                  No admins match your filters.
                </td>
              </tr>
            ) : (
              filteredAdmins.map((admin) => {
                const isSelf = admin.id === user?.id;
                const lastSeen = admin.lastSeenAt
                  ? new Date(admin.lastSeenAt).toLocaleString('en-ZA', {
                      dateStyle: 'medium',
                      timeStyle: 'short',
                    })
                  : 'Never';
                return (
                  <tr
                    key={admin.id}
                    className="border-t border-slate-800/80 hover:bg-slate-900/40"
                  >
                    <td className="px-4 py-3">
                      <div className="flex items-center space-x-3">
                        <img
                          src={admin.avatarUrl}
                          alt={admin.fullName}
                          className="w-9 h-9 rounded-full border border-slate-700"
                        />
                        <div>
                          <div className="font-bold text-slate-100 flex items-center space-x-2">
                            <span>{admin.fullName || 'Unnamed Admin'}</span>
                            {isSelf && (
                              <span className="text-[10px] px-2 py-0.5 rounded-full bg-purple-500/20 text-purple-200 border border-purple-500/30 font-mono">
                                YOU
                              </span>
                            )}
                            {admin.adminRole === 'super_admin' && (
                              <Crown className="w-3.5 h-3.5 text-amber-400" />
                            )}
                          </div>
                          <div className="text-[11px] text-slate-500">
                            {admin.email || admin.phone || admin.id}
                          </div>
                        </div>
                      </div>
                    </td>
                    <td className="px-4 py-3">
                      <span
                        className={`text-[10px] px-2.5 py-1 rounded-full border font-mono uppercase ${ROLE_BADGE[admin.adminRole]}`}
                      >
                        {roleLabel(admin.adminRole)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-slate-300">{lastSeen}</td>
                    <td className="px-4 py-3 text-right">
                      <div className="flex items-center justify-end space-x-2">
                        <button
                          disabled={isSelf}
                          onClick={() =>
                            setRoleEditor({
                              admin,
                              selectedRole: admin.adminRole,
                            })
                          }
                          className="px-2.5 py-1.5 rounded-lg bg-slate-900 border border-slate-700 hover:border-slate-500 text-slate-200 text-[11px] font-bold flex items-center space-x-1 disabled:opacity-40 disabled:cursor-not-allowed"
                          title={isSelf ? 'You cannot change your own role' : 'Change scoped role'}
                        >
                          <UserCog className="w-3.5 h-3.5" />
                          <span>Role</span>
                        </button>
                        <button
                          disabled={isSelf}
                          onClick={() =>
                            setDemoteEditor({
                              admin,
                              fallbackRole: 'passenger',
                            })
                          }
                          className="px-2.5 py-1.5 rounded-lg bg-red-500/10 border border-red-500/40 hover:bg-red-500/20 text-red-200 text-[11px] font-bold flex items-center space-x-1 disabled:opacity-40 disabled:cursor-not-allowed"
                          title={isSelf ? 'You cannot demote yourself' : 'Revoke admin access'}
                        >
                          <ArrowDownCircle className="w-3.5 h-3.5" />
                          <span>Demote</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Role editor dialog */}
      {roleEditor && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setRoleEditor(null)}
        >
          <div
            className="w-full max-w-md glass-panel border border-slate-800 rounded-2xl p-6 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div>
              <h3 className="text-sm font-bold text-white">
                Change scoped role
              </h3>
              <p className="text-[11px] text-slate-400 mt-1">
                {roleEditor.admin.fullName} · {roleEditor.admin.email || roleEditor.admin.id}
              </p>
            </div>
            <div className="space-y-2">
              {(Object.keys(ROLE_DESCRIPTIONS) as AdminRole[]).map((role) => (
                <label
                  key={role}
                  className={`flex items-start space-x-3 p-3 rounded-xl border cursor-pointer transition ${
                    roleEditor.selectedRole === role
                      ? 'bg-slate-900 border-slate-200'
                      : 'bg-slate-900/40 border-slate-800 hover:border-slate-700'
                  }`}
                >
                  <input
                    type="radio"
                    name="admin-role"
                    className="mt-1"
                    checked={roleEditor.selectedRole === role}
                    onChange={() =>
                      setRoleEditor({ ...roleEditor, selectedRole: role })
                    }
                  />
                  <div>
                    <div className="flex items-center space-x-2">
                      <span className={`text-[10px] px-2 py-0.5 rounded-full border font-mono uppercase ${ROLE_BADGE[role]}`}>
                        {roleLabel(role)}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-400 mt-1">
                      {ROLE_DESCRIPTIONS[role]}
                    </p>
                  </div>
                </label>
              ))}
            </div>
            {!roleEditor.admin.id && null}
            <div className="flex items-center justify-end space-x-2 pt-2">
              <button
                onClick={() => setRoleEditor(null)}
                className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
              >
                Cancel
              </button>
              <button
                onClick={() => handleAssignRole(roleEditor.admin, roleEditor.selectedRole)}
                disabled={
                  pendingAction === `role:${roleEditor.admin.id}` ||
                  roleEditor.admin.adminRole === roleEditor.selectedRole
                }
                className="px-3 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
              >
                {pendingAction === `role:${roleEditor.admin.id}` ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Check className="w-4 h-4" />
                )}
                <span>Apply</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Demote dialog */}
      {demoteEditor && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setDemoteEditor(null)}
        >
          <div
            className="w-full max-w-md glass-panel border border-red-500/40 rounded-2xl p-6 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="flex items-start space-x-3">
              <AlertTriangle className="w-6 h-6 text-red-300 shrink-0 mt-0.5" />
              <div>
                <h3 className="text-sm font-bold text-white">
                  Revoke admin access
                </h3>
                <p className="text-[11px] text-slate-400 mt-1">
                  {demoteEditor.admin.fullName} ({demoteEditor.admin.email || demoteEditor.admin.id})
                  will lose console access immediately. The action is audit-logged.
                </p>
              </div>
            </div>
            <div>
              <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
                Restore base role
              </label>
              <div className="grid grid-cols-2 gap-2">
                {(['passenger', 'driver'] as const).map((fallback) => (
                  <button
                    key={fallback}
                    onClick={() =>
                      setDemoteEditor({ ...demoteEditor, fallbackRole: fallback })
                    }
                    className={`px-3 py-2.5 rounded-xl border text-xs font-bold capitalize ${
                      demoteEditor.fallbackRole === fallback
                        ? 'bg-slate-100 text-slate-950 border-slate-100'
                        : 'bg-slate-900 border-slate-700 text-slate-300 hover:border-slate-500'
                    }`}
                  >
                    {fallback}
                  </button>
                ))}
              </div>
              <p className="text-[10px] text-slate-500 mt-2">
                Choose <span className="font-mono">driver</span> only if the profile was originally
                a driver. New passenger accounts cannot be downgraded to administrative roles
                unless this super admin re-promotes them.
              </p>
            </div>
            <div className="flex items-center justify-end space-x-2 pt-2">
              <button
                onClick={() => setDemoteEditor(null)}
                className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
              >
                Cancel
              </button>
              <button
                onClick={handleDemote}
                disabled={pendingAction === `demote:${demoteEditor.admin.id}`}
                className="px-3 py-2 rounded-xl bg-red-500 hover:bg-red-400 text-white font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
              >
                {pendingAction === `demote:${demoteEditor.admin.id}` ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <ArrowDownCircle className="w-4 h-4" />
                )}
                <span>Revoke Access</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Promote dialog */}
      {promoteOpen && (
        <div
          className="fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center p-4"
          onClick={() => setPromoteOpen(false)}
        >
          <div
            className="w-full max-w-lg glass-panel border border-slate-800 rounded-2xl p-6 space-y-4"
            onClick={(e) => e.stopPropagation()}
          >
            <div>
              <h3 className="text-sm font-bold text-white flex items-center space-x-2">
                <UserPlus className="w-4 h-4 text-purple-300" />
                <span>Promote a User</span>
              </h3>
              <p className="text-[11px] text-slate-400 mt-1">
                Search any driver or passenger and assign them a console role. They remain
                in their original role group until demoted.
              </p>
            </div>

            <div className="relative">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
              <input
                value={promoteSearch}
                onChange={(e) => setPromoteSearch(e.target.value)}
                placeholder="Search by name, email or ID..."
                className="w-full pl-9 pr-3 py-2.5 rounded-xl bg-slate-900 border border-slate-800 text-slate-100 text-sm placeholder-slate-500 focus:outline-none focus:border-slate-400"
              />
            </div>
            <div className="max-h-56 overflow-y-auto rounded-xl border border-slate-800 divide-y divide-slate-800">
              {filteredCandidates.length === 0 ? (
                <div className="p-4 text-xs text-slate-500 text-center">
                  No matching drivers or passengers.
                </div>
              ) : (
                filteredCandidates.map((cand) => (
                  <label
                    key={`${cand.sourceRole}:${cand.id}`}
                    className={`flex items-center justify-between p-3 cursor-pointer hover:bg-slate-900/60 ${
                      promoteTargetId === cand.id ? 'bg-slate-900' : ''
                    }`}
                  >
                    <div className="flex items-center space-x-3">
                      <input
                        type="radio"
                        name="promote-target"
                        checked={promoteTargetId === cand.id}
                        onChange={() => setPromoteTargetId(cand.id)}
                      />
                      <div>
                        <div className="text-xs font-bold text-slate-100">
                          {cand.fullName || 'Unnamed'}
                        </div>
                        <div className="text-[11px] text-slate-500">
                          {cand.email || cand.id}{' '}
                          <span className="ml-2 text-[10px] uppercase font-mono text-slate-400">
                            {cand.sourceRole}
                          </span>
                        </div>
                      </div>
                    </div>
                  </label>
                ))
              )}
            </div>

            <div>
              <label className="text-[11px] uppercase tracking-wider text-slate-400 font-bold block mb-2">
                Scoped role
              </label>
              <div className="grid grid-cols-2 gap-2">
                {(Object.keys(ROLE_DESCRIPTIONS) as AdminRole[]).map((role) => (
                  <button
                    key={role}
                    onClick={() => setPromoteRole(role)}
                    className={`px-3 py-2 rounded-xl border text-[11px] font-bold ${
                      promoteRole === role
                        ? 'bg-slate-100 text-slate-950 border-slate-100'
                        : 'bg-slate-900 border-slate-700 text-slate-300 hover:border-slate-500'
                    }`}
                  >
                    {roleLabel(role)}
                  </button>
                ))}
              </div>
            </div>

            <div className="flex items-center justify-end space-x-2 pt-2">
              <button
                onClick={() => setPromoteOpen(false)}
                className="px-3 py-2 rounded-xl border border-slate-700 text-slate-300 hover:text-white text-xs font-bold"
              >
                Cancel
              </button>
              <button
                onClick={handlePromote}
                disabled={!promoteTargetId || !!pendingAction}
                className="px-3 py-2 rounded-xl bg-slate-100 hover:bg-white text-slate-950 font-bold text-xs flex items-center space-x-2 disabled:opacity-40"
              >
                {pendingAction?.startsWith('promote:') ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <Check className="w-4 h-4" />
                )}
                <span>Promote</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
