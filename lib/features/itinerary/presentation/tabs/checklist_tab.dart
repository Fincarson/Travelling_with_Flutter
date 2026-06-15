part of travel_agent_app;

class ChecklistTab extends StatefulWidget {
  const ChecklistTab({required this.trip, required this.onSave, super.key});

  final Trip trip;
  final ValueChanged<Trip> onSave;

  @override
  State<ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<ChecklistTab> {
  final Map<int, TextEditingController> _addItemControllers = {};
  int? _editingCategoryIndex;

  Trip get trip => widget.trip;

  @override
  void dispose() {
    for (final controller in _addItemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _saveChecklist(List<ChecklistCategory> checklist) {
    widget.onSave(trip.copyWith(checklist: checklist));
  }

  void _toggleItem(int categoryIndex, int itemIndex, bool? value) {
    final categories = [...trip.checklist];
    if (!_hasItem(categories, categoryIndex, itemIndex)) return;
    final category = categories[categoryIndex];
    final items = [...category.items];
    items[itemIndex] = _checklistItemWithCheckedState(
      items[itemIndex],
      value ?? false,
    );
    categories[categoryIndex] = ChecklistCategory(category.category, items);
    _saveChecklist(categories);
  }

  void _renameCategory(int categoryIndex, String value) {
    final categories = [...trip.checklist];
    if (categoryIndex < 0 || categoryIndex >= categories.length) return;
    final category = categories[categoryIndex];
    categories[categoryIndex] = ChecklistCategory(
      value.trim().isEmpty ? category.category : value,
      category.items,
    );
    _saveChecklist(categories);
  }

  void _renameItem(int categoryIndex, int itemIndex, String value) {
    final categories = [...trip.checklist];
    if (!_hasItem(categories, categoryIndex, itemIndex)) return;
    final category = categories[categoryIndex];
    final items = [...category.items];
    if (value.trim().isEmpty) return;
    items[itemIndex] = _checklistItemWithDisplayText(items[itemIndex], value);
    categories[categoryIndex] = ChecklistCategory(category.category, items);
    _saveChecklist(categories);
  }

  void _deleteItem(int categoryIndex, int itemIndex) {
    final categories = [...trip.checklist];
    if (!_hasItem(categories, categoryIndex, itemIndex)) return;
    final category = categories[categoryIndex];
    final items = [...category.items]..removeAt(itemIndex);
    categories[categoryIndex] = ChecklistCategory(category.category, items);
    _saveChecklist(categories);
  }

  void _addItem(int categoryIndex) {
    final controller = _addItemControllers[categoryIndex];
    final text = controller?.text.trim() ?? '';
    if (text.isEmpty) return;
    final categories = [...trip.checklist];
    if (categoryIndex < 0 || categoryIndex >= categories.length) return;
    final category = categories[categoryIndex];
    categories[categoryIndex] = ChecklistCategory(category.category, [
      ...category.items,
      text,
    ]);
    controller?.clear();
    _saveChecklist(categories);
  }

  void _addCategory() {
    final categories = [
      ...trip.checklist,
      const ChecklistCategory('New category', []),
    ];
    _saveChecklist(categories);
    setState(() => _editingCategoryIndex = categories.length - 1);
  }

  bool _hasItem(
    List<ChecklistCategory> categories,
    int categoryIndex,
    int itemIndex,
  ) {
    return categoryIndex >= 0 &&
        categoryIndex < categories.length &&
        itemIndex >= 0 &&
        itemIndex < categories[categoryIndex].items.length;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: _responsivePagePadding(context, top: 16, bottom: 112),
      children: [
        for (
          var categoryIndex = 0;
          categoryIndex < trip.checklist.length;
          categoryIndex++
        )
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _ChecklistCategoryPanel(
              category: trip.checklist[categoryIndex],
              categoryIndex: categoryIndex,
              editing: _editingCategoryIndex == categoryIndex,
              addController: _addItemControllers.putIfAbsent(
                categoryIndex,
                TextEditingController.new,
              ),
              onToggleEdit: () => setState(() {
                _editingCategoryIndex = _editingCategoryIndex == categoryIndex
                    ? null
                    : categoryIndex;
              }),
              onRenameCategory: (value) =>
                  _renameCategory(categoryIndex, value),
              onToggleItem: (itemIndex, value) =>
                  _toggleItem(categoryIndex, itemIndex, value),
              onRenameItem: (itemIndex, value) =>
                  _renameItem(categoryIndex, itemIndex, value),
              onDeleteItem: (itemIndex) =>
                  _deleteItem(categoryIndex, itemIndex),
              onAddItem: () => _addItem(categoryIndex),
            ),
          ),
        PrimaryButton(
          label: 'Add category',
          icon: Icons.add_rounded,
          onPressed: _addCategory,
        ),
      ],
    );
  }
}

class _ChecklistCategoryPanel extends StatelessWidget {
  const _ChecklistCategoryPanel({
    required this.category,
    required this.categoryIndex,
    required this.editing,
    required this.addController,
    required this.onToggleEdit,
    required this.onRenameCategory,
    required this.onToggleItem,
    required this.onRenameItem,
    required this.onDeleteItem,
    required this.onAddItem,
  });

  final ChecklistCategory category;
  final int categoryIndex;
  final bool editing;
  final TextEditingController addController;
  final VoidCallback onToggleEdit;
  final ValueChanged<String> onRenameCategory;
  final void Function(int itemIndex, bool? value) onToggleItem;
  final void Function(int itemIndex, String value) onRenameItem;
  final ValueChanged<int> onDeleteItem;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final addButton = ValueListenableBuilder<TextEditingValue>(
      valueListenable: addController,
      builder: (context, value, _) {
        if (value.text.trim().isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: appText(context, 'Add'),
          onPressed: onAddItem,
          icon: const Icon(Icons.check_rounded),
          color: _primary,
        );
      },
    );

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: editing
                    ? TextFormField(
                        key: ValueKey('category-$categoryIndex-editor'),
                        initialValue: category.category,
                        decoration: InputDecoration(
                          labelText: appText(context, 'Category name'),
                        ),
                        onChanged: onRenameCategory,
                      )
                    : Text(
                        appText(context, category.category),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              IconButton.filledTonal(
                tooltip: appText(context, editing ? 'Done' : 'Edit'),
                onPressed: onToggleEdit,
                icon: Icon(editing ? Icons.check_rounded : Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (
            var itemIndex = 0;
            itemIndex < category.items.length;
            itemIndex++
          )
            _ChecklistItemRow(
              key: ValueKey('checklist-$categoryIndex-$itemIndex'),
              item: category.items[itemIndex],
              itemIndex: itemIndex,
              editing: editing,
              onToggle: (value) => onToggleItem(itemIndex, value),
              onRename: (value) => onRenameItem(itemIndex, value),
              onDelete: () => onDeleteItem(itemIndex),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: _ChecklistItemRow.controlExtent),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: _ChecklistItemRow.rowHeight,
                  child: TextField(
                    controller: addController,
                    decoration: _checklistUnderlineDecoration(
                      context,
                      'New item',
                      suffix: SizedBox.square(
                        dimension: _ChecklistItemRow.controlExtent,
                        child: addButton,
                      ),
                    ),
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlignVertical: TextAlignVertical.center,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAddItem(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    required this.item,
    required this.itemIndex,
    required this.editing,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final String item;
  final int itemIndex;
  final bool editing;
  final ValueChanged<bool?> onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  static const rowHeight = 44.0;
  static const controlExtent = 40.0;

  @override
  Widget build(BuildContext context) {
    final isAiAdded = _isAiChecklistItem(item);
    final checked = _isChecklistItemChecked(item);
    final displayText = _checklistDisplayText(item);

    return SizedBox(
      height: rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: controlExtent,
            child: editing
                ? IconButton(
                    tooltip: appText(context, 'Delete'),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: const Color(0xFFE5484D),
                  )
                : Checkbox(
                    value: checked,
                    onChanged: onToggle,
                    activeColor: _primary,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: rowHeight,
              child: editing
                  ? TextFormField(
                      key: ValueKey('item-$itemIndex-editor'),
                      initialValue: displayText,
                      decoration: _checklistUnderlineDecoration(
                        context,
                        'Checklist item',
                      ),
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlignVertical: TextAlignVertical.center,
                      onChanged: onRename,
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        appText(context, displayText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          color: isAiAdded
                              ? const Color(0xFFB7791F)
                              : checked
                              ? _secondary
                              : null,
                          fontWeight: isAiAdded
                              ? FontWeight.w900
                              : FontWeight.w700,
                          backgroundColor: isAiAdded
                              ? const Color(0xFFFFF3BF)
                              : null,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _checklistUnderlineDecoration(
  BuildContext context,
  String label, {
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: appText(context, label),
    isDense: true,
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(
      minWidth: _ChecklistItemRow.controlExtent,
      minHeight: _ChecklistItemRow.controlExtent,
    ),
    contentPadding: const EdgeInsets.only(top: 8, bottom: 8),
    border: const UnderlineInputBorder(),
    enabledBorder: UnderlineInputBorder(
      borderSide: BorderSide(color: _secondary.withValues(alpha: .32)),
    ),
    focusedBorder: const UnderlineInputBorder(
      borderSide: BorderSide(color: _primary, width: 2),
    ),
  );
}
