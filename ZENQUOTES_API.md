# ZenQuotes API Integration

## Overview
Daily motivational notifications now use the ZenQuotes API for fresh, inspiring quotes with automatic offline fallback.

## API Details

### Endpoint
```
https://zenquotes.io/api/random
```

### Response Format
```json
[
  {
    "q": "The only way to do great work is to love what you do.",
    "a": "Steve Jobs",
    "h": "<blockquote>&ldquo;The only way to do great work is to love what you do.&rdquo; &mdash; <footer>Steve Jobs</footer></blockquote>"
  }
]
```

### Fields Used
- `q` - Quote text
- `a` - Author name

## Implementation

### How It Works

1. **8:00 AM Daily Notification**
   - Scheduled to trigger at 8:00 AM device local time
   - Runs every day automatically

2. **Online Mode (Internet Available)**
   - Fetches fresh quote from ZenQuotes API
   - 5-second timeout for API call
   - Format: "Quote text - Author name"
   - Example: "The only way to do great work is to love what you do. - Steve Jobs"

3. **Offline Mode (No Internet)**
   - Automatically falls back to 15 pre-loaded motivational messages
   - Rotates based on day of month
   - No API call attempted if previous call failed

### Code Flow
```
scheduleDailyMotivation()
    ↓
_fetchMotivationalMessage()
    ↓
Try: ZenQuotes API (5s timeout)
    ↓
Success? → Return "quote - author"
    ↓
Fail? → _getMotivationalMessage() (offline)
    ↓
Schedule notification for 8:00 AM
```

## Offline Fallback Messages

15 pre-loaded motivational quotes:
1. "Today is another chance to become the person you want to be!"
2. "Discipline is choosing between what you want now and what you want most."
3. "The only impossible journey is the one you never begin."
4. "Success is the sum of small efforts repeated day in and day out."
5. "You are stronger than you think and more capable than you imagine."
6. "Every day is a new opportunity to improve yourself."
7. "The pain of discipline weighs ounces, but the pain of regret weighs tons."
8. "Your only limit is your mind. Push through!"
9. "Great things never come from comfort zones."
10. "The difference between ordinary and extraordinary is that little extra."
11. "You didn't come this far to only come this far."
12. "Believe in yourself and all that you are."
13. "Champions keep playing until they get it right."
14. "The harder you work, the luckier you get."
15. "Don't stop when you're tired. Stop when you're done."

## Features

### ✅ Smart Fallback
- Automatic detection of network availability
- Graceful degradation to offline mode
- No user intervention required

### ✅ Performance
- 5-second timeout prevents hanging
- Cached offline messages for instant fallback
- Minimal battery impact

### ✅ Reliability
- Works with or without internet
- No dependency on external service uptime
- Always delivers daily motivation

## API Benefits

### Why ZenQuotes?
1. **Free** - No API key required
2. **No Rate Limits** - Unlimited requests
3. **Quality Content** - Curated inspirational quotes
4. **Variety** - Fresh quote every day
5. **Simple** - Single endpoint, easy integration

## Error Handling

### Network Errors
- Connection timeout (5s)
- DNS resolution failure
- Server unavailable
- Invalid response format

**Action**: Automatically use offline messages

### API Errors
- HTTP 4xx/5xx status codes
- Malformed JSON response
- Missing required fields

**Action**: Automatically use offline messages

## Testing

### Test Online Mode
```dart
// Trigger immediate notification with online quote
await NotificationService().scheduleDailyMotivation();
```

### Test Offline Mode
1. Disable device internet
2. Trigger notification
3. Verify offline message is used

### Test Fallback
1. Block zenquotes.io in hosts file
2. Trigger notification
3. Verify graceful fallback

## Monitoring

### Debug Logs
```
🔔 DEBUG: Fetched quote from ZenQuotes API
🔔 DEBUG: Failed to fetch online quote, using offline: [error]
🔔 DEBUG: Daily motivation scheduled successfully
```

## Privacy & Data

### Data Collection
- **None** - No user data sent to API
- **No Tracking** - Anonymous API calls
- **No Storage** - Quotes not cached locally

### Permissions Required
- `INTERNET` - For API calls
- `ACCESS_NETWORK_STATE` - To check connectivity

## Future Enhancements

### Potential Improvements
1. Cache last successful quote for 24 hours
2. Add quote categories (fitness, discipline, success)
3. User preference for quote types
4. Multiple quote sources with fallback chain
5. Quote history/favorites

## Compliance

### Terms of Service
- ZenQuotes API is free for personal and commercial use
- No attribution required (but appreciated)
- No API key needed
- Unlimited requests allowed

### Attribution (Optional)
"Quotes provided by ZenQuotes API"

## Troubleshooting

### Issue: No quotes received
**Solution**: Check internet connection, verify API endpoint

### Issue: Same quote every day
**Solution**: API returns random quotes; coincidence or API issue

### Issue: Notification not showing
**Solution**: Check notification permissions, verify 8 AM scheduling

---

**Status**: ✅ Implemented and tested
**API**: https://zenquotes.io/api/random
**Fallback**: 15 offline messages
**Schedule**: Daily at 8:00 AM device time
