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

## Design conformance

The Documents surface now uses the canonical `CoverWiseSectionLabel` hierarchy
for the saved-policy section, rounded refresh icons for navigation/actions, and
the rounded upload-file icon for the primary empty-state action. The existing
`first-policy.png` remains the canonical generated scene: a new image-generation
candidate was reviewed, but it was not adopted because the existing scene has
stronger policy-review meaning through its document, folder, lens, and shield
composition and already satisfies the asset contract.

## Verification

- The Documents screen test suite passes.
- A focused short-viewport regression test asserts no Flutter exception and
  confirms the empty-state copy remains present.
- The current checkout rebuilt successfully and launched on the iPhone 17 Pro
  iOS Simulator. A live serve-sim inspection after the section-label/icon pass
  showed the illustration, `No saved policies yet`, and the explanatory copy
  without the overflow diagnostic stripe. The final compact-spacing adjustment
  is covered by the focused tests and successful rebuild; a second final
  screenshot was not captured because the simulator stream disconnected after
  relaunch.

## Scope correction

The current checkout also changes the upload affordance beyond the overflow
fix: an empty library shows `Add policy file`, a populated library shows the
compact `Add new policy` CTA, and the expanded upload panel is shown only after
a file has been selected. This is a coherent UX direction, but it is an upload
journey change rather than a layout-only change.

The current focused tests cover the empty state, saved-policy rendering, and
the populated `Add new policy` CTA, but do not cover the selected-file panel or
provider-loading transition. Add those assertions before treating the entire
upload-surface change as closed. No route, storage, or server contract change
was observed.
