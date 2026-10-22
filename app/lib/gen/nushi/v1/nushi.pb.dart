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

import 'package:fixnum/fixnum.dart' as $fixnum;
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

class ListChatsRequest extends $pb.GeneratedMessage {
  factory ListChatsRequest() => ListChatsRequest._();

  ListChatsRequest._();

  factory ListChatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatsRequest()..mergeFromBuffer(data, registry);
  factory ListChatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListChatsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListChatsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatsRequest copyWith(void Function(ListChatsRequest) updates) =>
      super.copyWith((message) => updates(message as ListChatsRequest))
          as ListChatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListChatsRequest() / ListChatsRequest.new instead')
  static ListChatsRequest create() => ListChatsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListChatsRequest._();
  @$core.override
  ListChatsRequest createEmptyInstance() => ListChatsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListChatsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListChatsRequest>(
          ListChatsRequest.$_createMessage);
  static ListChatsRequest? _defaultInstance;
}

class ListChatsResponse extends $pb.GeneratedMessage {
  factory ListChatsResponse({
    $core.Iterable<Chat>? chats,
  }) {
    final result = ListChatsResponse._();
    if (chats != null) result.chats.addAll(chats);
    return result;
  }

  ListChatsResponse._();

  factory ListChatsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatsResponse()..mergeFromBuffer(data, registry);
  factory ListChatsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListChatsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListChatsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListChatsResponse.$_createMessage)
    ..pPM<Chat>(1, _omitFieldNames ? '' : 'chats',
        subBuilder: Chat.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListChatsResponse copyWith(void Function(ListChatsResponse) updates) =>
      super.copyWith((message) => updates(message as ListChatsResponse))
          as ListChatsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListChatsResponse() / ListChatsResponse.new instead')
  static ListChatsResponse create() => ListChatsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListChatsResponse._();
  @$core.override
  ListChatsResponse createEmptyInstance() => ListChatsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListChatsResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListChatsResponse>(
          ListChatsResponse.$_createMessage);
  static ListChatsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Chat> get chats => $_getList(0);
}

/// What Nushi keeps of a chat; the agent keeps the rest.
class Chat extends $pb.GeneratedMessage {
  factory Chat({
    $core.String? id,
    $core.String? agent,
    $core.String? folder,
    $core.String? title,
    $core.String? mode,
    $fixnum.Int64? createdUnixMs,
  }) {
    final result = Chat._();
    if (id != null) result.id = id;
    if (agent != null) result.agent = agent;
    if (folder != null) result.folder = folder;
    if (title != null) result.title = title;
    if (mode != null) result.mode = mode;
    if (createdUnixMs != null) result.createdUnixMs = createdUnixMs;
    return result;
  }

  Chat._();

  factory Chat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Chat()..mergeFromBuffer(data, registry);
  factory Chat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Chat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Chat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Chat.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'agent')
    ..aOS(3, _omitFieldNames ? '' : 'folder')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'mode')
    ..aInt64(6, _omitFieldNames ? '' : 'createdUnixMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Chat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Chat copyWith(void Function(Chat) updates) =>
      super.copyWith((message) => updates(message as Chat)) as Chat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Chat() / Chat.new instead')
  static Chat create() => Chat._();
  static $pb.GeneratedMessage $_createMessage() => Chat._();
  @$core.override
  Chat createEmptyInstance() => Chat._();
  @$core.pragma('dart2js:noInline')
  static Chat getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Chat>(Chat.$_createMessage);
  static Chat? _defaultInstance;

  /// The agent's session id.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get agent => $_getSZ(1);
  @$pb.TagNumber(2)
  set agent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgent() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get folder => $_getSZ(2);
  @$pb.TagNumber(3)
  set folder($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFolder() => $_has(2);
  @$pb.TagNumber(3)
  void clearFolder() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  /// The mode it was last in.
  @$pb.TagNumber(5)
  $core.String get mode => $_getSZ(4);
  @$pb.TagNumber(5)
  set mode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMode() => $_has(4);
  @$pb.TagNumber(5)
  void clearMode() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get createdUnixMs => $_getI64(5);
  @$pb.TagNumber(6)
  set createdUnixMs($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedUnixMs() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedUnixMs() => $_clearField(6);
}

class GetChatRequest extends $pb.GeneratedMessage {
  factory GetChatRequest({
    $core.String? chatId,
  }) {
    final result = GetChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  GetChatRequest._();

  factory GetChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatRequest()..mergeFromBuffer(data, registry);
  factory GetChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatRequest copyWith(void Function(GetChatRequest) updates) =>
      super.copyWith((message) => updates(message as GetChatRequest))
          as GetChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetChatRequest() / GetChatRequest.new instead')
  static GetChatRequest create() => GetChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetChatRequest._();
  @$core.override
  GetChatRequest createEmptyInstance() => GetChatRequest._();
  @$core.pragma('dart2js:noInline')
  static GetChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetChatRequest>(
          GetChatRequest.$_createMessage);
  static GetChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class GetChatResponse extends $pb.GeneratedMessage {
  factory GetChatResponse({
    Chat? chat,
    $core.Iterable<Item>? items,
    $core.Iterable<ConfigOption>? config,
    ChatStatus? status,
    $fixnum.Int64? seq,
  }) {
    final result = GetChatResponse._();
    if (chat != null) result.chat = chat;
    if (items != null) result.items.addAll(items);
    if (config != null) result.config.addAll(config);
    if (status != null) result.status = status;
    if (seq != null) result.seq = seq;
    return result;
  }

  GetChatResponse._();

  factory GetChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatResponse()..mergeFromBuffer(data, registry);
  factory GetChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetChatResponse.$_createMessage)
    ..aOM<Chat>(1, _omitFieldNames ? '' : 'chat',
        subBuilder: Chat.$_createMessage)
    ..pPM<Item>(2, _omitFieldNames ? '' : 'items',
        subBuilder: Item.$_createMessage)
    ..pPM<ConfigOption>(3, _omitFieldNames ? '' : 'config',
        subBuilder: ConfigOption.$_createMessage)
    ..aOM<ChatStatus>(4, _omitFieldNames ? '' : 'status',
        subBuilder: ChatStatus.$_createMessage)
    ..aInt64(5, _omitFieldNames ? '' : 'seq')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatResponse copyWith(void Function(GetChatResponse) updates) =>
      super.copyWith((message) => updates(message as GetChatResponse))
          as GetChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetChatResponse() / GetChatResponse.new instead')
  static GetChatResponse create() => GetChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetChatResponse._();
  @$core.override
  GetChatResponse createEmptyInstance() => GetChatResponse._();
  @$core.pragma('dart2js:noInline')
  static GetChatResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetChatResponse>(
          GetChatResponse.$_createMessage);
  static GetChatResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Chat get chat => $_getN(0);
  @$pb.TagNumber(1)
  set chat(Chat value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasChat() => $_has(0);
  @$pb.TagNumber(1)
  void clearChat() => $_clearField(1);
  @$pb.TagNumber(1)
  Chat ensureChat() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<Item> get items => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<ConfigOption> get config => $_getList(2);

  @$pb.TagNumber(4)
  ChatStatus get status => $_getN(3);
  @$pb.TagNumber(4)
  set status(ChatStatus value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);
  @$pb.TagNumber(4)
  ChatStatus ensureStatus() => $_ensure(3);

  /// The last event this includes: apply only the chat's events after it.
  @$pb.TagNumber(5)
  $fixnum.Int64 get seq => $_getI64(4);
  @$pb.TagNumber(5)
  set seq($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSeq() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeq() => $_clearField(5);
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
    $core.Iterable<ConfigOption>? config,
  }) {
    final result = StartChatResponse._();
    if (chatId != null) result.chatId = chatId;
    if (config != null) result.config.addAll(config);
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
    ..pPM<ConfigOption>(2, _omitFieldNames ? '' : 'config',
        subBuilder: ConfigOption.$_createMessage)
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

  /// The chat's config options as it starts; changes arrive as events.
  @$pb.TagNumber(2)
  $pb.PbList<ConfigOption> get config => $_getList(1);
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

class AnswerQuestionRequest extends $pb.GeneratedMessage {
  factory AnswerQuestionRequest({
    $core.String? chatId,
    $core.String? itemId,
    $core.Iterable<FieldAnswer>? answers,
    $core.bool? decline,
  }) {
    final result = AnswerQuestionRequest._();
    if (chatId != null) result.chatId = chatId;
    if (itemId != null) result.itemId = itemId;
    if (answers != null) result.answers.addAll(answers);
    if (decline != null) result.decline = decline;
    return result;
  }

  AnswerQuestionRequest._();

  factory AnswerQuestionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerQuestionRequest()..mergeFromBuffer(data, registry);
  factory AnswerQuestionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerQuestionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerQuestionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AnswerQuestionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'itemId')
    ..pPM<FieldAnswer>(3, _omitFieldNames ? '' : 'answers',
        subBuilder: FieldAnswer.$_createMessage)
    ..aOB(4, _omitFieldNames ? '' : 'decline')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerQuestionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerQuestionRequest copyWith(
          void Function(AnswerQuestionRequest) updates) =>
      super.copyWith((message) => updates(message as AnswerQuestionRequest))
          as AnswerQuestionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AnswerQuestionRequest() / AnswerQuestionRequest.new instead')
  static AnswerQuestionRequest create() => AnswerQuestionRequest._();
  static $pb.GeneratedMessage $_createMessage() => AnswerQuestionRequest._();
  @$core.override
  AnswerQuestionRequest createEmptyInstance() => AnswerQuestionRequest._();
  @$core.pragma('dart2js:noInline')
  static AnswerQuestionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerQuestionRequest>(
          AnswerQuestionRequest.$_createMessage);
  static AnswerQuestionRequest? _defaultInstance;

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

  /// The answer by field; fields left out are unanswered.
  @$pb.TagNumber(3)
  $pb.PbList<FieldAnswer> get answers => $_getList(2);

  /// Decline the question instead of answering it.
  @$pb.TagNumber(4)
  $core.bool get decline => $_getBF(3);
  @$pb.TagNumber(4)
  set decline($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDecline() => $_has(3);
  @$pb.TagNumber(4)
  void clearDecline() => $_clearField(4);
}

class FieldAnswer extends $pb.GeneratedMessage {
  factory FieldAnswer({
    $core.String? fieldId,
    $core.Iterable<$core.String>? values,
  }) {
    final result = FieldAnswer._();
    if (fieldId != null) result.fieldId = fieldId;
    if (values != null) result.values.addAll(values);
    return result;
  }

  FieldAnswer._();

  factory FieldAnswer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FieldAnswer()..mergeFromBuffer(data, registry);
  factory FieldAnswer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FieldAnswer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FieldAnswer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FieldAnswer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'fieldId')
    ..pPS(2, _omitFieldNames ? '' : 'values')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldAnswer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FieldAnswer copyWith(void Function(FieldAnswer) updates) =>
      super.copyWith((message) => updates(message as FieldAnswer))
          as FieldAnswer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FieldAnswer() / FieldAnswer.new instead')
  static FieldAnswer create() => FieldAnswer._();
  static $pb.GeneratedMessage $_createMessage() => FieldAnswer._();
  @$core.override
  FieldAnswer createEmptyInstance() => FieldAnswer._();
  @$core.pragma('dart2js:noInline')
  static FieldAnswer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FieldAnswer>(
          FieldAnswer.$_createMessage);
  static FieldAnswer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get fieldId => $_getSZ(0);
  @$pb.TagNumber(1)
  set fieldId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFieldId() => $_has(0);
  @$pb.TagNumber(1)
  void clearFieldId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get values => $_getList(1);
}

class AnswerQuestionResponse extends $pb.GeneratedMessage {
  factory AnswerQuestionResponse() => AnswerQuestionResponse._();

  AnswerQuestionResponse._();

  factory AnswerQuestionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerQuestionResponse()..mergeFromBuffer(data, registry);
  factory AnswerQuestionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AnswerQuestionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AnswerQuestionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AnswerQuestionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerQuestionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AnswerQuestionResponse copyWith(
          void Function(AnswerQuestionResponse) updates) =>
      super.copyWith((message) => updates(message as AnswerQuestionResponse))
          as AnswerQuestionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AnswerQuestionResponse() / AnswerQuestionResponse.new instead')
  static AnswerQuestionResponse create() => AnswerQuestionResponse._();
  static $pb.GeneratedMessage $_createMessage() => AnswerQuestionResponse._();
  @$core.override
  AnswerQuestionResponse createEmptyInstance() => AnswerQuestionResponse._();
  @$core.pragma('dart2js:noInline')
  static AnswerQuestionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AnswerQuestionResponse>(
          AnswerQuestionResponse.$_createMessage);
  static AnswerQuestionResponse? _defaultInstance;
}

class SetConfigOptionRequest extends $pb.GeneratedMessage {
  factory SetConfigOptionRequest({
    $core.String? chatId,
    $core.String? configId,
    $core.String? value,
  }) {
    final result = SetConfigOptionRequest._();
    if (chatId != null) result.chatId = chatId;
    if (configId != null) result.configId = configId;
    if (value != null) result.value = value;
    return result;
  }

  SetConfigOptionRequest._();

  factory SetConfigOptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetConfigOptionRequest()..mergeFromBuffer(data, registry);
  factory SetConfigOptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetConfigOptionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetConfigOptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetConfigOptionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'configId')
    ..aOS(3, _omitFieldNames ? '' : 'value')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetConfigOptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetConfigOptionRequest copyWith(
          void Function(SetConfigOptionRequest) updates) =>
      super.copyWith((message) => updates(message as SetConfigOptionRequest))
          as SetConfigOptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetConfigOptionRequest() / SetConfigOptionRequest.new instead')
  static SetConfigOptionRequest create() => SetConfigOptionRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetConfigOptionRequest._();
  @$core.override
  SetConfigOptionRequest createEmptyInstance() => SetConfigOptionRequest._();
  @$core.pragma('dart2js:noInline')
  static SetConfigOptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetConfigOptionRequest>(
          SetConfigOptionRequest.$_createMessage);
  static SetConfigOptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get configId => $_getSZ(1);
  @$pb.TagNumber(2)
  set configId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasConfigId() => $_has(1);
  @$pb.TagNumber(2)
  void clearConfigId() => $_clearField(2);

  /// A select option's value, or "true"/"false" for a boolean.
  @$pb.TagNumber(3)
  $core.String get value => $_getSZ(2);
  @$pb.TagNumber(3)
  set value($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearValue() => $_clearField(3);
}

class SetConfigOptionResponse extends $pb.GeneratedMessage {
  factory SetConfigOptionResponse() => SetConfigOptionResponse._();

  SetConfigOptionResponse._();

  factory SetConfigOptionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetConfigOptionResponse()..mergeFromBuffer(data, registry);
  factory SetConfigOptionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetConfigOptionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetConfigOptionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetConfigOptionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetConfigOptionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetConfigOptionResponse copyWith(
          void Function(SetConfigOptionResponse) updates) =>
      super.copyWith((message) => updates(message as SetConfigOptionResponse))
          as SetConfigOptionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetConfigOptionResponse() / SetConfigOptionResponse.new instead')
  static SetConfigOptionResponse create() => SetConfigOptionResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetConfigOptionResponse._();
  @$core.override
  SetConfigOptionResponse createEmptyInstance() => SetConfigOptionResponse._();
  @$core.pragma('dart2js:noInline')
  static SetConfigOptionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetConfigOptionResponse>(
          SetConfigOptionResponse.$_createMessage);
  static SetConfigOptionResponse? _defaultInstance;
}

class GetDiffRequest extends $pb.GeneratedMessage {
  factory GetDiffRequest({
    $core.String? folder,
  }) {
    final result = GetDiffRequest._();
    if (folder != null) result.folder = folder;
    return result;
  }

  GetDiffRequest._();

  factory GetDiffRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetDiffRequest()..mergeFromBuffer(data, registry);
  factory GetDiffRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetDiffRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetDiffRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetDiffRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDiffRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDiffRequest copyWith(void Function(GetDiffRequest) updates) =>
      super.copyWith((message) => updates(message as GetDiffRequest))
          as GetDiffRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetDiffRequest() / GetDiffRequest.new instead')
  static GetDiffRequest create() => GetDiffRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetDiffRequest._();
  @$core.override
  GetDiffRequest createEmptyInstance() => GetDiffRequest._();
  @$core.pragma('dart2js:noInline')
  static GetDiffRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetDiffRequest>(
          GetDiffRequest.$_createMessage);
  static GetDiffRequest? _defaultInstance;

  /// An absolute path; it may be anywhere inside a repository.
  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);
}

class GetDiffResponse extends $pb.GeneratedMessage {
  factory GetDiffResponse({
    $core.Iterable<FileChange>? files,
  }) {
    final result = GetDiffResponse._();
    if (files != null) result.files.addAll(files);
    return result;
  }

  GetDiffResponse._();

  factory GetDiffResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetDiffResponse()..mergeFromBuffer(data, registry);
  factory GetDiffResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetDiffResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetDiffResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetDiffResponse.$_createMessage)
    ..pPM<FileChange>(1, _omitFieldNames ? '' : 'files',
        subBuilder: FileChange.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDiffResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetDiffResponse copyWith(void Function(GetDiffResponse) updates) =>
      super.copyWith((message) => updates(message as GetDiffResponse))
          as GetDiffResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetDiffResponse() / GetDiffResponse.new instead')
  static GetDiffResponse create() => GetDiffResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetDiffResponse._();
  @$core.override
  GetDiffResponse createEmptyInstance() => GetDiffResponse._();
  @$core.pragma('dart2js:noInline')
  static GetDiffResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetDiffResponse>(
          GetDiffResponse.$_createMessage);
  static GetDiffResponse? _defaultInstance;

  /// Sorted by path.
  @$pb.TagNumber(1)
  $pb.PbList<FileChange> get files => $_getList(0);
}

/// One file's change: its text at HEAD and now.
class FileChange extends $pb.GeneratedMessage {
  factory FileChange({
    $core.String? path,
    $core.String? status,
    $core.String? oldText,
    $core.String? newText,
    $core.String? skipped,
  }) {
    final result = FileChange._();
    if (path != null) result.path = path;
    if (status != null) result.status = status;
    if (oldText != null) result.oldText = oldText;
    if (newText != null) result.newText = newText;
    if (skipped != null) result.skipped = skipped;
    return result;
  }

  FileChange._();

  factory FileChange.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileChange()..mergeFromBuffer(data, registry);
  factory FileChange.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FileChange()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FileChange',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FileChange.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..aOS(3, _omitFieldNames ? '' : 'oldText')
    ..aOS(4, _omitFieldNames ? '' : 'newText')
    ..aOS(5, _omitFieldNames ? '' : 'skipped')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileChange clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FileChange copyWith(void Function(FileChange) updates) =>
      super.copyWith((message) => updates(message as FileChange)) as FileChange;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FileChange() / FileChange.new instead')
  static FileChange create() => FileChange._();
  static $pb.GeneratedMessage $_createMessage() => FileChange._();
  @$core.override
  FileChange createEmptyInstance() => FileChange._();
  @$core.pragma('dart2js:noInline')
  static FileChange getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FileChange>(FileChange.$_createMessage);
  static FileChange? _defaultInstance;

  /// Relative to the folder.
  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// "added", "modified" or "deleted".
  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get oldText => $_getSZ(2);
  @$pb.TagNumber(3)
  set oldText($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOldText() => $_has(2);
  @$pb.TagNumber(3)
  void clearOldText() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get newText => $_getSZ(3);
  @$pb.TagNumber(4)
  set newText($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNewText() => $_has(3);
  @$pb.TagNumber(4)
  void clearNewText() => $_clearField(4);

  /// Why the texts are left out ("binary", "too large"), if they are.
  @$pb.TagNumber(5)
  $core.String get skipped => $_getSZ(4);
  @$pb.TagNumber(5)
  set skipped($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSkipped() => $_has(4);
  @$pb.TagNumber(5)
  void clearSkipped() => $_clearField(5);
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

enum EventsResponse_Kind { item, status, config, chat, notSet }

class EventsResponse extends $pb.GeneratedMessage {
  factory EventsResponse({
    $core.String? chatId,
    ItemEvent? item,
    ChatStatus? status,
    ChatConfig? config,
    Chat? chat,
    $fixnum.Int64? seq,
  }) {
    final result = EventsResponse._();
    if (chatId != null) result.chatId = chatId;
    if (item != null) result.item = item;
    if (status != null) result.status = status;
    if (config != null) result.config = config;
    if (chat != null) result.chat = chat;
    if (seq != null) result.seq = seq;
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
    4: EventsResponse_Kind.config,
    5: EventsResponse_Kind.chat,
    0: EventsResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EventsResponse.$_createMessage)
    ..oo(0, [2, 3, 4, 5])
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOM<ItemEvent>(2, _omitFieldNames ? '' : 'item',
        subBuilder: ItemEvent.$_createMessage)
    ..aOM<ChatStatus>(3, _omitFieldNames ? '' : 'status',
        subBuilder: ChatStatus.$_createMessage)
    ..aOM<ChatConfig>(4, _omitFieldNames ? '' : 'config',
        subBuilder: ChatConfig.$_createMessage)
    ..aOM<Chat>(5, _omitFieldNames ? '' : 'chat',
        subBuilder: Chat.$_createMessage)
    ..aInt64(6, _omitFieldNames ? '' : 'seq')
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
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  EventsResponse_Kind whichKind() =>
      _EventsResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
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

  @$pb.TagNumber(4)
  ChatConfig get config => $_getN(3);
  @$pb.TagNumber(4)
  set config(ChatConfig value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasConfig() => $_has(3);
  @$pb.TagNumber(4)
  void clearConfig() => $_clearField(4);
  @$pb.TagNumber(4)
  ChatConfig ensureConfig() => $_ensure(3);

  /// The chat was opened, or its title or mode changed.
  @$pb.TagNumber(5)
  Chat get chat => $_getN(4);
  @$pb.TagNumber(5)
  set chat(Chat value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasChat() => $_has(4);
  @$pb.TagNumber(5)
  void clearChat() => $_clearField(5);
  @$pb.TagNumber(5)
  Chat ensureChat() => $_ensure(4);

  /// Numbers the chat's events from 1 (see GetChatResponse.seq).
  @$pb.TagNumber(6)
  $fixnum.Int64 get seq => $_getI64(5);
  @$pb.TagNumber(6)
  set seq($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSeq() => $_has(5);
  @$pb.TagNumber(6)
  void clearSeq() => $_clearField(6);
}

/// A chat's config options, all of them.
class ChatConfig extends $pb.GeneratedMessage {
  factory ChatConfig({
    $core.Iterable<ConfigOption>? options,
  }) {
    final result = ChatConfig._();
    if (options != null) result.options.addAll(options);
    return result;
  }

  ChatConfig._();

  factory ChatConfig.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatConfig()..mergeFromBuffer(data, registry);
  factory ChatConfig.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatConfig()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatConfig',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ChatConfig.$_createMessage)
    ..pPM<ConfigOption>(1, _omitFieldNames ? '' : 'options',
        subBuilder: ConfigOption.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatConfig clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatConfig copyWith(void Function(ChatConfig) updates) =>
      super.copyWith((message) => updates(message as ChatConfig)) as ChatConfig;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChatConfig() / ChatConfig.new instead')
  static ChatConfig create() => ChatConfig._();
  static $pb.GeneratedMessage $_createMessage() => ChatConfig._();
  @$core.override
  ChatConfig createEmptyInstance() => ChatConfig._();
  @$core.pragma('dart2js:noInline')
  static ChatConfig getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatConfig>(ChatConfig.$_createMessage);
  static ChatConfig? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ConfigOption> get options => $_getList(0);
}

/// One of the agent's session settings.
class ConfigOption extends $pb.GeneratedMessage {
  factory ConfigOption({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $core.String? category,
    $core.String? type,
    $core.String? current,
    $core.Iterable<ConfigValue>? values,
  }) {
    final result = ConfigOption._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (category != null) result.category = category;
    if (type != null) result.type = type;
    if (current != null) result.current = current;
    if (values != null) result.values.addAll(values);
    return result;
  }

  ConfigOption._();

  factory ConfigOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigOption()..mergeFromBuffer(data, registry);
  factory ConfigOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigOption()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfigOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ConfigOption.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'category')
    ..aOS(5, _omitFieldNames ? '' : 'type')
    ..aOS(6, _omitFieldNames ? '' : 'current')
    ..pPM<ConfigValue>(7, _omitFieldNames ? '' : 'values',
        subBuilder: ConfigValue.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigOption copyWith(void Function(ConfigOption) updates) =>
      super.copyWith((message) => updates(message as ConfigOption))
          as ConfigOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ConfigOption() / ConfigOption.new instead')
  static ConfigOption create() => ConfigOption._();
  static $pb.GeneratedMessage $_createMessage() => ConfigOption._();
  @$core.override
  ConfigOption createEmptyInstance() => ConfigOption._();
  @$core.pragma('dart2js:noInline')
  static ConfigOption getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConfigOption>(
          ConfigOption.$_createMessage);
  static ConfigOption? _defaultInstance;

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

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  /// ACP's category: mode, model, model_config, thought_level, or another.
  @$pb.TagNumber(4)
  $core.String get category => $_getSZ(3);
  @$pb.TagNumber(4)
  set category($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCategory() => $_has(3);
  @$pb.TagNumber(4)
  void clearCategory() => $_clearField(4);

  /// "select" or "boolean".
  @$pb.TagNumber(5)
  $core.String get type => $_getSZ(4);
  @$pb.TagNumber(5)
  set type($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasType() => $_has(4);
  @$pb.TagNumber(5)
  void clearType() => $_clearField(5);

  /// The current value; "true" or "false" for a boolean.
  @$pb.TagNumber(6)
  $core.String get current => $_getSZ(5);
  @$pb.TagNumber(6)
  set current($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrent() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrent() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<ConfigValue> get values => $_getList(6);
}

class ConfigValue extends $pb.GeneratedMessage {
  factory ConfigValue({
    $core.String? value,
    $core.String? name,
    $core.String? description,
    $core.String? group,
  }) {
    final result = ConfigValue._();
    if (value != null) result.value = value;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (group != null) result.group = group;
    return result;
  }

  ConfigValue._();

  factory ConfigValue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigValue()..mergeFromBuffer(data, registry);
  factory ConfigValue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfigValue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfigValue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ConfigValue.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'value')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aOS(4, _omitFieldNames ? '' : 'group')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigValue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfigValue copyWith(void Function(ConfigValue) updates) =>
      super.copyWith((message) => updates(message as ConfigValue))
          as ConfigValue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ConfigValue() / ConfigValue.new instead')
  static ConfigValue create() => ConfigValue._();
  static $pb.GeneratedMessage $_createMessage() => ConfigValue._();
  @$core.override
  ConfigValue createEmptyInstance() => ConfigValue._();
  @$core.pragma('dart2js:noInline')
  static ConfigValue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ConfigValue>(
          ConfigValue.$_createMessage);
  static ConfigValue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get value => $_getSZ(0);
  @$pb.TagNumber(1)
  set value($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearValue() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  /// The value's group, if the agent groups them.
  @$pb.TagNumber(4)
  $core.String get group => $_getSZ(3);
  @$pb.TagNumber(4)
  set group($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGroup() => $_has(3);
  @$pb.TagNumber(4)
  void clearGroup() => $_clearField(4);
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
    $core.Iterable<Option>? options,
    $core.String? answer,
    $core.Iterable<Field>? fields,
    $core.Iterable<$core.String>? paths,
    $core.Iterable<FileChange>? diffs,
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
    if (fields != null) result.fields.addAll(fields);
    if (paths != null) result.paths.addAll(paths);
    if (diffs != null) result.diffs.addAll(diffs);
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
    ..pPM<Option>(7, _omitFieldNames ? '' : 'options',
        subBuilder: Option.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'answer')
    ..pPM<Field>(9, _omitFieldNames ? '' : 'fields',
        subBuilder: Field.$_createMessage)
    ..pPS(10, _omitFieldNames ? '' : 'paths')
    ..pPM<FileChange>(11, _omitFieldNames ? '' : 'diffs',
        subBuilder: FileChange.$_createMessage)
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

  /// The message, or a tool call's output as markdown (its diffs apart).
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
  $pb.PbList<Option> get options => $_getList(6);

  @$pb.TagNumber(8)
  $core.String get answer => $_getSZ(7);
  @$pb.TagNumber(8)
  set answer($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAnswer() => $_has(7);
  @$pb.TagNumber(8)
  void clearAnswer() => $_clearField(8);

  /// A question's form, in the agent's order.
  @$pb.TagNumber(9)
  $pb.PbList<Field> get fields => $_getList(8);

  /// The files a tool call works on, relative to the chat's folder when
  /// inside it, and the edits it makes (path, old_text, new_text).
  @$pb.TagNumber(10)
  $pb.PbList<$core.String> get paths => $_getList(9);

  @$pb.TagNumber(11)
  $pb.PbList<FileChange> get diffs => $_getList(10);
}

/// A choice the agent offers.
class Option extends $pb.GeneratedMessage {
  factory Option({
    $core.String? id,
    $core.String? name,
    $core.String? kind,
    $core.String? description,
  }) {
    final result = Option._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (kind != null) result.kind = kind;
    if (description != null) result.description = description;
    return result;
  }

  Option._();

  factory Option.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Option()..mergeFromBuffer(data, registry);
  factory Option.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Option()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Option',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Option.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'kind')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Option clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Option copyWith(void Function(Option) updates) =>
      super.copyWith((message) => updates(message as Option)) as Option;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Option() / Option.new instead')
  static Option create() => Option._();
  static $pb.GeneratedMessage $_createMessage() => Option._();
  @$core.override
  Option createEmptyInstance() => Option._();
  @$core.pragma('dart2js:noInline')
  static Option getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Option>(Option.$_createMessage);
  static Option? _defaultInstance;

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

  /// For a permission option, ACP's hint: allow_once, allow_always,
  /// reject_once or reject_always.
  @$pb.TagNumber(3)
  $core.String get kind => $_getSZ(2);
  @$pb.TagNumber(3)
  set kind($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKind() => $_has(2);
  @$pb.TagNumber(3)
  void clearKind() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);
}

/// One entry of a question's form.
class Field extends $pb.GeneratedMessage {
  factory Field({
    $core.String? id,
    $core.String? title,
    $core.String? description,
    FieldType? type,
    $core.Iterable<Option>? options,
    $core.bool? required,
    $core.Iterable<$core.String>? values,
  }) {
    final result = Field._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (description != null) result.description = description;
    if (type != null) result.type = type;
    if (options != null) result.options.addAll(options);
    if (required != null) result.required = required;
    if (values != null) result.values.addAll(values);
    return result;
  }

  Field._();

  factory Field.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Field()..mergeFromBuffer(data, registry);
  factory Field.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Field()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Field',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Field.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aE<FieldType>(4, _omitFieldNames ? '' : 'type',
        enumValues: FieldType.values)
    ..pPM<Option>(5, _omitFieldNames ? '' : 'options',
        subBuilder: Option.$_createMessage)
    ..aOB(6, _omitFieldNames ? '' : 'required')
    ..pPS(7, _omitFieldNames ? '' : 'values')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Field clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Field copyWith(void Function(Field) updates) =>
      super.copyWith((message) => updates(message as Field)) as Field;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Field() / Field.new instead')
  static Field create() => Field._();
  static $pb.GeneratedMessage $_createMessage() => Field._();
  @$core.override
  Field createEmptyInstance() => Field._();
  @$core.pragma('dart2js:noInline')
  static Field getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Field>(Field.$_createMessage);
  static Field? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  FieldType get type => $_getN(3);
  @$pb.TagNumber(4)
  set type(FieldType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasType() => $_has(3);
  @$pb.TagNumber(4)
  void clearType() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<Option> get options => $_getList(4);

  @$pb.TagNumber(6)
  $core.bool get required => $_getBF(5);
  @$pb.TagNumber(6)
  set required($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRequired() => $_has(5);
  @$pb.TagNumber(6)
  void clearRequired() => $_clearField(6);

  /// The answer, once given: one value, or several for CHOICES.
  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get values => $_getList(6);
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

  /// Lists every stored chat.
  $async.Future<ListChatsResponse> listChats(
          $pb.ClientContext? ctx, ListChatsRequest request) =>
      _client.invoke<ListChatsResponse>(
          ctx, 'NushiService', 'ListChats', request, ListChatsResponse());

  /// Returns everything a chat's events have built so far, to pick it up
  /// after (re)connecting.
  $async.Future<GetChatResponse> getChat(
          $pb.ClientContext? ctx, GetChatRequest request) =>
      _client.invoke<GetChatResponse>(
          ctx, 'NushiService', 'GetChat', request, GetChatResponse());

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

  /// Answers a pending question, or declines it.
  $async.Future<AnswerQuestionResponse> answerQuestion(
          $pb.ClientContext? ctx, AnswerQuestionRequest request) =>
      _client.invoke<AnswerQuestionResponse>(ctx, 'NushiService',
          'AnswerQuestion', request, AnswerQuestionResponse());

  /// Sets one of a chat's config options (mode, model, ...). Picking a mode
  /// makes new chats with the same agent start in it.
  $async.Future<SetConfigOptionResponse> setConfigOption(
          $pb.ClientContext? ctx, SetConfigOptionRequest request) =>
      _client.invoke<SetConfigOptionResponse>(ctx, 'NushiService',
          'SetConfigOption', request, SetConfigOptionResponse());

  /// Returns a folder's uncommitted changes against HEAD, untracked files
  /// included.
  $async.Future<GetDiffResponse> getDiff(
          $pb.ClientContext? ctx, GetDiffRequest request) =>
      _client.invoke<GetDiffResponse>(
          ctx, 'NushiService', 'GetDiff', request, GetDiffResponse());

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
