const int _asciiZero = 0x0030;
const int _arabicIndicZero = 0x0660;

/// Writes [n] in Arabic-Indic digits, as every number in the interface is.
String arabicDigits(int n) {
  if (n < 0) throw ArgumentError.value(n, 'n', 'must not be negative');
  return String.fromCharCodes(
    n.toString().codeUnits.map((unit) => unit - _asciiZero + _arabicIndicZero),
  );
}
