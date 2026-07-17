import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Inicializar zonas horarias para poder programar notificaciones exactas
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Aquí podríamos navegar a la ficha de la medición
      },
    );

    // Pedir permisos explícitos en Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Programa un recordatorio para una visita agendada
  /// Suponiendo que queremos que suene 2 horas antes de la visita.
  Future<void> scheduleVisitReminder(String projectId, String projectName, DateTime visitDate) async {
    // Calcular el momento del recordatorio: 2 horas antes
    final reminderDate = visitDate.subtract(const Duration(hours: 2));

    // Si ya pasó la fecha del recordatorio, no lo programamos
    if (reminderDate.isBefore(DateTime.now())) {
      return;
    }

    // Generar un ID único basado en el hash del ID del proyecto para poder sobrescribirlo si cambia la cita
    final int notificationId = projectId.hashCode;

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        '¡Medición Próxima!',
        'Tienes una visita agendada para "$projectName" en 2 horas.',
        tz.TZDateTime.from(reminderDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'xprinta_survey_channel',
            'Recordatorios de Medición',
            channelDescription: 'Notificaciones sobre citas y mediciones programadas',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Error scheduling exact alarm: $e');
    }
  }

  /// Cancela un recordatorio específico si se cambia la fase o se completa
  Future<void> cancelReminder(String projectId) async {
    await flutterLocalNotificationsPlugin.cancel(projectId.hashCode);
  }
}
