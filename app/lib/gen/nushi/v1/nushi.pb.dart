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
    ChatStatus? status,
    $core.bool? archived,
    $core.String? sessionId,
    Worktree? worktree,
  }) {
    final result = Chat._();
    if (id != null) result.id = id;
    if (agent != null) result.agent = agent;
    if (folder != null) result.folder = folder;
    if (title != null) result.title = title;
    if (mode != null) result.mode = mode;
    if (createdUnixMs != null) result.createdUnixMs = createdUnixMs;
    if (status != null) result.status = status;
    if (archived != null) result.archived = archived;
    if (sessionId != null) result.sessionId = sessionId;
    if (worktree != null) result.worktree = worktree;
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
    ..aOM<ChatStatus>(7, _omitFieldNames ? '' : 'status',
        subBuilder: ChatStatus.$_createMessage)
    ..aOB(8, _omitFieldNames ? '' : 'archived')
    ..aOS(9, _omitFieldNames ? '' : 'sessionId')
    ..aOM<Worktree>(10, _omitFieldNames ? '' : 'worktree',
        subBuilder: Worktree.$_createMessage)
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

  /// The title the user set, or else the agent's.
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

  /// Whether it works or waits on the user, for a list of chats.
  @$pb.TagNumber(7)
  ChatStatus get status => $_getN(6);
  @$pb.TagNumber(7)
  set status(ChatStatus value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasStatus() => $_has(6);
  @$pb.TagNumber(7)
  void clearStatus() => $_clearField(7);
  @$pb.TagNumber(7)
  ChatStatus ensureStatus() => $_ensure(6);

  /// Archived chats have no agent running and take no prompts.
  @$pb.TagNumber(8)
  $core.bool get archived => $_getBF(7);
  @$pb.TagNumber(8)
  set archived($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasArchived() => $_has(7);
  @$pb.TagNumber(8)
  void clearArchived() => $_clearField(8);

  /// The agent's session id (claude --resume <id>). It differs from id for
  /// chats started since API 16.
  @$pb.TagNumber(9)
  $core.String get sessionId => $_getSZ(8);
  @$pb.TagNumber(9)
  set sessionId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionId() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionId() => $_clearField(9);

  /// The git worktree Nushi made for the chat, if it runs in one (API 20).
  @$pb.TagNumber(10)
  Worktree get worktree => $_getN(9);
  @$pb.TagNumber(10)
  set worktree(Worktree value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasWorktree() => $_has(9);
  @$pb.TagNumber(10)
  void clearWorktree() => $_clearField(10);
  @$pb.TagNumber(10)
  Worktree ensureWorktree() => $_ensure(9);
}

/// A git worktree of a repository, on a branch of its own.
class Worktree extends $pb.GeneratedMessage {
  factory Worktree({
    $core.String? repo,
    $core.String? path,
    $core.String? branch,
    $core.String? base,
  }) {
    final result = Worktree._();
    if (repo != null) result.repo = repo;
    if (path != null) result.path = path;
    if (branch != null) result.branch = branch;
    if (base != null) result.base = base;
    return result;
  }

  Worktree._();

  factory Worktree.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Worktree()..mergeFromBuffer(data, registry);
  factory Worktree.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Worktree()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Worktree',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Worktree.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'repo')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aOS(3, _omitFieldNames ? '' : 'branch')
    ..aOS(4, _omitFieldNames ? '' : 'base')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Worktree clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Worktree copyWith(void Function(Worktree) updates) =>
      super.copyWith((message) => updates(message as Worktree)) as Worktree;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Worktree() / Worktree.new instead')
  static Worktree create() => Worktree._();
  static $pb.GeneratedMessage $_createMessage() => Worktree._();
  @$core.override
  Worktree createEmptyInstance() => Worktree._();
  @$core.pragma('dart2js:noInline')
  static Worktree getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Worktree>(Worktree.$_createMessage);
  static Worktree? _defaultInstance;

  /// The repository's folder (its main worktree).
  @$pb.TagNumber(1)
  $core.String get repo => $_getSZ(0);
  @$pb.TagNumber(1)
  set repo($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRepo() => $_has(0);
  @$pb.TagNumber(1)
  void clearRepo() => $_clearField(1);

  /// The worktree's folder; the chat's folder is in it.
  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  /// Its branch, nushi/<name>.
  @$pb.TagNumber(3)
  $core.String get branch => $_getSZ(2);
  @$pb.TagNumber(3)
  set branch($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBranch() => $_has(2);
  @$pb.TagNumber(3)
  void clearBranch() => $_clearField(3);

  /// The branch it started from (a commit, if HEAD was detached).
  @$pb.TagNumber(4)
  $core.String get base => $_getSZ(3);
  @$pb.TagNumber(4)
  set base($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBase() => $_has(3);
  @$pb.TagNumber(4)
  void clearBase() => $_clearField(4);
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
    $core.Iterable<Command>? commands,
    Usage? usage,
  }) {
    final result = GetChatResponse._();
    if (chat != null) result.chat = chat;
    if (items != null) result.items.addAll(items);
    if (config != null) result.config.addAll(config);
    if (status != null) result.status = status;
    if (seq != null) result.seq = seq;
    if (commands != null) result.commands.addAll(commands);
    if (usage != null) result.usage = usage;
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
    ..pPM<Command>(6, _omitFieldNames ? '' : 'commands',
        subBuilder: Command.$_createMessage)
    ..aOM<Usage>(7, _omitFieldNames ? '' : 'usage',
        subBuilder: Usage.$_createMessage)
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

  /// The agent's slash commands.
  @$pb.TagNumber(6)
  $pb.PbList<Command> get commands => $_getList(5);

  @$pb.TagNumber(7)
  Usage get usage => $_getN(6);
  @$pb.TagNumber(7)
  set usage(Usage value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasUsage() => $_has(6);
  @$pb.TagNumber(7)
  void clearUsage() => $_clearField(7);
  @$pb.TagNumber(7)
  Usage ensureUsage() => $_ensure(6);
}

/// What the agent last reported of a chat's usage; what it hasn't reported
/// is zero. It starts empty when the daemon restarts.
class Usage extends $pb.GeneratedMessage {
  factory Usage({
    $fixnum.Int64? contextUsed,
    $fixnum.Int64? contextSize,
    $core.double? cost,
    $core.String? currency,
    $fixnum.Int64? inputTokens,
    $fixnum.Int64? outputTokens,
    $fixnum.Int64? cachedReadTokens,
    $fixnum.Int64? cachedWriteTokens,
  }) {
    final result = Usage._();
    if (contextUsed != null) result.contextUsed = contextUsed;
    if (contextSize != null) result.contextSize = contextSize;
    if (cost != null) result.cost = cost;
    if (currency != null) result.currency = currency;
    if (inputTokens != null) result.inputTokens = inputTokens;
    if (outputTokens != null) result.outputTokens = outputTokens;
    if (cachedReadTokens != null) result.cachedReadTokens = cachedReadTokens;
    if (cachedWriteTokens != null) result.cachedWriteTokens = cachedWriteTokens;
    return result;
  }

  Usage._();

  factory Usage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Usage()..mergeFromBuffer(data, registry);
  factory Usage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Usage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Usage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Usage.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'contextUsed')
    ..aInt64(2, _omitFieldNames ? '' : 'contextSize')
    ..aD(3, _omitFieldNames ? '' : 'cost')
    ..aOS(4, _omitFieldNames ? '' : 'currency')
    ..aInt64(5, _omitFieldNames ? '' : 'inputTokens')
    ..aInt64(6, _omitFieldNames ? '' : 'outputTokens')
    ..aInt64(7, _omitFieldNames ? '' : 'cachedReadTokens')
    ..aInt64(8, _omitFieldNames ? '' : 'cachedWriteTokens')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Usage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Usage copyWith(void Function(Usage) updates) =>
      super.copyWith((message) => updates(message as Usage)) as Usage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Usage() / Usage.new instead')
  static Usage create() => Usage._();
  static $pb.GeneratedMessage $_createMessage() => Usage._();
  @$core.override
  Usage createEmptyInstance() => Usage._();
  @$core.pragma('dart2js:noInline')
  static Usage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Usage>(Usage.$_createMessage);
  static Usage? _defaultInstance;

  /// Context tokens in use, and the context window's size (ACP
  /// usage_update).
  @$pb.TagNumber(1)
  $fixnum.Int64 get contextUsed => $_getI64(0);
  @$pb.TagNumber(1)
  set contextUsed($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContextUsed() => $_has(0);
  @$pb.TagNumber(1)
  void clearContextUsed() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get contextSize => $_getI64(1);
  @$pb.TagNumber(2)
  set contextSize($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasContextSize() => $_has(1);
  @$pb.TagNumber(2)
  void clearContextSize() => $_clearField(2);

  /// The session's cost so far, in currency (ISO 4217).
  @$pb.TagNumber(3)
  $core.double get cost => $_getN(2);
  @$pb.TagNumber(3)
  set cost($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCost() => $_has(2);
  @$pb.TagNumber(3)
  void clearCost() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currency => $_getSZ(3);
  @$pb.TagNumber(4)
  set currency($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrency() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrency() => $_clearField(4);

  /// The last turn's tokens (the prompt response's usage).
  @$pb.TagNumber(5)
  $fixnum.Int64 get inputTokens => $_getI64(4);
  @$pb.TagNumber(5)
  set inputTokens($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInputTokens() => $_has(4);
  @$pb.TagNumber(5)
  void clearInputTokens() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get outputTokens => $_getI64(5);
  @$pb.TagNumber(6)
  set outputTokens($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOutputTokens() => $_has(5);
  @$pb.TagNumber(6)
  void clearOutputTokens() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get cachedReadTokens => $_getI64(6);
  @$pb.TagNumber(7)
  set cachedReadTokens($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCachedReadTokens() => $_has(6);
  @$pb.TagNumber(7)
  void clearCachedReadTokens() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get cachedWriteTokens => $_getI64(7);
  @$pb.TagNumber(8)
  set cachedWriteTokens($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCachedWriteTokens() => $_has(7);
  @$pb.TagNumber(8)
  void clearCachedWriteTokens() => $_clearField(8);
}

/// A slash command the agent offers; it is sent as a prompt starting with
/// "/name".
class Command extends $pb.GeneratedMessage {
  factory Command({
    $core.String? name,
    $core.String? description,
    $core.String? hint,
  }) {
    final result = Command._();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (hint != null) result.hint = hint;
    return result;
  }

  Command._();

  factory Command.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Command()..mergeFromBuffer(data, registry);
  factory Command.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Command()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Command',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Command.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'hint')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Command clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Command copyWith(void Function(Command) updates) =>
      super.copyWith((message) => updates(message as Command)) as Command;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Command() / Command.new instead')
  static Command create() => Command._();
  static $pb.GeneratedMessage $_createMessage() => Command._();
  @$core.override
  Command createEmptyInstance() => Command._();
  @$core.pragma('dart2js:noInline')
  static Command getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Command>(Command.$_createMessage);
  static Command? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  /// What to type after the name, if it takes input.
  @$pb.TagNumber(3)
  $core.String get hint => $_getSZ(2);
  @$pb.TagNumber(3)
  set hint($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHint() => $_has(2);
  @$pb.TagNumber(3)
  void clearHint() => $_clearField(3);
}

class ChatCommands extends $pb.GeneratedMessage {
  factory ChatCommands({
    $core.Iterable<Command>? commands,
  }) {
    final result = ChatCommands._();
    if (commands != null) result.commands.addAll(commands);
    return result;
  }

  ChatCommands._();

  factory ChatCommands.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatCommands()..mergeFromBuffer(data, registry);
  factory ChatCommands.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatCommands()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatCommands',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ChatCommands.$_createMessage)
    ..pPM<Command>(1, _omitFieldNames ? '' : 'commands',
        subBuilder: Command.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatCommands clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatCommands copyWith(void Function(ChatCommands) updates) =>
      super.copyWith((message) => updates(message as ChatCommands))
          as ChatCommands;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChatCommands() / ChatCommands.new instead')
  static ChatCommands create() => ChatCommands._();
  static $pb.GeneratedMessage $_createMessage() => ChatCommands._();
  @$core.override
  ChatCommands createEmptyInstance() => ChatCommands._();
  @$core.pragma('dart2js:noInline')
  static ChatCommands getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatCommands>(
          ChatCommands.$_createMessage);
  static ChatCommands? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Command> get commands => $_getList(0);
}

class StartChatRequest extends $pb.GeneratedMessage {
  factory StartChatRequest({
    $core.String? folder,
    $core.bool? worktree,
  }) {
    final result = StartChatRequest._();
    if (folder != null) result.folder = folder;
    if (worktree != null) result.worktree = worktree;
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
    ..aOB(2, _omitFieldNames ? '' : 'worktree')
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

  /// Empty: a scratch folder of the chat's own, in the daemon's data folder.
  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// Run the chat in a new worktree of folder's repository, at
  /// <repo>/.worktrees/<name> on a new branch nushi/<name> from folder's
  /// HEAD (API 20).
  @$pb.TagNumber(2)
  $core.bool get worktree => $_getBF(1);
  @$pb.TagNumber(2)
  set worktree($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktree() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktree() => $_clearField(2);
}

class MoveChatRequest extends $pb.GeneratedMessage {
  factory MoveChatRequest({
    $core.String? chatId,
    $core.String? folder,
    $core.bool? worktree,
  }) {
    final result = MoveChatRequest._();
    if (chatId != null) result.chatId = chatId;
    if (folder != null) result.folder = folder;
    if (worktree != null) result.worktree = worktree;
    return result;
  }

  MoveChatRequest._();

  factory MoveChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MoveChatRequest()..mergeFromBuffer(data, registry);
  factory MoveChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MoveChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MoveChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: MoveChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'folder')
    ..aOB(3, _omitFieldNames ? '' : 'worktree')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveChatRequest copyWith(void Function(MoveChatRequest) updates) =>
      super.copyWith((message) => updates(message as MoveChatRequest))
          as MoveChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MoveChatRequest() / MoveChatRequest.new instead')
  static MoveChatRequest create() => MoveChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => MoveChatRequest._();
  @$core.override
  MoveChatRequest createEmptyInstance() => MoveChatRequest._();
  @$core.pragma('dart2js:noInline')
  static MoveChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveChatRequest>(
          MoveChatRequest.$_createMessage);
  static MoveChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get folder => $_getSZ(1);
  @$pb.TagNumber(2)
  set folder($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFolder() => $_has(1);
  @$pb.TagNumber(2)
  void clearFolder() => $_clearField(2);

  /// Move to a new worktree of folder's repository, as StartChat makes one.
  @$pb.TagNumber(3)
  $core.bool get worktree => $_getBF(2);
  @$pb.TagNumber(3)
  set worktree($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWorktree() => $_has(2);
  @$pb.TagNumber(3)
  void clearWorktree() => $_clearField(3);
}

class MoveChatResponse extends $pb.GeneratedMessage {
  factory MoveChatResponse() => MoveChatResponse._();

  MoveChatResponse._();

  factory MoveChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MoveChatResponse()..mergeFromBuffer(data, registry);
  factory MoveChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      MoveChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MoveChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: MoveChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MoveChatResponse copyWith(void Function(MoveChatResponse) updates) =>
      super.copyWith((message) => updates(message as MoveChatResponse))
          as MoveChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use MoveChatResponse() / MoveChatResponse.new instead')
  static MoveChatResponse create() => MoveChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => MoveChatResponse._();
  @$core.override
  MoveChatResponse createEmptyInstance() => MoveChatResponse._();
  @$core.pragma('dart2js:noInline')
  static MoveChatResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MoveChatResponse>(
          MoveChatResponse.$_createMessage);
  static MoveChatResponse? _defaultInstance;
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
    $core.Iterable<$core.String>? files,
    $core.Iterable<ImageData>? images,
  }) {
    final result = SendPromptRequest._();
    if (chatId != null) result.chatId = chatId;
    if (text != null) result.text = text;
    if (files != null) result.files.addAll(files);
    if (images != null) result.images.addAll(images);
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
    ..pPS(3, _omitFieldNames ? '' : 'files')
    ..pPM<ImageData>(4, _omitFieldNames ? '' : 'images',
        subBuilder: ImageData.$_createMessage)
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

  /// Files the prompt mentions, relative to the chat's folder; they go to
  /// the agent as resource links after the text.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get files => $_getList(2);

  /// Images, after the files; refused unless status.images.
  @$pb.TagNumber(4)
  $pb.PbList<ImageData> get images => $_getList(3);
}

/// An image in a prompt, a message or a tool call's output.
class ImageData extends $pb.GeneratedMessage {
  factory ImageData({
    $core.String? mimeType,
    $core.List<$core.int>? data,
  }) {
    final result = ImageData._();
    if (mimeType != null) result.mimeType = mimeType;
    if (data != null) result.data = data;
    return result;
  }

  ImageData._();

  factory ImageData.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageData()..mergeFromBuffer(data, registry);
  factory ImageData.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ImageData()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImageData',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ImageData.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'mimeType')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageData clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImageData copyWith(void Function(ImageData) updates) =>
      super.copyWith((message) => updates(message as ImageData)) as ImageData;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ImageData() / ImageData.new instead')
  static ImageData create() => ImageData._();
  static $pb.GeneratedMessage $_createMessage() => ImageData._();
  @$core.override
  ImageData createEmptyInstance() => ImageData._();
  @$core.pragma('dart2js:noInline')
  static ImageData getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImageData>(ImageData.$_createMessage);
  static ImageData? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get mimeType => $_getSZ(0);
  @$pb.TagNumber(1)
  set mimeType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMimeType() => $_has(0);
  @$pb.TagNumber(1)
  void clearMimeType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class ListFilesRequest extends $pb.GeneratedMessage {
  factory ListFilesRequest({
    $core.String? folder,
  }) {
    final result = ListFilesRequest._();
    if (folder != null) result.folder = folder;
    return result;
  }

  ListFilesRequest._();

  factory ListFilesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesRequest()..mergeFromBuffer(data, registry);
  factory ListFilesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListFilesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListFilesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesRequest copyWith(void Function(ListFilesRequest) updates) =>
      super.copyWith((message) => updates(message as ListFilesRequest))
          as ListFilesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListFilesRequest() / ListFilesRequest.new instead')
  static ListFilesRequest create() => ListFilesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListFilesRequest._();
  @$core.override
  ListFilesRequest createEmptyInstance() => ListFilesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListFilesRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListFilesRequest>(
          ListFilesRequest.$_createMessage);
  static ListFilesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);
}

class ListFilesResponse extends $pb.GeneratedMessage {
  factory ListFilesResponse({
    $core.Iterable<$core.String>? paths,
  }) {
    final result = ListFilesResponse._();
    if (paths != null) result.paths.addAll(paths);
    return result;
  }

  ListFilesResponse._();

  factory ListFilesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesResponse()..mergeFromBuffer(data, registry);
  factory ListFilesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListFilesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListFilesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListFilesResponse.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'paths')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListFilesResponse copyWith(void Function(ListFilesResponse) updates) =>
      super.copyWith((message) => updates(message as ListFilesResponse))
          as ListFilesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListFilesResponse() / ListFilesResponse.new instead')
  static ListFilesResponse create() => ListFilesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListFilesResponse._();
  @$core.override
  ListFilesResponse createEmptyInstance() => ListFilesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListFilesResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListFilesResponse>(
          ListFilesResponse.$_createMessage);
  static ListFilesResponse? _defaultInstance;

  /// Relative to the folder.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get paths => $_getList(0);
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

class CancelTurnRequest extends $pb.GeneratedMessage {
  factory CancelTurnRequest({
    $core.String? chatId,
  }) {
    final result = CancelTurnRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  CancelTurnRequest._();

  factory CancelTurnRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTurnRequest()..mergeFromBuffer(data, registry);
  factory CancelTurnRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTurnRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelTurnRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CancelTurnRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTurnRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTurnRequest copyWith(void Function(CancelTurnRequest) updates) =>
      super.copyWith((message) => updates(message as CancelTurnRequest))
          as CancelTurnRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CancelTurnRequest() / CancelTurnRequest.new instead')
  static CancelTurnRequest create() => CancelTurnRequest._();
  static $pb.GeneratedMessage $_createMessage() => CancelTurnRequest._();
  @$core.override
  CancelTurnRequest createEmptyInstance() => CancelTurnRequest._();
  @$core.pragma('dart2js:noInline')
  static CancelTurnRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<CancelTurnRequest>(
          CancelTurnRequest.$_createMessage);
  static CancelTurnRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class CancelTurnResponse extends $pb.GeneratedMessage {
  factory CancelTurnResponse() => CancelTurnResponse._();

  CancelTurnResponse._();

  factory CancelTurnResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTurnResponse()..mergeFromBuffer(data, registry);
  factory CancelTurnResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CancelTurnResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CancelTurnResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CancelTurnResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTurnResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CancelTurnResponse copyWith(void Function(CancelTurnResponse) updates) =>
      super.copyWith((message) => updates(message as CancelTurnResponse))
          as CancelTurnResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CancelTurnResponse() / CancelTurnResponse.new instead')
  static CancelTurnResponse create() => CancelTurnResponse._();
  static $pb.GeneratedMessage $_createMessage() => CancelTurnResponse._();
  @$core.override
  CancelTurnResponse createEmptyInstance() => CancelTurnResponse._();
  @$core.pragma('dart2js:noInline')
  static CancelTurnResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CancelTurnResponse>(
          CancelTurnResponse.$_createMessage);
  static CancelTurnResponse? _defaultInstance;
}

class ForkChatRequest extends $pb.GeneratedMessage {
  factory ForkChatRequest({
    $core.String? chatId,
  }) {
    final result = ForkChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  ForkChatRequest._();

  factory ForkChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkChatRequest()..mergeFromBuffer(data, registry);
  factory ForkChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForkChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ForkChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkChatRequest copyWith(void Function(ForkChatRequest) updates) =>
      super.copyWith((message) => updates(message as ForkChatRequest))
          as ForkChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ForkChatRequest() / ForkChatRequest.new instead')
  static ForkChatRequest create() => ForkChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => ForkChatRequest._();
  @$core.override
  ForkChatRequest createEmptyInstance() => ForkChatRequest._();
  @$core.pragma('dart2js:noInline')
  static ForkChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ForkChatRequest>(
          ForkChatRequest.$_createMessage);
  static ForkChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class ForkChatResponse extends $pb.GeneratedMessage {
  factory ForkChatResponse({
    $core.String? chatId,
  }) {
    final result = ForkChatResponse._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  ForkChatResponse._();

  factory ForkChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkChatResponse()..mergeFromBuffer(data, registry);
  factory ForkChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ForkChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ForkChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ForkChatResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ForkChatResponse copyWith(void Function(ForkChatResponse) updates) =>
      super.copyWith((message) => updates(message as ForkChatResponse))
          as ForkChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ForkChatResponse() / ForkChatResponse.new instead')
  static ForkChatResponse create() => ForkChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => ForkChatResponse._();
  @$core.override
  ForkChatResponse createEmptyInstance() => ForkChatResponse._();
  @$core.pragma('dart2js:noInline')
  static ForkChatResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ForkChatResponse>(
          ForkChatResponse.$_createMessage);
  static ForkChatResponse? _defaultInstance;

  /// The side chat's id.
  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class CloseSideChatRequest extends $pb.GeneratedMessage {
  factory CloseSideChatRequest({
    $core.String? chatId,
  }) {
    final result = CloseSideChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  CloseSideChatRequest._();

  factory CloseSideChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseSideChatRequest()..mergeFromBuffer(data, registry);
  factory CloseSideChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseSideChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseSideChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CloseSideChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseSideChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseSideChatRequest copyWith(void Function(CloseSideChatRequest) updates) =>
      super.copyWith((message) => updates(message as CloseSideChatRequest))
          as CloseSideChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CloseSideChatRequest() / CloseSideChatRequest.new instead')
  static CloseSideChatRequest create() => CloseSideChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => CloseSideChatRequest._();
  @$core.override
  CloseSideChatRequest createEmptyInstance() => CloseSideChatRequest._();
  @$core.pragma('dart2js:noInline')
  static CloseSideChatRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloseSideChatRequest>(
          CloseSideChatRequest.$_createMessage);
  static CloseSideChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class CloseSideChatResponse extends $pb.GeneratedMessage {
  factory CloseSideChatResponse() => CloseSideChatResponse._();

  CloseSideChatResponse._();

  factory CloseSideChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseSideChatResponse()..mergeFromBuffer(data, registry);
  factory CloseSideChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseSideChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseSideChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CloseSideChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseSideChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseSideChatResponse copyWith(
          void Function(CloseSideChatResponse) updates) =>
      super.copyWith((message) => updates(message as CloseSideChatResponse))
          as CloseSideChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CloseSideChatResponse() / CloseSideChatResponse.new instead')
  static CloseSideChatResponse create() => CloseSideChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => CloseSideChatResponse._();
  @$core.override
  CloseSideChatResponse createEmptyInstance() => CloseSideChatResponse._();
  @$core.pragma('dart2js:noInline')
  static CloseSideChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloseSideChatResponse>(
          CloseSideChatResponse.$_createMessage);
  static CloseSideChatResponse? _defaultInstance;
}

class RenameChatRequest extends $pb.GeneratedMessage {
  factory RenameChatRequest({
    $core.String? chatId,
    $core.String? title,
  }) {
    final result = RenameChatRequest._();
    if (chatId != null) result.chatId = chatId;
    if (title != null) result.title = title;
    return result;
  }

  RenameChatRequest._();

  factory RenameChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameChatRequest()..mergeFromBuffer(data, registry);
  factory RenameChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RenameChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameChatRequest copyWith(void Function(RenameChatRequest) updates) =>
      super.copyWith((message) => updates(message as RenameChatRequest))
          as RenameChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenameChatRequest() / RenameChatRequest.new instead')
  static RenameChatRequest create() => RenameChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => RenameChatRequest._();
  @$core.override
  RenameChatRequest createEmptyInstance() => RenameChatRequest._();
  @$core.pragma('dart2js:noInline')
  static RenameChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RenameChatRequest>(
          RenameChatRequest.$_createMessage);
  static RenameChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);
}

class RenameChatResponse extends $pb.GeneratedMessage {
  factory RenameChatResponse() => RenameChatResponse._();

  RenameChatResponse._();

  factory RenameChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameChatResponse()..mergeFromBuffer(data, registry);
  factory RenameChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RenameChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameChatResponse copyWith(void Function(RenameChatResponse) updates) =>
      super.copyWith((message) => updates(message as RenameChatResponse))
          as RenameChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RenameChatResponse() / RenameChatResponse.new instead')
  static RenameChatResponse create() => RenameChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => RenameChatResponse._();
  @$core.override
  RenameChatResponse createEmptyInstance() => RenameChatResponse._();
  @$core.pragma('dart2js:noInline')
  static RenameChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameChatResponse>(
          RenameChatResponse.$_createMessage);
  static RenameChatResponse? _defaultInstance;
}

class ArchiveChatRequest extends $pb.GeneratedMessage {
  factory ArchiveChatRequest({
    $core.String? chatId,
    $core.bool? archived,
  }) {
    final result = ArchiveChatRequest._();
    if (chatId != null) result.chatId = chatId;
    if (archived != null) result.archived = archived;
    return result;
  }

  ArchiveChatRequest._();

  factory ArchiveChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveChatRequest()..mergeFromBuffer(data, registry);
  factory ArchiveChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArchiveChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ArchiveChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOB(2, _omitFieldNames ? '' : 'archived')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveChatRequest copyWith(void Function(ArchiveChatRequest) updates) =>
      super.copyWith((message) => updates(message as ArchiveChatRequest))
          as ArchiveChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ArchiveChatRequest() / ArchiveChatRequest.new instead')
  static ArchiveChatRequest create() => ArchiveChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => ArchiveChatRequest._();
  @$core.override
  ArchiveChatRequest createEmptyInstance() => ArchiveChatRequest._();
  @$core.pragma('dart2js:noInline')
  static ArchiveChatRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArchiveChatRequest>(
          ArchiveChatRequest.$_createMessage);
  static ArchiveChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  /// False unarchives it.
  @$pb.TagNumber(2)
  $core.bool get archived => $_getBF(1);
  @$pb.TagNumber(2)
  set archived($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasArchived() => $_has(1);
  @$pb.TagNumber(2)
  void clearArchived() => $_clearField(2);
}

class ArchiveChatResponse extends $pb.GeneratedMessage {
  factory ArchiveChatResponse() => ArchiveChatResponse._();

  ArchiveChatResponse._();

  factory ArchiveChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveChatResponse()..mergeFromBuffer(data, registry);
  factory ArchiveChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArchiveChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArchiveChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ArchiveChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArchiveChatResponse copyWith(void Function(ArchiveChatResponse) updates) =>
      super.copyWith((message) => updates(message as ArchiveChatResponse))
          as ArchiveChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ArchiveChatResponse() / ArchiveChatResponse.new instead')
  static ArchiveChatResponse create() => ArchiveChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => ArchiveChatResponse._();
  @$core.override
  ArchiveChatResponse createEmptyInstance() => ArchiveChatResponse._();
  @$core.pragma('dart2js:noInline')
  static ArchiveChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArchiveChatResponse>(
          ArchiveChatResponse.$_createMessage);
  static ArchiveChatResponse? _defaultInstance;
}

class RemoveChatRequest extends $pb.GeneratedMessage {
  factory RemoveChatRequest({
    $core.String? chatId,
  }) {
    final result = RemoveChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  RemoveChatRequest._();

  factory RemoveChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveChatRequest()..mergeFromBuffer(data, registry);
  factory RemoveChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveChatRequest copyWith(void Function(RemoveChatRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveChatRequest))
          as RemoveChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemoveChatRequest() / RemoveChatRequest.new instead')
  static RemoveChatRequest create() => RemoveChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveChatRequest._();
  @$core.override
  RemoveChatRequest createEmptyInstance() => RemoveChatRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemoveChatRequest>(
          RemoveChatRequest.$_createMessage);
  static RemoveChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class RemoveChatResponse extends $pb.GeneratedMessage {
  factory RemoveChatResponse() => RemoveChatResponse._();

  RemoveChatResponse._();

  factory RemoveChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveChatResponse()..mergeFromBuffer(data, registry);
  factory RemoveChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveChatResponse copyWith(void Function(RemoveChatResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveChatResponse))
          as RemoveChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemoveChatResponse() / RemoveChatResponse.new instead')
  static RemoveChatResponse create() => RemoveChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => RemoveChatResponse._();
  @$core.override
  RemoveChatResponse createEmptyInstance() => RemoveChatResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveChatResponse>(
          RemoveChatResponse.$_createMessage);
  static RemoveChatResponse? _defaultInstance;
}

class PlanDeleteChatRequest extends $pb.GeneratedMessage {
  factory PlanDeleteChatRequest({
    $core.String? chatId,
  }) {
    final result = PlanDeleteChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  PlanDeleteChatRequest._();

  factory PlanDeleteChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanDeleteChatRequest()..mergeFromBuffer(data, registry);
  factory PlanDeleteChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanDeleteChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanDeleteChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: PlanDeleteChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanDeleteChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanDeleteChatRequest copyWith(
          void Function(PlanDeleteChatRequest) updates) =>
      super.copyWith((message) => updates(message as PlanDeleteChatRequest))
          as PlanDeleteChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PlanDeleteChatRequest() / PlanDeleteChatRequest.new instead')
  static PlanDeleteChatRequest create() => PlanDeleteChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => PlanDeleteChatRequest._();
  @$core.override
  PlanDeleteChatRequest createEmptyInstance() => PlanDeleteChatRequest._();
  @$core.pragma('dart2js:noInline')
  static PlanDeleteChatRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanDeleteChatRequest>(
          PlanDeleteChatRequest.$_createMessage);
  static PlanDeleteChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class PlanDeleteChatResponse extends $pb.GeneratedMessage {
  factory PlanDeleteChatResponse({
    $core.Iterable<AgentSession>? sessions,
    $core.bool? deletesHistory,
    $core.String? scratchFolder,
    Worktree? worktree,
    WorktreeState? worktreeState,
    $core.Iterable<WorktreePlan>? worktrees,
  }) {
    final result = PlanDeleteChatResponse._();
    if (sessions != null) result.sessions.addAll(sessions);
    if (deletesHistory != null) result.deletesHistory = deletesHistory;
    if (scratchFolder != null) result.scratchFolder = scratchFolder;
    if (worktree != null) result.worktree = worktree;
    if (worktreeState != null) result.worktreeState = worktreeState;
    if (worktrees != null) result.worktrees.addAll(worktrees);
    return result;
  }

  PlanDeleteChatResponse._();

  factory PlanDeleteChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanDeleteChatResponse()..mergeFromBuffer(data, registry);
  factory PlanDeleteChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanDeleteChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanDeleteChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: PlanDeleteChatResponse.$_createMessage)
    ..pPM<AgentSession>(1, _omitFieldNames ? '' : 'sessions',
        subBuilder: AgentSession.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'deletesHistory')
    ..aOS(3, _omitFieldNames ? '' : 'scratchFolder')
    ..aOM<Worktree>(4, _omitFieldNames ? '' : 'worktree',
        subBuilder: Worktree.$_createMessage)
    ..aOM<WorktreeState>(5, _omitFieldNames ? '' : 'worktreeState',
        subBuilder: WorktreeState.$_createMessage)
    ..pPM<WorktreePlan>(6, _omitFieldNames ? '' : 'worktrees',
        subBuilder: WorktreePlan.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanDeleteChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanDeleteChatResponse copyWith(
          void Function(PlanDeleteChatResponse) updates) =>
      super.copyWith((message) => updates(message as PlanDeleteChatResponse))
          as PlanDeleteChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use PlanDeleteChatResponse() / PlanDeleteChatResponse.new instead')
  static PlanDeleteChatResponse create() => PlanDeleteChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => PlanDeleteChatResponse._();
  @$core.override
  PlanDeleteChatResponse createEmptyInstance() => PlanDeleteChatResponse._();
  @$core.pragma('dart2js:noInline')
  static PlanDeleteChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanDeleteChatResponse>(
          PlanDeleteChatResponse.$_createMessage);
  static PlanDeleteChatResponse? _defaultInstance;

  /// The agent's sessions the chat had, oldest first (more than one once it
  /// has moved).
  @$pb.TagNumber(1)
  $pb.PbList<AgentSession> get sessions => $_getList(0);

  /// Whether the agent deletes its history of them; if not, it stays.
  @$pb.TagNumber(2)
  $core.bool get deletesHistory => $_getBF(1);
  @$pb.TagNumber(2)
  set deletesHistory($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeletesHistory() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeletesHistory() => $_clearField(2);

  /// The chat's scratch folder, if it still has one.
  @$pb.TagNumber(3)
  $core.String get scratchFolder => $_getSZ(2);
  @$pb.TagNumber(3)
  set scratchFolder($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasScratchFolder() => $_has(2);
  @$pb.TagNumber(3)
  void clearScratchFolder() => $_clearField(3);

  /// The chat's worktree, if it has one, and what removing it and deleting
  /// its branch would lose (API 22).
  @$pb.TagNumber(4)
  Worktree get worktree => $_getN(3);
  @$pb.TagNumber(4)
  set worktree(Worktree value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasWorktree() => $_has(3);
  @$pb.TagNumber(4)
  void clearWorktree() => $_clearField(4);
  @$pb.TagNumber(4)
  Worktree ensureWorktree() => $_ensure(3);

  @$pb.TagNumber(5)
  WorktreeState get worktreeState => $_getN(4);
  @$pb.TagNumber(5)
  set worktreeState(WorktreeState value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasWorktreeState() => $_has(4);
  @$pb.TagNumber(5)
  void clearWorktreeState() => $_clearField(5);
  @$pb.TagNumber(5)
  WorktreeState ensureWorktreeState() => $_ensure(4);

  /// All of the chat's worktrees, each with what removing it and deleting
  /// its branch would lose: its own, then those it moved out of, which stay
  /// on disk until it is deleted (API 23).
  @$pb.TagNumber(6)
  $pb.PbList<WorktreePlan> get worktrees => $_getList(5);
}

class WorktreePlan extends $pb.GeneratedMessage {
  factory WorktreePlan({
    Worktree? worktree,
    WorktreeState? state,
  }) {
    final result = WorktreePlan._();
    if (worktree != null) result.worktree = worktree;
    if (state != null) result.state = state;
    return result;
  }

  WorktreePlan._();

  factory WorktreePlan.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreePlan()..mergeFromBuffer(data, registry);
  factory WorktreePlan.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreePlan()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorktreePlan',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: WorktreePlan.$_createMessage)
    ..aOM<Worktree>(1, _omitFieldNames ? '' : 'worktree',
        subBuilder: Worktree.$_createMessage)
    ..aOM<WorktreeState>(2, _omitFieldNames ? '' : 'state',
        subBuilder: WorktreeState.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreePlan clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreePlan copyWith(void Function(WorktreePlan) updates) =>
      super.copyWith((message) => updates(message as WorktreePlan))
          as WorktreePlan;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorktreePlan() / WorktreePlan.new instead')
  static WorktreePlan create() => WorktreePlan._();
  static $pb.GeneratedMessage $_createMessage() => WorktreePlan._();
  @$core.override
  WorktreePlan createEmptyInstance() => WorktreePlan._();
  @$core.pragma('dart2js:noInline')
  static WorktreePlan getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorktreePlan>(
          WorktreePlan.$_createMessage);
  static WorktreePlan? _defaultInstance;

  @$pb.TagNumber(1)
  Worktree get worktree => $_getN(0);
  @$pb.TagNumber(1)
  set worktree(Worktree value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasWorktree() => $_has(0);
  @$pb.TagNumber(1)
  void clearWorktree() => $_clearField(1);
  @$pb.TagNumber(1)
  Worktree ensureWorktree() => $_ensure(0);

  @$pb.TagNumber(2)
  WorktreeState get state => $_getN(1);
  @$pb.TagNumber(2)
  set state(WorktreeState value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);
  @$pb.TagNumber(2)
  WorktreeState ensureState() => $_ensure(1);
}

/// What removing a worktree and deleting its branch would lose.
class WorktreeState extends $pb.GeneratedMessage {
  factory WorktreeState({
    $core.bool? gone,
    $core.int? changed,
    $core.int? commits,
    $core.bool? branchGone,
    $core.String? error,
  }) {
    final result = WorktreeState._();
    if (gone != null) result.gone = gone;
    if (changed != null) result.changed = changed;
    if (commits != null) result.commits = commits;
    if (branchGone != null) result.branchGone = branchGone;
    if (error != null) result.error = error;
    return result;
  }

  WorktreeState._();

  factory WorktreeState.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeState()..mergeFromBuffer(data, registry);
  factory WorktreeState.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeState()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorktreeState',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: WorktreeState.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'gone')
    ..aI(2, _omitFieldNames ? '' : 'changed')
    ..aI(3, _omitFieldNames ? '' : 'commits')
    ..aOB(4, _omitFieldNames ? '' : 'branchGone')
    ..aOS(5, _omitFieldNames ? '' : 'error')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeState clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeState copyWith(void Function(WorktreeState) updates) =>
      super.copyWith((message) => updates(message as WorktreeState))
          as WorktreeState;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorktreeState() / WorktreeState.new instead')
  static WorktreeState create() => WorktreeState._();
  static $pb.GeneratedMessage $_createMessage() => WorktreeState._();
  @$core.override
  WorktreeState createEmptyInstance() => WorktreeState._();
  @$core.pragma('dart2js:noInline')
  static WorktreeState getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorktreeState>(
          WorktreeState.$_createMessage);
  static WorktreeState? _defaultInstance;

  /// Its folder was removed outside Nushi.
  @$pb.TagNumber(1)
  $core.bool get gone => $_getBF(0);
  @$pb.TagNumber(1)
  set gone($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGone() => $_has(0);
  @$pb.TagNumber(1)
  void clearGone() => $_clearField(1);

  /// Files with uncommitted changes, untracked ones included.
  @$pb.TagNumber(2)
  $core.int get changed => $_getIZ(1);
  @$pb.TagNumber(2)
  set changed($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChanged() => $_has(1);
  @$pb.TagNumber(2)
  void clearChanged() => $_clearField(2);

  /// Commits on its branch that its base doesn't have.
  @$pb.TagNumber(3)
  $core.int get commits => $_getIZ(2);
  @$pb.TagNumber(3)
  set commits($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommits() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommits() => $_clearField(3);

  /// Its branch was deleted outside Nushi.
  @$pb.TagNumber(4)
  $core.bool get branchGone => $_getBF(3);
  @$pb.TagNumber(4)
  set branchGone($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBranchGone() => $_has(3);
  @$pb.TagNumber(4)
  void clearBranchGone() => $_clearField(4);

  /// Why the rest can't be told, if it can't.
  @$pb.TagNumber(5)
  $core.String get error => $_getSZ(4);
  @$pb.TagNumber(5)
  set error($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasError() => $_has(4);
  @$pb.TagNumber(5)
  void clearError() => $_clearField(5);
}

/// One of the agent's sessions: its id and folder.
class AgentSession extends $pb.GeneratedMessage {
  factory AgentSession({
    $core.String? sessionId,
    $core.String? folder,
  }) {
    final result = AgentSession._();
    if (sessionId != null) result.sessionId = sessionId;
    if (folder != null) result.folder = folder;
    return result;
  }

  AgentSession._();

  factory AgentSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentSession()..mergeFromBuffer(data, registry);
  factory AgentSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AgentSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AgentSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AgentSession.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'folder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AgentSession copyWith(void Function(AgentSession) updates) =>
      super.copyWith((message) => updates(message as AgentSession))
          as AgentSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AgentSession() / AgentSession.new instead')
  static AgentSession create() => AgentSession._();
  static $pb.GeneratedMessage $_createMessage() => AgentSession._();
  @$core.override
  AgentSession createEmptyInstance() => AgentSession._();
  @$core.pragma('dart2js:noInline')
  static AgentSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<AgentSession>(
          AgentSession.$_createMessage);
  static AgentSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get folder => $_getSZ(1);
  @$pb.TagNumber(2)
  set folder($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFolder() => $_has(1);
  @$pb.TagNumber(2)
  void clearFolder() => $_clearField(2);
}

class DeleteChatRequest extends $pb.GeneratedMessage {
  factory DeleteChatRequest({
    $core.String? chatId,
    $core.bool? removeWorktree,
    $core.bool? forceWorktree,
    $core.bool? deleteBranch,
    $core.bool? forceBranch,
    $core.Iterable<WorktreeChoice>? worktrees,
  }) {
    final result = DeleteChatRequest._();
    if (chatId != null) result.chatId = chatId;
    if (removeWorktree != null) result.removeWorktree = removeWorktree;
    if (forceWorktree != null) result.forceWorktree = forceWorktree;
    if (deleteBranch != null) result.deleteBranch = deleteBranch;
    if (forceBranch != null) result.forceBranch = forceBranch;
    if (worktrees != null) result.worktrees.addAll(worktrees);
    return result;
  }

  DeleteChatRequest._();

  factory DeleteChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteChatRequest()..mergeFromBuffer(data, registry);
  factory DeleteChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: DeleteChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOB(2, _omitFieldNames ? '' : 'removeWorktree')
    ..aOB(3, _omitFieldNames ? '' : 'forceWorktree')
    ..aOB(4, _omitFieldNames ? '' : 'deleteBranch')
    ..aOB(5, _omitFieldNames ? '' : 'forceBranch')
    ..pPM<WorktreeChoice>(6, _omitFieldNames ? '' : 'worktrees',
        subBuilder: WorktreeChoice.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteChatRequest copyWith(void Function(DeleteChatRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteChatRequest))
          as DeleteChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeleteChatRequest() / DeleteChatRequest.new instead')
  static DeleteChatRequest create() => DeleteChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => DeleteChatRequest._();
  @$core.override
  DeleteChatRequest createEmptyInstance() => DeleteChatRequest._();
  @$core.pragma('dart2js:noInline')
  static DeleteChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeleteChatRequest>(
          DeleteChatRequest.$_createMessage);
  static DeleteChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  /// Remove the chat's worktree (git worktree remove). One with changes is
  /// removed only with force_worktree (API 22).
  @$pb.TagNumber(2)
  $core.bool get removeWorktree => $_getBF(1);
  @$pb.TagNumber(2)
  set removeWorktree($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRemoveWorktree() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemoveWorktree() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get forceWorktree => $_getBF(2);
  @$pb.TagNumber(3)
  set forceWorktree($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasForceWorktree() => $_has(2);
  @$pb.TagNumber(3)
  void clearForceWorktree() => $_clearField(3);

  /// Delete the worktree's branch (with the worktree). One with commits its
  /// base doesn't have is deleted only with force_branch.
  @$pb.TagNumber(4)
  $core.bool get deleteBranch => $_getBF(3);
  @$pb.TagNumber(4)
  set deleteBranch($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeleteBranch() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeleteBranch() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get forceBranch => $_getBF(4);
  @$pb.TagNumber(5)
  set forceBranch($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasForceBranch() => $_has(4);
  @$pb.TagNumber(5)
  void clearForceBranch() => $_clearField(5);

  /// What to do with each of the chat's worktrees, by path; when set, the
  /// fields above don't apply (API 23).
  @$pb.TagNumber(6)
  $pb.PbList<WorktreeChoice> get worktrees => $_getList(5);
}

/// What to do with a worktree and its branch, as for DeleteChatRequest's own
/// fields.
class WorktreeChoice extends $pb.GeneratedMessage {
  factory WorktreeChoice({
    $core.String? path,
    $core.bool? removeWorktree,
    $core.bool? forceWorktree,
    $core.bool? deleteBranch,
    $core.bool? forceBranch,
  }) {
    final result = WorktreeChoice._();
    if (path != null) result.path = path;
    if (removeWorktree != null) result.removeWorktree = removeWorktree;
    if (forceWorktree != null) result.forceWorktree = forceWorktree;
    if (deleteBranch != null) result.deleteBranch = deleteBranch;
    if (forceBranch != null) result.forceBranch = forceBranch;
    return result;
  }

  WorktreeChoice._();

  factory WorktreeChoice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeChoice()..mergeFromBuffer(data, registry);
  factory WorktreeChoice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WorktreeChoice()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WorktreeChoice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: WorktreeChoice.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOB(2, _omitFieldNames ? '' : 'removeWorktree')
    ..aOB(3, _omitFieldNames ? '' : 'forceWorktree')
    ..aOB(4, _omitFieldNames ? '' : 'deleteBranch')
    ..aOB(5, _omitFieldNames ? '' : 'forceBranch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeChoice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WorktreeChoice copyWith(void Function(WorktreeChoice) updates) =>
      super.copyWith((message) => updates(message as WorktreeChoice))
          as WorktreeChoice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use WorktreeChoice() / WorktreeChoice.new instead')
  static WorktreeChoice create() => WorktreeChoice._();
  static $pb.GeneratedMessage $_createMessage() => WorktreeChoice._();
  @$core.override
  WorktreeChoice createEmptyInstance() => WorktreeChoice._();
  @$core.pragma('dart2js:noInline')
  static WorktreeChoice getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<WorktreeChoice>(
          WorktreeChoice.$_createMessage);
  static WorktreeChoice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get removeWorktree => $_getBF(1);
  @$pb.TagNumber(2)
  set removeWorktree($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRemoveWorktree() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemoveWorktree() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get forceWorktree => $_getBF(2);
  @$pb.TagNumber(3)
  set forceWorktree($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasForceWorktree() => $_has(2);
  @$pb.TagNumber(3)
  void clearForceWorktree() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get deleteBranch => $_getBF(3);
  @$pb.TagNumber(4)
  set deleteBranch($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeleteBranch() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeleteBranch() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get forceBranch => $_getBF(4);
  @$pb.TagNumber(5)
  set forceBranch($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasForceBranch() => $_has(4);
  @$pb.TagNumber(5)
  void clearForceBranch() => $_clearField(5);
}

class DeleteChatResponse extends $pb.GeneratedMessage {
  factory DeleteChatResponse() => DeleteChatResponse._();

  DeleteChatResponse._();

  factory DeleteChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteChatResponse()..mergeFromBuffer(data, registry);
  factory DeleteChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DeleteChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: DeleteChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteChatResponse copyWith(void Function(DeleteChatResponse) updates) =>
      super.copyWith((message) => updates(message as DeleteChatResponse))
          as DeleteChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use DeleteChatResponse() / DeleteChatResponse.new instead')
  static DeleteChatResponse create() => DeleteChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => DeleteChatResponse._();
  @$core.override
  DeleteChatResponse createEmptyInstance() => DeleteChatResponse._();
  @$core.pragma('dart2js:noInline')
  static DeleteChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteChatResponse>(
          DeleteChatResponse.$_createMessage);
  static DeleteChatResponse? _defaultInstance;
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

class GetFolderStatusRequest extends $pb.GeneratedMessage {
  factory GetFolderStatusRequest({
    $core.String? folder,
    $core.String? base,
  }) {
    final result = GetFolderStatusRequest._();
    if (folder != null) result.folder = folder;
    if (base != null) result.base = base;
    return result;
  }

  GetFolderStatusRequest._();

  factory GetFolderStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFolderStatusRequest()..mergeFromBuffer(data, registry);
  factory GetFolderStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFolderStatusRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetFolderStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetFolderStatusRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'base')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFolderStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFolderStatusRequest copyWith(
          void Function(GetFolderStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetFolderStatusRequest))
          as GetFolderStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetFolderStatusRequest() / GetFolderStatusRequest.new instead')
  static GetFolderStatusRequest create() => GetFolderStatusRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetFolderStatusRequest._();
  @$core.override
  GetFolderStatusRequest createEmptyInstance() => GetFolderStatusRequest._();
  @$core.pragma('dart2js:noInline')
  static GetFolderStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetFolderStatusRequest>(
          GetFolderStatusRequest.$_createMessage);
  static GetFolderStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// As GetDiffRequest.base (API 21).
  @$pb.TagNumber(2)
  $core.String get base => $_getSZ(1);
  @$pb.TagNumber(2)
  set base($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBase() => $_has(1);
  @$pb.TagNumber(2)
  void clearBase() => $_clearField(2);
}

class GetFolderStatusResponse extends $pb.GeneratedMessage {
  factory GetFolderStatusResponse({
    $core.bool? git,
    $core.String? branch,
    $core.int? files,
    $core.int? added,
    $core.int? removed,
    $core.bool? gone,
  }) {
    final result = GetFolderStatusResponse._();
    if (git != null) result.git = git;
    if (branch != null) result.branch = branch;
    if (files != null) result.files = files;
    if (added != null) result.added = added;
    if (removed != null) result.removed = removed;
    if (gone != null) result.gone = gone;
    return result;
  }

  GetFolderStatusResponse._();

  factory GetFolderStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFolderStatusResponse()..mergeFromBuffer(data, registry);
  factory GetFolderStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFolderStatusResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetFolderStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetFolderStatusResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'git')
    ..aOS(2, _omitFieldNames ? '' : 'branch')
    ..aI(3, _omitFieldNames ? '' : 'files')
    ..aI(4, _omitFieldNames ? '' : 'added')
    ..aI(5, _omitFieldNames ? '' : 'removed')
    ..aOB(6, _omitFieldNames ? '' : 'gone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFolderStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFolderStatusResponse copyWith(
          void Function(GetFolderStatusResponse) updates) =>
      super.copyWith((message) => updates(message as GetFolderStatusResponse))
          as GetFolderStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetFolderStatusResponse() / GetFolderStatusResponse.new instead')
  static GetFolderStatusResponse create() => GetFolderStatusResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetFolderStatusResponse._();
  @$core.override
  GetFolderStatusResponse createEmptyInstance() => GetFolderStatusResponse._();
  @$core.pragma('dart2js:noInline')
  static GetFolderStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetFolderStatusResponse>(
          GetFolderStatusResponse.$_createMessage);
  static GetFolderStatusResponse? _defaultInstance;

  /// Whether the folder is in a git repository; nothing else is set if not.
  @$pb.TagNumber(1)
  $core.bool get git => $_getBF(0);
  @$pb.TagNumber(1)
  set git($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasGit() => $_has(0);
  @$pb.TagNumber(1)
  void clearGit() => $_clearField(1);

  /// The branch checked out, or the commit when none is.
  @$pb.TagNumber(2)
  $core.String get branch => $_getSZ(1);
  @$pb.TagNumber(2)
  set branch($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBranch() => $_has(1);
  @$pb.TagNumber(2)
  void clearBranch() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get files => $_getIZ(2);
  @$pb.TagNumber(3)
  set files($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFiles() => $_has(2);
  @$pb.TagNumber(3)
  void clearFiles() => $_clearField(3);

  /// Lines added and removed; binary files count none.
  @$pb.TagNumber(4)
  $core.int get added => $_getIZ(3);
  @$pb.TagNumber(4)
  set added($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAdded() => $_has(3);
  @$pb.TagNumber(4)
  void clearAdded() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get removed => $_getIZ(4);
  @$pb.TagNumber(5)
  set removed($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRemoved() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemoved() => $_clearField(5);

  /// The folder doesn't exist (any more); nothing else is set (API 22).
  @$pb.TagNumber(6)
  $core.bool get gone => $_getBF(5);
  @$pb.TagNumber(6)
  set gone($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGone() => $_has(5);
  @$pb.TagNumber(6)
  void clearGone() => $_clearField(6);
}

class GetDiffRequest extends $pb.GeneratedMessage {
  factory GetDiffRequest({
    $core.String? folder,
    $core.String? base,
  }) {
    final result = GetDiffRequest._();
    if (folder != null) result.folder = folder;
    if (base != null) result.base = base;
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
    ..aOS(2, _omitFieldNames ? '' : 'base')
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

  /// A branch: count the changes from where HEAD's branch left it (git
  /// merge-base HEAD base), the branch's commits and uncommitted changes
  /// together, instead of from HEAD (API 21).
  @$pb.TagNumber(2)
  $core.String get base => $_getSZ(1);
  @$pb.TagNumber(2)
  set base($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBase() => $_has(1);
  @$pb.TagNumber(2)
  void clearBase() => $_clearField(2);
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

enum EventsResponse_Kind {
  item,
  status,
  config,
  chat,
  commands,
  removed,
  usage,
  notSet
}

class EventsResponse extends $pb.GeneratedMessage {
  factory EventsResponse({
    $core.String? chatId,
    ItemEvent? item,
    ChatStatus? status,
    ChatConfig? config,
    Chat? chat,
    $fixnum.Int64? seq,
    ChatCommands? commands,
    $core.bool? removed,
    Usage? usage,
  }) {
    final result = EventsResponse._();
    if (chatId != null) result.chatId = chatId;
    if (item != null) result.item = item;
    if (status != null) result.status = status;
    if (config != null) result.config = config;
    if (chat != null) result.chat = chat;
    if (seq != null) result.seq = seq;
    if (commands != null) result.commands = commands;
    if (removed != null) result.removed = removed;
    if (usage != null) result.usage = usage;
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
    7: EventsResponse_Kind.commands,
    8: EventsResponse_Kind.removed,
    9: EventsResponse_Kind.usage,
    0: EventsResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EventsResponse.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 7, 8, 9])
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
    ..aOM<ChatCommands>(7, _omitFieldNames ? '' : 'commands',
        subBuilder: ChatCommands.$_createMessage)
    ..aOB(8, _omitFieldNames ? '' : 'removed')
    ..aOM<Usage>(9, _omitFieldNames ? '' : 'usage',
        subBuilder: Usage.$_createMessage)
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
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  EventsResponse_Kind whichKind() =>
      _EventsResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
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

  /// The chat was opened, or its title, mode or archived state changed.
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

  /// The agent's slash commands, all of them.
  @$pb.TagNumber(7)
  ChatCommands get commands => $_getN(6);
  @$pb.TagNumber(7)
  set commands(ChatCommands value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCommands() => $_has(6);
  @$pb.TagNumber(7)
  void clearCommands() => $_clearField(7);
  @$pb.TagNumber(7)
  ChatCommands ensureCommands() => $_ensure(6);

  /// The chat was removed (RemoveChat).
  @$pb.TagNumber(8)
  $core.bool get removed => $_getBF(7);
  @$pb.TagNumber(8)
  set removed($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRemoved() => $_has(7);
  @$pb.TagNumber(8)
  void clearRemoved() => $_clearField(8);

  /// The chat's usage, all of it.
  @$pb.TagNumber(9)
  Usage get usage => $_getN(8);
  @$pb.TagNumber(9)
  set usage(Usage value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasUsage() => $_has(8);
  @$pb.TagNumber(9)
  void clearUsage() => $_clearField(9);
  @$pb.TagNumber(9)
  Usage ensureUsage() => $_ensure(8);
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
    $core.Iterable<PlanEntry>? plan,
    $core.Iterable<ImageData>? images,
    $core.String? parent,
    $core.String? agent,
    $core.String? tool,
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
    if (plan != null) result.plan.addAll(plan);
    if (images != null) result.images.addAll(images);
    if (parent != null) result.parent = parent;
    if (agent != null) result.agent = agent;
    if (tool != null) result.tool = tool;
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
    ..pPM<PlanEntry>(12, _omitFieldNames ? '' : 'plan',
        subBuilder: PlanEntry.$_createMessage)
    ..pPM<ImageData>(13, _omitFieldNames ? '' : 'images',
        subBuilder: ImageData.$_createMessage)
    ..aOS(14, _omitFieldNames ? '' : 'parent')
    ..aOS(15, _omitFieldNames ? '' : 'agent')
    ..aOS(16, _omitFieldNames ? '' : 'tool')
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

  @$pb.TagNumber(12)
  $pb.PbList<PlanEntry> get plan => $_getList(11);

  /// A message's or a tool call's images.
  @$pb.TagNumber(13)
  $pb.PbList<ImageData> get images => $_getList(12);

  /// The tool call whose subagent made this item, if one did (API 24).
  @$pb.TagNumber(14)
  $core.String get parent => $_getSZ(13);
  @$pb.TagNumber(14)
  set parent($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasParent() => $_has(13);
  @$pb.TagNumber(14)
  void clearParent() => $_clearField(14);

  /// For a tool call that starts a subagent, the subagent's type ("Explore").
  @$pb.TagNumber(15)
  $core.String get agent => $_getSZ(14);
  @$pb.TagNumber(15)
  set agent($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasAgent() => $_has(14);
  @$pb.TagNumber(15)
  void clearAgent() => $_clearField(15);

  /// A tool call's tool, when the agent names it (Claude's "Read",
  /// "SubagentHandback", ...).
  @$pb.TagNumber(16)
  $core.String get tool => $_getSZ(15);
  @$pb.TagNumber(16)
  set tool($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasTool() => $_has(15);
  @$pb.TagNumber(16)
  void clearTool() => $_clearField(16);
}

/// A step of the agent's plan; status is "pending", "in_progress" or
/// "completed".
class PlanEntry extends $pb.GeneratedMessage {
  factory PlanEntry({
    $core.String? content,
    $core.String? status,
  }) {
    final result = PlanEntry._();
    if (content != null) result.content = content;
    if (status != null) result.status = status;
    return result;
  }

  PlanEntry._();

  factory PlanEntry.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanEntry()..mergeFromBuffer(data, registry);
  factory PlanEntry.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      PlanEntry()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanEntry',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: PlanEntry.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'content')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanEntry clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanEntry copyWith(void Function(PlanEntry) updates) =>
      super.copyWith((message) => updates(message as PlanEntry)) as PlanEntry;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use PlanEntry() / PlanEntry.new instead')
  static PlanEntry create() => PlanEntry._();
  static $pb.GeneratedMessage $_createMessage() => PlanEntry._();
  @$core.override
  PlanEntry createEmptyInstance() => PlanEntry._();
  @$core.pragma('dart2js:noInline')
  static PlanEntry getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PlanEntry>(PlanEntry.$_createMessage);
  static PlanEntry? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get content => $_getSZ(0);
  @$pb.TagNumber(1)
  set content($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasContent() => $_has(0);
  @$pb.TagNumber(1)
  void clearContent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);
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
    $fixnum.Int64? started,
    $core.bool? waiting,
    $core.bool? canFork,
    $core.bool? images,
  }) {
    final result = ChatStatus._();
    if (busy != null) result.busy = busy;
    if (error != null) result.error = error;
    if (started != null) result.started = started;
    if (waiting != null) result.waiting = waiting;
    if (canFork != null) result.canFork = canFork;
    if (images != null) result.images = images;
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
    ..aInt64(3, _omitFieldNames ? '' : 'started')
    ..aOB(4, _omitFieldNames ? '' : 'waiting')
    ..aOB(5, _omitFieldNames ? '' : 'canFork')
    ..aOB(6, _omitFieldNames ? '' : 'images')
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

  /// Not set since API version 11: a failed turn ends with a notice item.
  @$pb.TagNumber(2)
  $core.String get error => $_getSZ(1);
  @$pb.TagNumber(2)
  set error($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasError() => $_has(1);
  @$pb.TagNumber(2)
  void clearError() => $_clearField(2);

  /// When the running turn started, in Unix milliseconds; 0 when idle.
  @$pb.TagNumber(3)
  $fixnum.Int64 get started => $_getI64(2);
  @$pb.TagNumber(3)
  set started($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStarted() => $_has(2);
  @$pb.TagNumber(3)
  void clearStarted() => $_clearField(3);

  /// The agent waits on the user: a permission prompt or a question.
  @$pb.TagNumber(4)
  $core.bool get waiting => $_getBF(3);
  @$pb.TagNumber(4)
  set waiting($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasWaiting() => $_has(3);
  @$pb.TagNumber(4)
  void clearWaiting() => $_clearField(4);

  /// The agent can fork the chat (ForkChat).
  @$pb.TagNumber(5)
  $core.bool get canFork => $_getBF(4);
  @$pb.TagNumber(5)
  set canFork($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCanFork() => $_has(4);
  @$pb.TagNumber(5)
  void clearCanFork() => $_clearField(5);

  /// The agent takes images in prompts.
  @$pb.TagNumber(6)
  $core.bool get images => $_getBF(5);
  @$pb.TagNumber(6)
  set images($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasImages() => $_has(5);
  @$pb.TagNumber(6)
  void clearImages() => $_clearField(6);
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

  /// Moves a chat to another folder, or to a new worktree. A chat without
  /// messages starts a new session there (and a worktree it leaves is
  /// removed if it holds no work); one with messages keeps its history, in a
  /// fork of its session there. Refused while the chat is busy. If the move
  /// fails the chat stays where it was, with a notice saying why.
  $async.Future<MoveChatResponse> moveChat(
          $pb.ClientContext? ctx, MoveChatRequest request) =>
      _client.invoke<MoveChatResponse>(
          ctx, 'NushiService', 'MoveChat', request, MoveChatResponse());

  /// Sends a prompt; the reply arrives as events.
  $async.Future<SendPromptResponse> sendPrompt(
          $pb.ClientContext? ctx, SendPromptRequest request) =>
      _client.invoke<SendPromptResponse>(
          ctx, 'NushiService', 'SendPrompt', request, SendPromptResponse());

  /// Stops the chat's running turn (ACP session/cancel). The turn ends with a
  /// "cancelled" notice, and prompts it was waiting on are cancelled.
  $async.Future<CancelTurnResponse> cancelTurn(
          $pb.ClientContext? ctx, CancelTurnRequest request) =>
      _client.invoke<CancelTurnResponse>(
          ctx, 'NushiService', 'CancelTurn', request, CancelTurnResponse());

  /// Opens a side chat: a session the agent forks from the chat's (ACP
  /// session/fork, when status.can_fork). It knows the conversation so far
  /// but doesn't add to it, isn't listed or stored, and ends with
  /// CloseSideChat. Its items and status come as events like any chat's.
  $async.Future<ForkChatResponse> forkChat(
          $pb.ClientContext? ctx, ForkChatRequest request) =>
      _client.invoke<ForkChatResponse>(
          ctx, 'NushiService', 'ForkChat', request, ForkChatResponse());
  $async.Future<CloseSideChatResponse> closeSideChat(
          $pb.ClientContext? ctx, CloseSideChatRequest request) =>
      _client.invoke<CloseSideChatResponse>(ctx, 'NushiService',
          'CloseSideChat', request, CloseSideChatResponse());

  /// Sets the chat's title; it wins over the agent's. An empty title goes
  /// back to the agent's.
  $async.Future<RenameChatResponse> renameChat(
          $pb.ClientContext? ctx, RenameChatRequest request) =>
      _client.invoke<RenameChatResponse>(
          ctx, 'NushiService', 'RenameChat', request, RenameChatResponse());

  /// Archives a chat: its turn is cancelled and its agent stops; it stays
  /// listed, read-only. Unarchiving reopens it (ACP session/load).
  $async.Future<ArchiveChatResponse> archiveChat(
          $pb.ClientContext? ctx, ArchiveChatRequest request) =>
      _client.invoke<ArchiveChatResponse>(
          ctx, 'NushiService', 'ArchiveChat', request, ArchiveChatResponse());

  /// Forgets a chat: its turn is cancelled, its agent stops, and Nushi's
  /// record of it goes. The agent's own history of the session stays.
  $async.Future<RemoveChatResponse> removeChat(
          $pb.ClientContext? ctx, RemoveChatRequest request) =>
      _client.invoke<RemoveChatResponse>(
          ctx, 'NushiService', 'RemoveChat', request, RemoveChatResponse());

  /// Says what DeleteChat removes. The first time, the daemon starts the
  /// agent to learn whether it can delete its history.
  $async.Future<PlanDeleteChatResponse> planDeleteChat(
          $pb.ClientContext? ctx, PlanDeleteChatRequest request) =>
      _client.invoke<PlanDeleteChatResponse>(ctx, 'NushiService',
          'PlanDeleteChat', request, PlanDeleteChatResponse());

  /// Deletes a chat: its turn is cancelled and its agent stops, its worktree
  /// and branch go if asked, the agent deletes its history of each of the
  /// chat's sessions (ACP session/delete, when it can), the chat's scratch
  /// folder goes, and Nushi's record of it.
  $async.Future<DeleteChatResponse> deleteChat(
          $pb.ClientContext? ctx, DeleteChatRequest request) =>
      _client.invoke<DeleteChatResponse>(
          ctx, 'NushiService', 'DeleteChat', request, DeleteChatResponse());

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
  /// included, or everything since its branch left a base.
  $async.Future<GetDiffResponse> getDiff(
          $pb.ClientContext? ctx, GetDiffRequest request) =>
      _client.invoke<GetDiffResponse>(
          ctx, 'NushiService', 'GetDiff', request, GetDiffResponse());

  /// Sums up a folder's changes (as GetDiff lists them) and names its
  /// branch.
  $async.Future<GetFolderStatusResponse> getFolderStatus(
          $pb.ClientContext? ctx, GetFolderStatusRequest request) =>
      _client.invoke<GetFolderStatusResponse>(ctx, 'NushiService',
          'GetFolderStatus', request, GetFolderStatusResponse());

  /// Lists a folder's files (up to 20,000) for @-mentions: in a git
  /// repository the ones git doesn't ignore.
  $async.Future<ListFilesResponse> listFiles(
          $pb.ClientContext? ctx, ListFilesRequest request) =>
      _client.invoke<ListFilesResponse>(
          ctx, 'NushiService', 'ListFiles', request, ListFilesResponse());

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
