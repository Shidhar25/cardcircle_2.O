# Implementation Plan - SVG Visibility & NeoPopButton Theming

Fix the visibility of SVG icons in the navigation bar and align the `NeoPopButton` widget with the new tactile skeuomorphism / Neobrutalist design language.

## Proposed Changes

### [Root](file:///C:/Users/shrid/Downloads/CardCircke/cardcircle_2.O)

#### [MODIFY] [pubspec.yaml](file:///C:/Users/shrid/Downloads/CardCircke/cardcircle_2.O/pubspec.yaml)
- Enable the `assets` section in the `flutter` block.
- Add `assets/icons/` to the assets list to ensure `discover.svg` is bundled with the app.

---

### [shared/widgets](file:///C:/Users/shrid/Downloads/CardCircke/cardcircle_2.O/lib/shared/widgets)

#### [MODIFY] [neo_pop_button.dart](file:///C:/Users/shrid/Downloads/CardCircke/cardcircle_2.O/lib/shared/widgets/neo_pop_button.dart)
- **Import Theme**: Import `../../../core/theme/app_theme.dart`.
- **Factory Updates**:
  - `NeoPopButton.primary`: Use `AppColors.primary` (Lime) and `AppColors.darkText`.
  - `NeoPopButton.secondary`: Use `AppColors.elevated` and `AppColors.mutedForeground`.
  - `NeoPopButton.outline`: Use `AppColors.primary` for the border color.
- **Typography**:
  - Update `NeoPopButtonText` to use the `Syne` or `Space Mono` font from the theme. Specifically, use `Theme.of(context).textTheme.labelLarge` as the base style for that mechanical, typewriter feel.
- **Visual Refinement**:
  - Ensure the "pressed" state and "depth" shadows use the theme's semantic colors for better integration with the `GrittyBackground`.

---

### [features/feed/presentation](file:///C:/Users/shrid/Downloads/CardCircke/cardcircle_2.O/lib/features/feed/presentation)

#### [MODIFY] [tabs_layout.dart](file:///C:/Users/shrid/Downloads/CardCircke/cardcircle_2.O/lib/features/feed/presentation/tabs_layout.dart)
- Ensure the `SvgPicture.asset` usage correctly references the asset path declared in `pubspec.yaml`.

## Verification Plan

### Manual Verification
- **SVG Visibility**: Confirm the Discover icon is visible in the bottom navigation bar.
- **NeoPopButton Audit**:
  - Check the Login button and "Next Step" buttons.
  - Verify they use the **Lime** (`#C6E038`) color and **Space Mono** (Bold) font.
  - Confirm the "depth" shadows look consistent across screens.
  - Check the "pressed" animation for tactile feedback.
