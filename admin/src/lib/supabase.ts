import { createClient } from '@supabase/supabase-js';
import type {
  DriverProfile,
  PassengerProfile,
  Ride,
  FareSchema,
  PayoutSettlement,
  AdminAuditLog
} from '../types/admin';

// Initialize Supabase Client if env vars exist, otherwise fallback gracefully
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'https://demo.supabase.co';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY || 'demo-key';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// --- INITIAL MOCK / DATA SEED FOR TRYP SOUTH AFRICA ---

export const INITIAL_DRIVERS: DriverProfile[] = [
  {
    id: 'drv-001',
    fullName: 'David Khumalo',
    email: 'david.khumalo@tryp.co.za',
    phone: '+27 82 555 0192',
    saIdNumber: '8801015800081',
    licenseNumber: 'DL982341-ZA',
    driverStatus: 'pending',
    vehicleMake: 'Toyota',
    vehicleModel: 'Corolla Quest',
    vehicleYear: 2022,
    vehicleColor: 'Silver Metallic',
    vehiclePlate: 'GP 88 YZ GP',
    operatingCity: 'Johannesburg',
    bankName: 'First National Bank (FNB)',
    bankAccount: '62810934910',
    bankBranch: '250655',
    bankHolder: 'D. Khumalo',
    walletBalance: 1450.00,
    rating: 4.85,
    isOnline: true,
    currentLat: -26.1076,
    currentLng: 28.0567, // Sandton
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&q=80&w=200',
    joinedAt: '2026-07-15T09:30:00Z',
    totalTrips: 128,
    documents: [
      {
        id: 'doc-101',
        driverId: 'drv-001',
        docType: 'prdp_license',
        title: 'Professional Driving Permit (PrDP)',
        fileUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=1000',
        status: 'pending',
        uploadedAt: '2026-07-28T14:20:00Z',
        expiresAt: '2027-11-30'
      },
      {
        id: 'doc-102',
        driverId: 'drv-001',
        docType: 'vehicle_registration',
        title: 'Vehicle Registration Certificate (RC)',
        fileUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&q=80&w=1000',
        status: 'approved',
        uploadedAt: '2026-07-28T14:22:00Z',
        expiresAt: '2027-05-15'
      },
      {
        id: 'doc-103',
        driverId: 'drv-001',
        docType: 'insurance',
        title: 'Comprehensive Passenger Insurance',
        fileUrl: 'https://images.unsplash.com/photo-1450133064473-71024230f91b?auto=format&fit=crop&q=80&w=1000',
        status: 'flagged',
        uploadedAt: '2026-07-28T14:25:00Z',
        expiresAt: '2026-08-01',
        issueNotes: 'Policy document image blurry; expiration date obscured.'
      },
      {
        id: 'doc-104',
        driverId: 'drv-001',
        docType: 'roadworthiness',
        title: 'DEKRA Certificate of Roadworthiness',
        fileUrl: 'https://images.unsplash.com/photo-1563986768609-322da13575f3?auto=format&fit=crop&q=80&w=1000',
        status: 'approved',
        uploadedAt: '2026-07-28T14:27:00Z',
        expiresAt: '2027-01-20'
      }
    ]
  },
  {
    id: 'drv-002',
    fullName: 'Sipho Mokoena',
    email: 'sipho.m@tryp.co.za',
    phone: '+27 73 992 4410',
    saIdNumber: '9204125433085',
    licenseNumber: 'DL441029-ZA',
    driverStatus: 'approved',
    vehicleMake: 'Volkswagen',
    vehicleModel: 'Polo Sedan',
    vehicleYear: 2023,
    vehicleColor: 'Deep Black',
    vehiclePlate: 'ND 491 204',
    operatingCity: 'Durban',
    bankName: 'Capitec Bank',
    bankAccount: '1490284710',
    bankBranch: '470010',
    bankHolder: 'S. Mokoena',
    walletBalance: 2890.50,
    rating: 4.94,
    isOnline: true,
    currentLat: -26.1450,
    currentLng: 28.0440, // Rosebank
    avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=200',
    joinedAt: '2026-05-10T11:00:00Z',
    totalTrips: 452,
    documents: [
      {
        id: 'doc-201',
        driverId: 'drv-002',
        docType: 'prdp_license',
        title: 'Professional Driving Permit (PrDP)',
        fileUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=1000',
        status: 'approved',
        uploadedAt: '2026-05-10T11:10:00Z',
        expiresAt: '2028-04-10'
      }
    ]
  },
  {
    id: 'drv-003',
    fullName: 'Keanu Van Der Merwe',
    email: 'keanu.vdm@tryp.co.za',
    phone: '+27 84 102 9923',
    saIdNumber: '9508195129088',
    licenseNumber: 'DL771203-ZA',
    driverStatus: 'under_review',
    vehicleMake: 'Hyundai',
    vehicleModel: 'Grand i10',
    vehicleYear: 2021,
    vehicleColor: 'Polar White',
    vehiclePlate: 'CA 991-824',
    operatingCity: 'Cape Town',
    bankName: 'Standard Bank',
    bankAccount: '002938471',
    bankBranch: '051001',
    bankHolder: 'K. Van Der Merwe',
    walletBalance: 820.00,
    rating: 4.70,
    isOnline: false,
    currentLat: -33.9249,
    currentLng: 18.4241, // Cape Town CBD
    avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&q=80&w=200',
    joinedAt: '2026-07-25T16:45:00Z',
    totalTrips: 34,
    documents: [
      {
        id: 'doc-301',
        driverId: 'drv-003',
        docType: 'prdp_license',
        title: 'Professional Driving Permit (PrDP)',
        fileUrl: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&q=80&w=1000',
        status: 'pending',
        uploadedAt: '2026-07-26T08:15:00Z',
        expiresAt: '2027-09-12'
      }
    ]
  },
  {
    id: 'drv-004',
    fullName: 'Nomvula Naidoo',
    email: 'nomvula.naidoo@tryp.co.za',
    phone: '+27 71 883 0021',
    saIdNumber: '9103034920084',
    licenseNumber: 'DL304918-ZA',
    driverStatus: 'approved',
    vehicleMake: 'BMW',
    vehicleModel: '320i Executive',
    vehicleYear: 2024,
    vehicleColor: 'Mineral Grey',
    vehiclePlate: 'TRYP 01 GP',
    operatingCity: 'Johannesburg',
    bankName: 'Absa Bank',
    bankAccount: '4091823741',
    bankBranch: '632005',
    bankHolder: 'N. Naidoo',
    walletBalance: 5410.00,
    rating: 4.98,
    isOnline: true,
    currentLat: -26.1952,
    currentLng: 28.0340, // Braamfontein
    avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&q=80&w=200',
    joinedAt: '2026-01-10T10:00:00Z',
    totalTrips: 890,
    documents: []
  }
];

export const INITIAL_PASSENGERS: PassengerProfile[] = [
  {
    id: 'pas-101',
    fullName: 'Sizwe Dlamini',
    email: 'sizwe.dlamini@gmail.com',
    phone: '+27 82 441 9023',
    rating: 4.90,
    walletBalance: 450.00,
    emergencyContactName: 'Thandi Dlamini (Wife)',
    emergencyContactPhone: '+27 82 441 9099',
    totalRides: 42,
    status: 'active',
    joinedAt: '2026-02-14T12:00:00Z',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200'
  },
  {
    id: 'pas-102',
    fullName: 'Melanie Van Zyl',
    email: 'melanie.vz@corp.co.za',
    phone: '+27 76 991 2304',
    rating: 4.82,
    walletBalance: 1200.00,
    emergencyContactName: 'Johan Van Zyl (Brother)',
    emergencyContactPhone: '+27 76 991 2399',
    totalRides: 98,
    status: 'active',
    joinedAt: '2025-11-20T08:30:00Z',
    avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&q=80&w=200'
  },
  {
    id: 'pas-103',
    fullName: 'Brandon Pillay',
    email: 'bpillay@techhub.africa',
    phone: '+27 83 110 4920',
    rating: 4.35,
    walletBalance: 25.00,
    emergencyContactName: 'Devi Pillay (Mother)',
    emergencyContactPhone: '+27 83 110 4900',
    totalRides: 15,
    status: 'suspended',
    joinedAt: '2026-06-01T15:20:00Z',
    avatarUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&q=80&w=200'
  }
];

export const INITIAL_RIDES: Ride[] = [
  {
    id: 'ride-8912',
    passengerId: 'pas-101',
    passengerName: 'Sizwe Dlamini',
    passengerPhone: '+27 82 441 9023',
    driverId: 'drv-001',
    driverName: 'David Khumalo',
    driverPhone: '+27 82 555 0192',
    driverPlate: 'GP 88 YZ GP',
    pickupAddress: 'Sandton City Mall, Sandton Drive',
    destAddress: 'OR Tambo International Airport, Kempton Park',
    pickupLat: -26.1076,
    pickupLng: 28.0567,
    destLat: -26.1367,
    destLng: 28.2411,
    fare: 345.50,
    tier: 'TRYP Comfort',
    status: 'in_trip',
    paymentMethod: 'card',
    paymentStatus: 'paid',
    paymentReference: 'pstk_tx_99812401',
    requestedAt: '2026-07-29T11:15:00Z',
    surgeMultiplier: 1.25,
    distanceKm: 28.4,
    durationMins: 32
  },
  {
    id: 'ride-8913',
    passengerId: 'pas-102',
    passengerName: 'Melanie Van Zyl',
    passengerPhone: '+27 76 991 2304',
    driverId: 'drv-002',
    driverName: 'Sipho Mokoena',
    driverPhone: '+27 73 992 4410',
    driverPlate: 'ND 491 204',
    pickupAddress: 'Rosebank Mall, Oxford Road',
    destAddress: 'Melrose Arch, Corlett Drive',
    pickupLat: -26.1450,
    pickupLng: 28.0440,
    destLat: -26.1340,
    destLng: 28.0670,
    fare: 82.50,
    tier: 'TRYP Go',
    status: 'accepted',
    paymentMethod: 'wallet',
    paymentStatus: 'paid',
    paymentReference: 'wlt_tx_5541029',
    requestedAt: '2026-07-29T11:38:00Z',
    surgeMultiplier: 1.0,
    distanceKm: 4.8,
    durationMins: 11
  },
  {
    id: 'ride-8914',
    passengerId: 'pas-103',
    passengerName: 'Brandon Pillay',
    passengerPhone: '+27 83 110 4920',
    pickupAddress: 'Fourways Mall, William Nicol Dr',
    destAddress: 'Montecasino, Witkoppen Rd',
    pickupLat: -26.0175,
    pickupLng: 28.0061,
    destLat: -26.0245,
    destLng: 28.0125,
    fare: 55.00,
    tier: 'TRYP Go',
    status: 'requested',
    paymentMethod: 'cash',
    paymentStatus: 'pending',
    paymentReference: 'cash_ref_1092',
    requestedAt: '2026-07-29T11:42:00Z',
    surgeMultiplier: 1.1,
    distanceKm: 3.2,
    durationMins: 8
  }
];

export const INITIAL_FARE_SCHEMAS: FareSchema[] = [
  {
    id: 'schema-go',
    tier: 'TRYP Go',
    baseFare: 18.00,
    perKmRate: 6.50,
    minFare: 25.00,
    perMinuteRate: 1.20,
    commissionPercentage: 15.0,
    surgeMultiplier: 1.0,
    updatedAt: '2026-07-20T10:00:00Z'
  },
  {
    id: 'schema-comfort',
    tier: 'TRYP Comfort',
    baseFare: 28.00,
    perKmRate: 9.00,
    minFare: 40.00,
    perMinuteRate: 1.80,
    commissionPercentage: 18.0,
    surgeMultiplier: 1.25,
    updatedAt: '2026-07-20T10:00:00Z'
  },
  {
    id: 'schema-xl',
    tier: 'TRYP XL',
    baseFare: 45.00,
    perKmRate: 12.50,
    minFare: 65.00,
    perMinuteRate: 2.50,
    commissionPercentage: 20.0,
    surgeMultiplier: 1.0,
    updatedAt: '2026-07-20T10:00:00Z'
  },
  {
    id: 'schema-exec',
    tier: 'TRYP Exec',
    baseFare: 60.00,
    perKmRate: 16.00,
    minFare: 90.00,
    perMinuteRate: 3.20,
    commissionPercentage: 22.0,
    surgeMultiplier: 1.0,
    updatedAt: '2026-07-20T10:00:00Z'
  }
];

export const INITIAL_PAYOUTS: PayoutSettlement[] = [
  {
    id: 'pay-701',
    driverId: 'drv-002',
    driverName: 'Sipho Mokoena',
    bankName: 'Capitec Bank',
    accountNumber: '1490284710',
    branchCode: '470010',
    accountHolder: 'S. Mokoena',
    grossEarnings: 4200.00,
    platformFee: 630.00,
    netPayout: 3570.00,
    status: 'verified',
    period: '2026-W30 (21 Jul - 27 Jul)',
    updatedAt: '2026-07-28T09:00:00Z'
  },
  {
    id: 'pay-702',
    driverId: 'drv-004',
    driverName: 'Nomvula Naidoo',
    bankName: 'Absa Bank',
    accountNumber: '4091823741',
    branchCode: '632005',
    accountHolder: 'N. Naidoo',
    grossEarnings: 6850.00,
    platformFee: 1233.00,
    netPayout: 5617.00,
    status: 'verified',
    period: '2026-W30 (21 Jul - 27 Jul)',
    updatedAt: '2026-07-28T09:05:00Z'
  },
  {
    id: 'pay-703',
    driverId: 'drv-001',
    driverName: 'David Khumalo',
    bankName: 'First National Bank (FNB)',
    accountNumber: '62810934910',
    branchCode: '250655',
    accountHolder: 'D. Khumalo',
    grossEarnings: 1850.00,
    platformFee: 277.50,
    netPayout: 1572.50,
    status: 'pending',
    period: '2026-W30 (21 Jul - 27 Jul)',
    updatedAt: '2026-07-28T09:10:00Z'
  }
];

export const INITIAL_AUDIT_LOGS: AdminAuditLog[] = [
  {
    id: 'log-901',
    adminRole: 'kyc_officer',
    adminName: 'Sarah Jenkins',
    action: 'FLAG_DOCUMENT',
    targetId: 'doc-103',
    targetType: 'driver_document',
    details: 'Flagged Insurance Policy for driver David Khumalo: Image blurry and expiration unreadable.',
    ipAddress: '102.165.12.44',
    timestamp: '2026-07-29T10:14:22Z'
  },
  {
    id: 'log-902',
    adminRole: 'super_admin',
    adminName: 'Chief Admin',
    action: 'UPDATE_FARE_SCHEMA',
    targetId: 'schema-comfort',
    targetType: 'fare_schema',
    details: 'Updated TRYP Comfort surge multiplier from 1.0x to 1.25x for Sandton demand peak.',
    ipAddress: '102.165.12.1',
    timestamp: '2026-07-29T09:30:11Z'
  },
  {
    id: 'log-903',
    adminRole: 'finance_manager',
    adminName: 'Mark Thompson',
    action: 'VERIFY_PAYOUT',
    targetId: 'pay-702',
    targetType: 'payout_settlement',
    details: 'Verified weekly bank payout of R5,617.00 to Nomvula Naidoo (Absa ****3741).',
    ipAddress: '102.165.12.88',
    timestamp: '2026-07-28T16:45:00Z'
  }
];
