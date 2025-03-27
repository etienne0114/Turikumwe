// lib/utils/web_file_picker_stub.dart
// This is a stub file to avoid errors when importing file_picker conditionally

class FilePicker {
  static FilePicker get platform => FilePicker._();
  
  FilePicker._();
  
  Future<FilePickerResult?> pickFiles({
    FileType type = FileType.any,
    bool allowMultiple = false,
    String? dialogTitle,
    String? initialDirectory,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
  }) async {
    return null;
  }
}

class FilePickerResult {
  final List<PlatformFile> files;
  
  FilePickerResult(this.files);
}

class PlatformFile {
  final String? path;
  final String name;
  final int size;
  
  PlatformFile({required this.name, required this.size, this.path});
}

enum FileType {
  any,
  media,
  image,
  video,
  audio,
  custom
}

enum FilePickerStatus {
  picking,
  done
}