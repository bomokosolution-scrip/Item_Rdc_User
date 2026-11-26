import 'package:flutter/material.dart';

class FolderIconOption {
  final String key;
  final IconData icon;
  final String label;
  const FolderIconOption(this.key, this.icon, this.label);
}

/// Icônes prédéfinies : la clé est enregistrée dans Firestore (champ `icon`)
/// et l'application utilisateur affiche la même icône.
/// ⚠ Gardez les mêmes clés dans l'application utilisateur.
class FolderIcons {
  FolderIcons._();

  static const List<FolderIconOption> options = [
    FolderIconOption('folder', Icons.folder_rounded, 'Folder'),
    FolderIconOption('school', Icons.school_rounded, 'School'),
    FolderIconOption('book', Icons.menu_book_rounded, 'Book'),
    FolderIconOption('science', Icons.science_rounded, 'Science'),
    FolderIconOption('medical', Icons.medical_services_rounded, 'Medical'),
    FolderIconOption('math', Icons.calculate_rounded, 'Math'),
    FolderIconOption('code', Icons.code_rounded, 'Code'),
    FolderIconOption('tech', Icons.computer_rounded, 'Tech'),
    FolderIconOption('language', Icons.translate_rounded, 'Language'),
    FolderIconOption('law', Icons.gavel_rounded, 'Law'),
    FolderIconOption('economy', Icons.account_balance_rounded, 'Economy'),
    FolderIconOption('business', Icons.business_center_rounded, 'Business'),
    FolderIconOption('engineering', Icons.engineering_rounded, 'Engineering'),
    FolderIconOption('biology', Icons.biotech_rounded, 'Biology'),
    FolderIconOption('art', Icons.palette_rounded, 'Art'),
    FolderIconOption('music', Icons.music_note_rounded, 'Music'),
    FolderIconOption('sport', Icons.sports_soccer_rounded, 'Sport'),
    FolderIconOption('exam', Icons.quiz_rounded, 'Exam'),
    FolderIconOption('video', Icons.play_circle_rounded, 'Video'),
    FolderIconOption('star', Icons.star_rounded, 'Star'),
  ];

  static IconData? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final o in options) {
      if (o.key == key) return o.icon;
    }
    return null;
  }
}
