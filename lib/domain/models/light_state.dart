import 'package:freezed_annotation/freezed_annotation.dart';

part 'light_state.freezed.dart';

/// What Luminar knows about a light right now. Not persisted.
@freezed
abstract class LightState with _$LightState {
  const factory LightState({
    @Default(false) bool on,

    /// Whether the light has reported its state since Luminar started.
    @Default(false) bool known,

    /// False when the light did not answer the last state query.
    @Default(true) bool responding,
  }) = _LightState;
}
