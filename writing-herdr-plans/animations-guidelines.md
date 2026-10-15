# Animations Guidelines

Source: `animations.mdc` (design reference). Copy this file's content into the plan as the contract section `## Animation guidelines` whenever the plan has UI tasks, and list `Animation guidelines` in the **Contracts** of every UI task and of the E2E, usability and motion task.

## Keep your animations fast

- Default to `ease-out` for most animations.
- Animations should never be longer than 1s (unless illustrative); most should be around 0.2s to 0.3s.

## Easing rules

- Don't use built-in CSS easings unless it's `ease` or `linear`.
- Use the following easings for their described use case:
  - **`ease-in`** (starts slow, speeds up): generally avoid it; it makes the UI feel slow.
    - `ease-in-quad`: `cubic-bezier(.55, .085, .68, .53)`
    - `ease-in-cubic`: `cubic-bezier(.550, .055, .675, .19)`
    - `ease-in-quart`: `cubic-bezier(.895, .03, .685, .22)`
    - `ease-in-quint`: `cubic-bezier(.755, .05, .855, .06)`
    - `ease-in-expo`: `cubic-bezier(.95, .05, .795, .035)`
    - `ease-in-circ`: `cubic-bezier(.6, .04, .98, .335)`
  - **`ease-out`** (starts fast, slows down): best for elements entering the screen and user-initiated interactions.
    - `ease-out-quad`: `cubic-bezier(.25, .46, .45, .94)`
    - `ease-out-cubic`: `cubic-bezier(.215, .61, .355, 1)`
    - `ease-out-quart`: `cubic-bezier(.165, .84, .44, 1)`
    - `ease-out-quint`: `cubic-bezier(.23, 1, .32, 1)`
    - `ease-out-expo`: `cubic-bezier(.19, 1, .22, 1)`
    - `ease-out-circ`: `cubic-bezier(.075, .82, .165, 1)`
  - **`ease-in-out`** (smooth acceleration and deceleration): for elements moving within the screen.
    - `ease-in-out-quad`: `cubic-bezier(.455, .03, .515, .955)`
    - `ease-in-out-cubic`: `cubic-bezier(.645, .045, .355, 1)`
    - `ease-in-out-quart`: `cubic-bezier(.77, 0, .175, 1)`
    - `ease-in-out-quint`: `cubic-bezier(.86, 0, .07, 1)`
    - `ease-in-out-expo`: `cubic-bezier(1, 0, 0, 1)`
    - `ease-in-out-circ`: `cubic-bezier(.785, .135, .15, .86)`

## Hover transitions

- Use the built-in CSS `ease` with a duration of `200ms` for simple hover transitions like `color`, `background-color`, `opacity`.
- Fall back to the easing rules for more complex hover transitions.
- Disable hover transitions on touch devices with `@media (hover: hover) and (pointer: fine)`.

## Accessibility

- If `transform` is used in an animation, disable it in the `prefers-reduced-motion` media query.

## Origin-aware animations

- Elements animate from their trigger. A dropdown or popover opens from its button: set `transform-origin` according to the trigger position.

## Performance

- Stick to opacity and transforms when possible. Move elements with `transform`, not `top`, `left`, etc.
- Do not animate drag gestures using CSS variables.
- Do not animate blur values higher than 20px.
- Use `will-change` only for `transform`, `opacity`, `clipPath`, `filter`.
- With Motion/Framer Motion, use `transform` instead of `x` or `y` when the animation must be hardware accelerated.

## Spring animations

- Default to spring animations when using Framer Motion.
- Avoid bouncy springs unless working with drag gestures.

## Checks for the E2E, usability and motion task

Each rule above becomes a check the task can run in a browser. Use this table to turn the rules into assertions or evidence.

| Rule | How to check |
|---|---|
| Duration ≤ 1s, most 200–300ms | Read `getComputedStyle(el).transitionDuration` / `animationDuration`, or `el.getAnimations()[i].effect.getTiming().duration`, right after the trigger. |
| Allowed easing only | `transitionTimingFunction` is `ease`, `linear`, `ease-out` or one of the cubic-béziers listed above. Flag `ease-in` and unlisted curves. |
| Hover only on hover devices | In a touch-emulated context (`hasTouch: true`, mobile viewport) hovering changes nothing; the CSS keeps hover rules inside `(hover: hover) and (pointer: fine)`. |
| Reduced motion | Run the same flow with `reducedMotion: 'reduce'` (Playwright context option or `page.emulateMedia`). Assert that no `transform` animation runs: `document.getAnimations()` has no transform keyframes. |
| Origin-aware | Open each dropdown, popover and menu; assert `transform-origin` is not the default center for ones anchored to a trigger. |
| Transform/opacity only | In `getAnimations()` keyframes, no `top`, `left`, `width`, `height`, `margin` properties; blur ≤ 20px. |
| No jank, no layout shift | Trace or screenshot sequence of the key transitions; the page has no visible jump when content loads or a panel opens. |
