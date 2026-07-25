# CoverWise mobile design direction

## Product mode and job

CoverWise is a read-and-operate mobile product. The primary job is helping a
person understand their own policy without confusing an unverified assistant
draft with evidence-backed coverage information.

## Visual direction

**Policy instrument panel:** calm navy ink, high-contrast blue actions, and
mint as a restrained signal for local/offline capability. The hierarchy is
document-first: source selection, answer, then verification state.

## Tokens

- Ink: `#071B33` — primary text and app identity.
- Ink soft: `#12304F` — secondary dark surfaces.
- Blue: `#2F80ED` — action and navigation emphasis.
- Deep blue: `#145BC7` — primary action on light surfaces.
- Mint: `#5EEAD4` — offline/local capability signal only.
- Cloud: `#F5F8FC` — light background.
- Line: `#DCE6F1` — boundaries and dividers.

Typography uses the existing Material 3 system roles: bold app-bar/title
text, readable body copy, and compact labels for status metadata. Touch targets
remain at least 48dp and the UI must support dark mode, text scaling, focus,
and reduced motion.

## Signature element

Every generated answer carries an explicit verification state. Local mobile
assist is labelled `Not verified`; it never inherits the backend's
evidence-backed state.

## Anti-references and review

Avoid purple gradients, glass effects, sparkle/AI decoration, recursive cards,
and status theatre. For mobile changes, review a debug APK on Android and iOS
devices when available; browser screenshot review is not applicable to the
native Flutter surface. Check narrow phones, dark mode, 200% text scale,
keyboard focus, offline state, and model-preparation failure states.
