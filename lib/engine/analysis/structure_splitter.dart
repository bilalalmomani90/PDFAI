class PageLite {
  const PageLite(this.number, this.text);
  final int number; // 1-based
  final String text;
}

class OutlineEntry {
  const OutlineEntry(this.title, this.page, this.level);
  final String title;
  final int? page; // 1-based
  final int level; // 1 = top level
}

class SectionInfo {
  const SectionInfo(this.title, this.startPage);
  final String title;
  final int startPage;
  Map<String, Object?> toJson() => {'title': title, 'start_page': startPage};
}

class ChapterInfo {
  const ChapterInfo({
    required this.index,
    required this.title,
    required this.startPage,
    required this.endPage,
    this.sections = const [],
  });
  final int index;
  final String title; // empty = untitled (UI shows "Section n")
  final int startPage;
  final int endPage;
  final List<SectionInfo> sections;

  Map<String, Object?> toJson() => {
        'index': index,
        'title': title,
        'start_page': startPage,
        'end_page': endPage,
        'sections': sections.map((s) => s.toJson()).toList(),
      };
}

class StructureResult {
  const StructureResult(this.source, this.chapters);
  final String source; // outline | headings | fixed
  final List<ChapterInfo> chapters;
  Map<String, Object?> toJson() =>
      {'source': source, 'chapters': chapters.map((c) => c.toJson()).toList()};
}

/// Splits a document into chapters/sections:
/// 1) the PDF's own bookmarks (best), 2) detected headings, 3) fixed-size parts.
class StructureSplitter {
  StructureSplitter._();

  static const maxChapters = 150;
  static const fixedChunkChars = 8000;

  static StructureResult split({
    required List<PageLite> pages,
    required List<OutlineEntry> outline,
  }) {
    final total = pages.isEmpty ? 0 : pages.last.number;
    return _fromOutline(outline, total) ?? _fromHeadings(pages, total) ?? _fixed(pages);
  }

  // ---- 1) bookmarks ----
  static StructureResult? _fromOutline(List<OutlineEntry> outline, int total) {
    final top = outline
        .where((e) =>
            e.level == 1 &&
            e.page != null &&
            e.page! >= 1 &&
            e.page! <= total &&
            e.title.trim().isNotEmpty)
        .toList();
    if (top.length < 2 || top.length > maxChapters) return null;
    top.sort((a, b) => a.page!.compareTo(b.page!)); // stable for equal pages
    final subs = outline
        .where((e) => e.level == 2 && e.page != null && e.title.trim().isNotEmpty)
        .toList();
    return StructureResult('outline', _build(
      [for (final t in top) (t.title.trim(), t.page!)],
      [for (final s in subs) (s.title.trim(), s.page!)],
      total,
    ));
  }

  // ---- 2) headings ----
  static final _kw = RegExp(
      r'^(chapter|part|unit|lesson|section)\s+([0-9]+|[ivxlcdm]+)\b',
      caseSensitive: false);
  static final _kwAr = RegExp(r'^(الفصل|الباب|الجزء|الوحدة|الدرس|القسم)\s+\S+');
  static final _num1 = RegExp(r'^(\d{1,2})[\.\)\-]?\s+(\S.{2,70})$');
  static final _num2 = RegExp(r'^\d{1,2}\.\d{1,2}[\.\)]?\s+\S.{2,70}$');

  static StructureResult? _fromHeadings(List<PageLite> pages, int total) {
    final keyword = <(String, int)>[];
    final numeric = <(String, int, int)>[]; // title, page, number
    final sub = <(String, int)>[];

    String lastKw = '', lastNum = '', lastSub = '';
    for (final p in pages) {
      for (final raw in p.text.split('\n')) {
        final line = raw.trim();
        if (line.isEmpty || line.length > 80) continue;
        final last = line[line.length - 1];
        if (last == ',' || last == ';') continue;

        if (_kw.hasMatch(line) || _kwAr.hasMatch(line)) {
          if (line != lastKw) keyword.add((line, p.number));
          lastKw = line;
          continue;
        }
        if (_num2.hasMatch(line)) {
          if (line != lastSub) sub.add((line, p.number));
          lastSub = line;
          continue;
        }
        final m = _num1.firstMatch(line);
        if (m != null && last != '.') {
          if (line != lastNum) numeric.add((line, p.number, int.parse(m.group(1)!)));
          lastNum = line;
        }
      }
    }

    List<(String, int)> chapters = const [];
    if (keyword.length >= 2) {
      chapters = keyword;
    } else {
      // numbered headings must form the sequence 1, 2, 3, ... (filters out body lists)
      var expected = 1;
      final seq = <(String, int)>[];
      for (final c in numeric) {
        if (c.$3 == expected) {
          seq.add((c.$1, c.$2));
          expected++;
        }
      }
      if (seq.length >= 3) chapters = seq;
    }
    if (chapters.length < 2 || chapters.length > maxChapters) return null;
    return StructureResult('headings', _build(chapters, sub, total));
  }

  // ---- 3) fixed-size parts ----
  static StructureResult _fixed(List<PageLite> pages) {
    if (pages.isEmpty) return const StructureResult('fixed', []);
    final chapters = <ChapterInfo>[];
    var start = pages.first.number;
    var chars = 0;
    for (var i = 0; i < pages.length; i++) {
      chars += pages[i].text.length;
      final isLast = i == pages.length - 1;
      if (chars >= fixedChunkChars || isLast) {
        chapters.add(ChapterInfo(
          index: chapters.length + 1,
          title: '',
          startPage: start,
          endPage: pages[i].number,
        ));
        if (!isLast) start = pages[i + 1].number;
        chars = 0;
      }
    }
    return StructureResult('fixed', chapters);
  }

  static List<ChapterInfo> _build(
    List<(String, int)> chapters,
    List<(String, int)> subs,
    int total,
  ) {
    final out = <ChapterInfo>[];
    for (var i = 0; i < chapters.length; i++) {
      // first chapter also covers any front matter before it
      final start = i == 0 ? 1 : chapters[i].$2;
      final end = i == chapters.length - 1
          ? total
          : (chapters[i + 1].$2 - 1 < start ? start : chapters[i + 1].$2 - 1);
      final sections = [
        for (final s in subs)
          if (s.$2 >= start && s.$2 <= end) SectionInfo(s.$1, s.$2),
      ];
      out.add(ChapterInfo(
        index: i + 1,
        title: chapters[i].$1,
        startPage: start,
        endPage: end,
        sections: sections,
      ));
    }
    return out;
  }
}
