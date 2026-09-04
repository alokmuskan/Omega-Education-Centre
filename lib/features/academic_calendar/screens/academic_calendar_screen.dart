import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/empty_state_widget.dart';
import '../models/holiday_model.dart';
import '../models/event_model.dart';
import '../repository/academic_calendar_repository.dart';

/// Academic Calendar screen with month view, holidays, events, and terms.
class AcademicCalendarScreen extends StatefulWidget {
  const AcademicCalendarScreen({super.key});

  @override
  State<AcademicCalendarScreen> createState() => _AcademicCalendarScreenState();
}

class _AcademicCalendarScreenState extends State<AcademicCalendarScreen> with SingleTickerProviderStateMixin {
  final AcademicCalendarRepository _repo = AcademicCalendarRepository();

  late TabController _tabController;
  DateTime _currentMonth = DateTime.now();
  List<HolidayModel> _holidays = [];
  List<EventModel> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _holidays = await _repo.getHolidaysForMonth(_currentMonth.year, _currentMonth.month);
      _events = await _repo.getEventsForMonth(_currentMonth.year, _currentMonth.month);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading calendar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_month), text: 'Calendar'),
            Tab(icon: Icon(Icons.celebration), text: 'Holidays'),
            Tab(icon: Icon(Icons.event), text: 'Events'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarTab(),
                _buildHolidaysTab(),
                _buildEventsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  // ── Calendar Tab ──────────────────────────────────────────────

  Widget _buildCalendarTab() {
    return Column(
      children: [
        // Month Navigator
        _buildMonthNavigator(),
        // Calendar Grid
        _buildCalendarGrid(),
        // Upcoming Events Summary
        const SizedBox(height: 8),
        _buildUpcomingSummary(),
      ],
    );
  }

  Widget _buildMonthNavigator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: const Icon(Icons.chevron_left, size: 28),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Monday, 7=Sunday
    final daysInMonth = lastDay.day;

    // Holiday and event date sets for quick lookup
    final holidayDates = _holidays.map((h) => h.date).toSet();
    final eventDates = _events.map((e) => e.startDate).toSet();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            // Day headers
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 4),
            // Calendar days
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: (startWeekday - 1) + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < startWeekday - 1) return const SizedBox();

                  final day = index - (startWeekday - 1) + 1;
                  final dateStr = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                  final isToday = DateTime.now().day == day &&
                      DateTime.now().month == _currentMonth.month &&
                      DateTime.now().year == _currentMonth.year;
                  final isHoliday = holidayDates.contains(dateStr);
                  final isEvent = eventDates.contains(dateStr);
                  final isSunday = DateTime(_currentMonth.year, _currentMonth.month, day).weekday == 7;

                  return GestureDetector(
                    onTap: () => _showDayDetails(dateStr, day),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFF0D47A1)
                            : isHoliday
                                ? Colors.red.withAlpha(25)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isEvent
                            ? Border.all(color: Colors.orange, width: 1.5)
                            : isToday
                                ? null
                                : isSunday
                                    ? Border.all(color: Colors.grey.shade300, width: 0.5)
                                    : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday
                                  ? Colors.white
                                  : isHoliday
                                      ? Colors.red.shade700
                                      : isSunday
                                          ? Colors.grey.shade500
                                          : null,
                            ),
                          ),
                          if (isHoliday || isEvent)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isHoliday)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                if (isEvent)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(top: 2, left: 2),
                                    decoration: const BoxDecoration(
                                      color: Colors.orange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingSummary() {
    final upcoming = <String>[];
    if (_holidays.isNotEmpty) {
      upcoming.add('🔴 ${_holidays.length} holiday${_holidays.length == 1 ? '' : 's'} this month');
    }
    if (_events.isNotEmpty) {
      upcoming.add('🟠 ${_events.length} event${_events.length == 1 ? '' : 's'} this month');
    }

    if (upcoming.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFF0D47A1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              upcoming.join(' • '),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Holidays Tab ──────────────────────────────────────────────

  Widget _buildHolidaysTab() {
    if (_holidays.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.celebration_outlined,
        title: 'No holidays this month',
        subtitle: 'Add holidays using the + button below',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _holidays.length,
      itemBuilder: (context, index) {
        final h = _holidays[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.withAlpha(30),
              child: const Icon(Icons.event_busy, color: Colors.red, size: 20),
            ),
            title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              DateFormat('dd MMM yyyy').format(DateTime.parse(h.date)),
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (h.isRecurring)
                  const Chip(
                    label: Text('Yearly', style: TextStyle(fontSize: 10)),
                    visualDensity: VisualDensity.compact,
                  ),
                PopupMenuButton(
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                  onSelected: (v) => _handleHolidayAction(v, h),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Events Tab ────────────────────────────────────────────────

  Widget _buildEventsTab() {
    if (_events.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.event_outlined,
        title: 'No events this month',
        subtitle: 'Add exams, PTMs, annual day, and other events',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final e = _events[index];
        final color = _eventColor(e.eventType);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withAlpha(30),
              child: Icon(_eventIcon(e.eventType), color: color, size: 20),
            ),
            title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat('dd MMM').format(DateTime.parse(e.startDate))}${e.endDate != null ? ' — ${DateFormat('dd MMM').format(DateTime.parse(e.endDate!))}' : ''}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                if (e.targetClass != null && e.targetClass!.isNotEmpty)
                  Text(
                    'Class: ${e.targetClass}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (v) => _handleEventAction(v, e),
            ),
          ),
        );
      },
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddEditSheet(
        onSave: (type) {
          Navigator.pop(context);
          if (type == 'holiday') {
            _showHolidayForm();
          } else {
            _showEventForm();
          }
        },
      ),
    );
  }

  void _showHolidayForm({HolidayModel? holiday}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HolidayFormSheet(
        holiday: holiday,
        onSave: (h) async {
          Navigator.pop(context);
          if (holiday == null) {
            await _repo.insertHoliday(h);
          } else {
            await _repo.updateHoliday(h);
          }
          _loadData();
        },
      ),
    );
  }

  void _showEventForm({EventModel? event}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventFormSheet(
        event: event,
        onSave: (e) async {
          Navigator.pop(context);
          if (event == null) {
            await _repo.insertEvent(e);
          } else {
            await _repo.updateEvent(e);
          }
          _loadData();
        },
      ),
    );
  }

  void _showDayDetails(String dateStr, int day) {
    final dayHolidays = _holidays.where((h) => h.date == dateStr).toList();
    final dayEvents = _events.where((e) => e.startDate == dateStr).toList();

    if (dayHolidays.isEmpty && dayEvents.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(DateTime.parse(dateStr)),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...dayHolidays.map((h) => ListTile(
                  leading: const Icon(Icons.event_busy, color: Colors.red),
                  title: Text(h.name),
                  subtitle: Text(h.description ?? 'Holiday'),
                )),
            ...dayEvents.map((e) => ListTile(
                  leading: Icon(_eventIcon(e.eventType), color: _eventColor(e.eventType)),
                  title: Text(e.title),
                  subtitle: Text(e.eventType),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _handleHolidayAction(String action, HolidayModel holiday) async {
    if (action == 'edit') {
      _showHolidayForm(holiday: holiday);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Holiday?'),
          content: Text('Delete "${holiday.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _repo.deleteHoliday(holiday.id!);
        _loadData();
      }
    }
  }

  void _handleEventAction(String action, EventModel event) async {
    if (action == 'edit') {
      _showEventForm(event: event);
    } else if (action == 'delete') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Event?'),
          content: Text('Delete "${event.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _repo.deleteEvent(event.id!);
        _loadData();
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────

  Color _eventColor(String type) {
    switch (type) {
      case 'Exam': return Colors.purple;
      case 'PTM': return Colors.blue;
      case 'Annual Day': return Colors.orange;
      case 'Sports': return Colors.green;
      default: return Colors.teal;
    }
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'Exam': return Icons.quiz;
      case 'PTM': return Icons.people;
      case 'Annual Day': return Icons.celebration;
      case 'Sports': return Icons.sports;
      default: return Icons.event;
    }
  }
}

// ── Add/Edit Bottom Sheets ───────────────────────────────────────

class _AddEditSheet extends StatelessWidget {
  final Function(String type) onSave;
  const _AddEditSheet({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add to Calendar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.event_busy, color: Colors.red),
            title: const Text('Add Holiday'),
            subtitle: const Text('National holidays, institute closures'),
            onTap: () => onSave('holiday'),
          ),
          ListTile(
            leading: const Icon(Icons.event, color: Colors.orange),
            title: const Text('Add Event'),
            subtitle: const Text('Exams, PTM, annual day, sports'),
            onTap: () => onSave('event'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HolidayFormSheet extends StatefulWidget {
  final HolidayModel? holiday;
  final Function(HolidayModel) onSave;
  const _HolidayFormSheet({this.holiday, required this.onSave});

  @override
  State<_HolidayFormSheet> createState() => _HolidayFormSheetState();
}

class _HolidayFormSheetState extends State<_HolidayFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();
    if (widget.holiday != null) {
      _nameController.text = widget.holiday!.name;
      _descController.text = widget.holiday!.description ?? '';
      _selectedDate = DateTime.parse(widget.holiday!.date);
      _isRecurring = widget.holiday!.isRecurring;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.holiday == null ? 'Add Holiday' : 'Edit Holiday',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Holiday Name *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
            ),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring yearly'),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  widget.onSave(HolidayModel(
                    id: widget.holiday?.id,
                    name: _nameController.text.trim(),
                    date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                    description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                    isRecurring: _isRecurring,
                    createdAt: widget.holiday?.createdAt ?? DateTime.now().toIso8601String(),
                  ));
                },
                child: Text(widget.holiday == null ? 'Add Holiday' : 'Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  final EventModel? event;
  final Function(EventModel) onSave;
  const _EventFormSheet({this.event, required this.onSave});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _classController = TextEditingController();
  String _eventType = 'General';
  String _priority = 'Normal';
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  static const _eventTypes = ['General', 'Exam', 'PTM', 'Annual Day', 'Sports', 'Workshop', 'Other'];
  static const _priorities = ['Normal', 'Important', 'Urgent'];

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descController.text = widget.event!.description ?? '';
      _classController.text = widget.event!.targetClass ?? '';
      _eventType = widget.event!.eventType;
      _priority = widget.event!.priority;
      _startDate = DateTime.parse(widget.event!.startDate);
      _endDate = widget.event!.endDate != null ? DateTime.parse(widget.event!.endDate!) : null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _classController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event == null ? 'Add Event' : 'Edit Event',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Event Title *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _eventType,
                decoration: const InputDecoration(labelText: 'Event Type', border: OutlineInputBorder()),
                items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _eventType = v ?? 'General'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _priority = v ?? 'Normal'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date'),
                subtitle: Text(DateFormat('dd MMMM yyyy').format(_startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End Date (optional)'),
                subtitle: Text(_endDate != null ? DateFormat('dd MMMM yyyy').format(_endDate!) : 'Same as start date'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _startDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              TextFormField(
                controller: _classController,
                decoration: const InputDecoration(
                  labelText: 'Target Class (optional)',
                  hintText: 'e.g. 10, 12, All',
                  border: OutlineInputBorder(),
                ),
              ),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    widget.onSave(EventModel(
                      id: widget.event?.id,
                      title: _titleController.text.trim(),
                      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                      eventType: _eventType,
                      startDate: DateFormat('yyyy-MM-dd').format(_startDate),
                      endDate: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
                      targetClass: _classController.text.trim().isEmpty ? null : _classController.text.trim(),
                      priority: _priority,
                      createdAt: widget.event?.createdAt ?? DateTime.now().toIso8601String(),
                    ));
                  },
                  child: Text(widget.event == null ? 'Add Event' : 'Save Changes'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
