# Sahyog

Sahyog is a Flutter-based mobile application designed for surplus food and resource donation management. It connects **Donors**, **NGOs**, **Volunteers**, and **Administrators** into a unified platform featuring role-based workflows, live location tracking, and delivery route visualization.

---

## 📱 Modules & Features

### 1. Donor
- **Create Donation**: Donate food and essential supplies with category selection, quantity, food type (veg/non-veg), expiry time, photos, and pickup address.
- **Interactive Map Location Picker**: Set precise pickup coordinates on an interactive map.
- **Donation Tracking**: Real-time status progression (`Pending` ➔ `Assigned` ➔ `Out for Pickup` ➔ `Delivered`).
- **Live Tracking Map**: View the assigned delivery volunteer's location and route on a map.
- **Donation History**: View past donations and their delivery statuses.
- **Profile Management**: Update profile details and view activity stats.

### 2. NGO
- **Donation Feed**: Browse available donations, view donor details, food expiry, and accept or reject requests.
- **Volunteer Management**: Add and manage volunteers, view their live status (`Available`, `On Delivery`, `Offline`), and assign them to accepted donations.
- **Pickup Details & Routing**: View route details between pickup and delivery locations with donor contact details and delivery updates.
- **NGO Map**: View active volunteers and donation pickups on a map.
- **Donation History**: Track all completed and past donations received by the NGO.
- **Profile Management**: Maintain NGO organization profile and contact information.

### 3. Admin
- **Dashboard**: High-level platform statistics covering active donors, approved NGOs, total volunteers, and donation counts.
- **NGO Approval Center**: Review and verify newly registered NGOs with tabbed approval stages (`Pending`, `Approved`, `Verified`, `Rejected`).
- **Live Tracking Map**:
  - Spatial map tracking all approved NGOs and active volunteers.
  - Category filters: `NGOs`, `Volunteers`, `On Delivery`, `Available`.
  - Search bar with live camera centering and geocoding lookup.
  - Pickup and drop points with route polylines.
  - Single marker deduplication per active person/organization.
- **Reports**: Platform-wide donation summaries with PDF generation and printing.

---

## 🛠️ Tech Stack

- **Framework**: Flutter (Dart)
- **Backend & Database**: Firebase Authentication, Cloud Firestore, Firebase Storage
- **Mapping & Geolocation**:
  - `flutter_map` & `latlong2` (OpenStreetMap)
  - `geolocator` & reverse geocoding
  - OpenRouteService (ORS) API for route polyline calculation
- **State Management**: `flutter_riverpod`
- **Navigation**: `go_router`
- **Environment & Configuration**: `flutter_dotenv` (`.env`)
- **PDF & Reports**: `pdf`, `printing`

---

## 📂 Project Directory Structure

```text
lib/
├── constants/           # App colors, themes, and styling
├── models/              # Data models (Donations, NGO, Volunteer, User)
├── screens/
│   ├── admin/           # Admin dashboard, approval center, live map, reports
│   ├── auth/            # Login, registration, role selection
│   ├── donor/           # Donation creation, tracking map, history, profile
│   └── ngo/             # Donation feed, volunteer mgmt, pickup details, history
├── services/            # Firestore, routing, geocoding, location tracking
├── utils/               # Tracking helpers, date utilities
├── widgets/             # Map location picker, markers, shared UI components
└── main.dart            # App entry point
```

---

## ⚙️ How to Run

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Configure Environment Variables**:
   Create a `.env` file in the root directory (based on `.env.example`):
   ```env
   ORS_API_KEY=your_openrouteservice_api_key
   ```

3. **Firebase Setup**:
   Ensure `google-services.json` is placed in `android/app/`.

4. **Run the App**:
   ```bash
   flutter run
   ```
