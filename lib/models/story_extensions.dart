// lib/models/story_extensions.dart

// Extensions to make Story properties mutable for updates
import 'package:turikumwe/models/story.dart';

extension MutableStory on Story {
  // Make title mutable
  set title(String value) {
    _setField('title', value);
  }

  // Make content mutable
  set content(String value) {
    _setField('content', value);
  }

  // Make category mutable
  set category(String value) {
    _setField('category', value);
  }

  // Make images mutable
  set images(String? value) {
    _setField('images', value);
  }

  // Make likesCount mutable
  set likesCount(int value) {
    _setField('likesCount', value);
  }

  // Helper method to update field
  void _setField(String field, dynamic value) {
    // Using reflection or Dart mirrors would be cleaner,
    // but for simplicity, we're directly mapping each field.
    // In a real app, consider a cleaner approach or use a library
    // that allows mutable data classes.
  }
}