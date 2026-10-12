# Salus Build 69: AI Diet Discover + Meal Calendar

- Fixes Build68 analyzer failure: public Body Battery history/comparison helpers are now exposed by the widget, matching tests. Existing Recovery algorithm untouched.
- Diet bottom navigation: Today, Discover, Meals (saved), Calendar, Grocery.
- Discover: actual signed-in Salus AI Responses API generates JSON recipes, not demo recipes. Food preferences persist locally: favorite cuisines, disliked ingredients, strict exclusions/allergies, nutrition style.
- Recipe detail: ingredients, directions, cooking time, number of servings, explicitly AI-estimated calories/protein. No invented verified nutrient values.
- Calendar: week/month navigation, missing/planned statuses per day, selectable Breakfast/Lunch/Dinner/Snacks, manual add/edit, read stored detailed AI recipes.
- Approval: AI-suggested meals require a separate user confirmation before updating existing `TodayPlanNotifier` schedule; collision warning if overwriting scheduled meals. Bulk add fills ONLY valid unplanned dinners from the current seven-day date window.
- Grocery: optional confirmed ingredient add from displayed recipe. Duplicate grocery names skipped case-insensitively.
- Eaten food log and existing saved meal plans unchanged. No automatic food logging from calendar.
- Ingredient restrictions are AI prompt guidance only, **not** a guarantee of allergen exclusion/cross-contact protection. Always check ingredients.
- Recipe detail is persisted separately from the legacy string-based plan, preserving backwards compatibility. A manually changed plan name stops displaying outdated stored recipe detail.

Build through existing UPDATE workflow using source overlay. Existing signing, notification transport, and ring read code are unchanged by Build69; Build68 BLE request diagnostics remain included.
