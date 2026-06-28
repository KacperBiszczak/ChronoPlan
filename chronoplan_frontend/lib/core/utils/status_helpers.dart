import 'package:flutter/material.dart';

class AppTaskStatus {
  static String label(String status) {
    switch (status) {
      case 'TODO':
        return 'Do zrobienia';
      case 'IN_PROGRESS':
        return 'W trakcie';
      case 'DONE':
        return 'Zrobione';
      default:
        return status;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case 'TODO':
        return Icons.radio_button_unchecked;
      case 'IN_PROGRESS':
        return Icons.timelapse;
      case 'DONE':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'TODO':
        return Colors.grey;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'DONE':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }
}

class AppParticipantStatus {
  static String label(String status) {
    switch (status) {
      case 'INVITED':
        return 'Zaproszony';
      case 'ACCEPTED':
        return 'Zaakceptował';
      case 'DECLINED':
        return 'Odrzucił';
      default:
        return status;
    }
  }

  static Color color(String status) {
    switch (status) {
      case 'INVITED':
        return Colors.orange;
      case 'ACCEPTED':
        return Colors.green;
      case 'DECLINED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class AppEventRole {
  static String label(String role) {
    switch (role) {
      case 'ORGANIZER':
        return 'Organizator';
      case 'PARTICIPANT':
        return 'Uczestnik';
      default:
        return role;
    }
  }

  static Color color(String role) {
    switch (role) {
      case 'ORGANIZER':
        return Colors.blue;
      case 'PARTICIPANT':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}