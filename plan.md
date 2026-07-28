

# TRYP Full Implementation Plan

## 1. Final Technology Stack

### Mobile Applications

**Flutter + Dart**

We will use one Flutter codebase with role-based experiences:

```text
TRYP Mobile App
│
├── Passenger Mode
│
└── Driver Mode
```

This avoids maintaining two separate mobile codebases while allowing both apps to have completely different interfaces.

Later, if needed, we can produce separate passenger and driver builds from the same codebase.

---

## 2. Backend Architecture

### Core Backend

**Supabase**

```text
Supabase
│
├── PostgreSQL Database
├── Authentication
├── Row Level Security
├── Realtime
├── Storage
└── Edge Functions
```

### Important principle

The Flutter application should **never be trusted with important business decisions**.

For example:

```text
Flutter:
"Passenger wants to request a ride"
        │
        ▼
Backend:
├── Validate passenger
├── Check active trips
├── Calculate fare
├── Find drivers
├── Create trip
└── Dispatch ride
```

The mobile app displays the result.

---

# 3. TRYP System Architecture

```text
                    ┌─────────────────┐
                    │ Passenger App   │
                    │    Flutter      │
                    └────────┬────────┘
                             │
                             │
                    ┌────────▼────────┐
                    │     Supabase    │
                    │                 │
                    │ Authentication  │
                    │ PostgreSQL      │
                    │ Realtime        │
                    │ Storage         │
                    │ Edge Functions  │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
     ┌──────▼──────┐ ┌───────▼──────┐ ┌──────▼──────┐
     │ Driver App  │ │ Maps Service │ │ Payments    │
     │   Flutter   │ │              │ │             │
     └─────────────┘ └──────────────┘ └─────────────┘
```

---

# 4. Flutter Project Structure

I recommend a **feature-first architecture**.

```text
tryp/
│
├── android/
├── ios/
│
├── lib/
│   │
│   ├── main.dart
│   │
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── extensions/
│   │   ├── services/
│   │   ├── utils/
│   │   └── widgets/
│   │
│   ├── features/
│   │   │
│   │   ├── authentication/
│   │   │   ├── data/
│   │   │   ├── models/
│   │   │   ├── providers/
│   │   │   └── presentation/
│   │   │
│   │   ├── passenger/
│   │   │   ├── home/
│   │   │   ├── ride_request/
│   │   │   ├── ride_tracking/
│   │   │   ├── trip_history/
│   │   │   └── profile/
│   │   │
│   │   ├── driver/
│   │   │   ├── onboarding/
│   │   │   ├── dashboard/
│   │   │   ├── ride_requests/
│   │   │   ├── active_trip/
│   │   │   ├── earnings/
│   │   │   └── profile/
│   │   │
│   │   ├── trips/
│   │   ├── payments/
│   │   ├── maps/
│   │   ├── notifications/
│   │   └── support/
│   │
│   └── shared/
│       ├── models/
│       ├── providers/
│       └── widgets/
│
├── test/
│
└── pubspec.yaml
```

This keeps the project from becoming a giant `lib/` junk drawer six months from now.

---

# 5. Application Navigation

## Authentication Flow

```text
Splash
   │
   ▼
Session Check
   │
   ├── Not logged in
   │       │
   │       ▼
   │    Welcome
   │       │
   │       ▼
   │   Login/Register
   │
   └── Logged in
           │
           ▼
       Check Role
           │
           ├── Passenger
           │
           └── Driver
```

---

# 6. Passenger App Screens

## A. Splash Screen

```text
TRYP Logo
Move Smart. Move Safe.
```

---

## B. Onboarding

Three simple slides:

### Slide 1

```text
Request a ride
Wherever you need to go.
```

### Slide 2

```text
Track your driver
Know exactly where your ride is.
```

### Slide 3

```text
Ride safely
Your journey, tracked from start to finish.
```

---

## C. Authentication

```text
Login
Register
Phone verification
Forgot password
```

We can support:

* Phone number
* Email
* Social login later

For a transport app, I would make **phone authentication the primary method**.

---

## D. Passenger Home

The main interface:

```text
┌──────────────────────────┐
│ ☰       TRYP       🔔    │
│                          │
│       MAP                │
│                          │
│                          │
│                          │
│ ┌──────────────────────┐ │
│ │ 📍 Current location  │ │
│ │                      │ │
│ │ Where are you going? │ │
│ └──────────────────────┘ │
│                          │
│ Saved Places             │
│ 🏠 Home    💼 Work       │
└──────────────────────────┘
```

---

# 7. Ride Request Flow

```text
Home
 │
 ▼
Select Destination
 │
 ▼
Confirm Pickup
 │
 ▼
Choose Ride Type
 │
 ▼
Fare Estimate
 │
 ▼
Select Payment
 │
 ▼
Request Ride
 │
 ▼
Search for Driver
```

---

## Ride Types

For the first version:

```text
Economy
Comfort
XL
```

Each ride type should have:

```text
name
description
minimum_fare
base_fare
price_per_km
price_per_minute
vehicle_requirements
```

---

# 8. Driver Matching System

The driver dispatch system is the engine of TRYP.

## Flow

```text
Passenger requests ride
        │
        ▼
Trip created
        │
        ▼
Find nearby online drivers
        │
        ▼
Filter drivers
        │
        ├── Correct vehicle type
        ├── Not already on trip
        ├── Approved account
        └── Within service radius
        │
        ▼
Rank drivers
        │
        ▼
Send ride request
        │
        ▼
Driver has limited time
        │
        ├── Accept
        │
        └── Reject/Timeout
                    │
                    ▼
              Next driver
```

---

# 9. Driver App

## Driver Onboarding

```text
Create Account
      │
      ▼
Personal Details
      │
      ▼
Identity Verification
      │
      ▼
Driver's License
      │
      ▼
Vehicle Details
      │
      ▼
Vehicle Documents
      │
      ▼
Admin Review
      │
      ▼
Approved
```

The driver cannot receive rides until:

```text
driver.status = approved
```

---

# 10. Driver Home

```text
┌──────────────────────────┐
│ Good morning, Driver     │
│                          │
│        OFFLINE           │
│      [ GO ONLINE ]       │
│                          │
│ Today's Earnings         │
│ R 450.00                 │
│                          │
│ Trips Today: 8           │
│ Rating: ⭐ 4.8           │
│                          │
│ Earnings   Trips   Profile│
└──────────────────────────┘
```

---

# 11. Driver Ride Request

When a request arrives:

```text
┌──────────────────────────┐
│ New Ride Request         │
│                          │
│ Pickup                  │
│ 2.4 km away             │
│                          │
│ Destination             │
│ 8.5 km                  │
│                          │
│ Estimated Earnings      │
│ R 95.00                 │
│                          │
│ [ DECLINE ] [ ACCEPT ]  │
└──────────────────────────┘
```

The driver should see enough information to make an informed decision.

---

# 12. Trip State Machine

This is critical.

A trip should follow controlled states.

```text
requested
    │
    ▼
searching
    │
    ▼
driver_assigned
    │
    ▼
driver_arriving
    │
    ▼
driver_arrived
    │
    ▼
trip_started
    │
    ▼
completed
```

Alternative paths:

```text
requested
    │
    └── cancelled

searching
    │
    └── no_driver_found

driver_assigned
    │
    └── driver_cancelled

trip_started
    │
    └── dispute
```

The backend should reject invalid transitions.

For example:

```text
❌ completed → trip_started
❌ cancelled → driver_arriving
❌ requested → completed
```

---

# 13. Location Tracking

## Passenger

The passenger receives driver location updates.

```text
Driver Phone
     │
     ▼
Location Service
     │
     ▼
Supabase Realtime
     │
     ▼
Passenger App
```

We should **not write GPS coordinates to the database every second**.

That would be wasteful.

Better:

```text
Driver location
      │
      ▼
Update periodically
      │
      ▼
Realtime location channel
```

Permanent trip location history can be recorded at controlled intervals for safety and dispute purposes.

---

# 14. Database Schema

## profiles

```text
profiles
├── id
├── full_name
├── phone
├── email
├── avatar_url
├── role
├── rating
├── status
├── created_at
└── updated_at
```

---

## driver_profiles

```text
driver_profiles
├── id
├── user_id
├── verification_status
├── online_status
├── current_location
├── rating
├── total_trips
├── acceptance_rate
└── created_at
```

For location searches, use PostgreSQL geographic capabilities rather than basic latitude/longitude calculations.

---

## vehicles

```text
vehicles
├── id
├── driver_id
├── make
├── model
├── year
├── color
├── registration_number
├── vehicle_type
├── verification_status
└── created_at
```

---

## trips

```text
trips
├── id
├── passenger_id
├── driver_id
├── vehicle_id
├── pickup_location
├── destination_location
├── pickup_address
├── destination_address
├── ride_type
├── status
├── estimated_fare
├── final_fare
├── distance
├── duration
├── requested_at
├── started_at
├── completed_at
└── cancelled_at
```

---

## trip_events

Every important action should be recorded.

```text
trip_events
├── id
├── trip_id
├── event_type
├── actor_id
├── metadata
└── created_at
```

Example:

```text
ride_requested
driver_assigned
driver_arrived
trip_started
trip_completed
payment_completed
```

This is extremely useful for disputes and debugging.

---

# 15. Pricing Architecture

Pricing should be configurable.

```text
pricing_rules
├── ride_type
├── base_fare
├── price_per_km
├── price_per_minute
├── minimum_fare
├── booking_fee
└── active
```

The fare calculation should happen on the backend.

```text
distance
     │
     ▼
Fare Engine
     │
     ├── Base fare
     ├── Distance fare
     ├── Time fare
     ├── Fees
     └── Discounts
     │
     ▼
Final fare
```

The mobile app can show an estimate.

The backend calculates the authoritative fare.

---

# 16. Payments

The architecture should look like this:

```text
Passenger
    │
    ▼
Requests ride
    │
    ▼
Payment method selected
    │
    ▼
Trip completed
    │
    ▼
Backend calculates final fare
    │
    ▼
Payment processed
    │
    ▼
Transaction recorded
    │
    ▼
Driver earnings created
```

Database:

```text
payments
├── id
├── trip_id
├── passenger_id
├── amount
├── payment_method
├── provider
├── provider_reference
├── status
└── created_at
```

```text
driver_earnings
├── id
├── driver_id
├── trip_id
├── gross_amount
├── platform_commission
├── net_amount
├── payout_status
└── created_at
```

Important:

> Never trust a payment success message coming directly from the mobile app.

Payment confirmation should come from the payment provider through a secure backend webhook.

---

# 17. Notifications

TRYP needs notifications for:

### Passenger

* Driver found
* Driver arriving
* Driver arrived
* Trip started
* Trip completed
* Payment successful

### Driver

* New ride request
* Passenger cancelled
* New earnings
* Document approved
* Account warning

The backend should trigger notifications.

```text
Database Event
      │
      ▼
Edge Function
      │
      ▼
Push Notification
      │
      ▼
Phone
```

---

# 18. Safety System

## Emergency Button

Available during active trips.

```text
Emergency
     │
     ▼
Confirmation
     │
     ▼
Emergency action
```

Possible actions:

* Contact emergency services
* Alert TRYP support
* Share trip information
* Notify emergency contacts

The exact implementation should be tailored to the country where TRYP launches.

---

## Trip Sharing

The passenger can share:

```text
Driver name
Vehicle
Registration
Pickup
Destination
Live trip status
```

---

# 19. Ratings

After completion:

```text
Passenger ─────► Driver
Driver ─────────► Passenger
```

Rating:

```text
1 to 5 stars
```

Optional categories:

```text
Clean vehicle
Safe driving
Professionalism
Punctuality
```

However, I would keep the first version simple.

---

# 20. Supabase Security

This is one of the most important parts.

### Passenger should be able to:

```text
Read own profile
Update own profile
Create trip
Read own trips
```

### Driver should be able to:

```text
Read own profile
Update own location
Read assigned trips
Update permitted trip states
View own earnings
```

### Passenger should NOT be able to:

```text
Read all drivers' private data
Modify trip fare
Assign themselves a driver
Change payment status
```

### Driver should NOT be able to:

```text
Modify earnings
Modify payment records
Access other drivers' private data
```

This is handled through **Row Level Security policies**.

---

# 21. Backend Functions

The backend should contain functions such as:

```text
request-ride
calculate-fare
find-nearby-drivers
dispatch-ride
accept-ride
cancel-ride
driver-arrived
start-trip
complete-trip
process-payment
calculate-driver-earnings
send-notification
```

The ride flow becomes:

```text
Flutter
   │
   ▼
request-ride
   │
   ▼
Backend validates request
   │
   ▼
Trip created
   │
   ▼
find-nearby-drivers
   │
   ▼
dispatch-ride
   │
   ▼
Driver accepts
   │
   ▼
Realtime update
   │
   ▼
Passenger sees driver
```

---

# 22. Development Phases

## Phase 0: Project Setup

### Tasks

* Create Flutter project
* Create Supabase project
* Set up environments
* Configure Git
* Create database migrations
* Set up app theme
* Configure navigation
* Configure state management

### Environments

```text
Development
      │
      ▼
Staging
      │
      ▼
Production
```

Do not build directly against the production database.

---

# Phase 1: Authentication

Build:

* Splash screen
* Onboarding
* Registration
* Login
* Phone verification
* Session management
* Role selection

Deliverable:

```text
User can register and access the correct application mode.
```

---

# Phase 2: Passenger Foundation

Build:

* Passenger profile
* Home map
* Location permissions
* Pickup location
* Destination search
* Saved locations

Deliverable:

```text
Passenger can select where they are and where they want to go.
```

---

# Phase 3: Fare System

Build:

* Ride types
* Fare calculation
* Fare estimate
* Pricing rules

Deliverable:

```text
Passenger receives a reliable ride estimate.
```

---

# Phase 4: Driver Onboarding

Build:

* Driver profile
* License upload
* Vehicle registration
* Vehicle documents
* Admin approval status

Deliverable:

```text
Only approved drivers can go online.
```

---

# Phase 5: Driver Availability

Build:

* Go online
* Go offline
* Location tracking
* Driver status
* Nearby driver discovery

Deliverable:

```text
The system knows which drivers are available.
```

---

# Phase 6: Ride Dispatch

Build:

* Passenger ride request
* Nearby driver search
* Ride request notification
* Driver accept/reject
* Timeout
* Driver reassignment

Deliverable:

```text
Passenger can be matched with a driver.
```

This is the first major milestone.

---

# Phase 7: Active Trip

Build:

* Driver navigation
* Driver approaching
* Driver arrived
* Start trip
* Live tracking
* End trip

Deliverable:

```text
A complete ride can happen from beginning to end.
```

---

# Phase 8: Payments

Build:

* Payment methods
* Payment provider integration
* Payment confirmation
* Driver earnings
* Commission calculations
* Payment history

Deliverable:

```text
Money moves correctly and records are auditable.
```

---

# Phase 9: Ratings and History

Build:

* Passenger trip history
* Driver trip history
* Ratings
* Reviews
* Receipts

---

# Phase 10: Safety and Support

Build:

* SOS
* Trip sharing
* Report user
* Dispute system
* Support requests

---

# 23. Testing Strategy

We should not wait until the end to test.

## Unit Tests

Test:

```text
Fare calculation
Trip state transitions
Commission calculations
Driver ranking
```

## Widget Tests

Test:

```text
Login
Ride request
Driver acceptance
Payment screens
```

## Integration Tests

Test:

```text
Passenger requests ride
Driver receives ride
Driver accepts
Trip completes
Payment processes
```

The most important test:

```text
Passenger + Driver
        │
        ▼
Complete ride
        │
        ▼
Correct payment
```

---

# 24. Deployment Strategy

## Android

```text
Flutter
   │
   ▼
Android App Bundle
   │
   ▼
Google Play Store
```

## iOS

```text
Flutter
   │
   ▼
iOS Build
   │
   ▼
App Store
```

The driver and passenger applications can use:

```text
Same codebase
     │
     ├── Passenger build
     │
     └── Driver build
```

Or initially:

```text
One app
     │
     ▼
Role-based interface
```

For the MVP, I recommend **one app with role-based access**.

---

# 25. TRYP MVP Definition

The first usable version should contain:

### Passenger

* Registration
* Login
* Map
* Pickup location
* Destination
* Fare estimate
* Request ride
* Driver matching
* Live tracking
* Trip completion
* Payment
* Rating
* Trip history

### Driver

* Registration
* Document upload
* Vehicle registration
* Approval status
* Go online/offline
* Receive ride
* Accept ride
* Navigate to passenger
* Start trip
* Complete trip
* Earnings
* Trip history

### Backend

* Authentication
* Database
* Driver matching
* Pricing
* Realtime tracking
* Notifications
* Payments
* Security

---

# Recommended Build Order

I would build TRYP in this exact order:

```text
1. Flutter project
        ↓
2. Supabase project
        ↓
3. Database schema
        ↓
4. Authentication
        ↓
5. App navigation
        ↓
6. Passenger home
        ↓
7. Driver onboarding
        ↓
8. Maps and location
        ↓
9. Fare calculation
        ↓
10. Ride request
        ↓
11. Driver matching
        ↓
12. Realtime ride tracking
        ↓
13. Trip lifecycle
        ↓
14. Payments
        ↓
15. Ratings
        ↓
16. Safety
        ↓
17. Testing
        ↓
18. Launch
```

## My recommendation for the very next step

Before building screens, we should create the **TRYP technical foundation**:

1. Finalize the database schema
2. Define every trip status
3. Define the permissions for each role
4. Create the Supabase migrations
5. Create the Flutter project structure
6. Set up the design system from your TRYP mockup

That gives us the skeleton before we start adding muscles and shiny yellow wheels. 🚕⚡
