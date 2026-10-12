/// The interface level of PRD §7.3, lowest first. One setting; «بسيط» by
/// default (`LV-01`).
enum UiLevel {
  simple,
  medium,
  study;

  static const UiLevel initial = simple;
}
