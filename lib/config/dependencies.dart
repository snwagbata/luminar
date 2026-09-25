import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:luminar/data/repositories/connection_repository.dart';
import 'package:luminar/data/repositories/home_repository.dart';
import 'package:luminar/data/repositories/light_repository.dart';
import 'package:luminar/data/repositories/provisioning_repository.dart';
import 'package:luminar/data/repositories/scene_repository.dart';
import 'package:luminar/data/repositories/widget_repository.dart';
import 'package:luminar/data/services/activity_log.dart';
import 'package:luminar/data/services/ble/ble_service.dart';
import 'package:luminar/data/services/home_store.dart';
import 'package:luminar/data/services/home_widget_service.dart';
import 'package:luminar/data/services/mesh_proxy_service.dart';
import 'package:luminar/data/services/provisioning_service.dart';
import 'package:luminar/data/services/timings.dart';
import 'package:luminar/domain/use_cases/add_light_use_case.dart';
import 'package:luminar/domain/use_cases/connect_use_case.dart';
import 'package:luminar/domain/use_cases/widget_action_use_case.dart';
import 'package:luminar/ui/features/activity_log/view_models/activity_log_view_model.dart';
import 'package:luminar/ui/features/add_light/view_models/add_light_view_model.dart';
import 'package:luminar/ui/features/home/view_models/home_view_model.dart';

/// The app's object graph: services, repositories, use cases and the home
/// screen's view model. Tests pass a simulated [ble] and an in-memory
/// [store].
class Dependencies {
  Dependencies({
    required this.ble,
    required this.store,
    this.timings = const Timings(),
    HomeWidgetService? widgetService,
    this.widgetPort = WidgetRepository.defaultPortName,
  }) : widgetService = widgetService ?? PluginHomeWidgetService();

  final BleService ble;
  final HomeStore store;
  final Timings timings;
  final HomeWidgetService widgetService;
  final String widgetPort;

  late final log = ActivityLog();
  late final home = HomeRepository(store: store, log: log);
  late final proxy = MeshProxyService(ble: ble, keys: home, log: log, timings: timings);
  late final connection = ConnectionRepository(
    ble: ble,
    proxy: proxy,
    home: home,
    log: log,
    timings: timings,
  );
  late final lights = LightRepository(proxy: proxy, home: home, log: log, timings: timings);
  late final scenes = SceneRepository(proxy: proxy, home: home, log: log);
  late final provisioning = ProvisioningRepository(
    ble: ble,
    provisioning: ProvisioningService(ble: ble, log: log, timings: timings),
    home: home,
  );
  late final connect = ConnectUseCase(connection: connection, lights: lights);
  late final addLight = AddLightUseCase(
    provisioning: provisioning,
    connection: connection,
    lights: lights,
    log: log,
    timings: timings,
  );
  late final widgets = WidgetRepository(service: widgetService, portName: widgetPort);
  late final widgetAction = WidgetActionUseCase(connection: connection, lights: lights);
  late final homeViewModel = HomeViewModel(
    home: home,
    connection: connection,
    lights: lights,
    scenes: scenes,
    connect: connect,
    addLight: addLight,
    widgets: widgets,
    log: log,
  );

  /// A view model for one visit to the Add a light sheet.
  AddLightViewModel addLightViewModel() => AddLightViewModel(provisioning: provisioning);

  /// A view model for one visit to the activity log.
  ActivityLogViewModel activityLogViewModel() => ActivityLogViewModel(log: log);

  /// Everything the widget tree reads with `context.read`.
  List<SingleChildWidget> get providers => [
    Provider<Dependencies>.value(value: this),
    ChangeNotifierProvider.value(value: log),
    ChangeNotifierProvider.value(value: home),
    ChangeNotifierProvider.value(value: connection),
    ChangeNotifierProvider.value(value: lights),
    Provider.value(value: scenes),
    Provider.value(value: provisioning),
    Provider.value(value: connect),
    Provider.value(value: addLight),
    ChangeNotifierProvider.value(value: homeViewModel),
  ];

  void dispose() {
    homeViewModel.dispose();
    lights.dispose();
    connection.dispose();
    proxy.dispose();
    home.dispose();
    log.dispose();
  }
}
