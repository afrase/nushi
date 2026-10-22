// This is a generated file - do not edit.
//
// Generated from nushi/v1/nushi.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'nushi.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'nushi.pbenum.dart';

class PingRequest extends $pb.GeneratedMessage {
  factory PingRequest() => PingRequest._();

  PingRequest._();

  factory PingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingRequest()..mergeFromBuffer(data, registry);
  factory PingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: PingRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingRequest copyWith(void Function(PingRequest) updates) =>
      super.copyWith((message) => updates(message as PingRequest))
          as PingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PingRequest() / PingRequest.new instead')
  static PingRequest create() => PingRequest._();
  static $pb.GeneratedMessage $_createMessage() => PingRequest._();
  @$core.override
  PingRequest createEmptyInstance() => PingRequest._();
  @$core.pragma('dart2js:noInline')
  static PingRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingRequest>(
          PingRequest.$_createMessage);
  static PingRequest? _defaultInstance;
}

class PingResponse extends $pb.GeneratedMessage {
  factory PingResponse({
    $core.int? apiVersion,
  }) {
    final result = PingResponse._();
    if (apiVersion != null) result.apiVersion = apiVersion;
    return result;
  }

  PingResponse._();

  factory PingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingResponse()..mergeFromBuffer(data, registry);
  factory PingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: PingResponse.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'apiVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PingResponse copyWith(void Function(PingResponse) updates) =>
      super.copyWith((message) => updates(message as PingResponse))
          as PingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PingResponse() / PingResponse.new instead')
  static PingResponse create() => PingResponse._();
  static $pb.GeneratedMessage $_createMessage() => PingResponse._();
  @$core.override
  PingResponse createEmptyInstance() => PingResponse._();
  @$core.pragma('dart2js:noInline')
  static PingResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PingResponse>(
          PingResponse.$_createMessage);
  static PingResponse? _defaultInstance;

  /// Bumped when methods are added; the API only grows (ADR 0004).
  @$pb.TagNumber(1)
  $core.int get apiVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set apiVersion($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApiVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearApiVersion() => $_clearField(1);
}

class StartChatRequest extends $pb.GeneratedMessage {
  factory StartChatRequest({
    $core.String? folder,
  }) {
    final result = StartChatRequest._();
    if (folder != null) result.folder = folder;
    return result;
  }

  StartChatRequest._();

  factory StartChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartChatRequest()..mergeFromBuffer(data, registry);
  factory StartChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: StartChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartChatRequest copyWith(void Function(StartChatRequest) updates) =>
      super.copyWith((message) => updates(message as StartChatRequest))
          as StartChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StartChatRequest() / StartChatRequest.new instead')
  static StartChatRequest create() => StartChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => StartChatRequest._();
  @$core.override
  StartChatRequest createEmptyInstance() => StartChatRequest._();
  @$core.pragma('dart2js:noInline')
  static StartChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StartChatRequest>(
          StartChatRequest.$_createMessage);
  static StartChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);
}

class StartChatResponse extends $pb.GeneratedMessage {
  factory StartChatResponse({
    $core.String? chatId,
  }) {
    final result = StartChatResponse._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  StartChatResponse._();

  factory StartChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartChatResponse()..mergeFromBuffer(data, registry);
  factory StartChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: StartChatResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartChatResponse copyWith(void Function(StartChatResponse) updates) =>
      super.copyWith((message) => updates(message as StartChatResponse))
          as StartChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use StartChatResponse() / StartChatResponse.new instead')
  static StartChatResponse create() => StartChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => StartChatResponse._();
  @$core.override
  StartChatResponse createEmptyInstance() => StartChatResponse._();
  @$core.pragma('dart2js:noInline')
  static StartChatResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<StartChatResponse>(
          StartChatResponse.$_createMessage);
  static StartChatResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class SendPromptRequest extends $pb.GeneratedMessage {
  factory SendPromptRequest({
    $core.String? chatId,
    $core.String? text,
  }) {
    final result = SendPromptRequest._();
    if (chatId != null) result.chatId = chatId;
    if (text != null) result.text = text;
    return result;
  }

  SendPromptRequest._();

  factory SendPromptRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendPromptRequest()..mergeFromBuffer(data, registry);
  factory SendPromptRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendPromptRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendPromptRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SendPromptRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendPromptRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendPromptRequest copyWith(void Function(SendPromptRequest) updates) =>
      super.copyWith((message) => updates(message as SendPromptRequest))
          as SendPromptRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendPromptRequest() / SendPromptRequest.new instead')
  static SendPromptRequest create() => SendPromptRequest._();
  static $pb.GeneratedMessage $_createMessage() => SendPromptRequest._();
  @$core.override
  SendPromptRequest createEmptyInstance() => SendPromptRequest._();
  @$core.pragma('dart2js:noInline')
  static SendPromptRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SendPromptRequest>(
          SendPromptRequest.$_createMessage);
  static SendPromptRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);
}

class SendPromptResponse extends $pb.GeneratedMessage {
  factory SendPromptResponse() => SendPromptResponse._();

  SendPromptResponse._();

  factory SendPromptResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendPromptResponse()..mergeFromBuffer(data, registry);
  factory SendPromptResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendPromptResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendPromptResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SendPromptResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendPromptResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendPromptResponse copyWith(void Function(SendPromptResponse) updates) =>
      super.copyWith((message) => updates(message as SendPromptResponse))
          as SendPromptResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SendPromptResponse() / SendPromptResponse.new instead')
  static SendPromptResponse create() => SendPromptResponse._();
  static $pb.GeneratedMessage $_createMessage() => SendPromptResponse._();
  @$core.override
  SendPromptResponse createEmptyInstance() => SendPromptResponse._();
  @$core.pragma('dart2js:noInline')
  static SendPromptResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendPromptResponse>(
          SendPromptResponse.$_createMessage);
  static SendPromptResponse? _defaultInstance;
}

class AnswerPermissionRequest extends $pb.GeneratedMessage {
  factory AnswerPermissionRequest({
    $core.String? chatId,
    $core.String? itemId,
    $core.String? optionId,
  }) {
    final result = AnswerPermissionRequest._();
    if (chatId != null) result.chatId = chatId;
    if (itemId != null) result.itemId = itemId;
    if (optionId != null) result.optionId = optionId;
    return result;
  }

  AnswerPermissionRequest._();

  factory AnswerPermissionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerPermissionRequest()..mergeFromBuffer(data, registry);
  factory AnswerPermissionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerPermissionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerPermissionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AnswerPermissionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'itemId')
    ..aOS(3, _omitFieldNames ? '' : 'optionId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerPermissionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerPermissionRequest copyWith(
          void Function(AnswerPermissionRequest) updates) =>
      super.copyWith((message) => updates(message as AnswerPermissionRequest))
          as AnswerPermissionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AnswerPermissionRequest() / AnswerPermissionRequest.new instead')
  static AnswerPermissionRequest create() => AnswerPermissionRequest._();
  static $pb.GeneratedMessage $_createMessage() => AnswerPermissionRequest._();
  @$core.override
  AnswerPermissionRequest createEmptyInstance() => AnswerPermissionRequest._();
  @$core.pragma('dart2js:noInline')
  static AnswerPermissionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerPermissionRequest>(
          AnswerPermissionRequest.$_createMessage);
  static AnswerPermissionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get itemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set itemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get optionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set optionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOptionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOptionId() => $_clearField(3);
}

class AnswerPermissionResponse extends $pb.GeneratedMessage {
  factory AnswerPermissionResponse() => AnswerPermissionResponse._();

  AnswerPermissionResponse._();

  factory AnswerPermissionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerPermissionResponse()..mergeFromBuffer(data, registry);
  factory AnswerPermissionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerPermissionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerPermissionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AnswerPermissionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerPermissionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerPermissionResponse copyWith(
          void Function(AnswerPermissionResponse) updates) =>
      super.copyWith((message) => updates(message as AnswerPermissionResponse))
          as AnswerPermissionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AnswerPermissionResponse() / AnswerPermissionResponse.new instead')
  static AnswerPermissionResponse create() => AnswerPermissionResponse._();
  static $pb.GeneratedMessage $_createMessage() => AnswerPermissionResponse._();
  @$core.override
  AnswerPermissionResponse createEmptyInstance() =>
      AnswerPermissionResponse._();
  @$core.pragma('dart2js:noInline')
  static AnswerPermissionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerPermissionResponse>(
          AnswerPermissionResponse.$_createMessage);
  static AnswerPermissionResponse? _defaultInstance;
}

class EventsRequest extends $pb.GeneratedMessage {
  factory EventsRequest() => EventsRequest._();

  EventsRequest._();

  factory EventsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventsRequest()..mergeFromBuffer(data, registry);
  factory EventsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EventsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventsRequest copyWith(void Function(EventsRequest) updates) =>
      super.copyWith((message) => updates(message as EventsRequest))
          as EventsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EventsRequest() / EventsRequest.new instead')
  static EventsRequest create() => EventsRequest._();
  static $pb.GeneratedMessage $_createMessage() => EventsRequest._();
  @$core.override
  EventsRequest createEmptyInstance() => EventsRequest._();
  @$core.pragma('dart2js:noInline')
  static EventsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EventsRequest>(
          EventsRequest.$_createMessage);
  static EventsRequest? _defaultInstance;
}

enum EventsResponse_Kind { item, status, notSet }

class EventsResponse extends $pb.GeneratedMessage {
  factory EventsResponse({
    $core.String? chatId,
    ItemEvent? item,
    ChatStatus? status,
  }) {
    final result = EventsResponse._();
    if (chatId != null) result.chatId = chatId;
    if (item != null) result.item = item;
    if (status != null) result.status = status;
    return result;
  }

  EventsResponse._();

  factory EventsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventsResponse()..mergeFromBuffer(data, registry);
  factory EventsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EventsResponse()..mergeFromJson(json, registry);

  static const $core.Map<$core.int, EventsResponse_Kind>
      _EventsResponse_KindByTag = {
    2: EventsResponse_Kind.item,
    3: EventsResponse_Kind.status,
    0: EventsResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EventsResponse.$_createMessage)
    ..oo(0, [2, 3])
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOM<ItemEvent>(2, _omitFieldNames ? '' : 'item',
        subBuilder: ItemEvent.$_createMessage)
    ..aOM<ChatStatus>(3, _omitFieldNames ? '' : 'status',
        subBuilder: ChatStatus.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EventsResponse copyWith(void Function(EventsResponse) updates) =>
      super.copyWith((message) => updates(message as EventsResponse))
          as EventsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use EventsResponse() / EventsResponse.new instead')
  static EventsResponse create() => EventsResponse._();
  static $pb.GeneratedMessage $_createMessage() => EventsResponse._();
  @$core.override
  EventsResponse createEmptyInstance() => EventsResponse._();
  @$core.pragma('dart2js:noInline')
  static EventsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EventsResponse>(
          EventsResponse.$_createMessage);
  static EventsResponse? _defaultInstance;

  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  EventsResponse_Kind whichKind() =>
      _EventsResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  void clearKind() => $_clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  ItemEvent get item => $_getN(1);
  @$pb.TagNumber(2)
  set item(ItemEvent value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasItem() => $_has(1);
  @$pb.TagNumber(2)
  void clearItem() => $_clearField(2);
  @$pb.TagNumber(2)
  ItemEvent ensureItem() => $_ensure(1);

  @$pb.TagNumber(3)
  ChatStatus get status => $_getN(2);
  @$pb.TagNumber(3)
  set status(ChatStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);
  @$pb.TagNumber(3)
  ChatStatus ensureStatus() => $_ensure(2);
}

/// One entry of a chat's transcript.
class Item extends $pb.GeneratedMessage {
  factory Item({
    $core.String? id,
    ItemKind? kind,
    $core.String? text,
    $core.String? title,
    $core.String? toolKind,
    $core.String? status,
    $core.Iterable<PermissionOption>? options,
    $core.String? answer,
  }) {
    final result = Item._();
    if (id != null) result.id = id;
    if (kind != null) result.kind = kind;
    if (text != null) result.text = text;
    if (title != null) result.title = title;
    if (toolKind != null) result.toolKind = toolKind;
    if (status != null) result.status = status;
    if (options != null) result.options.addAll(options);
    if (answer != null) result.answer = answer;
    return result;
  }

  Item._();

  factory Item.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Item()..mergeFromBuffer(data, registry);
  factory Item.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Item()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Item',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Item.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<ItemKind>(2, _omitFieldNames ? '' : 'kind',
        enumValues: ItemKind.values)
    ..aOS(3, _omitFieldNames ? '' : 'text')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'toolKind')
    ..aOS(6, _omitFieldNames ? '' : 'status')
    ..pPM<PermissionOption>(7, _omitFieldNames ? '' : 'options',
        subBuilder: PermissionOption.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'answer')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Item clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Item copyWith(void Function(Item) updates) =>
      super.copyWith((message) => updates(message as Item)) as Item;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Item() / Item.new instead')
  static Item create() => Item._();
  static $pb.GeneratedMessage $_createMessage() => Item._();
  @$core.override
  Item createEmptyInstance() => Item._();
  @$core.pragma('dart2js:noInline')
  static Item getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Item>(Item.$_createMessage);
  static Item? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  ItemKind get kind => $_getN(1);
  @$pb.TagNumber(2)
  set kind(ItemKind value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  /// The message, or a tool call's output as markdown.
  @$pb.TagNumber(3)
  $core.String get text => $_getSZ(2);
  @$pb.TagNumber(3)
  set text($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasText() => $_has(2);
  @$pb.TagNumber(3)
  void clearText() => $_clearField(3);

  /// A tool call's title, kind and status, as ACP names them ("execute",
  /// "completed", ...).
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get toolKind => $_getSZ(4);
  @$pb.TagNumber(5)
  set toolKind($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasToolKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearToolKind() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get status => $_getSZ(5);
  @$pb.TagNumber(6)
  set status($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearStatus() => $_clearField(6);

  /// A permission prompt's choices, and the id of the one picked.
  @$pb.TagNumber(7)
  $pb.PbList<PermissionOption> get options => $_getList(6);

  @$pb.TagNumber(8)
  $core.String get answer => $_getSZ(7);
  @$pb.TagNumber(8)
  set answer($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAnswer() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnswer() => $_clearField(8);
}

class PermissionOption extends $pb.GeneratedMessage {
  factory PermissionOption({
    $core.String? id,
    $core.String? name,
    $core.String? kind,
  }) {
    final result = PermissionOption._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    return result;
  }

  PermissionOption._();

  factory PermissionOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PermissionOption()..mergeFromBuffer(data, registry);
  factory PermissionOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PermissionOption()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PermissionOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: PermissionOption.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PermissionOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PermissionOption copyWith(void Function(PermissionOption) updates) =>
      super.copyWith((message) => updates(message as PermissionOption))
          as PermissionOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PermissionOption() / PermissionOption.new instead')
  static PermissionOption create() => PermissionOption._();
  static $pb.GeneratedMessage $_createMessage() => PermissionOption._();
  @$core.override
  PermissionOption createEmptyInstance() => PermissionOption._();
  @$core.pragma('dart2js:noInline')
  static PermissionOption getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PermissionOption>(
          PermissionOption.$_createMessage);
  static PermissionOption? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  /// ACP's hint: allow_once, allow_always, reject_once or reject_always.
  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);
}

class ItemEvent extends $pb.GeneratedMessage {
  factory ItemEvent({
    Item? item,
    $core.bool? append,
  }) {
    final result = ItemEvent._();
    if (item != null) result.item = item;
    if (append != null) result.append = append;
    return result;
  }

  ItemEvent._();

  factory ItemEvent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ItemEvent()..mergeFromBuffer(data, registry);
  factory ItemEvent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ItemEvent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ItemEvent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ItemEvent.$_createMessage)
    ..aOM<Item>(1, _omitFieldNames ? '' : 'item',
        subBuilder: Item.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'append')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ItemEvent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ItemEvent copyWith(void Function(ItemEvent) updates) =>
      super.copyWith((message) => updates(message as ItemEvent)) as ItemEvent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ItemEvent() / ItemEvent.new instead')
  static ItemEvent create() => ItemEvent._();
  static $pb.GeneratedMessage $_createMessage() => ItemEvent._();
  @$core.override
  ItemEvent createEmptyInstance() => ItemEvent._();
  @$core.pragma('dart2js:noInline')
  static ItemEvent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ItemEvent>(ItemEvent.$_createMessage);
  static ItemEvent? _defaultInstance;

  @$pb.TagNumber(1)
  Item get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(Item value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  Item ensureItem() => $_ensure(0);

  /// The item's text continues with item.text rather than being replaced.
  @$pb.TagNumber(2)
  $core.bool get append => $_getBF(1);
  @$pb.TagNumber(2)
  set append($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAppend() => $_has(1);
  @$pb.TagNumber(2)
  void clearAppend() => $_clearField(2);
}

class ChatStatus extends $pb.GeneratedMessage {
  factory ChatStatus({
    $core.bool? busy,
    $core.String? error,
  }) {
    final result = ChatStatus._();
    if (busy != null) result.busy = busy;
    if (error != null) result.error = error;
    return result;
  }

  ChatStatus._();

  factory ChatStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatStatus()..mergeFromBuffer(data, registry);
  factory ChatStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatStatus()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ChatStatus.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'busy')
    ..aOS(2, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatStatus copyWith(void Function(ChatStatus) updates) =>
      super.copyWith((message) => updates(message as ChatStatus)) as ChatStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChatStatus() / ChatStatus.new instead')
  static ChatStatus create() => ChatStatus._();
  static $pb.GeneratedMessage $_createMessage() => ChatStatus._();
  @$core.override
  ChatStatus createEmptyInstance() => ChatStatus._();
  @$core.pragma('dart2js:noInline')
  static ChatStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatStatus>(ChatStatus.$_createMessage);
  static ChatStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get busy => $_getBF(0);
  @$pb.TagNumber(1)
  set busy($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBusy() => $_has(0);
  @$pb.TagNumber(1)
  void clearBusy() => $_clearField(1);

  /// How the last turn failed, if it did.
  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);
}

class NushiServiceApi {
  final $pb.RpcClient _client;

  NushiServiceApi(this._client);

  $async.Future<PingResponse> ping(
          $pb.ClientContext? ctx, PingRequest request) =>
      _client.invoke<PingResponse>(
          ctx, 'NushiService', 'Ping', request, PingResponse());

  /// Starts an agent in a folder and opens a chat with it.
  $async.Future<StartChatResponse> startChat(
          $pb.ClientContext? ctx, StartChatRequest request) =>
      _client.invoke<StartChatResponse>(
          ctx, 'NushiService', 'StartChat', request, StartChatResponse());

  /// Sends a prompt; the reply arrives as events.
  $async.Future<SendPromptResponse> sendPrompt(
          $pb.ClientContext? ctx, SendPromptRequest request) =>
      _client.invoke<SendPromptResponse>(
          ctx, 'NushiService', 'SendPrompt', request, SendPromptResponse());

  /// Answers a pending permission prompt with one of its options.
  $async.Future<AnswerPermissionResponse> answerPermission(
          $pb.ClientContext? ctx, AnswerPermissionRequest request) =>
      _client.invoke<AnswerPermissionResponse>(ctx, 'NushiService',
          'AnswerPermission', request, AnswerPermissionResponse());

  /// Streams every change to every chat from now on. The first message is
  /// empty: it says the subscription is live.
  $async.Future<EventsResponse> events(
          $pb.ClientContext? ctx, EventsRequest request) =>
      _client.invoke<EventsResponse>(
          ctx, 'NushiService', 'Events', request, EventsResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
