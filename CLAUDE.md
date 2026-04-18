# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Appetight is a hackathon iOS nutrition tracking app that uses Claude AI for food image analysis, restaurant recommendations, and gym busy-time predictions. Users log meals via camera (Claude analyzes food photos), voice, or manual input.

## Build & Run

This is a native iOS app — all development happens in Xcode.

- **Build**: Open `Appetight.xcodeproj` → ⌘B
- **Run**: ⌘R (requires physical device or simulator)
- **Test**: ⌘U (no tests currently exist)

**Before first build**, add API keys to `Appetight/Config.swift`:
```swift
static let anthropic = "sk-ant-..."
static let googleMaps = "AIzaSy..."
```

## Architecture

**Central state**: `AppState.swift` is an `@EnvironmentObject` injected at root. It holds the user profile, all meal logs, friends list, and streak data, and persists everything to UserDefaults.

**Claude integration**: `AnthropicService.swift` makes all Anthropic API calls. Uses `claude-haiku-4-5-20251001`. Three main call sites:
1. Food image analysis (base64 image → nutrition facts)
2. Restaurant recommendations (location + persona context → ranked list)
3. Gym busy-time prediction (gym name + hour → estimated crowding)

**Personalization**: `PersonaEngine.swift` aggregates meal logs into a `UserPersona` (SwiftData model in `UserPersona.swift`). The persona is serialized into a string and injected into Claude system prompts to personalize responses over time.

**External data**: `PlacesService.swift` calls Google Maps Places API for nearby restaurants and gyms. `LocationService.swift` wraps CoreLocation.

**Navigation flow**:
- `AppetightApp.swift` → `RootView` checks for saved profile → routes to `OnboardingView` or `DashboardView`
- `DashboardView` is a 4-tab container: Today, Hungry, Gym, Friends
- Meal logging opens modally from the Today tab (camera, voice, or quick-add)

**Data models**: All core types (Profile, MealLog, Restaurant, Friend, etc.) are defined in `Models.swift`. TDEE/macro calculations live in `TDEE.swift` (Mifflin-St Jeor formula).

## Key Patterns

- MVVM with `@StateObject` / `@EnvironmentObject` / `@Observable`
- `async/await` throughout all service calls
- No external Swift packages — only Apple frameworks (SwiftUI, SwiftData, CoreLocation, Speech, AVFoundation, UserNotifications)
- SwiftData used only for `UserPersona`; everything else persists via `UserDefaults`

## Required Permissions

The app requests camera, microphone, location, speech recognition, photo library, and notifications at runtime. All permission strings must be present in `Info.plist`.
