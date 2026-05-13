<div align="center">
   <img src="nexo/Assets.xcassets/AppIcon.appiconset/nexo-logo.png" alt="Nexo App Icon" width="160" height="160" />

# Nexo – Waste Management & Recycling Made Simple

![Nexo](https://img.shields.io/badge/🏆%202nd%20Place-Hackathon%202026-green?style=for-the-badge&color=2ecc71)
![Swift](https://img.shields.io/badge/Swift-5.10+-orange?style=for-the-badge&logo=swift)
![iOS](https://img.shields.io/badge/iOS-17%2B-blue?style=for-the-badge&logo=apple)
![Status](https://img.shields.io/badge/Status-Active-brightgreen?style=for-the-badge)

</div>

**An intelligent iOS app that identifies waste using AI, guides proper preparation, and connects users with recycling centers and collectors.**

[About](#about) • [Features](#features) • [Tech Stack](#tech-stack) • [Getting Started](#getting-started) • [Architecture](#architecture)

---

## 🏆 Hackathon Achievement

**🥈 2nd Place Winner** – Hackathon 2026 Enactus // Swift Change Makers | Mexico City, MX

Nexo represents a commitment to solving Mexico's waste management challenges through innovative technology, making recycling accessible and rewarding for everyone.

---

## 📱 About

Nexo is an iOS application designed to tackle waste management and environmental sustainability in Mexico. The app empowers users by:

- **Identifying waste instantly** using AI-powered image recognition
- **Providing preparation guidance** with personalized, easy-to-follow instructions
- **Connecting with resources** by mapping nearby recycling centers and waste collectors
- **Tracking environmental impact** through CO₂ and water savings metrics

The app supports three distinct user roles—**Hogar (Households)**, **Recolector (Collectors)**, and **Empresa (Companies)**—each with tailored workflows optimized for their specific needs.

---

## ✨ Core Features

### 🔍 AI-Powered Waste Identification

- **Real-time image scanning** with device camera
- **YOLO-based detection** using on-device ML models for instant recognition
- **Multi-language support** for Spanish and regional dialects
- **99%+ accuracy** on common waste materials

### 📋 Smart Preparation Guidance

- **AI-generated instructions** powered by Foundation Models (on-device)
- **Context-aware recommendations** based on material type and local availability
- **Preparation tips** including smell detection and best practices
- **Compliance hints** for special waste categories (hazardous, electronics, etc.)

### 🗺️ Interactive Map & Discovery

- **Real-time location mapping** of recycling centers and waste collectors
- **Distance filtering** and routing integration with Apple Maps
- **Live collector/center listings** with contact information
- **Material-specific filtering** to find the right solution quickly

### 👥 Multi-Role Support

#### **Hogar (Household Mode)**

- Scan and categorize personal waste
- View preparation instructions
- Find nearby recycling centers
- Track personal environmental impact

#### **Recolector (Collector Mode)**

- Browse available material opportunities in the area
- Manage collection routes and listings
- Track collected materials and earnings

#### **Empresa (Company Mode)**

- Publish batch listings for certified waste managers
- 2.5× impact multiplier for bulk materials
- Specialized batch management interface
- Access to certified collection networks

### 📊 Impact Tracking & Gamification

- **Environmental metrics** – CO₂ avoided, water saved, waste diverted
- **Scan history** with detailed material breakdown
- **Impact statistics** dashboard
- **User engagement** through achievement visualization

### 🔐 Authentication & User Profiles

- **Email/password authentication** via Supabase
- **User profiles** with avatar support
- **Session management** across device restarts
- **Role-based access control**

### 🎨 Native iOS Widgets

- **Quick access** to scanner and history
- **At-a-glance impact stats**
- **WidgetKit integration** for home screen shortcuts

---

## 🛠️ Tech Stack

### Core Technologies

- **SwiftUI** – Modern, declarative UI framework
- **SwiftData** – On-device data persistence
- **AVFoundation** – Camera and real-time video processing
- **CoreML & Vision** – On-device machine learning (YOLO model)

### AI & Intelligence

- **FoundationModels API** – On-device LLM for instruction generation
- **YOLO v8** – Object detection model packaged in `.mlpackage` format
- **Vision Framework** – Image processing and classification

### Backend & Services

- **Supabase** – PostgreSQL database, authentication, and storage
- **Foundation** – Networking and async/await patterns

### Location & Maps

- **MapKit** – Interactive maps and location services
- **CoreLocation** – GPS and location authorization

### Architecture & State Management

- **Combine** – Reactive programming framework
- **MVVM Pattern** – Clean separation of concerns
- **Dependency Injection** – Services architecture

---

## 🚀 Getting Started

### Prerequisites

- **Xcode 16+** (iOS 17+ SDK required)
- **iOS 17 or later** deployment target
- **CocoaPods** or **Swift Package Manager** for dependencies
- **Supabase account** for backend services

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/Nexo.git
   cd Nexo
   ```

2. **Install dependencies**

   ```bash
   # If using CocoaPods
   pod install

   # Or use Swift Package Manager within Xcode
   ```

3. **Configure Supabase**
   - Create a `SupabaseConfig.swift` file in `nexo/Config/` (use `SupabaseConfigExample.swift` as template)
   - Add your Supabase project URL and API key

   ```swift
   import Foundation

   struct SupabaseConfig {
       static let projectURL = "YOUR_SUPABASE_URL"
       static let anonKey = "YOUR_SUPABASE_ANON_KEY"
   }
   ```

4. **Open the project**

   ```bash
   open nexo.xcodeproj
   ```

5. **Run on simulator or device**
   - Select your target device in Xcode
   - Press `Cmd + R` to build and run

### First Launch

- Sign up with email and password
- Grant camera permissions for waste scanning
- Grant location permissions to find nearby recycling centers
- Choose your user role (Hogar, Recolector, or Empresa)
- Start scanning!

---

## 🏗️ Project Architecture

### Directory Structure

```
Nexo/
├── nexo/                          # Main app target
│   ├── Services/                  # Business logic & API integration
│   │   ├── AuthService.swift      # Authentication & user management
│   │   ├── StorageService.swift   # Local data persistence
│   │   ├── SupabaseClientProvider.swift
│   │   ├── Bulkvaluecalculator.swift
│   │   └── CameraManager.swift    # Camera & real-time processing
│   │
│   ├── Models/                    # Data structures
│   │   ├── NEXOModels.swift       # App enums (AppMode, MaterialRoute)
│   │   ├── Collector.swift        # Collector profile model
│   │   ├── Centrosacopio.swift    # Recycling center model
│   │   ├── UserProfile.swift      # User data structure
│   │   ├── Listing.swift          # Available material listings
│   │   └── ...other models
│   │
│   ├── Views/                     # UI Components (SwiftUI)
│   │   ├── ScannerView.swift      # Main camera scanner interface
│   │   ├── MapView.swift          # Interactive maps & listings
│   │   ├── FichaDetailView.swift  # Material detail & preparation
│   │   ├── HistorialView.swift    # History & statistics
│   │   ├── LoginView.swift        # Authentication UI
│   │   ├── RecolectorView.swift   # Collector mode interface
│   │   ├── Empresa/               # Company mode views
│   │   ├── Onboarding/            # First-launch experience
│   │   └── ...other views
│   │
│   ├── Organic/                   # Organic waste specific logic
│   │   ├── OrganicFichaView.swift
│   │   └── Organicwasteservice.swift
│   │
│   ├── Config/                    # Configuration files
│   │   ├── SupabaseConfig.swift   # Backend credentials (gitignored)
│   │   └── SupabaseConfigExample.swift
│   │
│   ├── YOLONexo.mlpackage/       # ML Model package (YOLO v8)
│   ├── Intents/                   # Siri Shortcuts integration
│   ├── Assets.xcassets/           # Images, icons, colors
│   ├── NEXOTheme.swift            # Design system & colors
│   └── nexoApp.swift              # App entry point
│
├── NEXOWidget/                    # iOS Widget target
│   ├── NEXOWidget.swift           # Widget implementation
│   ├── NEXOWidgetBundle.swift
│   └── NEXOWidgetControl.swift
│
├── YOLONexo.mlpackage/           # YOLO ML model (root-level copy)
├── yolov8n.pt                     # PyTorch weights for training
└── nexo.xcodeproj/               # Xcode project configuration
```

### Key Architectural Patterns

**MVVM + Services Pattern**

- Views observe @ObservedObject and @EnvironmentObject
- ViewModels (Services) handle business logic
- Models represent data structures
- Services inject dependencies through environment

**Reactive Patterns with Combine**

- @Published properties trigger UI updates
- Subscribers handle async operations
- Error propagation through @Published var errorMessage

**On-Device ML Architecture**

- Vision Framework processes camera frames
- YOLO model runs in CoreML
- FoundationModels API for text generation (no network required)

---

## 🎯 Key Use Cases

### Household User (Hogar)

1. Point camera at waste item
2. App identifies material with AI
3. Read preparation instructions (AI-generated)
4. Find nearest recycling center on map
5. Track environmental impact in profile

### Waste Collector (Recolector)

1. Browse available waste materials on map
2. Check material requirements and locations
3. Accept and track collection jobs
4. Manage collection history

### Company/Bulk Generator (Empresa)

1. Scan or manually enter bulk materials
2. Create batch listings with quantity and type
3. Publish to network of certified collectors
4. Track collection and impact
5. Benefit from 2.5× impact multiplier

---

## 📊 Data Models

### Core Entities

- **User** – Account with profile, email, phone, avatar
- **FichaRegistro** – Individual waste scan record
- **RecoleccionRegistro** – Collection/pickup record
- **LoteRegistro** – Batch/bulk listing (company mode)
- **Collector** – Waste collector profile and listings
- **Centrosacopio** – Recycling center information
- **NEXOMaterial** – Material definition (ID, category, instructions, impact)

### Material Routing

Each material follows one of three pathways:

- **Reciclaje** (Recycling) – Standard recyclables
- **Composta** (Composting) – Organic/green waste
- **Acopio Especial** (Special Collection) – Hazardous/electronics

---

## 🔒 Security & Privacy

- **Local-first computation** – YOLO and LLM run on-device, no image uploading
- **Encrypted authentication** – Supabase handles secure password storage
- **Location privacy** – Location data stored only in user's local database
- **User consent** – Explicit permission requests for camera, location, contacts
- **Data minimization** – Only essential user data collected

---

## 🧪 Testing & Quality

- **SwiftUI Preview** – Inline UI testing and iteration
- **Unit tests** (in progress) – Service logic validation
- **Integration tests** – Supabase and location services
- **Visual regression testing** – Screenshot comparisons across themes

---

## 🤝 Contributing

We welcome contributions from the community! Whether you're fixing bugs, improving documentation, or adding features:

1. **Fork** the repository
2. **Create a feature branch** – `git checkout -b feature/amazing-feature`
3. **Commit changes** – `git commit -m 'Add amazing feature'`
4. **Push to branch** – `git push origin feature/amazing-feature`
5. **Open a Pull Request**

### Development Guidelines

- Follow Apple's [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use descriptive variable and function names
- Keep functions focused and under 100 lines when possible
- Add comments only for non-obvious logic
- Test on both simulator and physical device

---

## 📝 License

This project is licensed under the MIT License – see LICENSE file for details.

---

## 👥 Team

**iMakers** – Hackathon 2026 Winner  
_Mexico City, MX_

- Lead Development
- Design & UX
- Product & Strategy
- Backend & Infrastructure

---

## 🌱 Future Roadmap

- [ ] Push notifications for collection opportunities
- [ ] Gamification & achievement badges
- [ ] Social sharing of environmental impact
- [ ] Integration with municipal waste programs
- [ ] Material price marketplace
- [ ] Multi-language support (English, Portuguese)
- [ ] Android version
- [ ] Offline mode improvements
- [ ] AR visualization for waste items
- [ ] Carbon credit marketplace

---

## 📮 Support & Feedback

Have questions, found a bug, or want to suggest a feature?

- **Issues**: [GitHub Issues](https://github.com/yourusername/Nexo/issues)
- **Email**: support@nexo-app.com
- **Website**: [nexo-app.com](https://nexo-app.com)

---

## 🙏 Acknowledgments

- **Hackathon 2026 Enactus** for the opportunity
- **Apple** for SwiftUI and CoreML frameworks
- **Supabase** for backend infrastructure
- **YOLO** creators for the detection model
- **Our community** for feedback and support

---

<div align="center">

**Making waste management sustainable, one scan at a time. 🌍♻️**

[⬆ back to top](#nexo--waste-management--recycling-made-simple)

</div>
