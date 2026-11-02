import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../core/theme/figma_tokens.dart';
import '../core/theme/figma_widgets.dart';
import '../widgets/journal/journal_composer.dart';
import '../widgets/journal/journal_entries_list.dart';

/// Journal screen — mood tracking + daily reflections.
///
/// Composition only. The composer (JournalComposer) owns new-entry state and
/// saving; the entries list (JournalEntriesList) owns loading, grouping,
/// caching, edit and delete. Grouping itself is pure — see
/// [groupJournalEntries].
class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? FigmaTokens.darkBg : FigmaTokens.soft,
      appBar: const CustomAppBar(title: 'Daily journal', centerTitle: false),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const JournalComposer(),
                  const FigmaSectionHead(title: 'Entries by date', note: null),
                ]),
              ),
            ),
            const JournalEntriesList(),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        ),
      ),
    );
  }
}
