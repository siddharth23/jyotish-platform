/// The Jyotish design system.
///
/// Screens import this one file rather than reaching into `tokens/`,
/// `theme/` or `components/` directly.
///
/// ## Known debt: five hardcoded German strings
///
/// `CLAUDE.md` requires UI strings to be externalised via ICU, and these are not.
/// They are accessibility affordances that a component cannot function without and
/// that a caller should not have to supply on every use:
///
/// | String | Where |
/// |---|---|
/// | `Wird geladen` | [AppButton] loading hint, [AppProgressIndicator] |
/// | `Pflichtfeld` | [AppTextField] required marker |
/// | `Schritt N von M` | [AppStepper] position |
/// | `Schliessen` | [AppBottomSheet] close control |
///
/// `lib/core/l10n/` is still empty, so there is nothing to externalise them into
/// yet. **When localisation lands (epic E09), move these to ICU and delete this
/// section.** Until then a screen reader announces them in German regardless of
/// device language, which is wrong for the en-GB locale the product also ships.
///
/// Every other string in this library is passed in by the caller, so the debt does
/// not grow as screens are built on top.
library;

export 'components/app_avatar.dart';
export 'components/app_badge.dart';
export 'components/app_banner.dart';
export 'components/app_bottom_nav.dart';
export 'components/app_bottom_sheet.dart';
export 'components/app_button.dart';
export 'components/app_card.dart';
export 'components/app_checkbox.dart';
export 'components/app_chip.dart';
export 'components/app_dialog.dart';
export 'components/app_divider.dart';
export 'components/app_empty_state.dart';
export 'components/app_error_state.dart';
export 'components/app_icon_button.dart';
export 'components/app_key_value_row.dart';
export 'components/app_list_tile.dart';
export 'components/app_progress_indicator.dart';
export 'components/app_radio_group.dart';
export 'components/app_scaffold.dart';
export 'components/app_section_header.dart';
export 'components/app_segmented_control.dart';
export 'components/app_skeleton.dart';
export 'components/app_snack_bar.dart';
export 'components/app_stepper.dart';
export 'components/app_switch.dart';
export 'components/app_text_field.dart';
export 'theme/app_theme.dart';
export 'theme/app_theme_extension.dart';
export 'tokens/app_colors.dart';
export 'tokens/app_elevation.dart';
export 'tokens/app_motion.dart';
export 'tokens/app_radii.dart';
export 'tokens/app_spacing.dart';
export 'tokens/app_typography.dart';
