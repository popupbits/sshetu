# iOS: characters mangled when typing is driven by WebDriverAgent

**Status:** open, cause not established. Not reproduced with a human typing on
the software keyboard, because that path could not be exercised — see below.

## What was seen

On an **iPhone 17 Pro simulator, iOS 26.4**, with a live SSH session open and
the terminal focused, sending `uname -s; echo IOS_OK` through
`device_type` (which drives typing via WebDriverAgent) put this on the prompt:

```
unnaname --s-s; echo IOS_OK
```

Reading the mangling: `u`, `n`, `na`, `name` — each keystroke delivered the
whole accumulated string again rather than the one new character. Consistent
with the platform ignoring the `setEditingState(_initEditingState)` reset that
`packages/xterm2/lib/src/ui/custom_text_edit.dart` performs after every
insertion, so the delta — computed as "everything past the reset baseline" —
is the entire buffer each time.

The same session typed **correctly** in every other respect: the shell ran,
`IOS_OK` printed, arrows and the modifier bar worked, and Android does not show
this at all.

## What was tried, and why it was reverted

A common-prefix diff against the last value the platform actually sent, instead
of against the reset baseline. It is the obviously correct-looking fix, and it
made things **worse**: the same input then arrived as

```
una -s; ho IOS_TYPING_OK
```

— characters *dropped* rather than duplicated. So the platform is not simply
sending cumulative values either; some updates must arrive with a composing
region, or out of order, or the reset is honoured intermittently. The model was
wrong, and the patch was reverted rather than shipped. For a terminal, silently
losing a keystroke is worse than the bug being fixed: a dropped character can
change what a command means.

## Why it is not proven to affect users

`device_type` on iOS types through WebDriverAgent, which is not necessarily
what a finger on the on-screen keyboard produces. Direct taps on the simulator's
software keyboard did not register through the automation, so the ordinary path
— a person typing — was never exercised.

## How to settle it

1. Type into a session **by hand** on a real device or a simulator you are
   driving with your own keyboard, and see whether the mangling happens at all.
2. If it does, log every `updateEditingValue` (text, selection, composing) in
   `CustomTextEdit.updateEditingValue` and read the actual sequence rather than
   inferring it from the output. The fix follows from the sequence; guessing at
   it produced two wrong patches already.
3. If it does not, this is a WebDriverAgent artefact and the note can be
   deleted — but the automation caveat is worth keeping in mind for any future
   iOS input testing.
