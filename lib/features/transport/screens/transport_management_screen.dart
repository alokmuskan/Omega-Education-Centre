import 'package:flutter/material.dart';

import '../models/vehicle_model.dart';
import '../models/route_model.dart';
import '../models/student_transport_model.dart';
import '../repository/transport_repository.dart';

/// Transport Management Screen
///
/// Three-tab view: Vehicles, Routes, Students.
/// Supports full CRUD for vehicles and routes, plus student-route assignment.
class TransportManagementScreen extends StatefulWidget {
  const TransportManagementScreen({super.key});

  @override
  State<TransportManagementScreen> createState() => _TransportManagementScreenState();
}

class _TransportManagementScreenState extends State<TransportManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TransportRepository _repo = TransportRepository();

  List<VehicleModel> _vehicles = [];
  List<RouteModel> _routes = [];
  List<StudentTransportModel> _assignments = [];
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
      final vehicles = await _repo.getVehicles();
      final routes = await _repo.getRoutes();
      final assignments = await _repo.getStudentAssignments();

      setState(() {
        _vehicles = vehicles;
        _routes = routes;
        _assignments = assignments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transport data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.directions_bus), text: 'Vehicles'),
            Tab(icon: const Icon(Icons.route), text: 'Routes'),
            Tab(icon: const Icon(Icons.people), text: 'Students'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVehiclesTab(),
                _buildRoutesTab(),
                _buildStudentsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    switch (_tabController.index) {
      case 0:
        _showVehicleForm();
        break;
      case 1:
        _showRouteForm();
        break;
      case 2:
        _showAssignmentForm();
        break;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // VEHICLES TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildVehiclesTab() {
    return _vehicles.isEmpty
        ? _buildEmptyState('No vehicles added', Icons.directions_bus_outlined)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _vehicles.length,
            itemBuilder: (context, index) => _buildVehicleCard(_vehicles[index]),
          );
  }

  Widget _buildVehicleCard(VehicleModel vehicle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.directions_bus),
        ),
        title: Text(vehicle.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vehicle.vehicleType} • Capacity: ${vehicle.capacity}'),
            if (vehicle.driverName != null)
              Text('Driver: ${vehicle.driverName}', style: const TextStyle(fontSize: 13)),
            if (vehicle.driverPhone != null)
              Text('Phone: ${vehicle.driverPhone}', style: const TextStyle(fontSize: 13)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleVehicleAction(value, vehicle),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  void _handleVehicleAction(String action, VehicleModel vehicle) {
    switch (action) {
      case 'edit':
        _showVehicleForm(vehicle: vehicle);
        break;
      case 'delete':
        _confirmDelete(() async {
          await _repo.deleteVehicle(vehicle.id!);
          _loadData();
        }, 'Delete vehicle ${vehicle.vehicleNumber}?');
        break;
    }
  }

  void _showVehicleForm({VehicleModel? vehicle}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _VehicleFormSheet(
        vehicle: vehicle,
        onSave: (v) async {
          if (v.id == null) {
            await _repo.insertVehicle(v);
          } else {
            await _repo.updateVehicle(v);
          }
          _loadData();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // ROUTES TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildRoutesTab() {
    return _routes.isEmpty
        ? _buildEmptyState('No routes created', Icons.route_outlined)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _routes.length,
            itemBuilder: (context, index) => _buildRouteCard(_routes[index]),
          );
  }

  Widget _buildRouteCard(RouteModel route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: const Icon(Icons.route),
        ),
        title: Text(route.routeName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (route.startPoint != null || route.endPoint != null)
              Text('${route.startPoint ?? '?'} → ${route.endPoint ?? '?'}'),
            if (route.vehicleNumber != null)
              Text('Vehicle: ${route.vehicleNumber}', style: const TextStyle(fontSize: 13)),
            if (route.departureTime != null)
              Text(
                'Departs: ${route.departureTime} • Arrives: ${route.arrivalTime ?? '?'}',
                style: const TextStyle(fontSize: 13),
              ),
            Text('Fare: ₹${route.fare.toStringAsFixed(0)}/month',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleRouteAction(value, route),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  void _handleRouteAction(String action, RouteModel route) {
    switch (action) {
      case 'edit':
        _showRouteForm(route: route);
        break;
      case 'delete':
        _confirmDelete(() async {
          await _repo.deleteRoute(route.id!);
          _loadData();
        }, 'Delete route ${route.routeName}?');
        break;
    }
  }

  void _showRouteForm({RouteModel? route}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _RouteFormSheet(
        route: route,
        vehicles: _vehicles,
        onSave: (r) async {
          if (r.id == null) {
            await _repo.insertRoute(r);
          } else {
            await _repo.updateRoute(r);
          }
          _loadData();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // STUDENTS TAB
  // ══════════════════════════════════════════════════════════════════════

  Widget _buildStudentsTab() {
    return _assignments.isEmpty
        ? _buildEmptyState('No students assigned to routes', Icons.people_outline)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _assignments.length,
            itemBuilder: (context, index) => _buildAssignmentCard(_assignments[index]),
          );
  }

  Widget _buildAssignmentCard(StudentTransportModel assignment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
          child: const Icon(Icons.person),
        ),
        title: Text(assignment.studentName ?? 'Unknown',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Roll #${assignment.studentRollNo ?? '?'} • Class: ${assignment.studentClass ?? '?'}'),
            Text('Route: ${assignment.routeName ?? '?'}', style: const TextStyle(fontSize: 13)),
            Text('Stop: ${assignment.stopName ?? 'N/A'} • ${assignment.pickupOrDrop}',
                style: const TextStyle(fontSize: 13)),
            Text('Monthly Fee: ₹${assignment.monthlyFee.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: () => _confirmDelete(() async {
            await _repo.removeStudent(assignment.id!);
            _loadData();
          }, 'Remove ${assignment.studentName} from transport?'),
        ),
      ),
    );
  }

  void _showAssignmentForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AssignmentFormSheet(
        routes: _routes,
        onAssign: (assignment) async {
          await _repo.assignStudent(assignment);
          _loadData();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════

  void _confirmDelete(VoidCallback onConfirm, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// VEHICLE FORM SHEET
// ══════════════════════════════════════════════════════════════════════════

class _VehicleFormSheet extends StatefulWidget {
  final VehicleModel? vehicle;
  final Future<void> Function(VehicleModel) onSave;

  const _VehicleFormSheet({this.vehicle, required this.onSave});

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberController;
  late TextEditingController _capacityController;
  late TextEditingController _driverNameController;
  late TextEditingController _driverPhoneController;
  String _vehicleType = 'Bus';

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.vehicle?.vehicleNumber ?? '');
    _capacityController = TextEditingController(text: '${widget.vehicle?.capacity ?? 40}');
    _driverNameController = TextEditingController(text: widget.vehicle?.driverName ?? '');
    _driverPhoneController = TextEditingController(text: widget.vehicle?.driverPhone ?? '');
    _vehicleType = widget.vehicle?.vehicleType ?? 'Bus';
  }

  @override
  void dispose() {
    _numberController.dispose();
    _capacityController.dispose();
    _driverNameController.dispose();
    _driverPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.vehicle == null ? 'Add Vehicle' : 'Edit Vehicle',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              decoration: const InputDecoration(labelText: 'Vehicle Number *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Bus', child: Text('Bus')),
                DropdownMenuItem(value: 'Van', child: Text('Van')),
                DropdownMenuItem(value: 'Tempo', child: Text('Tempo')),
                DropdownMenuItem(value: 'Car', child: Text('Car')),
              ],
              onChanged: (v) => setState(() => _vehicleType = v ?? 'Bus'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityController,
              decoration: const InputDecoration(labelText: 'Capacity *', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Must be ≥ 1';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _driverNameController,
              decoration: const InputDecoration(labelText: 'Driver Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _driverPhoneController,
              decoration: const InputDecoration(labelText: 'Driver Phone', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Text(widget.vehicle == null ? 'Add Vehicle' : 'Update Vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().toIso8601String();

    final vehicle = VehicleModel(
      id: widget.vehicle?.id,
      vehicleNumber: _numberController.text.trim().toUpperCase(),
      vehicleType: _vehicleType,
      capacity: int.tryParse(_capacityController.text.trim()) ?? 40,
      driverName: _driverNameController.text.trim().isEmpty ? null : _driverNameController.text.trim(),
      driverPhone: _driverPhoneController.text.trim().isEmpty ? null : _driverPhoneController.text.trim(),
      createdAt: widget.vehicle?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.onSave(vehicle);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ROUTE FORM SHEET
// ══════════════════════════════════════════════════════════════════════════

class _RouteFormSheet extends StatefulWidget {
  final RouteModel? route;
  final List<VehicleModel> vehicles;
  final Future<void> Function(RouteModel) onSave;

  const _RouteFormSheet({this.route, required this.vehicles, required this.onSave});

  @override
  State<_RouteFormSheet> createState() => _RouteFormSheetState();
}

class _RouteFormSheetState extends State<_RouteFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _startController;
  late TextEditingController _endController;
  late TextEditingController _stopsController;
  late TextEditingController _fareController;
  int? _selectedVehicleId;
  TimeOfDay? _departureTime;
  TimeOfDay? _arrivalTime;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.route?.routeName ?? '');
    _startController = TextEditingController(text: widget.route?.startPoint ?? '');
    _endController = TextEditingController(text: widget.route?.endPoint ?? '');
    _stopsController = TextEditingController(text: widget.route?.stops ?? '');
    _fareController = TextEditingController(text: '${widget.route?.fare ?? 0}');
    _selectedVehicleId = widget.route?.vehicleId;

    if (widget.route?.departureTime != null) {
      final parts = widget.route!.departureTime!.split(':');
      if (parts.length >= 2) {
        _departureTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    if (widget.route?.arrivalTime != null) {
      final parts = widget.route!.arrivalTime!.split(':');
      if (parts.length >= 2) {
        _arrivalTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    _stopsController.dispose();
    _fareController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.route == null ? 'Add Route' : 'Edit Route',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Route Name *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startController,
                      decoration: const InputDecoration(labelText: 'Start Point', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _endController,
                      decoration: const InputDecoration(labelText: 'End Point', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _stopsController,
                decoration: const InputDecoration(
                  labelText: 'Stops (comma-separated)',
                  border: OutlineInputBorder(),
                  hintText: 'Stop 1, Stop 2, Stop 3',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedVehicleId,
                decoration: const InputDecoration(labelText: 'Vehicle', border: OutlineInputBorder()),
                items: widget.vehicles.map((v) => DropdownMenuItem(
                  value: v.id,
                  child: Text('${v.vehicleNumber} (${v.vehicleType})'),
                )).toList(),
                onChanged: (v) => setState(() => _selectedVehicleId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimePicker('Departure', _departureTime, (t) {
                      setState(() => _departureTime = t);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimePicker('Arrival', _arrivalTime, (t) {
                      setState(() => _arrivalTime = t);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fareController,
                decoration: const InputDecoration(
                  labelText: 'Monthly Fare (₹)',
                  border: OutlineInputBorder(),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: Text(widget.route == null ? 'Add Route' : 'Update Route'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, Function(TimeOfDay) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time ?? TimeOfDay.now(),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.access_time),
        ),
        child: Text(
          time != null ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}' : 'Select',
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now().toIso8601String();

    final route = RouteModel(
      id: widget.route?.id,
      routeName: _nameController.text.trim(),
      vehicleId: _selectedVehicleId,
      startPoint: _startController.text.trim().isEmpty ? null : _startController.text.trim(),
      endPoint: _endController.text.trim().isEmpty ? null : _endController.text.trim(),
      stops: _stopsController.text.trim().isEmpty ? null : _stopsController.text.trim(),
      departureTime: _departureTime != null
          ? '${_departureTime!.hour.toString().padLeft(2, '0')}:${_departureTime!.minute.toString().padLeft(2, '0')}'
          : null,
      arrivalTime: _arrivalTime != null
          ? '${_arrivalTime!.hour.toString().padLeft(2, '0')}:${_arrivalTime!.minute.toString().padLeft(2, '0')}'
          : null,
      fare: double.tryParse(_fareController.text.trim()) ?? 0,
      createdAt: widget.route?.createdAt ?? now,
      updatedAt: now,
    );

    await widget.onSave(route);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ASSIGNMENT FORM SHEET
// ══════════════════════════════════════════════════════════════════════════

class _AssignmentFormSheet extends StatefulWidget {
  final List<RouteModel> routes;
  final Future<void> Function(StudentTransportModel) onAssign;

  const _AssignmentFormSheet({required this.routes, required this.onAssign});

  @override
  State<_AssignmentFormSheet> createState() => _AssignmentFormSheetState();
}

class _AssignmentFormSheetState extends State<_AssignmentFormSheet> {
  int? _selectedStudentId;
  int? _selectedRouteId;
  String _pickupOrDrop = 'Both';
  final _stopController = TextEditingController();
  final _feeController = TextEditingController(text: '0');

  @override
  void dispose() {
    _stopController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Assign Student to Route',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Student *', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Student 1')),
              DropdownMenuItem(value: 2, child: Text('Student 2')),
            ],
            onChanged: (v) => setState(() => _selectedStudentId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'Route *', border: OutlineInputBorder()),
            items: widget.routes.map((r) => DropdownMenuItem(
              value: r.id,
              child: Text('${r.routeName} (₹${r.fare.toStringAsFixed(0)})'),
            )).toList(),
            onChanged: (v) => setState(() => _selectedRouteId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stopController,
            decoration: const InputDecoration(labelText: 'Stop Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _pickupOrDrop,
            decoration: const InputDecoration(labelText: 'Pickup/Drop', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Both', child: Text('Both')),
              DropdownMenuItem(value: 'Pickup', child: Text('Pickup Only')),
              DropdownMenuItem(value: 'Drop', child: Text('Drop Only')),
            ],
            onChanged: (v) => setState(() => _pickupOrDrop = v ?? 'Both'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _feeController,
            decoration: const InputDecoration(
              labelText: 'Monthly Fee (₹)',
              border: OutlineInputBorder(),
              prefixText: '₹ ',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_selectedStudentId == null || _selectedRouteId == null)
                ? null
                : _assign,
            child: const Text('Assign Student'),
          ),
        ],
      ),
    );
  }

  Future<void> _assign() async {
    if (_selectedStudentId == null || _selectedRouteId == null) return;
    final now = DateTime.now().toIso8601String();

    final assignment = StudentTransportModel(
      studentId: _selectedStudentId!,
      routeId: _selectedRouteId!,
      stopName: _stopController.text.trim().isEmpty ? null : _stopController.text.trim(),
      pickupOrDrop: _pickupOrDrop,
      monthlyFee: double.tryParse(_feeController.text.trim()) ?? 0,
      createdAt: now,
    );

    await widget.onAssign(assignment);
  }
}
