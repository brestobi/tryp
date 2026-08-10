export type AdminRole = 'super_admin' | 'kyc_officer' | 'fleet_dispatcher' | 'finance_manager';

export type DriverStatus = 'pending' | 'under_review' | 'approved' | 'rejected' | 'flagged';
export type DocumentType = 'prdp_license' | 'vehicle_registration' | 'insurance' | 'roadworthiness' | 'selfie';
export type DocumentStatus = 'pending' | 'approved' | 'rejected' | 'flagged';

export interface DriverDocument {
  id: string;
  driverId: string;
  docType: DocumentType;
  title: string;
  fileUrl: string;
  status: DocumentStatus;
  uploadedAt: string;
  expiresAt: string;
  issueNotes?: string;
}

export interface DriverProfile {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  saIdNumber: string;
  licenseNumber: string;
  driverStatus: DriverStatus;
  vehicleMake: string;
  vehicleModel: string;
  vehicleYear: number;
  vehicleColor: string;
  vehiclePlate: string;
  operatingCity: string;
  bankName: string;
  bankAccount: string;
  bankBranch: string;
  bankHolder: string;
  walletBalance: number;
  rating: number;
  isOnline: boolean;
  currentLat: number;
  currentLng: number;
  documents: DriverDocument[];
  joinedAt: string;
  totalTrips: number;
  avatarUrl: string;
}

export type PassengerVerificationStatus = 'unverified' | 'pending' | 'under_review' | 'approved' | 'rejected';

export interface DriverWallet {
  driverId: string;
  driverName: string;
  cashCollected: number;
  onlineHeld: number;
  cashPlatformFeeOwed: number;
  platformFeesTotal: number;
  updatedAt: string;
}

export interface PassengerProfile {
  id: string;
  fullName: string;
  email: string;
  phone: string;
  verificationStatus: PassengerVerificationStatus;
  rating: number;
  walletBalance: number;
  emergencyContactName: string;
  emergencyContactPhone: string;
  totalRides: number;
  status: 'active' | 'suspended';
  joinedAt: string;
  avatarUrl: string;
}

export interface PassengerVerification {
  id: string;
  passengerId: string;
  passengerName: string;
  passengerEmail: string;
  idDocumentUrl: string;
  selfieUrl: string;
  status: PassengerVerificationStatus;
  reviewNotes?: string;
  submittedAt: string;
  reviewedAt?: string;
}

export type RideStatus = 'requested' | 'accepted' | 'arrived' | 'in_trip' | 'completed' | 'cancelled';

export interface Ride {
  id: string;
  rideReference: string;
  passengerId: string;
  passengerName: string;
  passengerPhone: string;
  driverId?: string;
  driverName?: string;
  driverPhone?: string;
  driverPlate?: string;
  pickupAddress: string;
  destAddress: string;
  pickupLat: number;
  pickupLng: number;
  destLat: number;
  destLng: number;
  fare: number;
  tier: 'TRYP Go' | 'TRYP Comfort' | 'TRYP XL' | 'TRYP Exec';
  status: RideStatus;
  paymentMethod: 'card' | 'wallet' | 'cash';
  paymentStatus: 'paid' | 'pending' | 'failed';
  paymentReference: string;
  requestedAt: string;
  surgeMultiplier: number;
  distanceKm: number;
  durationMins: number;
}

export interface FareSchema {
  id: string;
  tier: 'TRYP Go' | 'TRYP Comfort' | 'TRYP XL' | 'TRYP Exec';
  baseFare: number;
  perKmRate: number;
  minFare: number;
  perMinuteRate: number;
  commissionPercentage: number;
  surgeMultiplier: number;
  updatedAt: string;
}

export interface PayoutSettlement {
  id: string;
  driverId: string;
  driverName: string;
  bankName: string;
  accountNumber: string;
  branchCode: string;
  accountHolder: string;
  grossEarnings: number;
  platformFee: number;
  netPayout: number;
  status: 'pending' | 'verified' | 'paid' | 'flagged';
  period: string;
  updatedAt: string;
}

export interface AdminAuditLog {
  id: string;
  adminRole: AdminRole;
  adminName: string;
  action: string;
  targetId: string;
  targetType: string;
  details: string;
  ipAddress: string;
  timestamp: string;
}
