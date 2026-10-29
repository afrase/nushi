/// The time now, for what the app shows counted from it (an age, "Updated
/// 3m ago", a pull request's last look); tests set their own, a fixed one
/// before each (`flutter_test_config.dart`), so a golden's ages never move.
DateTime Function() clock = DateTime.now;
