import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tatislam_app/core/constants/app_colors.dart';
import 'package:tatislam_app/core/constants/app_localizations.dart';
import 'package:tatislam_app/features/admin/presentation/widgets/background_selector.dart';
import 'package:tatislam_app/features/sections/data/section_providers.dart';

/// Full-page screen for creating or editing a section.
class SectionEditorScreen extends ConsumerStatefulWidget {
  final String? sectionId;

  const SectionEditorScreen({super.key, this.sectionId});

  @override
  ConsumerState<SectionEditorScreen> createState() =>
      _SectionEditorScreenState();
}

class _SectionEditorScreenState extends ConsumerState<SectionEditorScreen> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isSaving = false;
  bool? _isVisible;
  String? _backgroundImage;

  bool get _isEditing => widget.sectionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadSection();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSection() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(sectionRepositoryProvider);
      final sections = await repository.getSections(includeHidden: true);
      final section = sections
          .where((s) => s.id == widget.sectionId)
          .firstOrNull;
      if (section != null) {
        _nameController.text = section.name;
        _isVisible = section.isVisible;
        _backgroundImage = section.backgroundImage;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.admin.sectionLoadErrorT}$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.enterSectionName)));
      return;
    }

    if (_isSaving) return; // Prevent double tap

    setState(() => _isSaving = true);
    try {
      final repository = ref.read(sectionRepositoryProvider);

      if (_isEditing) {
        await repository.renameSection(widget.sectionId!, name);
        if (_isVisible != null) {
          await repository.setVisibility(widget.sectionId!, _isVisible!);
        }
        await repository.setBackgroundImage(
          widget.sectionId!,
          _backgroundImage,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.sectionSaved)));
        }
      } else {
        await repository.createSection(name);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppLocalizations.admin.sectionCreated)));
        }
      }

      if (mounted) {
        ref.invalidate(sectionRepositoryProvider);
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.admin.saveError}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.secondary,
        title: Text(_isEditing ? AppLocalizations.admin.editSectionTitle : AppLocalizations.admin.createSectionTitle),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(AppLocalizations.admin.saveAction),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.admin.sectionName,
                      border: const OutlineInputBorder(),
                      counterText: '',
                    ),
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 100,
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: Text(AppLocalizations.admin.showSection),
                      subtitle: Text(AppLocalizations.admin.sectionHiddenInfo),
                      value: _isVisible ?? true,
                      onChanged: (value) {
                        setState(() => _isVisible = value);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 24),
                  BackgroundSelector(
                    value: _backgroundImage,
                    onChanged: (value) {
                      setState(() => _backgroundImage = value);
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
