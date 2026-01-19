import 'package:flutter/material.dart';

import 'booking_details_page.dart';
import 'time_slots_for_day.dart';

class TimeSlotPicker extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String businessPhone;

  final String serviceId;
  final String serviceName;
  final int durationMin;

  const TimeSlotPicker({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
    required this.serviceId,
    required this.serviceName,
    required this.durationMin,
  });

  @override
  State<TimeSlotPicker> createState() => _TimeSlotPickerState();
}

class _TimeSlotPickerState extends State<TimeSlotPicker> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona tu horario'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha'),
              subtitle: Text(
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 120)),
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedTime = null; // ✅ reset hora al cambiar fecha
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            // ✅ CLAVE: Expanded para darle altura al GridView
            Expanded(
              child: TimeSlotsForDay(
                businessId: widget.businessId,
                date: _selectedDate,
                selectedTime: _selectedTime,
                onPick: (time) => setState(() => _selectedTime = time),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selectedTime == null
                    ? null
                    : () {
                        final startDateTime = DateTime(
                          _selectedDate.year,
                          _selectedDate.month,
                          _selectedDate.day,
                          _selectedTime!.hour,
                          _selectedTime!.minute,
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingDetailsPage(
                              businessId: widget.businessId,
                              businessName: widget.businessName,
                              businessPhone: widget.businessPhone,
                              serviceId: widget.serviceId,
                              serviceName: widget.serviceName,
                              durationMin: widget.durationMin,
                              startDateTime: startDateTime,
                            ),
                          ),
                        );
                      },
                child: const Text('Continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
