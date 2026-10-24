part of '../main.dart';

/// Preserves the document source chooser and isolates platform image I/O.
Future<XFile?> pickExpenseDocumentImage({
  required BuildContext context,
  required bool allowNoImage,
  required Future<XFile?> Function(
    ImageSource source, {
    required int imageQuality,
    required double maxWidth,
    required double maxHeight,
  }) requestImage,
  required void Function(Object error) onError,
}) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Fotografiază acum'),
          onTap: () => Navigator.pop(sheetContext, 'camera'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Alege din galerie'),
          onTap: () => Navigator.pop(sheetContext, 'gallery'),
        ),
        if (allowNoImage)
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Fără fotografie'),
            onTap: () => Navigator.pop(sheetContext, 'none'),
          ),
      ]),
    ),
  );
  if (!context.mounted || source == null || source == 'none') return null;
  try {
    return await requestImage(
      source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
      maxHeight: 2400,
    );
  } catch (error) {
    onError(error);
    return null;
  }
}
