# Layout implementation references

Ladybird is a useful independent implementation reference alongside the CSS
specifications and WebKit comparisons. These notes describe algorithm boundaries
to implement in our assembly engine; they do not add a runtime dependency or
claim that our rendering matches Ladybird.

## Sources reviewed

- [Block layout and floats](https://github.com/LadybirdBrowser/ladybird/blob/e520b408830fee3d66b675a6d9dd8d9c1ef9d30e/Libraries/LibWeb/Rust/src/layout/block_formatting_context.rs)
- [Independent formatting contexts and sizing](https://github.com/LadybirdBrowser/ladybird/blob/e520b408830fee3d66b675a6d9dd8d9c1ef9d30e/Libraries/LibWeb/Rust/src/layout/formatting_context.rs)
- [Flex item sizing](https://github.com/LadybirdBrowser/ladybird/blob/e520b408830fee3d66b675a6d9dd8d9c1ef9d30e/Libraries/LibWeb/Rust/src/layout/flex_formatting_context.rs)

References are pinned to the reviewed repository commit. The current implementation
lives under `Libraries/LibWeb/Rust/src/layout/`; older discussions point to C++
files that are no longer at those paths.

## Application to Oogabooga

1. **Formatting contexts:** distinguish the context that places a box from the
   context that lays out its contents. Give each context explicit available
   dimensions and return its used content dimensions. Native glyph measurement
   should not redefine the containing box after placement.
2. **Float sizing:** resolve edges and containing width before shrink-to-fit.
   For an automatic float width, constrain available content width between
   min-content and max-content widths. Preserve the distinction between definite
   available space and intrinsic sizing constraints.
3. **Automatic height:** obtain independent-context content height from its
   completed layout, with separate flex/Grid/table sizing paths. Avoid estimating
   every container from its aggregate descendant text range.
4. **Flex sizing:** retain distinct base, hypothetical and used sizes. Verify
   main-axis allocation separately from cross-axis measurement and alignment.

## Implemented checks

The current assembly changes include context-scoped macOS float exclusions,
shared source-ordered float avoidance used by both adapters, intrinsic flex gap
contributions and column-flex cross-size aggregation. Private native shaping
stores keep author link colors while scene URLs stay in the main logical source.
The `formatting-contexts` fixture checks float height, panel placement, nested
row sizing and Unicode; native checks also cover link hit regions and paint.

## Regression targets

Use small authored fixtures before changing live-page behavior: a float beside
an overflow container, a floated form followed by a heading, nested flex rows,
and a Grid header spanning two columns. Check box coordinates, painted text,
clipping and link hit regions together. Run the same fixtures on both platforms.
Then compare DuckDuckGo HTML results and Wikipedia against WebKit again.

Ladybird supplies implementation evidence, not the normative definition of CSS.
Follow the specification links in the reviewed code when resolving differences.
Keep production layout algorithms in `src/engine/` assembly and platform adapters
focused on glyph measurement, painting and native controls.

## Remaining boundary work

The macOS fixture still exposes a native paragraph advance before the overflow
panel (one source line in this example). Float contents need a separate shaping
and placement pass to remove that advance without breaking wrapping or nested
floats. The attempted float-isolation change was excluded after the existing
float-wrapping regression caught it. Full generated content/clearfix behavior
and modern Wikipedia toolbar layout also remain unfinished. Passing the reduced
fixture's geometry checks is not a full-page rendering pass.
