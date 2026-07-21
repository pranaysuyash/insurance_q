# Documents screen overflow review — 2026-07-21

## Finding

The empty Documents state was rendered as a fixed-height centered composition
inside the `Expanded` list area. On short mobile viewports, the page header,
upload allowance, upload CTA, and saved-policy heading left less vertical room
than the illustration and explanatory copy needed. Flutter therefore reported a
bottom `RenderFlex` overflow and painted the yellow/black diagnostic stripe.

## Decision

`EmptyStateWidget` now keeps its centered layout when it fits and uses a
vertical `SingleChildScrollView` when the available viewport is shorter than
the composition. This keeps the existing Documents page structure and fixed
navigation intact while also covering larger text scales and other screens that
reuse the shared empty-state widget.

## Verification

- The Documents screen test suite passes.
- A focused short-viewport regression test asserts no Flutter exception and
  confirms the empty-state copy remains present.

## Anything else?

No additional route, storage, upload, or document-list changes are required for
this layout-only defect.
