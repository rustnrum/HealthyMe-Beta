# Build 70 — global Salus voice + recipe library

- Existing Build 69 code remains installed: ring sensor reader, Garmin battery and notifications, Recovery, meal planner, diary and saved data.
- The sole Talk to Salus entry lives in MaterialApp.builder. It is visible on all module routes to logged-in users who completed onboarding, not just Diet.
- Voice uses the existing authorized ChatGPT Responses API plus Android speech-to-text and text-to-speech; it is **not** the OpenAI Realtime API and not an uninterrupted native ChatGPT Voice session. Android's recognizer is designed for short turns. Optional automatic recognition of the next turn may vary by device; microphone never activates just from launching the app.
- Health records and workout histories are NOT automatically sent to ChatGPT. Choosing a conversation domain does not grant record access.
- Diet recipes from AI discovery can be bookmarked under Breakfast, Lunch, Dinner, or Snacks and removed later without changing the food log or existing calendar plans. Calendar changes require an additional approval.
- Search now requests up to eight recipes and offers Find more, retaining earlier cards and deduplicating names.
- Voice in Diet can search for recipes and save a numbered result after approval. Other scopes share chat/voice transport but have no record-modifying actions.
- Local favorites are stored under the new `salus_saved_ai_recipes_v1` SharedPreferences key. Old diet data schemas are unchanged.
- Validation still required: speech permission, Android speech engine availability, ChatGPT token eligibility, physical device TTS, and full Flutter/Gradle CI build.
