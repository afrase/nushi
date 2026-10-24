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
    $core.String? build,
  }) {
    final result = PingResponse._();
    if (apiVersion != null) result.apiVersion = apiVersion;
    if (build != null) result.build = build;
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
    ..aOS(2, _omitFieldNames ? '' : 'build')
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

  /// Bumped when the API grows; it only grows (ADR 0004).
  @$pb.TagNumber(1)
  $core.int get apiVersion => $_getIZ(0);
  @$pb.TagNumber(1)
  set apiVersion($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasApiVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearApiVersion() => $_clearField(1);

  /// The daemon's executable as it started, "<size>-<mtime in ms>": the app
  /// compares it with the daemon it bundles, to offer a restart into a
  /// newer one.
  @$pb.TagNumber(2)
  $core.String get build => $_getSZ(1);
  @$pb.TagNumber(2)
  set build($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBuild() => $_has(1);
  @$pb.TagNumber(2)
  void clearBuild() => $_clearField(2);
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
    $core.bool? scratch,
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
    if (scratch != null) result.scratch = scratch;
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
    ..aOB(11, _omitFieldNames ? '' : 'scratch')
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

  /// The agent's session id (claude --resume <id>).
  @$pb.TagNumber(9)
  $core.String get sessionId => $_getSZ(8);
  @$pb.TagNumber(9)
  set sessionId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSessionId() => $_has(8);
  @$pb.TagNumber(9)
  void clearSessionId() => $_clearField(9);

  /// The git worktree Nushi made for the chat, if it runs in one.
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

  /// Its folder is a scratch folder of its own: it has no folder yet.
  @$pb.TagNumber(11)
  $core.bool get scratch => $_getBF(10);
  @$pb.TagNumber(11)
  set scratch($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasScratch() => $_has(10);
  @$pb.TagNumber(11)
  void clearScratch() => $_clearField(11);
}

/// A git worktree of a repository, on a branch of its own.
class Worktree extends $pb.GeneratedMessage {
  factory Worktree({
    $core.String? repo,
    $core.String? path,
    $core.String? branch,
    $core.String? base,
    $core.String? baseCommit,
  }) {
    final result = Worktree._();
    if (repo != null) result.repo = repo;
    if (path != null) result.path = path;
    if (branch != null) result.branch = branch;
    if (base != null) result.base = base;
    if (baseCommit != null) result.baseCommit = baseCommit;
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
    ..aOS(5, _omitFieldNames ? '' : 'baseCommit')
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

  /// The commit it started from, for when its base branch is gone; empty
  /// for worktrees made before daemon API 42.
  @$pb.TagNumber(5)
  $core.String get baseCommit => $_getSZ(4);
  @$pb.TagNumber(5)
  set baseCommit($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBaseCommit() => $_has(4);
  @$pb.TagNumber(5)
  void clearBaseCommit() => $_clearField(5);
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
    ChatQueue? queue,
  }) {
    final result = GetChatResponse._();
    if (chat != null) result.chat = chat;
    if (items != null) result.items.addAll(items);
    if (config != null) result.config.addAll(config);
    if (status != null) result.status = status;
    if (seq != null) result.seq = seq;
    if (commands != null) result.commands.addAll(commands);
    if (usage != null) result.usage = usage;
    if (queue != null) result.queue = queue;
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
    ..aOM<ChatQueue>(8, _omitFieldNames ? '' : 'queue',
        subBuilder: ChatQueue.$_createMessage)
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

  /// Messages waiting for the agent.
  @$pb.TagNumber(8)
  ChatQueue get queue => $_getN(7);
  @$pb.TagNumber(8)
  set queue(ChatQueue value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasQueue() => $_has(7);
  @$pb.TagNumber(8)
  void clearQueue() => $_clearField(8);
  @$pb.TagNumber(8)
  ChatQueue ensureQueue() => $_ensure(7);
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

class ListAgentsRequest extends $pb.GeneratedMessage {
  factory ListAgentsRequest() => ListAgentsRequest._();

  ListAgentsRequest._();

  factory ListAgentsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentsRequest()..mergeFromBuffer(data, registry);
  factory ListAgentsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAgentsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListAgentsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentsRequest copyWith(void Function(ListAgentsRequest) updates) =>
      super.copyWith((message) => updates(message as ListAgentsRequest))
          as ListAgentsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListAgentsRequest() / ListAgentsRequest.new instead')
  static ListAgentsRequest create() => ListAgentsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListAgentsRequest._();
  @$core.override
  ListAgentsRequest createEmptyInstance() => ListAgentsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListAgentsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListAgentsRequest>(
          ListAgentsRequest.$_createMessage);
  static ListAgentsRequest? _defaultInstance;
}

class ListAgentsResponse extends $pb.GeneratedMessage {
  factory ListAgentsResponse({
    $core.Iterable<Agent>? agents,
  }) {
    final result = ListAgentsResponse._();
    if (agents != null) result.agents.addAll(agents);
    return result;
  }

  ListAgentsResponse._();

  factory ListAgentsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentsResponse()..mergeFromBuffer(data, registry);
  factory ListAgentsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAgentsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListAgentsResponse.$_createMessage)
    ..pPM<Agent>(1, _omitFieldNames ? '' : 'agents',
        subBuilder: Agent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentsResponse copyWith(void Function(ListAgentsResponse) updates) =>
      super.copyWith((message) => updates(message as ListAgentsResponse))
          as ListAgentsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListAgentsResponse() / ListAgentsResponse.new instead')
  static ListAgentsResponse create() => ListAgentsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListAgentsResponse._();
  @$core.override
  ListAgentsResponse createEmptyInstance() => ListAgentsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListAgentsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAgentsResponse>(
          ListAgentsResponse.$_createMessage);
  static ListAgentsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Agent> get agents => $_getList(0);
}

/// An agent chats can run.
class Agent extends $pb.GeneratedMessage {
  factory Agent({
    $core.String? name,
    $core.String? title,
    $core.String? resume,
    $core.bool? mcp,
    $core.bool? deleteArchives,
  }) {
    final result = Agent._();
    if (name != null) result.name = name;
    if (title != null) result.title = title;
    if (resume != null) result.resume = resume;
    if (mcp != null) result.mcp = mcp;
    if (deleteArchives != null) result.deleteArchives = deleteArchives;
    return result;
  }

  Agent._();

  factory Agent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Agent()..mergeFromBuffer(data, registry);
  factory Agent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Agent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Agent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Agent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'resume')
    ..aOB(4, _omitFieldNames ? '' : 'mcp')
    ..aOB(5, _omitFieldNames ? '' : 'deleteArchives')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Agent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Agent copyWith(void Function(Agent) updates) =>
      super.copyWith((message) => updates(message as Agent)) as Agent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Agent() / Agent.new instead')
  static Agent create() => Agent._();
  static $pb.GeneratedMessage $_createMessage() => Agent._();
  @$core.override
  Agent createEmptyInstance() => Agent._();
  @$core.pragma('dart2js:noInline')
  static Agent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Agent>(Agent.$_createMessage);
  static Agent? _defaultInstance;

  /// As Chat.agent names it, such as "claude".
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// As people read it, such as "Claude".
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// The terminal command that opens one of its sessions, followed by the
  /// session id, such as "claude --resume".
  @$pb.TagNumber(3)
  $core.String get resume => $_getSZ(2);
  @$pb.TagNumber(3)
  set resume($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResume() => $_has(2);
  @$pb.TagNumber(3)
  void clearResume() => $_clearField(3);

  /// Nushi shows and changes its MCP servers (ListMcpServers).
  @$pb.TagNumber(4)
  $core.bool get mcp => $_getBF(3);
  @$pb.TagNumber(4)
  set mcp($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMcp() => $_has(3);
  @$pb.TagNumber(4)
  void clearMcp() => $_clearField(4);

  /// Deleting a chat archives the agent's history of it rather than
  /// deleting it: the resume command still offers it.
  @$pb.TagNumber(5)
  $core.bool get deleteArchives => $_getBF(4);
  @$pb.TagNumber(5)
  set deleteArchives($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeleteArchives() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeleteArchives() => $_clearField(5);
}

class StartChatRequest extends $pb.GeneratedMessage {
  factory StartChatRequest({
    $core.String? folder,
    $core.bool? worktree,
    $core.String? agent,
  }) {
    final result = StartChatRequest._();
    if (folder != null) result.folder = folder;
    if (worktree != null) result.worktree = worktree;
    if (agent != null) result.agent = agent;
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
    ..aOS(3, _omitFieldNames ? '' : 'agent')
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
  /// HEAD.
  @$pb.TagNumber(2)
  $core.bool get worktree => $_getBF(1);
  @$pb.TagNumber(2)
  set worktree($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWorktree() => $_has(1);
  @$pb.TagNumber(2)
  void clearWorktree() => $_clearField(2);

  /// The agent to run (Agent.name); empty for the default.
  @$pb.TagNumber(3)
  $core.String get agent => $_getSZ(2);
  @$pb.TagNumber(3)
  set agent($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAgent() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgent() => $_clearField(3);
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
    $core.bool? queue,
    $core.bool? now,
    $core.String? toSubagent,
  }) {
    final result = SendPromptRequest._();
    if (chatId != null) result.chatId = chatId;
    if (text != null) result.text = text;
    if (files != null) result.files.addAll(files);
    if (images != null) result.images.addAll(images);
    if (queue != null) result.queue = queue;
    if (now != null) result.now = now;
    if (toSubagent != null) result.toSubagent = toSubagent;
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
    ..aOB(5, _omitFieldNames ? '' : 'queue')
    ..aOB(6, _omitFieldNames ? '' : 'now')
    ..aOS(7, _omitFieldNames ? '' : 'toSubagent')
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

  /// While the chat is busy: wait in its queue for the agent's next chance:
  /// into the running turn when the agent can be steered, else as the next
  /// prompt. Without it a busy chat refuses the prompt.
  @$pb.TagNumber(5)
  $core.bool get queue => $_getBF(4);
  @$pb.TagNumber(5)
  set queue($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQueue() => $_has(4);
  @$pb.TagNumber(5)
  void clearQueue() => $_clearField(5);

  /// While a turn runs: stop it and send at once.
  @$pb.TagNumber(6)
  $core.bool get now => $_getBF(5);
  @$pb.TagNumber(6)
  set now($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNow() => $_has(5);
  @$pb.TagNumber(6)
  void clearNow() => $_clearField(6);

  /// The tool call of a subagent (one with agent_id) the message is for: the
  /// agent is asked to pass it on unchanged.
  @$pb.TagNumber(7)
  $core.String get toSubagent => $_getSZ(6);
  @$pb.TagNumber(7)
  set toSubagent($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasToSubagent() => $_has(6);
  @$pb.TagNumber(7)
  void clearToSubagent() => $_clearField(7);
}

/// A message the user sent, waiting in a chat's queue.
class QueuedMessage extends $pb.GeneratedMessage {
  factory QueuedMessage({
    $core.String? id,
    $core.String? text,
    $core.Iterable<$core.String>? files,
    $core.Iterable<ImageData>? images,
    $core.String? relayTo,
    $core.String? toSubagent,
  }) {
    final result = QueuedMessage._();
    if (id != null) result.id = id;
    if (text != null) result.text = text;
    if (files != null) result.files.addAll(files);
    if (images != null) result.images.addAll(images);
    if (relayTo != null) result.relayTo = relayTo;
    if (toSubagent != null) result.toSubagent = toSubagent;
    return result;
  }

  QueuedMessage._();

  factory QueuedMessage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QueuedMessage()..mergeFromBuffer(data, registry);
  factory QueuedMessage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      QueuedMessage()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QueuedMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: QueuedMessage.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'text')
    ..pPS(3, _omitFieldNames ? '' : 'files')
    ..pPM<ImageData>(4, _omitFieldNames ? '' : 'images',
        subBuilder: ImageData.$_createMessage)
    ..aOS(5, _omitFieldNames ? '' : 'relayTo')
    ..aOS(6, _omitFieldNames ? '' : 'toSubagent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueuedMessage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QueuedMessage copyWith(void Function(QueuedMessage) updates) =>
      super.copyWith((message) => updates(message as QueuedMessage))
          as QueuedMessage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use QueuedMessage() / QueuedMessage.new instead')
  static QueuedMessage create() => QueuedMessage._();
  static $pb.GeneratedMessage $_createMessage() => QueuedMessage._();
  @$core.override
  QueuedMessage createEmptyInstance() => QueuedMessage._();
  @$core.pragma('dart2js:noInline')
  static QueuedMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<QueuedMessage>(
          QueuedMessage.$_createMessage);
  static QueuedMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get text => $_getSZ(1);
  @$pb.TagNumber(2)
  set text($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasText() => $_has(1);
  @$pb.TagNumber(2)
  void clearText() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get files => $_getList(2);

  @$pb.TagNumber(4)
  $pb.PbList<ImageData> get images => $_getList(3);

  /// The type of the subagent it is for (SendPromptRequest.to_subagent).
  @$pb.TagNumber(5)
  $core.String get relayTo => $_getSZ(4);
  @$pb.TagNumber(5)
  set relayTo($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRelayTo() => $_has(4);
  @$pb.TagNumber(5)
  void clearRelayTo() => $_clearField(5);

  /// That subagent's tool call (SendPromptRequest.to_subagent), to send it
  /// there again; empty when not known (a replayed message).
  @$pb.TagNumber(6)
  $core.String get toSubagent => $_getSZ(5);
  @$pb.TagNumber(6)
  set toSubagent($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasToSubagent() => $_has(5);
  @$pb.TagNumber(6)
  void clearToSubagent() => $_clearField(6);
}

/// Every message waiting in a chat's queue, in order.
class ChatQueue extends $pb.GeneratedMessage {
  factory ChatQueue({
    $core.Iterable<QueuedMessage>? messages,
  }) {
    final result = ChatQueue._();
    if (messages != null) result.messages.addAll(messages);
    return result;
  }

  ChatQueue._();

  factory ChatQueue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatQueue()..mergeFromBuffer(data, registry);
  factory ChatQueue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatQueue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatQueue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ChatQueue.$_createMessage)
    ..pPM<QueuedMessage>(1, _omitFieldNames ? '' : 'messages',
        subBuilder: QueuedMessage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatQueue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatQueue copyWith(void Function(ChatQueue) updates) =>
      super.copyWith((message) => updates(message as ChatQueue)) as ChatQueue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChatQueue() / ChatQueue.new instead')
  static ChatQueue create() => ChatQueue._();
  static $pb.GeneratedMessage $_createMessage() => ChatQueue._();
  @$core.override
  ChatQueue createEmptyInstance() => ChatQueue._();
  @$core.pragma('dart2js:noInline')
  static ChatQueue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ChatQueue>(ChatQueue.$_createMessage);
  static ChatQueue? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<QueuedMessage> get messages => $_getList(0);
}

class RewindChatRequest extends $pb.GeneratedMessage {
  factory RewindChatRequest({
    $core.String? chatId,
    $core.String? itemId,
  }) {
    final result = RewindChatRequest._();
    if (chatId != null) result.chatId = chatId;
    if (itemId != null) result.itemId = itemId;
    return result;
  }

  RewindChatRequest._();

  factory RewindChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RewindChatRequest()..mergeFromBuffer(data, registry);
  factory RewindChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RewindChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RewindChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RewindChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'itemId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RewindChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RewindChatRequest copyWith(void Function(RewindChatRequest) updates) =>
      super.copyWith((message) => updates(message as RewindChatRequest))
          as RewindChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RewindChatRequest() / RewindChatRequest.new instead')
  static RewindChatRequest create() => RewindChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => RewindChatRequest._();
  @$core.override
  RewindChatRequest createEmptyInstance() => RewindChatRequest._();
  @$core.pragma('dart2js:noInline')
  static RewindChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RewindChatRequest>(
          RewindChatRequest.$_createMessage);
  static RewindChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  /// The user message to rewind to.
  @$pb.TagNumber(2)
  $core.String get itemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set itemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemId() => $_clearField(2);
}

class RewindChatResponse extends $pb.GeneratedMessage {
  factory RewindChatResponse({
    QueuedMessage? message,
  }) {
    final result = RewindChatResponse._();
    if (message != null) result.message = message;
    return result;
  }

  RewindChatResponse._();

  factory RewindChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RewindChatResponse()..mergeFromBuffer(data, registry);
  factory RewindChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RewindChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RewindChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RewindChatResponse.$_createMessage)
    ..aOM<QueuedMessage>(1, _omitFieldNames ? '' : 'message',
        subBuilder: QueuedMessage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RewindChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RewindChatResponse copyWith(void Function(RewindChatResponse) updates) =>
      super.copyWith((message) => updates(message as RewindChatResponse))
          as RewindChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RewindChatResponse() / RewindChatResponse.new instead')
  static RewindChatResponse create() => RewindChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => RewindChatResponse._();
  @$core.override
  RewindChatResponse createEmptyInstance() => RewindChatResponse._();
  @$core.pragma('dart2js:noInline')
  static RewindChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RewindChatResponse>(
          RewindChatResponse.$_createMessage);
  static RewindChatResponse? _defaultInstance;

  /// The message, to edit and send again (its files aren't kept).
  @$pb.TagNumber(1)
  QueuedMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(QueuedMessage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  QueuedMessage ensureMessage() => $_ensure(0);
}

class UnqueueRequest extends $pb.GeneratedMessage {
  factory UnqueueRequest({
    $core.String? chatId,
    $core.String? id,
  }) {
    final result = UnqueueRequest._();
    if (chatId != null) result.chatId = chatId;
    if (id != null) result.id = id;
    return result;
  }

  UnqueueRequest._();

  factory UnqueueRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnqueueRequest()..mergeFromBuffer(data, registry);
  factory UnqueueRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnqueueRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnqueueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: UnqueueRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnqueueRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnqueueRequest copyWith(void Function(UnqueueRequest) updates) =>
      super.copyWith((message) => updates(message as UnqueueRequest))
          as UnqueueRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UnqueueRequest() / UnqueueRequest.new instead')
  static UnqueueRequest create() => UnqueueRequest._();
  static $pb.GeneratedMessage $_createMessage() => UnqueueRequest._();
  @$core.override
  UnqueueRequest createEmptyInstance() => UnqueueRequest._();
  @$core.pragma('dart2js:noInline')
  static UnqueueRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnqueueRequest>(
          UnqueueRequest.$_createMessage);
  static UnqueueRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);
}

class UnqueueResponse extends $pb.GeneratedMessage {
  factory UnqueueResponse({
    QueuedMessage? message,
  }) {
    final result = UnqueueResponse._();
    if (message != null) result.message = message;
    return result;
  }

  UnqueueResponse._();

  factory UnqueueResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnqueueResponse()..mergeFromBuffer(data, registry);
  factory UnqueueResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnqueueResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnqueueResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: UnqueueResponse.$_createMessage)
    ..aOM<QueuedMessage>(1, _omitFieldNames ? '' : 'message',
        subBuilder: QueuedMessage.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnqueueResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnqueueResponse copyWith(void Function(UnqueueResponse) updates) =>
      super.copyWith((message) => updates(message as UnqueueResponse))
          as UnqueueResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use UnqueueResponse() / UnqueueResponse.new instead')
  static UnqueueResponse create() => UnqueueResponse._();
  static $pb.GeneratedMessage $_createMessage() => UnqueueResponse._();
  @$core.override
  UnqueueResponse createEmptyInstance() => UnqueueResponse._();
  @$core.pragma('dart2js:noInline')
  static UnqueueResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UnqueueResponse>(
          UnqueueResponse.$_createMessage);
  static UnqueueResponse? _defaultInstance;

  @$pb.TagNumber(1)
  QueuedMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(QueuedMessage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  QueuedMessage ensureMessage() => $_ensure(0);
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
    $core.bool? takeBack,
  }) {
    final result = CancelTurnRequest._();
    if (chatId != null) result.chatId = chatId;
    if (takeBack != null) result.takeBack = takeBack;
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
    ..aOB(2, _omitFieldNames ? '' : 'takeBack')
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

  /// Take the last user message back too, if the agent hasn't answered it
  /// with any text or tool call yet: the chat is rewound to just before it
  /// when it can be, else it stays, with a notice. The call then
  /// returns once the turn has ended.
  @$pb.TagNumber(2)
  $core.bool get takeBack => $_getBF(1);
  @$pb.TagNumber(2)
  set takeBack($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTakeBack() => $_has(1);
  @$pb.TagNumber(2)
  void clearTakeBack() => $_clearField(2);
}

class CancelTurnResponse extends $pb.GeneratedMessage {
  factory CancelTurnResponse({
    QueuedMessage? message,
  }) {
    final result = CancelTurnResponse._();
    if (message != null) result.message = message;
    return result;
  }

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
    ..aOM<QueuedMessage>(1, _omitFieldNames ? '' : 'message',
        subBuilder: QueuedMessage.$_createMessage)
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

  /// The message taken back, to edit, if it was.
  @$pb.TagNumber(1)
  QueuedMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message(QueuedMessage value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => $_clearField(1);
  @$pb.TagNumber(1)
  QueuedMessage ensureMessage() => $_ensure(0);
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

class SleepChatRequest extends $pb.GeneratedMessage {
  factory SleepChatRequest({
    $core.String? chatId,
  }) {
    final result = SleepChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  SleepChatRequest._();

  factory SleepChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SleepChatRequest()..mergeFromBuffer(data, registry);
  factory SleepChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SleepChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SleepChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SleepChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SleepChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SleepChatRequest copyWith(void Function(SleepChatRequest) updates) =>
      super.copyWith((message) => updates(message as SleepChatRequest))
          as SleepChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SleepChatRequest() / SleepChatRequest.new instead')
  static SleepChatRequest create() => SleepChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => SleepChatRequest._();
  @$core.override
  SleepChatRequest createEmptyInstance() => SleepChatRequest._();
  @$core.pragma('dart2js:noInline')
  static SleepChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SleepChatRequest>(
          SleepChatRequest.$_createMessage);
  static SleepChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class SleepChatResponse extends $pb.GeneratedMessage {
  factory SleepChatResponse() => SleepChatResponse._();

  SleepChatResponse._();

  factory SleepChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SleepChatResponse()..mergeFromBuffer(data, registry);
  factory SleepChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SleepChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SleepChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SleepChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SleepChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SleepChatResponse copyWith(void Function(SleepChatResponse) updates) =>
      super.copyWith((message) => updates(message as SleepChatResponse))
          as SleepChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SleepChatResponse() / SleepChatResponse.new instead')
  static SleepChatResponse create() => SleepChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => SleepChatResponse._();
  @$core.override
  SleepChatResponse createEmptyInstance() => SleepChatResponse._();
  @$core.pragma('dart2js:noInline')
  static SleepChatResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SleepChatResponse>(
          SleepChatResponse.$_createMessage);
  static SleepChatResponse? _defaultInstance;
}

class GetMemoryRequest extends $pb.GeneratedMessage {
  factory GetMemoryRequest({
    $core.int? appPid,
  }) {
    final result = GetMemoryRequest._();
    if (appPid != null) result.appPid = appPid;
    return result;
  }

  GetMemoryRequest._();

  factory GetMemoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetMemoryRequest()..mergeFromBuffer(data, registry);
  factory GetMemoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetMemoryRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMemoryRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetMemoryRequest.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'appPid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMemoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMemoryRequest copyWith(void Function(GetMemoryRequest) updates) =>
      super.copyWith((message) => updates(message as GetMemoryRequest))
          as GetMemoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetMemoryRequest() / GetMemoryRequest.new instead')
  static GetMemoryRequest create() => GetMemoryRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetMemoryRequest._();
  @$core.override
  GetMemoryRequest createEmptyInstance() => GetMemoryRequest._();
  @$core.pragma('dart2js:noInline')
  static GetMemoryRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetMemoryRequest>(
          GetMemoryRequest.$_createMessage);
  static GetMemoryRequest? _defaultInstance;

  /// The asking app's process, to read along; 0 for none.
  @$pb.TagNumber(1)
  $core.int get appPid => $_getIZ(0);
  @$pb.TagNumber(1)
  set appPid($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppPid() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppPid() => $_clearField(1);
}

class GetMemoryResponse extends $pb.GeneratedMessage {
  factory GetMemoryResponse({
    $fixnum.Int64? daemon,
    $fixnum.Int64? app,
    $fixnum.Int64? other,
    $core.Iterable<$core.MapEntry<$core.String, $fixnum.Int64>>? chats,
  }) {
    final result = GetMemoryResponse._();
    if (daemon != null) result.daemon = daemon;
    if (app != null) result.app = app;
    if (other != null) result.other = other;
    if (chats != null) result.chats.addEntries(chats);
    return result;
  }

  GetMemoryResponse._();

  factory GetMemoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetMemoryResponse()..mergeFromBuffer(data, registry);
  factory GetMemoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetMemoryResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetMemoryResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetMemoryResponse.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'daemon')
    ..aInt64(2, _omitFieldNames ? '' : 'app')
    ..aInt64(3, _omitFieldNames ? '' : 'other')
    ..m<$core.String, $fixnum.Int64>(4, _omitFieldNames ? '' : 'chats',
        entryClassName: 'GetMemoryResponse.ChatsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.O6,
        packageName: const $pb.PackageName('nushi.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMemoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetMemoryResponse copyWith(void Function(GetMemoryResponse) updates) =>
      super.copyWith((message) => updates(message as GetMemoryResponse))
          as GetMemoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetMemoryResponse() / GetMemoryResponse.new instead')
  static GetMemoryResponse create() => GetMemoryResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetMemoryResponse._();
  @$core.override
  GetMemoryResponse createEmptyInstance() => GetMemoryResponse._();
  @$core.pragma('dart2js:noInline')
  static GetMemoryResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetMemoryResponse>(
          GetMemoryResponse.$_createMessage);
  static GetMemoryResponse? _defaultInstance;

  /// nushid itself.
  @$pb.TagNumber(1)
  $fixnum.Int64 get daemon => $_getI64(0);
  @$pb.TagNumber(1)
  set daemon($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDaemon() => $_has(0);
  @$pb.TagNumber(1)
  void clearDaemon() => $_clearField(1);

  /// The app's process (app_pid), with what it started.
  @$pb.TagNumber(2)
  $fixnum.Int64 get app => $_getI64(1);
  @$pb.TagNumber(2)
  set app($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasApp() => $_has(1);
  @$pb.TagNumber(2)
  void clearApp() => $_clearField(2);

  /// The daemon's other processes: terminals, and agents no chat holds
  /// (one deleting a session's history, one still starting).
  @$pb.TagNumber(3)
  $fixnum.Int64 get other => $_getI64(2);
  @$pb.TagNumber(3)
  set other($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOther() => $_has(2);
  @$pb.TagNumber(3)
  void clearOther() => $_clearField(3);

  /// Each chat's running agent, with what it started, by chat id.
  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $fixnum.Int64> get chats => $_getMap(3);
}

class GetSettingsRequest extends $pb.GeneratedMessage {
  factory GetSettingsRequest() => GetSettingsRequest._();

  GetSettingsRequest._();

  factory GetSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSettingsRequest()..mergeFromBuffer(data, registry);
  factory GetSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSettingsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetSettingsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsRequest copyWith(void Function(GetSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as GetSettingsRequest))
          as GetSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetSettingsRequest() / GetSettingsRequest.new instead')
  static GetSettingsRequest create() => GetSettingsRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetSettingsRequest._();
  @$core.override
  GetSettingsRequest createEmptyInstance() => GetSettingsRequest._();
  @$core.pragma('dart2js:noInline')
  static GetSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSettingsRequest>(
          GetSettingsRequest.$_createMessage);
  static GetSettingsRequest? _defaultInstance;
}

class Settings extends $pb.GeneratedMessage {
  factory Settings({
    $core.int? sleepAfterMinutes,
  }) {
    final result = Settings._();
    if (sleepAfterMinutes != null) result.sleepAfterMinutes = sleepAfterMinutes;
    return result;
  }

  Settings._();

  factory Settings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Settings()..mergeFromBuffer(data, registry);
  factory Settings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Settings()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Settings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Settings.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'sleepAfterMinutes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Settings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Settings copyWith(void Function(Settings) updates) =>
      super.copyWith((message) => updates(message as Settings)) as Settings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Settings() / Settings.new instead')
  static Settings create() => Settings._();
  static $pb.GeneratedMessage $_createMessage() => Settings._();
  @$core.override
  Settings createEmptyInstance() => Settings._();
  @$core.pragma('dart2js:noInline')
  static Settings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Settings>(Settings.$_createMessage);
  static Settings? _defaultInstance;

  /// Chats sleep once idle this long, when nothing would be lost (no turn,
  /// queue, prompt, background command, subagent or side chat); 0: never.
  @$pb.TagNumber(1)
  $core.int get sleepAfterMinutes => $_getIZ(0);
  @$pb.TagNumber(1)
  set sleepAfterMinutes($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSleepAfterMinutes() => $_has(0);
  @$pb.TagNumber(1)
  void clearSleepAfterMinutes() => $_clearField(1);
}

class GetSettingsResponse extends $pb.GeneratedMessage {
  factory GetSettingsResponse({
    Settings? settings,
  }) {
    final result = GetSettingsResponse._();
    if (settings != null) result.settings = settings;
    return result;
  }

  GetSettingsResponse._();

  factory GetSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSettingsResponse()..mergeFromBuffer(data, registry);
  factory GetSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetSettingsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSettingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetSettingsResponse.$_createMessage)
    ..aOM<Settings>(1, _omitFieldNames ? '' : 'settings',
        subBuilder: Settings.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSettingsResponse copyWith(void Function(GetSettingsResponse) updates) =>
      super.copyWith((message) => updates(message as GetSettingsResponse))
          as GetSettingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use GetSettingsResponse() / GetSettingsResponse.new instead')
  static GetSettingsResponse create() => GetSettingsResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetSettingsResponse._();
  @$core.override
  GetSettingsResponse createEmptyInstance() => GetSettingsResponse._();
  @$core.pragma('dart2js:noInline')
  static GetSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSettingsResponse>(
          GetSettingsResponse.$_createMessage);
  static GetSettingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Settings get settings => $_getN(0);
  @$pb.TagNumber(1)
  set settings(Settings value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSettings() => $_has(0);
  @$pb.TagNumber(1)
  void clearSettings() => $_clearField(1);
  @$pb.TagNumber(1)
  Settings ensureSettings() => $_ensure(0);
}

class SetSettingsRequest extends $pb.GeneratedMessage {
  factory SetSettingsRequest({
    Settings? settings,
  }) {
    final result = SetSettingsRequest._();
    if (settings != null) result.settings = settings;
    return result;
  }

  SetSettingsRequest._();

  factory SetSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSettingsRequest()..mergeFromBuffer(data, registry);
  factory SetSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSettingsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetSettingsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetSettingsRequest.$_createMessage)
    ..aOM<Settings>(1, _omitFieldNames ? '' : 'settings',
        subBuilder: Settings.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSettingsRequest copyWith(void Function(SetSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as SetSettingsRequest))
          as SetSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetSettingsRequest() / SetSettingsRequest.new instead')
  static SetSettingsRequest create() => SetSettingsRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetSettingsRequest._();
  @$core.override
  SetSettingsRequest createEmptyInstance() => SetSettingsRequest._();
  @$core.pragma('dart2js:noInline')
  static SetSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetSettingsRequest>(
          SetSettingsRequest.$_createMessage);
  static SetSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  Settings get settings => $_getN(0);
  @$pb.TagNumber(1)
  set settings(Settings value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSettings() => $_has(0);
  @$pb.TagNumber(1)
  void clearSettings() => $_clearField(1);
  @$pb.TagNumber(1)
  Settings ensureSettings() => $_ensure(0);
}

class SetSettingsResponse extends $pb.GeneratedMessage {
  factory SetSettingsResponse() => SetSettingsResponse._();

  SetSettingsResponse._();

  factory SetSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSettingsResponse()..mergeFromBuffer(data, registry);
  factory SetSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSettingsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetSettingsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetSettingsResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSettingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSettingsResponse copyWith(void Function(SetSettingsResponse) updates) =>
      super.copyWith((message) => updates(message as SetSettingsResponse))
          as SetSettingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SetSettingsResponse() / SetSettingsResponse.new instead')
  static SetSettingsResponse create() => SetSettingsResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetSettingsResponse._();
  @$core.override
  SetSettingsResponse createEmptyInstance() => SetSettingsResponse._();
  @$core.pragma('dart2js:noInline')
  static SetSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetSettingsResponse>(
          SetSettingsResponse.$_createMessage);
  static SetSettingsResponse? _defaultInstance;
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
    $core.Iterable<WorktreePlan>? worktrees,
    $core.Iterable<Terminal>? terminals,
  }) {
    final result = PlanDeleteChatResponse._();
    if (sessions != null) result.sessions.addAll(sessions);
    if (deletesHistory != null) result.deletesHistory = deletesHistory;
    if (scratchFolder != null) result.scratchFolder = scratchFolder;
    if (worktrees != null) result.worktrees.addAll(worktrees);
    if (terminals != null) result.terminals.addAll(terminals);
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
    ..pPM<WorktreePlan>(6, _omitFieldNames ? '' : 'worktrees',
        subBuilder: WorktreePlan.$_createMessage)
    ..pPM<Terminal>(7, _omitFieldNames ? '' : 'terminals',
        subBuilder: Terminal.$_createMessage)
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

  /// All of the chat's worktrees, each with what removing it and deleting
  /// its branch would lose: its own, then those it moved out of, which stay
  /// on disk until it is deleted.
  @$pb.TagNumber(6)
  $pb.PbList<WorktreePlan> get worktrees => $_getList(3);

  ///  The chat's terminals whose shell still runs; deleting closes them
  /// .
  @$pb.TagNumber(7)
  $pb.PbList<Terminal> get terminals => $_getList(4);
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
    $core.int? ignored,
  }) {
    final result = WorktreeState._();
    if (gone != null) result.gone = gone;
    if (changed != null) result.changed = changed;
    if (commits != null) result.commits = commits;
    if (branchGone != null) result.branchGone = branchGone;
    if (error != null) result.error = error;
    if (ignored != null) result.ignored = ignored;
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
    ..aI(6, _omitFieldNames ? '' : 'ignored')
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

  /// Files and folders git ignores, which removing it deletes too.
  @$pb.TagNumber(6)
  $core.int get ignored => $_getIZ(5);
  @$pb.TagNumber(6)
  set ignored($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIgnored() => $_has(5);
  @$pb.TagNumber(6)
  void clearIgnored() => $_clearField(6);
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
    $core.Iterable<WorktreeChoice>? worktrees,
  }) {
    final result = DeleteChatRequest._();
    if (chatId != null) result.chatId = chatId;
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

  /// What to do with each of the chat's worktrees, by path; the ones left
  /// out stay.
  @$pb.TagNumber(6)
  $pb.PbList<WorktreeChoice> get worktrees => $_getList(1);
}

/// What to do with a worktree and its branch: remove the worktree (git
/// worktree remove; one with changes only with force_worktree), and delete
/// its branch (one with commits its base doesn't have only with
/// force_branch).
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

class GetContextUsageRequest extends $pb.GeneratedMessage {
  factory GetContextUsageRequest({
    $core.String? chatId,
  }) {
    final result = GetContextUsageRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  GetContextUsageRequest._();

  factory GetContextUsageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetContextUsageRequest()..mergeFromBuffer(data, registry);
  factory GetContextUsageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetContextUsageRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetContextUsageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetContextUsageRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetContextUsageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetContextUsageRequest copyWith(
          void Function(GetContextUsageRequest) updates) =>
      super.copyWith((message) => updates(message as GetContextUsageRequest))
          as GetContextUsageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetContextUsageRequest() / GetContextUsageRequest.new instead')
  static GetContextUsageRequest create() => GetContextUsageRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetContextUsageRequest._();
  @$core.override
  GetContextUsageRequest createEmptyInstance() => GetContextUsageRequest._();
  @$core.pragma('dart2js:noInline')
  static GetContextUsageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetContextUsageRequest>(
          GetContextUsageRequest.$_createMessage);
  static GetContextUsageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class GetContextUsageResponse extends $pb.GeneratedMessage {
  factory GetContextUsageResponse({
    $core.Iterable<ContextCategory>? categories,
    $core.String? markdown,
  }) {
    final result = GetContextUsageResponse._();
    if (categories != null) result.categories.addAll(categories);
    if (markdown != null) result.markdown = markdown;
    return result;
  }

  GetContextUsageResponse._();

  factory GetContextUsageResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetContextUsageResponse()..mergeFromBuffer(data, registry);
  factory GetContextUsageResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetContextUsageResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetContextUsageResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetContextUsageResponse.$_createMessage)
    ..pPM<ContextCategory>(1, _omitFieldNames ? '' : 'categories',
        subBuilder: ContextCategory.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'markdown')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetContextUsageResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetContextUsageResponse copyWith(
          void Function(GetContextUsageResponse) updates) =>
      super.copyWith((message) => updates(message as GetContextUsageResponse))
          as GetContextUsageResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetContextUsageResponse() / GetContextUsageResponse.new instead')
  static GetContextUsageResponse create() => GetContextUsageResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetContextUsageResponse._();
  @$core.override
  GetContextUsageResponse createEmptyInstance() => GetContextUsageResponse._();
  @$core.pragma('dart2js:noInline')
  static GetContextUsageResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetContextUsageResponse>(
          GetContextUsageResponse.$_createMessage);
  static GetContextUsageResponse? _defaultInstance;

  /// What fills the context, in the agent's order ("Free space" among them);
  /// empty when its answer couldn't be read.
  @$pb.TagNumber(1)
  $pb.PbList<ContextCategory> get categories => $_getList(0);

  /// The agent's answer as it gave it, markdown.
  @$pb.TagNumber(2)
  $core.String get markdown => $_getSZ(1);
  @$pb.TagNumber(2)
  set markdown($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMarkdown() => $_has(1);
  @$pb.TagNumber(2)
  void clearMarkdown() => $_clearField(2);
}

class ListMcpServersRequest extends $pb.GeneratedMessage {
  factory ListMcpServersRequest({
    $core.String? folder,
    $core.bool? checkHealth,
  }) {
    final result = ListMcpServersRequest._();
    if (folder != null) result.folder = folder;
    if (checkHealth != null) result.checkHealth = checkHealth;
    return result;
  }

  ListMcpServersRequest._();

  factory ListMcpServersRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpServersRequest()..mergeFromBuffer(data, registry);
  factory ListMcpServersRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpServersRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMcpServersRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListMcpServersRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOB(2, _omitFieldNames ? '' : 'checkHealth')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpServersRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpServersRequest copyWith(
          void Function(ListMcpServersRequest) updates) =>
      super.copyWith((message) => updates(message as ListMcpServersRequest))
          as ListMcpServersRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListMcpServersRequest() / ListMcpServersRequest.new instead')
  static ListMcpServersRequest create() => ListMcpServersRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListMcpServersRequest._();
  @$core.override
  ListMcpServersRequest createEmptyInstance() => ListMcpServersRequest._();
  @$core.pragma('dart2js:noInline')
  static ListMcpServersRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMcpServersRequest>(
          ListMcpServersRequest.$_createMessage);
  static ListMcpServersRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get checkHealth => $_getBF(1);
  @$pb.TagNumber(2)
  set checkHealth($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCheckHealth() => $_has(1);
  @$pb.TagNumber(2)
  void clearCheckHealth() => $_clearField(2);
}

class ListMcpServersResponse extends $pb.GeneratedMessage {
  factory ListMcpServersResponse({
    $core.Iterable<McpServer>? servers,
    $core.String? checkError,
  }) {
    final result = ListMcpServersResponse._();
    if (servers != null) result.servers.addAll(servers);
    if (checkError != null) result.checkError = checkError;
    return result;
  }

  ListMcpServersResponse._();

  factory ListMcpServersResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpServersResponse()..mergeFromBuffer(data, registry);
  factory ListMcpServersResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListMcpServersResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListMcpServersResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListMcpServersResponse.$_createMessage)
    ..pPM<McpServer>(1, _omitFieldNames ? '' : 'servers',
        subBuilder: McpServer.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'checkError')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpServersResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListMcpServersResponse copyWith(
          void Function(ListMcpServersResponse) updates) =>
      super.copyWith((message) => updates(message as ListMcpServersResponse))
          as ListMcpServersResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListMcpServersResponse() / ListMcpServersResponse.new instead')
  static ListMcpServersResponse create() => ListMcpServersResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListMcpServersResponse._();
  @$core.override
  ListMcpServersResponse createEmptyInstance() => ListMcpServersResponse._();
  @$core.pragma('dart2js:noInline')
  static ListMcpServersResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListMcpServersResponse>(
          ListMcpServersResponse.$_createMessage);
  static ListMcpServersResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<McpServer> get servers => $_getList(0);

  /// Why checking failed; the servers then come unchecked.
  @$pb.TagNumber(2)
  $core.String get checkError => $_getSZ(1);
  @$pb.TagNumber(2)
  set checkError($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCheckError() => $_has(1);
  @$pb.TagNumber(2)
  void clearCheckError() => $_clearField(2);
}

class McpServer extends $pb.GeneratedMessage {
  factory McpServer({
    $core.String? name,
    $core.String? scope,
    $core.String? source,
    $core.String? configJson,
    $core.String? state,
    $core.String? detail,
    $core.bool? shadowed,
    $core.bool? off,
    $core.String? offBy,
    $core.bool? approved,
  }) {
    final result = McpServer._();
    if (name != null) result.name = name;
    if (scope != null) result.scope = scope;
    if (source != null) result.source = source;
    if (configJson != null) result.configJson = configJson;
    if (state != null) result.state = state;
    if (detail != null) result.detail = detail;
    if (shadowed != null) result.shadowed = shadowed;
    if (off != null) result.off = off;
    if (offBy != null) result.offBy = offBy;
    if (approved != null) result.approved = approved;
    return result;
  }

  McpServer._();

  factory McpServer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      McpServer()..mergeFromBuffer(data, registry);
  factory McpServer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      McpServer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'McpServer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: McpServer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'scope')
    ..aOS(3, _omitFieldNames ? '' : 'source')
    ..aOS(4, _omitFieldNames ? '' : 'configJson')
    ..aOS(5, _omitFieldNames ? '' : 'state')
    ..aOS(6, _omitFieldNames ? '' : 'detail')
    ..aOB(7, _omitFieldNames ? '' : 'shadowed')
    ..aOB(8, _omitFieldNames ? '' : 'off')
    ..aOS(9, _omitFieldNames ? '' : 'offBy')
    ..aOB(10, _omitFieldNames ? '' : 'approved')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  McpServer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  McpServer copyWith(void Function(McpServer) updates) =>
      super.copyWith((message) => updates(message as McpServer)) as McpServer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use McpServer() / McpServer.new instead')
  static McpServer create() => McpServer._();
  static $pb.GeneratedMessage $_createMessage() => McpServer._();
  @$core.override
  McpServer createEmptyInstance() => McpServer._();
  @$core.pragma('dart2js:noInline')
  static McpServer getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<McpServer>(McpServer.$_createMessage);
  static McpServer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// "user", "project", "local", "plugin", "claudeai" or "other".
  @$pb.TagNumber(2)
  $core.String get scope => $_getSZ(1);
  @$pb.TagNumber(2)
  set scope($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScope() => $_has(1);
  @$pb.TagNumber(2)
  void clearScope() => $_clearField(2);

  /// The file that has it (for local scope, the project folder).
  @$pb.TagNumber(3)
  $core.String get source => $_getSZ(2);
  @$pb.TagNumber(3)
  set source($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => $_clearField(3);

  /// Its config as JSON ("command", "args", "env", "type", "url",
  /// "headers", ...), env and header values as "••••".
  @$pb.TagNumber(4)
  $core.String get configJson => $_getSZ(3);
  @$pb.TagNumber(4)
  set configJson($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConfigJson() => $_has(3);
  @$pb.TagNumber(4)
  void clearConfigJson() => $_clearField(4);

  /// Once checked: "connected", "failed", "needs_auth", "pending"
  /// (approval), "disabled" or "unknown"; detail is the agent's words.
  @$pb.TagNumber(5)
  $core.String get state => $_getSZ(4);
  @$pb.TagNumber(5)
  set state($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasState() => $_has(4);
  @$pb.TagNumber(5)
  void clearState() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get detail => $_getSZ(5);
  @$pb.TagNumber(6)
  set detail($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDetail() => $_has(5);
  @$pb.TagNumber(6)
  void clearDetail() => $_clearField(6);

  /// A server of the same name in a scope that wins hides it.
  @$pb.TagNumber(7)
  $core.bool get shadowed => $_getBF(6);
  @$pb.TagNumber(7)
  set shadowed($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasShadowed() => $_has(6);
  @$pb.TagNumber(7)
  void clearShadowed() => $_clearField(7);

  /// A project server turned off (rejected) for the folder; off_by names a
  /// file that does it other than the one SetMcpServerOn changes.
  @$pb.TagNumber(8)
  $core.bool get off => $_getBF(7);
  @$pb.TagNumber(8)
  set off($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOff() => $_has(7);
  @$pb.TagNumber(8)
  void clearOff() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get offBy => $_getSZ(8);
  @$pb.TagNumber(9)
  set offBy($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOffBy() => $_has(8);
  @$pb.TagNumber(9)
  void clearOffBy() => $_clearField(9);

  /// The project's local settings approve this project server (Claude in
  /// the terminal takes that once the folder is trusted there).
  @$pb.TagNumber(10)
  $core.bool get approved => $_getBF(9);
  @$pb.TagNumber(10)
  set approved($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasApproved() => $_has(9);
  @$pb.TagNumber(10)
  void clearApproved() => $_clearField(10);
}

class AddMcpServerRequest extends $pb.GeneratedMessage {
  factory AddMcpServerRequest({
    $core.String? folder,
    $core.String? scope,
    $core.String? name,
    $core.String? configJson,
  }) {
    final result = AddMcpServerRequest._();
    if (folder != null) result.folder = folder;
    if (scope != null) result.scope = scope;
    if (name != null) result.name = name;
    if (configJson != null) result.configJson = configJson;
    return result;
  }

  AddMcpServerRequest._();

  factory AddMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddMcpServerRequest()..mergeFromBuffer(data, registry);
  factory AddMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'scope')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'configJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddMcpServerRequest copyWith(void Function(AddMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as AddMcpServerRequest))
          as AddMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use AddMcpServerRequest() / AddMcpServerRequest.new instead')
  static AddMcpServerRequest create() => AddMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddMcpServerRequest._();
  @$core.override
  AddMcpServerRequest createEmptyInstance() => AddMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static AddMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddMcpServerRequest>(
          AddMcpServerRequest.$_createMessage);
  static AddMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get scope => $_getSZ(1);
  @$pb.TagNumber(2)
  set scope($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScope() => $_has(1);
  @$pb.TagNumber(2)
  void clearScope() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get configJson => $_getSZ(3);
  @$pb.TagNumber(4)
  set configJson($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConfigJson() => $_has(3);
  @$pb.TagNumber(4)
  void clearConfigJson() => $_clearField(4);
}

class AddMcpServerResponse extends $pb.GeneratedMessage {
  factory AddMcpServerResponse() => AddMcpServerResponse._();

  AddMcpServerResponse._();

  factory AddMcpServerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddMcpServerResponse()..mergeFromBuffer(data, registry);
  factory AddMcpServerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddMcpServerResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddMcpServerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddMcpServerResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddMcpServerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddMcpServerResponse copyWith(void Function(AddMcpServerResponse) updates) =>
      super.copyWith((message) => updates(message as AddMcpServerResponse))
          as AddMcpServerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddMcpServerResponse() / AddMcpServerResponse.new instead')
  static AddMcpServerResponse create() => AddMcpServerResponse._();
  static $pb.GeneratedMessage $_createMessage() => AddMcpServerResponse._();
  @$core.override
  AddMcpServerResponse createEmptyInstance() => AddMcpServerResponse._();
  @$core.pragma('dart2js:noInline')
  static AddMcpServerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddMcpServerResponse>(
          AddMcpServerResponse.$_createMessage);
  static AddMcpServerResponse? _defaultInstance;
}

class EditMcpServerRequest extends $pb.GeneratedMessage {
  factory EditMcpServerRequest({
    $core.String? folder,
    $core.String? scope,
    $core.String? name,
    $core.String? configJson,
  }) {
    final result = EditMcpServerRequest._();
    if (folder != null) result.folder = folder;
    if (scope != null) result.scope = scope;
    if (name != null) result.name = name;
    if (configJson != null) result.configJson = configJson;
    return result;
  }

  EditMcpServerRequest._();

  factory EditMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EditMcpServerRequest()..mergeFromBuffer(data, registry);
  factory EditMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EditMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EditMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'scope')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'configJson')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditMcpServerRequest copyWith(void Function(EditMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as EditMcpServerRequest))
          as EditMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use EditMcpServerRequest() / EditMcpServerRequest.new instead')
  static EditMcpServerRequest create() => EditMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => EditMcpServerRequest._();
  @$core.override
  EditMcpServerRequest createEmptyInstance() => EditMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static EditMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditMcpServerRequest>(
          EditMcpServerRequest.$_createMessage);
  static EditMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get scope => $_getSZ(1);
  @$pb.TagNumber(2)
  set scope($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScope() => $_has(1);
  @$pb.TagNumber(2)
  void clearScope() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get configJson => $_getSZ(3);
  @$pb.TagNumber(4)
  set configJson($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasConfigJson() => $_has(3);
  @$pb.TagNumber(4)
  void clearConfigJson() => $_clearField(4);
}

class EditMcpServerResponse extends $pb.GeneratedMessage {
  factory EditMcpServerResponse() => EditMcpServerResponse._();

  EditMcpServerResponse._();

  factory EditMcpServerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EditMcpServerResponse()..mergeFromBuffer(data, registry);
  factory EditMcpServerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      EditMcpServerResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EditMcpServerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EditMcpServerResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditMcpServerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  EditMcpServerResponse copyWith(
          void Function(EditMcpServerResponse) updates) =>
      super.copyWith((message) => updates(message as EditMcpServerResponse))
          as EditMcpServerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use EditMcpServerResponse() / EditMcpServerResponse.new instead')
  static EditMcpServerResponse create() => EditMcpServerResponse._();
  static $pb.GeneratedMessage $_createMessage() => EditMcpServerResponse._();
  @$core.override
  EditMcpServerResponse createEmptyInstance() => EditMcpServerResponse._();
  @$core.pragma('dart2js:noInline')
  static EditMcpServerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<EditMcpServerResponse>(
          EditMcpServerResponse.$_createMessage);
  static EditMcpServerResponse? _defaultInstance;
}

class RemoveMcpServerRequest extends $pb.GeneratedMessage {
  factory RemoveMcpServerRequest({
    $core.String? folder,
    $core.String? scope,
    $core.String? name,
  }) {
    final result = RemoveMcpServerRequest._();
    if (folder != null) result.folder = folder;
    if (scope != null) result.scope = scope;
    if (name != null) result.name = name;
    return result;
  }

  RemoveMcpServerRequest._();

  factory RemoveMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerRequest()..mergeFromBuffer(data, registry);
  factory RemoveMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'scope')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerRequest copyWith(
          void Function(RemoveMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveMcpServerRequest))
          as RemoveMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveMcpServerRequest() / RemoveMcpServerRequest.new instead')
  static RemoveMcpServerRequest create() => RemoveMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveMcpServerRequest._();
  @$core.override
  RemoveMcpServerRequest createEmptyInstance() => RemoveMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveMcpServerRequest>(
          RemoveMcpServerRequest.$_createMessage);
  static RemoveMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get scope => $_getSZ(1);
  @$pb.TagNumber(2)
  set scope($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasScope() => $_has(1);
  @$pb.TagNumber(2)
  void clearScope() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);
}

class RemoveMcpServerResponse extends $pb.GeneratedMessage {
  factory RemoveMcpServerResponse() => RemoveMcpServerResponse._();

  RemoveMcpServerResponse._();

  factory RemoveMcpServerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerResponse()..mergeFromBuffer(data, registry);
  factory RemoveMcpServerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveMcpServerResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveMcpServerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveMcpServerResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveMcpServerResponse copyWith(
          void Function(RemoveMcpServerResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveMcpServerResponse))
          as RemoveMcpServerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveMcpServerResponse() / RemoveMcpServerResponse.new instead')
  static RemoveMcpServerResponse create() => RemoveMcpServerResponse._();
  static $pb.GeneratedMessage $_createMessage() => RemoveMcpServerResponse._();
  @$core.override
  RemoveMcpServerResponse createEmptyInstance() => RemoveMcpServerResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveMcpServerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveMcpServerResponse>(
          RemoveMcpServerResponse.$_createMessage);
  static RemoveMcpServerResponse? _defaultInstance;
}

class SetMcpServerOnRequest extends $pb.GeneratedMessage {
  factory SetMcpServerOnRequest({
    $core.String? folder,
    $core.String? name,
    $core.bool? on,
  }) {
    final result = SetMcpServerOnRequest._();
    if (folder != null) result.folder = folder;
    if (name != null) result.name = name;
    if (on != null) result.on = on;
    return result;
  }

  SetMcpServerOnRequest._();

  factory SetMcpServerOnRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMcpServerOnRequest()..mergeFromBuffer(data, registry);
  factory SetMcpServerOnRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMcpServerOnRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMcpServerOnRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetMcpServerOnRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOB(3, _omitFieldNames ? '' : 'on')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMcpServerOnRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMcpServerOnRequest copyWith(
          void Function(SetMcpServerOnRequest) updates) =>
      super.copyWith((message) => updates(message as SetMcpServerOnRequest))
          as SetMcpServerOnRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetMcpServerOnRequest() / SetMcpServerOnRequest.new instead')
  static SetMcpServerOnRequest create() => SetMcpServerOnRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetMcpServerOnRequest._();
  @$core.override
  SetMcpServerOnRequest createEmptyInstance() => SetMcpServerOnRequest._();
  @$core.pragma('dart2js:noInline')
  static SetMcpServerOnRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMcpServerOnRequest>(
          SetMcpServerOnRequest.$_createMessage);
  static SetMcpServerOnRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get on => $_getBF(2);
  @$pb.TagNumber(3)
  set on($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOn() => $_has(2);
  @$pb.TagNumber(3)
  void clearOn() => $_clearField(3);
}

class SetMcpServerOnResponse extends $pb.GeneratedMessage {
  factory SetMcpServerOnResponse() => SetMcpServerOnResponse._();

  SetMcpServerOnResponse._();

  factory SetMcpServerOnResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMcpServerOnResponse()..mergeFromBuffer(data, registry);
  factory SetMcpServerOnResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetMcpServerOnResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetMcpServerOnResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetMcpServerOnResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMcpServerOnResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetMcpServerOnResponse copyWith(
          void Function(SetMcpServerOnResponse) updates) =>
      super.copyWith((message) => updates(message as SetMcpServerOnResponse))
          as SetMcpServerOnResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetMcpServerOnResponse() / SetMcpServerOnResponse.new instead')
  static SetMcpServerOnResponse create() => SetMcpServerOnResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetMcpServerOnResponse._();
  @$core.override
  SetMcpServerOnResponse createEmptyInstance() => SetMcpServerOnResponse._();
  @$core.pragma('dart2js:noInline')
  static SetMcpServerOnResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetMcpServerOnResponse>(
          SetMcpServerOnResponse.$_createMessage);
  static SetMcpServerOnResponse? _defaultInstance;
}

class LoginMcpServerRequest extends $pb.GeneratedMessage {
  factory LoginMcpServerRequest({
    $core.String? folder,
    $core.String? name,
  }) {
    final result = LoginMcpServerRequest._();
    if (folder != null) result.folder = folder;
    if (name != null) result.name = name;
    return result;
  }

  LoginMcpServerRequest._();

  factory LoginMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginMcpServerRequest()..mergeFromBuffer(data, registry);
  factory LoginMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LoginMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginMcpServerRequest copyWith(
          void Function(LoginMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as LoginMcpServerRequest))
          as LoginMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LoginMcpServerRequest() / LoginMcpServerRequest.new instead')
  static LoginMcpServerRequest create() => LoginMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => LoginMcpServerRequest._();
  @$core.override
  LoginMcpServerRequest createEmptyInstance() => LoginMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static LoginMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginMcpServerRequest>(
          LoginMcpServerRequest.$_createMessage);
  static LoginMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class LoginMcpServerResponse extends $pb.GeneratedMessage {
  factory LoginMcpServerResponse() => LoginMcpServerResponse._();

  LoginMcpServerResponse._();

  factory LoginMcpServerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginMcpServerResponse()..mergeFromBuffer(data, registry);
  factory LoginMcpServerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LoginMcpServerResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginMcpServerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LoginMcpServerResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginMcpServerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginMcpServerResponse copyWith(
          void Function(LoginMcpServerResponse) updates) =>
      super.copyWith((message) => updates(message as LoginMcpServerResponse))
          as LoginMcpServerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LoginMcpServerResponse() / LoginMcpServerResponse.new instead')
  static LoginMcpServerResponse create() => LoginMcpServerResponse._();
  static $pb.GeneratedMessage $_createMessage() => LoginMcpServerResponse._();
  @$core.override
  LoginMcpServerResponse createEmptyInstance() => LoginMcpServerResponse._();
  @$core.pragma('dart2js:noInline')
  static LoginMcpServerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginMcpServerResponse>(
          LoginMcpServerResponse.$_createMessage);
  static LoginMcpServerResponse? _defaultInstance;
}

class LogoutMcpServerRequest extends $pb.GeneratedMessage {
  factory LogoutMcpServerRequest({
    $core.String? folder,
    $core.String? name,
  }) {
    final result = LogoutMcpServerRequest._();
    if (folder != null) result.folder = folder;
    if (name != null) result.name = name;
    return result;
  }

  LogoutMcpServerRequest._();

  factory LogoutMcpServerRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogoutMcpServerRequest()..mergeFromBuffer(data, registry);
  factory LogoutMcpServerRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogoutMcpServerRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogoutMcpServerRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LogoutMcpServerRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutMcpServerRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutMcpServerRequest copyWith(
          void Function(LogoutMcpServerRequest) updates) =>
      super.copyWith((message) => updates(message as LogoutMcpServerRequest))
          as LogoutMcpServerRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LogoutMcpServerRequest() / LogoutMcpServerRequest.new instead')
  static LogoutMcpServerRequest create() => LogoutMcpServerRequest._();
  static $pb.GeneratedMessage $_createMessage() => LogoutMcpServerRequest._();
  @$core.override
  LogoutMcpServerRequest createEmptyInstance() => LogoutMcpServerRequest._();
  @$core.pragma('dart2js:noInline')
  static LogoutMcpServerRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogoutMcpServerRequest>(
          LogoutMcpServerRequest.$_createMessage);
  static LogoutMcpServerRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class LogoutMcpServerResponse extends $pb.GeneratedMessage {
  factory LogoutMcpServerResponse() => LogoutMcpServerResponse._();

  LogoutMcpServerResponse._();

  factory LogoutMcpServerResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogoutMcpServerResponse()..mergeFromBuffer(data, registry);
  factory LogoutMcpServerResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogoutMcpServerResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogoutMcpServerResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LogoutMcpServerResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutMcpServerResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogoutMcpServerResponse copyWith(
          void Function(LogoutMcpServerResponse) updates) =>
      super.copyWith((message) => updates(message as LogoutMcpServerResponse))
          as LogoutMcpServerResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use LogoutMcpServerResponse() / LogoutMcpServerResponse.new instead')
  static LogoutMcpServerResponse create() => LogoutMcpServerResponse._();
  static $pb.GeneratedMessage $_createMessage() => LogoutMcpServerResponse._();
  @$core.override
  LogoutMcpServerResponse createEmptyInstance() => LogoutMcpServerResponse._();
  @$core.pragma('dart2js:noInline')
  static LogoutMcpServerResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogoutMcpServerResponse>(
          LogoutMcpServerResponse.$_createMessage);
  static LogoutMcpServerResponse? _defaultInstance;
}

class ReloadChatRequest extends $pb.GeneratedMessage {
  factory ReloadChatRequest({
    $core.String? chatId,
  }) {
    final result = ReloadChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  ReloadChatRequest._();

  factory ReloadChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadChatRequest()..mergeFromBuffer(data, registry);
  factory ReloadChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReloadChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ReloadChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadChatRequest copyWith(void Function(ReloadChatRequest) updates) =>
      super.copyWith((message) => updates(message as ReloadChatRequest))
          as ReloadChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReloadChatRequest() / ReloadChatRequest.new instead')
  static ReloadChatRequest create() => ReloadChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => ReloadChatRequest._();
  @$core.override
  ReloadChatRequest createEmptyInstance() => ReloadChatRequest._();
  @$core.pragma('dart2js:noInline')
  static ReloadChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReloadChatRequest>(
          ReloadChatRequest.$_createMessage);
  static ReloadChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class ReloadChatResponse extends $pb.GeneratedMessage {
  factory ReloadChatResponse() => ReloadChatResponse._();

  ReloadChatResponse._();

  factory ReloadChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadChatResponse()..mergeFromBuffer(data, registry);
  factory ReloadChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReloadChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReloadChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ReloadChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReloadChatResponse copyWith(void Function(ReloadChatResponse) updates) =>
      super.copyWith((message) => updates(message as ReloadChatResponse))
          as ReloadChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReloadChatResponse() / ReloadChatResponse.new instead')
  static ReloadChatResponse create() => ReloadChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => ReloadChatResponse._();
  @$core.override
  ReloadChatResponse createEmptyInstance() => ReloadChatResponse._();
  @$core.pragma('dart2js:noInline')
  static ReloadChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReloadChatResponse>(
          ReloadChatResponse.$_createMessage);
  static ReloadChatResponse? _defaultInstance;
}

class ContextCategory extends $pb.GeneratedMessage {
  factory ContextCategory({
    $core.String? name,
    $fixnum.Int64? tokens,
    $core.double? percent,
    $core.String? kind,
  }) {
    final result = ContextCategory._();
    if (name != null) result.name = name;
    if (tokens != null) result.tokens = tokens;
    if (percent != null) result.percent = percent;
    if (kind != null) result.kind = kind;
    return result;
  }

  ContextCategory._();

  factory ContextCategory.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContextCategory()..mergeFromBuffer(data, registry);
  factory ContextCategory.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ContextCategory()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ContextCategory',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ContextCategory.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aInt64(2, _omitFieldNames ? '' : 'tokens')
    ..aD(3, _omitFieldNames ? '' : 'percent')
    ..aOS(4, _omitFieldNames ? '' : 'kind')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContextCategory clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ContextCategory copyWith(void Function(ContextCategory) updates) =>
      super.copyWith((message) => updates(message as ContextCategory))
          as ContextCategory;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ContextCategory() / ContextCategory.new instead')
  static ContextCategory create() => ContextCategory._();
  static $pb.GeneratedMessage $_createMessage() => ContextCategory._();
  @$core.override
  ContextCategory createEmptyInstance() => ContextCategory._();
  @$core.pragma('dart2js:noInline')
  static ContextCategory getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ContextCategory>(
          ContextCategory.$_createMessage);
  static ContextCategory? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get tokens => $_getI64(1);
  @$pb.TagNumber(2)
  set tokens($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTokens() => $_has(1);
  @$pb.TagNumber(2)
  void clearTokens() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get percent => $_getN(2);
  @$pb.TagNumber(3)
  set percent($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPercent() => $_has(2);
  @$pb.TagNumber(3)
  void clearPercent() => $_clearField(3);

  /// "free" for the free space, "deferred" for what is listed but loaded
  /// only on demand (outside the context), else "".
  @$pb.TagNumber(4)
  $core.String get kind => $_getSZ(3);
  @$pb.TagNumber(4)
  set kind($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKind() => $_has(3);
  @$pb.TagNumber(4)
  void clearKind() => $_clearField(4);
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

  /// As GetDiffRequest.base.
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
    $core.String? defaultBase,
    $core.int? ahead,
  }) {
    final result = GetFolderStatusResponse._();
    if (git != null) result.git = git;
    if (branch != null) result.branch = branch;
    if (files != null) result.files = files;
    if (added != null) result.added = added;
    if (removed != null) result.removed = removed;
    if (gone != null) result.gone = gone;
    if (defaultBase != null) result.defaultBase = defaultBase;
    if (ahead != null) result.ahead = ahead;
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
    ..aOS(7, _omitFieldNames ? '' : 'defaultBase')
    ..aI(8, _omitFieldNames ? '' : 'ahead')
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

  /// The folder doesn't exist (any more); nothing else is set.
  @$pb.TagNumber(6)
  $core.bool get gone => $_getBF(5);
  @$pb.TagNumber(6)
  set gone($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasGone() => $_has(5);
  @$pb.TagNumber(6)
  void clearGone() => $_clearField(6);

  /// The branch a branch is counted from when the chat has no base of its
  /// own: origin/HEAD's branch, else main or master; "" if none.
  @$pb.TagNumber(7)
  $core.String get defaultBase => $_getSZ(6);
  @$pb.TagNumber(7)
  set defaultBase($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDefaultBase() => $_has(6);
  @$pb.TagNumber(7)
  void clearDefaultBase() => $_clearField(7);

  ///  The commits HEAD has that the base (or else default_base) lacks
  /// .
  @$pb.TagNumber(8)
  $core.int get ahead => $_getIZ(7);
  @$pb.TagNumber(8)
  set ahead($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAhead() => $_has(7);
  @$pb.TagNumber(8)
  void clearAhead() => $_clearField(8);
}

class GetDiffRequest extends $pb.GeneratedMessage {
  factory GetDiffRequest({
    $core.String? folder,
    $core.String? base,
    $core.String? commit,
    $core.String? since,
  }) {
    final result = GetDiffRequest._();
    if (folder != null) result.folder = folder;
    if (base != null) result.base = base;
    if (commit != null) result.commit = commit;
    if (since != null) result.since = since;
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
    ..aOS(3, _omitFieldNames ? '' : 'commit')
    ..aOS(4, _omitFieldNames ? '' : 'since')
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
  /// together, instead of from HEAD.
  @$pb.TagNumber(2)
  $core.String get base => $_getSZ(1);
  @$pb.TagNumber(2)
  set base($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBase() => $_has(1);
  @$pb.TagNumber(2)
  void clearBase() => $_clearField(2);

  /// A commit: what it changed, from its first parent, instead.
  @$pb.TagNumber(3)
  $core.String get commit => $_getSZ(2);
  @$pb.TagNumber(3)
  set commit($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommit() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommit() => $_clearField(3);

  /// With commit, an older commit: what the commits from it to commit
  /// changed, it included.
  @$pb.TagNumber(4)
  $core.String get since => $_getSZ(3);
  @$pb.TagNumber(4)
  set since($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSince() => $_has(3);
  @$pb.TagNumber(4)
  void clearSince() => $_clearField(4);
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
    $core.String? oldPath,
    $core.int? added,
    $core.int? removed,
  }) {
    final result = FileChange._();
    if (path != null) result.path = path;
    if (status != null) result.status = status;
    if (oldText != null) result.oldText = oldText;
    if (newText != null) result.newText = newText;
    if (skipped != null) result.skipped = skipped;
    if (oldPath != null) result.oldPath = oldPath;
    if (added != null) result.added = added;
    if (removed != null) result.removed = removed;
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
    ..aOS(6, _omitFieldNames ? '' : 'oldPath')
    ..aI(7, _omitFieldNames ? '' : 'added')
    ..aI(8, _omitFieldNames ? '' : 'removed')
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

  /// "added", "modified", "deleted", "renamed" (from old_path) or
  /// "untracked".
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

  /// A renamed file's earlier path.
  @$pb.TagNumber(6)
  $core.String get oldPath => $_getSZ(5);
  @$pb.TagNumber(6)
  set oldPath($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOldPath() => $_has(5);
  @$pb.TagNumber(6)
  void clearOldPath() => $_clearField(6);

  /// Lines added and removed; a binary file counts none.
  @$pb.TagNumber(7)
  $core.int get added => $_getIZ(6);
  @$pb.TagNumber(7)
  set added($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAdded() => $_has(6);
  @$pb.TagNumber(7)
  void clearAdded() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get removed => $_getIZ(7);
  @$pb.TagNumber(8)
  set removed($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasRemoved() => $_has(7);
  @$pb.TagNumber(8)
  void clearRemoved() => $_clearField(8);
}

class ListCommitsRequest extends $pb.GeneratedMessage {
  factory ListCommitsRequest({
    $core.String? folder,
    $core.String? base,
  }) {
    final result = ListCommitsRequest._();
    if (folder != null) result.folder = folder;
    if (base != null) result.base = base;
    return result;
  }

  ListCommitsRequest._();

  factory ListCommitsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCommitsRequest()..mergeFromBuffer(data, registry);
  factory ListCommitsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCommitsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCommitsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListCommitsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'base')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCommitsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCommitsRequest copyWith(void Function(ListCommitsRequest) updates) =>
      super.copyWith((message) => updates(message as ListCommitsRequest))
          as ListCommitsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListCommitsRequest() / ListCommitsRequest.new instead')
  static ListCommitsRequest create() => ListCommitsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListCommitsRequest._();
  @$core.override
  ListCommitsRequest createEmptyInstance() => ListCommitsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListCommitsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCommitsRequest>(
          ListCommitsRequest.$_createMessage);
  static ListCommitsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// HEAD's commits that base lacks (up to 500); without one the last 50.
  @$pb.TagNumber(2)
  $core.String get base => $_getSZ(1);
  @$pb.TagNumber(2)
  set base($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBase() => $_has(1);
  @$pb.TagNumber(2)
  void clearBase() => $_clearField(2);
}

class ListCommitsResponse extends $pb.GeneratedMessage {
  factory ListCommitsResponse({
    $core.Iterable<Commit>? commits,
  }) {
    final result = ListCommitsResponse._();
    if (commits != null) result.commits.addAll(commits);
    return result;
  }

  ListCommitsResponse._();

  factory ListCommitsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCommitsResponse()..mergeFromBuffer(data, registry);
  factory ListCommitsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListCommitsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCommitsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListCommitsResponse.$_createMessage)
    ..pPM<Commit>(1, _omitFieldNames ? '' : 'commits',
        subBuilder: Commit.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCommitsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCommitsResponse copyWith(void Function(ListCommitsResponse) updates) =>
      super.copyWith((message) => updates(message as ListCommitsResponse))
          as ListCommitsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use ListCommitsResponse() / ListCommitsResponse.new instead')
  static ListCommitsResponse create() => ListCommitsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListCommitsResponse._();
  @$core.override
  ListCommitsResponse createEmptyInstance() => ListCommitsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListCommitsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCommitsResponse>(
          ListCommitsResponse.$_createMessage);
  static ListCommitsResponse? _defaultInstance;

  /// Newest first.
  @$pb.TagNumber(1)
  $pb.PbList<Commit> get commits => $_getList(0);
}

class Commit extends $pb.GeneratedMessage {
  factory Commit({
    $core.String? hash,
    $core.String? short,
    $core.String? subject,
    $fixnum.Int64? unixSeconds,
    $core.int? added,
    $core.int? removed,
  }) {
    final result = Commit._();
    if (hash != null) result.hash = hash;
    if (short != null) result.short = short;
    if (subject != null) result.subject = subject;
    if (unixSeconds != null) result.unixSeconds = unixSeconds;
    if (added != null) result.added = added;
    if (removed != null) result.removed = removed;
    return result;
  }

  Commit._();

  factory Commit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Commit()..mergeFromBuffer(data, registry);
  factory Commit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Commit()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Commit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Commit.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'hash')
    ..aOS(2, _omitFieldNames ? '' : 'short')
    ..aOS(3, _omitFieldNames ? '' : 'subject')
    ..aInt64(4, _omitFieldNames ? '' : 'unixSeconds')
    ..aI(5, _omitFieldNames ? '' : 'added')
    ..aI(6, _omitFieldNames ? '' : 'removed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Commit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Commit copyWith(void Function(Commit) updates) =>
      super.copyWith((message) => updates(message as Commit)) as Commit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Commit() / Commit.new instead')
  static Commit create() => Commit._();
  static $pb.GeneratedMessage $_createMessage() => Commit._();
  @$core.override
  Commit createEmptyInstance() => Commit._();
  @$core.pragma('dart2js:noInline')
  static Commit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Commit>(Commit.$_createMessage);
  static Commit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get hash => $_getSZ(0);
  @$pb.TagNumber(1)
  set hash($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHash() => $_has(0);
  @$pb.TagNumber(1)
  void clearHash() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get short => $_getSZ(1);
  @$pb.TagNumber(2)
  set short($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasShort() => $_has(1);
  @$pb.TagNumber(2)
  void clearShort() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get subject => $_getSZ(2);
  @$pb.TagNumber(3)
  set subject($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSubject() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubject() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get unixSeconds => $_getI64(3);
  @$pb.TagNumber(4)
  set unixSeconds($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUnixSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearUnixSeconds() => $_clearField(4);

  /// Lines added and removed in the folder.
  @$pb.TagNumber(5)
  $core.int get added => $_getIZ(4);
  @$pb.TagNumber(5)
  set added($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAdded() => $_has(4);
  @$pb.TagNumber(5)
  void clearAdded() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get removed => $_getIZ(5);
  @$pb.TagNumber(6)
  set removed($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasRemoved() => $_has(5);
  @$pb.TagNumber(6)
  void clearRemoved() => $_clearField(6);
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
  queue,
  cut,
  terminals,
  dropped,
  remote,
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
    ChatQueue? queue,
    $core.String? cut,
    ChatTerminals? terminals,
    $core.String? dropped,
    Remote? remote,
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
    if (queue != null) result.queue = queue;
    if (cut != null) result.cut = cut;
    if (terminals != null) result.terminals = terminals;
    if (dropped != null) result.dropped = dropped;
    if (remote != null) result.remote = remote;
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
    10: EventsResponse_Kind.queue,
    11: EventsResponse_Kind.cut,
    12: EventsResponse_Kind.terminals,
    13: EventsResponse_Kind.dropped,
    14: EventsResponse_Kind.remote,
    0: EventsResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EventsResponse.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14])
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
    ..aOM<ChatQueue>(10, _omitFieldNames ? '' : 'queue',
        subBuilder: ChatQueue.$_createMessage)
    ..aOS(11, _omitFieldNames ? '' : 'cut')
    ..aOM<ChatTerminals>(12, _omitFieldNames ? '' : 'terminals',
        subBuilder: ChatTerminals.$_createMessage)
    ..aOS(13, _omitFieldNames ? '' : 'dropped')
    ..aOM<Remote>(14, _omitFieldNames ? '' : 'remote',
        subBuilder: Remote.$_createMessage)
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
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
  EventsResponse_Kind whichKind() =>
      _EventsResponse_KindByTag[$_whichOneof(0)]!;
  @$pb.TagNumber(2)
  @$pb.TagNumber(3)
  @$pb.TagNumber(4)
  @$pb.TagNumber(5)
  @$pb.TagNumber(7)
  @$pb.TagNumber(8)
  @$pb.TagNumber(9)
  @$pb.TagNumber(10)
  @$pb.TagNumber(11)
  @$pb.TagNumber(12)
  @$pb.TagNumber(13)
  @$pb.TagNumber(14)
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

  /// The chat was deleted (DeleteChat).
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

  /// The messages waiting for the agent, all of them.
  @$pb.TagNumber(10)
  ChatQueue get queue => $_getN(9);
  @$pb.TagNumber(10)
  set queue(ChatQueue value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasQueue() => $_has(9);
  @$pb.TagNumber(10)
  void clearQueue() => $_clearField(10);
  @$pb.TagNumber(10)
  ChatQueue ensureQueue() => $_ensure(9);

  /// The transcript was cut back: this item and every one after it are
  /// gone.
  @$pb.TagNumber(11)
  $core.String get cut => $_getSZ(10);
  @$pb.TagNumber(11)
  set cut($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCut() => $_has(10);
  @$pb.TagNumber(11)
  void clearCut() => $_clearField(11);

  /// The chat's terminals, all of them, in order; these events have no
  /// seq.
  @$pb.TagNumber(12)
  ChatTerminals get terminals => $_getN(11);
  @$pb.TagNumber(12)
  set terminals(ChatTerminals value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasTerminals() => $_has(11);
  @$pb.TagNumber(12)
  void clearTerminals() => $_clearField(12);
  @$pb.TagNumber(12)
  ChatTerminals ensureTerminals() => $_ensure(11);

  /// This item is gone (a message the agent never got); the rest stay.
  @$pb.TagNumber(13)
  $core.String get dropped => $_getSZ(12);
  @$pb.TagNumber(13)
  set dropped($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasDropped() => $_has(12);
  @$pb.TagNumber(13)
  void clearDropped() => $_clearField(13);

  /// Remote access changed (chat_id is empty).
  @$pb.TagNumber(14)
  Remote get remote => $_getN(13);
  @$pb.TagNumber(14)
  set remote(Remote value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasRemote() => $_has(13);
  @$pb.TagNumber(14)
  void clearRemote() => $_clearField(14);
  @$pb.TagNumber(14)
  Remote ensureRemote() => $_ensure(13);
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
    $core.bool? isDefault,
  }) {
    final result = ConfigValue._();
    if (value != null) result.value = value;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (group != null) result.group = group;
    if (isDefault != null) result.isDefault = isDefault;
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
    ..aOB(5, _omitFieldNames ? '' : 'isDefault')
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

  /// The agent's "use the default" choice (Claude's "Default (recommended)"
  /// model), rather than one value of its own.
  @$pb.TagNumber(5)
  $core.bool get isDefault => $_getBF(4);
  @$pb.TagNumber(5)
  set isDefault($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIsDefault() => $_has(4);
  @$pb.TagNumber(5)
  void clearIsDefault() => $_clearField(5);
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
    $core.String? forkAt,
    $core.bool? rewindable,
    Subagent? subagent,
    $core.bool? report,
    $core.String? prompt,
    $core.String? model,
    $core.String? effort,
    $core.String? ranModel,
    Shell? shell,
    $core.String? agentId,
    $core.String? relayTo,
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
    if (forkAt != null) result.forkAt = forkAt;
    if (rewindable != null) result.rewindable = rewindable;
    if (subagent != null) result.subagent = subagent;
    if (report != null) result.report = report;
    if (prompt != null) result.prompt = prompt;
    if (model != null) result.model = model;
    if (effort != null) result.effort = effort;
    if (ranModel != null) result.ranModel = ranModel;
    if (shell != null) result.shell = shell;
    if (agentId != null) result.agentId = agentId;
    if (relayTo != null) result.relayTo = relayTo;
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
    ..aOS(17, _omitFieldNames ? '' : 'forkAt')
    ..aOB(18, _omitFieldNames ? '' : 'rewindable')
    ..aOM<Subagent>(19, _omitFieldNames ? '' : 'subagent',
        subBuilder: Subagent.$_createMessage)
    ..aOB(20, _omitFieldNames ? '' : 'report')
    ..aOS(21, _omitFieldNames ? '' : 'prompt')
    ..aOS(22, _omitFieldNames ? '' : 'model')
    ..aOS(23, _omitFieldNames ? '' : 'effort')
    ..aOS(24, _omitFieldNames ? '' : 'ranModel')
    ..aOM<Shell>(25, _omitFieldNames ? '' : 'shell',
        subBuilder: Shell.$_createMessage)
    ..aOS(26, _omitFieldNames ? '' : 'agentId')
    ..aOS(27, _omitFieldNames ? '' : 'relayTo')
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

  /// The tool call whose subagent made this item, if one did.
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

  /// For a user message: the agent's message the conversation before it
  /// ends with, where a rewind to it forks the session.
  @$pb.TagNumber(17)
  $core.String get forkAt => $_getSZ(16);
  @$pb.TagNumber(17)
  set forkAt($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasForkAt() => $_has(16);
  @$pb.TagNumber(17)
  void clearForkAt() => $_clearField(17);

  /// For a user message: the chat can be rewound to just before it while
  /// status.can_rewind and the chat is idle.
  @$pb.TagNumber(18)
  $core.bool get rewindable => $_getBF(17);
  @$pb.TagNumber(18)
  set rewindable($core.bool value) => $_setBool(17, value);
  @$pb.TagNumber(18)
  $core.bool hasRewindable() => $_has(17);
  @$pb.TagNumber(18)
  void clearRewindable() => $_clearField(18);

  /// For a tool call that starts a subagent: how the subagent goes.
  @$pb.TagNumber(19)
  Subagent get subagent => $_getN(18);
  @$pb.TagNumber(19)
  set subagent(Subagent value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasSubagent() => $_has(18);
  @$pb.TagNumber(19)
  void clearSubagent() => $_clearField(19);
  @$pb.TagNumber(19)
  Subagent ensureSubagent() => $_ensure(18);

  /// The tool call is a subagent's report to the chat (Claude's
  /// SubagentHandback): its subagent's result, not one of its steps.
  @$pb.TagNumber(20)
  $core.bool get report => $_getBF(19);
  @$pb.TagNumber(20)
  set report($core.bool value) => $_setBool(19, value);
  @$pb.TagNumber(20)
  $core.bool hasReport() => $_has(19);
  @$pb.TagNumber(20)
  void clearReport() => $_clearField(20);

  /// For a tool call that starts a subagent: the task it was given, the
  /// model and effort it was asked to use (the config option values, "" when
  /// it uses the chat's), and the model it ran on (a name to show), once the
  /// agent says.
  @$pb.TagNumber(21)
  $core.String get prompt => $_getSZ(20);
  @$pb.TagNumber(21)
  set prompt($core.String value) => $_setString(20, value);
  @$pb.TagNumber(21)
  $core.bool hasPrompt() => $_has(20);
  @$pb.TagNumber(21)
  void clearPrompt() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.String get model => $_getSZ(21);
  @$pb.TagNumber(22)
  set model($core.String value) => $_setString(21, value);
  @$pb.TagNumber(22)
  $core.bool hasModel() => $_has(21);
  @$pb.TagNumber(22)
  void clearModel() => $_clearField(22);

  @$pb.TagNumber(23)
  $core.String get effort => $_getSZ(22);
  @$pb.TagNumber(23)
  set effort($core.String value) => $_setString(22, value);
  @$pb.TagNumber(23)
  $core.bool hasEffort() => $_has(22);
  @$pb.TagNumber(23)
  void clearEffort() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.String get ranModel => $_getSZ(23);
  @$pb.TagNumber(24)
  set ranModel($core.String value) => $_setString(23, value);
  @$pb.TagNumber(24)
  $core.bool hasRanModel() => $_has(23);
  @$pb.TagNumber(24)
  void clearRanModel() => $_clearField(24);

  /// For a tool call that left its command running in the background.
  @$pb.TagNumber(25)
  Shell get shell => $_getN(24);
  @$pb.TagNumber(25)
  set shell(Shell value) => $_setField(25, value);
  @$pb.TagNumber(25)
  $core.bool hasShell() => $_has(24);
  @$pb.TagNumber(25)
  void clearShell() => $_clearField(25);
  @$pb.TagNumber(25)
  Shell ensureShell() => $_ensure(24);

  /// For a tool call that starts a subagent: the agent's id for it, when the
  /// agent can pass it messages (SendPromptRequest.to_subagent).
  @$pb.TagNumber(26)
  $core.String get agentId => $_getSZ(25);
  @$pb.TagNumber(26)
  set agentId($core.String value) => $_setString(25, value);
  @$pb.TagNumber(26)
  $core.bool hasAgentId() => $_has(25);
  @$pb.TagNumber(26)
  void clearAgentId() => $_clearField(26);

  /// For a user message: the type of the subagent the agent was asked to
  /// pass it to.
  @$pb.TagNumber(27)
  $core.String get relayTo => $_getSZ(26);
  @$pb.TagNumber(27)
  set relayTo($core.String value) => $_setString(26, value);
  @$pb.TagNumber(27)
  $core.bool hasRelayTo() => $_has(26);
  @$pb.TagNumber(27)
  void clearRelayTo() => $_clearField(27);
}

/// A command the agent runs in the background.
class Shell extends $pb.GeneratedMessage {
  factory Shell({
    $core.String? id,
    $core.String? state,
    $fixnum.Int64? started,
    $fixnum.Int64? ended,
    $core.String? output,
    $core.String? end,
  }) {
    final result = Shell._();
    if (id != null) result.id = id;
    if (state != null) result.state = state;
    if (started != null) result.started = started;
    if (ended != null) result.ended = ended;
    if (output != null) result.output = output;
    if (end != null) result.end = end;
    return result;
  }

  Shell._();

  factory Shell.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Shell()..mergeFromBuffer(data, registry);
  factory Shell.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Shell()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Shell',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Shell.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'state')
    ..aInt64(3, _omitFieldNames ? '' : 'started')
    ..aInt64(4, _omitFieldNames ? '' : 'ended')
    ..aOS(5, _omitFieldNames ? '' : 'output')
    ..aOS(6, _omitFieldNames ? '' : 'end')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Shell clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Shell copyWith(void Function(Shell) updates) =>
      super.copyWith((message) => updates(message as Shell)) as Shell;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Shell() / Shell.new instead')
  static Shell create() => Shell._();
  static $pb.GeneratedMessage $_createMessage() => Shell._();
  @$core.override
  Shell createEmptyInstance() => Shell._();
  @$core.pragma('dart2js:noInline')
  static Shell getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Shell>(Shell.$_createMessage);
  static Shell? _defaultInstance;

  /// The agent's id for it.
  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  /// "running" while the daemon sees it run, then "done", "failed" or
  /// "stopped"; "started" when its end can't be known.
  @$pb.TagNumber(2)
  $core.String get state => $_getSZ(1);
  @$pb.TagNumber(2)
  set state($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);

  /// When the daemon saw it start, and end, in Unix milliseconds; 0 when it
  /// didn't.
  @$pb.TagNumber(3)
  $fixnum.Int64 get started => $_getI64(2);
  @$pb.TagNumber(3)
  set started($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStarted() => $_has(2);
  @$pb.TagNumber(3)
  void clearStarted() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get ended => $_getI64(3);
  @$pb.TagNumber(4)
  set ended($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEnded() => $_has(3);
  @$pb.TagNumber(4)
  void clearEnded() => $_clearField(4);

  /// What it wrote so far (the end of it), and how it ended, in the agent's
  /// words ("exited with code 0").
  @$pb.TagNumber(5)
  $core.String get output => $_getSZ(4);
  @$pb.TagNumber(5)
  set output($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOutput() => $_has(4);
  @$pb.TagNumber(5)
  void clearOutput() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get end => $_getSZ(5);
  @$pb.TagNumber(6)
  set end($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEnd() => $_has(5);
  @$pb.TagNumber(6)
  void clearEnd() => $_clearField(6);
}

/// How a subagent goes.
class Subagent extends $pb.GeneratedMessage {
  factory Subagent({
    $core.String? state,
    $fixnum.Int64? started,
    $fixnum.Int64? ended,
    $core.String? result,
  }) {
    final result$ = Subagent._();
    if (state != null) result$.state = state;
    if (started != null) result$.started = started;
    if (ended != null) result$.ended = ended;
    if (result != null) result$.result = result;
    return result$;
  }

  Subagent._();

  factory Subagent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subagent()..mergeFromBuffer(data, registry);
  factory Subagent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Subagent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subagent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Subagent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'state')
    ..aInt64(2, _omitFieldNames ? '' : 'started')
    ..aInt64(3, _omitFieldNames ? '' : 'ended')
    ..aOS(4, _omitFieldNames ? '' : 'result')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subagent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subagent copyWith(void Function(Subagent) updates) =>
      super.copyWith((message) => updates(message as Subagent)) as Subagent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Subagent() / Subagent.new instead')
  static Subagent create() => Subagent._();
  static $pb.GeneratedMessage $_createMessage() => Subagent._();
  @$core.override
  Subagent createEmptyInstance() => Subagent._();
  @$core.pragma('dart2js:noInline')
  static Subagent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Subagent>(Subagent.$_createMessage);
  static Subagent? _defaultInstance;

  /// "running", "done" or "failed".
  @$pb.TagNumber(1)
  $core.String get state => $_getSZ(0);
  @$pb.TagNumber(1)
  set state($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasState() => $_has(0);
  @$pb.TagNumber(1)
  void clearState() => $_clearField(1);

  /// When the daemon saw it start, and end, in Unix milliseconds; 0 when it
  /// didn't (a replayed chat).
  @$pb.TagNumber(2)
  $fixnum.Int64 get started => $_getI64(1);
  @$pb.TagNumber(2)
  set started($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStarted() => $_has(1);
  @$pb.TagNumber(2)
  void clearStarted() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get ended => $_getI64(2);
  @$pb.TagNumber(3)
  set ended($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEnded() => $_has(2);
  @$pb.TagNumber(3)
  void clearEnded() => $_clearField(3);

  /// What it found, once it has ended: its report, or its call's output.
  @$pb.TagNumber(4)
  $core.String get result => $_getSZ(3);
  @$pb.TagNumber(4)
  set result($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResult() => $_has(3);
  @$pb.TagNumber(4)
  void clearResult() => $_clearField(4);
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
    $core.String? otherFor,
  }) {
    final result = Field._();
    if (id != null) result.id = id;
    if (title != null) result.title = title;
    if (description != null) result.description = description;
    if (type != null) result.type = type;
    if (options != null) result.options.addAll(options);
    if (required != null) result.required = required;
    if (values != null) result.values.addAll(values);
    if (otherFor != null) result.otherFor = otherFor;
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
    ..aOS(8, _omitFieldNames ? '' : 'otherFor')
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

  /// For a free-text field that is another field's "Other" answer: that
  /// field's id.
  @$pb.TagNumber(8)
  $core.String get otherFor => $_getSZ(7);
  @$pb.TagNumber(8)
  set otherFor($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOtherFor() => $_has(7);
  @$pb.TagNumber(8)
  void clearOtherFor() => $_clearField(8);
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
    $fixnum.Int64? started,
    $core.bool? waiting,
    $core.bool? canFork,
    $core.bool? images,
    $core.bool? canRewind,
    $core.bool? mcpChanged,
    $core.bool? canAskContext,
    $core.bool? asleep,
    $core.bool? canSleep,
  }) {
    final result = ChatStatus._();
    if (busy != null) result.busy = busy;
    if (started != null) result.started = started;
    if (waiting != null) result.waiting = waiting;
    if (canFork != null) result.canFork = canFork;
    if (images != null) result.images = images;
    if (canRewind != null) result.canRewind = canRewind;
    if (mcpChanged != null) result.mcpChanged = mcpChanged;
    if (canAskContext != null) result.canAskContext = canAskContext;
    if (asleep != null) result.asleep = asleep;
    if (canSleep != null) result.canSleep = canSleep;
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
    ..aInt64(3, _omitFieldNames ? '' : 'started')
    ..aOB(4, _omitFieldNames ? '' : 'waiting')
    ..aOB(5, _omitFieldNames ? '' : 'canFork')
    ..aOB(6, _omitFieldNames ? '' : 'images')
    ..aOB(7, _omitFieldNames ? '' : 'canRewind')
    ..aOB(8, _omitFieldNames ? '' : 'mcpChanged')
    ..aOB(9, _omitFieldNames ? '' : 'canAskContext')
    ..aOB(10, _omitFieldNames ? '' : 'asleep')
    ..aOB(11, _omitFieldNames ? '' : 'canSleep')
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

  /// When the running turn started, in Unix milliseconds; 0 when idle.
  @$pb.TagNumber(3)
  $fixnum.Int64 get started => $_getI64(1);
  @$pb.TagNumber(3)
  set started($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(3)
  $core.bool hasStarted() => $_has(1);
  @$pb.TagNumber(3)
  void clearStarted() => $_clearField(3);

  /// The agent waits on the user: a permission prompt or a question.
  @$pb.TagNumber(4)
  $core.bool get waiting => $_getBF(2);
  @$pb.TagNumber(4)
  set waiting($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(4)
  $core.bool hasWaiting() => $_has(2);
  @$pb.TagNumber(4)
  void clearWaiting() => $_clearField(4);

  /// The agent can fork the chat (ForkChat).
  @$pb.TagNumber(5)
  $core.bool get canFork => $_getBF(3);
  @$pb.TagNumber(5)
  set canFork($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(5)
  $core.bool hasCanFork() => $_has(3);
  @$pb.TagNumber(5)
  void clearCanFork() => $_clearField(5);

  /// The agent takes images in prompts.
  @$pb.TagNumber(6)
  $core.bool get images => $_getBF(4);
  @$pb.TagNumber(6)
  set images($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(6)
  $core.bool hasImages() => $_has(4);
  @$pb.TagNumber(6)
  void clearImages() => $_clearField(6);

  /// The agent can rewind the chat to a user message (RewindChat).
  @$pb.TagNumber(7)
  $core.bool get canRewind => $_getBF(5);
  @$pb.TagNumber(7)
  set canRewind($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(7)
  $core.bool hasCanRewind() => $_has(5);
  @$pb.TagNumber(7)
  void clearCanRewind() => $_clearField(7);

  ///  MCP servers changed since the agent started; ReloadChat picks them up
  /// .
  @$pb.TagNumber(8)
  $core.bool get mcpChanged => $_getBF(6);
  @$pb.TagNumber(8)
  set mcpChanged($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(8)
  $core.bool hasMcpChanged() => $_has(6);
  @$pb.TagNumber(8)
  void clearMcpChanged() => $_clearField(8);

  /// GetContextUsage can ask the agent what fills its context, once the
  /// chat is idle.
  @$pb.TagNumber(9)
  $core.bool get canAskContext => $_getBF(7);
  @$pb.TagNumber(9)
  set canAskContext($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(9)
  $core.bool hasCanAskContext() => $_has(7);
  @$pb.TagNumber(9)
  void clearCanAskContext() => $_clearField(9);

  /// No agent runs for the chat: it sleeps (SleepChat), or wasn't opened
  /// since the daemon started. Never said of an archived chat.
  @$pb.TagNumber(10)
  $core.bool get asleep => $_getBF(8);
  @$pb.TagNumber(10)
  set asleep($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(10)
  $core.bool hasAsleep() => $_has(8);
  @$pb.TagNumber(10)
  void clearAsleep() => $_clearField(10);

  /// SleepChat can put it to sleep: its agent runs and can reopen the
  /// session.
  @$pb.TagNumber(11)
  $core.bool get canSleep => $_getBF(9);
  @$pb.TagNumber(11)
  set canSleep($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(11)
  $core.bool hasCanSleep() => $_has(9);
  @$pb.TagNumber(11)
  void clearCanSleep() => $_clearField(11);
}

/// A shell the user runs beside a chat, in the daemon.
class Terminal extends $pb.GeneratedMessage {
  factory Terminal({
    $core.String? id,
    $core.String? chatId,
    $core.String? folder,
    $core.String? shell,
    $core.String? program,
    $core.bool? exited,
    $core.int? exitCode,
    $core.String? name,
  }) {
    final result = Terminal._();
    if (id != null) result.id = id;
    if (chatId != null) result.chatId = chatId;
    if (folder != null) result.folder = folder;
    if (shell != null) result.shell = shell;
    if (program != null) result.program = program;
    if (exited != null) result.exited = exited;
    if (exitCode != null) result.exitCode = exitCode;
    if (name != null) result.name = name;
    return result;
  }

  Terminal._();

  factory Terminal.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Terminal()..mergeFromBuffer(data, registry);
  factory Terminal.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Terminal()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Terminal',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Terminal.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'chatId')
    ..aOS(3, _omitFieldNames ? '' : 'folder')
    ..aOS(5, _omitFieldNames ? '' : 'shell')
    ..aOS(6, _omitFieldNames ? '' : 'program')
    ..aOB(7, _omitFieldNames ? '' : 'exited')
    ..aI(8, _omitFieldNames ? '' : 'exitCode')
    ..aOS(9, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Terminal clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Terminal copyWith(void Function(Terminal) updates) =>
      super.copyWith((message) => updates(message as Terminal)) as Terminal;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Terminal() / Terminal.new instead')
  static Terminal create() => Terminal._();
  static $pb.GeneratedMessage $_createMessage() => Terminal._();
  @$core.override
  Terminal createEmptyInstance() => Terminal._();
  @$core.pragma('dart2js:noInline')
  static Terminal getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Terminal>(Terminal.$_createMessage);
  static Terminal? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get chatId => $_getSZ(1);
  @$pb.TagNumber(2)
  set chatId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasChatId() => $_has(1);
  @$pb.TagNumber(2)
  void clearChatId() => $_clearField(2);

  /// Where it started.
  @$pb.TagNumber(3)
  $core.String get folder => $_getSZ(2);
  @$pb.TagNumber(3)
  set folder($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFolder() => $_has(2);
  @$pb.TagNumber(3)
  void clearFolder() => $_clearField(3);

  /// The shell's name, such as "zsh".
  @$pb.TagNumber(5)
  $core.String get shell => $_getSZ(3);
  @$pb.TagNumber(5)
  set shell($core.String value) => $_setString(3, value);
  @$pb.TagNumber(5)
  $core.bool hasShell() => $_has(3);
  @$pb.TagNumber(5)
  void clearShell() => $_clearField(5);

  /// The foreground program's command line while it isn't the shell.
  @$pb.TagNumber(6)
  $core.String get program => $_getSZ(4);
  @$pb.TagNumber(6)
  set program($core.String value) => $_setString(4, value);
  @$pb.TagNumber(6)
  $core.bool hasProgram() => $_has(4);
  @$pb.TagNumber(6)
  void clearProgram() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get exited => $_getBF(5);
  @$pb.TagNumber(7)
  set exited($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(7)
  $core.bool hasExited() => $_has(5);
  @$pb.TagNumber(7)
  void clearExited() => $_clearField(7);

  /// -1: killed by a signal.
  @$pb.TagNumber(8)
  $core.int get exitCode => $_getIZ(6);
  @$pb.TagNumber(8)
  set exitCode($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(8)
  $core.bool hasExitCode() => $_has(6);
  @$pb.TagNumber(8)
  void clearExitCode() => $_clearField(8);

  /// The name the user gave it, if any.
  @$pb.TagNumber(9)
  $core.String get name => $_getSZ(7);
  @$pb.TagNumber(9)
  set name($core.String value) => $_setString(7, value);
  @$pb.TagNumber(9)
  $core.bool hasName() => $_has(7);
  @$pb.TagNumber(9)
  void clearName() => $_clearField(9);
}

class ChatTerminals extends $pb.GeneratedMessage {
  factory ChatTerminals({
    $core.Iterable<Terminal>? terminals,
  }) {
    final result = ChatTerminals._();
    if (terminals != null) result.terminals.addAll(terminals);
    return result;
  }

  ChatTerminals._();

  factory ChatTerminals.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatTerminals()..mergeFromBuffer(data, registry);
  factory ChatTerminals.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ChatTerminals()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ChatTerminals',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ChatTerminals.$_createMessage)
    ..pPM<Terminal>(1, _omitFieldNames ? '' : 'terminals',
        subBuilder: Terminal.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatTerminals clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ChatTerminals copyWith(void Function(ChatTerminals) updates) =>
      super.copyWith((message) => updates(message as ChatTerminals))
          as ChatTerminals;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ChatTerminals() / ChatTerminals.new instead')
  static ChatTerminals create() => ChatTerminals._();
  static $pb.GeneratedMessage $_createMessage() => ChatTerminals._();
  @$core.override
  ChatTerminals createEmptyInstance() => ChatTerminals._();
  @$core.pragma('dart2js:noInline')
  static ChatTerminals getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ChatTerminals>(
          ChatTerminals.$_createMessage);
  static ChatTerminals? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Terminal> get terminals => $_getList(0);
}

class OpenTerminalRequest extends $pb.GeneratedMessage {
  factory OpenTerminalRequest({
    $core.String? chatId,
    $core.String? folder,
    $core.int? cols,
    $core.int? rows,
  }) {
    final result = OpenTerminalRequest._();
    if (chatId != null) result.chatId = chatId;
    if (folder != null) result.folder = folder;
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    return result;
  }

  OpenTerminalRequest._();

  factory OpenTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenTerminalRequest()..mergeFromBuffer(data, registry);
  factory OpenTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: OpenTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'folder')
    ..aI(3, _omitFieldNames ? '' : 'cols')
    ..aI(4, _omitFieldNames ? '' : 'rows')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenTerminalRequest copyWith(void Function(OpenTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as OpenTerminalRequest))
          as OpenTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use OpenTerminalRequest() / OpenTerminalRequest.new instead')
  static OpenTerminalRequest create() => OpenTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => OpenTerminalRequest._();
  @$core.override
  OpenTerminalRequest createEmptyInstance() => OpenTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static OpenTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenTerminalRequest>(
          OpenTerminalRequest.$_createMessage);
  static OpenTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  /// Empty: the chat's folder.
  @$pb.TagNumber(2)
  $core.String get folder => $_getSZ(1);
  @$pb.TagNumber(2)
  set folder($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFolder() => $_has(1);
  @$pb.TagNumber(2)
  void clearFolder() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get cols => $_getIZ(2);
  @$pb.TagNumber(3)
  set cols($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCols() => $_has(2);
  @$pb.TagNumber(3)
  void clearCols() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get rows => $_getIZ(3);
  @$pb.TagNumber(4)
  set rows($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRows() => $_has(3);
  @$pb.TagNumber(4)
  void clearRows() => $_clearField(4);
}

class OpenTerminalResponse extends $pb.GeneratedMessage {
  factory OpenTerminalResponse({
    Terminal? terminal,
  }) {
    final result = OpenTerminalResponse._();
    if (terminal != null) result.terminal = terminal;
    return result;
  }

  OpenTerminalResponse._();

  factory OpenTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenTerminalResponse()..mergeFromBuffer(data, registry);
  factory OpenTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: OpenTerminalResponse.$_createMessage)
    ..aOM<Terminal>(1, _omitFieldNames ? '' : 'terminal',
        subBuilder: Terminal.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenTerminalResponse copyWith(void Function(OpenTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as OpenTerminalResponse))
          as OpenTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use OpenTerminalResponse() / OpenTerminalResponse.new instead')
  static OpenTerminalResponse create() => OpenTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => OpenTerminalResponse._();
  @$core.override
  OpenTerminalResponse createEmptyInstance() => OpenTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static OpenTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenTerminalResponse>(
          OpenTerminalResponse.$_createMessage);
  static OpenTerminalResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Terminal get terminal => $_getN(0);
  @$pb.TagNumber(1)
  set terminal(Terminal value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminal() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminal() => $_clearField(1);
  @$pb.TagNumber(1)
  Terminal ensureTerminal() => $_ensure(0);
}

class ListTerminalsRequest extends $pb.GeneratedMessage {
  factory ListTerminalsRequest({
    $core.String? chatId,
  }) {
    final result = ListTerminalsRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  ListTerminalsRequest._();

  factory ListTerminalsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTerminalsRequest()..mergeFromBuffer(data, registry);
  factory ListTerminalsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTerminalsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTerminalsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListTerminalsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTerminalsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTerminalsRequest copyWith(void Function(ListTerminalsRequest) updates) =>
      super.copyWith((message) => updates(message as ListTerminalsRequest))
          as ListTerminalsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListTerminalsRequest() / ListTerminalsRequest.new instead')
  static ListTerminalsRequest create() => ListTerminalsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListTerminalsRequest._();
  @$core.override
  ListTerminalsRequest createEmptyInstance() => ListTerminalsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListTerminalsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTerminalsRequest>(
          ListTerminalsRequest.$_createMessage);
  static ListTerminalsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class ListTerminalsResponse extends $pb.GeneratedMessage {
  factory ListTerminalsResponse({
    $core.Iterable<Terminal>? terminals,
  }) {
    final result = ListTerminalsResponse._();
    if (terminals != null) result.terminals.addAll(terminals);
    return result;
  }

  ListTerminalsResponse._();

  factory ListTerminalsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTerminalsResponse()..mergeFromBuffer(data, registry);
  factory ListTerminalsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTerminalsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTerminalsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListTerminalsResponse.$_createMessage)
    ..pPM<Terminal>(1, _omitFieldNames ? '' : 'terminals',
        subBuilder: Terminal.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTerminalsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTerminalsResponse copyWith(
          void Function(ListTerminalsResponse) updates) =>
      super.copyWith((message) => updates(message as ListTerminalsResponse))
          as ListTerminalsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListTerminalsResponse() / ListTerminalsResponse.new instead')
  static ListTerminalsResponse create() => ListTerminalsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListTerminalsResponse._();
  @$core.override
  ListTerminalsResponse createEmptyInstance() => ListTerminalsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListTerminalsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTerminalsResponse>(
          ListTerminalsResponse.$_createMessage);
  static ListTerminalsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Terminal> get terminals => $_getList(0);
}

class AttachTerminalRequest extends $pb.GeneratedMessage {
  factory AttachTerminalRequest({
    $core.String? terminalId,
  }) {
    final result = AttachTerminalRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    return result;
  }

  AttachTerminalRequest._();

  factory AttachTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachTerminalRequest()..mergeFromBuffer(data, registry);
  factory AttachTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AttachTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachTerminalRequest copyWith(
          void Function(AttachTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as AttachTerminalRequest))
          as AttachTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AttachTerminalRequest() / AttachTerminalRequest.new instead')
  static AttachTerminalRequest create() => AttachTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => AttachTerminalRequest._();
  @$core.override
  AttachTerminalRequest createEmptyInstance() => AttachTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static AttachTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttachTerminalRequest>(
          AttachTerminalRequest.$_createMessage);
  static AttachTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);
}

class AttachTerminalResponse extends $pb.GeneratedMessage {
  factory AttachTerminalResponse({
    $core.List<$core.int>? data,
    $core.bool? exited,
    $core.int? exitCode,
  }) {
    final result = AttachTerminalResponse._();
    if (data != null) result.data = data;
    if (exited != null) result.exited = exited;
    if (exitCode != null) result.exitCode = exitCode;
    return result;
  }

  AttachTerminalResponse._();

  factory AttachTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachTerminalResponse()..mergeFromBuffer(data, registry);
  factory AttachTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AttachTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AttachTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AttachTerminalResponse.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOB(2, _omitFieldNames ? '' : 'exited')
    ..aI(3, _omitFieldNames ? '' : 'exitCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AttachTerminalResponse copyWith(
          void Function(AttachTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as AttachTerminalResponse))
          as AttachTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AttachTerminalResponse() / AttachTerminalResponse.new instead')
  static AttachTerminalResponse create() => AttachTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => AttachTerminalResponse._();
  @$core.override
  AttachTerminalResponse createEmptyInstance() => AttachTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static AttachTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AttachTerminalResponse>(
          AttachTerminalResponse.$_createMessage);
  static AttachTerminalResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  /// The shell has exited; this is the last message.
  @$pb.TagNumber(2)
  $core.bool get exited => $_getBF(1);
  @$pb.TagNumber(2)
  set exited($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExited() => $_has(1);
  @$pb.TagNumber(2)
  void clearExited() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get exitCode => $_getIZ(2);
  @$pb.TagNumber(3)
  set exitCode($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExitCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearExitCode() => $_clearField(3);
}

class WriteTerminalRequest extends $pb.GeneratedMessage {
  factory WriteTerminalRequest({
    $core.String? terminalId,
    $core.List<$core.int>? data,
  }) {
    final result = WriteTerminalRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    if (data != null) result.data = data;
    return result;
  }

  WriteTerminalRequest._();

  factory WriteTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteTerminalRequest()..mergeFromBuffer(data, registry);
  factory WriteTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: WriteTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteTerminalRequest copyWith(void Function(WriteTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as WriteTerminalRequest))
          as WriteTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use WriteTerminalRequest() / WriteTerminalRequest.new instead')
  static WriteTerminalRequest create() => WriteTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => WriteTerminalRequest._();
  @$core.override
  WriteTerminalRequest createEmptyInstance() => WriteTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static WriteTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WriteTerminalRequest>(
          WriteTerminalRequest.$_createMessage);
  static WriteTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get data => $_getN(1);
  @$pb.TagNumber(2)
  set data($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasData() => $_has(1);
  @$pb.TagNumber(2)
  void clearData() => $_clearField(2);
}

class WriteTerminalResponse extends $pb.GeneratedMessage {
  factory WriteTerminalResponse() => WriteTerminalResponse._();

  WriteTerminalResponse._();

  factory WriteTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteTerminalResponse()..mergeFromBuffer(data, registry);
  factory WriteTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      WriteTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'WriteTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: WriteTerminalResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  WriteTerminalResponse copyWith(
          void Function(WriteTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as WriteTerminalResponse))
          as WriteTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use WriteTerminalResponse() / WriteTerminalResponse.new instead')
  static WriteTerminalResponse create() => WriteTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => WriteTerminalResponse._();
  @$core.override
  WriteTerminalResponse createEmptyInstance() => WriteTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static WriteTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<WriteTerminalResponse>(
          WriteTerminalResponse.$_createMessage);
  static WriteTerminalResponse? _defaultInstance;
}

class ResizeTerminalRequest extends $pb.GeneratedMessage {
  factory ResizeTerminalRequest({
    $core.String? terminalId,
    $core.int? cols,
    $core.int? rows,
  }) {
    final result = ResizeTerminalRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    return result;
  }

  ResizeTerminalRequest._();

  factory ResizeTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResizeTerminalRequest()..mergeFromBuffer(data, registry);
  factory ResizeTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResizeTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResizeTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ResizeTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..aI(2, _omitFieldNames ? '' : 'cols')
    ..aI(3, _omitFieldNames ? '' : 'rows')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizeTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizeTerminalRequest copyWith(
          void Function(ResizeTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as ResizeTerminalRequest))
          as ResizeTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ResizeTerminalRequest() / ResizeTerminalRequest.new instead')
  static ResizeTerminalRequest create() => ResizeTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => ResizeTerminalRequest._();
  @$core.override
  ResizeTerminalRequest createEmptyInstance() => ResizeTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static ResizeTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResizeTerminalRequest>(
          ResizeTerminalRequest.$_createMessage);
  static ResizeTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get cols => $_getIZ(1);
  @$pb.TagNumber(2)
  set cols($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCols() => $_has(1);
  @$pb.TagNumber(2)
  void clearCols() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rows => $_getIZ(2);
  @$pb.TagNumber(3)
  set rows($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearRows() => $_clearField(3);
}

class ResizeTerminalResponse extends $pb.GeneratedMessage {
  factory ResizeTerminalResponse() => ResizeTerminalResponse._();

  ResizeTerminalResponse._();

  factory ResizeTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResizeTerminalResponse()..mergeFromBuffer(data, registry);
  factory ResizeTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResizeTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResizeTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ResizeTerminalResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizeTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResizeTerminalResponse copyWith(
          void Function(ResizeTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as ResizeTerminalResponse))
          as ResizeTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ResizeTerminalResponse() / ResizeTerminalResponse.new instead')
  static ResizeTerminalResponse create() => ResizeTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => ResizeTerminalResponse._();
  @$core.override
  ResizeTerminalResponse createEmptyInstance() => ResizeTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static ResizeTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResizeTerminalResponse>(
          ResizeTerminalResponse.$_createMessage);
  static ResizeTerminalResponse? _defaultInstance;
}

class RenameTerminalRequest extends $pb.GeneratedMessage {
  factory RenameTerminalRequest({
    $core.String? terminalId,
    $core.String? name,
  }) {
    final result = RenameTerminalRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    if (name != null) result.name = name;
    return result;
  }

  RenameTerminalRequest._();

  factory RenameTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameTerminalRequest()..mergeFromBuffer(data, registry);
  factory RenameTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RenameTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameTerminalRequest copyWith(
          void Function(RenameTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as RenameTerminalRequest))
          as RenameTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RenameTerminalRequest() / RenameTerminalRequest.new instead')
  static RenameTerminalRequest create() => RenameTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => RenameTerminalRequest._();
  @$core.override
  RenameTerminalRequest createEmptyInstance() => RenameTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static RenameTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameTerminalRequest>(
          RenameTerminalRequest.$_createMessage);
  static RenameTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);
}

class RenameTerminalResponse extends $pb.GeneratedMessage {
  factory RenameTerminalResponse() => RenameTerminalResponse._();

  RenameTerminalResponse._();

  factory RenameTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameTerminalResponse()..mergeFromBuffer(data, registry);
  factory RenameTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RenameTerminalResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameTerminalResponse copyWith(
          void Function(RenameTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as RenameTerminalResponse))
          as RenameTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RenameTerminalResponse() / RenameTerminalResponse.new instead')
  static RenameTerminalResponse create() => RenameTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => RenameTerminalResponse._();
  @$core.override
  RenameTerminalResponse createEmptyInstance() => RenameTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static RenameTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameTerminalResponse>(
          RenameTerminalResponse.$_createMessage);
  static RenameTerminalResponse? _defaultInstance;
}

class ArrangeTerminalsRequest extends $pb.GeneratedMessage {
  factory ArrangeTerminalsRequest({
    $core.String? chatId,
    $core.Iterable<$core.String>? terminalIds,
  }) {
    final result = ArrangeTerminalsRequest._();
    if (chatId != null) result.chatId = chatId;
    if (terminalIds != null) result.terminalIds.addAll(terminalIds);
    return result;
  }

  ArrangeTerminalsRequest._();

  factory ArrangeTerminalsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArrangeTerminalsRequest()..mergeFromBuffer(data, registry);
  factory ArrangeTerminalsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArrangeTerminalsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArrangeTerminalsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ArrangeTerminalsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..pPS(2, _omitFieldNames ? '' : 'terminalIds')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrangeTerminalsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrangeTerminalsRequest copyWith(
          void Function(ArrangeTerminalsRequest) updates) =>
      super.copyWith((message) => updates(message as ArrangeTerminalsRequest))
          as ArrangeTerminalsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ArrangeTerminalsRequest() / ArrangeTerminalsRequest.new instead')
  static ArrangeTerminalsRequest create() => ArrangeTerminalsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ArrangeTerminalsRequest._();
  @$core.override
  ArrangeTerminalsRequest createEmptyInstance() => ArrangeTerminalsRequest._();
  @$core.pragma('dart2js:noInline')
  static ArrangeTerminalsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArrangeTerminalsRequest>(
          ArrangeTerminalsRequest.$_createMessage);
  static ArrangeTerminalsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get terminalIds => $_getList(1);
}

class ArrangeTerminalsResponse extends $pb.GeneratedMessage {
  factory ArrangeTerminalsResponse() => ArrangeTerminalsResponse._();

  ArrangeTerminalsResponse._();

  factory ArrangeTerminalsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArrangeTerminalsResponse()..mergeFromBuffer(data, registry);
  factory ArrangeTerminalsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ArrangeTerminalsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ArrangeTerminalsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ArrangeTerminalsResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrangeTerminalsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ArrangeTerminalsResponse copyWith(
          void Function(ArrangeTerminalsResponse) updates) =>
      super.copyWith((message) => updates(message as ArrangeTerminalsResponse))
          as ArrangeTerminalsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ArrangeTerminalsResponse() / ArrangeTerminalsResponse.new instead')
  static ArrangeTerminalsResponse create() => ArrangeTerminalsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ArrangeTerminalsResponse._();
  @$core.override
  ArrangeTerminalsResponse createEmptyInstance() =>
      ArrangeTerminalsResponse._();
  @$core.pragma('dart2js:noInline')
  static ArrangeTerminalsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ArrangeTerminalsResponse>(
          ArrangeTerminalsResponse.$_createMessage);
  static ArrangeTerminalsResponse? _defaultInstance;
}

class RestartTerminalRequest extends $pb.GeneratedMessage {
  factory RestartTerminalRequest({
    $core.String? terminalId,
    $core.int? cols,
    $core.int? rows,
  }) {
    final result = RestartTerminalRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    if (cols != null) result.cols = cols;
    if (rows != null) result.rows = rows;
    return result;
  }

  RestartTerminalRequest._();

  factory RestartTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartTerminalRequest()..mergeFromBuffer(data, registry);
  factory RestartTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestartTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RestartTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..aI(2, _omitFieldNames ? '' : 'cols')
    ..aI(3, _omitFieldNames ? '' : 'rows')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartTerminalRequest copyWith(
          void Function(RestartTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as RestartTerminalRequest))
          as RestartTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RestartTerminalRequest() / RestartTerminalRequest.new instead')
  static RestartTerminalRequest create() => RestartTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => RestartTerminalRequest._();
  @$core.override
  RestartTerminalRequest createEmptyInstance() => RestartTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static RestartTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestartTerminalRequest>(
          RestartTerminalRequest.$_createMessage);
  static RestartTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get cols => $_getIZ(1);
  @$pb.TagNumber(2)
  set cols($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCols() => $_has(1);
  @$pb.TagNumber(2)
  void clearCols() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get rows => $_getIZ(2);
  @$pb.TagNumber(3)
  set rows($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRows() => $_has(2);
  @$pb.TagNumber(3)
  void clearRows() => $_clearField(3);
}

class RestartTerminalResponse extends $pb.GeneratedMessage {
  factory RestartTerminalResponse() => RestartTerminalResponse._();

  RestartTerminalResponse._();

  factory RestartTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartTerminalResponse()..mergeFromBuffer(data, registry);
  factory RestartTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RestartTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestartTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RestartTerminalResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestartTerminalResponse copyWith(
          void Function(RestartTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as RestartTerminalResponse))
          as RestartTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RestartTerminalResponse() / RestartTerminalResponse.new instead')
  static RestartTerminalResponse create() => RestartTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => RestartTerminalResponse._();
  @$core.override
  RestartTerminalResponse createEmptyInstance() => RestartTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static RestartTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestartTerminalResponse>(
          RestartTerminalResponse.$_createMessage);
  static RestartTerminalResponse? _defaultInstance;
}

class CloseTerminalRequest extends $pb.GeneratedMessage {
  factory CloseTerminalRequest({
    $core.String? terminalId,
  }) {
    final result = CloseTerminalRequest._();
    if (terminalId != null) result.terminalId = terminalId;
    return result;
  }

  CloseTerminalRequest._();

  factory CloseTerminalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseTerminalRequest()..mergeFromBuffer(data, registry);
  factory CloseTerminalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseTerminalRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseTerminalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CloseTerminalRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'terminalId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseTerminalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseTerminalRequest copyWith(void Function(CloseTerminalRequest) updates) =>
      super.copyWith((message) => updates(message as CloseTerminalRequest))
          as CloseTerminalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CloseTerminalRequest() / CloseTerminalRequest.new instead')
  static CloseTerminalRequest create() => CloseTerminalRequest._();
  static $pb.GeneratedMessage $_createMessage() => CloseTerminalRequest._();
  @$core.override
  CloseTerminalRequest createEmptyInstance() => CloseTerminalRequest._();
  @$core.pragma('dart2js:noInline')
  static CloseTerminalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloseTerminalRequest>(
          CloseTerminalRequest.$_createMessage);
  static CloseTerminalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get terminalId => $_getSZ(0);
  @$pb.TagNumber(1)
  set terminalId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTerminalId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTerminalId() => $_clearField(1);
}

class CloseTerminalResponse extends $pb.GeneratedMessage {
  factory CloseTerminalResponse() => CloseTerminalResponse._();

  CloseTerminalResponse._();

  factory CloseTerminalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseTerminalResponse()..mergeFromBuffer(data, registry);
  factory CloseTerminalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CloseTerminalResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloseTerminalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CloseTerminalResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseTerminalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloseTerminalResponse copyWith(
          void Function(CloseTerminalResponse) updates) =>
      super.copyWith((message) => updates(message as CloseTerminalResponse))
          as CloseTerminalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CloseTerminalResponse() / CloseTerminalResponse.new instead')
  static CloseTerminalResponse create() => CloseTerminalResponse._();
  static $pb.GeneratedMessage $_createMessage() => CloseTerminalResponse._();
  @$core.override
  CloseTerminalResponse createEmptyInstance() => CloseTerminalResponse._();
  @$core.pragma('dart2js:noInline')
  static CloseTerminalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloseTerminalResponse>(
          CloseTerminalResponse.$_createMessage);
  static CloseTerminalResponse? _defaultInstance;
}

class CheckFolderRequest extends $pb.GeneratedMessage {
  factory CheckFolderRequest({
    $core.String? folder,
    $core.String? agent,
  }) {
    final result = CheckFolderRequest._();
    if (folder != null) result.folder = folder;
    if (agent != null) result.agent = agent;
    return result;
  }

  CheckFolderRequest._();

  factory CheckFolderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckFolderRequest()..mergeFromBuffer(data, registry);
  factory CheckFolderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckFolderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckFolderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CheckFolderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckFolderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckFolderRequest copyWith(void Function(CheckFolderRequest) updates) =>
      super.copyWith((message) => updates(message as CheckFolderRequest))
          as CheckFolderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use CheckFolderRequest() / CheckFolderRequest.new instead')
  static CheckFolderRequest create() => CheckFolderRequest._();
  static $pb.GeneratedMessage $_createMessage() => CheckFolderRequest._();
  @$core.override
  CheckFolderRequest createEmptyInstance() => CheckFolderRequest._();
  @$core.pragma('dart2js:noInline')
  static CheckFolderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckFolderRequest>(
          CheckFolderRequest.$_createMessage);
  static CheckFolderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// The agent the chat runs (Agent.name); empty for the default.
  @$pb.TagNumber(2)
  $core.String get agent => $_getSZ(1);
  @$pb.TagNumber(2)
  set agent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgent() => $_clearField(2);
}

class CheckFolderResponse extends $pb.GeneratedMessage {
  factory CheckFolderResponse({
    $core.Iterable<FolderRun>? runs,
    $core.String? key,
  }) {
    final result = CheckFolderResponse._();
    if (runs != null) result.runs.addAll(runs);
    if (key != null) result.key = key;
    return result;
  }

  CheckFolderResponse._();

  factory CheckFolderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckFolderResponse()..mergeFromBuffer(data, registry);
  factory CheckFolderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckFolderResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckFolderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CheckFolderResponse.$_createMessage)
    ..pPM<FolderRun>(1, _omitFieldNames ? '' : 'runs',
        subBuilder: FolderRun.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'key')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckFolderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckFolderResponse copyWith(void Function(CheckFolderResponse) updates) =>
      super.copyWith((message) => updates(message as CheckFolderResponse))
          as CheckFolderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use CheckFolderResponse() / CheckFolderResponse.new instead')
  static CheckFolderResponse create() => CheckFolderResponse._();
  static $pb.GeneratedMessage $_createMessage() => CheckFolderResponse._();
  @$core.override
  CheckFolderResponse createEmptyInstance() => CheckFolderResponse._();
  @$core.pragma('dart2js:noInline')
  static CheckFolderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckFolderResponse>(
          CheckFolderResponse.$_createMessage);
  static CheckFolderResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FolderRun> get runs => $_getList(0);

  /// What TrustFolder remembers for exactly what runs shows; empty when the
  /// folder can't be remembered (Start anyway is then for this start only).
  @$pb.TagNumber(2)
  $core.String get key => $_getSZ(1);
  @$pb.TagNumber(2)
  set key($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);
}

/// Something a folder has the agent run on its own.
class FolderRun extends $pb.GeneratedMessage {
  factory FolderRun({
    $core.String? file,
    $core.String? what,
    $core.String? command,
  }) {
    final result = FolderRun._();
    if (file != null) result.file = file;
    if (what != null) result.what = what;
    if (command != null) result.command = command;
    return result;
  }

  FolderRun._();

  factory FolderRun.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FolderRun()..mergeFromBuffer(data, registry);
  factory FolderRun.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FolderRun()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FolderRun',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FolderRun.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'file')
    ..aOS(2, _omitFieldNames ? '' : 'what')
    ..aOS(3, _omitFieldNames ? '' : 'command')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FolderRun clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FolderRun copyWith(void Function(FolderRun) updates) =>
      super.copyWith((message) => updates(message as FolderRun)) as FolderRun;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FolderRun() / FolderRun.new instead')
  static FolderRun create() => FolderRun._();
  static $pb.GeneratedMessage $_createMessage() => FolderRun._();
  @$core.override
  FolderRun createEmptyInstance() => FolderRun._();
  @$core.pragma('dart2js:noInline')
  static FolderRun getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FolderRun>(FolderRun.$_createMessage);
  static FolderRun? _defaultInstance;

  /// The file that says so.
  @$pb.TagNumber(1)
  $core.String get file => $_getSZ(0);
  @$pb.TagNumber(1)
  set file($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);

  /// What it is: "MCP server github", "Hook on SessionStart".
  @$pb.TagNumber(2)
  $core.String get what => $_getSZ(1);
  @$pb.TagNumber(2)
  set what($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWhat() => $_has(1);
  @$pb.TagNumber(2)
  void clearWhat() => $_clearField(2);

  /// Its command line, or URL; for an env block the names it sets.
  @$pb.TagNumber(3)
  $core.String get command => $_getSZ(2);
  @$pb.TagNumber(3)
  set command($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCommand() => $_has(2);
  @$pb.TagNumber(3)
  void clearCommand() => $_clearField(3);
}

class TrustFolderRequest extends $pb.GeneratedMessage {
  factory TrustFolderRequest({
    $core.String? folder,
    $core.String? agent,
    $core.String? key,
  }) {
    final result = TrustFolderRequest._();
    if (folder != null) result.folder = folder;
    if (agent != null) result.agent = agent;
    if (key != null) result.key = key;
    return result;
  }

  TrustFolderRequest._();

  factory TrustFolderRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrustFolderRequest()..mergeFromBuffer(data, registry);
  factory TrustFolderRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrustFolderRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrustFolderRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TrustFolderRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'agent')
    ..aOS(3, _omitFieldNames ? '' : 'key')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrustFolderRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrustFolderRequest copyWith(void Function(TrustFolderRequest) updates) =>
      super.copyWith((message) => updates(message as TrustFolderRequest))
          as TrustFolderRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TrustFolderRequest() / TrustFolderRequest.new instead')
  static TrustFolderRequest create() => TrustFolderRequest._();
  static $pb.GeneratedMessage $_createMessage() => TrustFolderRequest._();
  @$core.override
  TrustFolderRequest createEmptyInstance() => TrustFolderRequest._();
  @$core.pragma('dart2js:noInline')
  static TrustFolderRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrustFolderRequest>(
          TrustFolderRequest.$_createMessage);
  static TrustFolderRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// The agent the chat runs (Agent.name); empty for the default.
  @$pb.TagNumber(2)
  $core.String get agent => $_getSZ(1);
  @$pb.TagNumber(2)
  set agent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgent() => $_clearField(2);

  /// CheckFolderResponse.key. Refused (aborted) when the folder no longer
  /// matches it: check again.
  @$pb.TagNumber(3)
  $core.String get key => $_getSZ(2);
  @$pb.TagNumber(3)
  set key($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKey() => $_has(2);
  @$pb.TagNumber(3)
  void clearKey() => $_clearField(3);
}

class TrustFolderResponse extends $pb.GeneratedMessage {
  factory TrustFolderResponse() => TrustFolderResponse._();

  TrustFolderResponse._();

  factory TrustFolderResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrustFolderResponse()..mergeFromBuffer(data, registry);
  factory TrustFolderResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrustFolderResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrustFolderResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TrustFolderResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrustFolderResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrustFolderResponse copyWith(void Function(TrustFolderResponse) updates) =>
      super.copyWith((message) => updates(message as TrustFolderResponse))
          as TrustFolderResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use TrustFolderResponse() / TrustFolderResponse.new instead')
  static TrustFolderResponse create() => TrustFolderResponse._();
  static $pb.GeneratedMessage $_createMessage() => TrustFolderResponse._();
  @$core.override
  TrustFolderResponse createEmptyInstance() => TrustFolderResponse._();
  @$core.pragma('dart2js:noInline')
  static TrustFolderResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrustFolderResponse>(
          TrustFolderResponse.$_createMessage);
  static TrustFolderResponse? _defaultInstance;
}

class Remote extends $pb.GeneratedMessage {
  factory Remote({
    $core.bool? on,
    $core.String? relay,
    $core.String? state,
    $core.String? error,
    $core.Iterable<Device>? devices,
    Pairing? pairing,
    $core.String? rendezvous,
  }) {
    final result = Remote._();
    if (on != null) result.on = on;
    if (relay != null) result.relay = relay;
    if (state != null) result.state = state;
    if (error != null) result.error = error;
    if (devices != null) result.devices.addAll(devices);
    if (pairing != null) result.pairing = pairing;
    if (rendezvous != null) result.rendezvous = rendezvous;
    return result;
  }

  Remote._();

  factory Remote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Remote()..mergeFromBuffer(data, registry);
  factory Remote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Remote()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Remote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Remote.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'on')
    ..aOS(2, _omitFieldNames ? '' : 'relay')
    ..aOS(3, _omitFieldNames ? '' : 'state')
    ..aOS(4, _omitFieldNames ? '' : 'error')
    ..pPM<Device>(5, _omitFieldNames ? '' : 'devices',
        subBuilder: Device.$_createMessage)
    ..aOM<Pairing>(6, _omitFieldNames ? '' : 'pairing',
        subBuilder: Pairing.$_createMessage)
    ..aOS(7, _omitFieldNames ? '' : 'rendezvous')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Remote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Remote copyWith(void Function(Remote) updates) =>
      super.copyWith((message) => updates(message as Remote)) as Remote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Remote() / Remote.new instead')
  static Remote create() => Remote._();
  static $pb.GeneratedMessage $_createMessage() => Remote._();
  @$core.override
  Remote createEmptyInstance() => Remote._();
  @$core.pragma('dart2js:noInline')
  static Remote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Remote>(Remote.$_createMessage);
  static Remote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get on => $_getBF(0);
  @$pb.TagNumber(1)
  set on($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOn() => $_has(0);
  @$pb.TagNumber(1)
  void clearOn() => $_clearField(1);

  /// The relay's ws:// or wss:// URL.
  @$pb.TagNumber(2)
  $core.String get relay => $_getSZ(1);
  @$pb.TagNumber(2)
  set relay($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelay() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelay() => $_clearField(2);

  /// "off", "connecting", "connected" (waiting at the relay for phones) or
  /// "error" (error says what; it tries again).
  @$pb.TagNumber(3)
  $core.String get state => $_getSZ(2);
  @$pb.TagNumber(3)
  set state($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasState() => $_has(2);
  @$pb.TagNumber(3)
  void clearState() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get error => $_getSZ(3);
  @$pb.TagNumber(4)
  set error($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasError() => $_has(3);
  @$pb.TagNumber(4)
  void clearError() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<Device> get devices => $_getList(4);

  /// A phone being paired; unset when none.
  @$pb.TagNumber(6)
  Pairing get pairing => $_getN(5);
  @$pb.TagNumber(6)
  set pairing(Pairing value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPairing() => $_has(5);
  @$pb.TagNumber(6)
  void clearPairing() => $_clearField(6);
  @$pb.TagNumber(6)
  Pairing ensurePairing() => $_ensure(5);

  /// The daemon's id at the relay, where its phones dial. It changes when a
  /// device is revoked: a phone that sees another than the one it dials
  /// keeps this one from then on (its old one answers it for 30 days).
  @$pb.TagNumber(7)
  $core.String get rendezvous => $_getSZ(6);
  @$pb.TagNumber(7)
  set rendezvous($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRendezvous() => $_has(6);
  @$pb.TagNumber(7)
  void clearRendezvous() => $_clearField(7);
}

class Device extends $pb.GeneratedMessage {
  factory Device({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? paired,
    $fixnum.Int64? lastSeen,
    $core.bool? connected,
  }) {
    final result = Device._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (paired != null) result.paired = paired;
    if (lastSeen != null) result.lastSeen = lastSeen;
    if (connected != null) result.connected = connected;
    return result;
  }

  Device._();

  factory Device.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Device()..mergeFromBuffer(data, registry);
  factory Device.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Device()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Device',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Device.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'paired')
    ..aInt64(4, _omitFieldNames ? '' : 'lastSeen')
    ..aOB(5, _omitFieldNames ? '' : 'connected')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Device copyWith(void Function(Device) updates) =>
      super.copyWith((message) => updates(message as Device)) as Device;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Device() / Device.new instead')
  static Device create() => Device._();
  static $pb.GeneratedMessage $_createMessage() => Device._();
  @$core.override
  Device createEmptyInstance() => Device._();
  @$core.pragma('dart2js:noInline')
  static Device getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Device>(Device.$_createMessage);
  static Device? _defaultInstance;

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

  /// Unix milliseconds; last_seen 0 when never.
  @$pb.TagNumber(3)
  $fixnum.Int64 get paired => $_getI64(2);
  @$pb.TagNumber(3)
  set paired($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPaired() => $_has(2);
  @$pb.TagNumber(3)
  void clearPaired() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get lastSeen => $_getI64(3);
  @$pb.TagNumber(4)
  set lastSeen($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLastSeen() => $_has(3);
  @$pb.TagNumber(4)
  void clearLastSeen() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get connected => $_getBF(4);
  @$pb.TagNumber(5)
  set connected($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasConnected() => $_has(4);
  @$pb.TagNumber(5)
  void clearConnected() => $_clearField(5);
}

class Pairing extends $pb.GeneratedMessage {
  factory Pairing({
    $fixnum.Int64? expires,
    $core.String? name,
    $core.String? code,
  }) {
    final result = Pairing._();
    if (expires != null) result.expires = expires;
    if (name != null) result.name = name;
    if (code != null) result.code = code;
    return result;
  }

  Pairing._();

  factory Pairing.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pairing()..mergeFromBuffer(data, registry);
  factory Pairing.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Pairing()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Pairing',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Pairing.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'expires')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pairing clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Pairing copyWith(void Function(Pairing) updates) =>
      super.copyWith((message) => updates(message as Pairing)) as Pairing;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Pairing() / Pairing.new instead')
  static Pairing create() => Pairing._();
  static $pb.GeneratedMessage $_createMessage() => Pairing._();
  @$core.override
  Pairing createEmptyInstance() => Pairing._();
  @$core.pragma('dart2js:noInline')
  static Pairing getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Pairing>(Pairing.$_createMessage);
  static Pairing? _defaultInstance;

  /// Unix milliseconds: the QR code is good until then.
  @$pb.TagNumber(1)
  $fixnum.Int64 get expires => $_getI64(0);
  @$pb.TagNumber(1)
  set expires($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasExpires() => $_has(0);
  @$pb.TagNumber(1)
  void clearExpires() => $_clearField(1);

  /// Once a phone has connected: its name, and the code both screens show.
  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get code => $_getSZ(2);
  @$pb.TagNumber(3)
  set code($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => $_clearField(3);
}

class GetRemoteRequest extends $pb.GeneratedMessage {
  factory GetRemoteRequest() => GetRemoteRequest._();

  GetRemoteRequest._();

  factory GetRemoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetRemoteRequest()..mergeFromBuffer(data, registry);
  factory GetRemoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetRemoteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRemoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetRemoteRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRemoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRemoteRequest copyWith(void Function(GetRemoteRequest) updates) =>
      super.copyWith((message) => updates(message as GetRemoteRequest))
          as GetRemoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetRemoteRequest() / GetRemoteRequest.new instead')
  static GetRemoteRequest create() => GetRemoteRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetRemoteRequest._();
  @$core.override
  GetRemoteRequest createEmptyInstance() => GetRemoteRequest._();
  @$core.pragma('dart2js:noInline')
  static GetRemoteRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetRemoteRequest>(
          GetRemoteRequest.$_createMessage);
  static GetRemoteRequest? _defaultInstance;
}

class GetRemoteResponse extends $pb.GeneratedMessage {
  factory GetRemoteResponse({
    Remote? remote,
  }) {
    final result = GetRemoteResponse._();
    if (remote != null) result.remote = remote;
    return result;
  }

  GetRemoteResponse._();

  factory GetRemoteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetRemoteResponse()..mergeFromBuffer(data, registry);
  factory GetRemoteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetRemoteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetRemoteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetRemoteResponse.$_createMessage)
    ..aOM<Remote>(1, _omitFieldNames ? '' : 'remote',
        subBuilder: Remote.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRemoteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetRemoteResponse copyWith(void Function(GetRemoteResponse) updates) =>
      super.copyWith((message) => updates(message as GetRemoteResponse))
          as GetRemoteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetRemoteResponse() / GetRemoteResponse.new instead')
  static GetRemoteResponse create() => GetRemoteResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetRemoteResponse._();
  @$core.override
  GetRemoteResponse createEmptyInstance() => GetRemoteResponse._();
  @$core.pragma('dart2js:noInline')
  static GetRemoteResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetRemoteResponse>(
          GetRemoteResponse.$_createMessage);
  static GetRemoteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  Remote get remote => $_getN(0);
  @$pb.TagNumber(1)
  set remote(Remote value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRemote() => $_has(0);
  @$pb.TagNumber(1)
  void clearRemote() => $_clearField(1);
  @$pb.TagNumber(1)
  Remote ensureRemote() => $_ensure(0);
}

class SetRemoteRequest extends $pb.GeneratedMessage {
  factory SetRemoteRequest({
    $core.bool? on,
    $core.String? relay,
  }) {
    final result = SetRemoteRequest._();
    if (on != null) result.on = on;
    if (relay != null) result.relay = relay;
    return result;
  }

  SetRemoteRequest._();

  factory SetRemoteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetRemoteRequest()..mergeFromBuffer(data, registry);
  factory SetRemoteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetRemoteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetRemoteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetRemoteRequest.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'on')
    ..aOS(2, _omitFieldNames ? '' : 'relay')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRemoteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRemoteRequest copyWith(void Function(SetRemoteRequest) updates) =>
      super.copyWith((message) => updates(message as SetRemoteRequest))
          as SetRemoteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetRemoteRequest() / SetRemoteRequest.new instead')
  static SetRemoteRequest create() => SetRemoteRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetRemoteRequest._();
  @$core.override
  SetRemoteRequest createEmptyInstance() => SetRemoteRequest._();
  @$core.pragma('dart2js:noInline')
  static SetRemoteRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetRemoteRequest>(
          SetRemoteRequest.$_createMessage);
  static SetRemoteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get on => $_getBF(0);
  @$pb.TagNumber(1)
  set on($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOn() => $_has(0);
  @$pb.TagNumber(1)
  void clearOn() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get relay => $_getSZ(1);
  @$pb.TagNumber(2)
  set relay($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRelay() => $_has(1);
  @$pb.TagNumber(2)
  void clearRelay() => $_clearField(2);
}

class SetRemoteResponse extends $pb.GeneratedMessage {
  factory SetRemoteResponse() => SetRemoteResponse._();

  SetRemoteResponse._();

  factory SetRemoteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetRemoteResponse()..mergeFromBuffer(data, registry);
  factory SetRemoteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetRemoteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetRemoteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetRemoteResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRemoteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetRemoteResponse copyWith(void Function(SetRemoteResponse) updates) =>
      super.copyWith((message) => updates(message as SetRemoteResponse))
          as SetRemoteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetRemoteResponse() / SetRemoteResponse.new instead')
  static SetRemoteResponse create() => SetRemoteResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetRemoteResponse._();
  @$core.override
  SetRemoteResponse createEmptyInstance() => SetRemoteResponse._();
  @$core.pragma('dart2js:noInline')
  static SetRemoteResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetRemoteResponse>(
          SetRemoteResponse.$_createMessage);
  static SetRemoteResponse? _defaultInstance;
}

class StartPairingRequest extends $pb.GeneratedMessage {
  factory StartPairingRequest() => StartPairingRequest._();

  StartPairingRequest._();

  factory StartPairingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartPairingRequest()..mergeFromBuffer(data, registry);
  factory StartPairingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartPairingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartPairingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: StartPairingRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartPairingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartPairingRequest copyWith(void Function(StartPairingRequest) updates) =>
      super.copyWith((message) => updates(message as StartPairingRequest))
          as StartPairingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use StartPairingRequest() / StartPairingRequest.new instead')
  static StartPairingRequest create() => StartPairingRequest._();
  static $pb.GeneratedMessage $_createMessage() => StartPairingRequest._();
  @$core.override
  StartPairingRequest createEmptyInstance() => StartPairingRequest._();
  @$core.pragma('dart2js:noInline')
  static StartPairingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartPairingRequest>(
          StartPairingRequest.$_createMessage);
  static StartPairingRequest? _defaultInstance;
}

class StartPairingResponse extends $pb.GeneratedMessage {
  factory StartPairingResponse({
    $core.String? qr,
    $fixnum.Int64? expires,
  }) {
    final result = StartPairingResponse._();
    if (qr != null) result.qr = qr;
    if (expires != null) result.expires = expires;
    return result;
  }

  StartPairingResponse._();

  factory StartPairingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartPairingResponse()..mergeFromBuffer(data, registry);
  factory StartPairingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      StartPairingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StartPairingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: StartPairingResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'qr')
    ..aInt64(2, _omitFieldNames ? '' : 'expires')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartPairingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StartPairingResponse copyWith(void Function(StartPairingResponse) updates) =>
      super.copyWith((message) => updates(message as StartPairingResponse))
          as StartPairingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use StartPairingResponse() / StartPairingResponse.new instead')
  static StartPairingResponse create() => StartPairingResponse._();
  static $pb.GeneratedMessage $_createMessage() => StartPairingResponse._();
  @$core.override
  StartPairingResponse createEmptyInstance() => StartPairingResponse._();
  @$core.pragma('dart2js:noInline')
  static StartPairingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StartPairingResponse>(
          StartPairingResponse.$_createMessage);
  static StartPairingResponse? _defaultInstance;

  /// nushi://pair?r=<relay>&i=<one-time id>&k=<daemon's key>&s=<secret>
  @$pb.TagNumber(1)
  $core.String get qr => $_getSZ(0);
  @$pb.TagNumber(1)
  set qr($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQr() => $_has(0);
  @$pb.TagNumber(1)
  void clearQr() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get expires => $_getI64(1);
  @$pb.TagNumber(2)
  set expires($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExpires() => $_has(1);
  @$pb.TagNumber(2)
  void clearExpires() => $_clearField(2);
}

class ConfirmPairingRequest extends $pb.GeneratedMessage {
  factory ConfirmPairingRequest({
    $core.String? code,
    $core.bool? allow,
  }) {
    final result = ConfirmPairingRequest._();
    if (code != null) result.code = code;
    if (allow != null) result.allow = allow;
    return result;
  }

  ConfirmPairingRequest._();

  factory ConfirmPairingRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfirmPairingRequest()..mergeFromBuffer(data, registry);
  factory ConfirmPairingRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfirmPairingRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfirmPairingRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ConfirmPairingRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOB(2, _omitFieldNames ? '' : 'allow')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmPairingRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmPairingRequest copyWith(
          void Function(ConfirmPairingRequest) updates) =>
      super.copyWith((message) => updates(message as ConfirmPairingRequest))
          as ConfirmPairingRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ConfirmPairingRequest() / ConfirmPairingRequest.new instead')
  static ConfirmPairingRequest create() => ConfirmPairingRequest._();
  static $pb.GeneratedMessage $_createMessage() => ConfirmPairingRequest._();
  @$core.override
  ConfirmPairingRequest createEmptyInstance() => ConfirmPairingRequest._();
  @$core.pragma('dart2js:noInline')
  static ConfirmPairingRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfirmPairingRequest>(
          ConfirmPairingRequest.$_createMessage);
  static ConfirmPairingRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get allow => $_getBF(1);
  @$pb.TagNumber(2)
  set allow($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAllow() => $_has(1);
  @$pb.TagNumber(2)
  void clearAllow() => $_clearField(2);
}

class ConfirmPairingResponse extends $pb.GeneratedMessage {
  factory ConfirmPairingResponse() => ConfirmPairingResponse._();

  ConfirmPairingResponse._();

  factory ConfirmPairingResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfirmPairingResponse()..mergeFromBuffer(data, registry);
  factory ConfirmPairingResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ConfirmPairingResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConfirmPairingResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ConfirmPairingResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmPairingResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConfirmPairingResponse copyWith(
          void Function(ConfirmPairingResponse) updates) =>
      super.copyWith((message) => updates(message as ConfirmPairingResponse))
          as ConfirmPairingResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ConfirmPairingResponse() / ConfirmPairingResponse.new instead')
  static ConfirmPairingResponse create() => ConfirmPairingResponse._();
  static $pb.GeneratedMessage $_createMessage() => ConfirmPairingResponse._();
  @$core.override
  ConfirmPairingResponse createEmptyInstance() => ConfirmPairingResponse._();
  @$core.pragma('dart2js:noInline')
  static ConfirmPairingResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConfirmPairingResponse>(
          ConfirmPairingResponse.$_createMessage);
  static ConfirmPairingResponse? _defaultInstance;
}

class RevokeDeviceRequest extends $pb.GeneratedMessage {
  factory RevokeDeviceRequest({
    $core.String? id,
  }) {
    final result = RevokeDeviceRequest._();
    if (id != null) result.id = id;
    return result;
  }

  RevokeDeviceRequest._();

  factory RevokeDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevokeDeviceRequest()..mergeFromBuffer(data, registry);
  factory RevokeDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevokeDeviceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RevokeDeviceRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceRequest copyWith(void Function(RevokeDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RevokeDeviceRequest))
          as RevokeDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RevokeDeviceRequest() / RevokeDeviceRequest.new instead')
  static RevokeDeviceRequest create() => RevokeDeviceRequest._();
  static $pb.GeneratedMessage $_createMessage() => RevokeDeviceRequest._();
  @$core.override
  RevokeDeviceRequest createEmptyInstance() => RevokeDeviceRequest._();
  @$core.pragma('dart2js:noInline')
  static RevokeDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeDeviceRequest>(
          RevokeDeviceRequest.$_createMessage);
  static RevokeDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class RevokeDeviceResponse extends $pb.GeneratedMessage {
  factory RevokeDeviceResponse() => RevokeDeviceResponse._();

  RevokeDeviceResponse._();

  factory RevokeDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevokeDeviceResponse()..mergeFromBuffer(data, registry);
  factory RevokeDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RevokeDeviceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RevokeDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RevokeDeviceResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RevokeDeviceResponse copyWith(void Function(RevokeDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as RevokeDeviceResponse))
          as RevokeDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RevokeDeviceResponse() / RevokeDeviceResponse.new instead')
  static RevokeDeviceResponse create() => RevokeDeviceResponse._();
  static $pb.GeneratedMessage $_createMessage() => RevokeDeviceResponse._();
  @$core.override
  RevokeDeviceResponse createEmptyInstance() => RevokeDeviceResponse._();
  @$core.pragma('dart2js:noInline')
  static RevokeDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RevokeDeviceResponse>(
          RevokeDeviceResponse.$_createMessage);
  static RevokeDeviceResponse? _defaultInstance;
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

  /// Lists the agents chats can run, the default first.
  $async.Future<ListAgentsResponse> listAgents(
          $pb.ClientContext? ctx, ListAgentsRequest request) =>
      _client.invoke<ListAgentsResponse>(
          ctx, 'NushiService', 'ListAgents', request, ListAgentsResponse());

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

  /// Cuts a chat back to just before one of its user messages (when
  /// status.can_rewind and the message's fork_at is set, or it is the first)
  /// and returns that message. The agent's session is forked there: a new
  /// session id, the same chat. Files aren't rewound. Refused while the chat
  /// is busy.
  $async.Future<RewindChatResponse> rewindChat(
          $pb.ClientContext? ctx, RewindChatRequest request) =>
      _client.invoke<RewindChatResponse>(
          ctx, 'NushiService', 'RewindChat', request, RewindChatResponse());

  /// Takes a message out of the chat's queue before the agent gets it, and
  /// returns it. Refused once the agent has it.
  $async.Future<UnqueueResponse> unqueue(
          $pb.ClientContext? ctx, UnqueueRequest request) =>
      _client.invoke<UnqueueResponse>(
          ctx, 'NushiService', 'Unqueue', request, UnqueueResponse());

  /// Stops the chat's running turn (ACP session/cancel). The turn ends with a
  /// "cancelled" notice, and prompts it was waiting on are cancelled. It can
  /// take the last message back too (take_back).
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

  /// Puts a chat to sleep (when status.can_sleep): its agent stops as for
  /// ArchiveChat (a running turn is stopped, side chats end), and the chat
  /// stays, its transcript too. A message, or anything else that needs the
  /// agent, reopens the session (ACP session/load); opening it doesn't.
  $async.Future<SleepChatResponse> sleepChat(
          $pb.ClientContext? ctx, SleepChatRequest request) =>
      _client.invoke<SleepChatResponse>(
          ctx, 'NushiService', 'SleepChat', request, SleepChatResponse());

  /// The daemon's settings, and changing them.
  /// Says how much memory Nushi takes, as footprint (Activity Monitor's
  /// Memory), in bytes: a few milliseconds' work.
  $async.Future<GetMemoryResponse> getMemory(
          $pb.ClientContext? ctx, GetMemoryRequest request) =>
      _client.invoke<GetMemoryResponse>(
          ctx, 'NushiService', 'GetMemory', request, GetMemoryResponse());
  $async.Future<GetSettingsResponse> getSettings(
          $pb.ClientContext? ctx, GetSettingsRequest request) =>
      _client.invoke<GetSettingsResponse>(
          ctx, 'NushiService', 'GetSettings', request, GetSettingsResponse());
  $async.Future<SetSettingsResponse> setSettings(
          $pb.ClientContext? ctx, SetSettingsRequest request) =>
      _client.invoke<SetSettingsResponse>(
          ctx, 'NushiService', 'SetSettings', request, SetSettingsResponse());

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
  /// included, or everything since its branch left a base, or what commits
  /// changed.
  $async.Future<GetDiffResponse> getDiff(
          $pb.ClientContext? ctx, GetDiffRequest request) =>
      _client.invoke<GetDiffResponse>(
          ctx, 'NushiService', 'GetDiff', request, GetDiffResponse());

  /// Lists a branch's commits since a base, or the last ones.
  $async.Future<ListCommitsResponse> listCommits(
          $pb.ClientContext? ctx, ListCommitsRequest request) =>
      _client.invoke<ListCommitsResponse>(
          ctx, 'NushiService', 'ListCommits', request, ListCommitsResponse());

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

  /// Asks the chat's agent, unseen, what fills its context (Claude's
  /// /context), in a throwaway fork of its session, while the chat is idle.
  /// Refused when the agent can't fork.
  $async.Future<GetContextUsageResponse> getContextUsage(
          $pb.ClientContext? ctx, GetContextUsageRequest request) =>
      _client.invoke<GetContextUsageResponse>(ctx, 'NushiService',
          'GetContextUsage', request, GetContextUsageResponse());

  /// Lists the MCP servers the agent's config gives a folder, read from the
  /// agent's own files, env and header values masked. With check_health, the
  /// agent connects to each and says how that went (Claude's `claude mcp list`,
  /// seconds), and servers only it knows (plugins', claude.ai connectors)
  /// are added.
  $async.Future<ListMcpServersResponse> listMcpServers(
          $pb.ClientContext? ctx, ListMcpServersRequest request) =>
      _client.invoke<ListMcpServersResponse>(ctx, 'NushiService',
          'ListMcpServers', request, ListMcpServersResponse());

  /// Add, edit and remove an MCP server in a scope ("user", "project",
  /// "local"), through the agent's own CLI; the folder names the project.
  /// Editing keeps the name and scope, and env and header values sent as
  /// "••••" keep the values they had; if the new config is refused, the old
  /// one is put back. Running chats the change reaches get
  /// status.mcp_changed.
  $async.Future<AddMcpServerResponse> addMcpServer(
          $pb.ClientContext? ctx, AddMcpServerRequest request) =>
      _client.invoke<AddMcpServerResponse>(
          ctx, 'NushiService', 'AddMcpServer', request, AddMcpServerResponse());
  $async.Future<EditMcpServerResponse> editMcpServer(
          $pb.ClientContext? ctx, EditMcpServerRequest request) =>
      _client.invoke<EditMcpServerResponse>(ctx, 'NushiService',
          'EditMcpServer', request, EditMcpServerResponse());
  $async.Future<RemoveMcpServerResponse> removeMcpServer(
          $pb.ClientContext? ctx, RemoveMcpServerRequest request) =>
      _client.invoke<RemoveMcpServerResponse>(ctx, 'NushiService',
          'RemoveMcpServer', request, RemoveMcpServerResponse());

  /// Turns a project's .mcp.json server on for the folder's project, which
  /// approves it, or off, which rejects it (Claude's
  /// enabledMcpjsonServers and disabledMcpjsonServers in the project's
  /// .claude/settings.local.json).
  $async.Future<SetMcpServerOnResponse> setMcpServerOn(
          $pb.ClientContext? ctx, SetMcpServerOnRequest request) =>
      _client.invoke<SetMcpServerOnResponse>(ctx, 'NushiService',
          'SetMcpServerOn', request, SetMcpServerOnResponse());

  /// Signs in to a server that needs OAuth: the agent opens the browser and
  /// the call returns once the sign-in is done there, or failed (a few
  /// minutes at most). Logout forgets the sign-in.
  $async.Future<LoginMcpServerResponse> loginMcpServer(
          $pb.ClientContext? ctx, LoginMcpServerRequest request) =>
      _client.invoke<LoginMcpServerResponse>(ctx, 'NushiService',
          'LoginMcpServer', request, LoginMcpServerResponse());
  $async.Future<LogoutMcpServerResponse> logoutMcpServer(
          $pb.ClientContext? ctx, LogoutMcpServerRequest request) =>
      _client.invoke<LogoutMcpServerResponse>(ctx, 'NushiService',
          'LogoutMcpServer', request, LogoutMcpServerResponse());

  /// Reopens a chat's session on a new agent (ACP session/load), which
  /// replays its transcript, so it uses the MCP servers as they are now.
  /// Refused while it is busy.
  $async.Future<ReloadChatResponse> reloadChat(
          $pb.ClientContext? ctx, ReloadChatRequest request) =>
      _client.invoke<ReloadChatResponse>(
          ctx, 'NushiService', 'ReloadChat', request, ReloadChatResponse());

  /// Opens a terminal for a chat: the user's login shell, in the chat's
  /// folder (its worktree, for a worktree chat) or in a given one. The
  /// daemon owns it, so it outlives the app, but not the daemon. Changes to
  /// a chat's terminals come as events.
  $async.Future<OpenTerminalResponse> openTerminal(
          $pb.ClientContext? ctx, OpenTerminalRequest request) =>
      _client.invoke<OpenTerminalResponse>(
          ctx, 'NushiService', 'OpenTerminal', request, OpenTerminalResponse());
  $async.Future<ListTerminalsResponse> listTerminals(
          $pb.ClientContext? ctx, ListTerminalsRequest request) =>
      _client.invoke<ListTerminalsResponse>(ctx, 'NushiService',
          'ListTerminals', request, ListTerminalsResponse());

  /// Streams a terminal's output: first what it kept (the last 1 MB, maybe
  /// empty), then new output, and a last message once its shell has exited.
  /// A client that falls far behind is cut off and attaches again.
  $async.Future<AttachTerminalResponse> attachTerminal(
          $pb.ClientContext? ctx, AttachTerminalRequest request) =>
      _client.invoke<AttachTerminalResponse>(ctx, 'NushiService',
          'AttachTerminal', request, AttachTerminalResponse());
  $async.Future<WriteTerminalResponse> writeTerminal(
          $pb.ClientContext? ctx, WriteTerminalRequest request) =>
      _client.invoke<WriteTerminalResponse>(ctx, 'NushiService',
          'WriteTerminal', request, WriteTerminalResponse());
  $async.Future<ResizeTerminalResponse> resizeTerminal(
          $pb.ClientContext? ctx, ResizeTerminalRequest request) =>
      _client.invoke<ResizeTerminalResponse>(ctx, 'NushiService',
          'ResizeTerminal', request, ResizeTerminalResponse());

  /// Names a terminal; an empty name goes back to the one it shows by
  /// itself.
  $async.Future<RenameTerminalResponse> renameTerminal(
          $pb.ClientContext? ctx, RenameTerminalRequest request) =>
      _client.invoke<RenameTerminalResponse>(ctx, 'NushiService',
          'RenameTerminal', request, RenameTerminalResponse());

  /// Puts a chat's terminals in an order.
  $async.Future<ArrangeTerminalsResponse> arrangeTerminals(
          $pb.ClientContext? ctx, ArrangeTerminalsRequest request) =>
      _client.invoke<ArrangeTerminalsResponse>(ctx, 'NushiService',
          'ArrangeTerminals', request, ArrangeTerminalsResponse());

  /// Starts a new shell in a terminal's folder in place of its old one (a
  /// shell that exited), keeping its place and name.
  $async.Future<RestartTerminalResponse> restartTerminal(
          $pb.ClientContext? ctx, RestartTerminalRequest request) =>
      _client.invoke<RestartTerminalResponse>(ctx, 'NushiService',
          'RestartTerminal', request, RestartTerminalResponse());

  /// Closes a terminal: its shell is hung up, then killed after a short
  /// grace, along with what still runs in it.
  $async.Future<CloseTerminalResponse> closeTerminal(
          $pb.ClientContext? ctx, CloseTerminalRequest request) =>
      _client.invoke<CloseTerminalResponse>(ctx, 'NushiService',
          'CloseTerminal', request, CloseTerminalResponse());

  /// Says what a folder brings for the agent to run on its own (MCP
  /// servers, hooks, helper commands) when neither the agent nor Nushi was
  /// told to trust it; nothing when it is trusted or brings nothing. Ask
  /// before starting or moving a chat there.
  $async.Future<CheckFolderResponse> checkFolder(
          $pb.ClientContext? ctx, CheckFolderRequest request) =>
      _client.invoke<CheckFolderResponse>(
          ctx, 'NushiService', 'CheckFolder', request, CheckFolderResponse());

  /// Remembers that the user starts chats in a folder anyway (its
  /// repository, outside git the folders under it too).
  $async.Future<TrustFolderResponse> trustFolder(
          $pb.ClientContext? ctx, TrustFolderRequest request) =>
      _client.invoke<TrustFolderResponse>(
          ctx, 'NushiService', 'TrustFolder', request, TrustFolderResponse());

  /// Remote access (ADRs 0033, 0034): how it stands, and switching it on
  /// or off through a relay.
  $async.Future<GetRemoteResponse> getRemote(
          $pb.ClientContext? ctx, GetRemoteRequest request) =>
      _client.invoke<GetRemoteResponse>(
          ctx, 'NushiService', 'GetRemote', request, GetRemoteResponse());
  $async.Future<SetRemoteResponse> setRemote(
          $pb.ClientContext? ctx, SetRemoteRequest request) =>
      _client.invoke<SetRemoteResponse>(
          ctx, 'NushiService', 'SetRemote', request, SetRemoteResponse());

  /// Starts pairing a phone (remote access must be on): the text for the QR
  /// code, good until it expires. Once a phone holding it connects,
  /// Remote.pairing has its name and the code both screens show.
  $async.Future<StartPairingResponse> startPairing(
          $pb.ClientContext? ctx, StartPairingRequest request) =>
      _client.invoke<StartPairingResponse>(
          ctx, 'NushiService', 'StartPairing', request, StartPairingResponse());

  /// Allows or denies the phone that connected, named by its code.
  $async.Future<ConfirmPairingResponse> confirmPairing(
          $pb.ClientContext? ctx, ConfirmPairingRequest request) =>
      _client.invoke<ConfirmPairingResponse>(ctx, 'NushiService',
          'ConfirmPairing', request, ConfirmPairingResponse());

  /// Unpairs a phone and drops its connections.
  $async.Future<RevokeDeviceResponse> revokeDevice(
          $pb.ClientContext? ctx, RevokeDeviceRequest request) =>
      _client.invoke<RevokeDeviceResponse>(
          ctx, 'NushiService', 'RevokeDevice', request, RevokeDeviceResponse());

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
