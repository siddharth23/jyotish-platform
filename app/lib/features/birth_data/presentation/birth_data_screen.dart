import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../birth_details.dart';

/// Birth date and time entry (US-020).
///
/// ## The screen validates on submit, not on every keystroke
///
/// A date field cannot tell a half-typed `17.0` from a wrong one, so
/// validating as the user types means showing an error for every valid entry
/// on its way to being complete. Errors appear when the user asks to continue,
/// and clear as soon as the offending field changes — which is the point at
/// which the message has stopped being true.
///
/// ## Why the explanation is on the screen rather than behind an info icon
///
/// AC4 asks for it inline. The people most likely to guess at their birth time
/// are the ones who will not open a tooltip to find out whether guessing
/// matters, and a guessed time produces a confident, wrong chart — worse than
/// no time at all, because the solar-chart caveat at least tells the truth.
class BirthDataScreen extends StatefulWidget {
  const BirthDataScreen({this.onSubmit, super.key});

  /// Called with the validated details. Null while there is nowhere to send
  /// them — the profile module (US-014) owns persistence.
  final ValueChanged<BirthDetails>? onSubmit;

  @override
  State<BirthDataScreen> createState() => _BirthDataScreenState();
}

class _BirthDataScreenState extends State<BirthDataScreen> {
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  bool _timeUnknown = false;
  BirthFieldRejection? _dateError;
  BirthFieldRejection? _timeError;

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      title: l10n.birthDataTitle,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.birthDataIntro,
            style: AppTypography.bodyLarge
                .copyWith(color: context.colors.onSurface),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: l10n.birthDateLabel,
            hint: l10n.birthDateHint,
            controller: _dateController,
            isRequired: true,
            keyboardType: TextInputType.datetime,
            textInputAction: TextInputAction.next,
            // Digits and dots only. Stops a paste of "17/05/1990" from
            // reaching the parser as something it will merely reject.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              LengthLimitingTextInputFormatter(10),
            ],
            errorText:
                _dateError == null ? null : _dateMessage(l10n, _dateError!),
            onChanged: (_) => _clearDateError(),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppSwitch(
            label: l10n.birthTimeUnknownLabel,
            value: _timeUnknown,
            onChanged: (value) => setState(() {
              _timeUnknown = value;
              // The field is about to be hidden. Leaving a stale error behind
              // it would block submission with a message nobody can see.
              if (value) _timeError = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_timeUnknown)
            AppBanner(
              tone: AppBannerTone.warning,
              title: l10n.birthTimeUnknownCaveatTitle,
              message: l10n.birthTimeUnknownCaveat,
            )
          else ...[
            AppTextField(
              label: l10n.birthTimeLabel,
              hint: l10n.birthTimeHint,
              helperText: l10n.birthTimeHelper,
              controller: _timeController,
              isRequired: true,
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                LengthLimitingTextInputFormatter(5),
              ],
              errorText:
                  _timeError == null ? null : _timeMessage(l10n, _timeError!),
              onChanged: (_) => _clearTimeError(),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppSectionHeader(title: l10n.birthTimeWhyItMattersTitle),
            Text(
              l10n.birthTimeWhyItMatters,
              style: AppTypography.bodyMedium
                  .copyWith(color: context.colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.birthDataContinue,
            isFullWidth: true,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  void _clearDateError() {
    if (_dateError != null) setState(() => _dateError = null);
  }

  void _clearTimeError() {
    if (_timeError != null) setState(() => _timeError = null);
  }

  void _submit() {
    final now = DateTime.now();
    final today = BirthDate(now.year, now.month, now.day);

    final date = parseGermanDate(_dateController.text, today: today);
    final time = _timeUnknown ? null : parseTime(_timeController.text);

    setState(() {
      _dateError = date is ParseFailure<BirthDate> ? date.reason : null;
      _timeError = time is ParseFailure<BirthTime> ? time.reason : null;
    });

    // Both fields are checked before returning, so someone who got both wrong
    // sees both messages rather than fixing one and discovering the other.
    if (date is! ParseSuccess<BirthDate>) return;
    if (time != null && time is! ParseSuccess<BirthTime>) return;

    widget.onSubmit?.call(
      BirthDetails(
        date: date.value,
        time: time == null ? null : (time as ParseSuccess<BirthTime>).value,
      ),
    );
  }

  String _dateMessage(AppL10n l10n, BirthFieldRejection reason) =>
      switch (reason) {
        BirthFieldRejection.empty ||
        BirthFieldRejection.malformed =>
          l10n.birthDateErrorMalformed,
        BirthFieldRejection.notACalendarDate =>
          l10n.birthDateErrorNotACalendarDate,
        BirthFieldRejection.inTheFuture => l10n.birthDateErrorInFuture,
        BirthFieldRejection.tooEarly => l10n.birthDateErrorTooEarly,
        BirthFieldRejection.outOfRange => l10n.birthDateErrorMalformed,
      };

  String _timeMessage(AppL10n l10n, BirthFieldRejection reason) =>
      switch (reason) {
        BirthFieldRejection.outOfRange => l10n.birthTimeErrorOutOfRange,
        _ => l10n.birthTimeErrorMalformed,
      };
}
