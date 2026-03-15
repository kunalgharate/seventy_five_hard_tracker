# .kiro Folder Optimization - Feb 17, 2026

## Changes Made

### 1. Reduced `flutter-ui-engineer.md` (8KB → 1.5KB)
- Removed verbose tables and examples
- Kept only essential rules and patterns
- Compressed to minimal format

### 2. Optimized `context.json` (643B → 350B)
- Removed redundant architecture section
- Simplified must_follow rules
- Kept only critical info

### 3. Result
- **80% reduction** in prompt size
- Faster context loading
- More tokens available for actual code
- Focused, actionable guidance only

## Token Usage Strategy
- Prompts: ~2KB (was ~9KB)
- Context files: Only when explicitly needed
- Code tool: Targeted symbol search first
- Grep: Specific patterns only

## Best Practices Going Forward
1. Use `code search_symbols` before loading files
2. Reference specific files/lines in questions
3. Clear context between unrelated tasks
4. Avoid loading entire directories
