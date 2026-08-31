import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_system.dart';
import '../../../core/l10n/generated/app_l10n.dart';
import '../coordinates.dart';
import '../gazetteer_loader.dart';
import '../place.dart';

/// Birthplace entry: search the bundled gazetteer, or type coordinates.
///
/// ## Two ways in, because one is not enough
///
/// The gazetteer holds places above 5,000 people. That covers where almost
/// everybody is born and misses villages, home births, and towns renamed
/// since. A birthplace field with no escape hatch is a dead end in the one
/// flow the product depends on, so AC4's manual coordinates are not a nicety —
/// they are what stops the funnel ending here.
///
/// The manual mode explains where to get the numbers. Telling someone to enter
/// a latitude without saying how is much the same as refusing them.
class BirthPlaceField extends ConsumerStatefulWidget {
  const BirthPlaceField({required this.onSelected, super.key});

  /// Called with a resolved place, or null when the entry becomes incomplete.
  final ValueChanged<Place?> onSelected;

  @override
  ConsumerState<BirthPlaceField> createState() => _BirthPlaceFieldState();
}

class _BirthPlaceFieldState extends ConsumerState<BirthPlaceField> {
  final _queryController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _manual = false;
  List<Place> _results = const [];
  Place? _selected;
  CoordinateRejection? _latitudeError;
  CoordinateRejection? _longitudeError;

  @override
  void dispose() {
    _queryController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _manual ? _manualMode(l10n) : _searchMode(l10n),
    );
  }

  List<Widget> _searchMode(AppL10n l10n) {
    final gazetteer = ref.watch(gazetteerProvider);
    final query = _queryController.text.trim();
    return [
      AppTextField(
        label: l10n.birthPlaceLabel,
        hint: l10n.birthPlaceHint,
        helperText: l10n.birthPlaceHelper,
        controller: _queryController,
        isRequired: true,
        onChanged: (value) => _search(gazetteer.value, value),
      ),
      // The asset decodes on a background isolate the first time it is needed.
      // Saying so beats an empty result list, which reads as "no such place".
      if (gazetteer.isLoading) _note(l10n.birthPlaceLoading),
      if (_selected != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: AppKeyValueRow(
            label: _selected!.name,
            value: '${_selected!.latitude}, ${_selected!.longitude}',
          ),
        ),
      for (final place in _results)
        AppListTile(
          title: place.name,
          subtitle: '${place.countryCode} · ${place.timeZoneId}',
          onTap: () => _select(place),
        ),
      if (_results.isEmpty &&
          _selected == null &&
          query.isNotEmpty &&
          !gazetteer.isLoading)
        _note(l10n.birthPlaceNoResults),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: l10n.birthPlaceManualToggle,
        variant: AppButtonVariant.tertiary,
        onPressed: () => setState(() => _manual = true),
      ),
    ];
  }

  List<Widget> _manualMode(AppL10n l10n) {
    return [
      _note(l10n.birthPlaceManualExplainer),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: l10n.birthPlaceLatitude,
        hint: l10n.birthPlaceLatitudeHint,
        controller: _latitudeController,
        isRequired: true,
        errorText: _latitudeError == null
            ? null
            : _coordinateMessage(
                l10n, _latitudeError!, CoordinateAxis.latitude),
        onChanged: (_) => _readCoordinates(),
      ),
      const SizedBox(height: AppSpacing.md),
      AppTextField(
        label: l10n.birthPlaceLongitude,
        hint: l10n.birthPlaceLongitudeHint,
        controller: _longitudeController,
        isRequired: true,
        errorText: _longitudeError == null
            ? null
            : _coordinateMessage(
                l10n, _longitudeError!, CoordinateAxis.longitude),
        onChanged: (_) => _readCoordinates(),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: l10n.birthPlaceSearchToggle,
        variant: AppButtonVariant.tertiary,
        onPressed: () => setState(() => _manual = false),
      ),
    ];
  }

  Widget _note(String text) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Text(
          text,
          style: AppTypography.bodySmall
              .copyWith(color: context.colors.onSurfaceVariant),
        ),
      );

  void _search(Gazetteer? gazetteer, String query) {
    if (gazetteer == null) return;
    setState(() {
      _selected = null;
      _results = gazetteer.search(query);
    });
    widget.onSelected(null);
  }

  void _select(Place place) {
    setState(() {
      _selected = place;
      _results = const [];
      _queryController.text = place.name;
    });
    widget.onSelected(place);
  }

  void _readCoordinates() {
    final latitude =
        parseCoordinate(_latitudeController.text, CoordinateAxis.latitude);
    final longitude =
        parseCoordinate(_longitudeController.text, CoordinateAxis.longitude);

    setState(() {
      // An empty field is not an error while the user is still typing the
      // other one. It just is not a complete answer yet.
      _latitudeError = latitude is CoordinateRejected &&
              latitude.reason != CoordinateRejection.empty
          ? latitude.reason
          : null;
      _longitudeError = longitude is CoordinateRejected &&
              longitude.reason != CoordinateRejection.empty
          ? longitude.reason
          : null;
    });

    if (latitude is! CoordinateParsed || longitude is! CoordinateParsed) {
      widget.onSelected(null);
      return;
    }

    widget.onSelected(
      Place(
        name: '${latitude.degrees}, ${longitude.degrees}',
        countryCode: '',
        latitude: latitude.degrees,
        longitude: longitude.degrees,
        // Deliberately empty. A typed coordinate has no timezone until
        // something resolves one for it, and defaulting to UTC here would
        // silently produce a chart an hour or more out — exactly the failure
        // CLAUDE.md warns about. US-022 owns filling this in.
        timeZoneId: '',
        population: 0,
      ),
    );
  }

  String _coordinateMessage(
    AppL10n l10n,
    CoordinateRejection reason,
    CoordinateAxis axis,
  ) =>
      switch (reason) {
        CoordinateRejection.outOfRange => axis == CoordinateAxis.latitude
            ? l10n.birthPlaceLatitudeOutOfRange
            : l10n.birthPlaceLongitudeOutOfRange,
        _ => l10n.birthPlaceCoordinateMalformed,
      };
}
