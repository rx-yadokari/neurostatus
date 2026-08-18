import 'package:shared_preferences/shared_preferences.dart';

/// Remembers social contact/group names entered once so they can be
/// re-selected on later entries, the same way custom emotions are.
class ContactsRepository {
  ContactsRepository._();
  static final ContactsRepository instance = ContactsRepository._();

  static const _prefsKey = 'social_contacts';

  Future<List<String>> allContacts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }

  Future<void> addContact(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList(_prefsKey) ?? [];
    if (!contacts.contains(trimmed)) {
      contacts.add(trimmed);
      await prefs.setStringList(_prefsKey, contacts);
    }
  }

  Future<void> removeContact(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = prefs.getStringList(_prefsKey) ?? [];
    contacts.remove(name);
    await prefs.setStringList(_prefsKey, contacts);
  }
}
