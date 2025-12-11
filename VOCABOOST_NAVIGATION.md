# VocaBoost Application Navigation & System Presentation

## 📱 Application Overview

**VocaBoost** is a comprehensive Bisaya (Cebuano) language learning application designed to help users master Mindanao Bisaya vocabulary through interactive learning methods, AI-powered assistance, and adaptive learning algorithms.

---

## 🗺️ Navigation Structure

### Entry Point
```
App Launch
    ↓
AuthWrapper (Authentication Check)
    ├─→ Login Screen (if not authenticated)
    └─→ Dashboard Screen (if authenticated)
```

---

## 🔐 Authentication Flow

### Login Screen (`login_screen.dart`)
- **Purpose**: User authentication and registration
- **Features**:
  - Email/Password login
  - User registration (signup)
  - Password reset
  - Dark mode toggle
- **Navigation**:
  - On successful login → Automatically navigates to Dashboard (via auth state stream)

### Signup Screen (`signup_screen.dart`)
- **Purpose**: New user registration
- **Navigation**:
  - After registration → Returns to Login Screen

---

## 🏠 Main Dashboard (`dashboard_screen.dart`)

**Central hub of the application**

### Features:
- Word of the Day display
- User profile information
- Quick access to all features
- Dark mode toggle

### Navigation Menu (Drawer):
```
Dashboard
├─ Home (Close drawer)
├─ Learning → Learning Screen
├─ AI Assistant → Voice Translation Screen
├─ Word Vocabulary → Word Vocabulary Screen
├─ Spaced Repetition Review → Review Screen
├─ Progress and Reports → Progress Screen
├─ Settings → Settings Screen
└─ Profile (via header tap) → Profile Screen
```

---

## 📚 Learning Module

### Learning Screen (`learning_screen.dart`)
**Main learning hub with three learning modes**

#### Navigation Options:
1. **Adaptive Flashcards** → `adaptive_flashcard_screen.dart`
   - Interactive flashcard system
   - Adaptive difficulty based on performance
   - Word mastery tracking

2. **Voice Quiz** → `voice_quiz_screen.dart`
   - Speech recognition-based pronunciation quiz
   - Real-time pronunciation feedback
   - AI-powered detailed feedback
   - Auto-saves challenging words

3. **Practice Mode** → `practice_mode_screen.dart`
   - Text-based quiz practice
   - Multiple choice questions
   - Performance tracking

### Quiz Selection Screen (`quiz_selection_screen.dart`)
- Redirects to Learning Screen (legacy route)

### Quiz Screen (`quiz_screen.dart`)
- Text-based vocabulary quiz
- Multiple choice format
- Auto-saves words after 3 incorrect attempts

---

## 🤖 AI Assistant Module

### Voice Translation Screen (`voice_translation_screen.dart`)
**AI-powered voice assistant for real-time learning**

#### Features:
- Voice input with speech-to-text
- AI chat assistant (OpenAI integration)
- Real-time translation
- Pronunciation guidance
- Conversational learning support

#### Navigation:
- Accessible from Dashboard → "AI Assistant"
- Can navigate back to Dashboard

---

## 📖 Word Vocabulary Module

### Word Vocabulary Screen (`word_vocabulary_screen.dart`)
**Comprehensive dictionary and word lookup**

#### Features:
- Search for Bisaya words
- Deep word analysis via OpenAI API
- Complete dictionary entries with:
  - Part of speech
  - English and Tagalog meanings
  - Sample sentences
  - Usage notes
  - Synonyms
- Works with local dataset and AI API
- Save words to personal collection

#### Navigation:
- Accessible from Dashboard → "Word Vocabulary"
- Can save words (stored in Firestore)

---

## 🔄 Spaced Repetition Module

### Review Screen (`review_screen.dart`)
**SM-2 Algorithm-based spaced repetition system**

#### Features:
- Review words due for practice
- Interactive flashcards
- Quality rating (0-5) for recall assessment
- Automatic scheduling based on performance
- Review statistics display

#### Navigation:
- Accessible from Dashboard → "Spaced Repetition Review"
- Words automatically scheduled based on:
  - Easiness factor
  - Repetition count
  - Review interval
  - Next review date

---

## 📊 Progress & Analytics Module

### Progress Screen (`progress_screen.dart`)
**Comprehensive learning analytics and reports**

#### Features:
- Learning statistics dashboard
- Progress charts and graphs
- Achievement system
- Performance metrics
- Learning insights
- Top mastered words
- Quiz history

#### Navigation:
- Accessible from Dashboard → "Progress and Reports"

---

## ⚙️ Settings & Profile

### Settings Screen (`settings_screen.dart`)
**Application configuration**

#### Features:
- Dark mode toggle
- Language preferences
- Notification settings
- Account management
- App information

### Profile Screen (`profile_screen.dart`)
**User profile management**

#### Features:
- User information display
- Profile editing
- Account settings
- Statistics overview

#### Navigation:
- Accessible from Dashboard → Tap on profile header

---

## 🔗 Complete Navigation Map

```
┌─────────────────────────────────────────────────────────────┐
│                    VocaBoost Application                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  AuthWrapper    │
                    │ (Auth Check)    │
                    └─────────────────┘
                              │
                ┌─────────────┴─────────────┐
                ▼                             ▼
        ┌───────────────┐            ┌──────────────┐
        │ Login Screen  │            │  Dashboard   │
        │               │            │   (Main Hub)  │
        └───────────────┘            └──────────────┘
                │                             │
                │                             ├─────────────────┐
                │                             │                 │
                ▼                             ▼                 ▼
        ┌───────────────┐            ┌─────────────────┐  ┌──────────────┐
        │ Signup Screen │            │ Learning Screen │  │ AI Assistant │
        └───────────────┘            └─────────────────┘  └──────────────┘
                                              │
                          ┌───────────────────┼───────────────────┐
                          │                   │                   │
                          ▼                   ▼                   ▼
              ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐
              │ Adaptive         │  │ Voice Quiz       │  │ Practice     │
              │ Flashcards       │  │ Screen           │  │ Mode Screen  │
              └──────────────────┘  └──────────────────┘  └──────────────┘
                                                                    │
                                                                    ▼
                                                          ┌──────────────┐
                                                          │ Quiz Screen  │
                                                          └──────────────┘

        ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
        │ Word         │  │ Review      │  │ Progress     │  │ Settings     │
        │ Vocabulary   │  │ Screen      │  │ Screen       │  │ Screen       │
        │ Screen       │  │ (SRS)       │  │              │  │              │
        └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
```

---

## 📱 Screen Details

### Primary Screens (Top Level)
1. **Login Screen** - Authentication entry point
2. **Dashboard Screen** - Main navigation hub
3. **Learning Screen** - Learning mode selection
4. **AI Assistant** - Voice translation and chat
5. **Word Vocabulary** - Dictionary and word lookup
6. **Review Screen** - Spaced repetition practice
7. **Progress Screen** - Analytics and reports
8. **Settings Screen** - App configuration
9. **Profile Screen** - User profile management

### Secondary Screens (Accessed from Learning)
1. **Adaptive Flashcard Screen** - Interactive flashcards
2. **Voice Quiz Screen** - Pronunciation practice
3. **Practice Mode Screen** - Text-based practice
4. **Quiz Screen** - Multiple choice quizzes

---

## 🔄 Data Flow

### Authentication Flow
```
User Input → Login Screen → Firebase Auth → Auth State Stream → Dashboard
```

### Word Saving Flow
```
Quiz/Vocabulary → Save Action → Translation Service → Firestore → Spaced Repetition Service
```

### Review Flow
```
Review Screen → Spaced Repetition Service → Firestore Query → Display Words → User Rating → Update SRS Parameters
```

### AI Integration Flow
```
User Query → AI Service → OpenAI API → Response Processing → Display Result
```

---

## 🎯 Key Features by Screen

| Screen | Primary Features |
|--------|------------------|
| **Dashboard** | Word of the Day, Quick Navigation, User Info |
| **Learning** | Mode Selection (Flashcards, Voice Quiz, Practice) |
| **Adaptive Flashcards** | Interactive Cards, Difficulty Adaptation |
| **Voice Quiz** | Speech Recognition, Pronunciation Feedback, AI Analysis |
| **Word Vocabulary** | Dictionary Lookup, AI-Enhanced Definitions, Word Saving |
| **Review Screen** | Spaced Repetition, Quality Rating, Review Scheduling |
| **Progress Screen** | Statistics, Charts, Achievements, Insights |
| **AI Assistant** | Voice Translation, Chat, Real-time Help |
| **Settings** | Theme, Preferences, Account Management |

---

## 🛠️ Technical Architecture

### Navigation Pattern
- **Material Design** navigation with `Navigator.push()`
- **Drawer-based** navigation for main menu
- **Stack-based** navigation for screen hierarchy
- **Auth state stream** for automatic navigation

### State Management
- **StatefulWidget** for local state
- **Firebase Auth** for authentication state
- **Firestore** for data persistence
- **SharedPreferences** for local settings

### Services Integration
- **Translation Service** - Word saving and translation
- **Spaced Repetition Service** - Review scheduling (SM-2 algorithm)
- **AI Service** - OpenAI API integration
- **NLP Model Service** - Local word embeddings
- **Dataset Service** - Local vocabulary dataset
- **Progress Service** - Learning analytics

---

## 📝 Navigation Best Practices

1. **Always pass theme state** (`isDarkMode`, `onToggleDarkMode`) to child screens
2. **Use MaterialPageRoute** for navigation
3. **Close drawer** before navigation (if applicable)
4. **Handle back navigation** appropriately
5. **Maintain auth state** through Firebase Auth stream

---

## 🎨 UI/UX Patterns

- **Consistent color scheme**: Blue Hour Harbor palette
- **Dark mode support**: All screens support theme switching
- **Responsive design**: Adapts to different screen sizes
- **Loading states**: Progress indicators for async operations
- **Error handling**: User-friendly error messages

---

## 📅 Last Updated
**Date**: 2024
**Version**: Current Implementation
**Status**: Active Development

---

## 🔍 Quick Reference

### Access Points:
- **Learning Modes**: Dashboard → Learning
- **AI Help**: Dashboard → AI Assistant
- **Word Lookup**: Dashboard → Word Vocabulary
- **Review Practice**: Dashboard → Spaced Repetition Review
- **View Progress**: Dashboard → Progress and Reports
- **Configure App**: Dashboard → Settings
- **View Profile**: Dashboard → Tap Profile Header

### Key Shortcuts:
- **Back Button**: Returns to previous screen
- **Drawer Menu**: Swipe from left or tap menu icon
- **Home**: Closes drawer (stays on Dashboard)

---

*This document provides a comprehensive overview of the VocaBoost application navigation structure and system architecture.*

