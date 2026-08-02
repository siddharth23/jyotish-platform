/// The Jyotish design system.
///
/// Screens import this one file rather than reaching into `tokens/`,
/// `theme/` or `components/` directly.
///
/// ## Localisation
///
/// Components resolve their own accessibility strings — the loading hint, the
/// required-field marker, the stepper position, the sheet close control — from
/// `AppL10n`. **A host `MaterialApp` must therefore install
/// `AppL10n.delegate` and `supportedLocales`**, or those lookups throw. Every
/// other string is caller-supplied.
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
