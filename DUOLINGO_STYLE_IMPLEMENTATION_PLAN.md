# VocaBoost Duolingo-Style Transformation Plan

## Overview
Transform VocaBoost into a complete Duolingo-style Bisaya learning engine with gamification, structured lessons, XP system, and standardized output formats.

## Current State Analysis

### Already Implemented:
- ✅ Basic vocabulary validation and dictionary entries
- ✅ SM-2 spaced repetition algorithm
- ✅ Streak tracking (in `lib/services/flashcard_service.dart`)
- ✅ Basic achievements (in `lib/screens/progress_screen.dart`)
- ✅ Voice quiz with pronunciation feedback
- ✅ Adaptive difficulty adjustment
- ✅ Progress tracking and analytics
- ✅ Beginner/intermediate/advanced example support (partial in `lib/services/flashcard_service.dart`)

### Missing/Needs Enhancement:
- ❌ XP (Experience Points) system
- ❌ Crown/Skill mastery levels
- ❌ Structured lesson types (fill-in-blank, listening, sentence building, word matching)
- ❌ Standardized vocabulary output format (9-point structure)
- ❌ Challenge modes
- ❌ Skill path recommendations
- ❌ Enhanced cultural context in examples
- ❌ Comprehensive error-focused review system

## Implementation Plan

### Phase 1: Core Gamification System

#### 1.1 Create XP Service
**File**: `lib/services/xp_service.dart` (NEW)
- Track XP earned per activity (quiz, flashcard, review)
- Calculate XP based on difficulty and performance
- Store daily/weekly/total XP in Firestore
- Methods:
  - `earnXP(int amount, String activityType)`
  - `getTotalXP()`
  - `getDailyXP()`
  - `getLevel()` (calculate level from total XP)
  - `getXPToNextLevel()`

**Firestore Schema**:
```
users/{userId}/xp_data {
  totalXP: int,
  currentLevel: int,
  dailyXP: int,
  weeklyXP: int,
  lastXPDate: timestamp,
  lastXPWeek: timestamp
}
```

#### 1.2 Create Skill Mastery Service
**File**: `lib/services/skill_mastery_service.dart` (NEW)
- Track mastery levels (0-5 crowns) per word/skill
- Calculate mastery based on:
  - Number of correct answers
  - Difficulty of questions answered
  - Time since last review
  - Consistency of performance
- Methods:
  - `updateMastery(String wordId, bool isCorrect, int difficulty)`
  - `getMasteryLevel(String wordId)`
  - `getSkillsByLevel(int minLevel)`
  - `getMasteryProgress(String category)`

**Firestore Schema**:
```
users/{userId}/skill_mastery/{wordId} {
  wordId: string,
  masteryLevel: int (0-5),
  correctCount: int,
  totalAttempts: int,
  lastMastered: timestamp,
  category: string
}
```

#### 1.3 Enhance Streak System
**File**: `lib/services/flashcard_service.dart` (MODIFY)
- Already has streak tracking (lines 774-863), enhance with:
  - Streak freeze functionality
  - Streak milestones notifications
  - Streak recovery options
  - Streak badges

### Phase 2: Standardized Vocabulary Output

#### 2.1 Update AI Service for Structured Output
**File**: `lib/services/ai_service.dart` (MODIFY)
- Update `generateDictionaryEntry()` method (starting line 233) to return standardized 9-point format:
  1. Bisaya
  2. Tagalog
  3. English
  4. Part of Speech
  5. Pronunciation
  6. Category
  7. Beginner Example (Bisaya, English, Tagalog)
  8. Intermediate Example (Bisaya, English, Tagalog)
  9. Advanced Example (Bisaya, English, Tagalog)
- Update prompt (line 246-297) to enforce exact output order
- Ensure cultural context (jeepney, tindahan, fiesta, etc.) in all examples

**New JSON Structure**:
```json
{
  "valid": true,
  "bisaya": "kaon",
  "tagalog": "kain",
  "english": "eat",
  "partOfSpeech": "verb",
  "pronunciation": "kah-OHN",
  "category": "Action",
  "beginnerExample": {
    "bisaya": "Gusto ko kaon.",
    "english": "I want to eat.",
    "tagalog": "Gusto kong kumain."
  },
  "intermediateExample": {
    "bisaya": "Kaon na ta sa tindahan.",
    "english": "Let's eat at the store.",
    "tagalog": "Kumain na tayo sa tindahan."
  },
  "advancedExample": {
    "bisaya": "Nakaon na ba ka sa fiesta kagahapon?",
    "english": "Did you already eat at the fiesta yesterday?",
    "tagalog": "Nakakain ka na ba sa fiesta kahapon?"
  }
}
```

#### 2.2 Update Word Vocabulary Screen
**File**: `lib/screens/word_vocabulary_screen.dart` (MODIFY)
- Update display logic (around line 286-340) to show vocabulary in standardized format
- Display all three difficulty levels of examples
- Ensure proper ordering as specified
- Add cultural context indicators

### Phase 3: Duolingo-Style Lesson Types

#### 3.1 Create Lesson Generator Service
**File**: `lib/services/lesson_generator_service.dart` (NEW)
- Generate different lesson types:
  - **Flashcards**: Enhance existing with difficulty levels
  - **Fill-in-the-Blank**: Create sentences with missing words
  - **Multiple Choice**: Standardize format (already exists in `quiz_screen.dart`)
  - **Listening Exercises**: Audio-based questions
  - **Speaking Tasks**: Pronunciation practice (exists in `voice_quiz_screen.dart`)
  - **Word Matching**: Match Bisaya to English/Tagalog
  - **Sentence Building**: Arrange words to form sentences
- Methods:
  - `generateFillInBlank(String word, String difficulty)`
  - `generateListeningExercise(String word)`
  - `generateWordMatching(List<String> words)`
  - `generateSentenceBuilding(String sentence)`
  - `generateLesson(String lessonType, List<String> words, String difficulty)`

#### 3.2 Create Lesson Screen
**File**: `lib/screens/lesson_screen.dart` (NEW)
- Unified screen for all lesson types
- Adaptive lesson flow
- XP rewards on completion
- Progress tracking per lesson
- Motivational messages
- Mastery level updates

#### 3.3 Update Learning Screen
**File**: `lib/screens/learning_screen.dart` (MODIFY)
- Add new lesson type options (around line 66-200)
- Integrate with lesson generator service
- Show XP and mastery indicators
- Display recommended lessons

### Phase 4: Enhanced Adaptive Learning

#### 4.1 Create Adaptive Path Service
**File**: `lib/services/adaptive_path_service.dart` (NEW)
- Recommend next lessons based on:
  - User performance
  - Mastery levels
  - Weak areas
  - Spaced repetition schedule
  - Learning goals
- Methods:
  - `getRecommendedLessons()`
  - `getNextSkillToLearn()`
  - `getReviewPriority()`
  - `getPersonalizedPath()`

#### 4.2 Create Challenge Mode Service
**File**: `lib/services/challenge_service.dart` (NEW)
- Daily challenges
- Weekly challenges
- Special event challenges
- Methods:
  - `getDailyChallenge()`
  - `completeChallenge(String challengeId)`
  - `getChallengeRewards()`
  - `getChallengeHistory()`

**Firestore Schema**:
```
users/{userId}/challenges {
  challengeId: string,
  type: string (daily/weekly/special),
  completed: bool,
  completedAt: timestamp,
  xpReward: int,
  target: map
}
```

### Phase 5: Error-Focused Review System

#### 5.1 Enhance Spaced Repetition Service
**File**: `lib/services/spaced_repetition_service.dart` (MODIFY)
- Add error tracking per word (enhance existing methods)
- Identify common error patterns
- Generate targeted review sessions
- Methods:
  - `trackError(String wordId, String errorType)` (NEW)
  - `getErrorPatterns()` (NEW)
  - `generateErrorReview()` (NEW)
  - Enhance `getWordsDueForReview()` to prioritize error-prone words

**Firestore Schema**:
```
users/{userId}/saved_words/{wordId} {
  ...existing fields...,
  errorCount: int,
  errorTypes: array,
  lastError: timestamp
}
```

#### 5.2 Create Error Review Screen
**File**: `lib/screens/error_review_screen.dart` (NEW)
- Focus on words with frequent errors
- Provide targeted practice
- Show error patterns and corrections
- Track improvement

### Phase 6: Enhanced Cultural Context

#### 6.1 Update AI Prompts
**Files**: 
- `lib/services/ai_service.dart` (MODIFY line 246-297)
- `lib/services/flashcard_service.dart` (MODIFY line 93-130)
- Ensure all examples include:
  - Mindanao-specific contexts (jeepney, tindahan, school, fiesta)
  - Real Bisaya daily life scenarios
  - Cultural relevance
  - Regional authenticity

**Updated Prompt Template**:
```
When generating examples, always use culturally relevant Mindanao Bisaya contexts:
- Transportation: jeepney, tricycle, habal-habal
- Places: tindahan, palengke, eskwelahan, simbahan
- Events: fiesta, kasal, binyag
- Daily life: kumain sa karinderya, maglaba, magluto
- Family: pamilya, mga igsuon, lola, lolo
```

### Phase 7: UI/UX Enhancements

#### 7.1 Update Dashboard
**File**: `lib/screens/dashboard_screen.dart` (MODIFY)
- Display XP, level, streak prominently (around line 400-500)
- Show daily goals
- Display skill mastery progress
- Show recommended lessons
- Add motivational messages

#### 7.2 Update Progress Screen
**File**: `lib/screens/progress_screen.dart` (MODIFY)
- Add XP history chart (enhance existing charts around line 520-600)
- Show skill mastery tree
- Display crown levels per skill
- Show challenge completions
- Add level progression indicator

#### 7.3 Create Skill Tree Screen
**File**: `lib/screens/skill_tree_screen.dart` (NEW)
- Visual representation of skill mastery
- Crown levels per skill category
- Progress indicators
- Unlockable skills
- Category-based organization

### Phase 8: Motivational System

#### 8.1 Create Motivation Service
**File**: `lib/services/motivation_service.dart` (NEW)
- Generate encouraging messages
- Celebrate milestones
- Provide learning tips
- Methods:
  - `getMotivationalMessage(String context)`
  - `celebrateMilestone(String milestoneType)`
  - `getLearningTip()`
  - `getEncouragement(double performance)`

#### 8.2 Integrate Motivational Messages
**Files**: Various screens (MODIFY)
- Show motivational messages after completing lessons
- Celebrate achievements
- Provide encouragement during difficult sessions
- Update: `lesson_screen.dart`, `quiz_screen.dart`, `voice_quiz_screen.dart`, `adaptive_flashcard_screen.dart`

## Implementation Order

1. **Phase 1** (Core Gamification) - Foundation for all other features
2. **Phase 2** (Standardized Output) - Ensures consistency
3. **Phase 3** (Lesson Types) - Core learning experience
4. **Phase 4** (Adaptive Path) - Personalization
5. **Phase 5** (Error Review) - Targeted improvement
6. **Phase 6** (Cultural Context) - Authenticity
7. **Phase 7** (UI/UX) - User experience
8. **Phase 8** (Motivation) - Engagement

## Key Files to Create

1. `lib/services/xp_service.dart` - XP tracking and leveling
2. `lib/services/skill_mastery_service.dart` - Crown/mastery system
3. `lib/services/lesson_generator_service.dart` - Lesson type generation
4. `lib/services/adaptive_path_service.dart` - Personalized learning path
5. `lib/services/challenge_service.dart` - Challenge system
6. `lib/services/motivation_service.dart` - Motivational messages
7. `lib/screens/lesson_screen.dart` - Unified lesson interface
8. `lib/screens/error_review_screen.dart` - Error-focused practice
9. `lib/screens/skill_tree_screen.dart` - Visual skill mastery

## Key Files to Modify

1. `lib/services/ai_service.dart` - Standardized output format (line 233-619)
2. `lib/services/flashcard_service.dart` - Enhanced streaks, cultural context (line 93-130, 774-863)
3. `lib/services/spaced_repetition_service.dart` - Error tracking (add new methods)
4. `lib/screens/dashboard_screen.dart` - XP, level, mastery display (line 400-500)
5. `lib/screens/progress_screen.dart` - Enhanced analytics (line 520-600)
6. `lib/screens/learning_screen.dart` - Lesson type integration (line 66-200)
7. `lib/screens/word_vocabulary_screen.dart` - Standardized format display (line 286-340)

## Firestore Schema Updates

### New Collections:
- `users/{userId}/xp_data` - XP and leveling data
- `users/{userId}/skill_mastery/{wordId}` - Skill/crown levels per word
- `users/{userId}/challenges` - Challenge completions
- `users/{userId}/error_patterns` - Error tracking data

### Updated Collections:
- `users/{userId}/quiz_results` - Add `xpEarned` field
- `users/{userId}/saved_words` - Add `masteryLevel`, `errorCount`, `errorTypes` fields

## XP Calculation Rules

- **Flashcard**: 5-15 XP (based on difficulty)
- **Quiz Question**: 10 XP (correct), 5 XP (incorrect but learned)
- **Voice Quiz**: 15-25 XP (based on pronunciation accuracy)
- **Review Session**: 10 XP per word reviewed
- **Challenge Completion**: 50-200 XP (based on challenge type)
- **Daily Goal**: Bonus 20 XP
- **Streak Bonus**: +5 XP per day of streak

## Mastery Level Calculation

- **Level 0 (New)**: 0 correct answers
- **Level 1 (Crown 1)**: 3 correct answers
- **Level 2 (Crown 2)**: 6 correct answers + 80% accuracy
- **Level 3 (Crown 3)**: 10 correct answers + 85% accuracy
- **Level 4 (Crown 4)**: 15 correct answers + 90% accuracy
- **Level 5 (Crown 5/Mastered)**: 20 correct answers + 95% accuracy + no errors in 7 days

## Testing Considerations

- Test XP calculation accuracy across all activities
- Verify mastery level progression logic
- Test all 7 lesson types generate correctly
- Validate standardized output format matches specification
- Test adaptive path recommendations are relevant
- Verify cultural context appears in all examples
- Test error tracking and review system identifies weak areas
- Test streak system with edge cases (timezone, day boundaries)
- Verify Firestore schema updates don't break existing data

## Success Metrics

- Users can see XP, level, and mastery progress on dashboard
- All 7 lesson types are functional and engaging
- Vocabulary output follows exact 9-point structure
- Adaptive recommendations are relevant and helpful
- Cultural context is authentic and regionally appropriate
- Error review system effectively identifies and addresses weak areas
- Gamification elements increase user engagement and retention
- System feels like a complete Duolingo-style learning engine

## Notes

- Maintain backward compatibility with existing data
- Ensure offline functionality for core features
- Keep AI features optional (require internet)
- Preserve existing spaced repetition logic
- Enhance rather than replace current systems
- Focus on Mindanao Bisaya authenticity throughout

