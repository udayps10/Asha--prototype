import '../../../core/common_widgets/aasha_surface.dart';
import 'package:flutter/material.dart';
import '../../../core/common_widgets/app_button.dart';
import '../../../core/common_widgets/app_text_field.dart';
import '../../../features/matching/data/models/match_request.dart';
import '../../images/data/image_selection_service.dart';
import '../../images/data/image_upload_api_service.dart';
import '../../images/data/local_image.dart';
import '../../images/presentation/image_source_picker.dart';

class SearchFormScreen extends StatefulWidget {
  const SearchFormScreen({super.key});

  @override
  State<SearchFormScreen> createState() => _SearchFormScreenState();
}

class _SearchFormScreenState extends State<SearchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _detailsController = TextEditingController();
  final ImageSelectionService _imageSelection = LocalImageSelectionService();
  final ImageUploadApiService _imageUpload = HttpImageUploadApiService();
  LocalImage? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final source = await chooseImageSource(context);
    if (source == null) return;
    try {
      final image = await _imageSelection.pickImage(source: source);
      if (image == null) return;
      final validation = await _imageSelection.validateImage(image);
      if (!validation.isValid) {
        _showMessage(validation.message ?? 'Invalid image.');
        return;
      }
      if (mounted) setState(() => _selectedImage = image);
    } catch (error, stackTrace) {
      debugPrint('[USER MATCH][IMAGE_PICK] failed: $error');
      debugPrint('$stackTrace');
      _showMessage('Unable to select the photo. Please try again.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      String? photoReference;
      if (_selectedImage != null) {
        final requestId = 'match_${DateTime.now().microsecondsSinceEpoch}';
        final uploaded = await _imageUpload.uploadMatchInput(
          requestId: requestId,
          image: _selectedImage!,
        );
        photoReference = uploaded.assetId;
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/results',
        arguments: MatchRequest(
          name: _nameController.text.trim(),
          age: int.parse(_ageController.text),
          photoReference: photoReference,
          lastKnownLocation: _locationController.text.trim(),
          additionalDetails: _detailsController.text.trim(),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('[USER MATCH][IMAGE_UPLOAD] failed: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        _showMessage('Unable to upload the photo. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Your Loved One')),
      body: AashaSurface(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us who you’re looking for. Every detail can help us compare response records.',
                  style: TextStyle(
                    color: Color(0xFF536D86),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Container(
                        height: 150,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: _selectedImage == null
                            ? const Icon(
                                Icons.add_a_photo,
                                size: 50,
                                color: Colors.grey,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _selectedImage!.bytes,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _choosePhoto,
                        icon: const Icon(Icons.add_a_photo),
                        label: Text(
                          _selectedImage == null
                              ? 'Upload Photo (Highly Recommended)'
                              : 'Change Photo',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Full Name (Required)',
                  hint: 'Enter full name',
                  controller: _nameController,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Age (Required)',
                  hint: 'Enter age',
                  keyboardType: TextInputType.number,
                  controller: _ageController,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Age is required';
                    if (int.tryParse(val) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Last Known Location (Optional)',
                  hint: 'Where was the person last seen?',
                  controller: _locationController,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Additional Identifying Info (Optional)',
                  hint: 'Tattoos, birthmarks, clothing, etc.',
                  maxLines: 3,
                  controller: _detailsController,
                ),
                const SizedBox(height: 32),
                AppButton(
                  text: 'Search verified records  →',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
