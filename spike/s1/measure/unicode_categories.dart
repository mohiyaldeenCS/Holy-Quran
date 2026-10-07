/// The Unicode general category of [codePoint], from the table below, or
/// null when it lies outside the table's blocks or is unassigned there.
String? generalCategory(int codePoint) {
  var low = 0;
  var high = _runs.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final (first, last, category) = _runs[mid];
    if (codePoint < first) {
      high = mid - 1;
    } else if (codePoint > last) {
      low = mid + 1;
    } else {
      return category;
    }
  }
  return null;
}

/// Runs of one general category, ascending, from UnicodeData.txt of Unicode
/// 15.1, over U+0020, U+00A0, the Arabic blocks (U+0600 to U+06FF, U+0750 to
/// U+077F, U+0870 to U+08FF), the format and separator characters of General
/// Punctuation (U+200B to U+200F, U+2028 to U+202E, U+2060 to U+2064),
/// U+25CC and the Arabic Presentation Forms (U+FB50 to U+FDFF, U+FE70 to
/// U+FEFF). Unassigned code points are left out.
const _runs = <(int, int, String)>[
  (0x0020, 0x0020, 'Zs'),
  (0x00A0, 0x00A0, 'Zs'),
  (0x0600, 0x0605, 'Cf'),
  (0x0606, 0x0608, 'Sm'),
  (0x0609, 0x060A, 'Po'),
  (0x060B, 0x060B, 'Sc'),
  (0x060C, 0x060D, 'Po'),
  (0x060E, 0x060F, 'So'),
  (0x0610, 0x061A, 'Mn'),
  (0x061B, 0x061B, 'Po'),
  (0x061C, 0x061C, 'Cf'),
  (0x061D, 0x061F, 'Po'),
  (0x0620, 0x063F, 'Lo'),
  (0x0640, 0x0640, 'Lm'),
  (0x0641, 0x064A, 'Lo'),
  (0x064B, 0x065F, 'Mn'),
  (0x0660, 0x0669, 'Nd'),
  (0x066A, 0x066D, 'Po'),
  (0x066E, 0x066F, 'Lo'),
  (0x0670, 0x0670, 'Mn'),
  (0x0671, 0x06D3, 'Lo'),
  (0x06D4, 0x06D4, 'Po'),
  (0x06D5, 0x06D5, 'Lo'),
  (0x06D6, 0x06DC, 'Mn'),
  (0x06DD, 0x06DD, 'Cf'),
  (0x06DE, 0x06DE, 'So'),
  (0x06DF, 0x06E4, 'Mn'),
  (0x06E5, 0x06E6, 'Lm'),
  (0x06E7, 0x06E8, 'Mn'),
  (0x06E9, 0x06E9, 'So'),
  (0x06EA, 0x06ED, 'Mn'),
  (0x06EE, 0x06EF, 'Lo'),
  (0x06F0, 0x06F9, 'Nd'),
  (0x06FA, 0x06FC, 'Lo'),
  (0x06FD, 0x06FE, 'So'),
  (0x06FF, 0x06FF, 'Lo'),
  (0x0750, 0x077F, 'Lo'),
  (0x0870, 0x0887, 'Lo'),
  (0x0888, 0x0888, 'Sk'),
  (0x0889, 0x088E, 'Lo'),
  (0x0890, 0x0891, 'Cf'),
  (0x0898, 0x089F, 'Mn'),
  (0x08A0, 0x08C8, 'Lo'),
  (0x08C9, 0x08C9, 'Lm'),
  (0x08CA, 0x08E1, 'Mn'),
  (0x08E2, 0x08E2, 'Cf'),
  (0x08E3, 0x08FF, 'Mn'),
  (0x200B, 0x200F, 'Cf'),
  (0x2028, 0x2028, 'Zl'),
  (0x2029, 0x2029, 'Zp'),
  (0x202A, 0x202E, 'Cf'),
  (0x2060, 0x2064, 'Cf'),
  (0x25CC, 0x25CC, 'So'),
  (0xFB50, 0xFBB1, 'Lo'),
  (0xFBB2, 0xFBC2, 'Sk'),
  (0xFBD3, 0xFD3D, 'Lo'),
  (0xFD3E, 0xFD3E, 'Pe'),
  (0xFD3F, 0xFD3F, 'Ps'),
  (0xFD40, 0xFD4F, 'So'),
  (0xFD50, 0xFD8F, 'Lo'),
  (0xFD92, 0xFDC7, 'Lo'),
  (0xFDCF, 0xFDCF, 'So'),
  (0xFDF0, 0xFDFB, 'Lo'),
  (0xFDFC, 0xFDFC, 'Sc'),
  (0xFDFD, 0xFDFF, 'So'),
  (0xFE70, 0xFE74, 'Lo'),
  (0xFE76, 0xFEFC, 'Lo'),
  (0xFEFF, 0xFEFF, 'Cf'),
];
