// Generates self-contained coverage SVGs from `coverage/lcov.info`.
//
// Outputs:
//   assets/coverage_badge.svg  — shields.io-style flat badge
//   assets/coverage_donut.svg  — donut chart (covered vs uncovered)
//
// Run after `flutter test --coverage`. No external dependencies.

import 'dart:io';
import 'dart:math' as math;

void main(List<String> args) {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run `flutter test --coverage` first.',
    );
    exit(1);
  }

  final stats = _parseLcov(lcov.readAsLinesSync());
  if (stats.found == 0) {
    stderr.writeln('No coverage data in lcov.info.');
    exit(1);
  }

  final pct = (stats.hit * 100 / stats.found).round();

  final assets = Directory('assets')..createSync(recursive: true);

  File(
    '${assets.path}/coverage_badge.svg',
  ).writeAsStringSync(_buildBadge('coverage', '$pct%', pct));
  File(
    '${assets.path}/coverage_donut.svg',
  ).writeAsStringSync(_buildDonut(pct, stats.hit, stats.found));

  stdout.writeln(
    'coverage: $pct% (${stats.hit}/${stats.found} lines) → assets/coverage_*.svg',
  );
}

class _Stats {
  _Stats(this.hit, this.found);
  final int hit;
  final int found;
}

_Stats _parseLcov(List<String> lines) {
  var found = 0;
  var hit = 0;
  for (final line in lines) {
    if (line.startsWith('LF:')) found += int.parse(line.substring(3));
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
  }
  return _Stats(hit, found);
}

// ─── Badge (shields.io flat style) ───────────────────────────────────────────

String _color(int pct) {
  if (pct >= 95) return '#4c1'; // bright green
  if (pct >= 80) return '#97ca00'; // green
  if (pct >= 70) return '#a4a61d'; // yellow-green
  if (pct >= 60) return '#dfb317'; // yellow
  if (pct >= 40) return '#fe7d37'; // orange
  return '#e05d44'; // red
}

// Approx Verdana 11px character widths (in 1/10 px units).
// Good enough for shields-style badges; matches shields.io within ~2px.
double _charWidth(String s, {bool bold = false}) {
  // Average glyph width at 110-units (font-size 110, scaled by 0.1).
  // Empirically: numbers ~70, letters ~70, '%' ~95.
  var sum = 0.0;
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (c == '%') {
      sum += 95;
    } else if (RegExp(r'[il1.,;:]').hasMatch(c)) {
      sum += 35;
    } else if (RegExp(r'[wmWM]').hasMatch(c)) {
      sum += 90;
    } else {
      sum += 70;
    }
  }
  return sum * (bold ? 1.05 : 1.0);
}

String _buildBadge(String label, String value, int pct) {
  // 60-unit padding on each side (≈6px in scaled coords).
  final lwUnits = _charWidth(label) + 100;
  final vwUnits = _charWidth(value) + 100;

  // Convert to displayed pixel widths (10x scale).
  final lw = (lwUnits / 10).round();
  final vw = (vwUnits / 10).round();
  final tw = lw + vw;

  // Center coordinates in scaled units.
  final lx = (lw * 10) ~/ 2;
  final vx = (lw + vw / 2).round() * 10;

  final color = _color(pct);
  final labelTextLen = _charWidth(label).round();
  final valueTextLen = _charWidth(value).round();

  return '''<svg xmlns="http://www.w3.org/2000/svg" width="$tw" height="20" role="img" aria-label="$label: $value">
  <title>$label: $value</title>
  <linearGradient id="s" x2="0" y2="100%">
    <stop offset="0" stop-color="#bbb" stop-opacity=".1"/>
    <stop offset="1" stop-opacity=".1"/>
  </linearGradient>
  <clipPath id="r"><rect width="$tw" height="20" rx="3" fill="#fff"/></clipPath>
  <g clip-path="url(#r)">
    <rect width="$lw" height="20" fill="#555"/>
    <rect x="$lw" width="$vw" height="20" fill="$color"/>
    <rect width="$tw" height="20" fill="url(#s)"/>
  </g>
  <g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110">
    <text aria-hidden="true" x="$lx" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="$labelTextLen">$label</text>
    <text x="$lx" y="140" transform="scale(.1)" fill="#fff" textLength="$labelTextLen">$label</text>
    <text aria-hidden="true" x="$vx" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="$valueTextLen">$value</text>
    <text x="$vx" y="140" transform="scale(.1)" fill="#fff" textLength="$valueTextLen">$value</text>
  </g>
</svg>
''';
}

// ─── Donut chart ─────────────────────────────────────────────────────────────

String _buildDonut(int pct, int hit, int found) {
  const size = 220;
  const center = size / 2;
  const outerR = 90.0;
  const innerR = 60.0;
  const stroke = outerR - innerR;
  const radius = (outerR + innerR) / 2;
  const circumference = 2 * math.pi * radius;

  final coveredLen = circumference * pct / 100;
  final uncoveredLen = circumference - coveredLen;
  final coveredColor = _color(pct);
  const uncoveredColor = '#e05d44';

  // SVG stroke-dasharray rendering for ring.
  // Start at top (rotate -90 deg).
  return '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $size $size" role="img" aria-label="coverage donut: $pct% ($hit of $found lines)">
  <title>coverage: $pct% ($hit/$found lines)</title>
  <g transform="rotate(-90 $center $center)">
    <circle cx="$center" cy="$center" r="$radius" fill="none" stroke="$uncoveredColor" stroke-width="$stroke"/>
    <circle cx="$center" cy="$center" r="$radius" fill="none" stroke="$coveredColor" stroke-width="$stroke"
            stroke-dasharray="${coveredLen.toStringAsFixed(2)} ${uncoveredLen.toStringAsFixed(2)}"/>
  </g>
  <text x="$center" y="$center" text-anchor="middle" dominant-baseline="central"
        font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="36" font-weight="700" fill="#333">$pct%</text>
  <text x="$center" y="${center + 32}" text-anchor="middle" dominant-baseline="central"
        font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="13" fill="#666">$hit / $found lines</text>
</svg>
''';
}
