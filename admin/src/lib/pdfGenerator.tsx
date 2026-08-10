/**
 * TRYP Driver Statement PDF Generator
 * Uses @react-pdf/renderer to create branded PDF statements
 */

import React from 'react';
import {
  Document,
  Page,
  View,
  Text,
  StyleSheet,
} from '@react-pdf/renderer';
import type { DriverStatementSummary } from '../types/admin';

// TRYP Green Brand Colors
const TRYP_COLORS = {
  primary: '#00A651', // TRYP Green
  primaryDark: '#008C44',
  secondary: '#000000', // Black
  accent: '#333333',
  white: '#FFFFFF',
  lightGray: '#F5F5F5',
  borderGray: '#E0E0E0',
  textGray: '#666666',
  success: '#28A745',
  warning: '#FFC107',
};

// Create styles
const styles = StyleSheet.create({
  page: {
    padding: 40,
    fontFamily: 'Helvetica',
    backgroundColor: TRYP_COLORS.white,
  },
  
  // Header styles
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 30,
    paddingBottom: 20,
    borderBottomWidth: 2,
    borderBottomColor: TRYP_COLORS.primary,
  },
  logoSection: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  logoPlaceholder: {
    width: 50,
    height: 50,
    backgroundColor: TRYP_COLORS.primary,
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  logoText: {
    color: TRYP_COLORS.white,
    fontSize: 18,
    fontWeight: 'bold',
  },
  brandName: {
    fontSize: 24,
    fontWeight: 'bold',
    color: TRYP_COLORS.secondary,
  },
  brandTagline: {
    fontSize: 10,
    color: TRYP_COLORS.textGray,
    marginTop: 2,
  },
  headerRight: {
    alignItems: 'flex-end',
  },
  documentTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: TRYP_COLORS.primary,
    marginBottom: 4,
  },
  documentDate: {
    fontSize: 10,
    color: TRYP_COLORS.textGray,
  },
  
  // Driver Info section
  driverInfoSection: {
    backgroundColor: TRYP_COLORS.lightGray,
    borderRadius: 8,
    padding: 16,
    marginBottom: 24,
  },
  driverInfoTitle: {
    fontSize: 12,
    fontWeight: 'bold',
    color: TRYP_COLORS.secondary,
    marginBottom: 12,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  driverInfoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  driverInfoItem: {
    width: '50%',
    marginBottom: 8,
  },
  driverInfoLabel: {
    fontSize: 9,
    color: TRYP_COLORS.textGray,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
  },
  driverInfoValue: {
    fontSize: 11,
    color: TRYP_COLORS.secondary,
    fontWeight: 'bold',
    marginTop: 2,
  },
  
  // Period section
  periodSection: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 24,
    paddingVertical: 12,
    borderTopWidth: 1,
    borderBottomWidth: 1,
    borderColor: TRYP_COLORS.borderGray,
  },
  periodItem: {
    alignItems: 'center',
  },
  periodLabel: {
    fontSize: 9,
    color: TRYP_COLORS.textGray,
    textTransform: 'uppercase',
  },
  periodValue: {
    fontSize: 12,
    color: TRYP_COLORS.secondary,
    fontWeight: 'bold',
    marginTop: 4,
  },
  
  // Summary cards
  summaryCards: {
    flexDirection: 'row',
    marginBottom: 24,
    gap: 12,
  },
  summaryCard: {
    flex: 1,
    backgroundColor: TRYP_COLORS.lightGray,
    borderRadius: 8,
    padding: 12,
    alignItems: 'center',
  },
  summaryCardGreen: {
    backgroundColor: TRYP_COLORS.primary,
  },
  summaryCardValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: TRYP_COLORS.secondary,
    marginBottom: 4,
  },
  summaryCardValueWhite: {
    color: TRYP_COLORS.white,
  },
  summaryCardLabel: {
    fontSize: 9,
    color: TRYP_COLORS.textGray,
    textTransform: 'uppercase',
    textAlign: 'center',
  },
  summaryCardLabelWhite: {
    color: TRYP_COLORS.white,
  },
  
  // Section headers
  sectionHeader: {
    fontSize: 14,
    fontWeight: 'bold',
    color: TRYP_COLORS.secondary,
    marginBottom: 12,
    paddingBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: TRYP_COLORS.primary,
  },
  
  // Earnings breakdown
  earningsBreakdown: {
    marginBottom: 24,
  },
  earningsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: TRYP_COLORS.borderGray,
  },
  earningsLabel: {
    fontSize: 11,
    color: TRYP_COLORS.textGray,
  },
  earningsValue: {
    fontSize: 11,
    fontWeight: 'bold',
    color: TRYP_COLORS.secondary,
  },
  earningsValueGreen: {
    color: TRYP_COLORS.primary,
  },
  earningsTotalRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingTop: 12,
    marginTop: 8,
    borderTopWidth: 2,
    borderTopColor: TRYP_COLORS.primary,
  },
  earningsTotalLabel: {
    fontSize: 12,
    fontWeight: 'bold',
    color: TRYP_COLORS.secondary,
  },
  earningsTotalValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: TRYP_COLORS.primary,
  },
  
  // Stats grid
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginBottom: 24,
    gap: 8,
  },
  statItem: {
    width: '33.33%',
    backgroundColor: TRYP_COLORS.lightGray,
    borderRadius: 6,
    padding: 10,
    alignItems: 'center',
  },
  statValue: {
    fontSize: 14,
    fontWeight: 'bold',
    color: TRYP_COLORS.primary,
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 8,
    color: TRYP_COLORS.textGray,
    textTransform: 'uppercase',
    textAlign: 'center',
  },
  
  // Trip table
  tripTable: {
    marginBottom: 24,
  },
  tripTableHeader: {
    flexDirection: 'row',
    backgroundColor: TRYP_COLORS.secondary,
    paddingVertical: 8,
    paddingHorizontal: 8,
    borderRadius: 4,
    marginBottom: 4,
  },
  tripTableRow: {
    flexDirection: 'row',
    paddingVertical: 8,
    paddingHorizontal: 8,
    borderBottomWidth: 1,
    borderBottomColor: TRYP_COLORS.borderGray,
  },
  tripTableRowAlt: {
    backgroundColor: TRYP_COLORS.lightGray,
  },
  tripTableCell: {
    fontSize: 9,
    color: TRYP_COLORS.secondary,
  },
  tripTableCellHeader: {
    fontSize: 8,
    fontWeight: 'bold',
    color: TRYP_COLORS.white,
    textTransform: 'uppercase',
  },
  colRef: { width: '12%' },
  colDate: { width: '15%' },
  colPickup: { width: '20%' },
  colDrop: { width: '20%' },
  colFare: { width: '10%', textAlign: 'right' },
  colMethod: { width: '10%', textAlign: 'center' },
  colNet: { width: '13%', textAlign: 'right' },
  
  // Payout schedule
  payoutSchedule: {
    backgroundColor: TRYP_COLORS.primary,
    borderRadius: 8,
    padding: 16,
    marginBottom: 24,
  },
  payoutScheduleTitle: {
    fontSize: 12,
    fontWeight: 'bold',
    color: TRYP_COLORS.white,
    marginBottom: 8,
  },
  payoutScheduleText: {
    fontSize: 10,
    color: TRYP_COLORS.white,
    marginBottom: 4,
  },
  
  // Footer
  footer: {
    marginTop: 40,
    paddingTop: 20,
    borderTopWidth: 1,
    borderTopColor: TRYP_COLORS.borderGray,
  },
  footerText: {
    fontSize: 9,
    color: TRYP_COLORS.textGray,
    textAlign: 'center',
    marginBottom: 4,
  },
  footerSupport: {
    fontSize: 9,
    color: TRYP_COLORS.primary,
    textAlign: 'center',
    fontWeight: 'bold',
  },
});

// Statement Document Component
const StatementDocument: React.FC<{ statement: DriverStatementSummary }> = ({ statement }) => {
  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('en-ZA', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const formatCurrency = (amount: number) => {
    return `R${amount.toLocaleString('en-ZA', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  };

  const formatDateTime = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString('en-ZA', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  return (
    <Document>
      <Page size="A4" style={styles.page}>
        {/* Header */}
        <View style={styles.header}>
          <View style={styles.logoSection}>
            <View style={styles.logoPlaceholder}>
              <Text style={styles.logoText}>T</Text>
            </View>
            <View>
              <Text style={styles.brandName}>TRYP</Text>
              <Text style={styles.brandTagline}>Driver Partner Platform</Text>
            </View>
          </View>
          <View style={styles.headerRight}>
            <Text style={styles.documentTitle}>WEEKLY EARNINGS STATEMENT</Text>
            <Text style={styles.documentDate}>
              Generated: {formatDate(new Date().toISOString())}
            </Text>
          </View>
        </View>

        {/* Driver Information */}
        <View style={styles.driverInfoSection}>
          <Text style={styles.driverInfoTitle}>Driver Information</Text>
          <View style={styles.driverInfoGrid}>
            <View style={styles.driverInfoItem}>
              <Text style={styles.driverInfoLabel}>Full Name</Text>
              <Text style={styles.driverInfoValue}>{statement.driverName}</Text>
            </View>
            <View style={styles.driverInfoItem}>
              <Text style={styles.driverInfoLabel}>Email</Text>
              <Text style={styles.driverInfoValue}>{statement.driverEmail}</Text>
            </View>
            <View style={styles.driverInfoItem}>
              <Text style={styles.driverInfoLabel}>Phone</Text>
              <Text style={styles.driverInfoValue}>{statement.driverPhone}</Text>
            </View>
            <View style={styles.driverInfoItem}>
              <Text style={styles.driverInfoLabel}>Vehicle Plate</Text>
              <Text style={styles.driverInfoValue}>{statement.vehiclePlate}</Text>
            </View>
            <View style={styles.driverInfoItem}>
              <Text style={styles.driverInfoLabel}>Driver Rating</Text>
              <Text style={styles.driverInfoValue}>⭐ {statement.rating.toFixed(1)}</Text>
            </View>
            <View style={styles.driverInfoItem}>
              <Text style={styles.driverInfoLabel}>Bank</Text>
              <Text style={styles.driverInfoValue}>{statement.bankName || 'Not configured'}</Text>
            </View>
          </View>
        </View>

        {/* Statement Period */}
        <View style={styles.periodSection}>
          <View style={styles.periodItem}>
            <Text style={styles.periodLabel}>Statement Period Start</Text>
            <Text style={styles.periodValue}>{formatDate(statement.periodStart)}</Text>
          </View>
          <View style={styles.periodItem}>
            <Text style={styles.periodLabel}>Statement Period End</Text>
            <Text style={styles.periodValue}>{formatDate(statement.periodEnd)}</Text>
          </View>
          <View style={styles.periodItem}>
            <Text style={styles.periodLabel}>Total Days</Text>
            <Text style={styles.periodValue}>
              {Math.ceil(
                (new Date(statement.periodEnd).getTime() - new Date(statement.periodStart).getTime()) /
                  (1000 * 60 * 60 * 24)
              )} days
            </Text>
          </View>
        </View>

        {/* Summary Cards */}
        <View style={styles.summaryCards}>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryCardValue}>{statement.totalTrips}</Text>
            <Text style={styles.summaryCardLabel}>Total Trips</Text>
          </View>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryCardValue}>{statement.cashTrips}</Text>
            <Text style={styles.summaryCardLabel}>Cash Trips</Text>
          </View>
          <View style={styles.summaryCard}>
            <Text style={styles.summaryCardValue}>{statement.onlineTrips}</Text>
            <Text style={styles.summaryCardLabel}>Card Trips</Text>
          </View>
          <View style={[styles.summaryCard, styles.summaryCardGreen]}>
            <Text style={[styles.summaryCardValue, styles.summaryCardValueWhite]}>
              {formatCurrency(statement.totalNetEarnings)}
            </Text>
            <Text style={[styles.summaryCardLabel, styles.summaryCardLabelWhite]}>
              Net Earnings
            </Text>
          </View>
        </View>

        {/* Earnings Breakdown */}
        <View style={styles.earningsBreakdown}>
          <Text style={styles.sectionHeader}>Earnings Breakdown</Text>
          
          <View style={styles.earningsRow}>
            <Text style={styles.earningsLabel}>Cash Collected (from passengers)</Text>
            <Text style={styles.earningsValue}>{formatCurrency(statement.cashCollected)}</Text>
          </View>
          <View style={styles.earningsRow}>
            <Text style={styles.earningsLabel}>Cash Platform Fees Owed</Text>
            <Text style={styles.earningsValue}>-{formatCurrency(statement.cashFeesOwed)}</Text>
          </View>
          <View style={styles.earningsRow}>
            <Text style={styles.earningsLabel}>Online/Card Payments (held by TRYP)</Text>
            <Text style={styles.earningsValue}>{formatCurrency(statement.onlineEarnings)}</Text>
          </View>
          <View style={styles.earningsRow}>
            <Text style={styles.earningsLabel}>Online Platform Fees Withheld</Text>
            <Text style={styles.earningsValue}>-{formatCurrency(statement.onlineFeesWithheld)}</Text>
          </View>
          
          <View style={styles.earningsTotalRow}>
            <Text style={styles.earningsTotalLabel}>Total Gross Earnings</Text>
            <Text style={styles.earningsTotalValue}>{formatCurrency(statement.totalGross)}</Text>
          </View>
          <View style={styles.earningsTotalRow}>
            <Text style={styles.earningsTotalLabel}>Total Platform Fees</Text>
            <Text style={styles.earningsTotalValue}>-{formatCurrency(statement.totalPlatformFees)}</Text>
          </View>
          <View style={styles.earningsTotalRow}>
            <Text style={styles.earningsTotalLabel}>Net Earnings (Payable to Driver)</Text>
            <Text style={styles.earningsTotalValue}>{formatCurrency(statement.totalNetEarnings)}</Text>
          </View>
        </View>

        {/* Performance Stats */}
        <Text style={styles.sectionHeader}>Performance Statistics</Text>
        <View style={styles.statsGrid}>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{formatCurrency(statement.averageFare)}</Text>
            <Text style={styles.statLabel}>Average Fare</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{statement.totalDistanceKm.toFixed(1)} km</Text>
            <Text style={styles.statLabel}>Total Distance</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{statement.totalDurationMins} min</Text>
            <Text style={styles.statLabel}>Total Duration</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{statement.longestTrip.toFixed(1)} km</Text>
            <Text style={styles.statLabel}>Longest Trip</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{statement.shortestTrip.toFixed(1)} km</Text>
            <Text style={styles.statLabel}>Shortest Trip</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>
              {statement.totalTrips > 0
                ? (statement.totalDistanceKm / statement.totalTrips).toFixed(1)
                : '0'}{' '}
              km
            </Text>
            <Text style={styles.statLabel}>Avg Distance/Trip</Text>
          </View>
        </View>

        {/* Payout Schedule */}
        <View style={styles.payoutSchedule}>
          <Text style={styles.payoutScheduleTitle}>💰 Payout Schedule</Text>
          <Text style={styles.payoutScheduleText}>
            • Cash earnings: Retained by driver after collecting from passenger
          </Text>
          <Text style={styles.payoutScheduleText}>
            • Card/Online earnings: Paid out every Monday and Friday
          </Text>
          <Text style={styles.payoutScheduleText}>
            • Pending online payout: {formatCurrency(statement.pendingOnlinePayout)}
          </Text>
          <Text style={styles.payoutScheduleText}>
            • Platform fees: Deducted from gross fare (15% commission)
          </Text>
        </View>

        {/* Trip Details Table */}
        {statement.trips.length > 0 && (
          <View style={styles.tripTable}>
            <Text style={styles.sectionHeader}>Trip Details ({statement.trips.length} trips)</Text>
            
            <View style={styles.tripTableHeader}>
              <Text style={[styles.tripTableCellHeader, styles.colRef]}>Ref</Text>
              <Text style={[styles.tripTableCellHeader, styles.colDate]}>Date</Text>
              <Text style={[styles.tripTableCellHeader, styles.colPickup]}>Pickup</Text>
              <Text style={[styles.tripTableCellHeader, styles.colDrop]}>Drop-off</Text>
              <Text style={[styles.tripTableCellHeader, styles.colFare]}>Fare</Text>
              <Text style={[styles.tripTableCellHeader, styles.colMethod]}>Method</Text>
              <Text style={[styles.tripTableCellHeader, styles.colNet]}>Net</Text>
            </View>

            {statement.trips.slice(0, 20).map((trip, index) => (
              <View
                key={trip.id}
                style={[styles.tripTableRow, ...(index % 2 === 1 ? [styles.tripTableRowAlt] : [])]}
              >
                <Text style={[styles.tripTableCell, styles.colRef]}>
                  {trip.rideReference.slice(0, 8)}
                </Text>
                <Text style={[styles.tripTableCell, styles.colDate]}>
                  {formatDateTime(trip.completedAt)}
                </Text>
                <Text style={[styles.tripTableCell, styles.colPickup]}>
                  {trip.pickupAddress.slice(0, 25)}
                  {trip.pickupAddress.length > 25 ? '...' : ''}
                </Text>
                <Text style={[styles.tripTableCell, styles.colDrop]}>
                  {trip.destAddress.slice(0, 25)}
                  {trip.destAddress.length > 25 ? '...' : ''}
                </Text>
                <Text style={[styles.tripTableCell, styles.colFare]}>
                  {formatCurrency(trip.fare)}
                </Text>
                <Text
                  style={[
                    styles.tripTableCell,
                    styles.colMethod,
                    { color: trip.paymentMethod === 'Cash' ? '#FFC107' : TRYP_COLORS.primary },
                  ]}
                >
                  {trip.paymentMethod}
                </Text>
                <Text style={[styles.tripTableCell, styles.colNet]}>
                  {formatCurrency(trip.driverNetAmount)}
                </Text>
              </View>
            ))}

            {statement.trips.length > 20 && (
              <Text style={[styles.footerText, { marginTop: 8 }]}>
                ... and {statement.trips.length - 20} more trips (see full statement in admin console)
              </Text>
            )}
          </View>
        )}

        {/* Footer */}
        <View style={styles.footer}>
          <Text style={styles.footerText}>
            This statement is auto-generated every Monday and reflects earnings for the preceding 7-day period.
          </Text>
          <Text style={styles.footerText}>
            For questions about this statement, contact your fleet manager or TRYP support.
          </Text>
          <Text style={styles.footerSupport}>
            TRYP Driver Partner Support | support@tryp.co.za
          </Text>
          <Text style={[styles.footerText, { marginTop: 8 }]}>
            © {new Date().getFullYear()} TRYP. All rights reserved.
          </Text>
        </View>
      </Page>
    </Document>
  );
};

// Export PDF as blob
export async function generateStatementPDF(
  statement: DriverStatementSummary
): Promise<Blob> {
  const { pdf } = await import('@react-pdf/renderer');
  
  const doc = <StatementDocument statement={statement} />;
  const blob = await pdf(doc).toBlob();
  return blob;
}

// Export PDF as data URL (for preview)
export async function generateStatementPDFDataUrl(
  statement: DriverStatementSummary
): Promise<string> {
  const { pdf } = await import('@react-pdf/renderer');
  
  const doc = <StatementDocument statement={statement} />;
  const dataUrl = await pdf(doc).toBlob();
  return URL.createObjectURL(dataUrl);
}

// Download PDF helper
export async function downloadStatementPDF(
  statement: DriverStatementSummary
): Promise<void> {
  const blob = await generateStatementPDF(statement);
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `TRYP_Statement_${statement.driverName.replace(/\s+/g, '_')}_${statement.periodStart.slice(0, 10)}.pdf`;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

// Bulk download helper
export async function downloadAllStatementsPDF(
  statements: DriverStatementSummary[]
): Promise<void> {
  for (const statement of statements) {
    await downloadStatementPDF(statement);
    // Small delay between downloads
    await new Promise(resolve => setTimeout(resolve, 500));
  }
}
