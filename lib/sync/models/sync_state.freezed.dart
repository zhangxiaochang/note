// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sync_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$SyncState {
  SyncDirection get direction => throw _privateConstructorUsedError;
  bool get isSyncing => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get current => throw _privateConstructorUsedError;
  String? get currentFile => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SyncStateCopyWith<SyncState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SyncStateCopyWith<$Res> {
  factory $SyncStateCopyWith(SyncState value, $Res Function(SyncState) then) =
      _$SyncStateCopyWithImpl<$Res, SyncState>;
  @useResult
  $Res call({
    SyncDirection direction,
    bool isSyncing,
    int total,
    int current,
    String? currentFile,
    String? error,
  });
}

/// @nodoc
class _$SyncStateCopyWithImpl<$Res, $Val extends SyncState>
    implements $SyncStateCopyWith<$Res> {
  _$SyncStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? direction = null,
    Object? isSyncing = null,
    Object? total = null,
    Object? current = null,
    Object? currentFile = freezed,
    Object? error = freezed,
  }) {
    return _then(
      _value.copyWith(
            direction: null == direction
                ? _value.direction
                : direction // ignore: cast_nullable_to_non_nullable
                      as SyncDirection,
            isSyncing: null == isSyncing
                ? _value.isSyncing
                : isSyncing // ignore: cast_nullable_to_non_nullable
                      as bool,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            current: null == current
                ? _value.current
                : current // ignore: cast_nullable_to_non_nullable
                      as int,
            currentFile: freezed == currentFile
                ? _value.currentFile
                : currentFile // ignore: cast_nullable_to_non_nullable
                      as String?,
            error: freezed == error
                ? _value.error
                : error // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SyncStateImplCopyWith<$Res>
    implements $SyncStateCopyWith<$Res> {
  factory _$$SyncStateImplCopyWith(
    _$SyncStateImpl value,
    $Res Function(_$SyncStateImpl) then,
  ) = __$$SyncStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SyncDirection direction,
    bool isSyncing,
    int total,
    int current,
    String? currentFile,
    String? error,
  });
}

/// @nodoc
class __$$SyncStateImplCopyWithImpl<$Res>
    extends _$SyncStateCopyWithImpl<$Res, _$SyncStateImpl>
    implements _$$SyncStateImplCopyWith<$Res> {
  __$$SyncStateImplCopyWithImpl(
    _$SyncStateImpl _value,
    $Res Function(_$SyncStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? direction = null,
    Object? isSyncing = null,
    Object? total = null,
    Object? current = null,
    Object? currentFile = freezed,
    Object? error = freezed,
  }) {
    return _then(
      _$SyncStateImpl(
        direction: null == direction
            ? _value.direction
            : direction // ignore: cast_nullable_to_non_nullable
                  as SyncDirection,
        isSyncing: null == isSyncing
            ? _value.isSyncing
            : isSyncing // ignore: cast_nullable_to_non_nullable
                  as bool,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        current: null == current
            ? _value.current
            : current // ignore: cast_nullable_to_non_nullable
                  as int,
        currentFile: freezed == currentFile
            ? _value.currentFile
            : currentFile // ignore: cast_nullable_to_non_nullable
                  as String?,
        error: freezed == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$SyncStateImpl implements _SyncState {
  const _$SyncStateImpl({
    this.direction = SyncDirection.both,
    this.isSyncing = false,
    this.total = 0,
    this.current = 0,
    this.currentFile,
    this.error,
  });

  @override
  @JsonKey()
  final SyncDirection direction;
  @override
  @JsonKey()
  final bool isSyncing;
  @override
  @JsonKey()
  final int total;
  @override
  @JsonKey()
  final int current;
  @override
  final String? currentFile;
  @override
  final String? error;

  @override
  String toString() {
    return 'SyncState(direction: $direction, isSyncing: $isSyncing, total: $total, current: $current, currentFile: $currentFile, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SyncStateImpl &&
            (identical(other.direction, direction) ||
                other.direction == direction) &&
            (identical(other.isSyncing, isSyncing) ||
                other.isSyncing == isSyncing) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.current, current) || other.current == current) &&
            (identical(other.currentFile, currentFile) ||
                other.currentFile == currentFile) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    direction,
    isSyncing,
    total,
    current,
    currentFile,
    error,
  );

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SyncStateImplCopyWith<_$SyncStateImpl> get copyWith =>
      __$$SyncStateImplCopyWithImpl<_$SyncStateImpl>(this, _$identity);
}

abstract class _SyncState implements SyncState {
  const factory _SyncState({
    final SyncDirection direction,
    final bool isSyncing,
    final int total,
    final int current,
    final String? currentFile,
    final String? error,
  }) = _$SyncStateImpl;

  @override
  SyncDirection get direction;
  @override
  bool get isSyncing;
  @override
  int get total;
  @override
  int get current;
  @override
  String? get currentFile;
  @override
  String? get error;

  /// Create a copy of SyncState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SyncStateImplCopyWith<_$SyncStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
