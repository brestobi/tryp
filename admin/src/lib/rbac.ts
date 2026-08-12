import type { AdminRole } from '../types/admin';

export type Permission =
  | 'dashboard:read'
  | 'kyc:read'
  | 'kyc:write'
  | 'fleet:read'
  | 'fleet:write'
  | 'fares:read'
  | 'fares:write'
  | 'finance:read'
  | 'finance:write'
  | 'users:read'
  | 'users:write'
  | 'admin:manage'
  | 'audit:read'
  | 'broadcast:write'
  | 'statements:read';

const ALL_PERMISSIONS: Permission[] = [
  'dashboard:read',
  'kyc:read',
  'kyc:write',
  'fleet:read',
  'fleet:write',
  'fares:read',
  'fares:write',
  'finance:read',
  'finance:write',
  'users:read',
  'users:write',
  'admin:manage',
  'audit:read',
  'broadcast:write',
  'statements:read',
];

export const ROLE_PERMISSIONS: Record<AdminRole, readonly Permission[]> = {
  super_admin: ALL_PERMISSIONS,
  kyc_officer: [
    'dashboard:read',
    'kyc:read',
    'kyc:write',
    'users:read',
    'audit:read',
  ],
  fleet_dispatcher: [
    'dashboard:read',
    'fleet:read',
    'fleet:write',
    'users:read',
    'audit:read',
  ],
  finance_manager: [
    'dashboard:read',
    'fares:read',
    'finance:read',
    'finance:write',
    'users:read',
    'audit:read',
    'statements:read',
  ],
};

/**
 * Legacy admin accounts predate granular roles and retain full access until
 * an administrator assigns them a specific admin_role in their profile.
 */
export function normalizeAdminRole(role: string | null | undefined, adminRole?: string | null): AdminRole | null {
  // A scoped admin_role is meaningful only on an admin base profile. This
  // prevents a passenger/driver profile value from becoming console access.
  if (role !== 'admin' && role !== 'super_admin') return null;
  if (adminRole && adminRole in ROLE_PERMISSIONS) {
    return adminRole as AdminRole;
  }
  if (role === 'admin' || role === 'super_admin') {
    return 'super_admin';
  }
  return null;
}

export function hasPermission(role: AdminRole | null | undefined, permission: Permission): boolean {
  if (!role) return false;
  return ROLE_PERMISSIONS[role].includes(permission);
}

export function roleLabel(role: AdminRole): string {
  return {
    super_admin: 'Super Admin',
    kyc_officer: 'KYC Officer',
    fleet_dispatcher: 'Fleet Dispatcher',
    finance_manager: 'Finance Manager',
  }[role];
}
