import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/account/account_repository.dart';
import 'package:lichess_mobile/src/model/user/user.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/view/user/countries.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform_alert_dialog.dart';
import 'package:result_extensions/result_extensions.dart';

final _countries = countries.values.toList();

class EditProfileScreen extends StatelessWidget {
  EditProfileScreen({Key? key}) : super(key: key);

  // Global key to access form state and dirty flag
  final GlobalKey<_EditProfileFormState> _formKey = GlobalKey();

  Future<bool?> _showBackDialog(BuildContext context) {
    return showAdaptiveDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog.adaptive(
          title: Text(context.l10n.mobileAreYouSure),
          content: const Text('Your changes will be lost.'),
          actions: [
            PlatformDialogAction(
              child: Text(context.l10n.cancel),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            PlatformDialogAction(
              child: Text(context.l10n.ok),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.editProfile)),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, _) async {
          if (didPop) return;
          // Check if form has unsaved changes
          final bool hasChanges = _formKey.currentState?._isDirty ?? false;
          if (hasChanges) {
            final bool? shouldPop = await _showBackDialog(context);
            if (shouldPop ?? false) Navigator.of(context).pop();
          } else {
            Navigator.of(context).pop();
          }
        },
        // Pass formKey down so child can mark dirty
        child: _Body(formKey: _formKey),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final GlobalKey<_EditProfileFormState> formKey;
  const _Body({required this.formKey, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    return account.when(
      data: (data) {
        if (data == null) {
          return Center(child: Text(context.l10n.mobileMustBeLoggedIn));
        }
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: Styles.bodyPadding.copyWith(top: 0, bottom: 0),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                SizedBox(height: Styles.bodyPadding.top),
                Text(context.l10n.allInformationIsPublicAndOptional),
                const SizedBox(height: 16),
                // Attach the GlobalKey to the form widget
                _EditProfileForm(data, key: formKey),
                SizedBox(height: Styles.bodyPadding.bottom),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (err, stack) => Center(child: Text(err.toString())),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm(this.user, {Key? key}) : super(key: key);

  final User user;

  @override
  _EditProfileFormState createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isDirty = false;

  final _formData = <String, dynamic>{
    'flag': null,
    'location': null,
    'bio': null,
    'firstName': null,
    'lastName': null,
    'fideRating': null,
    'uscfRating': null,
    'ecfRating': null,
    'rcfRating': null,
    'cfcRating': null,
    'dsbRating': null,
    'links': null,
  };

  Future<void>? _pendingSaveProfile;

  void _markAsDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final String? initialLinks = widget.user.profile?.links?.map((e) => e.url).join('\r\n');
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _TextField(
            label: context.l10n.biography,
            initialValue: widget.user.profile?.bio,
            formKey: 'bio',
            formData: _formData,
            description: context.l10n.biographyDescription,
            maxLength: 400,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            onChanged: _markAsDirty,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: FormField<String>(
              initialValue: widget.user.profile?.country,
              validator: (value) => (value == null || !countries.containsKey(value))
                  ? 'Please select a valid country'
                  : null,
              onSaved: (value) => _formData['flag'] = value,
              builder: (FormFieldState<String> field) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.countryRegion, style: Styles.formLabel),
                    const SizedBox(height: 6.0),
                    Autocomplete<String>(
                      initialValue: field.value != null
                          ? TextEditingValue(text: countries[field.value]!)
                          : null,
                      optionsBuilder: (TextEditingValue value) {
                        if (value.text.isEmpty) return const Iterable<String>.empty();
                        return _countries.where((option)
                          => option.toLowerCase().contains(value.text.toLowerCase())
                        );
                      },
                      onSelected: (selection) {
                        final country = countries.entries.firstWhere(
                          (e) => e.value == selection,
                        );
                        field.didChange(country.key);
                        _markAsDirty();
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          _TextField(
            label: context.l10n.location,
            initialValue: widget.user.profile?.location,
            formKey: 'location',
            formData: _formData,
            maxLength: 80,
            onChanged: _markAsDirty,
          ),
          _TextField(
            label: context.l10n.realName,
            initialValue: widget.user.profile?.realName,
            formKey: 'realName',
            formData: _formData,
            maxLength: 20,
            onChanged: _markAsDirty,
          ),
          _NumericField(
            label: context.l10n.xRating('FIDE'),
            initialValue: widget.user.profile?.fideRating,
            formKey: 'fideRating',
            formData: _formData,
            validator: (value) {
              if (value != null && (value < 1400 || value > 3000)) {
                return 'Rating must be between 1400 and 3000';
              }
              return null;
            },
            onChanged: _markAsDirty,
          ),
          _NumericField(
            label: context.l10n.xRating('USCF'),
            initialValue: widget.user.profile?.uscfRating,
            formKey: 'uscfRating',
            formData: _formData,
            validator: (value) {
              if (value != null && (value < 100 || value > 3000)) {
                return 'Rating must be between 100 and 3000';
              }
              return null;
            },
            onChanged: _markAsDirty,
          ),
          _NumericField(
            label: context.l10n.xRating('ECF'),
            initialValue: widget.user.profile?.ecfRating,
            formKey: 'ecfRating',
            formData: _formData,
            validator: (value) {
              if (value != null && (value < 0 || value > 3000)) {
                return 'Rating must be between 0 and 3000';
              }
              return null;
            },
            onChanged: _markAsDirty,
          ),
          _TextField(
            label: context.l10n.socialMediaLinks,
            initialValue: initialLinks,
            formKey: 'links',
            formData: _formData,
            maxLength: 3000,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            description: 'Mastodon, Facebook, GitHub, Chess.com, ...\r\n${context.l10n.oneUrlPerLine}',
            onChanged: _markAsDirty,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: FutureBuilder(
              future: _pendingSaveProfile,
              builder: (context, snapshot) {
                return FatButton(
                  semanticsLabel: context.l10n.apply,
                  onPressed: snapshot.connectionState == ConnectionState.waiting
                      ? null
                      : () async {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            _formData.removeWhere((key, value) =>
                              value == null || (value is String && value.trim().isEmpty)
                            );
                            final future = Result.capture(
                              ref.withClient((client) =>
                                AccountRepository(client).saveProfile(
                                  _formData.map((k, v) => MapEntry(k, v.toString())),
                                ),
                              ),
                            );
                            setState(() => _pendingSaveProfile = future);
                            final result = await future;
                            result.match(
                              onError: (err, _) {
                                if (context.mounted) showSnackBar(
                                  context,
                                  'Something went wrong',
                                  type: SnackBarType.error,
                                );
                              },
                              onSuccess: (_) {
                                if (context.mounted) {
                                  ref.invalidate(accountProvider);
                                  showSnackBar(
                                    context,
                                    context.l10n.success,
                                    type: SnackBarType.success,
                                  );
                                  Navigator.of(context).pop();
                                }
                              },
                            );
                          }
                        },
                  child: Text(context.l10n.apply),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NumericField extends StatefulWidget {
  final String label;
  final int? initialValue;
  final String formKey;
  final String? Function(int?)? validator;
  final Map<String, dynamic> formData;
  final VoidCallback? onChanged;
  const _NumericField({
    required this.label,
    required this.initialValue,
    required this.formKey,
    required this.validator,
    required this.formData,
    this.onChanged,
  });

  @override
  State<_NumericField> createState() => __NumericFieldState();
}

class __NumericFieldState extends State<_NumericField> {
  final _controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue?.toString() ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FormField<int>(
        initialValue: widget.initialValue,
        onSaved: (value) => widget.formData[widget.formKey] = value,
        validator: widget.validator,
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: Styles.formLabel),
              const SizedBox(height: 6.0),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(errorText: field.errorText),
                onChanged: (value) {
                  field.didChange(int.tryParse(value));
                  widget.onChanged?.call();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  final String label;
  final String? initialValue;
  final String formKey;
  final String? description;
  final int? maxLength;
  final int? maxLines;
  final Map<String, dynamic> formData;
  final TextInputAction textInputAction;
  final VoidCallback? onChanged;
  const _TextField({
    required this.label,
    required this.initialValue,
    required this.formKey,
    required this.formData,
    this.description,
    this.maxLength,
    this.maxLines,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
  });

  @override
  State<_TextField> createState() => __TextFieldState();
}

class __TextFieldState extends State<_TextField> {
  final _controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: FormField<String>(
        initialValue: widget.initialValue,
        onSaved: (value) => widget.formData[widget.formKey] = value?.trim(),
        builder: (field) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.label, style: Styles.formLabel),
              const SizedBox(height: 6.0),
              TextField(
                maxLength: widget.maxLength,
                maxLines: widget.maxLines,
                controller: _controller,
                decoration: InputDecoration(errorText: field.errorText),
                textInputAction: widget.textInputAction,
                onChanged: (value) {
                  field.didChange(value.trim());
                  widget.onChanged?.call();
                },
              ),
              if (widget.description != null) ...[
                const SizedBox(height: 6.0),
                Text(widget.description!, style: Styles.formDescription),
              ],
            ],
          );
        },
      ),
    );
  }
}
