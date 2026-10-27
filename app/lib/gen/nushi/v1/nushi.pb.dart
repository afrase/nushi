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
    $core.Iterable<RemovedChat>? removed,
  }) {
    final result = ListChatsResponse._();
    if (chats != null) result.chats.addAll(chats);
    if (removed != null) result.removed.addAll(removed);
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
    ..pPM<RemovedChat>(2, _omitFieldNames ? '' : 'removed',
        subBuilder: RemovedChat.$_createMessage)
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

  /// Chats the daemon removed since it started because their agent no
  /// longer has their sessions (Claude Code deletes old ones), until
  /// DismissRemovedChats; oldest first.
  @$pb.TagNumber(2)
  $pb.PbList<RemovedChat> get removed => $_getList(1);
}

/// A chat the daemon removed, its agent having deleted its session: what
/// Nushi kept of it. Its worktree and branch, if any, stay.
class RemovedChat extends $pb.GeneratedMessage {
  factory RemovedChat({
    $core.String? id,
    $core.String? agent,
    $core.String? title,
    $core.String? folder,
    $fixnum.Int64? removedUnixMs,
  }) {
    final result = RemovedChat._();
    if (id != null) result.id = id;
    if (agent != null) result.agent = agent;
    if (title != null) result.title = title;
    if (folder != null) result.folder = folder;
    if (removedUnixMs != null) result.removedUnixMs = removedUnixMs;
    return result;
  }

  RemovedChat._();

  factory RemovedChat.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemovedChat()..mergeFromBuffer(data, registry);
  factory RemovedChat.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemovedChat()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemovedChat',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemovedChat.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'agent')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'folder')
    ..aInt64(5, _omitFieldNames ? '' : 'removedUnixMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovedChat clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovedChat copyWith(void Function(RemovedChat) updates) =>
      super.copyWith((message) => updates(message as RemovedChat))
          as RemovedChat;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemovedChat() / RemovedChat.new instead')
  static RemovedChat create() => RemovedChat._();
  static $pb.GeneratedMessage $_createMessage() => RemovedChat._();
  @$core.override
  RemovedChat createEmptyInstance() => RemovedChat._();
  @$core.pragma('dart2js:noInline')
  static RemovedChat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemovedChat>(
          RemovedChat.$_createMessage);
  static RemovedChat? _defaultInstance;

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
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get folder => $_getSZ(3);
  @$pb.TagNumber(4)
  set folder($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasFolder() => $_has(3);
  @$pb.TagNumber(4)
  void clearFolder() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get removedUnixMs => $_getI64(4);
  @$pb.TagNumber(5)
  set removedUnixMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRemovedUnixMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemovedUnixMs() => $_clearField(5);
}

class RemovedChats extends $pb.GeneratedMessage {
  factory RemovedChats({
    $core.Iterable<RemovedChat>? chats,
  }) {
    final result = RemovedChats._();
    if (chats != null) result.chats.addAll(chats);
    return result;
  }

  RemovedChats._();

  factory RemovedChats.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemovedChats()..mergeFromBuffer(data, registry);
  factory RemovedChats.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemovedChats()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemovedChats',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemovedChats.$_createMessage)
    ..pPM<RemovedChat>(1, _omitFieldNames ? '' : 'chats',
        subBuilder: RemovedChat.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovedChats clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemovedChats copyWith(void Function(RemovedChats) updates) =>
      super.copyWith((message) => updates(message as RemovedChats))
          as RemovedChats;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemovedChats() / RemovedChats.new instead')
  static RemovedChats create() => RemovedChats._();
  static $pb.GeneratedMessage $_createMessage() => RemovedChats._();
  @$core.override
  RemovedChats createEmptyInstance() => RemovedChats._();
  @$core.pragma('dart2js:noInline')
  static RemovedChats getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<RemovedChats>(
          RemovedChats.$_createMessage);
  static RemovedChats? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<RemovedChat> get chats => $_getList(0);
}

class DismissRemovedChatsRequest extends $pb.GeneratedMessage {
  factory DismissRemovedChatsRequest({
    $core.Iterable<$core.String>? ids,
  }) {
    final result = DismissRemovedChatsRequest._();
    if (ids != null) result.ids.addAll(ids);
    return result;
  }

  DismissRemovedChatsRequest._();

  factory DismissRemovedChatsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissRemovedChatsRequest()..mergeFromBuffer(data, registry);
  factory DismissRemovedChatsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissRemovedChatsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DismissRemovedChatsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: DismissRemovedChatsRequest.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'ids')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissRemovedChatsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissRemovedChatsRequest copyWith(
          void Function(DismissRemovedChatsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as DismissRemovedChatsRequest))
          as DismissRemovedChatsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DismissRemovedChatsRequest() / DismissRemovedChatsRequest.new instead')
  static DismissRemovedChatsRequest create() => DismissRemovedChatsRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      DismissRemovedChatsRequest._();
  @$core.override
  DismissRemovedChatsRequest createEmptyInstance() =>
      DismissRemovedChatsRequest._();
  @$core.pragma('dart2js:noInline')
  static DismissRemovedChatsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DismissRemovedChatsRequest>(
          DismissRemovedChatsRequest.$_createMessage);
  static DismissRemovedChatsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get ids => $_getList(0);
}

class DismissRemovedChatsResponse extends $pb.GeneratedMessage {
  factory DismissRemovedChatsResponse() => DismissRemovedChatsResponse._();

  DismissRemovedChatsResponse._();

  factory DismissRemovedChatsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissRemovedChatsResponse()..mergeFromBuffer(data, registry);
  factory DismissRemovedChatsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      DismissRemovedChatsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DismissRemovedChatsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: DismissRemovedChatsResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissRemovedChatsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DismissRemovedChatsResponse copyWith(
          void Function(DismissRemovedChatsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as DismissRemovedChatsResponse))
          as DismissRemovedChatsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use DismissRemovedChatsResponse() / DismissRemovedChatsResponse.new instead')
  static DismissRemovedChatsResponse create() =>
      DismissRemovedChatsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      DismissRemovedChatsResponse._();
  @$core.override
  DismissRemovedChatsResponse createEmptyInstance() =>
      DismissRemovedChatsResponse._();
  @$core.pragma('dart2js:noInline')
  static DismissRemovedChatsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DismissRemovedChatsResponse>(
          DismissRemovedChatsResponse.$_createMessage);
  static DismissRemovedChatsResponse? _defaultInstance;
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
    $core.String? jiraSite,
    $core.String? jiraKey,
    GitHubLink? github,
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
    if (jiraSite != null) result.jiraSite = jiraSite;
    if (jiraKey != null) result.jiraKey = jiraKey;
    if (github != null) result.github = github;
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
    ..aOS(12, _omitFieldNames ? '' : 'jiraSite')
    ..aOS(13, _omitFieldNames ? '' : 'jiraKey')
    ..aOM<GitHubLink>(14, _omitFieldNames ? '' : 'github',
        subBuilder: GitHubLink.$_createMessage)
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

  /// The Jira issue it was started from, if it was.
  @$pb.TagNumber(12)
  $core.String get jiraSite => $_getSZ(11);
  @$pb.TagNumber(12)
  set jiraSite($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasJiraSite() => $_has(11);
  @$pb.TagNumber(12)
  void clearJiraSite() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get jiraKey => $_getSZ(12);
  @$pb.TagNumber(13)
  set jiraKey($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasJiraKey() => $_has(12);
  @$pb.TagNumber(13)
  void clearJiraKey() => $_clearField(13);

  /// The GitHub pull request or issue it was started from, if it was.
  @$pb.TagNumber(14)
  GitHubLink get github => $_getN(13);
  @$pb.TagNumber(14)
  set github(GitHubLink value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasGithub() => $_has(13);
  @$pb.TagNumber(14)
  void clearGithub() => $_clearField(14);
  @$pb.TagNumber(14)
  GitHubLink ensureGithub() => $_ensure(13);
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

  /// Its branch: nushi/<two words> at first, named after the chat once it
  /// has a title (between turns, unless pushed or renamed), or as the user
  /// renamed it (RenameBranch).
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
    $core.int? recent,
  }) {
    final result = GetChatRequest._();
    if (chatId != null) result.chatId = chatId;
    if (recent != null) result.recent = recent;
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
    ..aI(2, _omitFieldNames ? '' : 'recent')
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

  /// Only the last this many items (0: all), reaching back to the tool call
  /// that started a subagent whose steps are among them; `older` counts
  /// the ones left out. A phone on a slow link opens a long chat this way.
  @$pb.TagNumber(2)
  $core.int get recent => $_getIZ(1);
  @$pb.TagNumber(2)
  set recent($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRecent() => $_has(1);
  @$pb.TagNumber(2)
  void clearRecent() => $_clearField(2);
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
    $core.int? older,
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
    if (older != null) result.older = older;
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
    ..aI(9, _omitFieldNames ? '' : 'older')
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

  /// How many items come before `items` (with `recent`).
  @$pb.TagNumber(9)
  $core.int get older => $_getIZ(8);
  @$pb.TagNumber(9)
  set older($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOlder() => $_has(8);
  @$pb.TagNumber(9)
  void clearOlder() => $_clearField(9);
}

class GetChatItemsRequest extends $pb.GeneratedMessage {
  factory GetChatItemsRequest({
    $core.String? chatId,
    $core.String? before,
    $core.int? limit,
  }) {
    final result = GetChatItemsRequest._();
    if (chatId != null) result.chatId = chatId;
    if (before != null) result.before = before;
    if (limit != null) result.limit = limit;
    return result;
  }

  GetChatItemsRequest._();

  factory GetChatItemsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatItemsRequest()..mergeFromBuffer(data, registry);
  factory GetChatItemsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatItemsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetChatItemsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetChatItemsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'before')
    ..aI(3, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatItemsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatItemsRequest copyWith(void Function(GetChatItemsRequest) updates) =>
      super.copyWith((message) => updates(message as GetChatItemsRequest))
          as GetChatItemsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use GetChatItemsRequest() / GetChatItemsRequest.new instead')
  static GetChatItemsRequest create() => GetChatItemsRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetChatItemsRequest._();
  @$core.override
  GetChatItemsRequest createEmptyInstance() => GetChatItemsRequest._();
  @$core.pragma('dart2js:noInline')
  static GetChatItemsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetChatItemsRequest>(
          GetChatItemsRequest.$_createMessage);
  static GetChatItemsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  /// The item the page ends before (the first one the client has).
  @$pb.TagNumber(2)
  $core.String get before => $_getSZ(1);
  @$pb.TagNumber(2)
  set before($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBefore() => $_has(1);
  @$pb.TagNumber(2)
  void clearBefore() => $_clearField(2);

  /// How many items at most, reaching back to a subagent's call as
  /// `recent` does.
  @$pb.TagNumber(3)
  $core.int get limit => $_getIZ(2);
  @$pb.TagNumber(3)
  set limit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimit() => $_clearField(3);
}

class GetChatItemsResponse extends $pb.GeneratedMessage {
  factory GetChatItemsResponse({
    $core.Iterable<Item>? items,
    $core.int? older,
  }) {
    final result = GetChatItemsResponse._();
    if (items != null) result.items.addAll(items);
    if (older != null) result.older = older;
    return result;
  }

  GetChatItemsResponse._();

  factory GetChatItemsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatItemsResponse()..mergeFromBuffer(data, registry);
  factory GetChatItemsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetChatItemsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetChatItemsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetChatItemsResponse.$_createMessage)
    ..pPM<Item>(1, _omitFieldNames ? '' : 'items',
        subBuilder: Item.$_createMessage)
    ..aI(2, _omitFieldNames ? '' : 'older')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatItemsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetChatItemsResponse copyWith(void Function(GetChatItemsResponse) updates) =>
      super.copyWith((message) => updates(message as GetChatItemsResponse))
          as GetChatItemsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetChatItemsResponse() / GetChatItemsResponse.new instead')
  static GetChatItemsResponse create() => GetChatItemsResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetChatItemsResponse._();
  @$core.override
  GetChatItemsResponse createEmptyInstance() => GetChatItemsResponse._();
  @$core.pragma('dart2js:noInline')
  static GetChatItemsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetChatItemsResponse>(
          GetChatItemsResponse.$_createMessage);
  static GetChatItemsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Item> get items => $_getList(0);

  /// How many items come before these.
  @$pb.TagNumber(2)
  $core.int get older => $_getIZ(1);
  @$pb.TagNumber(2)
  set older($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOlder() => $_has(1);
  @$pb.TagNumber(2)
  void clearOlder() => $_clearField(2);
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
  factory ListAgentsRequest({
    $core.bool? refreshEnvironment,
    $core.bool? reloadEnvironment,
  }) {
    final result = ListAgentsRequest._();
    if (refreshEnvironment != null)
      result.refreshEnvironment = refreshEnvironment;
    if (reloadEnvironment != null) result.reloadEnvironment = reloadEnvironment;
    return result;
  }

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
    ..aOB(1, _omitFieldNames ? '' : 'refreshEnvironment')
    ..aOB(2, _omitFieldNames ? '' : 'reloadEnvironment')
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

  /// Read the login shell's environment, which agents start with, again
  /// first when the last reading is over a minute old (Settings › Agents
  /// opening; ADR 0048).
  @$pb.TagNumber(1)
  $core.bool get refreshEnvironment => $_getBF(0);
  @$pb.TagNumber(1)
  set refreshEnvironment($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefreshEnvironment() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefreshEnvironment() => $_clearField(1);

  /// Read it again now, whatever its age (Settings › Agents › Reload).
  @$pb.TagNumber(2)
  $core.bool get reloadEnvironment => $_getBF(1);
  @$pb.TagNumber(2)
  set reloadEnvironment($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReloadEnvironment() => $_has(1);
  @$pb.TagNumber(2)
  void clearReloadEnvironment() => $_clearField(2);
}

class ListAgentsResponse extends $pb.GeneratedMessage {
  factory ListAgentsResponse({
    $core.Iterable<Agent>? agents,
    ShellEnvironment? environment,
  }) {
    final result = ListAgentsResponse._();
    if (agents != null) result.agents.addAll(agents);
    if (environment != null) result.environment = environment;
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
    ..aOM<ShellEnvironment>(2, _omitFieldNames ? '' : 'environment',
        subBuilder: ShellEnvironment.$_createMessage)
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

  /// How reading the login shell's environment went last; unset when
  /// agents get the daemon's own. Nothing of the environment itself.
  @$pb.TagNumber(2)
  ShellEnvironment get environment => $_getN(1);
  @$pb.TagNumber(2)
  set environment(ShellEnvironment value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasEnvironment() => $_has(1);
  @$pb.TagNumber(2)
  void clearEnvironment() => $_clearField(2);
  @$pb.TagNumber(2)
  ShellEnvironment ensureEnvironment() => $_ensure(1);
}

/// How the daemon last read the login shell's environment (ADR 0048).
class ShellEnvironment extends $pb.GeneratedMessage {
  factory ShellEnvironment({
    $core.String? shell,
    $fixnum.Int64? readUnixMs,
    $core.String? problem,
  }) {
    final result = ShellEnvironment._();
    if (shell != null) result.shell = shell;
    if (readUnixMs != null) result.readUnixMs = readUnixMs;
    if (problem != null) result.problem = problem;
    return result;
  }

  ShellEnvironment._();

  factory ShellEnvironment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShellEnvironment()..mergeFromBuffer(data, registry);
  factory ShellEnvironment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ShellEnvironment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShellEnvironment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ShellEnvironment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'shell')
    ..aInt64(2, _omitFieldNames ? '' : 'readUnixMs')
    ..aOS(3, _omitFieldNames ? '' : 'problem')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShellEnvironment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShellEnvironment copyWith(void Function(ShellEnvironment) updates) =>
      super.copyWith((message) => updates(message as ShellEnvironment))
          as ShellEnvironment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ShellEnvironment() / ShellEnvironment.new instead')
  static ShellEnvironment create() => ShellEnvironment._();
  static $pb.GeneratedMessage $_createMessage() => ShellEnvironment._();
  @$core.override
  ShellEnvironment createEmptyInstance() => ShellEnvironment._();
  @$core.pragma('dart2js:noInline')
  static ShellEnvironment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShellEnvironment>(
          ShellEnvironment.$_createMessage);
  static ShellEnvironment? _defaultInstance;

  /// The shell it ran: "/opt/homebrew/bin/fish".
  @$pb.TagNumber(1)
  $core.String get shell => $_getSZ(0);
  @$pb.TagNumber(1)
  set shell($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasShell() => $_has(0);
  @$pb.TagNumber(1)
  void clearShell() => $_clearField(1);

  /// When the reading ended, worked or not.
  @$pb.TagNumber(2)
  $fixnum.Int64 get readUnixMs => $_getI64(1);
  @$pb.TagNumber(2)
  set readUnixMs($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReadUnixMs() => $_has(1);
  @$pb.TagNumber(2)
  void clearReadUnixMs() => $_clearField(2);

  /// Why it failed ("fish took over 5s"); empty when it worked. Agents
  /// then start with the last reading that worked, else the daemon's own.
  @$pb.TagNumber(3)
  $core.String get problem => $_getSZ(2);
  @$pb.TagNumber(3)
  set problem($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProblem() => $_has(2);
  @$pb.TagNumber(3)
  void clearProblem() => $_clearField(3);
}

/// An agent chats can run.
class Agent extends $pb.GeneratedMessage {
  factory Agent({
    $core.String? name,
    $core.String? title,
    $core.String? resume,
    $core.bool? mcp,
    $core.bool? deleteArchives,
    $core.String? path,
    $core.String? version,
    $core.String? page,
    $core.String? problem,
    $core.String? signedIn,
    Adapter? adapter,
    $core.bool? ready,
    $core.int? awake,
  }) {
    final result = Agent._();
    if (name != null) result.name = name;
    if (title != null) result.title = title;
    if (resume != null) result.resume = resume;
    if (mcp != null) result.mcp = mcp;
    if (deleteArchives != null) result.deleteArchives = deleteArchives;
    if (path != null) result.path = path;
    if (version != null) result.version = version;
    if (page != null) result.page = page;
    if (problem != null) result.problem = problem;
    if (signedIn != null) result.signedIn = signedIn;
    if (adapter != null) result.adapter = adapter;
    if (ready != null) result.ready = ready;
    if (awake != null) result.awake = awake;
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
    ..aOS(6, _omitFieldNames ? '' : 'path')
    ..aOS(7, _omitFieldNames ? '' : 'version')
    ..aOS(8, _omitFieldNames ? '' : 'page')
    ..aOS(9, _omitFieldNames ? '' : 'problem')
    ..aOS(10, _omitFieldNames ? '' : 'signedIn')
    ..aOM<Adapter>(11, _omitFieldNames ? '' : 'adapter',
        subBuilder: Adapter.$_createMessage)
    ..aOB(12, _omitFieldNames ? '' : 'ready')
    ..aI(13, _omitFieldNames ? '' : 'awake')
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

  /// Its CLI, as found on the login shell's PATH (or where its installer
  /// puts it); empty when it isn't installed.
  @$pb.TagNumber(6)
  $core.String get path => $_getSZ(5);
  @$pb.TagNumber(6)
  set path($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPath() => $_has(5);
  @$pb.TagNumber(6)
  void clearPath() => $_clearField(6);

  /// The CLI's version, as it says it; empty when that couldn't be read.
  @$pb.TagNumber(7)
  $core.String get version => $_getSZ(6);
  @$pb.TagNumber(7)
  set version($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearVersion() => $_clearField(7);

  /// Where to get it.
  @$pb.TagNumber(8)
  $core.String get page => $_getSZ(7);
  @$pb.TagNumber(8)
  set page($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPage() => $_has(7);
  @$pb.TagNumber(8)
  void clearPage() => $_clearField(8);

  /// Why it can't run, in a few words ("Not installed", "Needs Bun");
  /// empty when it can.
  @$pb.TagNumber(9)
  $core.String get problem => $_getSZ(8);
  @$pb.TagNumber(9)
  set problem($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasProblem() => $_has(8);
  @$pb.TagNumber(9)
  void clearProblem() => $_clearField(9);

  /// Whether the CLI is signed in, "yes" or "no", when it can tell
  /// cheaply; empty otherwise.
  @$pb.TagNumber(10)
  $core.String get signedIn => $_getSZ(9);
  @$pb.TagNumber(10)
  set signedIn($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasSignedIn() => $_has(9);
  @$pb.TagNumber(10)
  void clearSignedIn() => $_clearField(10);

  /// The npm package its ACP side comes in, when it needs one.
  @$pb.TagNumber(11)
  Adapter get adapter => $_getN(10);
  @$pb.TagNumber(11)
  set adapter(Adapter value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasAdapter() => $_has(10);
  @$pb.TagNumber(11)
  void clearAdapter() => $_clearField(11);
  @$pb.TagNumber(11)
  Adapter ensureAdapter() => $_ensure(10);

  /// A chat can start: it's installed, has what it needs, and its adapter
  /// (if any) is set up.
  @$pb.TagNumber(12)
  $core.bool get ready => $_getBF(11);
  @$pb.TagNumber(12)
  set ready($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasReady() => $_has(11);
  @$pb.TagNumber(12)
  void clearReady() => $_clearField(12);

  /// Its chats whose agent runs (they sleep when the adapter changes).
  @$pb.TagNumber(13)
  $core.int get awake => $_getIZ(12);
  @$pb.TagNumber(13)
  set awake($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAwake() => $_has(12);
  @$pb.TagNumber(13)
  void clearAwake() => $_clearField(13);
}

/// An agent's adapter.
class Adapter extends $pb.GeneratedMessage {
  factory Adapter({
    $core.String? package,
    $core.String? pinned,
    $core.String? installed,
    $core.int? packages,
    $fixnum.Int64? downloadBytes,
    $fixnum.Int64? diskBytes,
    $core.String? folder,
  }) {
    final result = Adapter._();
    if (package != null) result.package = package;
    if (pinned != null) result.pinned = pinned;
    if (installed != null) result.installed = installed;
    if (packages != null) result.packages = packages;
    if (downloadBytes != null) result.downloadBytes = downloadBytes;
    if (diskBytes != null) result.diskBytes = diskBytes;
    if (folder != null) result.folder = folder;
    return result;
  }

  Adapter._();

  factory Adapter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Adapter()..mergeFromBuffer(data, registry);
  factory Adapter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Adapter()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Adapter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Adapter.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'package')
    ..aOS(2, _omitFieldNames ? '' : 'pinned')
    ..aOS(3, _omitFieldNames ? '' : 'installed')
    ..aI(4, _omitFieldNames ? '' : 'packages')
    ..aInt64(5, _omitFieldNames ? '' : 'downloadBytes')
    ..aInt64(6, _omitFieldNames ? '' : 'diskBytes')
    ..aOS(7, _omitFieldNames ? '' : 'folder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Adapter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Adapter copyWith(void Function(Adapter) updates) =>
      super.copyWith((message) => updates(message as Adapter)) as Adapter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Adapter() / Adapter.new instead')
  static Adapter create() => Adapter._();
  static $pb.GeneratedMessage $_createMessage() => Adapter._();
  @$core.override
  Adapter createEmptyInstance() => Adapter._();
  @$core.pragma('dart2js:noInline')
  static Adapter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Adapter>(Adapter.$_createMessage);
  static Adapter? _defaultInstance;

  /// "@agentclientprotocol/claude-agent-acp".
  @$pb.TagNumber(1)
  $core.String get package => $_getSZ(0);
  @$pb.TagNumber(1)
  set package($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPackage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPackage() => $_clearField(1);

  /// The version Nushi pins, and the one set up (empty when it isn't).
  @$pb.TagNumber(2)
  $core.String get pinned => $_getSZ(1);
  @$pb.TagNumber(2)
  set pinned($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPinned() => $_has(1);
  @$pb.TagNumber(2)
  void clearPinned() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get installed => $_getSZ(2);
  @$pb.TagNumber(3)
  set installed($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasInstalled() => $_has(2);
  @$pb.TagNumber(3)
  void clearInstalled() => $_clearField(3);

  /// How many packages it installs, the adapter's included.
  @$pb.TagNumber(4)
  $core.int get packages => $_getIZ(3);
  @$pb.TagNumber(4)
  set packages($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPackages() => $_has(3);
  @$pb.TagNumber(4)
  void clearPackages() => $_clearField(4);

  /// About how much it downloads, and takes on disk, in bytes.
  @$pb.TagNumber(5)
  $fixnum.Int64 get downloadBytes => $_getI64(4);
  @$pb.TagNumber(5)
  set downloadBytes($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDownloadBytes() => $_has(4);
  @$pb.TagNumber(5)
  void clearDownloadBytes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get diskBytes => $_getI64(5);
  @$pb.TagNumber(6)
  set diskBytes($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDiskBytes() => $_has(5);
  @$pb.TagNumber(6)
  void clearDiskBytes() => $_clearField(6);

  /// Where it goes.
  @$pb.TagNumber(7)
  $core.String get folder => $_getSZ(6);
  @$pb.TagNumber(7)
  set folder($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFolder() => $_has(6);
  @$pb.TagNumber(7)
  void clearFolder() => $_clearField(7);
}

class SetUpAgentRequest extends $pb.GeneratedMessage {
  factory SetUpAgentRequest({
    $core.String? agent,
  }) {
    final result = SetUpAgentRequest._();
    if (agent != null) result.agent = agent;
    return result;
  }

  SetUpAgentRequest._();

  factory SetUpAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetUpAgentRequest()..mergeFromBuffer(data, registry);
  factory SetUpAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetUpAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetUpAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetUpAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetUpAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetUpAgentRequest copyWith(void Function(SetUpAgentRequest) updates) =>
      super.copyWith((message) => updates(message as SetUpAgentRequest))
          as SetUpAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetUpAgentRequest() / SetUpAgentRequest.new instead')
  static SetUpAgentRequest create() => SetUpAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetUpAgentRequest._();
  @$core.override
  SetUpAgentRequest createEmptyInstance() => SetUpAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static SetUpAgentRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetUpAgentRequest>(
          SetUpAgentRequest.$_createMessage);
  static SetUpAgentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agent => $_getSZ(0);
  @$pb.TagNumber(1)
  set agent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgent() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgent() => $_clearField(1);
}

class SetUpAgentResponse extends $pb.GeneratedMessage {
  factory SetUpAgentResponse() => SetUpAgentResponse._();

  SetUpAgentResponse._();

  factory SetUpAgentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetUpAgentResponse()..mergeFromBuffer(data, registry);
  factory SetUpAgentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetUpAgentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetUpAgentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetUpAgentResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetUpAgentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetUpAgentResponse copyWith(void Function(SetUpAgentResponse) updates) =>
      super.copyWith((message) => updates(message as SetUpAgentResponse))
          as SetUpAgentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetUpAgentResponse() / SetUpAgentResponse.new instead')
  static SetUpAgentResponse create() => SetUpAgentResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetUpAgentResponse._();
  @$core.override
  SetUpAgentResponse createEmptyInstance() => SetUpAgentResponse._();
  @$core.pragma('dart2js:noInline')
  static SetUpAgentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetUpAgentResponse>(
          SetUpAgentResponse.$_createMessage);
  static SetUpAgentResponse? _defaultInstance;
}

class RemoveAgentRequest extends $pb.GeneratedMessage {
  factory RemoveAgentRequest({
    $core.String? agent,
  }) {
    final result = RemoveAgentRequest._();
    if (agent != null) result.agent = agent;
    return result;
  }

  RemoveAgentRequest._();

  factory RemoveAgentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveAgentRequest()..mergeFromBuffer(data, registry);
  factory RemoveAgentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveAgentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveAgentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveAgentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveAgentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveAgentRequest copyWith(void Function(RemoveAgentRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveAgentRequest))
          as RemoveAgentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use RemoveAgentRequest() / RemoveAgentRequest.new instead')
  static RemoveAgentRequest create() => RemoveAgentRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveAgentRequest._();
  @$core.override
  RemoveAgentRequest createEmptyInstance() => RemoveAgentRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveAgentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveAgentRequest>(
          RemoveAgentRequest.$_createMessage);
  static RemoveAgentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agent => $_getSZ(0);
  @$pb.TagNumber(1)
  set agent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgent() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgent() => $_clearField(1);
}

class RemoveAgentResponse extends $pb.GeneratedMessage {
  factory RemoveAgentResponse() => RemoveAgentResponse._();

  RemoveAgentResponse._();

  factory RemoveAgentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveAgentResponse()..mergeFromBuffer(data, registry);
  factory RemoveAgentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveAgentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveAgentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveAgentResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveAgentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveAgentResponse copyWith(void Function(RemoveAgentResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveAgentResponse))
          as RemoveAgentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RemoveAgentResponse() / RemoveAgentResponse.new instead')
  static RemoveAgentResponse create() => RemoveAgentResponse._();
  static $pb.GeneratedMessage $_createMessage() => RemoveAgentResponse._();
  @$core.override
  RemoveAgentResponse createEmptyInstance() => RemoveAgentResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveAgentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveAgentResponse>(
          RemoveAgentResponse.$_createMessage);
  static RemoveAgentResponse? _defaultInstance;
}

class StartChatRequest extends $pb.GeneratedMessage {
  factory StartChatRequest({
    $core.String? folder,
    $core.bool? worktree,
    $core.String? agent,
    $core.String? jiraSite,
    $core.String? jiraKey,
    $core.String? branch,
    GitHubLink? github,
  }) {
    final result = StartChatRequest._();
    if (folder != null) result.folder = folder;
    if (worktree != null) result.worktree = worktree;
    if (agent != null) result.agent = agent;
    if (jiraSite != null) result.jiraSite = jiraSite;
    if (jiraKey != null) result.jiraKey = jiraKey;
    if (branch != null) result.branch = branch;
    if (github != null) result.github = github;
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
    ..aOS(4, _omitFieldNames ? '' : 'jiraSite')
    ..aOS(5, _omitFieldNames ? '' : 'jiraKey')
    ..aOS(6, _omitFieldNames ? '' : 'branch')
    ..aOM<GitHubLink>(7, _omitFieldNames ? '' : 'github',
        subBuilder: GitHubLink.$_createMessage)
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

  /// A chat on a Jira issue (FindJiraIssues), which it remembers; its
  /// agent's Jira tools say which issue it is.
  @$pb.TagNumber(4)
  $core.String get jiraSite => $_getSZ(3);
  @$pb.TagNumber(4)
  set jiraSite($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasJiraSite() => $_has(3);
  @$pb.TagNumber(4)
  void clearJiraSite() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get jiraKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set jiraKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasJiraKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearJiraKey() => $_clearField(5);

  /// The worktree's branch, if not one of Nushi's (a name git takes).
  @$pb.TagNumber(6)
  $core.String get branch => $_getSZ(5);
  @$pb.TagNumber(6)
  set branch($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBranch() => $_has(5);
  @$pb.TagNumber(6)
  void clearBranch() => $_clearField(6);

  /// A chat on a GitHub pull request or issue, which it remembers. A pull
  /// request's worktree starts from its head, fetched from the folder's
  /// remote that is its repository (a fork's from refs/pull/<n>/head), on
  /// its head's branch (a fork's: pr-<n>-<head>); branch is then unused.
  @$pb.TagNumber(7)
  GitHubLink get github => $_getN(6);
  @$pb.TagNumber(7)
  set github(GitHubLink value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasGithub() => $_has(6);
  @$pb.TagNumber(7)
  void clearGithub() => $_clearField(7);
  @$pb.TagNumber(7)
  GitHubLink ensureGithub() => $_ensure(6);
}

class ListAgentSessionsRequest extends $pb.GeneratedMessage {
  factory ListAgentSessionsRequest({
    $core.String? agent,
    $core.String? folder,
    $core.String? cursor,
  }) {
    final result = ListAgentSessionsRequest._();
    if (agent != null) result.agent = agent;
    if (folder != null) result.folder = folder;
    if (cursor != null) result.cursor = cursor;
    return result;
  }

  ListAgentSessionsRequest._();

  factory ListAgentSessionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentSessionsRequest()..mergeFromBuffer(data, registry);
  factory ListAgentSessionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentSessionsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAgentSessionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListAgentSessionsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agent')
    ..aOS(2, _omitFieldNames ? '' : 'folder')
    ..aOS(3, _omitFieldNames ? '' : 'cursor')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentSessionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentSessionsRequest copyWith(
          void Function(ListAgentSessionsRequest) updates) =>
      super.copyWith((message) => updates(message as ListAgentSessionsRequest))
          as ListAgentSessionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListAgentSessionsRequest() / ListAgentSessionsRequest.new instead')
  static ListAgentSessionsRequest create() => ListAgentSessionsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListAgentSessionsRequest._();
  @$core.override
  ListAgentSessionsRequest createEmptyInstance() =>
      ListAgentSessionsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListAgentSessionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAgentSessionsRequest>(
          ListAgentSessionsRequest.$_createMessage);
  static ListAgentSessionsRequest? _defaultInstance;

  /// Agent.name; empty for the default.
  @$pb.TagNumber(1)
  $core.String get agent => $_getSZ(0);
  @$pb.TagNumber(1)
  set agent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgent() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgent() => $_clearField(1);

  /// Empty: every folder's.
  @$pb.TagNumber(2)
  $core.String get folder => $_getSZ(1);
  @$pb.TagNumber(2)
  set folder($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFolder() => $_has(1);
  @$pb.TagNumber(2)
  void clearFolder() => $_clearField(2);

  /// The last page's next_cursor, for the page after it.
  @$pb.TagNumber(3)
  $core.String get cursor => $_getSZ(2);
  @$pb.TagNumber(3)
  set cursor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCursor() => $_has(2);
  @$pb.TagNumber(3)
  void clearCursor() => $_clearField(3);
}

class ListAgentSessionsResponse extends $pb.GeneratedMessage {
  factory ListAgentSessionsResponse({
    $core.bool? canList,
    $core.Iterable<FoundSession>? sessions,
    $core.String? nextCursor,
    $core.bool? seesOpen,
    $core.bool? oneWriter,
  }) {
    final result = ListAgentSessionsResponse._();
    if (canList != null) result.canList = canList;
    if (sessions != null) result.sessions.addAll(sessions);
    if (nextCursor != null) result.nextCursor = nextCursor;
    if (seesOpen != null) result.seesOpen = seesOpen;
    if (oneWriter != null) result.oneWriter = oneWriter;
    return result;
  }

  ListAgentSessionsResponse._();

  factory ListAgentSessionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentSessionsResponse()..mergeFromBuffer(data, registry);
  factory ListAgentSessionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListAgentSessionsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAgentSessionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListAgentSessionsResponse.$_createMessage)
    ..aOB(1, _omitFieldNames ? '' : 'canList')
    ..pPM<FoundSession>(2, _omitFieldNames ? '' : 'sessions',
        subBuilder: FoundSession.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'nextCursor')
    ..aOB(4, _omitFieldNames ? '' : 'seesOpen')
    ..aOB(5, _omitFieldNames ? '' : 'oneWriter')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentSessionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAgentSessionsResponse copyWith(
          void Function(ListAgentSessionsResponse) updates) =>
      super.copyWith((message) => updates(message as ListAgentSessionsResponse))
          as ListAgentSessionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListAgentSessionsResponse() / ListAgentSessionsResponse.new instead')
  static ListAgentSessionsResponse create() => ListAgentSessionsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      ListAgentSessionsResponse._();
  @$core.override
  ListAgentSessionsResponse createEmptyInstance() =>
      ListAgentSessionsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListAgentSessionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAgentSessionsResponse>(
          ListAgentSessionsResponse.$_createMessage);
  static ListAgentSessionsResponse? _defaultInstance;

  /// The agent lists its sessions (and reopens them); without, there are none.
  @$pb.TagNumber(1)
  $core.bool get canList => $_getBF(0);
  @$pb.TagNumber(1)
  set canList($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCanList() => $_has(0);
  @$pb.TagNumber(1)
  void clearCanList() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<FoundSession> get sessions => $_getList(1);

  /// Empty at the end.
  @$pb.TagNumber(3)
  $core.String get nextCursor => $_getSZ(2);
  @$pb.TagNumber(3)
  set nextCursor($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNextCursor() => $_has(2);
  @$pb.TagNumber(3)
  void clearNextCursor() => $_clearField(3);

  /// Nushi can tell when one of this agent's sessions is open elsewhere
  /// (FoundSession.open_in); without, it can't know.
  @$pb.TagNumber(4)
  $core.bool get seesOpen => $_getBF(3);
  @$pb.TagNumber(4)
  set seesOpen($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSeesOpen() => $_has(3);
  @$pb.TagNumber(4)
  void clearSeesOpen() => $_clearField(4);

  /// The agent lets one app at a time write to a session: one open
  /// elsewhere can't be opened until it's closed there (Codex).
  @$pb.TagNumber(5)
  $core.bool get oneWriter => $_getBF(4);
  @$pb.TagNumber(5)
  set oneWriter($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasOneWriter() => $_has(4);
  @$pb.TagNumber(5)
  void clearOneWriter() => $_clearField(5);
}

/// One of an agent's sessions that isn't a chat.
class FoundSession extends $pb.GeneratedMessage {
  factory FoundSession({
    $core.String? sessionId,
    $core.String? title,
    $core.String? folder,
    $fixnum.Int64? updatedUnixMs,
    $core.int? messages,
    $core.String? openIn,
    $core.bool? folderGone,
  }) {
    final result = FoundSession._();
    if (sessionId != null) result.sessionId = sessionId;
    if (title != null) result.title = title;
    if (folder != null) result.folder = folder;
    if (updatedUnixMs != null) result.updatedUnixMs = updatedUnixMs;
    if (messages != null) result.messages = messages;
    if (openIn != null) result.openIn = openIn;
    if (folderGone != null) result.folderGone = folderGone;
    return result;
  }

  FoundSession._();

  factory FoundSession.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FoundSession()..mergeFromBuffer(data, registry);
  factory FoundSession.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FoundSession()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FoundSession',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FoundSession.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'folder')
    ..aInt64(4, _omitFieldNames ? '' : 'updatedUnixMs')
    ..aI(5, _omitFieldNames ? '' : 'messages')
    ..aOS(6, _omitFieldNames ? '' : 'openIn')
    ..aOB(7, _omitFieldNames ? '' : 'folderGone')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FoundSession clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FoundSession copyWith(void Function(FoundSession) updates) =>
      super.copyWith((message) => updates(message as FoundSession))
          as FoundSession;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FoundSession() / FoundSession.new instead')
  static FoundSession create() => FoundSession._();
  static $pb.GeneratedMessage $_createMessage() => FoundSession._();
  @$core.override
  FoundSession createEmptyInstance() => FoundSession._();
  @$core.pragma('dart2js:noInline')
  static FoundSession getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FoundSession>(
          FoundSession.$_createMessage);
  static FoundSession? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  /// Empty when the agent has none for it.
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  /// Its folder (cwd), as the agent keeps it.
  @$pb.TagNumber(3)
  $core.String get folder => $_getSZ(2);
  @$pb.TagNumber(3)
  set folder($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFolder() => $_has(2);
  @$pb.TagNumber(3)
  void clearFolder() => $_clearField(3);

  /// Its last activity; 0 when the agent doesn't say.
  @$pb.TagNumber(4)
  $fixnum.Int64 get updatedUnixMs => $_getI64(3);
  @$pb.TagNumber(4)
  set updatedUnixMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasUpdatedUnixMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearUpdatedUnixMs() => $_clearField(4);

  /// How many messages it has; 0 when the agent doesn't say.
  @$pb.TagNumber(5)
  $core.int get messages => $_getIZ(4);
  @$pb.TagNumber(5)
  set messages($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMessages() => $_has(4);
  @$pb.TagNumber(5)
  void clearMessages() => $_clearField(5);

  /// Where it is open now, outside this daemon, such as "a terminal": both
  /// would write to its history. Empty when it isn't, or can't be told.
  @$pb.TagNumber(6)
  $core.String get openIn => $_getSZ(5);
  @$pb.TagNumber(6)
  set openIn($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOpenIn() => $_has(5);
  @$pb.TagNumber(6)
  void clearOpenIn() => $_clearField(6);

  /// Its folder no longer exists: it can't be opened.
  @$pb.TagNumber(7)
  $core.bool get folderGone => $_getBF(6);
  @$pb.TagNumber(7)
  set folderGone($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasFolderGone() => $_has(6);
  @$pb.TagNumber(7)
  void clearFolderGone() => $_clearField(7);
}

class OpenAgentSessionRequest extends $pb.GeneratedMessage {
  factory OpenAgentSessionRequest({
    $core.String? agent,
    $core.String? folder,
    $core.String? sessionId,
    $core.String? title,
  }) {
    final result = OpenAgentSessionRequest._();
    if (agent != null) result.agent = agent;
    if (folder != null) result.folder = folder;
    if (sessionId != null) result.sessionId = sessionId;
    if (title != null) result.title = title;
    return result;
  }

  OpenAgentSessionRequest._();

  factory OpenAgentSessionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenAgentSessionRequest()..mergeFromBuffer(data, registry);
  factory OpenAgentSessionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenAgentSessionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenAgentSessionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: OpenAgentSessionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agent')
    ..aOS(2, _omitFieldNames ? '' : 'folder')
    ..aOS(3, _omitFieldNames ? '' : 'sessionId')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenAgentSessionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenAgentSessionRequest copyWith(
          void Function(OpenAgentSessionRequest) updates) =>
      super.copyWith((message) => updates(message as OpenAgentSessionRequest))
          as OpenAgentSessionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use OpenAgentSessionRequest() / OpenAgentSessionRequest.new instead')
  static OpenAgentSessionRequest create() => OpenAgentSessionRequest._();
  static $pb.GeneratedMessage $_createMessage() => OpenAgentSessionRequest._();
  @$core.override
  OpenAgentSessionRequest createEmptyInstance() => OpenAgentSessionRequest._();
  @$core.pragma('dart2js:noInline')
  static OpenAgentSessionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenAgentSessionRequest>(
          OpenAgentSessionRequest.$_createMessage);
  static OpenAgentSessionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agent => $_getSZ(0);
  @$pb.TagNumber(1)
  set agent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgent() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgent() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get folder => $_getSZ(1);
  @$pb.TagNumber(2)
  set folder($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFolder() => $_has(1);
  @$pb.TagNumber(2)
  void clearFolder() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get sessionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set sessionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSessionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSessionId() => $_clearField(3);

  /// The title it had in the list, until the agent names it.
  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);
}

class OpenAgentSessionResponse extends $pb.GeneratedMessage {
  factory OpenAgentSessionResponse({
    $core.String? chatId,
  }) {
    final result = OpenAgentSessionResponse._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  OpenAgentSessionResponse._();

  factory OpenAgentSessionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenAgentSessionResponse()..mergeFromBuffer(data, registry);
  factory OpenAgentSessionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      OpenAgentSessionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OpenAgentSessionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: OpenAgentSessionResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenAgentSessionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OpenAgentSessionResponse copyWith(
          void Function(OpenAgentSessionResponse) updates) =>
      super.copyWith((message) => updates(message as OpenAgentSessionResponse))
          as OpenAgentSessionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use OpenAgentSessionResponse() / OpenAgentSessionResponse.new instead')
  static OpenAgentSessionResponse create() => OpenAgentSessionResponse._();
  static $pb.GeneratedMessage $_createMessage() => OpenAgentSessionResponse._();
  @$core.override
  OpenAgentSessionResponse createEmptyInstance() =>
      OpenAgentSessionResponse._();
  @$core.pragma('dart2js:noInline')
  static OpenAgentSessionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OpenAgentSessionResponse>(
          OpenAgentSessionResponse.$_createMessage);
  static OpenAgentSessionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
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

class RenameBranchRequest extends $pb.GeneratedMessage {
  factory RenameBranchRequest({
    $core.String? chatId,
    $core.String? branch,
  }) {
    final result = RenameBranchRequest._();
    if (chatId != null) result.chatId = chatId;
    if (branch != null) result.branch = branch;
    return result;
  }

  RenameBranchRequest._();

  factory RenameBranchRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameBranchRequest()..mergeFromBuffer(data, registry);
  factory RenameBranchRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameBranchRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameBranchRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RenameBranchRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'branch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameBranchRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameBranchRequest copyWith(void Function(RenameBranchRequest) updates) =>
      super.copyWith((message) => updates(message as RenameBranchRequest))
          as RenameBranchRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use RenameBranchRequest() / RenameBranchRequest.new instead')
  static RenameBranchRequest create() => RenameBranchRequest._();
  static $pb.GeneratedMessage $_createMessage() => RenameBranchRequest._();
  @$core.override
  RenameBranchRequest createEmptyInstance() => RenameBranchRequest._();
  @$core.pragma('dart2js:noInline')
  static RenameBranchRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameBranchRequest>(
          RenameBranchRequest.$_createMessage);
  static RenameBranchRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get branch => $_getSZ(1);
  @$pb.TagNumber(2)
  set branch($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBranch() => $_has(1);
  @$pb.TagNumber(2)
  void clearBranch() => $_clearField(2);
}

class RenameBranchResponse extends $pb.GeneratedMessage {
  factory RenameBranchResponse() => RenameBranchResponse._();

  RenameBranchResponse._();

  factory RenameBranchResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameBranchResponse()..mergeFromBuffer(data, registry);
  factory RenameBranchResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RenameBranchResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RenameBranchResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RenameBranchResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameBranchResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RenameBranchResponse copyWith(void Function(RenameBranchResponse) updates) =>
      super.copyWith((message) => updates(message as RenameBranchResponse))
          as RenameBranchResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RenameBranchResponse() / RenameBranchResponse.new instead')
  static RenameBranchResponse create() => RenameBranchResponse._();
  static $pb.GeneratedMessage $_createMessage() => RenameBranchResponse._();
  @$core.override
  RenameBranchResponse createEmptyInstance() => RenameBranchResponse._();
  @$core.pragma('dart2js:noInline')
  static RenameBranchResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RenameBranchResponse>(
          RenameBranchResponse.$_createMessage);
  static RenameBranchResponse? _defaultInstance;
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

class ReopenChatRequest extends $pb.GeneratedMessage {
  factory ReopenChatRequest({
    $core.String? chatId,
  }) {
    final result = ReopenChatRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  ReopenChatRequest._();

  factory ReopenChatRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReopenChatRequest()..mergeFromBuffer(data, registry);
  factory ReopenChatRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReopenChatRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReopenChatRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ReopenChatRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReopenChatRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReopenChatRequest copyWith(void Function(ReopenChatRequest) updates) =>
      super.copyWith((message) => updates(message as ReopenChatRequest))
          as ReopenChatRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReopenChatRequest() / ReopenChatRequest.new instead')
  static ReopenChatRequest create() => ReopenChatRequest._();
  static $pb.GeneratedMessage $_createMessage() => ReopenChatRequest._();
  @$core.override
  ReopenChatRequest createEmptyInstance() => ReopenChatRequest._();
  @$core.pragma('dart2js:noInline')
  static ReopenChatRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReopenChatRequest>(
          ReopenChatRequest.$_createMessage);
  static ReopenChatRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class ReopenChatResponse extends $pb.GeneratedMessage {
  factory ReopenChatResponse() => ReopenChatResponse._();

  ReopenChatResponse._();

  factory ReopenChatResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReopenChatResponse()..mergeFromBuffer(data, registry);
  factory ReopenChatResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReopenChatResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReopenChatResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ReopenChatResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReopenChatResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReopenChatResponse copyWith(void Function(ReopenChatResponse) updates) =>
      super.copyWith((message) => updates(message as ReopenChatResponse))
          as ReopenChatResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ReopenChatResponse() / ReopenChatResponse.new instead')
  static ReopenChatResponse create() => ReopenChatResponse._();
  static $pb.GeneratedMessage $_createMessage() => ReopenChatResponse._();
  @$core.override
  ReopenChatResponse createEmptyInstance() => ReopenChatResponse._();
  @$core.pragma('dart2js:noInline')
  static ReopenChatResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReopenChatResponse>(
          ReopenChatResponse.$_createMessage);
  static ReopenChatResponse? _defaultInstance;
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
    $core.bool? debugLog,
    $core.bool? keepTranscripts,
    $core.int? transcriptDays,
  }) {
    final result = Settings._();
    if (sleepAfterMinutes != null) result.sleepAfterMinutes = sleepAfterMinutes;
    if (debugLog != null) result.debugLog = debugLog;
    if (keepTranscripts != null) result.keepTranscripts = keepTranscripts;
    if (transcriptDays != null) result.transcriptDays = transcriptDays;
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
    ..aOB(2, _omitFieldNames ? '' : 'debugLog')
    ..aOB(3, _omitFieldNames ? '' : 'keepTranscripts')
    ..aI(4, _omitFieldNames ? '' : 'transcriptDays')
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

  /// The daemon's log has DEBUG lines too: every ACP method and API call,
  /// with how long it took (ADR 0038). SetSettings sets both fields.
  @$pb.TagNumber(2)
  $core.bool get debugLog => $_getBF(1);
  @$pb.TagNumber(2)
  set debugLog($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDebugLog() => $_has(1);
  @$pb.TagNumber(2)
  void clearDebugLog() => $_clearField(2);

  /// Nushi keeps its own read-only copy of each chat's transcript (ADR
  /// 0047); on by default. SetSettings leaves it as it is when not given.
  @$pb.TagNumber(3)
  $core.bool get keepTranscripts => $_getBF(2);
  @$pb.TagNumber(3)
  set keepTranscripts($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasKeepTranscripts() => $_has(2);
  @$pb.TagNumber(3)
  void clearKeepTranscripts() => $_clearField(3);

  /// A copy goes this many days after it was last written; 0: never.
  /// SetSettings leaves it as it is when not given.
  @$pb.TagNumber(4)
  $core.int get transcriptDays => $_getIZ(3);
  @$pb.TagNumber(4)
  set transcriptDays($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTranscriptDays() => $_has(3);
  @$pb.TagNumber(4)
  void clearTranscriptDays() => $_clearField(4);
}

class ListTranscriptsRequest extends $pb.GeneratedMessage {
  factory ListTranscriptsRequest() => ListTranscriptsRequest._();

  ListTranscriptsRequest._();

  factory ListTranscriptsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTranscriptsRequest()..mergeFromBuffer(data, registry);
  factory ListTranscriptsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTranscriptsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTranscriptsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListTranscriptsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTranscriptsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTranscriptsRequest copyWith(
          void Function(ListTranscriptsRequest) updates) =>
      super.copyWith((message) => updates(message as ListTranscriptsRequest))
          as ListTranscriptsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListTranscriptsRequest() / ListTranscriptsRequest.new instead')
  static ListTranscriptsRequest create() => ListTranscriptsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListTranscriptsRequest._();
  @$core.override
  ListTranscriptsRequest createEmptyInstance() => ListTranscriptsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListTranscriptsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTranscriptsRequest>(
          ListTranscriptsRequest.$_createMessage);
  static ListTranscriptsRequest? _defaultInstance;
}

class ListTranscriptsResponse extends $pb.GeneratedMessage {
  factory ListTranscriptsResponse({
    $fixnum.Int64? totalBytes,
    $core.Iterable<TranscriptCopy>? copies,
  }) {
    final result = ListTranscriptsResponse._();
    if (totalBytes != null) result.totalBytes = totalBytes;
    if (copies != null) result.copies.addAll(copies);
    return result;
  }

  ListTranscriptsResponse._();

  factory ListTranscriptsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTranscriptsResponse()..mergeFromBuffer(data, registry);
  factory ListTranscriptsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListTranscriptsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTranscriptsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListTranscriptsResponse.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'totalBytes')
    ..pPM<TranscriptCopy>(2, _omitFieldNames ? '' : 'copies',
        subBuilder: TranscriptCopy.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTranscriptsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTranscriptsResponse copyWith(
          void Function(ListTranscriptsResponse) updates) =>
      super.copyWith((message) => updates(message as ListTranscriptsResponse))
          as ListTranscriptsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListTranscriptsResponse() / ListTranscriptsResponse.new instead')
  static ListTranscriptsResponse create() => ListTranscriptsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListTranscriptsResponse._();
  @$core.override
  ListTranscriptsResponse createEmptyInstance() => ListTranscriptsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListTranscriptsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTranscriptsResponse>(
          ListTranscriptsResponse.$_createMessage);
  static ListTranscriptsResponse? _defaultInstance;

  /// All of them, in bytes.
  @$pb.TagNumber(1)
  $fixnum.Int64 get totalBytes => $_getI64(0);
  @$pb.TagNumber(1)
  set totalBytes($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalBytes() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalBytes() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<TranscriptCopy> get copies => $_getList(1);
}

/// A chat's copy of its transcript.
class TranscriptCopy extends $pb.GeneratedMessage {
  factory TranscriptCopy({
    $core.String? chatId,
    $core.String? title,
    $core.String? agent,
    $fixnum.Int64? bytes,
    $fixnum.Int64? lastWrittenMs,
  }) {
    final result = TranscriptCopy._();
    if (chatId != null) result.chatId = chatId;
    if (title != null) result.title = title;
    if (agent != null) result.agent = agent;
    if (bytes != null) result.bytes = bytes;
    if (lastWrittenMs != null) result.lastWrittenMs = lastWrittenMs;
    return result;
  }

  TranscriptCopy._();

  factory TranscriptCopy.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TranscriptCopy()..mergeFromBuffer(data, registry);
  factory TranscriptCopy.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TranscriptCopy()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TranscriptCopy',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TranscriptCopy.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..aOS(2, _omitFieldNames ? '' : 'title')
    ..aOS(3, _omitFieldNames ? '' : 'agent')
    ..aInt64(4, _omitFieldNames ? '' : 'bytes')
    ..aInt64(5, _omitFieldNames ? '' : 'lastWrittenMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TranscriptCopy clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TranscriptCopy copyWith(void Function(TranscriptCopy) updates) =>
      super.copyWith((message) => updates(message as TranscriptCopy))
          as TranscriptCopy;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TranscriptCopy() / TranscriptCopy.new instead')
  static TranscriptCopy create() => TranscriptCopy._();
  static $pb.GeneratedMessage $_createMessage() => TranscriptCopy._();
  @$core.override
  TranscriptCopy createEmptyInstance() => TranscriptCopy._();
  @$core.pragma('dart2js:noInline')
  static TranscriptCopy getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TranscriptCopy>(
          TranscriptCopy.$_createMessage);
  static TranscriptCopy? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);

  /// The chat's title and agent; empty when Nushi no longer has the chat.
  @$pb.TagNumber(2)
  $core.String get title => $_getSZ(1);
  @$pb.TagNumber(2)
  set title($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTitle() => $_has(1);
  @$pb.TagNumber(2)
  void clearTitle() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get agent => $_getSZ(2);
  @$pb.TagNumber(3)
  set agent($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAgent() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgent() => $_clearField(3);

  /// Its size on disk, images included.
  @$pb.TagNumber(4)
  $fixnum.Int64 get bytes => $_getI64(3);
  @$pb.TagNumber(4)
  set bytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearBytes() => $_clearField(4);

  /// When it was last written, in Unix milliseconds.
  @$pb.TagNumber(5)
  $fixnum.Int64 get lastWrittenMs => $_getI64(4);
  @$pb.TagNumber(5)
  set lastWrittenMs($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLastWrittenMs() => $_has(4);
  @$pb.TagNumber(5)
  void clearLastWrittenMs() => $_clearField(5);
}

class ClearTranscriptsRequest extends $pb.GeneratedMessage {
  factory ClearTranscriptsRequest({
    $core.Iterable<$core.String>? chatIds,
    $core.bool? all,
    $core.int? olderThanDays,
  }) {
    final result = ClearTranscriptsRequest._();
    if (chatIds != null) result.chatIds.addAll(chatIds);
    if (all != null) result.all = all;
    if (olderThanDays != null) result.olderThanDays = olderThanDays;
    return result;
  }

  ClearTranscriptsRequest._();

  factory ClearTranscriptsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClearTranscriptsRequest()..mergeFromBuffer(data, registry);
  factory ClearTranscriptsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClearTranscriptsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearTranscriptsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ClearTranscriptsRequest.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'chatIds')
    ..aOB(2, _omitFieldNames ? '' : 'all')
    ..aI(3, _omitFieldNames ? '' : 'olderThanDays')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearTranscriptsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearTranscriptsRequest copyWith(
          void Function(ClearTranscriptsRequest) updates) =>
      super.copyWith((message) => updates(message as ClearTranscriptsRequest))
          as ClearTranscriptsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ClearTranscriptsRequest() / ClearTranscriptsRequest.new instead')
  static ClearTranscriptsRequest create() => ClearTranscriptsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ClearTranscriptsRequest._();
  @$core.override
  ClearTranscriptsRequest createEmptyInstance() => ClearTranscriptsRequest._();
  @$core.pragma('dart2js:noInline')
  static ClearTranscriptsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearTranscriptsRequest>(
          ClearTranscriptsRequest.$_createMessage);
  static ClearTranscriptsRequest? _defaultInstance;

  /// These chats' copies.
  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get chatIds => $_getList(0);

  /// Every copy.
  @$pb.TagNumber(2)
  $core.bool get all => $_getBF(1);
  @$pb.TagNumber(2)
  set all($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAll() => $_has(1);
  @$pb.TagNumber(2)
  void clearAll() => $_clearField(2);

  /// The copies last written more than this many days ago (with neither
  /// of the above).
  @$pb.TagNumber(3)
  $core.int get olderThanDays => $_getIZ(2);
  @$pb.TagNumber(3)
  set olderThanDays($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOlderThanDays() => $_has(2);
  @$pb.TagNumber(3)
  void clearOlderThanDays() => $_clearField(3);
}

class ClearTranscriptsResponse extends $pb.GeneratedMessage {
  factory ClearTranscriptsResponse({
    $core.int? cleared,
    $fixnum.Int64? bytes,
  }) {
    final result = ClearTranscriptsResponse._();
    if (cleared != null) result.cleared = cleared;
    if (bytes != null) result.bytes = bytes;
    return result;
  }

  ClearTranscriptsResponse._();

  factory ClearTranscriptsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClearTranscriptsResponse()..mergeFromBuffer(data, registry);
  factory ClearTranscriptsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ClearTranscriptsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ClearTranscriptsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ClearTranscriptsResponse.$_createMessage)
    ..aI(1, _omitFieldNames ? '' : 'cleared')
    ..aInt64(2, _omitFieldNames ? '' : 'bytes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearTranscriptsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ClearTranscriptsResponse copyWith(
          void Function(ClearTranscriptsResponse) updates) =>
      super.copyWith((message) => updates(message as ClearTranscriptsResponse))
          as ClearTranscriptsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ClearTranscriptsResponse() / ClearTranscriptsResponse.new instead')
  static ClearTranscriptsResponse create() => ClearTranscriptsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ClearTranscriptsResponse._();
  @$core.override
  ClearTranscriptsResponse createEmptyInstance() =>
      ClearTranscriptsResponse._();
  @$core.pragma('dart2js:noInline')
  static ClearTranscriptsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ClearTranscriptsResponse>(
          ClearTranscriptsResponse.$_createMessage);
  static ClearTranscriptsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get cleared => $_getIZ(0);
  @$pb.TagNumber(1)
  set cleared($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCleared() => $_has(0);
  @$pb.TagNumber(1)
  void clearCleared() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get bytes => $_getI64(1);
  @$pb.TagNumber(2)
  set bytes($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBytes() => $_has(1);
  @$pb.TagNumber(2)
  void clearBytes() => $_clearField(2);
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

  /// Turned off for the folder's project: a project server rejected, or a
  /// user or local one turned off by /mcp (or SetMcpServerOn); off_by
  /// names a file that does it other than what SetMcpServerOn changes. A
  /// plugin's server or connector turned off says so in its state.
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
    $core.String? scope,
  }) {
    final result = SetMcpServerOnRequest._();
    if (folder != null) result.folder = folder;
    if (name != null) result.name = name;
    if (on != null) result.on = on;
    if (scope != null) result.scope = scope;
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
    ..aOS(4, _omitFieldNames ? '' : 'scope')
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

  /// The server's scope: "project" (also when empty), "user" or "local".
  @$pb.TagNumber(4)
  $core.String get scope => $_getSZ(3);
  @$pb.TagNumber(4)
  set scope($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasScope() => $_has(3);
  @$pb.TagNumber(4)
  void clearScope() => $_clearField(4);
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

class ListSkillsRequest extends $pb.GeneratedMessage {
  factory ListSkillsRequest({
    $core.String? folder,
    $core.String? agent,
  }) {
    final result = ListSkillsRequest._();
    if (folder != null) result.folder = folder;
    if (agent != null) result.agent = agent;
    return result;
  }

  ListSkillsRequest._();

  factory ListSkillsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsRequest()..mergeFromBuffer(data, registry);
  factory ListSkillsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSkillsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListSkillsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsRequest copyWith(void Function(ListSkillsRequest) updates) =>
      super.copyWith((message) => updates(message as ListSkillsRequest))
          as ListSkillsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListSkillsRequest() / ListSkillsRequest.new instead')
  static ListSkillsRequest create() => ListSkillsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListSkillsRequest._();
  @$core.override
  ListSkillsRequest createEmptyInstance() => ListSkillsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListSkillsRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ListSkillsRequest>(
          ListSkillsRequest.$_createMessage);
  static ListSkillsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// The agent whose skills these are ("claude" when empty).
  @$pb.TagNumber(2)
  $core.String get agent => $_getSZ(1);
  @$pb.TagNumber(2)
  set agent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgent() => $_clearField(2);
}

class ListSkillsResponse extends $pb.GeneratedMessage {
  factory ListSkillsResponse({
    $core.Iterable<Skill>? skills,
    $core.Iterable<Plugin>? plugins,
    $core.String? pluginsError,
    $core.bool? builtInOff,
    $core.String? builtInSetIn,
    $core.String? noSkills,
    $core.String? noSwitch,
    $core.bool? readsShared,
  }) {
    final result = ListSkillsResponse._();
    if (skills != null) result.skills.addAll(skills);
    if (plugins != null) result.plugins.addAll(plugins);
    if (pluginsError != null) result.pluginsError = pluginsError;
    if (builtInOff != null) result.builtInOff = builtInOff;
    if (builtInSetIn != null) result.builtInSetIn = builtInSetIn;
    if (noSkills != null) result.noSkills = noSkills;
    if (noSwitch != null) result.noSwitch = noSwitch;
    if (readsShared != null) result.readsShared = readsShared;
    return result;
  }

  ListSkillsResponse._();

  factory ListSkillsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsResponse()..mergeFromBuffer(data, registry);
  factory ListSkillsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListSkillsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSkillsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListSkillsResponse.$_createMessage)
    ..pPM<Skill>(1, _omitFieldNames ? '' : 'skills',
        subBuilder: Skill.$_createMessage)
    ..pPM<Plugin>(2, _omitFieldNames ? '' : 'plugins',
        subBuilder: Plugin.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'pluginsError')
    ..aOB(4, _omitFieldNames ? '' : 'builtInOff')
    ..aOS(5, _omitFieldNames ? '' : 'builtInSetIn')
    ..aOS(6, _omitFieldNames ? '' : 'noSkills')
    ..aOS(7, _omitFieldNames ? '' : 'noSwitch')
    ..aOB(8, _omitFieldNames ? '' : 'readsShared')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSkillsResponse copyWith(void Function(ListSkillsResponse) updates) =>
      super.copyWith((message) => updates(message as ListSkillsResponse))
          as ListSkillsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use ListSkillsResponse() / ListSkillsResponse.new instead')
  static ListSkillsResponse create() => ListSkillsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListSkillsResponse._();
  @$core.override
  ListSkillsResponse createEmptyInstance() => ListSkillsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListSkillsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSkillsResponse>(
          ListSkillsResponse.$_createMessage);
  static ListSkillsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Skill> get skills => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<Plugin> get plugins => $_getList(1);

  /// Why Claude couldn't list its plugins (their skills are then missing).
  @$pb.TagNumber(3)
  $core.String get pluginsError => $_getSZ(2);
  @$pb.TagNumber(3)
  set pluginsError($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPluginsError() => $_has(2);
  @$pb.TagNumber(3)
  void clearPluginsError() => $_clearField(3);

  /// Claude's built-in skills are off; built_in_set_in names a settings
  /// file that decides it other than yours.
  @$pb.TagNumber(4)
  $core.bool get builtInOff => $_getBF(3);
  @$pb.TagNumber(4)
  set builtInOff($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasBuiltInOff() => $_has(3);
  @$pb.TagNumber(4)
  void clearBuiltInOff() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get builtInSetIn => $_getSZ(4);
  @$pb.TagNumber(5)
  set builtInSetIn($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBuiltInSetIn() => $_has(4);
  @$pb.TagNumber(5)
  void clearBuiltInSetIn() => $_clearField(5);

  /// Why the agent has no skills to show, or no switches ("" when it has).
  @$pb.TagNumber(6)
  $core.String get noSkills => $_getSZ(5);
  @$pb.TagNumber(6)
  set noSkills($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNoSkills() => $_has(5);
  @$pb.TagNumber(6)
  void clearNoSkills() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get noSwitch => $_getSZ(6);
  @$pb.TagNumber(7)
  set noSwitch($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNoSwitch() => $_has(6);
  @$pb.TagNumber(7)
  void clearNoSwitch() => $_clearField(7);

  /// The agent reads the project's .agents/skills (shared skills).
  @$pb.TagNumber(8)
  $core.bool get readsShared => $_getBF(7);
  @$pb.TagNumber(8)
  set readsShared($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasReadsShared() => $_has(7);
  @$pb.TagNumber(8)
  void clearReadsShared() => $_clearField(8);
}

class Skill extends $pb.GeneratedMessage {
  factory Skill({
    $core.String? name,
    $core.String? description,
    $core.String? source,
    $core.String? plugin,
    $core.String? path,
    $core.String? state,
    $core.String? setIn,
    $core.int? tokens,
    $core.String? linked,
    $core.bool? everywhere,
    $core.Iterable<SkillAgent>? agents,
  }) {
    final result = Skill._();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (source != null) result.source = source;
    if (plugin != null) result.plugin = plugin;
    if (path != null) result.path = path;
    if (state != null) result.state = state;
    if (setIn != null) result.setIn = setIn;
    if (tokens != null) result.tokens = tokens;
    if (linked != null) result.linked = linked;
    if (everywhere != null) result.everywhere = everywhere;
    if (agents != null) result.agents.addAll(agents);
    return result;
  }

  Skill._();

  factory Skill.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Skill()..mergeFromBuffer(data, registry);
  factory Skill.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Skill()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Skill',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Skill.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aOS(3, _omitFieldNames ? '' : 'source')
    ..aOS(4, _omitFieldNames ? '' : 'plugin')
    ..aOS(5, _omitFieldNames ? '' : 'path')
    ..aOS(6, _omitFieldNames ? '' : 'state')
    ..aOS(7, _omitFieldNames ? '' : 'setIn')
    ..aI(8, _omitFieldNames ? '' : 'tokens')
    ..aOS(9, _omitFieldNames ? '' : 'linked')
    ..aOB(10, _omitFieldNames ? '' : 'everywhere')
    ..pPM<SkillAgent>(11, _omitFieldNames ? '' : 'agents',
        subBuilder: SkillAgent.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Skill clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Skill copyWith(void Function(Skill) updates) =>
      super.copyWith((message) => updates(message as Skill)) as Skill;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Skill() / Skill.new instead')
  static Skill create() => Skill._();
  static $pb.GeneratedMessage $_createMessage() => Skill._();
  @$core.override
  Skill createEmptyInstance() => Skill._();
  @$core.pragma('dart2js:noInline')
  static Skill getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Skill>(Skill.$_createMessage);
  static Skill? _defaultInstance;

  /// As Claude lists it; a plugin's is "<plugin>:<skill>".
  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  /// From its front matter, else its first line: its author's text.
  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  /// "user", "project", "plugin" (plugin: the plugin's id), "system" (the
  /// agent's own) or "shared" (.agents/skills, which several agents read).
  @$pb.TagNumber(3)
  $core.String get source => $_getSZ(2);
  @$pb.TagNumber(3)
  set source($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSource() => $_has(2);
  @$pb.TagNumber(3)
  void clearSource() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get plugin => $_getSZ(3);
  @$pb.TagNumber(4)
  set plugin($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlugin() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlugin() => $_clearField(4);

  /// Its folder, which holds SKILL.md.
  @$pb.TagNumber(5)
  $core.String get path => $_getSZ(4);
  @$pb.TagNumber(5)
  set path($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPath() => $_has(4);
  @$pb.TagNumber(5)
  void clearPath() => $_clearField(5);

  /// "on", "name-only", "user-invocable-only" or "off"; set_in names a
  /// settings file that decides it other than the one SetSkillOn changes.
  @$pb.TagNumber(6)
  $core.String get state => $_getSZ(5);
  @$pb.TagNumber(6)
  set state($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasState() => $_has(5);
  @$pb.TagNumber(6)
  void clearState() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get setIn => $_getSZ(6);
  @$pb.TagNumber(7)
  set setIn($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSetIn() => $_has(6);
  @$pb.TagNumber(7)
  void clearSetIn() => $_clearField(7);

  /// About what listing it costs each session's context, in tokens.
  @$pb.TagNumber(8)
  $core.int get tokens => $_getIZ(7);
  @$pb.TagNumber(8)
  set tokens($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTokens() => $_has(7);
  @$pb.TagNumber(8)
  void clearTokens() => $_clearField(8);

  /// Where the skill's folder points when it is a symlink, as the link says.
  @$pb.TagNumber(9)
  $core.String get linked => $_getSZ(8);
  @$pb.TagNumber(9)
  set linked($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasLinked() => $_has(8);
  @$pb.TagNumber(9)
  void clearLinked() => $_clearField(9);

  /// A shared skill in your own ~/.agents/skills, not the project's.
  @$pb.TagNumber(10)
  $core.bool get everywhere => $_getBF(9);
  @$pb.TagNumber(10)
  set everywhere($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasEverywhere() => $_has(9);
  @$pb.TagNumber(10)
  void clearEverywhere() => $_clearField(10);

  /// A shared skill's agents: those that load it, each with its state.
  @$pb.TagNumber(11)
  $pb.PbList<SkillAgent> get agents => $_getList(10);
}

class SkillAgent extends $pb.GeneratedMessage {
  factory SkillAgent({
    $core.String? agent,
    $core.String? state,
    $core.String? setIn,
    $core.String? via,
  }) {
    final result = SkillAgent._();
    if (agent != null) result.agent = agent;
    if (state != null) result.state = state;
    if (setIn != null) result.setIn = setIn;
    if (via != null) result.via = via;
    return result;
  }

  SkillAgent._();

  factory SkillAgent.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SkillAgent()..mergeFromBuffer(data, registry);
  factory SkillAgent.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SkillAgent()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SkillAgent',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SkillAgent.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'agent')
    ..aOS(2, _omitFieldNames ? '' : 'state')
    ..aOS(3, _omitFieldNames ? '' : 'setIn')
    ..aOS(4, _omitFieldNames ? '' : 'via')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkillAgent clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SkillAgent copyWith(void Function(SkillAgent) updates) =>
      super.copyWith((message) => updates(message as SkillAgent)) as SkillAgent;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SkillAgent() / SkillAgent.new instead')
  static SkillAgent create() => SkillAgent._();
  static $pb.GeneratedMessage $_createMessage() => SkillAgent._();
  @$core.override
  SkillAgent createEmptyInstance() => SkillAgent._();
  @$core.pragma('dart2js:noInline')
  static SkillAgent getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SkillAgent>(SkillAgent.$_createMessage);
  static SkillAgent? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get agent => $_getSZ(0);
  @$pb.TagNumber(1)
  set agent($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAgent() => $_has(0);
  @$pb.TagNumber(1)
  void clearAgent() => $_clearField(1);

  /// "on", "off", or "untrusted": it loads once the folder is trusted.
  @$pb.TagNumber(2)
  $core.String get state => $_getSZ(1);
  @$pb.TagNumber(2)
  set state($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get setIn => $_getSZ(2);
  @$pb.TagNumber(3)
  set setIn($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSetIn() => $_has(2);
  @$pb.TagNumber(3)
  void clearSetIn() => $_clearField(3);

  /// The agent's own skill folder that links to it, when that's how it
  /// loads it.
  @$pb.TagNumber(4)
  $core.String get via => $_getSZ(3);
  @$pb.TagNumber(4)
  set via($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVia() => $_has(3);
  @$pb.TagNumber(4)
  void clearVia() => $_clearField(4);
}

class Plugin extends $pb.GeneratedMessage {
  factory Plugin({
    $core.String? id,
    $core.String? name,
    $core.String? version,
    $core.String? description,
    $core.String? scope,
    $core.String? path,
    $core.bool? enabled,
    $core.int? skills,
    $core.int? commands,
    $core.int? agents,
    $core.int? mcpServers,
    $core.String? switchScope,
  }) {
    final result = Plugin._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (version != null) result.version = version;
    if (description != null) result.description = description;
    if (scope != null) result.scope = scope;
    if (path != null) result.path = path;
    if (enabled != null) result.enabled = enabled;
    if (skills != null) result.skills = skills;
    if (commands != null) result.commands = commands;
    if (agents != null) result.agents = agents;
    if (mcpServers != null) result.mcpServers = mcpServers;
    if (switchScope != null) result.switchScope = switchScope;
    return result;
  }

  Plugin._();

  factory Plugin.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Plugin()..mergeFromBuffer(data, registry);
  factory Plugin.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Plugin()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Plugin',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Plugin.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'version')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..aOS(5, _omitFieldNames ? '' : 'scope')
    ..aOS(6, _omitFieldNames ? '' : 'path')
    ..aOB(7, _omitFieldNames ? '' : 'enabled')
    ..aI(8, _omitFieldNames ? '' : 'skills')
    ..aI(9, _omitFieldNames ? '' : 'commands')
    ..aI(10, _omitFieldNames ? '' : 'agents')
    ..aI(11, _omitFieldNames ? '' : 'mcpServers')
    ..aOS(12, _omitFieldNames ? '' : 'switchScope')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Plugin clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Plugin copyWith(void Function(Plugin) updates) =>
      super.copyWith((message) => updates(message as Plugin)) as Plugin;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Plugin() / Plugin.new instead')
  static Plugin create() => Plugin._();
  static $pb.GeneratedMessage $_createMessage() => Plugin._();
  @$core.override
  Plugin createEmptyInstance() => Plugin._();
  @$core.pragma('dart2js:noInline')
  static Plugin getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Plugin>(Plugin.$_createMessage);
  static Plugin? _defaultInstance;

  /// "<name>@<marketplace>".
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
  $core.String get version => $_getSZ(2);
  @$pb.TagNumber(3)
  set version($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearVersion() => $_clearField(3);

  /// From its manifest: its author's text.
  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  /// Where it's installed: "user", "project" or "local".
  @$pb.TagNumber(5)
  $core.String get scope => $_getSZ(4);
  @$pb.TagNumber(5)
  set scope($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasScope() => $_has(4);
  @$pb.TagNumber(5)
  void clearScope() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get path => $_getSZ(5);
  @$pb.TagNumber(6)
  set path($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPath() => $_has(5);
  @$pb.TagNumber(6)
  void clearPath() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get enabled => $_getBF(6);
  @$pb.TagNumber(7)
  set enabled($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEnabled() => $_has(6);
  @$pb.TagNumber(7)
  void clearEnabled() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get skills => $_getIZ(7);
  @$pb.TagNumber(8)
  set skills($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSkills() => $_has(7);
  @$pb.TagNumber(8)
  void clearSkills() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get commands => $_getIZ(8);
  @$pb.TagNumber(9)
  set commands($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCommands() => $_has(8);
  @$pb.TagNumber(9)
  void clearCommands() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get agents => $_getIZ(9);
  @$pb.TagNumber(10)
  set agents($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAgents() => $_has(9);
  @$pb.TagNumber(10)
  void clearAgents() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get mcpServers => $_getIZ(10);
  @$pb.TagNumber(11)
  set mcpServers($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasMcpServers() => $_has(10);
  @$pb.TagNumber(11)
  void clearMcpServers() => $_clearField(11);

  /// Where SetPluginOn changes it: "user" (everywhere) or "local" (this
  /// project).
  @$pb.TagNumber(12)
  $core.String get switchScope => $_getSZ(11);
  @$pb.TagNumber(12)
  set switchScope($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasSwitchScope() => $_has(11);
  @$pb.TagNumber(12)
  void clearSwitchScope() => $_clearField(12);
}

class SetSkillOnRequest extends $pb.GeneratedMessage {
  factory SetSkillOnRequest({
    $core.String? folder,
    $core.String? source,
    $core.String? name,
    $core.bool? on,
    $core.String? agent,
  }) {
    final result = SetSkillOnRequest._();
    if (folder != null) result.folder = folder;
    if (source != null) result.source = source;
    if (name != null) result.name = name;
    if (on != null) result.on = on;
    if (agent != null) result.agent = agent;
    return result;
  }

  SetSkillOnRequest._();

  factory SetSkillOnRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSkillOnRequest()..mergeFromBuffer(data, registry);
  factory SetSkillOnRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSkillOnRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetSkillOnRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetSkillOnRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'source')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOB(4, _omitFieldNames ? '' : 'on')
    ..aOS(5, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSkillOnRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSkillOnRequest copyWith(void Function(SetSkillOnRequest) updates) =>
      super.copyWith((message) => updates(message as SetSkillOnRequest))
          as SetSkillOnRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetSkillOnRequest() / SetSkillOnRequest.new instead')
  static SetSkillOnRequest create() => SetSkillOnRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetSkillOnRequest._();
  @$core.override
  SetSkillOnRequest createEmptyInstance() => SetSkillOnRequest._();
  @$core.pragma('dart2js:noInline')
  static SetSkillOnRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SetSkillOnRequest>(
          SetSkillOnRequest.$_createMessage);
  static SetSkillOnRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// "user", "project" or "builtin" (name empty).
  @$pb.TagNumber(2)
  $core.String get source => $_getSZ(1);
  @$pb.TagNumber(2)
  set source($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSource() => $_has(1);
  @$pb.TagNumber(2)
  void clearSource() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get on => $_getBF(3);
  @$pb.TagNumber(4)
  set on($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOn() => $_has(3);
  @$pb.TagNumber(4)
  void clearOn() => $_clearField(4);

  /// The agent ("claude" when empty).
  @$pb.TagNumber(5)
  $core.String get agent => $_getSZ(4);
  @$pb.TagNumber(5)
  set agent($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAgent() => $_has(4);
  @$pb.TagNumber(5)
  void clearAgent() => $_clearField(5);
}

class SetSkillOnResponse extends $pb.GeneratedMessage {
  factory SetSkillOnResponse() => SetSkillOnResponse._();

  SetSkillOnResponse._();

  factory SetSkillOnResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSkillOnResponse()..mergeFromBuffer(data, registry);
  factory SetSkillOnResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetSkillOnResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetSkillOnResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetSkillOnResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSkillOnResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetSkillOnResponse copyWith(void Function(SetSkillOnResponse) updates) =>
      super.copyWith((message) => updates(message as SetSkillOnResponse))
          as SetSkillOnResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetSkillOnResponse() / SetSkillOnResponse.new instead')
  static SetSkillOnResponse create() => SetSkillOnResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetSkillOnResponse._();
  @$core.override
  SetSkillOnResponse createEmptyInstance() => SetSkillOnResponse._();
  @$core.pragma('dart2js:noInline')
  static SetSkillOnResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetSkillOnResponse>(
          SetSkillOnResponse.$_createMessage);
  static SetSkillOnResponse? _defaultInstance;
}

class SetPluginOnRequest extends $pb.GeneratedMessage {
  factory SetPluginOnRequest({
    $core.String? folder,
    $core.String? id,
    $core.bool? on,
    $core.String? agent,
  }) {
    final result = SetPluginOnRequest._();
    if (folder != null) result.folder = folder;
    if (id != null) result.id = id;
    if (on != null) result.on = on;
    if (agent != null) result.agent = agent;
    return result;
  }

  SetPluginOnRequest._();

  factory SetPluginOnRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPluginOnRequest()..mergeFromBuffer(data, registry);
  factory SetPluginOnRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPluginOnRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPluginOnRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetPluginOnRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOB(3, _omitFieldNames ? '' : 'on')
    ..aOS(4, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPluginOnRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPluginOnRequest copyWith(void Function(SetPluginOnRequest) updates) =>
      super.copyWith((message) => updates(message as SetPluginOnRequest))
          as SetPluginOnRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use SetPluginOnRequest() / SetPluginOnRequest.new instead')
  static SetPluginOnRequest create() => SetPluginOnRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetPluginOnRequest._();
  @$core.override
  SetPluginOnRequest createEmptyInstance() => SetPluginOnRequest._();
  @$core.pragma('dart2js:noInline')
  static SetPluginOnRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPluginOnRequest>(
          SetPluginOnRequest.$_createMessage);
  static SetPluginOnRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get on => $_getBF(2);
  @$pb.TagNumber(3)
  set on($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOn() => $_has(2);
  @$pb.TagNumber(3)
  void clearOn() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get agent => $_getSZ(3);
  @$pb.TagNumber(4)
  set agent($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAgent() => $_has(3);
  @$pb.TagNumber(4)
  void clearAgent() => $_clearField(4);
}

class SetPluginOnResponse extends $pb.GeneratedMessage {
  factory SetPluginOnResponse() => SetPluginOnResponse._();

  SetPluginOnResponse._();

  factory SetPluginOnResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPluginOnResponse()..mergeFromBuffer(data, registry);
  factory SetPluginOnResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPluginOnResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPluginOnResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetPluginOnResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPluginOnResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPluginOnResponse copyWith(void Function(SetPluginOnResponse) updates) =>
      super.copyWith((message) => updates(message as SetPluginOnResponse))
          as SetPluginOnResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SetPluginOnResponse() / SetPluginOnResponse.new instead')
  static SetPluginOnResponse create() => SetPluginOnResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetPluginOnResponse._();
  @$core.override
  SetPluginOnResponse createEmptyInstance() => SetPluginOnResponse._();
  @$core.pragma('dart2js:noInline')
  static SetPluginOnResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPluginOnResponse>(
          SetPluginOnResponse.$_createMessage);
  static SetPluginOnResponse? _defaultInstance;
}

class UninstallPluginRequest extends $pb.GeneratedMessage {
  factory UninstallPluginRequest({
    $core.String? folder,
    $core.String? id,
    $core.String? agent,
  }) {
    final result = UninstallPluginRequest._();
    if (folder != null) result.folder = folder;
    if (id != null) result.id = id;
    if (agent != null) result.agent = agent;
    return result;
  }

  UninstallPluginRequest._();

  factory UninstallPluginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UninstallPluginRequest()..mergeFromBuffer(data, registry);
  factory UninstallPluginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UninstallPluginRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UninstallPluginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: UninstallPluginRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOS(3, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UninstallPluginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UninstallPluginRequest copyWith(
          void Function(UninstallPluginRequest) updates) =>
      super.copyWith((message) => updates(message as UninstallPluginRequest))
          as UninstallPluginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UninstallPluginRequest() / UninstallPluginRequest.new instead')
  static UninstallPluginRequest create() => UninstallPluginRequest._();
  static $pb.GeneratedMessage $_createMessage() => UninstallPluginRequest._();
  @$core.override
  UninstallPluginRequest createEmptyInstance() => UninstallPluginRequest._();
  @$core.pragma('dart2js:noInline')
  static UninstallPluginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UninstallPluginRequest>(
          UninstallPluginRequest.$_createMessage);
  static UninstallPluginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get agent => $_getSZ(2);
  @$pb.TagNumber(3)
  set agent($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAgent() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgent() => $_clearField(3);
}

class UninstallPluginResponse extends $pb.GeneratedMessage {
  factory UninstallPluginResponse() => UninstallPluginResponse._();

  UninstallPluginResponse._();

  factory UninstallPluginResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UninstallPluginResponse()..mergeFromBuffer(data, registry);
  factory UninstallPluginResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UninstallPluginResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UninstallPluginResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: UninstallPluginResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UninstallPluginResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UninstallPluginResponse copyWith(
          void Function(UninstallPluginResponse) updates) =>
      super.copyWith((message) => updates(message as UninstallPluginResponse))
          as UninstallPluginResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UninstallPluginResponse() / UninstallPluginResponse.new instead')
  static UninstallPluginResponse create() => UninstallPluginResponse._();
  static $pb.GeneratedMessage $_createMessage() => UninstallPluginResponse._();
  @$core.override
  UninstallPluginResponse createEmptyInstance() => UninstallPluginResponse._();
  @$core.pragma('dart2js:noInline')
  static UninstallPluginResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UninstallPluginResponse>(
          UninstallPluginResponse.$_createMessage);
  static UninstallPluginResponse? _defaultInstance;
}

class TrashSkillRequest extends $pb.GeneratedMessage {
  factory TrashSkillRequest({
    $core.String? folder,
    $core.String? path,
    $core.String? agent,
  }) {
    final result = TrashSkillRequest._();
    if (folder != null) result.folder = folder;
    if (path != null) result.path = path;
    if (agent != null) result.agent = agent;
    return result;
  }

  TrashSkillRequest._();

  factory TrashSkillRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrashSkillRequest()..mergeFromBuffer(data, registry);
  factory TrashSkillRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrashSkillRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrashSkillRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TrashSkillRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aOS(3, _omitFieldNames ? '' : 'agent')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrashSkillRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrashSkillRequest copyWith(void Function(TrashSkillRequest) updates) =>
      super.copyWith((message) => updates(message as TrashSkillRequest))
          as TrashSkillRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TrashSkillRequest() / TrashSkillRequest.new instead')
  static TrashSkillRequest create() => TrashSkillRequest._();
  static $pb.GeneratedMessage $_createMessage() => TrashSkillRequest._();
  @$core.override
  TrashSkillRequest createEmptyInstance() => TrashSkillRequest._();
  @$core.pragma('dart2js:noInline')
  static TrashSkillRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<TrashSkillRequest>(
          TrashSkillRequest.$_createMessage);
  static TrashSkillRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// The skill's folder, as listed.
  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get agent => $_getSZ(2);
  @$pb.TagNumber(3)
  set agent($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAgent() => $_has(2);
  @$pb.TagNumber(3)
  void clearAgent() => $_clearField(3);
}

class TrashSkillResponse extends $pb.GeneratedMessage {
  factory TrashSkillResponse() => TrashSkillResponse._();

  TrashSkillResponse._();

  factory TrashSkillResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrashSkillResponse()..mergeFromBuffer(data, registry);
  factory TrashSkillResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TrashSkillResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TrashSkillResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TrashSkillResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrashSkillResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TrashSkillResponse copyWith(void Function(TrashSkillResponse) updates) =>
      super.copyWith((message) => updates(message as TrashSkillResponse))
          as TrashSkillResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use TrashSkillResponse() / TrashSkillResponse.new instead')
  static TrashSkillResponse create() => TrashSkillResponse._();
  static $pb.GeneratedMessage $_createMessage() => TrashSkillResponse._();
  @$core.override
  TrashSkillResponse createEmptyInstance() => TrashSkillResponse._();
  @$core.pragma('dart2js:noInline')
  static TrashSkillResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TrashSkillResponse>(
          TrashSkillResponse.$_createMessage);
  static TrashSkillResponse? _defaultInstance;
}

class LinkSkillRequest extends $pb.GeneratedMessage {
  factory LinkSkillRequest({
    $core.String? folder,
    $core.String? agent,
    $core.String? path,
  }) {
    final result = LinkSkillRequest._();
    if (folder != null) result.folder = folder;
    if (agent != null) result.agent = agent;
    if (path != null) result.path = path;
    return result;
  }

  LinkSkillRequest._();

  factory LinkSkillRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkSkillRequest()..mergeFromBuffer(data, registry);
  factory LinkSkillRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkSkillRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkSkillRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LinkSkillRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'agent')
    ..aOS(3, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkSkillRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkSkillRequest copyWith(void Function(LinkSkillRequest) updates) =>
      super.copyWith((message) => updates(message as LinkSkillRequest))
          as LinkSkillRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LinkSkillRequest() / LinkSkillRequest.new instead')
  static LinkSkillRequest create() => LinkSkillRequest._();
  static $pb.GeneratedMessage $_createMessage() => LinkSkillRequest._();
  @$core.override
  LinkSkillRequest createEmptyInstance() => LinkSkillRequest._();
  @$core.pragma('dart2js:noInline')
  static LinkSkillRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LinkSkillRequest>(
          LinkSkillRequest.$_createMessage);
  static LinkSkillRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get agent => $_getSZ(1);
  @$pb.TagNumber(2)
  set agent($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAgent() => $_has(1);
  @$pb.TagNumber(2)
  void clearAgent() => $_clearField(2);

  /// The shared skill's folder, as listed.
  @$pb.TagNumber(3)
  $core.String get path => $_getSZ(2);
  @$pb.TagNumber(3)
  set path($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPath() => $_has(2);
  @$pb.TagNumber(3)
  void clearPath() => $_clearField(3);
}

class LinkSkillResponse extends $pb.GeneratedMessage {
  factory LinkSkillResponse() => LinkSkillResponse._();

  LinkSkillResponse._();

  factory LinkSkillResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkSkillResponse()..mergeFromBuffer(data, registry);
  factory LinkSkillResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LinkSkillResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LinkSkillResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LinkSkillResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkSkillResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LinkSkillResponse copyWith(void Function(LinkSkillResponse) updates) =>
      super.copyWith((message) => updates(message as LinkSkillResponse))
          as LinkSkillResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LinkSkillResponse() / LinkSkillResponse.new instead')
  static LinkSkillResponse create() => LinkSkillResponse._();
  static $pb.GeneratedMessage $_createMessage() => LinkSkillResponse._();
  @$core.override
  LinkSkillResponse createEmptyInstance() => LinkSkillResponse._();
  @$core.pragma('dart2js:noInline')
  static LinkSkillResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LinkSkillResponse>(
          LinkSkillResponse.$_createMessage);
  static LinkSkillResponse? _defaultInstance;
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

class GetFileRequest extends $pb.GeneratedMessage {
  factory GetFileRequest({
    $core.String? folder,
    $core.String? path,
  }) {
    final result = GetFileRequest._();
    if (folder != null) result.folder = folder;
    if (path != null) result.path = path;
    return result;
  }

  GetFileRequest._();

  factory GetFileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFileRequest()..mergeFromBuffer(data, registry);
  factory GetFileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFileRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetFileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetFileRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'folder')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFileRequest copyWith(void Function(GetFileRequest) updates) =>
      super.copyWith((message) => updates(message as GetFileRequest))
          as GetFileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetFileRequest() / GetFileRequest.new instead')
  static GetFileRequest create() => GetFileRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetFileRequest._();
  @$core.override
  GetFileRequest createEmptyInstance() => GetFileRequest._();
  @$core.pragma('dart2js:noInline')
  static GetFileRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetFileRequest>(
          GetFileRequest.$_createMessage);
  static GetFileRequest? _defaultInstance;

  /// An absolute path.
  @$pb.TagNumber(1)
  $core.String get folder => $_getSZ(0);
  @$pb.TagNumber(1)
  set folder($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFolder() => $_has(0);
  @$pb.TagNumber(1)
  void clearFolder() => $_clearField(1);

  /// Relative to folder.
  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);
}

class GetFileResponse extends $pb.GeneratedMessage {
  factory GetFileResponse({
    FileChange? file,
  }) {
    final result = GetFileResponse._();
    if (file != null) result.file = file;
    return result;
  }

  GetFileResponse._();

  factory GetFileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFileResponse()..mergeFromBuffer(data, registry);
  factory GetFileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetFileResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetFileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetFileResponse.$_createMessage)
    ..aOM<FileChange>(1, _omitFieldNames ? '' : 'file',
        subBuilder: FileChange.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetFileResponse copyWith(void Function(GetFileResponse) updates) =>
      super.copyWith((message) => updates(message as GetFileResponse))
          as GetFileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetFileResponse() / GetFileResponse.new instead')
  static GetFileResponse create() => GetFileResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetFileResponse._();
  @$core.override
  GetFileResponse createEmptyInstance() => GetFileResponse._();
  @$core.pragma('dart2js:noInline')
  static GetFileResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetFileResponse>(
          GetFileResponse.$_createMessage);
  static GetFileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  FileChange get file => $_getN(0);
  @$pb.TagNumber(1)
  set file(FileChange value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);
  @$pb.TagNumber(1)
  FileChange ensureFile() => $_ensure(0);
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
  removedChats,
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
    RemovedChats? removedChats,
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
    if (removedChats != null) result.removedChats = removedChats;
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
    15: EventsResponse_Kind.removedChats,
    0: EventsResponse_Kind.notSet
  };
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'EventsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: EventsResponse.$_createMessage)
    ..oo(0, [2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15])
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
    ..aOM<RemovedChats>(15, _omitFieldNames ? '' : 'removedChats',
        subBuilder: RemovedChats.$_createMessage)
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
  @$pb.TagNumber(15)
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
  @$pb.TagNumber(15)
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

  /// The chats removed because their agent no longer has their sessions,
  /// all of them (ListChatsResponse.removed); chat_id is empty.
  @$pb.TagNumber(15)
  RemovedChats get removedChats => $_getN(14);
  @$pb.TagNumber(15)
  set removedChats(RemovedChats value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasRemovedChats() => $_has(14);
  @$pb.TagNumber(15)
  void clearRemovedChats() => $_clearField(15);
  @$pb.TagNumber(15)
  RemovedChats ensureRemovedChats() => $_ensure(14);
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
    $core.String? relayCall,
    $core.String? relayState,
    $core.String? relayedBy,
    Findings? findings,
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
    if (relayCall != null) result.relayCall = relayCall;
    if (relayState != null) result.relayState = relayState;
    if (relayedBy != null) result.relayedBy = relayedBy;
    if (findings != null) result.findings = findings;
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
    ..aOS(28, _omitFieldNames ? '' : 'relayCall')
    ..aOS(29, _omitFieldNames ? '' : 'relayState')
    ..aOS(30, _omitFieldNames ? '' : 'relayedBy')
    ..aOM<Findings>(31, _omitFieldNames ? '' : 'findings',
        subBuilder: Findings.$_createMessage)
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
  /// pass it to, and that subagent's tool call (not known after a replay
  /// the agent's own call doesn't link).
  @$pb.TagNumber(27)
  $core.String get relayTo => $_getSZ(26);
  @$pb.TagNumber(27)
  set relayTo($core.String value) => $_setString(26, value);
  @$pb.TagNumber(27)
  $core.bool hasRelayTo() => $_has(26);
  @$pb.TagNumber(27)
  void clearRelayTo() => $_clearField(27);

  @$pb.TagNumber(28)
  $core.String get relayCall => $_getSZ(27);
  @$pb.TagNumber(28)
  set relayCall($core.String value) => $_setString(27, value);
  @$pb.TagNumber(28)
  $core.bool hasRelayCall() => $_has(27);
  @$pb.TagNumber(28)
  void clearRelayCall() => $_clearField(28);

  /// How the relay went: "sending" until the agent passes it on (its call
  /// that does is relayed_by), "relayed" once that call completes, "failed"
  /// when it fails or the turn ends without one; "" when unknown (replayed).
  @$pb.TagNumber(29)
  $core.String get relayState => $_getSZ(28);
  @$pb.TagNumber(29)
  set relayState($core.String value) => $_setString(28, value);
  @$pb.TagNumber(29)
  $core.bool hasRelayState() => $_has(28);
  @$pb.TagNumber(29)
  void clearRelayState() => $_clearField(29);

  @$pb.TagNumber(30)
  $core.String get relayedBy => $_getSZ(29);
  @$pb.TagNumber(30)
  set relayedBy($core.String value) => $_setString(29, value);
  @$pb.TagNumber(30)
  $core.bool hasRelayedBy() => $_has(29);
  @$pb.TagNumber(30)
  void clearRelayedBy() => $_clearField(30);

  /// For a tool call that reports a code review's result (Claude's
  /// ReportFindings): what it found.
  @$pb.TagNumber(31)
  Findings get findings => $_getN(30);
  @$pb.TagNumber(31)
  set findings(Findings value) => $_setField(31, value);
  @$pb.TagNumber(31)
  $core.bool hasFindings() => $_has(30);
  @$pb.TagNumber(31)
  void clearFindings() => $_clearField(31);
  @$pb.TagNumber(31)
  Findings ensureFindings() => $_ensure(30);
}

/// A code review's result: the effort level it ran at ("medium"; "" when
/// not said) and its findings, most severe first.
class Findings extends $pb.GeneratedMessage {
  factory Findings({
    $core.String? level,
    $core.Iterable<Finding>? items,
  }) {
    final result = Findings._();
    if (level != null) result.level = level;
    if (items != null) result.items.addAll(items);
    return result;
  }

  Findings._();

  factory Findings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Findings()..mergeFromBuffer(data, registry);
  factory Findings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Findings()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Findings',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Findings.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'level')
    ..pPM<Finding>(2, _omitFieldNames ? '' : 'items',
        subBuilder: Finding.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Findings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Findings copyWith(void Function(Findings) updates) =>
      super.copyWith((message) => updates(message as Findings)) as Findings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Findings() / Findings.new instead')
  static Findings create() => Findings._();
  static $pb.GeneratedMessage $_createMessage() => Findings._();
  @$core.override
  Findings createEmptyInstance() => Findings._();
  @$core.pragma('dart2js:noInline')
  static Findings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Findings>(Findings.$_createMessage);
  static Findings? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get level => $_getSZ(0);
  @$pb.TagNumber(1)
  set level($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLevel() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<Finding> get items => $_getList(1);
}

/// One thing a review found. file is relative to the repository (or
/// absolute), line from 1 (0: not given); short_summary (up to 60
/// characters), category ("correctness"), verdict ("CONFIRMED",
/// "PLAUSIBLE") and outcome after fixes ("fixed", "skipped",
/// "no_change_needed") may be empty. All of it is the agent's text.
class Finding extends $pb.GeneratedMessage {
  factory Finding({
    $core.String? file,
    $core.int? line,
    $core.String? summary,
    $core.String? shortSummary,
    $core.String? failureScenario,
    $core.String? category,
    $core.String? verdict,
    $core.String? outcome,
  }) {
    final result = Finding._();
    if (file != null) result.file = file;
    if (line != null) result.line = line;
    if (summary != null) result.summary = summary;
    if (shortSummary != null) result.shortSummary = shortSummary;
    if (failureScenario != null) result.failureScenario = failureScenario;
    if (category != null) result.category = category;
    if (verdict != null) result.verdict = verdict;
    if (outcome != null) result.outcome = outcome;
    return result;
  }

  Finding._();

  factory Finding.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Finding()..mergeFromBuffer(data, registry);
  factory Finding.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      Finding()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Finding',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: Finding.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'file')
    ..aI(2, _omitFieldNames ? '' : 'line')
    ..aOS(3, _omitFieldNames ? '' : 'summary')
    ..aOS(4, _omitFieldNames ? '' : 'shortSummary')
    ..aOS(5, _omitFieldNames ? '' : 'failureScenario')
    ..aOS(6, _omitFieldNames ? '' : 'category')
    ..aOS(7, _omitFieldNames ? '' : 'verdict')
    ..aOS(8, _omitFieldNames ? '' : 'outcome')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Finding clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Finding copyWith(void Function(Finding) updates) =>
      super.copyWith((message) => updates(message as Finding)) as Finding;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use Finding() / Finding.new instead')
  static Finding create() => Finding._();
  static $pb.GeneratedMessage $_createMessage() => Finding._();
  @$core.override
  Finding createEmptyInstance() => Finding._();
  @$core.pragma('dart2js:noInline')
  static Finding getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Finding>(Finding.$_createMessage);
  static Finding? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get file => $_getSZ(0);
  @$pb.TagNumber(1)
  set file($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasFile() => $_has(0);
  @$pb.TagNumber(1)
  void clearFile() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get line => $_getIZ(1);
  @$pb.TagNumber(2)
  set line($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLine() => $_has(1);
  @$pb.TagNumber(2)
  void clearLine() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get summary => $_getSZ(2);
  @$pb.TagNumber(3)
  set summary($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSummary() => $_has(2);
  @$pb.TagNumber(3)
  void clearSummary() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get shortSummary => $_getSZ(3);
  @$pb.TagNumber(4)
  set shortSummary($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasShortSummary() => $_has(3);
  @$pb.TagNumber(4)
  void clearShortSummary() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get failureScenario => $_getSZ(4);
  @$pb.TagNumber(5)
  set failureScenario($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFailureScenario() => $_has(4);
  @$pb.TagNumber(5)
  void clearFailureScenario() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get category => $_getSZ(5);
  @$pb.TagNumber(6)
  set category($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCategory() => $_has(5);
  @$pb.TagNumber(6)
  void clearCategory() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get verdict => $_getSZ(6);
  @$pb.TagNumber(7)
  set verdict($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVerdict() => $_has(6);
  @$pb.TagNumber(7)
  void clearVerdict() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get outcome => $_getSZ(7);
  @$pb.TagNumber(8)
  set outcome($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOutcome() => $_has(7);
  @$pb.TagNumber(8)
  void clearOutcome() => $_clearField(8);
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

  /// "running", "done", "failed", or "stopped" (with its agent, by Nushi).
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
    $core.int? index,
  }) {
    final result = ItemEvent._();
    if (item != null) result.item = item;
    if (append != null) result.append = append;
    if (index != null) result.index = index;
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
    ..aI(3, _omitFieldNames ? '' : 'index')
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

  /// Where the item is in the chat, from 0 (not with append): a client that
  /// has only the recent part (GetChatRequest.recent) leaves out what is
  /// before it.
  @$pb.TagNumber(3)
  $core.int get index => $_getIZ(2);
  @$pb.TagNumber(3)
  set index($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIndex() => $_has(2);
  @$pb.TagNumber(3)
  void clearIndex() => $_clearField(3);
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
    $core.bool? reopenFailed,
    $core.bool? sessionGone,
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
    if (reopenFailed != null) result.reopenFailed = reopenFailed;
    if (sessionGone != null) result.sessionGone = sessionGone;
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
    ..aOB(12, _omitFieldNames ? '' : 'reopenFailed')
    ..aOB(13, _omitFieldNames ? '' : 'sessionGone')
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

  /// No agent runs for the chat because its last reopen failed (a notice
  /// says why); it isn't asleep. ReopenChat tries again; an agent that
  /// becomes ready clears it where it wasn't (the next ReopenChat reopens).
  @$pb.TagNumber(12)
  $core.bool get reopenFailed => $_getBF(10);
  @$pb.TagNumber(12)
  set reopenFailed($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(12)
  $core.bool hasReopenFailed() => $_has(10);
  @$pb.TagNumber(12)
  void clearReopenFailed() => $_clearField(12);

  /// Of a chat whose reopen failed: its agent no longer has its session
  /// (it deleted it). The chat stays only for its worktree's or scratch
  /// folder's work; DeleteChat is what's left.
  @$pb.TagNumber(13)
  $core.bool get sessionGone => $_getBF(11);
  @$pb.TagNumber(13)
  set sessionGone($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(13)
  $core.bool hasSessionGone() => $_has(11);
  @$pb.TagNumber(13)
  void clearSessionGone() => $_clearField(13);
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
    $core.List<$core.int>? key,
  }) {
    final result = Remote._();
    if (on != null) result.on = on;
    if (relay != null) result.relay = relay;
    if (state != null) result.state = state;
    if (error != null) result.error = error;
    if (devices != null) result.devices.addAll(devices);
    if (pairing != null) result.pairing = pairing;
    if (rendezvous != null) result.rendezvous = rendezvous;
    if (key != null) result.key = key;
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
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'key', $pb.PbFieldType.OY)
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

  /// "off", "connecting", "connected" (waiting at the relay for phones),
  /// "reconnecting" (the relay dropped the wait: a restart, the network;
  /// error says how) or "error" (error says what; it tries again, waiting
  /// up to 30 s between tries).
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

  /// The daemon's Noise public key (32 bytes), so a phone and the Mac can
  /// show the same fingerprint of it.
  @$pb.TagNumber(8)
  $core.List<$core.int> get key => $_getN(7);
  @$pb.TagNumber(8)
  set key($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasKey() => $_has(7);
  @$pb.TagNumber(8)
  void clearKey() => $_clearField(8);
}

class Device extends $pb.GeneratedMessage {
  factory Device({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? paired,
    $fixnum.Int64? lastSeen,
    $core.bool? connected,
    $core.String? kind,
    $core.bool? push,
  }) {
    final result = Device._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (paired != null) result.paired = paired;
    if (lastSeen != null) result.lastSeen = lastSeen;
    if (connected != null) result.connected = connected;
    if (kind != null) result.kind = kind;
    if (push != null) result.push = push;
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
    ..aOS(6, _omitFieldNames ? '' : 'kind')
    ..aOB(7, _omitFieldNames ? '' : 'push')
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

  /// "web" for the web app, "" for an app.
  @$pb.TagNumber(6)
  $core.String get kind => $_getSZ(5);
  @$pb.TagNumber(6)
  set kind($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasKind() => $_has(5);
  @$pb.TagNumber(6)
  void clearKind() => $_clearField(6);

  /// It has a push subscription: notifications are on.
  @$pb.TagNumber(7)
  $core.bool get push => $_getBF(6);
  @$pb.TagNumber(7)
  set push($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPush() => $_has(6);
  @$pb.TagNumber(7)
  void clearPush() => $_clearField(7);
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

class GetPushKeyRequest extends $pb.GeneratedMessage {
  factory GetPushKeyRequest() => GetPushKeyRequest._();

  GetPushKeyRequest._();

  factory GetPushKeyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPushKeyRequest()..mergeFromBuffer(data, registry);
  factory GetPushKeyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPushKeyRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPushKeyRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetPushKeyRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPushKeyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPushKeyRequest copyWith(void Function(GetPushKeyRequest) updates) =>
      super.copyWith((message) => updates(message as GetPushKeyRequest))
          as GetPushKeyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetPushKeyRequest() / GetPushKeyRequest.new instead')
  static GetPushKeyRequest create() => GetPushKeyRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetPushKeyRequest._();
  @$core.override
  GetPushKeyRequest createEmptyInstance() => GetPushKeyRequest._();
  @$core.pragma('dart2js:noInline')
  static GetPushKeyRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetPushKeyRequest>(
          GetPushKeyRequest.$_createMessage);
  static GetPushKeyRequest? _defaultInstance;
}

class GetPushKeyResponse extends $pb.GeneratedMessage {
  factory GetPushKeyResponse({
    $core.String? key,
  }) {
    final result = GetPushKeyResponse._();
    if (key != null) result.key = key;
    return result;
  }

  GetPushKeyResponse._();

  factory GetPushKeyResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPushKeyResponse()..mergeFromBuffer(data, registry);
  factory GetPushKeyResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetPushKeyResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPushKeyResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetPushKeyResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPushKeyResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPushKeyResponse copyWith(void Function(GetPushKeyResponse) updates) =>
      super.copyWith((message) => updates(message as GetPushKeyResponse))
          as GetPushKeyResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetPushKeyResponse() / GetPushKeyResponse.new instead')
  static GetPushKeyResponse create() => GetPushKeyResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetPushKeyResponse._();
  @$core.override
  GetPushKeyResponse createEmptyInstance() => GetPushKeyResponse._();
  @$core.pragma('dart2js:noInline')
  static GetPushKeyResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPushKeyResponse>(
          GetPushKeyResponse.$_createMessage);
  static GetPushKeyResponse? _defaultInstance;

  /// The VAPID public key, uncompressed P-256, base64url without padding.
  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);
}

class SetPushSubscriptionRequest extends $pb.GeneratedMessage {
  factory SetPushSubscriptionRequest({
    $core.String? endpoint,
    $core.List<$core.int>? p256dh,
    $core.List<$core.int>? auth,
  }) {
    final result = SetPushSubscriptionRequest._();
    if (endpoint != null) result.endpoint = endpoint;
    if (p256dh != null) result.p256dh = p256dh;
    if (auth != null) result.auth = auth;
    return result;
  }

  SetPushSubscriptionRequest._();

  factory SetPushSubscriptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPushSubscriptionRequest()..mergeFromBuffer(data, registry);
  factory SetPushSubscriptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPushSubscriptionRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPushSubscriptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetPushSubscriptionRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'endpoint')
    ..a<$core.List<$core.int>>(
        2, _omitFieldNames ? '' : 'p256dh', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'auth', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPushSubscriptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPushSubscriptionRequest copyWith(
          void Function(SetPushSubscriptionRequest) updates) =>
      super.copyWith(
              (message) => updates(message as SetPushSubscriptionRequest))
          as SetPushSubscriptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetPushSubscriptionRequest() / SetPushSubscriptionRequest.new instead')
  static SetPushSubscriptionRequest create() => SetPushSubscriptionRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      SetPushSubscriptionRequest._();
  @$core.override
  SetPushSubscriptionRequest createEmptyInstance() =>
      SetPushSubscriptionRequest._();
  @$core.pragma('dart2js:noInline')
  static SetPushSubscriptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPushSubscriptionRequest>(
          SetPushSubscriptionRequest.$_createMessage);
  static SetPushSubscriptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get endpoint => $_getSZ(0);
  @$pb.TagNumber(1)
  set endpoint($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEndpoint() => $_has(0);
  @$pb.TagNumber(1)
  void clearEndpoint() => $_clearField(1);

  /// The subscription's keys: p256dh (65 bytes) and auth (16 bytes).
  @$pb.TagNumber(2)
  $core.List<$core.int> get p256dh => $_getN(1);
  @$pb.TagNumber(2)
  set p256dh($core.List<$core.int> value) => $_setBytes(1, value);
  @$pb.TagNumber(2)
  $core.bool hasP256dh() => $_has(1);
  @$pb.TagNumber(2)
  void clearP256dh() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get auth => $_getN(2);
  @$pb.TagNumber(3)
  set auth($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAuth() => $_has(2);
  @$pb.TagNumber(3)
  void clearAuth() => $_clearField(3);
}

class SetPushSubscriptionResponse extends $pb.GeneratedMessage {
  factory SetPushSubscriptionResponse() => SetPushSubscriptionResponse._();

  SetPushSubscriptionResponse._();

  factory SetPushSubscriptionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPushSubscriptionResponse()..mergeFromBuffer(data, registry);
  factory SetPushSubscriptionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetPushSubscriptionResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetPushSubscriptionResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetPushSubscriptionResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPushSubscriptionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetPushSubscriptionResponse copyWith(
          void Function(SetPushSubscriptionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SetPushSubscriptionResponse))
          as SetPushSubscriptionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetPushSubscriptionResponse() / SetPushSubscriptionResponse.new instead')
  static SetPushSubscriptionResponse create() =>
      SetPushSubscriptionResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      SetPushSubscriptionResponse._();
  @$core.override
  SetPushSubscriptionResponse createEmptyInstance() =>
      SetPushSubscriptionResponse._();
  @$core.pragma('dart2js:noInline')
  static SetPushSubscriptionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetPushSubscriptionResponse>(
          SetPushSubscriptionResponse.$_createMessage);
  static SetPushSubscriptionResponse? _defaultInstance;
}

class SetDeviceViewRequest extends $pb.GeneratedMessage {
  factory SetDeviceViewRequest({
    $core.String? chatId,
  }) {
    final result = SetDeviceViewRequest._();
    if (chatId != null) result.chatId = chatId;
    return result;
  }

  SetDeviceViewRequest._();

  factory SetDeviceViewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetDeviceViewRequest()..mergeFromBuffer(data, registry);
  factory SetDeviceViewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetDeviceViewRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetDeviceViewRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetDeviceViewRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'chatId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDeviceViewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDeviceViewRequest copyWith(void Function(SetDeviceViewRequest) updates) =>
      super.copyWith((message) => updates(message as SetDeviceViewRequest))
          as SetDeviceViewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetDeviceViewRequest() / SetDeviceViewRequest.new instead')
  static SetDeviceViewRequest create() => SetDeviceViewRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetDeviceViewRequest._();
  @$core.override
  SetDeviceViewRequest createEmptyInstance() => SetDeviceViewRequest._();
  @$core.pragma('dart2js:noInline')
  static SetDeviceViewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetDeviceViewRequest>(
          SetDeviceViewRequest.$_createMessage);
  static SetDeviceViewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get chatId => $_getSZ(0);
  @$pb.TagNumber(1)
  set chatId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasChatId() => $_has(0);
  @$pb.TagNumber(1)
  void clearChatId() => $_clearField(1);
}

class SetDeviceViewResponse extends $pb.GeneratedMessage {
  factory SetDeviceViewResponse() => SetDeviceViewResponse._();

  SetDeviceViewResponse._();

  factory SetDeviceViewResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetDeviceViewResponse()..mergeFromBuffer(data, registry);
  factory SetDeviceViewResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetDeviceViewResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetDeviceViewResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetDeviceViewResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDeviceViewResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetDeviceViewResponse copyWith(
          void Function(SetDeviceViewResponse) updates) =>
      super.copyWith((message) => updates(message as SetDeviceViewResponse))
          as SetDeviceViewResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetDeviceViewResponse() / SetDeviceViewResponse.new instead')
  static SetDeviceViewResponse create() => SetDeviceViewResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetDeviceViewResponse._();
  @$core.override
  SetDeviceViewResponse createEmptyInstance() => SetDeviceViewResponse._();
  @$core.pragma('dart2js:noInline')
  static SetDeviceViewResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetDeviceViewResponse>(
          SetDeviceViewResponse.$_createMessage);
  static SetDeviceViewResponse? _defaultInstance;
}

class SendTestPushRequest extends $pb.GeneratedMessage {
  factory SendTestPushRequest({
    $core.String? deviceId,
  }) {
    final result = SendTestPushRequest._();
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  SendTestPushRequest._();

  factory SendTestPushRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendTestPushRequest()..mergeFromBuffer(data, registry);
  factory SendTestPushRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendTestPushRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendTestPushRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SendTestPushRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendTestPushRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendTestPushRequest copyWith(void Function(SendTestPushRequest) updates) =>
      super.copyWith((message) => updates(message as SendTestPushRequest))
          as SendTestPushRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SendTestPushRequest() / SendTestPushRequest.new instead')
  static SendTestPushRequest create() => SendTestPushRequest._();
  static $pb.GeneratedMessage $_createMessage() => SendTestPushRequest._();
  @$core.override
  SendTestPushRequest createEmptyInstance() => SendTestPushRequest._();
  @$core.pragma('dart2js:noInline')
  static SendTestPushRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendTestPushRequest>(
          SendTestPushRequest.$_createMessage);
  static SendTestPushRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);
}

class SendTestPushResponse extends $pb.GeneratedMessage {
  factory SendTestPushResponse() => SendTestPushResponse._();

  SendTestPushResponse._();

  factory SendTestPushResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendTestPushResponse()..mergeFromBuffer(data, registry);
  factory SendTestPushResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SendTestPushResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SendTestPushResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SendTestPushResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendTestPushResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SendTestPushResponse copyWith(void Function(SendTestPushResponse) updates) =>
      super.copyWith((message) => updates(message as SendTestPushResponse))
          as SendTestPushResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SendTestPushResponse() / SendTestPushResponse.new instead')
  static SendTestPushResponse create() => SendTestPushResponse._();
  static $pb.GeneratedMessage $_createMessage() => SendTestPushResponse._();
  @$core.override
  SendTestPushResponse createEmptyInstance() => SendTestPushResponse._();
  @$core.pragma('dart2js:noInline')
  static SendTestPushResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SendTestPushResponse>(
          SendTestPushResponse.$_createMessage);
  static SendTestPushResponse? _defaultInstance;
}

class UnpairThisDeviceRequest extends $pb.GeneratedMessage {
  factory UnpairThisDeviceRequest() => UnpairThisDeviceRequest._();

  UnpairThisDeviceRequest._();

  factory UnpairThisDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnpairThisDeviceRequest()..mergeFromBuffer(data, registry);
  factory UnpairThisDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnpairThisDeviceRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnpairThisDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: UnpairThisDeviceRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairThisDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairThisDeviceRequest copyWith(
          void Function(UnpairThisDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as UnpairThisDeviceRequest))
          as UnpairThisDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UnpairThisDeviceRequest() / UnpairThisDeviceRequest.new instead')
  static UnpairThisDeviceRequest create() => UnpairThisDeviceRequest._();
  static $pb.GeneratedMessage $_createMessage() => UnpairThisDeviceRequest._();
  @$core.override
  UnpairThisDeviceRequest createEmptyInstance() => UnpairThisDeviceRequest._();
  @$core.pragma('dart2js:noInline')
  static UnpairThisDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnpairThisDeviceRequest>(
          UnpairThisDeviceRequest.$_createMessage);
  static UnpairThisDeviceRequest? _defaultInstance;
}

class UnpairThisDeviceResponse extends $pb.GeneratedMessage {
  factory UnpairThisDeviceResponse() => UnpairThisDeviceResponse._();

  UnpairThisDeviceResponse._();

  factory UnpairThisDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnpairThisDeviceResponse()..mergeFromBuffer(data, registry);
  factory UnpairThisDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      UnpairThisDeviceResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UnpairThisDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: UnpairThisDeviceResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairThisDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UnpairThisDeviceResponse copyWith(
          void Function(UnpairThisDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as UnpairThisDeviceResponse))
          as UnpairThisDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use UnpairThisDeviceResponse() / UnpairThisDeviceResponse.new instead')
  static UnpairThisDeviceResponse create() => UnpairThisDeviceResponse._();
  static $pb.GeneratedMessage $_createMessage() => UnpairThisDeviceResponse._();
  @$core.override
  UnpairThisDeviceResponse createEmptyInstance() =>
      UnpairThisDeviceResponse._();
  @$core.pragma('dart2js:noInline')
  static UnpairThisDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UnpairThisDeviceResponse>(
          UnpairThisDeviceResponse.$_createMessage);
  static UnpairThisDeviceResponse? _defaultInstance;
}

class LogRequest extends $pb.GeneratedMessage {
  factory LogRequest({
    $core.String? level,
    $core.String? message,
    $core.String? stack,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? attrs,
  }) {
    final result = LogRequest._();
    if (level != null) result.level = level;
    if (message != null) result.message = message;
    if (stack != null) result.stack = stack;
    if (attrs != null) result.attrs.addEntries(attrs);
    return result;
  }

  LogRequest._();

  factory LogRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogRequest()..mergeFromBuffer(data, registry);
  factory LogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LogRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'level')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..aOS(3, _omitFieldNames ? '' : 'stack')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'attrs',
        entryClassName: 'LogRequest.AttrsEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('nushi.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogRequest copyWith(void Function(LogRequest) updates) =>
      super.copyWith((message) => updates(message as LogRequest)) as LogRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LogRequest() / LogRequest.new instead')
  static LogRequest create() => LogRequest._();
  static $pb.GeneratedMessage $_createMessage() => LogRequest._();
  @$core.override
  LogRequest createEmptyInstance() => LogRequest._();
  @$core.pragma('dart2js:noInline')
  static LogRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LogRequest>(LogRequest.$_createMessage);
  static LogRequest? _defaultInstance;

  /// "debug", "info", "warn" or "error".
  @$pb.TagNumber(1)
  $core.String get level => $_getSZ(0);
  @$pb.TagNumber(1)
  set level($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLevel() => $_has(0);
  @$pb.TagNumber(1)
  void clearLevel() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);

  /// A Dart stack trace, for an error.
  @$pb.TagNumber(3)
  $core.String get stack => $_getSZ(2);
  @$pb.TagNumber(3)
  set stack($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStack() => $_has(2);
  @$pb.TagNumber(3)
  void clearStack() => $_clearField(3);

  /// More of the line, as key=value.
  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get attrs => $_getMap(3);
}

class LogResponse extends $pb.GeneratedMessage {
  factory LogResponse() => LogResponse._();

  LogResponse._();

  factory LogResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogResponse()..mergeFromBuffer(data, registry);
  factory LogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      LogResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: LogResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LogResponse copyWith(void Function(LogResponse) updates) =>
      super.copyWith((message) => updates(message as LogResponse))
          as LogResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use LogResponse() / LogResponse.new instead')
  static LogResponse create() => LogResponse._();
  static $pb.GeneratedMessage $_createMessage() => LogResponse._();
  @$core.override
  LogResponse createEmptyInstance() => LogResponse._();
  @$core.pragma('dart2js:noInline')
  static LogResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<LogResponse>(
          LogResponse.$_createMessage);
  static LogResponse? _defaultInstance;
}

/// A Jira site Nushi has a token for; id is its host.
class JiraSite extends $pb.GeneratedMessage {
  factory JiraSite({
    $core.String? id,
    $core.String? url,
    $core.String? email,
    $core.String? name,
    $core.String? accountId,
    $core.bool? scoped,
    $fixnum.Int64? expires,
    $fixnum.Int64? board,
    $core.String? boardName,
    $core.Iterable<JiraSearch>? searches,
    $core.String? problem,
    $core.bool? needsOk,
    $core.bool? needsRestart,
  }) {
    final result = JiraSite._();
    if (id != null) result.id = id;
    if (url != null) result.url = url;
    if (email != null) result.email = email;
    if (name != null) result.name = name;
    if (accountId != null) result.accountId = accountId;
    if (scoped != null) result.scoped = scoped;
    if (expires != null) result.expires = expires;
    if (board != null) result.board = board;
    if (boardName != null) result.boardName = boardName;
    if (searches != null) result.searches.addAll(searches);
    if (problem != null) result.problem = problem;
    if (needsOk != null) result.needsOk = needsOk;
    if (needsRestart != null) result.needsRestart = needsRestart;
    return result;
  }

  JiraSite._();

  factory JiraSite.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraSite()..mergeFromBuffer(data, registry);
  factory JiraSite.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraSite()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraSite',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraSite.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..aOS(3, _omitFieldNames ? '' : 'email')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'accountId')
    ..aOB(6, _omitFieldNames ? '' : 'scoped')
    ..aInt64(7, _omitFieldNames ? '' : 'expires')
    ..aInt64(8, _omitFieldNames ? '' : 'board')
    ..aOS(9, _omitFieldNames ? '' : 'boardName')
    ..pPM<JiraSearch>(10, _omitFieldNames ? '' : 'searches',
        subBuilder: JiraSearch.$_createMessage)
    ..aOS(11, _omitFieldNames ? '' : 'problem')
    ..aOB(12, _omitFieldNames ? '' : 'needsOk')
    ..aOB(13, _omitFieldNames ? '' : 'needsRestart')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraSite clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraSite copyWith(void Function(JiraSite) updates) =>
      super.copyWith((message) => updates(message as JiraSite)) as JiraSite;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraSite() / JiraSite.new instead')
  static JiraSite create() => JiraSite._();
  static $pb.GeneratedMessage $_createMessage() => JiraSite._();
  @$core.override
  JiraSite createEmptyInstance() => JiraSite._();
  @$core.pragma('dart2js:noInline')
  static JiraSite getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraSite>(JiraSite.$_createMessage);
  static JiraSite? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get email => $_getSZ(2);
  @$pb.TagNumber(3)
  set email($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmail() => $_clearField(3);

  /// Who the token is.
  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get accountId => $_getSZ(4);
  @$pb.TagNumber(5)
  set accountId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAccountId() => $_has(4);
  @$pb.TagNumber(5)
  void clearAccountId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get scoped => $_getBF(5);
  @$pb.TagNumber(6)
  set scoped($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScoped() => $_has(5);
  @$pb.TagNumber(6)
  void clearScoped() => $_clearField(6);

  /// When the token expires, if the user said (ms; 0: not known).
  @$pb.TagNumber(7)
  $fixnum.Int64 get expires => $_getI64(6);
  @$pb.TagNumber(7)
  set expires($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasExpires() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpires() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get board => $_getI64(7);
  @$pb.TagNumber(8)
  set board($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasBoard() => $_has(7);
  @$pb.TagNumber(8)
  void clearBoard() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get boardName => $_getSZ(8);
  @$pb.TagNumber(9)
  set boardName($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBoardName() => $_has(8);
  @$pb.TagNumber(9)
  void clearBoardName() => $_clearField(9);

  @$pb.TagNumber(10)
  $pb.PbList<JiraSearch> get searches => $_getList(9);

  /// Why Nushi can't use it now, if it can't; needs_ok: the keychain wants
  /// the user's OK (AllowJiraToken).
  @$pb.TagNumber(11)
  $core.String get problem => $_getSZ(10);
  @$pb.TagNumber(11)
  set problem($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasProblem() => $_has(10);
  @$pb.TagNumber(11)
  void clearProblem() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get needsOk => $_getBF(11);
  @$pb.TagNumber(12)
  set needsOk($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasNeedsOk() => $_has(11);
  @$pb.TagNumber(12)
  void clearNeedsOk() => $_clearField(12);

  /// The daemon can't reach the keychain until it starts again (its build
  /// was replaced or removed since it started, or it runs outside the
  /// user's login session): problem says so; Allow wouldn't help.
  @$pb.TagNumber(13)
  $core.bool get needsRestart => $_getBF(12);
  @$pb.TagNumber(13)
  set needsRestart($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasNeedsRestart() => $_has(12);
  @$pb.TagNumber(13)
  void clearNeedsRestart() => $_clearField(13);
}

class JiraSearch extends $pb.GeneratedMessage {
  factory JiraSearch({
    $core.String? name,
    $core.String? jql,
  }) {
    final result = JiraSearch._();
    if (name != null) result.name = name;
    if (jql != null) result.jql = jql;
    return result;
  }

  JiraSearch._();

  factory JiraSearch.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraSearch()..mergeFromBuffer(data, registry);
  factory JiraSearch.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraSearch()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraSearch',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraSearch.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'jql')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraSearch clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraSearch copyWith(void Function(JiraSearch) updates) =>
      super.copyWith((message) => updates(message as JiraSearch)) as JiraSearch;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraSearch() / JiraSearch.new instead')
  static JiraSearch create() => JiraSearch._();
  static $pb.GeneratedMessage $_createMessage() => JiraSearch._();
  @$core.override
  JiraSearch createEmptyInstance() => JiraSearch._();
  @$core.pragma('dart2js:noInline')
  static JiraSearch getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraSearch>(JiraSearch.$_createMessage);
  static JiraSearch? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get jql => $_getSZ(1);
  @$pb.TagNumber(2)
  set jql($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJql() => $_has(1);
  @$pb.TagNumber(2)
  void clearJql() => $_clearField(2);
}

class JiraIssueRef extends $pb.GeneratedMessage {
  factory JiraIssueRef({
    $core.String? key,
    $core.String? summary,
    $core.String? type,
    $core.String? status,
    $core.String? statusCategory,
  }) {
    final result = JiraIssueRef._();
    if (key != null) result.key = key;
    if (summary != null) result.summary = summary;
    if (type != null) result.type = type;
    if (status != null) result.status = status;
    if (statusCategory != null) result.statusCategory = statusCategory;
    return result;
  }

  JiraIssueRef._();

  factory JiraIssueRef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraIssueRef()..mergeFromBuffer(data, registry);
  factory JiraIssueRef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraIssueRef()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraIssueRef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraIssueRef.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'summary')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..aOS(5, _omitFieldNames ? '' : 'statusCategory')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraIssueRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraIssueRef copyWith(void Function(JiraIssueRef) updates) =>
      super.copyWith((message) => updates(message as JiraIssueRef))
          as JiraIssueRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraIssueRef() / JiraIssueRef.new instead')
  static JiraIssueRef create() => JiraIssueRef._();
  static $pb.GeneratedMessage $_createMessage() => JiraIssueRef._();
  @$core.override
  JiraIssueRef createEmptyInstance() => JiraIssueRef._();
  @$core.pragma('dart2js:noInline')
  static JiraIssueRef getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JiraIssueRef>(
          JiraIssueRef.$_createMessage);
  static JiraIssueRef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get summary => $_getSZ(1);
  @$pb.TagNumber(2)
  set summary($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSummary() => $_has(1);
  @$pb.TagNumber(2)
  void clearSummary() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  /// "new", "indeterminate" or "done".
  @$pb.TagNumber(5)
  $core.String get statusCategory => $_getSZ(4);
  @$pb.TagNumber(5)
  set statusCategory($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatusCategory() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatusCategory() => $_clearField(5);
}

/// An issue; a list fills only key to updated. Text is Markdown.
class JiraIssue extends $pb.GeneratedMessage {
  factory JiraIssue({
    $core.String? key,
    $core.String? summary,
    $core.String? type,
    $core.String? status,
    $core.String? statusCategory,
    $core.String? priority,
    $core.String? assignee,
    $fixnum.Int64? updated,
    $core.String? reporter,
    $fixnum.Int64? created,
    $core.Iterable<$core.String>? labels,
    $core.String? description,
    $core.String? acceptanceCriteria,
    JiraIssueRef? parent,
    $core.Iterable<JiraIssueRef>? subtasks,
    $core.Iterable<JiraLink>? links,
    $core.Iterable<JiraAttachment>? attachments,
    $core.Iterable<JiraComment>? comments,
    $core.Iterable<JiraRemoteLink>? remoteLinks,
    $core.String? url,
  }) {
    final result = JiraIssue._();
    if (key != null) result.key = key;
    if (summary != null) result.summary = summary;
    if (type != null) result.type = type;
    if (status != null) result.status = status;
    if (statusCategory != null) result.statusCategory = statusCategory;
    if (priority != null) result.priority = priority;
    if (assignee != null) result.assignee = assignee;
    if (updated != null) result.updated = updated;
    if (reporter != null) result.reporter = reporter;
    if (created != null) result.created = created;
    if (labels != null) result.labels.addAll(labels);
    if (description != null) result.description = description;
    if (acceptanceCriteria != null)
      result.acceptanceCriteria = acceptanceCriteria;
    if (parent != null) result.parent = parent;
    if (subtasks != null) result.subtasks.addAll(subtasks);
    if (links != null) result.links.addAll(links);
    if (attachments != null) result.attachments.addAll(attachments);
    if (comments != null) result.comments.addAll(comments);
    if (remoteLinks != null) result.remoteLinks.addAll(remoteLinks);
    if (url != null) result.url = url;
    return result;
  }

  JiraIssue._();

  factory JiraIssue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraIssue()..mergeFromBuffer(data, registry);
  factory JiraIssue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraIssue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraIssue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraIssue.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'key')
    ..aOS(2, _omitFieldNames ? '' : 'summary')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..aOS(5, _omitFieldNames ? '' : 'statusCategory')
    ..aOS(6, _omitFieldNames ? '' : 'priority')
    ..aOS(7, _omitFieldNames ? '' : 'assignee')
    ..aInt64(8, _omitFieldNames ? '' : 'updated')
    ..aOS(9, _omitFieldNames ? '' : 'reporter')
    ..aInt64(10, _omitFieldNames ? '' : 'created')
    ..pPS(11, _omitFieldNames ? '' : 'labels')
    ..aOS(12, _omitFieldNames ? '' : 'description')
    ..aOS(13, _omitFieldNames ? '' : 'acceptanceCriteria')
    ..aOM<JiraIssueRef>(14, _omitFieldNames ? '' : 'parent',
        subBuilder: JiraIssueRef.$_createMessage)
    ..pPM<JiraIssueRef>(15, _omitFieldNames ? '' : 'subtasks',
        subBuilder: JiraIssueRef.$_createMessage)
    ..pPM<JiraLink>(16, _omitFieldNames ? '' : 'links',
        subBuilder: JiraLink.$_createMessage)
    ..pPM<JiraAttachment>(17, _omitFieldNames ? '' : 'attachments',
        subBuilder: JiraAttachment.$_createMessage)
    ..pPM<JiraComment>(18, _omitFieldNames ? '' : 'comments',
        subBuilder: JiraComment.$_createMessage)
    ..pPM<JiraRemoteLink>(19, _omitFieldNames ? '' : 'remoteLinks',
        subBuilder: JiraRemoteLink.$_createMessage)
    ..aOS(20, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraIssue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraIssue copyWith(void Function(JiraIssue) updates) =>
      super.copyWith((message) => updates(message as JiraIssue)) as JiraIssue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraIssue() / JiraIssue.new instead')
  static JiraIssue create() => JiraIssue._();
  static $pb.GeneratedMessage $_createMessage() => JiraIssue._();
  @$core.override
  JiraIssue createEmptyInstance() => JiraIssue._();
  @$core.pragma('dart2js:noInline')
  static JiraIssue getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraIssue>(JiraIssue.$_createMessage);
  static JiraIssue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get key => $_getSZ(0);
  @$pb.TagNumber(1)
  set key($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearKey() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get summary => $_getSZ(1);
  @$pb.TagNumber(2)
  set summary($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSummary() => $_has(1);
  @$pb.TagNumber(2)
  void clearSummary() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get statusCategory => $_getSZ(4);
  @$pb.TagNumber(5)
  set statusCategory($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStatusCategory() => $_has(4);
  @$pb.TagNumber(5)
  void clearStatusCategory() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get priority => $_getSZ(5);
  @$pb.TagNumber(6)
  set priority($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPriority() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriority() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get assignee => $_getSZ(6);
  @$pb.TagNumber(7)
  set assignee($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAssignee() => $_has(6);
  @$pb.TagNumber(7)
  void clearAssignee() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get updated => $_getI64(7);
  @$pb.TagNumber(8)
  set updated($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasUpdated() => $_has(7);
  @$pb.TagNumber(8)
  void clearUpdated() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get reporter => $_getSZ(8);
  @$pb.TagNumber(9)
  set reporter($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasReporter() => $_has(8);
  @$pb.TagNumber(9)
  void clearReporter() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get created => $_getI64(9);
  @$pb.TagNumber(10)
  set created($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasCreated() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreated() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get labels => $_getList(10);

  @$pb.TagNumber(12)
  $core.String get description => $_getSZ(11);
  @$pb.TagNumber(12)
  set description($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDescription() => $_has(11);
  @$pb.TagNumber(12)
  void clearDescription() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get acceptanceCriteria => $_getSZ(12);
  @$pb.TagNumber(13)
  set acceptanceCriteria($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAcceptanceCriteria() => $_has(12);
  @$pb.TagNumber(13)
  void clearAcceptanceCriteria() => $_clearField(13);

  @$pb.TagNumber(14)
  JiraIssueRef get parent => $_getN(13);
  @$pb.TagNumber(14)
  set parent(JiraIssueRef value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasParent() => $_has(13);
  @$pb.TagNumber(14)
  void clearParent() => $_clearField(14);
  @$pb.TagNumber(14)
  JiraIssueRef ensureParent() => $_ensure(13);

  @$pb.TagNumber(15)
  $pb.PbList<JiraIssueRef> get subtasks => $_getList(14);

  @$pb.TagNumber(16)
  $pb.PbList<JiraLink> get links => $_getList(15);

  @$pb.TagNumber(17)
  $pb.PbList<JiraAttachment> get attachments => $_getList(16);

  @$pb.TagNumber(18)
  $pb.PbList<JiraComment> get comments => $_getList(17);

  @$pb.TagNumber(19)
  $pb.PbList<JiraRemoteLink> get remoteLinks => $_getList(18);

  /// The issue in the browser.
  @$pb.TagNumber(20)
  $core.String get url => $_getSZ(19);
  @$pb.TagNumber(20)
  set url($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasUrl() => $_has(19);
  @$pb.TagNumber(20)
  void clearUrl() => $_clearField(20);
}

class JiraLink extends $pb.GeneratedMessage {
  factory JiraLink({
    $core.String? relation,
    JiraIssueRef? issue,
  }) {
    final result = JiraLink._();
    if (relation != null) result.relation = relation;
    if (issue != null) result.issue = issue;
    return result;
  }

  JiraLink._();

  factory JiraLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraLink()..mergeFromBuffer(data, registry);
  factory JiraLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraLink()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraLink.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'relation')
    ..aOM<JiraIssueRef>(2, _omitFieldNames ? '' : 'issue',
        subBuilder: JiraIssueRef.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraLink copyWith(void Function(JiraLink) updates) =>
      super.copyWith((message) => updates(message as JiraLink)) as JiraLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraLink() / JiraLink.new instead')
  static JiraLink create() => JiraLink._();
  static $pb.GeneratedMessage $_createMessage() => JiraLink._();
  @$core.override
  JiraLink createEmptyInstance() => JiraLink._();
  @$core.pragma('dart2js:noInline')
  static JiraLink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraLink>(JiraLink.$_createMessage);
  static JiraLink? _defaultInstance;

  /// As this issue reads it: "blocks", "is blocked by".
  @$pb.TagNumber(1)
  $core.String get relation => $_getSZ(0);
  @$pb.TagNumber(1)
  set relation($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRelation() => $_has(0);
  @$pb.TagNumber(1)
  void clearRelation() => $_clearField(1);

  @$pb.TagNumber(2)
  JiraIssueRef get issue => $_getN(1);
  @$pb.TagNumber(2)
  set issue(JiraIssueRef value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasIssue() => $_has(1);
  @$pb.TagNumber(2)
  void clearIssue() => $_clearField(2);
  @$pb.TagNumber(2)
  JiraIssueRef ensureIssue() => $_ensure(1);
}

class JiraAttachment extends $pb.GeneratedMessage {
  factory JiraAttachment({
    $core.String? id,
    $core.String? name,
    $core.String? mimeType,
    $fixnum.Int64? size,
  }) {
    final result = JiraAttachment._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (mimeType != null) result.mimeType = mimeType;
    if (size != null) result.size = size;
    return result;
  }

  JiraAttachment._();

  factory JiraAttachment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraAttachment()..mergeFromBuffer(data, registry);
  factory JiraAttachment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraAttachment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraAttachment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraAttachment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'mimeType')
    ..aInt64(4, _omitFieldNames ? '' : 'size')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraAttachment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraAttachment copyWith(void Function(JiraAttachment) updates) =>
      super.copyWith((message) => updates(message as JiraAttachment))
          as JiraAttachment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraAttachment() / JiraAttachment.new instead')
  static JiraAttachment create() => JiraAttachment._();
  static $pb.GeneratedMessage $_createMessage() => JiraAttachment._();
  @$core.override
  JiraAttachment createEmptyInstance() => JiraAttachment._();
  @$core.pragma('dart2js:noInline')
  static JiraAttachment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JiraAttachment>(
          JiraAttachment.$_createMessage);
  static JiraAttachment? _defaultInstance;

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
  $core.String get mimeType => $_getSZ(2);
  @$pb.TagNumber(3)
  set mimeType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMimeType() => $_has(2);
  @$pb.TagNumber(3)
  void clearMimeType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get size => $_getI64(3);
  @$pb.TagNumber(4)
  set size($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);
}

class JiraComment extends $pb.GeneratedMessage {
  factory JiraComment({
    $core.String? id,
    $core.String? author,
    $core.String? body,
    $fixnum.Int64? created,
    $fixnum.Int64? updated,
  }) {
    final result = JiraComment._();
    if (id != null) result.id = id;
    if (author != null) result.author = author;
    if (body != null) result.body = body;
    if (created != null) result.created = created;
    if (updated != null) result.updated = updated;
    return result;
  }

  JiraComment._();

  factory JiraComment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraComment()..mergeFromBuffer(data, registry);
  factory JiraComment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraComment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraComment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraComment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'author')
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..aInt64(4, _omitFieldNames ? '' : 'created')
    ..aInt64(5, _omitFieldNames ? '' : 'updated')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraComment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraComment copyWith(void Function(JiraComment) updates) =>
      super.copyWith((message) => updates(message as JiraComment))
          as JiraComment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraComment() / JiraComment.new instead')
  static JiraComment create() => JiraComment._();
  static $pb.GeneratedMessage $_createMessage() => JiraComment._();
  @$core.override
  JiraComment createEmptyInstance() => JiraComment._();
  @$core.pragma('dart2js:noInline')
  static JiraComment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JiraComment>(
          JiraComment.$_createMessage);
  static JiraComment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get author => $_getSZ(1);
  @$pb.TagNumber(2)
  set author($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthor() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthor() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get created => $_getI64(3);
  @$pb.TagNumber(4)
  set created($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCreated() => $_has(3);
  @$pb.TagNumber(4)
  void clearCreated() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get updated => $_getI64(4);
  @$pb.TagNumber(5)
  set updated($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUpdated() => $_has(4);
  @$pb.TagNumber(5)
  void clearUpdated() => $_clearField(5);
}

class JiraRemoteLink extends $pb.GeneratedMessage {
  factory JiraRemoteLink({
    $core.String? title,
    $core.String? url,
  }) {
    final result = JiraRemoteLink._();
    if (title != null) result.title = title;
    if (url != null) result.url = url;
    return result;
  }

  JiraRemoteLink._();

  factory JiraRemoteLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraRemoteLink()..mergeFromBuffer(data, registry);
  factory JiraRemoteLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraRemoteLink()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraRemoteLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraRemoteLink.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'title')
    ..aOS(2, _omitFieldNames ? '' : 'url')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraRemoteLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraRemoteLink copyWith(void Function(JiraRemoteLink) updates) =>
      super.copyWith((message) => updates(message as JiraRemoteLink))
          as JiraRemoteLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraRemoteLink() / JiraRemoteLink.new instead')
  static JiraRemoteLink create() => JiraRemoteLink._();
  static $pb.GeneratedMessage $_createMessage() => JiraRemoteLink._();
  @$core.override
  JiraRemoteLink createEmptyInstance() => JiraRemoteLink._();
  @$core.pragma('dart2js:noInline')
  static JiraRemoteLink getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JiraRemoteLink>(
          JiraRemoteLink.$_createMessage);
  static JiraRemoteLink? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get title => $_getSZ(0);
  @$pb.TagNumber(1)
  set title($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTitle() => $_has(0);
  @$pb.TagNumber(1)
  void clearTitle() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get url => $_getSZ(1);
  @$pb.TagNumber(2)
  set url($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearUrl() => $_clearField(2);
}

class JiraTransition extends $pb.GeneratedMessage {
  factory JiraTransition({
    $core.String? id,
    $core.String? name,
    $core.String? to,
    $core.String? toCategory,
    $core.Iterable<JiraField>? fields,
  }) {
    final result = JiraTransition._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (to != null) result.to = to;
    if (toCategory != null) result.toCategory = toCategory;
    if (fields != null) result.fields.addAll(fields);
    return result;
  }

  JiraTransition._();

  factory JiraTransition.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraTransition()..mergeFromBuffer(data, registry);
  factory JiraTransition.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraTransition()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraTransition',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraTransition.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'to')
    ..aOS(4, _omitFieldNames ? '' : 'toCategory')
    ..pPM<JiraField>(5, _omitFieldNames ? '' : 'fields',
        subBuilder: JiraField.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraTransition clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraTransition copyWith(void Function(JiraTransition) updates) =>
      super.copyWith((message) => updates(message as JiraTransition))
          as JiraTransition;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraTransition() / JiraTransition.new instead')
  static JiraTransition create() => JiraTransition._();
  static $pb.GeneratedMessage $_createMessage() => JiraTransition._();
  @$core.override
  JiraTransition createEmptyInstance() => JiraTransition._();
  @$core.pragma('dart2js:noInline')
  static JiraTransition getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JiraTransition>(
          JiraTransition.$_createMessage);
  static JiraTransition? _defaultInstance;

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
  $core.String get to => $_getSZ(2);
  @$pb.TagNumber(3)
  set to($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get toCategory => $_getSZ(3);
  @$pb.TagNumber(4)
  set toCategory($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToCategory() => $_has(3);
  @$pb.TagNumber(4)
  void clearToCategory() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<JiraField> get fields => $_getList(4);
}

/// A field a transition's screen asks for. type: "string", "text"
/// (Markdown), "number", "user" (an account id), "option" and the like (an
/// option's id), "array:<items>".
class JiraField extends $pb.GeneratedMessage {
  factory JiraField({
    $core.String? id,
    $core.String? name,
    $core.String? type,
    $core.bool? required,
    $core.Iterable<JiraOption>? options,
  }) {
    final result = JiraField._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (type != null) result.type = type;
    if (required != null) result.required = required;
    if (options != null) result.options.addAll(options);
    return result;
  }

  JiraField._();

  factory JiraField.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraField()..mergeFromBuffer(data, registry);
  factory JiraField.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraField()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraField',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraField.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'type')
    ..aOB(4, _omitFieldNames ? '' : 'required')
    ..pPM<JiraOption>(5, _omitFieldNames ? '' : 'options',
        subBuilder: JiraOption.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraField clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraField copyWith(void Function(JiraField) updates) =>
      super.copyWith((message) => updates(message as JiraField)) as JiraField;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraField() / JiraField.new instead')
  static JiraField create() => JiraField._();
  static $pb.GeneratedMessage $_createMessage() => JiraField._();
  @$core.override
  JiraField createEmptyInstance() => JiraField._();
  @$core.pragma('dart2js:noInline')
  static JiraField getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraField>(JiraField.$_createMessage);
  static JiraField? _defaultInstance;

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
  $core.String get type => $_getSZ(2);
  @$pb.TagNumber(3)
  set type($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasType() => $_has(2);
  @$pb.TagNumber(3)
  void clearType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get required => $_getBF(3);
  @$pb.TagNumber(4)
  set required($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasRequired() => $_has(3);
  @$pb.TagNumber(4)
  void clearRequired() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<JiraOption> get options => $_getList(4);
}

class JiraOption extends $pb.GeneratedMessage {
  factory JiraOption({
    $core.String? id,
    $core.String? name,
  }) {
    final result = JiraOption._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    return result;
  }

  JiraOption._();

  factory JiraOption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraOption()..mergeFromBuffer(data, registry);
  factory JiraOption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraOption()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraOption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraOption.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraOption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraOption copyWith(void Function(JiraOption) updates) =>
      super.copyWith((message) => updates(message as JiraOption)) as JiraOption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraOption() / JiraOption.new instead')
  static JiraOption create() => JiraOption._();
  static $pb.GeneratedMessage $_createMessage() => JiraOption._();
  @$core.override
  JiraOption createEmptyInstance() => JiraOption._();
  @$core.pragma('dart2js:noInline')
  static JiraOption getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraOption>(JiraOption.$_createMessage);
  static JiraOption? _defaultInstance;

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
}

class JiraBoard extends $pb.GeneratedMessage {
  factory JiraBoard({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? project,
  }) {
    final result = JiraBoard._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (project != null) result.project = project;
    return result;
  }

  JiraBoard._();

  factory JiraBoard.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraBoard()..mergeFromBuffer(data, registry);
  factory JiraBoard.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraBoard()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraBoard',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraBoard.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'project')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraBoard clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraBoard copyWith(void Function(JiraBoard) updates) =>
      super.copyWith((message) => updates(message as JiraBoard)) as JiraBoard;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraBoard() / JiraBoard.new instead')
  static JiraBoard create() => JiraBoard._();
  static $pb.GeneratedMessage $_createMessage() => JiraBoard._();
  @$core.override
  JiraBoard createEmptyInstance() => JiraBoard._();
  @$core.pragma('dart2js:noInline')
  static JiraBoard getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraBoard>(JiraBoard.$_createMessage);
  static JiraBoard? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
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
  $core.String get project => $_getSZ(2);
  @$pb.TagNumber(3)
  set project($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProject() => $_has(2);
  @$pb.TagNumber(3)
  void clearProject() => $_clearField(3);
}

class ListJiraSitesRequest extends $pb.GeneratedMessage {
  factory ListJiraSitesRequest() => ListJiraSitesRequest._();

  ListJiraSitesRequest._();

  factory ListJiraSitesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraSitesRequest()..mergeFromBuffer(data, registry);
  factory ListJiraSitesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraSitesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraSitesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraSitesRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraSitesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraSitesRequest copyWith(void Function(ListJiraSitesRequest) updates) =>
      super.copyWith((message) => updates(message as ListJiraSitesRequest))
          as ListJiraSitesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraSitesRequest() / ListJiraSitesRequest.new instead')
  static ListJiraSitesRequest create() => ListJiraSitesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListJiraSitesRequest._();
  @$core.override
  ListJiraSitesRequest createEmptyInstance() => ListJiraSitesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListJiraSitesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraSitesRequest>(
          ListJiraSitesRequest.$_createMessage);
  static ListJiraSitesRequest? _defaultInstance;
}

class ListJiraSitesResponse extends $pb.GeneratedMessage {
  factory ListJiraSitesResponse({
    $core.Iterable<JiraSite>? sites,
  }) {
    final result = ListJiraSitesResponse._();
    if (sites != null) result.sites.addAll(sites);
    return result;
  }

  ListJiraSitesResponse._();

  factory ListJiraSitesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraSitesResponse()..mergeFromBuffer(data, registry);
  factory ListJiraSitesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraSitesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraSitesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraSitesResponse.$_createMessage)
    ..pPM<JiraSite>(1, _omitFieldNames ? '' : 'sites',
        subBuilder: JiraSite.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraSitesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraSitesResponse copyWith(
          void Function(ListJiraSitesResponse) updates) =>
      super.copyWith((message) => updates(message as ListJiraSitesResponse))
          as ListJiraSitesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraSitesResponse() / ListJiraSitesResponse.new instead')
  static ListJiraSitesResponse create() => ListJiraSitesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListJiraSitesResponse._();
  @$core.override
  ListJiraSitesResponse createEmptyInstance() => ListJiraSitesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListJiraSitesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraSitesResponse>(
          ListJiraSitesResponse.$_createMessage);
  static ListJiraSitesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JiraSite> get sites => $_getList(0);
}

class AddJiraSiteRequest extends $pb.GeneratedMessage {
  factory AddJiraSiteRequest({
    $core.String? url,
    $core.String? email,
    $core.String? token,
    $fixnum.Int64? expires,
  }) {
    final result = AddJiraSiteRequest._();
    if (url != null) result.url = url;
    if (email != null) result.email = email;
    if (token != null) result.token = token;
    if (expires != null) result.expires = expires;
    return result;
  }

  AddJiraSiteRequest._();

  factory AddJiraSiteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraSiteRequest()..mergeFromBuffer(data, registry);
  factory AddJiraSiteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraSiteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddJiraSiteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddJiraSiteRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'url')
    ..aOS(2, _omitFieldNames ? '' : 'email')
    ..aOS(3, _omitFieldNames ? '' : 'token')
    ..aInt64(4, _omitFieldNames ? '' : 'expires')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraSiteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraSiteRequest copyWith(void Function(AddJiraSiteRequest) updates) =>
      super.copyWith((message) => updates(message as AddJiraSiteRequest))
          as AddJiraSiteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use AddJiraSiteRequest() / AddJiraSiteRequest.new instead')
  static AddJiraSiteRequest create() => AddJiraSiteRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddJiraSiteRequest._();
  @$core.override
  AddJiraSiteRequest createEmptyInstance() => AddJiraSiteRequest._();
  @$core.pragma('dart2js:noInline')
  static AddJiraSiteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddJiraSiteRequest>(
          AddJiraSiteRequest.$_createMessage);
  static AddJiraSiteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get url => $_getSZ(0);
  @$pb.TagNumber(1)
  set url($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUrl() => $_has(0);
  @$pb.TagNumber(1)
  void clearUrl() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get email => $_getSZ(1);
  @$pb.TagNumber(2)
  set email($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEmail() => $_has(1);
  @$pb.TagNumber(2)
  void clearEmail() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get token => $_getSZ(2);
  @$pb.TagNumber(3)
  set token($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearToken() => $_clearField(3);

  /// When the token expires, if known (ms).
  @$pb.TagNumber(4)
  $fixnum.Int64 get expires => $_getI64(3);
  @$pb.TagNumber(4)
  set expires($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExpires() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpires() => $_clearField(4);
}

class AddJiraSiteResponse extends $pb.GeneratedMessage {
  factory AddJiraSiteResponse({
    JiraSite? site,
  }) {
    final result = AddJiraSiteResponse._();
    if (site != null) result.site = site;
    return result;
  }

  AddJiraSiteResponse._();

  factory AddJiraSiteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraSiteResponse()..mergeFromBuffer(data, registry);
  factory AddJiraSiteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraSiteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddJiraSiteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddJiraSiteResponse.$_createMessage)
    ..aOM<JiraSite>(1, _omitFieldNames ? '' : 'site',
        subBuilder: JiraSite.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraSiteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraSiteResponse copyWith(void Function(AddJiraSiteResponse) updates) =>
      super.copyWith((message) => updates(message as AddJiraSiteResponse))
          as AddJiraSiteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use AddJiraSiteResponse() / AddJiraSiteResponse.new instead')
  static AddJiraSiteResponse create() => AddJiraSiteResponse._();
  static $pb.GeneratedMessage $_createMessage() => AddJiraSiteResponse._();
  @$core.override
  AddJiraSiteResponse createEmptyInstance() => AddJiraSiteResponse._();
  @$core.pragma('dart2js:noInline')
  static AddJiraSiteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddJiraSiteResponse>(
          AddJiraSiteResponse.$_createMessage);
  static AddJiraSiteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  JiraSite get site => $_getN(0);
  @$pb.TagNumber(1)
  set site(JiraSite value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);
  @$pb.TagNumber(1)
  JiraSite ensureSite() => $_ensure(0);
}

class RemoveJiraSiteRequest extends $pb.GeneratedMessage {
  factory RemoveJiraSiteRequest({
    $core.String? site,
  }) {
    final result = RemoveJiraSiteRequest._();
    if (site != null) result.site = site;
    return result;
  }

  RemoveJiraSiteRequest._();

  factory RemoveJiraSiteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveJiraSiteRequest()..mergeFromBuffer(data, registry);
  factory RemoveJiraSiteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveJiraSiteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveJiraSiteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveJiraSiteRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveJiraSiteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveJiraSiteRequest copyWith(
          void Function(RemoveJiraSiteRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveJiraSiteRequest))
          as RemoveJiraSiteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveJiraSiteRequest() / RemoveJiraSiteRequest.new instead')
  static RemoveJiraSiteRequest create() => RemoveJiraSiteRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveJiraSiteRequest._();
  @$core.override
  RemoveJiraSiteRequest createEmptyInstance() => RemoveJiraSiteRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveJiraSiteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveJiraSiteRequest>(
          RemoveJiraSiteRequest.$_createMessage);
  static RemoveJiraSiteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);
}

class RemoveJiraSiteResponse extends $pb.GeneratedMessage {
  factory RemoveJiraSiteResponse() => RemoveJiraSiteResponse._();

  RemoveJiraSiteResponse._();

  factory RemoveJiraSiteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveJiraSiteResponse()..mergeFromBuffer(data, registry);
  factory RemoveJiraSiteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveJiraSiteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveJiraSiteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveJiraSiteResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveJiraSiteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveJiraSiteResponse copyWith(
          void Function(RemoveJiraSiteResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveJiraSiteResponse))
          as RemoveJiraSiteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveJiraSiteResponse() / RemoveJiraSiteResponse.new instead')
  static RemoveJiraSiteResponse create() => RemoveJiraSiteResponse._();
  static $pb.GeneratedMessage $_createMessage() => RemoveJiraSiteResponse._();
  @$core.override
  RemoveJiraSiteResponse createEmptyInstance() => RemoveJiraSiteResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveJiraSiteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveJiraSiteResponse>(
          RemoveJiraSiteResponse.$_createMessage);
  static RemoveJiraSiteResponse? _defaultInstance;
}

class CheckJiraSiteRequest extends $pb.GeneratedMessage {
  factory CheckJiraSiteRequest({
    $core.String? site,
  }) {
    final result = CheckJiraSiteRequest._();
    if (site != null) result.site = site;
    return result;
  }

  CheckJiraSiteRequest._();

  factory CheckJiraSiteRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckJiraSiteRequest()..mergeFromBuffer(data, registry);
  factory CheckJiraSiteRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckJiraSiteRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckJiraSiteRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CheckJiraSiteRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckJiraSiteRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckJiraSiteRequest copyWith(void Function(CheckJiraSiteRequest) updates) =>
      super.copyWith((message) => updates(message as CheckJiraSiteRequest))
          as CheckJiraSiteRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CheckJiraSiteRequest() / CheckJiraSiteRequest.new instead')
  static CheckJiraSiteRequest create() => CheckJiraSiteRequest._();
  static $pb.GeneratedMessage $_createMessage() => CheckJiraSiteRequest._();
  @$core.override
  CheckJiraSiteRequest createEmptyInstance() => CheckJiraSiteRequest._();
  @$core.pragma('dart2js:noInline')
  static CheckJiraSiteRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckJiraSiteRequest>(
          CheckJiraSiteRequest.$_createMessage);
  static CheckJiraSiteRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);
}

class CheckJiraSiteResponse extends $pb.GeneratedMessage {
  factory CheckJiraSiteResponse({
    $core.String? name,
  }) {
    final result = CheckJiraSiteResponse._();
    if (name != null) result.name = name;
    return result;
  }

  CheckJiraSiteResponse._();

  factory CheckJiraSiteResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckJiraSiteResponse()..mergeFromBuffer(data, registry);
  factory CheckJiraSiteResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      CheckJiraSiteResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckJiraSiteResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: CheckJiraSiteResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckJiraSiteResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckJiraSiteResponse copyWith(
          void Function(CheckJiraSiteResponse) updates) =>
      super.copyWith((message) => updates(message as CheckJiraSiteResponse))
          as CheckJiraSiteResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use CheckJiraSiteResponse() / CheckJiraSiteResponse.new instead')
  static CheckJiraSiteResponse create() => CheckJiraSiteResponse._();
  static $pb.GeneratedMessage $_createMessage() => CheckJiraSiteResponse._();
  @$core.override
  CheckJiraSiteResponse createEmptyInstance() => CheckJiraSiteResponse._();
  @$core.pragma('dart2js:noInline')
  static CheckJiraSiteResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckJiraSiteResponse>(
          CheckJiraSiteResponse.$_createMessage);
  static CheckJiraSiteResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
}

class AllowJiraTokenRequest extends $pb.GeneratedMessage {
  factory AllowJiraTokenRequest({
    $core.String? site,
  }) {
    final result = AllowJiraTokenRequest._();
    if (site != null) result.site = site;
    return result;
  }

  AllowJiraTokenRequest._();

  factory AllowJiraTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowJiraTokenRequest()..mergeFromBuffer(data, registry);
  factory AllowJiraTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowJiraTokenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AllowJiraTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AllowJiraTokenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowJiraTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowJiraTokenRequest copyWith(
          void Function(AllowJiraTokenRequest) updates) =>
      super.copyWith((message) => updates(message as AllowJiraTokenRequest))
          as AllowJiraTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AllowJiraTokenRequest() / AllowJiraTokenRequest.new instead')
  static AllowJiraTokenRequest create() => AllowJiraTokenRequest._();
  static $pb.GeneratedMessage $_createMessage() => AllowJiraTokenRequest._();
  @$core.override
  AllowJiraTokenRequest createEmptyInstance() => AllowJiraTokenRequest._();
  @$core.pragma('dart2js:noInline')
  static AllowJiraTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AllowJiraTokenRequest>(
          AllowJiraTokenRequest.$_createMessage);
  static AllowJiraTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);
}

class AllowJiraTokenResponse extends $pb.GeneratedMessage {
  factory AllowJiraTokenResponse() => AllowJiraTokenResponse._();

  AllowJiraTokenResponse._();

  factory AllowJiraTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowJiraTokenResponse()..mergeFromBuffer(data, registry);
  factory AllowJiraTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowJiraTokenResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AllowJiraTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AllowJiraTokenResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowJiraTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowJiraTokenResponse copyWith(
          void Function(AllowJiraTokenResponse) updates) =>
      super.copyWith((message) => updates(message as AllowJiraTokenResponse))
          as AllowJiraTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AllowJiraTokenResponse() / AllowJiraTokenResponse.new instead')
  static AllowJiraTokenResponse create() => AllowJiraTokenResponse._();
  static $pb.GeneratedMessage $_createMessage() => AllowJiraTokenResponse._();
  @$core.override
  AllowJiraTokenResponse createEmptyInstance() => AllowJiraTokenResponse._();
  @$core.pragma('dart2js:noInline')
  static AllowJiraTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AllowJiraTokenResponse>(
          AllowJiraTokenResponse.$_createMessage);
  static AllowJiraTokenResponse? _defaultInstance;
}

class ListJiraBoardsRequest extends $pb.GeneratedMessage {
  factory ListJiraBoardsRequest({
    $core.String? site,
  }) {
    final result = ListJiraBoardsRequest._();
    if (site != null) result.site = site;
    return result;
  }

  ListJiraBoardsRequest._();

  factory ListJiraBoardsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraBoardsRequest()..mergeFromBuffer(data, registry);
  factory ListJiraBoardsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraBoardsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraBoardsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraBoardsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraBoardsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraBoardsRequest copyWith(
          void Function(ListJiraBoardsRequest) updates) =>
      super.copyWith((message) => updates(message as ListJiraBoardsRequest))
          as ListJiraBoardsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraBoardsRequest() / ListJiraBoardsRequest.new instead')
  static ListJiraBoardsRequest create() => ListJiraBoardsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListJiraBoardsRequest._();
  @$core.override
  ListJiraBoardsRequest createEmptyInstance() => ListJiraBoardsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListJiraBoardsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraBoardsRequest>(
          ListJiraBoardsRequest.$_createMessage);
  static ListJiraBoardsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);
}

class ListJiraBoardsResponse extends $pb.GeneratedMessage {
  factory ListJiraBoardsResponse({
    $core.Iterable<JiraBoard>? boards,
  }) {
    final result = ListJiraBoardsResponse._();
    if (boards != null) result.boards.addAll(boards);
    return result;
  }

  ListJiraBoardsResponse._();

  factory ListJiraBoardsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraBoardsResponse()..mergeFromBuffer(data, registry);
  factory ListJiraBoardsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraBoardsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraBoardsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraBoardsResponse.$_createMessage)
    ..pPM<JiraBoard>(1, _omitFieldNames ? '' : 'boards',
        subBuilder: JiraBoard.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraBoardsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraBoardsResponse copyWith(
          void Function(ListJiraBoardsResponse) updates) =>
      super.copyWith((message) => updates(message as ListJiraBoardsResponse))
          as ListJiraBoardsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraBoardsResponse() / ListJiraBoardsResponse.new instead')
  static ListJiraBoardsResponse create() => ListJiraBoardsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListJiraBoardsResponse._();
  @$core.override
  ListJiraBoardsResponse createEmptyInstance() => ListJiraBoardsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListJiraBoardsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraBoardsResponse>(
          ListJiraBoardsResponse.$_createMessage);
  static ListJiraBoardsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JiraBoard> get boards => $_getList(0);
}

class SetJiraBoardRequest extends $pb.GeneratedMessage {
  factory SetJiraBoardRequest({
    $core.String? site,
    JiraBoard? board,
  }) {
    final result = SetJiraBoardRequest._();
    if (site != null) result.site = site;
    if (board != null) result.board = board;
    return result;
  }

  SetJiraBoardRequest._();

  factory SetJiraBoardRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraBoardRequest()..mergeFromBuffer(data, registry);
  factory SetJiraBoardRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraBoardRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetJiraBoardRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetJiraBoardRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOM<JiraBoard>(2, _omitFieldNames ? '' : 'board',
        subBuilder: JiraBoard.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraBoardRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraBoardRequest copyWith(void Function(SetJiraBoardRequest) updates) =>
      super.copyWith((message) => updates(message as SetJiraBoardRequest))
          as SetJiraBoardRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use SetJiraBoardRequest() / SetJiraBoardRequest.new instead')
  static SetJiraBoardRequest create() => SetJiraBoardRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetJiraBoardRequest._();
  @$core.override
  SetJiraBoardRequest createEmptyInstance() => SetJiraBoardRequest._();
  @$core.pragma('dart2js:noInline')
  static SetJiraBoardRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetJiraBoardRequest>(
          SetJiraBoardRequest.$_createMessage);
  static SetJiraBoardRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  JiraBoard get board => $_getN(1);
  @$pb.TagNumber(2)
  set board(JiraBoard value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasBoard() => $_has(1);
  @$pb.TagNumber(2)
  void clearBoard() => $_clearField(2);
  @$pb.TagNumber(2)
  JiraBoard ensureBoard() => $_ensure(1);
}

class SetJiraBoardResponse extends $pb.GeneratedMessage {
  factory SetJiraBoardResponse() => SetJiraBoardResponse._();

  SetJiraBoardResponse._();

  factory SetJiraBoardResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraBoardResponse()..mergeFromBuffer(data, registry);
  factory SetJiraBoardResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraBoardResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetJiraBoardResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetJiraBoardResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraBoardResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraBoardResponse copyWith(void Function(SetJiraBoardResponse) updates) =>
      super.copyWith((message) => updates(message as SetJiraBoardResponse))
          as SetJiraBoardResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetJiraBoardResponse() / SetJiraBoardResponse.new instead')
  static SetJiraBoardResponse create() => SetJiraBoardResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetJiraBoardResponse._();
  @$core.override
  SetJiraBoardResponse createEmptyInstance() => SetJiraBoardResponse._();
  @$core.pragma('dart2js:noInline')
  static SetJiraBoardResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetJiraBoardResponse>(
          SetJiraBoardResponse.$_createMessage);
  static SetJiraBoardResponse? _defaultInstance;
}

class SetJiraSearchesRequest extends $pb.GeneratedMessage {
  factory SetJiraSearchesRequest({
    $core.String? site,
    $core.Iterable<JiraSearch>? searches,
  }) {
    final result = SetJiraSearchesRequest._();
    if (site != null) result.site = site;
    if (searches != null) result.searches.addAll(searches);
    return result;
  }

  SetJiraSearchesRequest._();

  factory SetJiraSearchesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraSearchesRequest()..mergeFromBuffer(data, registry);
  factory SetJiraSearchesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraSearchesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetJiraSearchesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetJiraSearchesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..pPM<JiraSearch>(2, _omitFieldNames ? '' : 'searches',
        subBuilder: JiraSearch.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraSearchesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraSearchesRequest copyWith(
          void Function(SetJiraSearchesRequest) updates) =>
      super.copyWith((message) => updates(message as SetJiraSearchesRequest))
          as SetJiraSearchesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetJiraSearchesRequest() / SetJiraSearchesRequest.new instead')
  static SetJiraSearchesRequest create() => SetJiraSearchesRequest._();
  static $pb.GeneratedMessage $_createMessage() => SetJiraSearchesRequest._();
  @$core.override
  SetJiraSearchesRequest createEmptyInstance() => SetJiraSearchesRequest._();
  @$core.pragma('dart2js:noInline')
  static SetJiraSearchesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetJiraSearchesRequest>(
          SetJiraSearchesRequest.$_createMessage);
  static SetJiraSearchesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<JiraSearch> get searches => $_getList(1);
}

class SetJiraSearchesResponse extends $pb.GeneratedMessage {
  factory SetJiraSearchesResponse() => SetJiraSearchesResponse._();

  SetJiraSearchesResponse._();

  factory SetJiraSearchesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraSearchesResponse()..mergeFromBuffer(data, registry);
  factory SetJiraSearchesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SetJiraSearchesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SetJiraSearchesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SetJiraSearchesResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraSearchesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SetJiraSearchesResponse copyWith(
          void Function(SetJiraSearchesResponse) updates) =>
      super.copyWith((message) => updates(message as SetJiraSearchesResponse))
          as SetJiraSearchesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SetJiraSearchesResponse() / SetJiraSearchesResponse.new instead')
  static SetJiraSearchesResponse create() => SetJiraSearchesResponse._();
  static $pb.GeneratedMessage $_createMessage() => SetJiraSearchesResponse._();
  @$core.override
  SetJiraSearchesResponse createEmptyInstance() => SetJiraSearchesResponse._();
  @$core.pragma('dart2js:noInline')
  static SetJiraSearchesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SetJiraSearchesResponse>(
          SetJiraSearchesResponse.$_createMessage);
  static SetJiraSearchesResponse? _defaultInstance;
}

class ListJiraIssuesRequest extends $pb.GeneratedMessage {
  factory ListJiraIssuesRequest({
    $core.String? site,
    $core.String? list,
    $core.String? jql,
    $core.bool? cached,
  }) {
    final result = ListJiraIssuesRequest._();
    if (site != null) result.site = site;
    if (list != null) result.list = list;
    if (jql != null) result.jql = jql;
    if (cached != null) result.cached = cached;
    return result;
  }

  ListJiraIssuesRequest._();

  factory ListJiraIssuesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraIssuesRequest()..mergeFromBuffer(data, registry);
  factory ListJiraIssuesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraIssuesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraIssuesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraIssuesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'list')
    ..aOS(3, _omitFieldNames ? '' : 'jql')
    ..aOB(4, _omitFieldNames ? '' : 'cached')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraIssuesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraIssuesRequest copyWith(
          void Function(ListJiraIssuesRequest) updates) =>
      super.copyWith((message) => updates(message as ListJiraIssuesRequest))
          as ListJiraIssuesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraIssuesRequest() / ListJiraIssuesRequest.new instead')
  static ListJiraIssuesRequest create() => ListJiraIssuesRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListJiraIssuesRequest._();
  @$core.override
  ListJiraIssuesRequest createEmptyInstance() => ListJiraIssuesRequest._();
  @$core.pragma('dart2js:noInline')
  static ListJiraIssuesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraIssuesRequest>(
          ListJiraIssuesRequest.$_createMessage);
  static ListJiraIssuesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  /// "mine", "sprint", or "" for jql.
  @$pb.TagNumber(2)
  $core.String get list => $_getSZ(1);
  @$pb.TagNumber(2)
  set list($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasList() => $_has(1);
  @$pb.TagNumber(2)
  void clearList() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get jql => $_getSZ(2);
  @$pb.TagNumber(3)
  set jql($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasJql() => $_has(2);
  @$pb.TagNumber(3)
  void clearJql() => $_clearField(3);

  /// What the list showed last, kept by the daemon, without asking Jira:
  /// shown at once while the list is asked for (at_ms 0 when none).
  @$pb.TagNumber(4)
  $core.bool get cached => $_getBF(3);
  @$pb.TagNumber(4)
  set cached($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCached() => $_has(3);
  @$pb.TagNumber(4)
  void clearCached() => $_clearField(4);
}

class ListJiraIssuesResponse extends $pb.GeneratedMessage {
  factory ListJiraIssuesResponse({
    $core.Iterable<JiraIssue>? issues,
    $core.String? sprint,
    $fixnum.Int64? atMs,
  }) {
    final result = ListJiraIssuesResponse._();
    if (issues != null) result.issues.addAll(issues);
    if (sprint != null) result.sprint = sprint;
    if (atMs != null) result.atMs = atMs;
    return result;
  }

  ListJiraIssuesResponse._();

  factory ListJiraIssuesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraIssuesResponse()..mergeFromBuffer(data, registry);
  factory ListJiraIssuesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraIssuesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraIssuesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraIssuesResponse.$_createMessage)
    ..pPM<JiraIssue>(1, _omitFieldNames ? '' : 'issues',
        subBuilder: JiraIssue.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'sprint')
    ..aInt64(3, _omitFieldNames ? '' : 'atMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraIssuesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraIssuesResponse copyWith(
          void Function(ListJiraIssuesResponse) updates) =>
      super.copyWith((message) => updates(message as ListJiraIssuesResponse))
          as ListJiraIssuesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraIssuesResponse() / ListJiraIssuesResponse.new instead')
  static ListJiraIssuesResponse create() => ListJiraIssuesResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListJiraIssuesResponse._();
  @$core.override
  ListJiraIssuesResponse createEmptyInstance() => ListJiraIssuesResponse._();
  @$core.pragma('dart2js:noInline')
  static ListJiraIssuesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraIssuesResponse>(
          ListJiraIssuesResponse.$_createMessage);
  static ListJiraIssuesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JiraIssue> get issues => $_getList(0);

  /// The sprint list's sprint ("" when the board has none active).
  @$pb.TagNumber(2)
  $core.String get sprint => $_getSZ(1);
  @$pb.TagNumber(2)
  set sprint($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSprint() => $_has(1);
  @$pb.TagNumber(2)
  void clearSprint() => $_clearField(2);

  /// When Jira said so.
  @$pb.TagNumber(3)
  $fixnum.Int64 get atMs => $_getI64(2);
  @$pb.TagNumber(3)
  set atMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAtMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearAtMs() => $_clearField(3);
}

class GetJiraJqlRequest extends $pb.GeneratedMessage {
  factory GetJiraJqlRequest({
    $core.String? site,
  }) {
    final result = GetJiraJqlRequest._();
    if (site != null) result.site = site;
    return result;
  }

  GetJiraJqlRequest._();

  factory GetJiraJqlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraJqlRequest()..mergeFromBuffer(data, registry);
  factory GetJiraJqlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraJqlRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetJiraJqlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetJiraJqlRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraJqlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraJqlRequest copyWith(void Function(GetJiraJqlRequest) updates) =>
      super.copyWith((message) => updates(message as GetJiraJqlRequest))
          as GetJiraJqlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetJiraJqlRequest() / GetJiraJqlRequest.new instead')
  static GetJiraJqlRequest create() => GetJiraJqlRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetJiraJqlRequest._();
  @$core.override
  GetJiraJqlRequest createEmptyInstance() => GetJiraJqlRequest._();
  @$core.pragma('dart2js:noInline')
  static GetJiraJqlRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GetJiraJqlRequest>(
          GetJiraJqlRequest.$_createMessage);
  static GetJiraJqlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);
}

class GetJiraJqlResponse extends $pb.GeneratedMessage {
  factory GetJiraJqlResponse({
    $core.Iterable<JiraJqlField>? fields,
    $core.Iterable<$core.String>? functions,
    $core.Iterable<$core.String>? words,
  }) {
    final result = GetJiraJqlResponse._();
    if (fields != null) result.fields.addAll(fields);
    if (functions != null) result.functions.addAll(functions);
    if (words != null) result.words.addAll(words);
    return result;
  }

  GetJiraJqlResponse._();

  factory GetJiraJqlResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraJqlResponse()..mergeFromBuffer(data, registry);
  factory GetJiraJqlResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraJqlResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetJiraJqlResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetJiraJqlResponse.$_createMessage)
    ..pPM<JiraJqlField>(1, _omitFieldNames ? '' : 'fields',
        subBuilder: JiraJqlField.$_createMessage)
    ..pPS(2, _omitFieldNames ? '' : 'functions')
    ..pPS(3, _omitFieldNames ? '' : 'words')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraJqlResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraJqlResponse copyWith(void Function(GetJiraJqlResponse) updates) =>
      super.copyWith((message) => updates(message as GetJiraJqlResponse))
          as GetJiraJqlResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GetJiraJqlResponse() / GetJiraJqlResponse.new instead')
  static GetJiraJqlResponse create() => GetJiraJqlResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetJiraJqlResponse._();
  @$core.override
  GetJiraJqlResponse createEmptyInstance() => GetJiraJqlResponse._();
  @$core.pragma('dart2js:noInline')
  static GetJiraJqlResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetJiraJqlResponse>(
          GetJiraJqlResponse.$_createMessage);
  static GetJiraJqlResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JiraJqlField> get fields => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get functions => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get words => $_getList(2);
}

class JiraJqlField extends $pb.GeneratedMessage {
  factory JiraJqlField({
    $core.String? name,
    $core.String? display,
    $core.Iterable<$core.String>? operators,
  }) {
    final result = JiraJqlField._();
    if (name != null) result.name = name;
    if (display != null) result.display = display;
    if (operators != null) result.operators.addAll(operators);
    return result;
  }

  JiraJqlField._();

  factory JiraJqlField.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraJqlField()..mergeFromBuffer(data, registry);
  factory JiraJqlField.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraJqlField()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraJqlField',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraJqlField.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'display')
    ..pPS(3, _omitFieldNames ? '' : 'operators')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraJqlField clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraJqlField copyWith(void Function(JiraJqlField) updates) =>
      super.copyWith((message) => updates(message as JiraJqlField))
          as JiraJqlField;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraJqlField() / JiraJqlField.new instead')
  static JiraJqlField create() => JiraJqlField._();
  static $pb.GeneratedMessage $_createMessage() => JiraJqlField._();
  @$core.override
  JiraJqlField createEmptyInstance() => JiraJqlField._();
  @$core.pragma('dart2js:noInline')
  static JiraJqlField getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<JiraJqlField>(
          JiraJqlField.$_createMessage);
  static JiraJqlField? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get display => $_getSZ(1);
  @$pb.TagNumber(2)
  set display($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplay() => $_has(1);
  @$pb.TagNumber(2)
  void clearDisplay() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get operators => $_getList(2);
}

class SuggestJiraJqlRequest extends $pb.GeneratedMessage {
  factory SuggestJiraJqlRequest({
    $core.String? site,
    $core.String? fieldName,
    $core.String? prefix,
  }) {
    final result = SuggestJiraJqlRequest._();
    if (site != null) result.site = site;
    if (fieldName != null) result.fieldName = fieldName;
    if (prefix != null) result.prefix = prefix;
    return result;
  }

  SuggestJiraJqlRequest._();

  factory SuggestJiraJqlRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SuggestJiraJqlRequest()..mergeFromBuffer(data, registry);
  factory SuggestJiraJqlRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SuggestJiraJqlRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SuggestJiraJqlRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SuggestJiraJqlRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'fieldName')
    ..aOS(3, _omitFieldNames ? '' : 'prefix')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SuggestJiraJqlRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SuggestJiraJqlRequest copyWith(
          void Function(SuggestJiraJqlRequest) updates) =>
      super.copyWith((message) => updates(message as SuggestJiraJqlRequest))
          as SuggestJiraJqlRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SuggestJiraJqlRequest() / SuggestJiraJqlRequest.new instead')
  static SuggestJiraJqlRequest create() => SuggestJiraJqlRequest._();
  static $pb.GeneratedMessage $_createMessage() => SuggestJiraJqlRequest._();
  @$core.override
  SuggestJiraJqlRequest createEmptyInstance() => SuggestJiraJqlRequest._();
  @$core.pragma('dart2js:noInline')
  static SuggestJiraJqlRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SuggestJiraJqlRequest>(
          SuggestJiraJqlRequest.$_createMessage);
  static SuggestJiraJqlRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get fieldName => $_getSZ(1);
  @$pb.TagNumber(2)
  set fieldName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFieldName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFieldName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get prefix => $_getSZ(2);
  @$pb.TagNumber(3)
  set prefix($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPrefix() => $_has(2);
  @$pb.TagNumber(3)
  void clearPrefix() => $_clearField(3);
}

class SuggestJiraJqlResponse extends $pb.GeneratedMessage {
  factory SuggestJiraJqlResponse({
    $core.Iterable<JiraOption>? values,
  }) {
    final result = SuggestJiraJqlResponse._();
    if (values != null) result.values.addAll(values);
    return result;
  }

  SuggestJiraJqlResponse._();

  factory SuggestJiraJqlResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SuggestJiraJqlResponse()..mergeFromBuffer(data, registry);
  factory SuggestJiraJqlResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SuggestJiraJqlResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SuggestJiraJqlResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SuggestJiraJqlResponse.$_createMessage)
    ..pPM<JiraOption>(1, _omitFieldNames ? '' : 'values',
        subBuilder: JiraOption.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SuggestJiraJqlResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SuggestJiraJqlResponse copyWith(
          void Function(SuggestJiraJqlResponse) updates) =>
      super.copyWith((message) => updates(message as SuggestJiraJqlResponse))
          as SuggestJiraJqlResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SuggestJiraJqlResponse() / SuggestJiraJqlResponse.new instead')
  static SuggestJiraJqlResponse create() => SuggestJiraJqlResponse._();
  static $pb.GeneratedMessage $_createMessage() => SuggestJiraJqlResponse._();
  @$core.override
  SuggestJiraJqlResponse createEmptyInstance() => SuggestJiraJqlResponse._();
  @$core.pragma('dart2js:noInline')
  static SuggestJiraJqlResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SuggestJiraJqlResponse>(
          SuggestJiraJqlResponse.$_createMessage);
  static SuggestJiraJqlResponse? _defaultInstance;

  /// id: the value as JQL takes it; name: how it reads.
  @$pb.TagNumber(1)
  $pb.PbList<JiraOption> get values => $_getList(0);
}

class GetJiraIssueRequest extends $pb.GeneratedMessage {
  factory GetJiraIssueRequest({
    $core.String? site,
    $core.String? key,
    $core.bool? cached,
  }) {
    final result = GetJiraIssueRequest._();
    if (site != null) result.site = site;
    if (key != null) result.key = key;
    if (cached != null) result.cached = cached;
    return result;
  }

  GetJiraIssueRequest._();

  factory GetJiraIssueRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraIssueRequest()..mergeFromBuffer(data, registry);
  factory GetJiraIssueRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraIssueRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetJiraIssueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetJiraIssueRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'key')
    ..aOB(3, _omitFieldNames ? '' : 'cached')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraIssueRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraIssueRequest copyWith(void Function(GetJiraIssueRequest) updates) =>
      super.copyWith((message) => updates(message as GetJiraIssueRequest))
          as GetJiraIssueRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core
      .Deprecated('Use GetJiraIssueRequest() / GetJiraIssueRequest.new instead')
  static GetJiraIssueRequest create() => GetJiraIssueRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetJiraIssueRequest._();
  @$core.override
  GetJiraIssueRequest createEmptyInstance() => GetJiraIssueRequest._();
  @$core.pragma('dart2js:noInline')
  static GetJiraIssueRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetJiraIssueRequest>(
          GetJiraIssueRequest.$_createMessage);
  static GetJiraIssueRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get key => $_getSZ(1);
  @$pb.TagNumber(2)
  set key($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);

  /// As the issue showed last (ListJiraIssuesRequest.cached).
  @$pb.TagNumber(3)
  $core.bool get cached => $_getBF(2);
  @$pb.TagNumber(3)
  set cached($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCached() => $_has(2);
  @$pb.TagNumber(3)
  void clearCached() => $_clearField(3);
}

class GetJiraIssueResponse extends $pb.GeneratedMessage {
  factory GetJiraIssueResponse({
    JiraIssue? issue,
    $core.Iterable<JiraWrite>? agentWrites,
    $fixnum.Int64? atMs,
  }) {
    final result = GetJiraIssueResponse._();
    if (issue != null) result.issue = issue;
    if (agentWrites != null) result.agentWrites.addAll(agentWrites);
    if (atMs != null) result.atMs = atMs;
    return result;
  }

  GetJiraIssueResponse._();

  factory GetJiraIssueResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraIssueResponse()..mergeFromBuffer(data, registry);
  factory GetJiraIssueResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraIssueResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetJiraIssueResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetJiraIssueResponse.$_createMessage)
    ..aOM<JiraIssue>(1, _omitFieldNames ? '' : 'issue',
        subBuilder: JiraIssue.$_createMessage)
    ..pPM<JiraWrite>(2, _omitFieldNames ? '' : 'agentWrites',
        subBuilder: JiraWrite.$_createMessage)
    ..aInt64(3, _omitFieldNames ? '' : 'atMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraIssueResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraIssueResponse copyWith(void Function(GetJiraIssueResponse) updates) =>
      super.copyWith((message) => updates(message as GetJiraIssueResponse))
          as GetJiraIssueResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetJiraIssueResponse() / GetJiraIssueResponse.new instead')
  static GetJiraIssueResponse create() => GetJiraIssueResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetJiraIssueResponse._();
  @$core.override
  GetJiraIssueResponse createEmptyInstance() => GetJiraIssueResponse._();
  @$core.pragma('dart2js:noInline')
  static GetJiraIssueResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetJiraIssueResponse>(
          GetJiraIssueResponse.$_createMessage);
  static GetJiraIssueResponse? _defaultInstance;

  @$pb.TagNumber(1)
  JiraIssue get issue => $_getN(0);
  @$pb.TagNumber(1)
  set issue(JiraIssue value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasIssue() => $_has(0);
  @$pb.TagNumber(1)
  void clearIssue() => $_clearField(1);
  @$pb.TagNumber(1)
  JiraIssue ensureIssue() => $_ensure(0);

  /// What agents wrote to it through their tools, the latest last.
  @$pb.TagNumber(2)
  $pb.PbList<JiraWrite> get agentWrites => $_getList(1);

  /// When Jira said so (0 for a cached issue never kept).
  @$pb.TagNumber(3)
  $fixnum.Int64 get atMs => $_getI64(2);
  @$pb.TagNumber(3)
  set atMs($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAtMs() => $_has(2);
  @$pb.TagNumber(3)
  void clearAtMs() => $_clearField(3);
}

/// A write an agent made to an issue through its tools (ADR 0043).
class JiraWrite extends $pb.GeneratedMessage {
  factory JiraWrite({
    $core.String? kind,
    $core.String? comment,
    $core.String? to,
    $core.String? chat,
    $core.String? agent,
    $fixnum.Int64? at,
  }) {
    final result = JiraWrite._();
    if (kind != null) result.kind = kind;
    if (comment != null) result.comment = comment;
    if (to != null) result.to = to;
    if (chat != null) result.chat = chat;
    if (agent != null) result.agent = agent;
    if (at != null) result.at = at;
    return result;
  }

  JiraWrite._();

  factory JiraWrite.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraWrite()..mergeFromBuffer(data, registry);
  factory JiraWrite.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      JiraWrite()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'JiraWrite',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: JiraWrite.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'kind')
    ..aOS(2, _omitFieldNames ? '' : 'comment')
    ..aOS(3, _omitFieldNames ? '' : 'to')
    ..aOS(4, _omitFieldNames ? '' : 'chat')
    ..aOS(5, _omitFieldNames ? '' : 'agent')
    ..aInt64(6, _omitFieldNames ? '' : 'at')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraWrite clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  JiraWrite copyWith(void Function(JiraWrite) updates) =>
      super.copyWith((message) => updates(message as JiraWrite)) as JiraWrite;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use JiraWrite() / JiraWrite.new instead')
  static JiraWrite create() => JiraWrite._();
  static $pb.GeneratedMessage $_createMessage() => JiraWrite._();
  @$core.override
  JiraWrite createEmptyInstance() => JiraWrite._();
  @$core.pragma('dart2js:noInline')
  static JiraWrite getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<JiraWrite>(JiraWrite.$_createMessage);
  static JiraWrite? _defaultInstance;

  /// "comment" (comment: its id) or "move" (to: the status).
  @$pb.TagNumber(1)
  $core.String get kind => $_getSZ(0);
  @$pb.TagNumber(1)
  set kind($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasKind() => $_has(0);
  @$pb.TagNumber(1)
  void clearKind() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get comment => $_getSZ(1);
  @$pb.TagNumber(2)
  set comment($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasComment() => $_has(1);
  @$pb.TagNumber(2)
  void clearComment() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get to => $_getSZ(2);
  @$pb.TagNumber(3)
  set to($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTo() => $_has(2);
  @$pb.TagNumber(3)
  void clearTo() => $_clearField(3);

  /// The chat and its agent.
  @$pb.TagNumber(4)
  $core.String get chat => $_getSZ(3);
  @$pb.TagNumber(4)
  set chat($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChat() => $_has(3);
  @$pb.TagNumber(4)
  void clearChat() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get agent => $_getSZ(4);
  @$pb.TagNumber(5)
  set agent($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAgent() => $_has(4);
  @$pb.TagNumber(5)
  void clearAgent() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get at => $_getI64(5);
  @$pb.TagNumber(6)
  set at($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearAt() => $_clearField(6);
}

class ListJiraTransitionsRequest extends $pb.GeneratedMessage {
  factory ListJiraTransitionsRequest({
    $core.String? site,
    $core.String? key,
  }) {
    final result = ListJiraTransitionsRequest._();
    if (site != null) result.site = site;
    if (key != null) result.key = key;
    return result;
  }

  ListJiraTransitionsRequest._();

  factory ListJiraTransitionsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraTransitionsRequest()..mergeFromBuffer(data, registry);
  factory ListJiraTransitionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraTransitionsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraTransitionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraTransitionsRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'key')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraTransitionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraTransitionsRequest copyWith(
          void Function(ListJiraTransitionsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ListJiraTransitionsRequest))
          as ListJiraTransitionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraTransitionsRequest() / ListJiraTransitionsRequest.new instead')
  static ListJiraTransitionsRequest create() => ListJiraTransitionsRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      ListJiraTransitionsRequest._();
  @$core.override
  ListJiraTransitionsRequest createEmptyInstance() =>
      ListJiraTransitionsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListJiraTransitionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraTransitionsRequest>(
          ListJiraTransitionsRequest.$_createMessage);
  static ListJiraTransitionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get key => $_getSZ(1);
  @$pb.TagNumber(2)
  set key($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);
}

class ListJiraTransitionsResponse extends $pb.GeneratedMessage {
  factory ListJiraTransitionsResponse({
    $core.Iterable<JiraTransition>? transitions,
  }) {
    final result = ListJiraTransitionsResponse._();
    if (transitions != null) result.transitions.addAll(transitions);
    return result;
  }

  ListJiraTransitionsResponse._();

  factory ListJiraTransitionsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraTransitionsResponse()..mergeFromBuffer(data, registry);
  factory ListJiraTransitionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListJiraTransitionsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListJiraTransitionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListJiraTransitionsResponse.$_createMessage)
    ..pPM<JiraTransition>(1, _omitFieldNames ? '' : 'transitions',
        subBuilder: JiraTransition.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraTransitionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListJiraTransitionsResponse copyWith(
          void Function(ListJiraTransitionsResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ListJiraTransitionsResponse))
          as ListJiraTransitionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListJiraTransitionsResponse() / ListJiraTransitionsResponse.new instead')
  static ListJiraTransitionsResponse create() =>
      ListJiraTransitionsResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      ListJiraTransitionsResponse._();
  @$core.override
  ListJiraTransitionsResponse createEmptyInstance() =>
      ListJiraTransitionsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListJiraTransitionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListJiraTransitionsResponse>(
          ListJiraTransitionsResponse.$_createMessage);
  static ListJiraTransitionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<JiraTransition> get transitions => $_getList(0);
}

class TransitionJiraIssueRequest extends $pb.GeneratedMessage {
  factory TransitionJiraIssueRequest({
    $core.String? site,
    $core.String? key,
    $core.String? transition,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? values,
  }) {
    final result = TransitionJiraIssueRequest._();
    if (site != null) result.site = site;
    if (key != null) result.key = key;
    if (transition != null) result.transition = transition;
    if (values != null) result.values.addEntries(values);
    return result;
  }

  TransitionJiraIssueRequest._();

  factory TransitionJiraIssueRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransitionJiraIssueRequest()..mergeFromBuffer(data, registry);
  factory TransitionJiraIssueRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransitionJiraIssueRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransitionJiraIssueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TransitionJiraIssueRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'key')
    ..aOS(3, _omitFieldNames ? '' : 'transition')
    ..m<$core.String, $core.String>(4, _omitFieldNames ? '' : 'values',
        entryClassName: 'TransitionJiraIssueRequest.ValuesEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('nushi.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransitionJiraIssueRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransitionJiraIssueRequest copyWith(
          void Function(TransitionJiraIssueRequest) updates) =>
      super.copyWith(
              (message) => updates(message as TransitionJiraIssueRequest))
          as TransitionJiraIssueRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransitionJiraIssueRequest() / TransitionJiraIssueRequest.new instead')
  static TransitionJiraIssueRequest create() => TransitionJiraIssueRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      TransitionJiraIssueRequest._();
  @$core.override
  TransitionJiraIssueRequest createEmptyInstance() =>
      TransitionJiraIssueRequest._();
  @$core.pragma('dart2js:noInline')
  static TransitionJiraIssueRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransitionJiraIssueRequest>(
          TransitionJiraIssueRequest.$_createMessage);
  static TransitionJiraIssueRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get key => $_getSZ(1);
  @$pb.TagNumber(2)
  set key($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get transition => $_getSZ(2);
  @$pb.TagNumber(3)
  set transition($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTransition() => $_has(2);
  @$pb.TagNumber(3)
  void clearTransition() => $_clearField(3);

  /// By field id.
  @$pb.TagNumber(4)
  $pb.PbMap<$core.String, $core.String> get values => $_getMap(3);
}

class TransitionJiraIssueResponse extends $pb.GeneratedMessage {
  factory TransitionJiraIssueResponse() => TransitionJiraIssueResponse._();

  TransitionJiraIssueResponse._();

  factory TransitionJiraIssueResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransitionJiraIssueResponse()..mergeFromBuffer(data, registry);
  factory TransitionJiraIssueResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      TransitionJiraIssueResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TransitionJiraIssueResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: TransitionJiraIssueResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransitionJiraIssueResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TransitionJiraIssueResponse copyWith(
          void Function(TransitionJiraIssueResponse) updates) =>
      super.copyWith(
              (message) => updates(message as TransitionJiraIssueResponse))
          as TransitionJiraIssueResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use TransitionJiraIssueResponse() / TransitionJiraIssueResponse.new instead')
  static TransitionJiraIssueResponse create() =>
      TransitionJiraIssueResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      TransitionJiraIssueResponse._();
  @$core.override
  TransitionJiraIssueResponse createEmptyInstance() =>
      TransitionJiraIssueResponse._();
  @$core.pragma('dart2js:noInline')
  static TransitionJiraIssueResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TransitionJiraIssueResponse>(
          TransitionJiraIssueResponse.$_createMessage);
  static TransitionJiraIssueResponse? _defaultInstance;
}

class AddJiraCommentRequest extends $pb.GeneratedMessage {
  factory AddJiraCommentRequest({
    $core.String? site,
    $core.String? key,
    $core.String? markdown,
  }) {
    final result = AddJiraCommentRequest._();
    if (site != null) result.site = site;
    if (key != null) result.key = key;
    if (markdown != null) result.markdown = markdown;
    return result;
  }

  AddJiraCommentRequest._();

  factory AddJiraCommentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraCommentRequest()..mergeFromBuffer(data, registry);
  factory AddJiraCommentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraCommentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddJiraCommentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddJiraCommentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'key')
    ..aOS(3, _omitFieldNames ? '' : 'markdown')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraCommentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraCommentRequest copyWith(
          void Function(AddJiraCommentRequest) updates) =>
      super.copyWith((message) => updates(message as AddJiraCommentRequest))
          as AddJiraCommentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddJiraCommentRequest() / AddJiraCommentRequest.new instead')
  static AddJiraCommentRequest create() => AddJiraCommentRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddJiraCommentRequest._();
  @$core.override
  AddJiraCommentRequest createEmptyInstance() => AddJiraCommentRequest._();
  @$core.pragma('dart2js:noInline')
  static AddJiraCommentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddJiraCommentRequest>(
          AddJiraCommentRequest.$_createMessage);
  static AddJiraCommentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get key => $_getSZ(1);
  @$pb.TagNumber(2)
  set key($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKey() => $_has(1);
  @$pb.TagNumber(2)
  void clearKey() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get markdown => $_getSZ(2);
  @$pb.TagNumber(3)
  set markdown($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarkdown() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarkdown() => $_clearField(3);
}

class AddJiraCommentResponse extends $pb.GeneratedMessage {
  factory AddJiraCommentResponse({
    JiraComment? comment,
  }) {
    final result = AddJiraCommentResponse._();
    if (comment != null) result.comment = comment;
    return result;
  }

  AddJiraCommentResponse._();

  factory AddJiraCommentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraCommentResponse()..mergeFromBuffer(data, registry);
  factory AddJiraCommentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddJiraCommentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddJiraCommentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddJiraCommentResponse.$_createMessage)
    ..aOM<JiraComment>(1, _omitFieldNames ? '' : 'comment',
        subBuilder: JiraComment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraCommentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddJiraCommentResponse copyWith(
          void Function(AddJiraCommentResponse) updates) =>
      super.copyWith((message) => updates(message as AddJiraCommentResponse))
          as AddJiraCommentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddJiraCommentResponse() / AddJiraCommentResponse.new instead')
  static AddJiraCommentResponse create() => AddJiraCommentResponse._();
  static $pb.GeneratedMessage $_createMessage() => AddJiraCommentResponse._();
  @$core.override
  AddJiraCommentResponse createEmptyInstance() => AddJiraCommentResponse._();
  @$core.pragma('dart2js:noInline')
  static AddJiraCommentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddJiraCommentResponse>(
          AddJiraCommentResponse.$_createMessage);
  static AddJiraCommentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  JiraComment get comment => $_getN(0);
  @$pb.TagNumber(1)
  set comment(JiraComment value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasComment() => $_has(0);
  @$pb.TagNumber(1)
  void clearComment() => $_clearField(1);
  @$pb.TagNumber(1)
  JiraComment ensureComment() => $_ensure(0);
}

class GetJiraAttachmentRequest extends $pb.GeneratedMessage {
  factory GetJiraAttachmentRequest({
    $core.String? site,
    $core.String? id,
    $core.bool? thumbnail,
  }) {
    final result = GetJiraAttachmentRequest._();
    if (site != null) result.site = site;
    if (id != null) result.id = id;
    if (thumbnail != null) result.thumbnail = thumbnail;
    return result;
  }

  GetJiraAttachmentRequest._();

  factory GetJiraAttachmentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraAttachmentRequest()..mergeFromBuffer(data, registry);
  factory GetJiraAttachmentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraAttachmentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetJiraAttachmentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetJiraAttachmentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOB(3, _omitFieldNames ? '' : 'thumbnail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraAttachmentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraAttachmentRequest copyWith(
          void Function(GetJiraAttachmentRequest) updates) =>
      super.copyWith((message) => updates(message as GetJiraAttachmentRequest))
          as GetJiraAttachmentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetJiraAttachmentRequest() / GetJiraAttachmentRequest.new instead')
  static GetJiraAttachmentRequest create() => GetJiraAttachmentRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetJiraAttachmentRequest._();
  @$core.override
  GetJiraAttachmentRequest createEmptyInstance() =>
      GetJiraAttachmentRequest._();
  @$core.pragma('dart2js:noInline')
  static GetJiraAttachmentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetJiraAttachmentRequest>(
          GetJiraAttachmentRequest.$_createMessage);
  static GetJiraAttachmentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get thumbnail => $_getBF(2);
  @$pb.TagNumber(3)
  set thumbnail($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasThumbnail() => $_has(2);
  @$pb.TagNumber(3)
  void clearThumbnail() => $_clearField(3);
}

class GetJiraAttachmentResponse extends $pb.GeneratedMessage {
  factory GetJiraAttachmentResponse({
    $core.List<$core.int>? data,
    $core.String? mimeType,
  }) {
    final result = GetJiraAttachmentResponse._();
    if (data != null) result.data = data;
    if (mimeType != null) result.mimeType = mimeType;
    return result;
  }

  GetJiraAttachmentResponse._();

  factory GetJiraAttachmentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraAttachmentResponse()..mergeFromBuffer(data, registry);
  factory GetJiraAttachmentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetJiraAttachmentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetJiraAttachmentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetJiraAttachmentResponse.$_createMessage)
    ..a<$core.List<$core.int>>(
        1, _omitFieldNames ? '' : 'data', $pb.PbFieldType.OY)
    ..aOS(2, _omitFieldNames ? '' : 'mimeType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraAttachmentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetJiraAttachmentResponse copyWith(
          void Function(GetJiraAttachmentResponse) updates) =>
      super.copyWith((message) => updates(message as GetJiraAttachmentResponse))
          as GetJiraAttachmentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetJiraAttachmentResponse() / GetJiraAttachmentResponse.new instead')
  static GetJiraAttachmentResponse create() => GetJiraAttachmentResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      GetJiraAttachmentResponse._();
  @$core.override
  GetJiraAttachmentResponse createEmptyInstance() =>
      GetJiraAttachmentResponse._();
  @$core.pragma('dart2js:noInline')
  static GetJiraAttachmentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetJiraAttachmentResponse>(
          GetJiraAttachmentResponse.$_createMessage);
  static GetJiraAttachmentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get data => $_getN(0);
  @$pb.TagNumber(1)
  set data($core.List<$core.int> value) => $_setBytes(0, value);
  @$pb.TagNumber(1)
  $core.bool hasData() => $_has(0);
  @$pb.TagNumber(1)
  void clearData() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get mimeType => $_getSZ(1);
  @$pb.TagNumber(2)
  set mimeType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMimeType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMimeType() => $_clearField(2);
}

class FindJiraIssuesRequest extends $pb.GeneratedMessage {
  factory FindJiraIssuesRequest({
    $core.String? text,
    $core.String? site,
  }) {
    final result = FindJiraIssuesRequest._();
    if (text != null) result.text = text;
    if (site != null) result.site = site;
    return result;
  }

  FindJiraIssuesRequest._();

  factory FindJiraIssuesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FindJiraIssuesRequest()..mergeFromBuffer(data, registry);
  factory FindJiraIssuesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FindJiraIssuesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindJiraIssuesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FindJiraIssuesRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..aOS(2, _omitFieldNames ? '' : 'site')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindJiraIssuesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindJiraIssuesRequest copyWith(
          void Function(FindJiraIssuesRequest) updates) =>
      super.copyWith((message) => updates(message as FindJiraIssuesRequest))
          as FindJiraIssuesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FindJiraIssuesRequest() / FindJiraIssuesRequest.new instead')
  static FindJiraIssuesRequest create() => FindJiraIssuesRequest._();
  static $pb.GeneratedMessage $_createMessage() => FindJiraIssuesRequest._();
  @$core.override
  FindJiraIssuesRequest createEmptyInstance() => FindJiraIssuesRequest._();
  @$core.pragma('dart2js:noInline')
  static FindJiraIssuesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindJiraIssuesRequest>(
          FindJiraIssuesRequest.$_createMessage);
  static FindJiraIssuesRequest? _defaultInstance;

  /// An issue's link (https://<site>/browse/KEY, a board's ?selectedIssue=),
  /// its key, or words of it; empty for the issues looked at last.
  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);

  /// The site a key is on (the one used last); empty for the first.
  @$pb.TagNumber(2)
  $core.String get site => $_getSZ(1);
  @$pb.TagNumber(2)
  set site($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSite() => $_has(1);
  @$pb.TagNumber(2)
  void clearSite() => $_clearField(2);
}

class FindJiraIssuesResponse extends $pb.GeneratedMessage {
  factory FindJiraIssuesResponse({
    $core.Iterable<FoundJiraIssue>? issues,
    $core.String? unknownSite,
  }) {
    final result = FindJiraIssuesResponse._();
    if (issues != null) result.issues.addAll(issues);
    if (unknownSite != null) result.unknownSite = unknownSite;
    return result;
  }

  FindJiraIssuesResponse._();

  factory FindJiraIssuesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FindJiraIssuesResponse()..mergeFromBuffer(data, registry);
  factory FindJiraIssuesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FindJiraIssuesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FindJiraIssuesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FindJiraIssuesResponse.$_createMessage)
    ..pPM<FoundJiraIssue>(1, _omitFieldNames ? '' : 'issues',
        subBuilder: FoundJiraIssue.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'unknownSite')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindJiraIssuesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FindJiraIssuesResponse copyWith(
          void Function(FindJiraIssuesResponse) updates) =>
      super.copyWith((message) => updates(message as FindJiraIssuesResponse))
          as FindJiraIssuesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use FindJiraIssuesResponse() / FindJiraIssuesResponse.new instead')
  static FindJiraIssuesResponse create() => FindJiraIssuesResponse._();
  static $pb.GeneratedMessage $_createMessage() => FindJiraIssuesResponse._();
  @$core.override
  FindJiraIssuesResponse createEmptyInstance() => FindJiraIssuesResponse._();
  @$core.pragma('dart2js:noInline')
  static FindJiraIssuesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FindJiraIssuesResponse>(
          FindJiraIssuesResponse.$_createMessage);
  static FindJiraIssuesResponse? _defaultInstance;

  /// A link matching several sites has one issue from each.
  @$pb.TagNumber(1)
  $pb.PbList<FoundJiraIssue> get issues => $_getList(0);

  /// A link to a site that isn't added: its address.
  @$pb.TagNumber(2)
  $core.String get unknownSite => $_getSZ(1);
  @$pb.TagNumber(2)
  set unknownSite($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasUnknownSite() => $_has(1);
  @$pb.TagNumber(2)
  void clearUnknownSite() => $_clearField(2);
}

class FoundJiraIssue extends $pb.GeneratedMessage {
  factory FoundJiraIssue({
    $core.String? site,
    JiraIssue? issue,
    $core.String? branch,
  }) {
    final result = FoundJiraIssue._();
    if (site != null) result.site = site;
    if (issue != null) result.issue = issue;
    if (branch != null) result.branch = branch;
    return result;
  }

  FoundJiraIssue._();

  factory FoundJiraIssue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FoundJiraIssue()..mergeFromBuffer(data, registry);
  factory FoundJiraIssue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      FoundJiraIssue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FoundJiraIssue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: FoundJiraIssue.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'site')
    ..aOM<JiraIssue>(2, _omitFieldNames ? '' : 'issue',
        subBuilder: JiraIssue.$_createMessage)
    ..aOS(3, _omitFieldNames ? '' : 'branch')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FoundJiraIssue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FoundJiraIssue copyWith(void Function(FoundJiraIssue) updates) =>
      super.copyWith((message) => updates(message as FoundJiraIssue))
          as FoundJiraIssue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use FoundJiraIssue() / FoundJiraIssue.new instead')
  static FoundJiraIssue create() => FoundJiraIssue._();
  static $pb.GeneratedMessage $_createMessage() => FoundJiraIssue._();
  @$core.override
  FoundJiraIssue createEmptyInstance() => FoundJiraIssue._();
  @$core.pragma('dart2js:noInline')
  static FoundJiraIssue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<FoundJiraIssue>(
          FoundJiraIssue.$_createMessage);
  static FoundJiraIssue? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get site => $_getSZ(0);
  @$pb.TagNumber(1)
  set site($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSite() => $_has(0);
  @$pb.TagNumber(1)
  void clearSite() => $_clearField(1);

  /// Key, summary, type, status.
  @$pb.TagNumber(2)
  JiraIssue get issue => $_getN(1);
  @$pb.TagNumber(2)
  set issue(JiraIssue value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasIssue() => $_has(1);
  @$pb.TagNumber(2)
  void clearIssue() => $_clearField(2);
  @$pb.TagNumber(2)
  JiraIssue ensureIssue() => $_ensure(1);

  /// KEY-summary-slug, the key uppercase so Jira links it.
  @$pb.TagNumber(3)
  $core.String get branch => $_getSZ(2);
  @$pb.TagNumber(3)
  set branch($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBranch() => $_has(2);
  @$pb.TagNumber(3)
  void clearBranch() => $_clearField(3);
}

/// What's left of one of GitHub's rate limits ("core", "graphql",
/// "search"…), as GitHub said last.
class GitHubBucket extends $pb.GeneratedMessage {
  factory GitHubBucket({
    $core.String? name,
    $core.int? limit,
    $core.int? remaining,
    $fixnum.Int64? resetMs,
  }) {
    final result = GitHubBucket._();
    if (name != null) result.name = name;
    if (limit != null) result.limit = limit;
    if (remaining != null) result.remaining = remaining;
    if (resetMs != null) result.resetMs = resetMs;
    return result;
  }

  GitHubBucket._();

  factory GitHubBucket.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubBucket()..mergeFromBuffer(data, registry);
  factory GitHubBucket.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubBucket()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubBucket',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubBucket.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..aI(3, _omitFieldNames ? '' : 'remaining')
    ..aInt64(4, _omitFieldNames ? '' : 'resetMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubBucket clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubBucket copyWith(void Function(GitHubBucket) updates) =>
      super.copyWith((message) => updates(message as GitHubBucket))
          as GitHubBucket;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubBucket() / GitHubBucket.new instead')
  static GitHubBucket create() => GitHubBucket._();
  static $pb.GeneratedMessage $_createMessage() => GitHubBucket._();
  @$core.override
  GitHubBucket createEmptyInstance() => GitHubBucket._();
  @$core.pragma('dart2js:noInline')
  static GitHubBucket getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubBucket>(
          GitHubBucket.$_createMessage);
  static GitHubBucket? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get remaining => $_getIZ(2);
  @$pb.TagNumber(3)
  set remaining($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRemaining() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemaining() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get resetMs => $_getI64(3);
  @$pb.TagNumber(4)
  set resetMs($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasResetMs() => $_has(3);
  @$pb.TagNumber(4)
  void clearResetMs() => $_clearField(4);
}

class GitHubHost extends $pb.GeneratedMessage {
  factory GitHubHost({
    $core.String? host,
    $core.String? login,
    $core.String? name,
    $core.String? source,
    $core.String? kind,
    $core.Iterable<$core.String>? scopes,
    $core.Iterable<GitHubBucket>? budget,
    $core.String? problem,
    $core.bool? needsOk,
    $core.bool? pasted,
    $core.bool? needsRestart,
  }) {
    final result = GitHubHost._();
    if (host != null) result.host = host;
    if (login != null) result.login = login;
    if (name != null) result.name = name;
    if (source != null) result.source = source;
    if (kind != null) result.kind = kind;
    if (scopes != null) result.scopes.addAll(scopes);
    if (budget != null) result.budget.addAll(budget);
    if (problem != null) result.problem = problem;
    if (needsOk != null) result.needsOk = needsOk;
    if (pasted != null) result.pasted = pasted;
    if (needsRestart != null) result.needsRestart = needsRestart;
    return result;
  }

  GitHubHost._();

  factory GitHubHost.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubHost()..mergeFromBuffer(data, registry);
  factory GitHubHost.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubHost()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubHost',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubHost.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'login')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'source')
    ..aOS(5, _omitFieldNames ? '' : 'kind')
    ..pPS(6, _omitFieldNames ? '' : 'scopes')
    ..pPM<GitHubBucket>(7, _omitFieldNames ? '' : 'budget',
        subBuilder: GitHubBucket.$_createMessage)
    ..aOS(8, _omitFieldNames ? '' : 'problem')
    ..aOB(9, _omitFieldNames ? '' : 'needsOk')
    ..aOB(10, _omitFieldNames ? '' : 'pasted')
    ..aOB(11, _omitFieldNames ? '' : 'needsRestart')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubHost clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubHost copyWith(void Function(GitHubHost) updates) =>
      super.copyWith((message) => updates(message as GitHubHost)) as GitHubHost;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubHost() / GitHubHost.new instead')
  static GitHubHost create() => GitHubHost._();
  static $pb.GeneratedMessage $_createMessage() => GitHubHost._();
  @$core.override
  GitHubHost createEmptyInstance() => GitHubHost._();
  @$core.pragma('dart2js:noInline')
  static GitHubHost getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GitHubHost>(GitHubHost.$_createMessage);
  static GitHubHost? _defaultInstance;

  /// github.com, or an Enterprise server's host.
  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  /// Who its token is.
  @$pb.TagNumber(2)
  $core.String get login => $_getSZ(1);
  @$pb.TagNumber(2)
  set login($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLogin() => $_has(1);
  @$pb.TagNumber(2)
  void clearLogin() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// Where its token is from: "gh" (gh's login), "GH_TOKEN" (the
  /// environment, through gh's rules), "token" (pasted).
  @$pb.TagNumber(4)
  $core.String get source => $_getSZ(3);
  @$pb.TagNumber(4)
  set source($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSource() => $_has(3);
  @$pb.TagNumber(4)
  void clearSource() => $_clearField(4);

  /// "oauth" (gh's), "classic", "fine-grained", "app", or "".
  @$pb.TagNumber(5)
  $core.String get kind => $_getSZ(4);
  @$pb.TagNumber(5)
  set kind($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasKind() => $_has(4);
  @$pb.TagNumber(5)
  void clearKind() => $_clearField(5);

  /// A classic or OAuth token's scopes.
  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get scopes => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<GitHubBucket> get budget => $_getList(6);

  /// Why Nushi can't use it now, if it can't.
  @$pb.TagNumber(8)
  $core.String get problem => $_getSZ(7);
  @$pb.TagNumber(8)
  set problem($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasProblem() => $_has(7);
  @$pb.TagNumber(8)
  void clearProblem() => $_clearField(8);

  /// Its pasted token needs the user's OK for this build (AllowGitHubToken).
  @$pb.TagNumber(9)
  $core.bool get needsOk => $_getBF(8);
  @$pb.TagNumber(9)
  set needsOk($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasNeedsOk() => $_has(8);
  @$pb.TagNumber(9)
  void clearNeedsOk() => $_clearField(9);

  /// A pasted token is kept for it (RemoveGitHubToken).
  @$pb.TagNumber(10)
  $core.bool get pasted => $_getBF(9);
  @$pb.TagNumber(10)
  set pasted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasPasted() => $_has(9);
  @$pb.TagNumber(10)
  void clearPasted() => $_clearField(10);

  /// As JiraSite.needs_restart.
  @$pb.TagNumber(11)
  $core.bool get needsRestart => $_getBF(10);
  @$pb.TagNumber(11)
  set needsRestart($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNeedsRestart() => $_has(10);
  @$pb.TagNumber(11)
  void clearNeedsRestart() => $_clearField(11);
}

class ListGitHubHostsRequest extends $pb.GeneratedMessage {
  factory ListGitHubHostsRequest() => ListGitHubHostsRequest._();

  ListGitHubHostsRequest._();

  factory ListGitHubHostsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubHostsRequest()..mergeFromBuffer(data, registry);
  factory ListGitHubHostsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubHostsRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGitHubHostsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListGitHubHostsRequest.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubHostsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubHostsRequest copyWith(
          void Function(ListGitHubHostsRequest) updates) =>
      super.copyWith((message) => updates(message as ListGitHubHostsRequest))
          as ListGitHubHostsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListGitHubHostsRequest() / ListGitHubHostsRequest.new instead')
  static ListGitHubHostsRequest create() => ListGitHubHostsRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListGitHubHostsRequest._();
  @$core.override
  ListGitHubHostsRequest createEmptyInstance() => ListGitHubHostsRequest._();
  @$core.pragma('dart2js:noInline')
  static ListGitHubHostsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGitHubHostsRequest>(
          ListGitHubHostsRequest.$_createMessage);
  static ListGitHubHostsRequest? _defaultInstance;
}

class ListGitHubHostsResponse extends $pb.GeneratedMessage {
  factory ListGitHubHostsResponse({
    $core.Iterable<GitHubHost>? hosts,
  }) {
    final result = ListGitHubHostsResponse._();
    if (hosts != null) result.hosts.addAll(hosts);
    return result;
  }

  ListGitHubHostsResponse._();

  factory ListGitHubHostsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubHostsResponse()..mergeFromBuffer(data, registry);
  factory ListGitHubHostsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubHostsResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGitHubHostsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListGitHubHostsResponse.$_createMessage)
    ..pPM<GitHubHost>(1, _omitFieldNames ? '' : 'hosts',
        subBuilder: GitHubHost.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubHostsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubHostsResponse copyWith(
          void Function(ListGitHubHostsResponse) updates) =>
      super.copyWith((message) => updates(message as ListGitHubHostsResponse))
          as ListGitHubHostsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListGitHubHostsResponse() / ListGitHubHostsResponse.new instead')
  static ListGitHubHostsResponse create() => ListGitHubHostsResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListGitHubHostsResponse._();
  @$core.override
  ListGitHubHostsResponse createEmptyInstance() => ListGitHubHostsResponse._();
  @$core.pragma('dart2js:noInline')
  static ListGitHubHostsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGitHubHostsResponse>(
          ListGitHubHostsResponse.$_createMessage);
  static ListGitHubHostsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GitHubHost> get hosts => $_getList(0);
}

class AddGitHubTokenRequest extends $pb.GeneratedMessage {
  factory AddGitHubTokenRequest({
    $core.String? host,
    $core.String? token,
  }) {
    final result = AddGitHubTokenRequest._();
    if (host != null) result.host = host;
    if (token != null) result.token = token;
    return result;
  }

  AddGitHubTokenRequest._();

  factory AddGitHubTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubTokenRequest()..mergeFromBuffer(data, registry);
  factory AddGitHubTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubTokenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddGitHubTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddGitHubTokenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubTokenRequest copyWith(
          void Function(AddGitHubTokenRequest) updates) =>
      super.copyWith((message) => updates(message as AddGitHubTokenRequest))
          as AddGitHubTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddGitHubTokenRequest() / AddGitHubTokenRequest.new instead')
  static AddGitHubTokenRequest create() => AddGitHubTokenRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddGitHubTokenRequest._();
  @$core.override
  AddGitHubTokenRequest createEmptyInstance() => AddGitHubTokenRequest._();
  @$core.pragma('dart2js:noInline')
  static AddGitHubTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddGitHubTokenRequest>(
          AddGitHubTokenRequest.$_createMessage);
  static AddGitHubTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get token => $_getSZ(1);
  @$pb.TagNumber(2)
  set token($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearToken() => $_clearField(2);
}

class AddGitHubTokenResponse extends $pb.GeneratedMessage {
  factory AddGitHubTokenResponse({
    $core.String? login,
  }) {
    final result = AddGitHubTokenResponse._();
    if (login != null) result.login = login;
    return result;
  }

  AddGitHubTokenResponse._();

  factory AddGitHubTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubTokenResponse()..mergeFromBuffer(data, registry);
  factory AddGitHubTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubTokenResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddGitHubTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddGitHubTokenResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'login')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubTokenResponse copyWith(
          void Function(AddGitHubTokenResponse) updates) =>
      super.copyWith((message) => updates(message as AddGitHubTokenResponse))
          as AddGitHubTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddGitHubTokenResponse() / AddGitHubTokenResponse.new instead')
  static AddGitHubTokenResponse create() => AddGitHubTokenResponse._();
  static $pb.GeneratedMessage $_createMessage() => AddGitHubTokenResponse._();
  @$core.override
  AddGitHubTokenResponse createEmptyInstance() => AddGitHubTokenResponse._();
  @$core.pragma('dart2js:noInline')
  static AddGitHubTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddGitHubTokenResponse>(
          AddGitHubTokenResponse.$_createMessage);
  static AddGitHubTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get login => $_getSZ(0);
  @$pb.TagNumber(1)
  set login($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLogin() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogin() => $_clearField(1);
}

class RemoveGitHubTokenRequest extends $pb.GeneratedMessage {
  factory RemoveGitHubTokenRequest({
    $core.String? host,
  }) {
    final result = RemoveGitHubTokenRequest._();
    if (host != null) result.host = host;
    return result;
  }

  RemoveGitHubTokenRequest._();

  factory RemoveGitHubTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveGitHubTokenRequest()..mergeFromBuffer(data, registry);
  factory RemoveGitHubTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveGitHubTokenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveGitHubTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveGitHubTokenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveGitHubTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveGitHubTokenRequest copyWith(
          void Function(RemoveGitHubTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveGitHubTokenRequest))
          as RemoveGitHubTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveGitHubTokenRequest() / RemoveGitHubTokenRequest.new instead')
  static RemoveGitHubTokenRequest create() => RemoveGitHubTokenRequest._();
  static $pb.GeneratedMessage $_createMessage() => RemoveGitHubTokenRequest._();
  @$core.override
  RemoveGitHubTokenRequest createEmptyInstance() =>
      RemoveGitHubTokenRequest._();
  @$core.pragma('dart2js:noInline')
  static RemoveGitHubTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveGitHubTokenRequest>(
          RemoveGitHubTokenRequest.$_createMessage);
  static RemoveGitHubTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);
}

class RemoveGitHubTokenResponse extends $pb.GeneratedMessage {
  factory RemoveGitHubTokenResponse() => RemoveGitHubTokenResponse._();

  RemoveGitHubTokenResponse._();

  factory RemoveGitHubTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveGitHubTokenResponse()..mergeFromBuffer(data, registry);
  factory RemoveGitHubTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      RemoveGitHubTokenResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveGitHubTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: RemoveGitHubTokenResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveGitHubTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveGitHubTokenResponse copyWith(
          void Function(RemoveGitHubTokenResponse) updates) =>
      super.copyWith((message) => updates(message as RemoveGitHubTokenResponse))
          as RemoveGitHubTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use RemoveGitHubTokenResponse() / RemoveGitHubTokenResponse.new instead')
  static RemoveGitHubTokenResponse create() => RemoveGitHubTokenResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      RemoveGitHubTokenResponse._();
  @$core.override
  RemoveGitHubTokenResponse createEmptyInstance() =>
      RemoveGitHubTokenResponse._();
  @$core.pragma('dart2js:noInline')
  static RemoveGitHubTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveGitHubTokenResponse>(
          RemoveGitHubTokenResponse.$_createMessage);
  static RemoveGitHubTokenResponse? _defaultInstance;
}

class AllowGitHubTokenRequest extends $pb.GeneratedMessage {
  factory AllowGitHubTokenRequest({
    $core.String? host,
  }) {
    final result = AllowGitHubTokenRequest._();
    if (host != null) result.host = host;
    return result;
  }

  AllowGitHubTokenRequest._();

  factory AllowGitHubTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowGitHubTokenRequest()..mergeFromBuffer(data, registry);
  factory AllowGitHubTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowGitHubTokenRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AllowGitHubTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AllowGitHubTokenRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowGitHubTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowGitHubTokenRequest copyWith(
          void Function(AllowGitHubTokenRequest) updates) =>
      super.copyWith((message) => updates(message as AllowGitHubTokenRequest))
          as AllowGitHubTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AllowGitHubTokenRequest() / AllowGitHubTokenRequest.new instead')
  static AllowGitHubTokenRequest create() => AllowGitHubTokenRequest._();
  static $pb.GeneratedMessage $_createMessage() => AllowGitHubTokenRequest._();
  @$core.override
  AllowGitHubTokenRequest createEmptyInstance() => AllowGitHubTokenRequest._();
  @$core.pragma('dart2js:noInline')
  static AllowGitHubTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AllowGitHubTokenRequest>(
          AllowGitHubTokenRequest.$_createMessage);
  static AllowGitHubTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);
}

class AllowGitHubTokenResponse extends $pb.GeneratedMessage {
  factory AllowGitHubTokenResponse() => AllowGitHubTokenResponse._();

  AllowGitHubTokenResponse._();

  factory AllowGitHubTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowGitHubTokenResponse()..mergeFromBuffer(data, registry);
  factory AllowGitHubTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AllowGitHubTokenResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AllowGitHubTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AllowGitHubTokenResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowGitHubTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AllowGitHubTokenResponse copyWith(
          void Function(AllowGitHubTokenResponse) updates) =>
      super.copyWith((message) => updates(message as AllowGitHubTokenResponse))
          as AllowGitHubTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AllowGitHubTokenResponse() / AllowGitHubTokenResponse.new instead')
  static AllowGitHubTokenResponse create() => AllowGitHubTokenResponse._();
  static $pb.GeneratedMessage $_createMessage() => AllowGitHubTokenResponse._();
  @$core.override
  AllowGitHubTokenResponse createEmptyInstance() =>
      AllowGitHubTokenResponse._();
  @$core.pragma('dart2js:noInline')
  static AllowGitHubTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AllowGitHubTokenResponse>(
          AllowGitHubTokenResponse.$_createMessage);
  static AllowGitHubTokenResponse? _defaultInstance;
}

class GitHubRepo extends $pb.GeneratedMessage {
  factory GitHubRepo({
    $core.String? host,
    $core.String? repo,
    $core.Iterable<$core.String>? folders,
  }) {
    final result = GitHubRepo._();
    if (host != null) result.host = host;
    if (repo != null) result.repo = repo;
    if (folders != null) result.folders.addAll(folders);
    return result;
  }

  GitHubRepo._();

  factory GitHubRepo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubRepo()..mergeFromBuffer(data, registry);
  factory GitHubRepo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubRepo()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubRepo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubRepo.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'repo')
    ..pPS(3, _omitFieldNames ? '' : 'folders')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubRepo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubRepo copyWith(void Function(GitHubRepo) updates) =>
      super.copyWith((message) => updates(message as GitHubRepo)) as GitHubRepo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubRepo() / GitHubRepo.new instead')
  static GitHubRepo create() => GitHubRepo._();
  static $pb.GeneratedMessage $_createMessage() => GitHubRepo._();
  @$core.override
  GitHubRepo createEmptyInstance() => GitHubRepo._();
  @$core.pragma('dart2js:noInline')
  static GitHubRepo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GitHubRepo>(GitHubRepo.$_createMessage);
  static GitHubRepo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  /// owner/name.
  @$pb.TagNumber(2)
  $core.String get repo => $_getSZ(1);
  @$pb.TagNumber(2)
  set repo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRepo() => $_has(1);
  @$pb.TagNumber(2)
  void clearRepo() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get folders => $_getList(2);
}

class ListGitHubReposRequest extends $pb.GeneratedMessage {
  factory ListGitHubReposRequest({
    $core.Iterable<$core.String>? folders,
  }) {
    final result = ListGitHubReposRequest._();
    if (folders != null) result.folders.addAll(folders);
    return result;
  }

  ListGitHubReposRequest._();

  factory ListGitHubReposRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubReposRequest()..mergeFromBuffer(data, registry);
  factory ListGitHubReposRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubReposRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGitHubReposRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListGitHubReposRequest.$_createMessage)
    ..pPS(1, _omitFieldNames ? '' : 'folders')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubReposRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubReposRequest copyWith(
          void Function(ListGitHubReposRequest) updates) =>
      super.copyWith((message) => updates(message as ListGitHubReposRequest))
          as ListGitHubReposRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListGitHubReposRequest() / ListGitHubReposRequest.new instead')
  static ListGitHubReposRequest create() => ListGitHubReposRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListGitHubReposRequest._();
  @$core.override
  ListGitHubReposRequest createEmptyInstance() => ListGitHubReposRequest._();
  @$core.pragma('dart2js:noInline')
  static ListGitHubReposRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGitHubReposRequest>(
          ListGitHubReposRequest.$_createMessage);
  static ListGitHubReposRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.String> get folders => $_getList(0);
}

class ListGitHubReposResponse extends $pb.GeneratedMessage {
  factory ListGitHubReposResponse({
    $core.Iterable<GitHubRepo>? repos,
  }) {
    final result = ListGitHubReposResponse._();
    if (repos != null) result.repos.addAll(repos);
    return result;
  }

  ListGitHubReposResponse._();

  factory ListGitHubReposResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubReposResponse()..mergeFromBuffer(data, registry);
  factory ListGitHubReposResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubReposResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGitHubReposResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListGitHubReposResponse.$_createMessage)
    ..pPM<GitHubRepo>(1, _omitFieldNames ? '' : 'repos',
        subBuilder: GitHubRepo.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubReposResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubReposResponse copyWith(
          void Function(ListGitHubReposResponse) updates) =>
      super.copyWith((message) => updates(message as ListGitHubReposResponse))
          as ListGitHubReposResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListGitHubReposResponse() / ListGitHubReposResponse.new instead')
  static ListGitHubReposResponse create() => ListGitHubReposResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListGitHubReposResponse._();
  @$core.override
  ListGitHubReposResponse createEmptyInstance() => ListGitHubReposResponse._();
  @$core.pragma('dart2js:noInline')
  static ListGitHubReposResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGitHubReposResponse>(
          ListGitHubReposResponse.$_createMessage);
  static ListGitHubReposResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GitHubRepo> get repos => $_getList(0);
}

/// A pull request or an issue: its host, repository and number.
class GitHubRef extends $pb.GeneratedMessage {
  factory GitHubRef({
    $core.String? host,
    $core.String? repo,
    $core.int? number,
  }) {
    final result = GitHubRef._();
    if (host != null) result.host = host;
    if (repo != null) result.repo = repo;
    if (number != null) result.number = number;
    return result;
  }

  GitHubRef._();

  factory GitHubRef.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubRef()..mergeFromBuffer(data, registry);
  factory GitHubRef.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubRef()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubRef',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubRef.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'repo')
    ..aI(3, _omitFieldNames ? '' : 'number')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubRef clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubRef copyWith(void Function(GitHubRef) updates) =>
      super.copyWith((message) => updates(message as GitHubRef)) as GitHubRef;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubRef() / GitHubRef.new instead')
  static GitHubRef create() => GitHubRef._();
  static $pb.GeneratedMessage $_createMessage() => GitHubRef._();
  @$core.override
  GitHubRef createEmptyInstance() => GitHubRef._();
  @$core.pragma('dart2js:noInline')
  static GitHubRef getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GitHubRef>(GitHubRef.$_createMessage);
  static GitHubRef? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get repo => $_getSZ(1);
  @$pb.TagNumber(2)
  set repo($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRepo() => $_has(1);
  @$pb.TagNumber(2)
  void clearRepo() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get number => $_getIZ(2);
  @$pb.TagNumber(3)
  set number($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNumber() => $_has(2);
  @$pb.TagNumber(3)
  void clearNumber() => $_clearField(3);
}

/// A pull request or an issue as a list shows it.
class GitHubItem extends $pb.GeneratedMessage {
  factory GitHubItem({
    GitHubRef? ref,
    $core.String? id,
    $core.bool? pull,
    $core.String? title,
    $core.String? url,
    $core.String? state,
    $core.bool? draft,
    $core.String? author,
    $fixnum.Int64? updatedMs,
    $core.String? checks,
    $core.String? review,
    $core.int? unresolved,
    $core.int? comments,
  }) {
    final result = GitHubItem._();
    if (ref != null) result.ref = ref;
    if (id != null) result.id = id;
    if (pull != null) result.pull = pull;
    if (title != null) result.title = title;
    if (url != null) result.url = url;
    if (state != null) result.state = state;
    if (draft != null) result.draft = draft;
    if (author != null) result.author = author;
    if (updatedMs != null) result.updatedMs = updatedMs;
    if (checks != null) result.checks = checks;
    if (review != null) result.review = review;
    if (unresolved != null) result.unresolved = unresolved;
    if (comments != null) result.comments = comments;
    return result;
  }

  GitHubItem._();

  factory GitHubItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubItem()..mergeFromBuffer(data, registry);
  factory GitHubItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubItem()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubItem.$_createMessage)
    ..aOM<GitHubRef>(1, _omitFieldNames ? '' : 'ref',
        subBuilder: GitHubRef.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOB(3, _omitFieldNames ? '' : 'pull')
    ..aOS(4, _omitFieldNames ? '' : 'title')
    ..aOS(5, _omitFieldNames ? '' : 'url')
    ..aOS(6, _omitFieldNames ? '' : 'state')
    ..aOB(7, _omitFieldNames ? '' : 'draft')
    ..aOS(8, _omitFieldNames ? '' : 'author')
    ..aInt64(9, _omitFieldNames ? '' : 'updatedMs')
    ..aOS(10, _omitFieldNames ? '' : 'checks')
    ..aOS(11, _omitFieldNames ? '' : 'review')
    ..aI(12, _omitFieldNames ? '' : 'unresolved')
    ..aI(13, _omitFieldNames ? '' : 'comments')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubItem copyWith(void Function(GitHubItem) updates) =>
      super.copyWith((message) => updates(message as GitHubItem)) as GitHubItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubItem() / GitHubItem.new instead')
  static GitHubItem create() => GitHubItem._();
  static $pb.GeneratedMessage $_createMessage() => GitHubItem._();
  @$core.override
  GitHubItem createEmptyInstance() => GitHubItem._();
  @$core.pragma('dart2js:noInline')
  static GitHubItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GitHubItem>(GitHubItem.$_createMessage);
  static GitHubItem? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubRef get ref => $_getN(0);
  @$pb.TagNumber(1)
  set ref(GitHubRef value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRef() => $_has(0);
  @$pb.TagNumber(1)
  void clearRef() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubRef ensureRef() => $_ensure(0);

  /// GitHub's node id.
  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get pull => $_getBF(2);
  @$pb.TagNumber(3)
  set pull($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPull() => $_has(2);
  @$pb.TagNumber(3)
  void clearPull() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get title => $_getSZ(3);
  @$pb.TagNumber(4)
  set title($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTitle() => $_has(3);
  @$pb.TagNumber(4)
  void clearTitle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get url => $_getSZ(4);
  @$pb.TagNumber(5)
  set url($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearUrl() => $_clearField(5);

  /// "open", "closed" or "merged".
  @$pb.TagNumber(6)
  $core.String get state => $_getSZ(5);
  @$pb.TagNumber(6)
  set state($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasState() => $_has(5);
  @$pb.TagNumber(6)
  void clearState() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get draft => $_getBF(6);
  @$pb.TagNumber(7)
  set draft($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDraft() => $_has(6);
  @$pb.TagNumber(7)
  void clearDraft() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get author => $_getSZ(7);
  @$pb.TagNumber(8)
  set author($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAuthor() => $_has(7);
  @$pb.TagNumber(8)
  void clearAuthor() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get updatedMs => $_getI64(8);
  @$pb.TagNumber(9)
  set updatedMs($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdatedMs() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdatedMs() => $_clearField(9);

  /// A pull request's checks: "success", "failure", "pending", or "".
  @$pb.TagNumber(10)
  $core.String get checks => $_getSZ(9);
  @$pb.TagNumber(10)
  set checks($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasChecks() => $_has(9);
  @$pb.TagNumber(10)
  void clearChecks() => $_clearField(10);

  /// Its review decision: "approved", "changes_requested",
  /// "review_required", or "".
  @$pb.TagNumber(11)
  $core.String get review => $_getSZ(10);
  @$pb.TagNumber(11)
  set review($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasReview() => $_has(10);
  @$pb.TagNumber(11)
  void clearReview() => $_clearField(11);

  /// Its review threads not resolved.
  @$pb.TagNumber(12)
  $core.int get unresolved => $_getIZ(11);
  @$pb.TagNumber(12)
  set unresolved($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasUnresolved() => $_has(11);
  @$pb.TagNumber(12)
  void clearUnresolved() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get comments => $_getIZ(12);
  @$pb.TagNumber(13)
  set comments($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasComments() => $_has(12);
  @$pb.TagNumber(13)
  void clearComments() => $_clearField(13);
}

class ListGitHubInboxRequest extends $pb.GeneratedMessage {
  factory ListGitHubInboxRequest({
    $core.String? host,
    $core.Iterable<$core.String>? repos,
    $core.bool? quiet,
    $core.bool? teams,
    $core.bool? cached,
    $core.int? updatedDays,
    $core.Iterable<$core.String>? wide,
    $core.Iterable<$core.String>? hide,
    $core.Iterable<$core.String>? owners,
  }) {
    final result = ListGitHubInboxRequest._();
    if (host != null) result.host = host;
    if (repos != null) result.repos.addAll(repos);
    if (quiet != null) result.quiet = quiet;
    if (teams != null) result.teams = teams;
    if (cached != null) result.cached = cached;
    if (updatedDays != null) result.updatedDays = updatedDays;
    if (wide != null) result.wide.addAll(wide);
    if (hide != null) result.hide.addAll(hide);
    if (owners != null) result.owners.addAll(owners);
    return result;
  }

  ListGitHubInboxRequest._();

  factory ListGitHubInboxRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubInboxRequest()..mergeFromBuffer(data, registry);
  factory ListGitHubInboxRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubInboxRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGitHubInboxRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListGitHubInboxRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..pPS(2, _omitFieldNames ? '' : 'repos')
    ..aOB(3, _omitFieldNames ? '' : 'quiet')
    ..aOB(4, _omitFieldNames ? '' : 'teams')
    ..aOB(5, _omitFieldNames ? '' : 'cached')
    ..aI(6, _omitFieldNames ? '' : 'updatedDays')
    ..pPS(7, _omitFieldNames ? '' : 'wide')
    ..pPS(8, _omitFieldNames ? '' : 'hide')
    ..pPS(9, _omitFieldNames ? '' : 'owners')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubInboxRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubInboxRequest copyWith(
          void Function(ListGitHubInboxRequest) updates) =>
      super.copyWith((message) => updates(message as ListGitHubInboxRequest))
          as ListGitHubInboxRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListGitHubInboxRequest() / ListGitHubInboxRequest.new instead')
  static ListGitHubInboxRequest create() => ListGitHubInboxRequest._();
  static $pb.GeneratedMessage $_createMessage() => ListGitHubInboxRequest._();
  @$core.override
  ListGitHubInboxRequest createEmptyInstance() => ListGitHubInboxRequest._();
  @$core.pragma('dart2js:noInline')
  static ListGitHubInboxRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGitHubInboxRequest>(
          ListGitHubInboxRequest.$_createMessage);
  static ListGitHubInboxRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  /// Only these repositories' (owner/name); empty for all.
  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get repos => $_getList(1);

  /// The app's timer asking: held back while a rate limit is low.
  @$pb.TagNumber(3)
  $core.bool get quiet => $_getBF(2);
  @$pb.TagNumber(3)
  set quiet($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuiet() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuiet() => $_clearField(3);

  /// Review requested includes pull requests asked of a team of mine
  /// (GitHub's review-requested:@me); else only those asking me by name
  /// (user-review-requested:@me).
  @$pb.TagNumber(4)
  $core.bool get teams => $_getBF(3);
  @$pb.TagNumber(4)
  set teams($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTeams() => $_has(3);
  @$pb.TagNumber(4)
  void clearTeams() => $_clearField(4);

  /// The inbox as GitHub gave it last, kept by the daemon, without asking
  /// GitHub: shown at once while it's asked for (at_ms 0 when none).
  @$pb.TagNumber(5)
  $core.bool get cached => $_getBF(4);
  @$pb.TagNumber(5)
  set cached($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCached() => $_has(4);
  @$pb.TagNumber(5)
  void clearCached() => $_clearField(5);

  /// Only what changed in the last this many days (0: any time), in the
  /// search itself; except the sections named in wide ("review", "mine",
  /// "assigned").
  @$pb.TagNumber(6)
  $core.int get updatedDays => $_getIZ(5);
  @$pb.TagNumber(6)
  set updatedDays($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUpdatedDays() => $_has(5);
  @$pb.TagNumber(6)
  void clearUpdatedDays() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.String> get wide => $_getList(6);

  /// Never these repositories (owner/name) or owners' (a user or an
  /// organization), in the search itself.
  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get hide => $_getList(7);

  /// Only these owners' repositories (10 at most); none for all.
  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get owners => $_getList(8);
}

class ListGitHubInboxResponse extends $pb.GeneratedMessage {
  factory ListGitHubInboxResponse({
    $core.Iterable<GitHubItem>? review,
    $core.Iterable<GitHubItem>? mine,
    $core.Iterable<GitHubItem>? assigned,
    $core.int? reviewTotal,
    $core.int? mineTotal,
    $core.int? assignedTotal,
    $fixnum.Int64? atMs,
    $core.String? stale,
    $core.int? reviewOlder,
    $core.int? mineOlder,
    $core.int? assignedOlder,
  }) {
    final result = ListGitHubInboxResponse._();
    if (review != null) result.review.addAll(review);
    if (mine != null) result.mine.addAll(mine);
    if (assigned != null) result.assigned.addAll(assigned);
    if (reviewTotal != null) result.reviewTotal = reviewTotal;
    if (mineTotal != null) result.mineTotal = mineTotal;
    if (assignedTotal != null) result.assignedTotal = assignedTotal;
    if (atMs != null) result.atMs = atMs;
    if (stale != null) result.stale = stale;
    if (reviewOlder != null) result.reviewOlder = reviewOlder;
    if (mineOlder != null) result.mineOlder = mineOlder;
    if (assignedOlder != null) result.assignedOlder = assignedOlder;
    return result;
  }

  ListGitHubInboxResponse._();

  factory ListGitHubInboxResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubInboxResponse()..mergeFromBuffer(data, registry);
  factory ListGitHubInboxResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ListGitHubInboxResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGitHubInboxResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ListGitHubInboxResponse.$_createMessage)
    ..pPM<GitHubItem>(1, _omitFieldNames ? '' : 'review',
        subBuilder: GitHubItem.$_createMessage)
    ..pPM<GitHubItem>(2, _omitFieldNames ? '' : 'mine',
        subBuilder: GitHubItem.$_createMessage)
    ..pPM<GitHubItem>(3, _omitFieldNames ? '' : 'assigned',
        subBuilder: GitHubItem.$_createMessage)
    ..aI(4, _omitFieldNames ? '' : 'reviewTotal')
    ..aI(5, _omitFieldNames ? '' : 'mineTotal')
    ..aI(6, _omitFieldNames ? '' : 'assignedTotal')
    ..aInt64(7, _omitFieldNames ? '' : 'atMs')
    ..aOS(8, _omitFieldNames ? '' : 'stale')
    ..aI(9, _omitFieldNames ? '' : 'reviewOlder')
    ..aI(10, _omitFieldNames ? '' : 'mineOlder')
    ..aI(11, _omitFieldNames ? '' : 'assignedOlder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubInboxResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGitHubInboxResponse copyWith(
          void Function(ListGitHubInboxResponse) updates) =>
      super.copyWith((message) => updates(message as ListGitHubInboxResponse))
          as ListGitHubInboxResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ListGitHubInboxResponse() / ListGitHubInboxResponse.new instead')
  static ListGitHubInboxResponse create() => ListGitHubInboxResponse._();
  static $pb.GeneratedMessage $_createMessage() => ListGitHubInboxResponse._();
  @$core.override
  ListGitHubInboxResponse createEmptyInstance() => ListGitHubInboxResponse._();
  @$core.pragma('dart2js:noInline')
  static ListGitHubInboxResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGitHubInboxResponse>(
          ListGitHubInboxResponse.$_createMessage);
  static ListGitHubInboxResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GitHubItem> get review => $_getList(0);

  @$pb.TagNumber(2)
  $pb.PbList<GitHubItem> get mine => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<GitHubItem> get assigned => $_getList(2);

  /// How many each search found (50 are listed at most).
  @$pb.TagNumber(4)
  $core.int get reviewTotal => $_getIZ(3);
  @$pb.TagNumber(4)
  set reviewTotal($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReviewTotal() => $_has(3);
  @$pb.TagNumber(4)
  void clearReviewTotal() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get mineTotal => $_getIZ(4);
  @$pb.TagNumber(5)
  set mineTotal($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMineTotal() => $_has(4);
  @$pb.TagNumber(5)
  void clearMineTotal() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get assignedTotal => $_getIZ(5);
  @$pb.TagNumber(6)
  set assignedTotal($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAssignedTotal() => $_has(5);
  @$pb.TagNumber(6)
  void clearAssignedTotal() => $_clearField(6);

  /// When GitHub said so; with stale, why it couldn't say again.
  @$pb.TagNumber(7)
  $fixnum.Int64 get atMs => $_getI64(6);
  @$pb.TagNumber(7)
  set atMs($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAtMs() => $_has(6);
  @$pb.TagNumber(7)
  void clearAtMs() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get stale => $_getSZ(7);
  @$pb.TagNumber(8)
  set stale($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasStale() => $_has(7);
  @$pb.TagNumber(8)
  void clearStale() => $_clearField(8);

  /// How many more each search finds without updated_days (0 without it,
  /// or for a wide section).
  @$pb.TagNumber(9)
  $core.int get reviewOlder => $_getIZ(8);
  @$pb.TagNumber(9)
  set reviewOlder($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasReviewOlder() => $_has(8);
  @$pb.TagNumber(9)
  void clearReviewOlder() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get mineOlder => $_getIZ(9);
  @$pb.TagNumber(10)
  set mineOlder($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasMineOlder() => $_has(9);
  @$pb.TagNumber(10)
  void clearMineOlder() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get assignedOlder => $_getIZ(10);
  @$pb.TagNumber(11)
  set assignedOlder($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasAssignedOlder() => $_has(10);
  @$pb.TagNumber(11)
  void clearAssignedOlder() => $_clearField(11);
}

/// A pull request or an issue a chat is on: its host and node id, and its
/// repository and number.
class GitHubLink extends $pb.GeneratedMessage {
  factory GitHubLink({
    $core.String? host,
    $core.String? id,
    $core.String? repo,
    $core.int? number,
    $core.bool? pull,
  }) {
    final result = GitHubLink._();
    if (host != null) result.host = host;
    if (id != null) result.id = id;
    if (repo != null) result.repo = repo;
    if (number != null) result.number = number;
    if (pull != null) result.pull = pull;
    return result;
  }

  GitHubLink._();

  factory GitHubLink.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubLink()..mergeFromBuffer(data, registry);
  factory GitHubLink.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubLink()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubLink',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubLink.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'id')
    ..aOS(3, _omitFieldNames ? '' : 'repo')
    ..aI(4, _omitFieldNames ? '' : 'number')
    ..aOB(5, _omitFieldNames ? '' : 'pull')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubLink clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubLink copyWith(void Function(GitHubLink) updates) =>
      super.copyWith((message) => updates(message as GitHubLink)) as GitHubLink;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubLink() / GitHubLink.new instead')
  static GitHubLink create() => GitHubLink._();
  static $pb.GeneratedMessage $_createMessage() => GitHubLink._();
  @$core.override
  GitHubLink createEmptyInstance() => GitHubLink._();
  @$core.pragma('dart2js:noInline')
  static GitHubLink getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GitHubLink>(GitHubLink.$_createMessage);
  static GitHubLink? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get id => $_getSZ(1);
  @$pb.TagNumber(2)
  set id($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get repo => $_getSZ(2);
  @$pb.TagNumber(3)
  set repo($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRepo() => $_has(2);
  @$pb.TagNumber(3)
  void clearRepo() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get number => $_getIZ(3);
  @$pb.TagNumber(4)
  set number($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNumber() => $_has(3);
  @$pb.TagNumber(4)
  void clearNumber() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get pull => $_getBF(4);
  @$pb.TagNumber(5)
  set pull($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPull() => $_has(4);
  @$pb.TagNumber(5)
  void clearPull() => $_clearField(5);
}

class GetGitHubStatesRequest extends $pb.GeneratedMessage {
  factory GetGitHubStatesRequest({
    $core.Iterable<GitHubLink>? items,
    $core.bool? quiet,
  }) {
    final result = GetGitHubStatesRequest._();
    if (items != null) result.items.addAll(items);
    if (quiet != null) result.quiet = quiet;
    return result;
  }

  GetGitHubStatesRequest._();

  factory GetGitHubStatesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubStatesRequest()..mergeFromBuffer(data, registry);
  factory GetGitHubStatesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubStatesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubStatesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubStatesRequest.$_createMessage)
    ..pPM<GitHubLink>(1, _omitFieldNames ? '' : 'items',
        subBuilder: GitHubLink.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'quiet')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubStatesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubStatesRequest copyWith(
          void Function(GetGitHubStatesRequest) updates) =>
      super.copyWith((message) => updates(message as GetGitHubStatesRequest))
          as GetGitHubStatesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubStatesRequest() / GetGitHubStatesRequest.new instead')
  static GetGitHubStatesRequest create() => GetGitHubStatesRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubStatesRequest._();
  @$core.override
  GetGitHubStatesRequest createEmptyInstance() => GetGitHubStatesRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubStatesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubStatesRequest>(
          GetGitHubStatesRequest.$_createMessage);
  static GetGitHubStatesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GitHubLink> get items => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get quiet => $_getBF(1);
  @$pb.TagNumber(2)
  set quiet($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuiet() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuiet() => $_clearField(2);
}

class GetGitHubStatesResponse extends $pb.GeneratedMessage {
  factory GetGitHubStatesResponse({
    $core.Iterable<GitHubItem>? items,
  }) {
    final result = GetGitHubStatesResponse._();
    if (items != null) result.items.addAll(items);
    return result;
  }

  GetGitHubStatesResponse._();

  factory GetGitHubStatesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubStatesResponse()..mergeFromBuffer(data, registry);
  factory GetGitHubStatesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubStatesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubStatesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubStatesResponse.$_createMessage)
    ..pPM<GitHubItem>(1, _omitFieldNames ? '' : 'items',
        subBuilder: GitHubItem.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubStatesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubStatesResponse copyWith(
          void Function(GetGitHubStatesResponse) updates) =>
      super.copyWith((message) => updates(message as GetGitHubStatesResponse))
          as GetGitHubStatesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubStatesResponse() / GetGitHubStatesResponse.new instead')
  static GetGitHubStatesResponse create() => GetGitHubStatesResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubStatesResponse._();
  @$core.override
  GetGitHubStatesResponse createEmptyInstance() => GetGitHubStatesResponse._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubStatesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubStatesResponse>(
          GetGitHubStatesResponse.$_createMessage);
  static GetGitHubStatesResponse? _defaultInstance;

  /// The ones known, as they are now (or last were).
  @$pb.TagNumber(1)
  $pb.PbList<GitHubItem> get items => $_getList(0);
}

/// A comment, or a review that said something; body is Markdown as
/// GitHub's page shows it.
class GitHubComment extends $pb.GeneratedMessage {
  factory GitHubComment({
    $core.String? id,
    $core.String? author,
    $core.String? association,
    $core.bool? outside,
    $core.bool? bot,
    $core.String? body,
    $core.String? url,
    $fixnum.Int64? createdMs,
    $core.String? review,
  }) {
    final result = GitHubComment._();
    if (id != null) result.id = id;
    if (author != null) result.author = author;
    if (association != null) result.association = association;
    if (outside != null) result.outside = outside;
    if (bot != null) result.bot = bot;
    if (body != null) result.body = body;
    if (url != null) result.url = url;
    if (createdMs != null) result.createdMs = createdMs;
    if (review != null) result.review = review;
    return result;
  }

  GitHubComment._();

  factory GitHubComment.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubComment()..mergeFromBuffer(data, registry);
  factory GitHubComment.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubComment()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubComment',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubComment.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'author')
    ..aOS(3, _omitFieldNames ? '' : 'association')
    ..aOB(4, _omitFieldNames ? '' : 'outside')
    ..aOB(5, _omitFieldNames ? '' : 'bot')
    ..aOS(6, _omitFieldNames ? '' : 'body')
    ..aOS(7, _omitFieldNames ? '' : 'url')
    ..aInt64(8, _omitFieldNames ? '' : 'createdMs')
    ..aOS(9, _omitFieldNames ? '' : 'review')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubComment clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubComment copyWith(void Function(GitHubComment) updates) =>
      super.copyWith((message) => updates(message as GitHubComment))
          as GitHubComment;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubComment() / GitHubComment.new instead')
  static GitHubComment create() => GitHubComment._();
  static $pb.GeneratedMessage $_createMessage() => GitHubComment._();
  @$core.override
  GitHubComment createEmptyInstance() => GitHubComment._();
  @$core.pragma('dart2js:noInline')
  static GitHubComment getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubComment>(
          GitHubComment.$_createMessage);
  static GitHubComment? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get author => $_getSZ(1);
  @$pb.TagNumber(2)
  set author($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAuthor() => $_has(1);
  @$pb.TagNumber(2)
  void clearAuthor() => $_clearField(2);

  /// GitHub's author association: OWNER, MEMBER, COLLABORATOR,
  /// CONTRIBUTOR, FIRST_TIME_CONTRIBUTOR, NONE…
  @$pb.TagNumber(3)
  $core.String get association => $_getSZ(2);
  @$pb.TagNumber(3)
  set association($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAssociation() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssociation() => $_clearField(3);

  /// The author isn't the repository's owner, a member or a collaborator.
  @$pb.TagNumber(4)
  $core.bool get outside => $_getBF(3);
  @$pb.TagNumber(4)
  set outside($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOutside() => $_has(3);
  @$pb.TagNumber(4)
  void clearOutside() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get bot => $_getBF(4);
  @$pb.TagNumber(5)
  set bot($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBot() => $_has(4);
  @$pb.TagNumber(5)
  void clearBot() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get body => $_getSZ(5);
  @$pb.TagNumber(6)
  set body($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBody() => $_has(5);
  @$pb.TagNumber(6)
  void clearBody() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get url => $_getSZ(6);
  @$pb.TagNumber(7)
  set url($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get createdMs => $_getI64(7);
  @$pb.TagNumber(8)
  set createdMs($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedMs() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedMs() => $_clearField(8);

  /// A review's state ("approved", "changes_requested", "commented",
  /// "dismissed"); empty for a comment.
  @$pb.TagNumber(9)
  $core.String get review => $_getSZ(8);
  @$pb.TagNumber(9)
  set review($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasReview() => $_has(8);
  @$pb.TagNumber(9)
  void clearReview() => $_clearField(9);
}

/// A review thread on line (from start_line) of path's side ("left", the
/// base; "right", the head), or on the file. An outdated one's lines are
/// the original ones.
class GitHubThread extends $pb.GeneratedMessage {
  factory GitHubThread({
    $core.String? id,
    $core.String? path,
    $core.String? side,
    $core.int? line,
    $core.int? startLine,
    $core.int? originalLine,
    $core.int? originalStartLine,
    $core.bool? onFile,
    $core.bool? outdated,
    $core.bool? resolved,
    $core.bool? canReply,
    $core.bool? canResolve,
    $core.bool? canUnresolve,
    $core.Iterable<GitHubComment>? comments,
  }) {
    final result = GitHubThread._();
    if (id != null) result.id = id;
    if (path != null) result.path = path;
    if (side != null) result.side = side;
    if (line != null) result.line = line;
    if (startLine != null) result.startLine = startLine;
    if (originalLine != null) result.originalLine = originalLine;
    if (originalStartLine != null) result.originalStartLine = originalStartLine;
    if (onFile != null) result.onFile = onFile;
    if (outdated != null) result.outdated = outdated;
    if (resolved != null) result.resolved = resolved;
    if (canReply != null) result.canReply = canReply;
    if (canResolve != null) result.canResolve = canResolve;
    if (canUnresolve != null) result.canUnresolve = canUnresolve;
    if (comments != null) result.comments.addAll(comments);
    return result;
  }

  GitHubThread._();

  factory GitHubThread.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubThread()..mergeFromBuffer(data, registry);
  factory GitHubThread.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubThread()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubThread',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubThread.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'path')
    ..aOS(3, _omitFieldNames ? '' : 'side')
    ..aI(4, _omitFieldNames ? '' : 'line')
    ..aI(5, _omitFieldNames ? '' : 'startLine')
    ..aI(6, _omitFieldNames ? '' : 'originalLine')
    ..aI(7, _omitFieldNames ? '' : 'originalStartLine')
    ..aOB(8, _omitFieldNames ? '' : 'onFile')
    ..aOB(9, _omitFieldNames ? '' : 'outdated')
    ..aOB(10, _omitFieldNames ? '' : 'resolved')
    ..aOB(11, _omitFieldNames ? '' : 'canReply')
    ..aOB(12, _omitFieldNames ? '' : 'canResolve')
    ..aOB(13, _omitFieldNames ? '' : 'canUnresolve')
    ..pPM<GitHubComment>(14, _omitFieldNames ? '' : 'comments',
        subBuilder: GitHubComment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubThread clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubThread copyWith(void Function(GitHubThread) updates) =>
      super.copyWith((message) => updates(message as GitHubThread))
          as GitHubThread;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubThread() / GitHubThread.new instead')
  static GitHubThread create() => GitHubThread._();
  static $pb.GeneratedMessage $_createMessage() => GitHubThread._();
  @$core.override
  GitHubThread createEmptyInstance() => GitHubThread._();
  @$core.pragma('dart2js:noInline')
  static GitHubThread getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubThread>(
          GitHubThread.$_createMessage);
  static GitHubThread? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get path => $_getSZ(1);
  @$pb.TagNumber(2)
  set path($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPath() => $_has(1);
  @$pb.TagNumber(2)
  void clearPath() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get side => $_getSZ(2);
  @$pb.TagNumber(3)
  set side($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSide() => $_has(2);
  @$pb.TagNumber(3)
  void clearSide() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get line => $_getIZ(3);
  @$pb.TagNumber(4)
  set line($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLine() => $_has(3);
  @$pb.TagNumber(4)
  void clearLine() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get startLine => $_getIZ(4);
  @$pb.TagNumber(5)
  set startLine($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasStartLine() => $_has(4);
  @$pb.TagNumber(5)
  void clearStartLine() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get originalLine => $_getIZ(5);
  @$pb.TagNumber(6)
  set originalLine($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasOriginalLine() => $_has(5);
  @$pb.TagNumber(6)
  void clearOriginalLine() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get originalStartLine => $_getIZ(6);
  @$pb.TagNumber(7)
  set originalStartLine($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasOriginalStartLine() => $_has(6);
  @$pb.TagNumber(7)
  void clearOriginalStartLine() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get onFile => $_getBF(7);
  @$pb.TagNumber(8)
  set onFile($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasOnFile() => $_has(7);
  @$pb.TagNumber(8)
  void clearOnFile() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.bool get outdated => $_getBF(8);
  @$pb.TagNumber(9)
  set outdated($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOutdated() => $_has(8);
  @$pb.TagNumber(9)
  void clearOutdated() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get resolved => $_getBF(9);
  @$pb.TagNumber(10)
  set resolved($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasResolved() => $_has(9);
  @$pb.TagNumber(10)
  void clearResolved() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.bool get canReply => $_getBF(10);
  @$pb.TagNumber(11)
  set canReply($core.bool value) => $_setBool(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCanReply() => $_has(10);
  @$pb.TagNumber(11)
  void clearCanReply() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get canResolve => $_getBF(11);
  @$pb.TagNumber(12)
  set canResolve($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasCanResolve() => $_has(11);
  @$pb.TagNumber(12)
  void clearCanResolve() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get canUnresolve => $_getBF(12);
  @$pb.TagNumber(13)
  set canUnresolve($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCanUnresolve() => $_has(12);
  @$pb.TagNumber(13)
  void clearCanUnresolve() => $_clearField(13);

  @$pb.TagNumber(14)
  $pb.PbList<GitHubComment> get comments => $_getList(13);
}

class GitHubAnnotation extends $pb.GeneratedMessage {
  factory GitHubAnnotation({
    $core.String? path,
    $core.String? level,
    $core.String? title,
    $core.String? message,
    $core.int? line,
    $core.int? endLine,
  }) {
    final result = GitHubAnnotation._();
    if (path != null) result.path = path;
    if (level != null) result.level = level;
    if (title != null) result.title = title;
    if (message != null) result.message = message;
    if (line != null) result.line = line;
    if (endLine != null) result.endLine = endLine;
    return result;
  }

  GitHubAnnotation._();

  factory GitHubAnnotation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubAnnotation()..mergeFromBuffer(data, registry);
  factory GitHubAnnotation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubAnnotation()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubAnnotation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubAnnotation.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'level')
    ..aOS(3, _omitFieldNames ? '' : 'title')
    ..aOS(4, _omitFieldNames ? '' : 'message')
    ..aI(5, _omitFieldNames ? '' : 'line')
    ..aI(6, _omitFieldNames ? '' : 'endLine')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubAnnotation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubAnnotation copyWith(void Function(GitHubAnnotation) updates) =>
      super.copyWith((message) => updates(message as GitHubAnnotation))
          as GitHubAnnotation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubAnnotation() / GitHubAnnotation.new instead')
  static GitHubAnnotation create() => GitHubAnnotation._();
  static $pb.GeneratedMessage $_createMessage() => GitHubAnnotation._();
  @$core.override
  GitHubAnnotation createEmptyInstance() => GitHubAnnotation._();
  @$core.pragma('dart2js:noInline')
  static GitHubAnnotation getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubAnnotation>(
          GitHubAnnotation.$_createMessage);
  static GitHubAnnotation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  /// "failure", "warning", "notice".
  @$pb.TagNumber(2)
  $core.String get level => $_getSZ(1);
  @$pb.TagNumber(2)
  set level($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLevel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLevel() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get title => $_getSZ(2);
  @$pb.TagNumber(3)
  set title($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTitle() => $_has(2);
  @$pb.TagNumber(3)
  void clearTitle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get message => $_getSZ(3);
  @$pb.TagNumber(4)
  set message($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMessage() => $_has(3);
  @$pb.TagNumber(4)
  void clearMessage() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get line => $_getIZ(4);
  @$pb.TagNumber(5)
  set line($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLine() => $_has(4);
  @$pb.TagNumber(5)
  void clearLine() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get endLine => $_getIZ(5);
  @$pb.TagNumber(6)
  set endLine($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEndLine() => $_has(5);
  @$pb.TagNumber(6)
  void clearEndLine() => $_clearField(6);
}

/// A check run (id is its id, an Actions job's) or a commit status (id 0).
class GitHubCheck extends $pb.GeneratedMessage {
  factory GitHubCheck({
    $fixnum.Int64? id,
    $core.String? name,
    $core.String? workflow,
    $core.String? app,
    $core.String? state,
    $core.bool? failed,
    $core.String? url,
    $core.String? title,
    $core.String? summary,
    $core.bool? required,
    $core.Iterable<GitHubAnnotation>? annotations,
    $fixnum.Int64? startedMs,
    $fixnum.Int64? completedMs,
  }) {
    final result = GitHubCheck._();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (workflow != null) result.workflow = workflow;
    if (app != null) result.app = app;
    if (state != null) result.state = state;
    if (failed != null) result.failed = failed;
    if (url != null) result.url = url;
    if (title != null) result.title = title;
    if (summary != null) result.summary = summary;
    if (required != null) result.required = required;
    if (annotations != null) result.annotations.addAll(annotations);
    if (startedMs != null) result.startedMs = startedMs;
    if (completedMs != null) result.completedMs = completedMs;
    return result;
  }

  GitHubCheck._();

  factory GitHubCheck.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubCheck()..mergeFromBuffer(data, registry);
  factory GitHubCheck.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubCheck()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubCheck',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubCheck.$_createMessage)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'workflow')
    ..aOS(4, _omitFieldNames ? '' : 'app')
    ..aOS(5, _omitFieldNames ? '' : 'state')
    ..aOB(6, _omitFieldNames ? '' : 'failed')
    ..aOS(7, _omitFieldNames ? '' : 'url')
    ..aOS(8, _omitFieldNames ? '' : 'title')
    ..aOS(9, _omitFieldNames ? '' : 'summary')
    ..aOB(10, _omitFieldNames ? '' : 'required')
    ..pPM<GitHubAnnotation>(11, _omitFieldNames ? '' : 'annotations',
        subBuilder: GitHubAnnotation.$_createMessage)
    ..aInt64(12, _omitFieldNames ? '' : 'startedMs')
    ..aInt64(13, _omitFieldNames ? '' : 'completedMs')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubCheck clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubCheck copyWith(void Function(GitHubCheck) updates) =>
      super.copyWith((message) => updates(message as GitHubCheck))
          as GitHubCheck;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubCheck() / GitHubCheck.new instead')
  static GitHubCheck create() => GitHubCheck._();
  static $pb.GeneratedMessage $_createMessage() => GitHubCheck._();
  @$core.override
  GitHubCheck createEmptyInstance() => GitHubCheck._();
  @$core.pragma('dart2js:noInline')
  static GitHubCheck getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubCheck>(
          GitHubCheck.$_createMessage);
  static GitHubCheck? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
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
  $core.String get workflow => $_getSZ(2);
  @$pb.TagNumber(3)
  set workflow($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWorkflow() => $_has(2);
  @$pb.TagNumber(3)
  void clearWorkflow() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get app => $_getSZ(3);
  @$pb.TagNumber(4)
  set app($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasApp() => $_has(3);
  @$pb.TagNumber(4)
  void clearApp() => $_clearField(4);

  /// "pending" until it ends, then its conclusion: "success", "failure",
  /// "cancelled", "skipped", "neutral", "timed_out"…
  @$pb.TagNumber(5)
  $core.String get state => $_getSZ(4);
  @$pb.TagNumber(5)
  set state($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasState() => $_has(4);
  @$pb.TagNumber(5)
  void clearState() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get failed => $_getBF(5);
  @$pb.TagNumber(6)
  set failed($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasFailed() => $_has(5);
  @$pb.TagNumber(6)
  void clearFailed() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get url => $_getSZ(6);
  @$pb.TagNumber(7)
  set url($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get title => $_getSZ(7);
  @$pb.TagNumber(8)
  set title($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTitle() => $_has(7);
  @$pb.TagNumber(8)
  void clearTitle() => $_clearField(8);

  /// Markdown as GitHub's page shows it.
  @$pb.TagNumber(9)
  $core.String get summary => $_getSZ(8);
  @$pb.TagNumber(9)
  set summary($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasSummary() => $_has(8);
  @$pb.TagNumber(9)
  void clearSummary() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get required => $_getBF(9);
  @$pb.TagNumber(10)
  set required($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasRequired() => $_has(9);
  @$pb.TagNumber(10)
  void clearRequired() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<GitHubAnnotation> get annotations => $_getList(10);

  @$pb.TagNumber(12)
  $fixnum.Int64 get startedMs => $_getI64(11);
  @$pb.TagNumber(12)
  set startedMs($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasStartedMs() => $_has(11);
  @$pb.TagNumber(12)
  void clearStartedMs() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get completedMs => $_getI64(12);
  @$pb.TagNumber(13)
  set completedMs($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCompletedMs() => $_has(12);
  @$pb.TagNumber(13)
  void clearCompletedMs() => $_clearField(13);
}

/// Someone asked to review ("requested"), or who did ("approved",
/// "changes_requested", "commented", "dismissed"); a team asked has team.
class GitHubReviewer extends $pb.GeneratedMessage {
  factory GitHubReviewer({
    $core.String? login,
    $core.String? state,
    $core.bool? team,
  }) {
    final result = GitHubReviewer._();
    if (login != null) result.login = login;
    if (state != null) result.state = state;
    if (team != null) result.team = team;
    return result;
  }

  GitHubReviewer._();

  factory GitHubReviewer.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubReviewer()..mergeFromBuffer(data, registry);
  factory GitHubReviewer.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubReviewer()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubReviewer',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubReviewer.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'login')
    ..aOS(2, _omitFieldNames ? '' : 'state')
    ..aOB(3, _omitFieldNames ? '' : 'team')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubReviewer clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubReviewer copyWith(void Function(GitHubReviewer) updates) =>
      super.copyWith((message) => updates(message as GitHubReviewer))
          as GitHubReviewer;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubReviewer() / GitHubReviewer.new instead')
  static GitHubReviewer create() => GitHubReviewer._();
  static $pb.GeneratedMessage $_createMessage() => GitHubReviewer._();
  @$core.override
  GitHubReviewer createEmptyInstance() => GitHubReviewer._();
  @$core.pragma('dart2js:noInline')
  static GitHubReviewer getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubReviewer>(
          GitHubReviewer.$_createMessage);
  static GitHubReviewer? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get login => $_getSZ(0);
  @$pb.TagNumber(1)
  set login($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasLogin() => $_has(0);
  @$pb.TagNumber(1)
  void clearLogin() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get state => $_getSZ(1);
  @$pb.TagNumber(2)
  set state($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasState() => $_has(1);
  @$pb.TagNumber(2)
  void clearState() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get team => $_getBF(2);
  @$pb.TagNumber(3)
  set team($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTeam() => $_has(2);
  @$pb.TagNumber(3)
  void clearTeam() => $_clearField(3);
}

class GitHubPull extends $pb.GeneratedMessage {
  factory GitHubPull({
    GitHubItem? item,
    $core.String? body,
    $core.String? association,
    $core.bool? outside,
    $core.String? base,
    $core.String? head,
    $core.String? headRepo,
    $core.bool? crossRepo,
    $core.String? baseOid,
    $core.String? headOid,
    $core.String? mergeable,
    $core.String? mergeState,
    $core.int? additions,
    $core.int? deletions,
    $core.int? changedFiles,
    $core.Iterable<GitHubReviewer>? reviewers,
    $core.Iterable<GitHubComment>? conversation,
    $core.Iterable<GitHubThread>? threads,
    $core.Iterable<GitHubCheck>? checks,
    $core.String? pendingReview,
    $core.int? pendingComments,
  }) {
    final result = GitHubPull._();
    if (item != null) result.item = item;
    if (body != null) result.body = body;
    if (association != null) result.association = association;
    if (outside != null) result.outside = outside;
    if (base != null) result.base = base;
    if (head != null) result.head = head;
    if (headRepo != null) result.headRepo = headRepo;
    if (crossRepo != null) result.crossRepo = crossRepo;
    if (baseOid != null) result.baseOid = baseOid;
    if (headOid != null) result.headOid = headOid;
    if (mergeable != null) result.mergeable = mergeable;
    if (mergeState != null) result.mergeState = mergeState;
    if (additions != null) result.additions = additions;
    if (deletions != null) result.deletions = deletions;
    if (changedFiles != null) result.changedFiles = changedFiles;
    if (reviewers != null) result.reviewers.addAll(reviewers);
    if (conversation != null) result.conversation.addAll(conversation);
    if (threads != null) result.threads.addAll(threads);
    if (checks != null) result.checks.addAll(checks);
    if (pendingReview != null) result.pendingReview = pendingReview;
    if (pendingComments != null) result.pendingComments = pendingComments;
    return result;
  }

  GitHubPull._();

  factory GitHubPull.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubPull()..mergeFromBuffer(data, registry);
  factory GitHubPull.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubPull()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubPull',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubPull.$_createMessage)
    ..aOM<GitHubItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: GitHubItem.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..aOS(3, _omitFieldNames ? '' : 'association')
    ..aOB(4, _omitFieldNames ? '' : 'outside')
    ..aOS(5, _omitFieldNames ? '' : 'base')
    ..aOS(6, _omitFieldNames ? '' : 'head')
    ..aOS(7, _omitFieldNames ? '' : 'headRepo')
    ..aOB(8, _omitFieldNames ? '' : 'crossRepo')
    ..aOS(9, _omitFieldNames ? '' : 'baseOid')
    ..aOS(10, _omitFieldNames ? '' : 'headOid')
    ..aOS(11, _omitFieldNames ? '' : 'mergeable')
    ..aOS(12, _omitFieldNames ? '' : 'mergeState')
    ..aI(13, _omitFieldNames ? '' : 'additions')
    ..aI(14, _omitFieldNames ? '' : 'deletions')
    ..aI(15, _omitFieldNames ? '' : 'changedFiles')
    ..pPM<GitHubReviewer>(16, _omitFieldNames ? '' : 'reviewers',
        subBuilder: GitHubReviewer.$_createMessage)
    ..pPM<GitHubComment>(17, _omitFieldNames ? '' : 'conversation',
        subBuilder: GitHubComment.$_createMessage)
    ..pPM<GitHubThread>(18, _omitFieldNames ? '' : 'threads',
        subBuilder: GitHubThread.$_createMessage)
    ..pPM<GitHubCheck>(19, _omitFieldNames ? '' : 'checks',
        subBuilder: GitHubCheck.$_createMessage)
    ..aOS(20, _omitFieldNames ? '' : 'pendingReview')
    ..aI(21, _omitFieldNames ? '' : 'pendingComments')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubPull clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubPull copyWith(void Function(GitHubPull) updates) =>
      super.copyWith((message) => updates(message as GitHubPull)) as GitHubPull;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubPull() / GitHubPull.new instead')
  static GitHubPull create() => GitHubPull._();
  static $pb.GeneratedMessage $_createMessage() => GitHubPull._();
  @$core.override
  GitHubPull createEmptyInstance() => GitHubPull._();
  @$core.pragma('dart2js:noInline')
  static GitHubPull getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GitHubPull>(GitHubPull.$_createMessage);
  static GitHubPull? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubItem get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(GitHubItem value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubItem ensureItem() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get association => $_getSZ(2);
  @$pb.TagNumber(3)
  set association($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAssociation() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssociation() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get outside => $_getBF(3);
  @$pb.TagNumber(4)
  set outside($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOutside() => $_has(3);
  @$pb.TagNumber(4)
  void clearOutside() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get base => $_getSZ(4);
  @$pb.TagNumber(5)
  set base($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBase() => $_has(4);
  @$pb.TagNumber(5)
  void clearBase() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get head => $_getSZ(5);
  @$pb.TagNumber(6)
  set head($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHead() => $_has(5);
  @$pb.TagNumber(6)
  void clearHead() => $_clearField(6);

  /// The head's repository (owner/name): another one for a fork's.
  @$pb.TagNumber(7)
  $core.String get headRepo => $_getSZ(6);
  @$pb.TagNumber(7)
  set headRepo($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasHeadRepo() => $_has(6);
  @$pb.TagNumber(7)
  void clearHeadRepo() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get crossRepo => $_getBF(7);
  @$pb.TagNumber(8)
  set crossRepo($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCrossRepo() => $_has(7);
  @$pb.TagNumber(8)
  void clearCrossRepo() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get baseOid => $_getSZ(8);
  @$pb.TagNumber(9)
  set baseOid($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBaseOid() => $_has(8);
  @$pb.TagNumber(9)
  void clearBaseOid() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get headOid => $_getSZ(9);
  @$pb.TagNumber(10)
  set headOid($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasHeadOid() => $_has(9);
  @$pb.TagNumber(10)
  void clearHeadOid() => $_clearField(10);

  /// "mergeable", "conflicting", "unknown".
  @$pb.TagNumber(11)
  $core.String get mergeable => $_getSZ(10);
  @$pb.TagNumber(11)
  set mergeable($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasMergeable() => $_has(10);
  @$pb.TagNumber(11)
  void clearMergeable() => $_clearField(11);

  /// "clean", "blocked", "behind", "dirty", "unstable", "has_hooks",
  /// "unknown".
  @$pb.TagNumber(12)
  $core.String get mergeState => $_getSZ(11);
  @$pb.TagNumber(12)
  set mergeState($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasMergeState() => $_has(11);
  @$pb.TagNumber(12)
  void clearMergeState() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get additions => $_getIZ(12);
  @$pb.TagNumber(13)
  set additions($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAdditions() => $_has(12);
  @$pb.TagNumber(13)
  void clearAdditions() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get deletions => $_getIZ(13);
  @$pb.TagNumber(14)
  set deletions($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasDeletions() => $_has(13);
  @$pb.TagNumber(14)
  void clearDeletions() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get changedFiles => $_getIZ(14);
  @$pb.TagNumber(15)
  set changedFiles($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasChangedFiles() => $_has(14);
  @$pb.TagNumber(15)
  void clearChangedFiles() => $_clearField(15);

  @$pb.TagNumber(16)
  $pb.PbList<GitHubReviewer> get reviewers => $_getList(15);

  /// Comments and reviews that said something, oldest first.
  @$pb.TagNumber(17)
  $pb.PbList<GitHubComment> get conversation => $_getList(16);

  @$pb.TagNumber(18)
  $pb.PbList<GitHubThread> get threads => $_getList(17);

  @$pb.TagNumber(19)
  $pb.PbList<GitHubCheck> get checks => $_getList(18);

  /// My review pending on GitHub (made in the browser), which a review
  /// submitted here joins, and its comments' count.
  @$pb.TagNumber(20)
  $core.String get pendingReview => $_getSZ(19);
  @$pb.TagNumber(20)
  set pendingReview($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasPendingReview() => $_has(19);
  @$pb.TagNumber(20)
  void clearPendingReview() => $_clearField(20);

  @$pb.TagNumber(21)
  $core.int get pendingComments => $_getIZ(20);
  @$pb.TagNumber(21)
  set pendingComments($core.int value) => $_setSignedInt32(20, value);
  @$pb.TagNumber(21)
  $core.bool hasPendingComments() => $_has(20);
  @$pb.TagNumber(21)
  void clearPendingComments() => $_clearField(21);
}

class GetGitHubPullRequest extends $pb.GeneratedMessage {
  factory GetGitHubPullRequest({
    GitHubRef? ref,
    $core.bool? quiet,
  }) {
    final result = GetGitHubPullRequest._();
    if (ref != null) result.ref = ref;
    if (quiet != null) result.quiet = quiet;
    return result;
  }

  GetGitHubPullRequest._();

  factory GetGitHubPullRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPullRequest()..mergeFromBuffer(data, registry);
  factory GetGitHubPullRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPullRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubPullRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubPullRequest.$_createMessage)
    ..aOM<GitHubRef>(1, _omitFieldNames ? '' : 'ref',
        subBuilder: GitHubRef.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'quiet')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPullRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPullRequest copyWith(void Function(GetGitHubPullRequest) updates) =>
      super.copyWith((message) => updates(message as GetGitHubPullRequest))
          as GetGitHubPullRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubPullRequest() / GetGitHubPullRequest.new instead')
  static GetGitHubPullRequest create() => GetGitHubPullRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubPullRequest._();
  @$core.override
  GetGitHubPullRequest createEmptyInstance() => GetGitHubPullRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubPullRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubPullRequest>(
          GetGitHubPullRequest.$_createMessage);
  static GetGitHubPullRequest? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubRef get ref => $_getN(0);
  @$pb.TagNumber(1)
  set ref(GitHubRef value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRef() => $_has(0);
  @$pb.TagNumber(1)
  void clearRef() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubRef ensureRef() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get quiet => $_getBF(1);
  @$pb.TagNumber(2)
  set quiet($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuiet() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuiet() => $_clearField(2);
}

class GetGitHubPullResponse extends $pb.GeneratedMessage {
  factory GetGitHubPullResponse({
    GitHubPull? pull,
  }) {
    final result = GetGitHubPullResponse._();
    if (pull != null) result.pull = pull;
    return result;
  }

  GetGitHubPullResponse._();

  factory GetGitHubPullResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPullResponse()..mergeFromBuffer(data, registry);
  factory GetGitHubPullResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPullResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubPullResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubPullResponse.$_createMessage)
    ..aOM<GitHubPull>(1, _omitFieldNames ? '' : 'pull',
        subBuilder: GitHubPull.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPullResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPullResponse copyWith(
          void Function(GetGitHubPullResponse) updates) =>
      super.copyWith((message) => updates(message as GetGitHubPullResponse))
          as GetGitHubPullResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubPullResponse() / GetGitHubPullResponse.new instead')
  static GetGitHubPullResponse create() => GetGitHubPullResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubPullResponse._();
  @$core.override
  GetGitHubPullResponse createEmptyInstance() => GetGitHubPullResponse._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubPullResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubPullResponse>(
          GetGitHubPullResponse.$_createMessage);
  static GetGitHubPullResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubPull get pull => $_getN(0);
  @$pb.TagNumber(1)
  set pull(GitHubPull value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPull() => $_has(0);
  @$pb.TagNumber(1)
  void clearPull() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubPull ensurePull() => $_ensure(0);
}

class GitHubIssue extends $pb.GeneratedMessage {
  factory GitHubIssue({
    GitHubItem? item,
    $core.String? body,
    $core.String? association,
    $core.bool? outside,
    $core.Iterable<$core.String>? labels,
    $core.Iterable<$core.String>? assignees,
    $core.Iterable<GitHubComment>? conversation,
  }) {
    final result = GitHubIssue._();
    if (item != null) result.item = item;
    if (body != null) result.body = body;
    if (association != null) result.association = association;
    if (outside != null) result.outside = outside;
    if (labels != null) result.labels.addAll(labels);
    if (assignees != null) result.assignees.addAll(assignees);
    if (conversation != null) result.conversation.addAll(conversation);
    return result;
  }

  GitHubIssue._();

  factory GitHubIssue.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubIssue()..mergeFromBuffer(data, registry);
  factory GitHubIssue.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubIssue()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubIssue',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubIssue.$_createMessage)
    ..aOM<GitHubItem>(1, _omitFieldNames ? '' : 'item',
        subBuilder: GitHubItem.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..aOS(3, _omitFieldNames ? '' : 'association')
    ..aOB(4, _omitFieldNames ? '' : 'outside')
    ..pPS(5, _omitFieldNames ? '' : 'labels')
    ..pPS(6, _omitFieldNames ? '' : 'assignees')
    ..pPM<GitHubComment>(7, _omitFieldNames ? '' : 'conversation',
        subBuilder: GitHubComment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubIssue clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubIssue copyWith(void Function(GitHubIssue) updates) =>
      super.copyWith((message) => updates(message as GitHubIssue))
          as GitHubIssue;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubIssue() / GitHubIssue.new instead')
  static GitHubIssue create() => GitHubIssue._();
  static $pb.GeneratedMessage $_createMessage() => GitHubIssue._();
  @$core.override
  GitHubIssue createEmptyInstance() => GitHubIssue._();
  @$core.pragma('dart2js:noInline')
  static GitHubIssue getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubIssue>(
          GitHubIssue.$_createMessage);
  static GitHubIssue? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubItem get item => $_getN(0);
  @$pb.TagNumber(1)
  set item(GitHubItem value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasItem() => $_has(0);
  @$pb.TagNumber(1)
  void clearItem() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubItem ensureItem() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get association => $_getSZ(2);
  @$pb.TagNumber(3)
  set association($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAssociation() => $_has(2);
  @$pb.TagNumber(3)
  void clearAssociation() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get outside => $_getBF(3);
  @$pb.TagNumber(4)
  set outside($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOutside() => $_has(3);
  @$pb.TagNumber(4)
  void clearOutside() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.String> get labels => $_getList(4);

  @$pb.TagNumber(6)
  $pb.PbList<$core.String> get assignees => $_getList(5);

  @$pb.TagNumber(7)
  $pb.PbList<GitHubComment> get conversation => $_getList(6);
}

class GetGitHubIssueRequest extends $pb.GeneratedMessage {
  factory GetGitHubIssueRequest({
    GitHubRef? ref,
    $core.bool? quiet,
  }) {
    final result = GetGitHubIssueRequest._();
    if (ref != null) result.ref = ref;
    if (quiet != null) result.quiet = quiet;
    return result;
  }

  GetGitHubIssueRequest._();

  factory GetGitHubIssueRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubIssueRequest()..mergeFromBuffer(data, registry);
  factory GetGitHubIssueRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubIssueRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubIssueRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubIssueRequest.$_createMessage)
    ..aOM<GitHubRef>(1, _omitFieldNames ? '' : 'ref',
        subBuilder: GitHubRef.$_createMessage)
    ..aOB(2, _omitFieldNames ? '' : 'quiet')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubIssueRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubIssueRequest copyWith(
          void Function(GetGitHubIssueRequest) updates) =>
      super.copyWith((message) => updates(message as GetGitHubIssueRequest))
          as GetGitHubIssueRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubIssueRequest() / GetGitHubIssueRequest.new instead')
  static GetGitHubIssueRequest create() => GetGitHubIssueRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubIssueRequest._();
  @$core.override
  GetGitHubIssueRequest createEmptyInstance() => GetGitHubIssueRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubIssueRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubIssueRequest>(
          GetGitHubIssueRequest.$_createMessage);
  static GetGitHubIssueRequest? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubRef get ref => $_getN(0);
  @$pb.TagNumber(1)
  set ref(GitHubRef value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRef() => $_has(0);
  @$pb.TagNumber(1)
  void clearRef() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubRef ensureRef() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get quiet => $_getBF(1);
  @$pb.TagNumber(2)
  set quiet($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasQuiet() => $_has(1);
  @$pb.TagNumber(2)
  void clearQuiet() => $_clearField(2);
}

class GetGitHubIssueResponse extends $pb.GeneratedMessage {
  factory GetGitHubIssueResponse({
    GitHubIssue? issue,
  }) {
    final result = GetGitHubIssueResponse._();
    if (issue != null) result.issue = issue;
    return result;
  }

  GetGitHubIssueResponse._();

  factory GetGitHubIssueResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubIssueResponse()..mergeFromBuffer(data, registry);
  factory GetGitHubIssueResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubIssueResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubIssueResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubIssueResponse.$_createMessage)
    ..aOM<GitHubIssue>(1, _omitFieldNames ? '' : 'issue',
        subBuilder: GitHubIssue.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubIssueResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubIssueResponse copyWith(
          void Function(GetGitHubIssueResponse) updates) =>
      super.copyWith((message) => updates(message as GetGitHubIssueResponse))
          as GetGitHubIssueResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubIssueResponse() / GetGitHubIssueResponse.new instead')
  static GetGitHubIssueResponse create() => GetGitHubIssueResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubIssueResponse._();
  @$core.override
  GetGitHubIssueResponse createEmptyInstance() => GetGitHubIssueResponse._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubIssueResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubIssueResponse>(
          GetGitHubIssueResponse.$_createMessage);
  static GetGitHubIssueResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubIssue get issue => $_getN(0);
  @$pb.TagNumber(1)
  set issue(GitHubIssue value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasIssue() => $_has(0);
  @$pb.TagNumber(1)
  void clearIssue() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubIssue ensureIssue() => $_ensure(0);
}

class GetGitHubFilesRequest extends $pb.GeneratedMessage {
  factory GetGitHubFilesRequest({
    GitHubRef? ref,
    $core.String? baseOid,
    $core.String? headOid,
  }) {
    final result = GetGitHubFilesRequest._();
    if (ref != null) result.ref = ref;
    if (baseOid != null) result.baseOid = baseOid;
    if (headOid != null) result.headOid = headOid;
    return result;
  }

  GetGitHubFilesRequest._();

  factory GetGitHubFilesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubFilesRequest()..mergeFromBuffer(data, registry);
  factory GetGitHubFilesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubFilesRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubFilesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubFilesRequest.$_createMessage)
    ..aOM<GitHubRef>(1, _omitFieldNames ? '' : 'ref',
        subBuilder: GitHubRef.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'baseOid')
    ..aOS(3, _omitFieldNames ? '' : 'headOid')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubFilesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubFilesRequest copyWith(
          void Function(GetGitHubFilesRequest) updates) =>
      super.copyWith((message) => updates(message as GetGitHubFilesRequest))
          as GetGitHubFilesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubFilesRequest() / GetGitHubFilesRequest.new instead')
  static GetGitHubFilesRequest create() => GetGitHubFilesRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubFilesRequest._();
  @$core.override
  GetGitHubFilesRequest createEmptyInstance() => GetGitHubFilesRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubFilesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubFilesRequest>(
          GetGitHubFilesRequest.$_createMessage);
  static GetGitHubFilesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubRef get ref => $_getN(0);
  @$pb.TagNumber(1)
  set ref(GitHubRef value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRef() => $_has(0);
  @$pb.TagNumber(1)
  void clearRef() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubRef ensureRef() => $_ensure(0);

  /// The pull request's base and head commits (GitHubPull's).
  @$pb.TagNumber(2)
  $core.String get baseOid => $_getSZ(1);
  @$pb.TagNumber(2)
  set baseOid($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBaseOid() => $_has(1);
  @$pb.TagNumber(2)
  void clearBaseOid() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get headOid => $_getSZ(2);
  @$pb.TagNumber(3)
  set headOid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeadOid() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadOid() => $_clearField(3);
}

class GetGitHubFilesResponse extends $pb.GeneratedMessage {
  factory GetGitHubFilesResponse({
    $core.Iterable<FileChange>? files,
  }) {
    final result = GetGitHubFilesResponse._();
    if (files != null) result.files.addAll(files);
    return result;
  }

  GetGitHubFilesResponse._();

  factory GetGitHubFilesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubFilesResponse()..mergeFromBuffer(data, registry);
  factory GetGitHubFilesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubFilesResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubFilesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubFilesResponse.$_createMessage)
    ..pPM<FileChange>(1, _omitFieldNames ? '' : 'files',
        subBuilder: FileChange.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubFilesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubFilesResponse copyWith(
          void Function(GetGitHubFilesResponse) updates) =>
      super.copyWith((message) => updates(message as GetGitHubFilesResponse))
          as GetGitHubFilesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubFilesResponse() / GetGitHubFilesResponse.new instead')
  static GetGitHubFilesResponse create() => GetGitHubFilesResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubFilesResponse._();
  @$core.override
  GetGitHubFilesResponse createEmptyInstance() => GetGitHubFilesResponse._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubFilesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubFilesResponse>(
          GetGitHubFilesResponse.$_createMessage);
  static GetGitHubFilesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<FileChange> get files => $_getList(0);
}

class GetGitHubJobLogRequest extends $pb.GeneratedMessage {
  factory GetGitHubJobLogRequest({
    GitHubRef? ref,
    $fixnum.Int64? job,
  }) {
    final result = GetGitHubJobLogRequest._();
    if (ref != null) result.ref = ref;
    if (job != null) result.job = job;
    return result;
  }

  GetGitHubJobLogRequest._();

  factory GetGitHubJobLogRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubJobLogRequest()..mergeFromBuffer(data, registry);
  factory GetGitHubJobLogRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubJobLogRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubJobLogRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubJobLogRequest.$_createMessage)
    ..aOM<GitHubRef>(1, _omitFieldNames ? '' : 'ref',
        subBuilder: GitHubRef.$_createMessage)
    ..aInt64(2, _omitFieldNames ? '' : 'job')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubJobLogRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubJobLogRequest copyWith(
          void Function(GetGitHubJobLogRequest) updates) =>
      super.copyWith((message) => updates(message as GetGitHubJobLogRequest))
          as GetGitHubJobLogRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubJobLogRequest() / GetGitHubJobLogRequest.new instead')
  static GetGitHubJobLogRequest create() => GetGitHubJobLogRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubJobLogRequest._();
  @$core.override
  GetGitHubJobLogRequest createEmptyInstance() => GetGitHubJobLogRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubJobLogRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubJobLogRequest>(
          GetGitHubJobLogRequest.$_createMessage);
  static GetGitHubJobLogRequest? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubRef get ref => $_getN(0);
  @$pb.TagNumber(1)
  set ref(GitHubRef value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRef() => $_has(0);
  @$pb.TagNumber(1)
  void clearRef() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubRef ensureRef() => $_ensure(0);

  /// The check run's id.
  @$pb.TagNumber(2)
  $fixnum.Int64 get job => $_getI64(1);
  @$pb.TagNumber(2)
  set job($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJob() => $_has(1);
  @$pb.TagNumber(2)
  void clearJob() => $_clearField(2);
}

class GetGitHubJobLogResponse extends $pb.GeneratedMessage {
  factory GetGitHubJobLogResponse({
    $core.String? tail,
  }) {
    final result = GetGitHubJobLogResponse._();
    if (tail != null) result.tail = tail;
    return result;
  }

  GetGitHubJobLogResponse._();

  factory GetGitHubJobLogResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubJobLogResponse()..mergeFromBuffer(data, registry);
  factory GetGitHubJobLogResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubJobLogResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubJobLogResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubJobLogResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'tail')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubJobLogResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubJobLogResponse copyWith(
          void Function(GetGitHubJobLogResponse) updates) =>
      super.copyWith((message) => updates(message as GetGitHubJobLogResponse))
          as GetGitHubJobLogResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubJobLogResponse() / GetGitHubJobLogResponse.new instead')
  static GetGitHubJobLogResponse create() => GetGitHubJobLogResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubJobLogResponse._();
  @$core.override
  GetGitHubJobLogResponse createEmptyInstance() => GetGitHubJobLogResponse._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubJobLogResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubJobLogResponse>(
          GetGitHubJobLogResponse.$_createMessage);
  static GetGitHubJobLogResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tail => $_getSZ(0);
  @$pb.TagNumber(1)
  set tail($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTail() => $_has(0);
  @$pb.TagNumber(1)
  void clearTail() => $_clearField(1);
}

class ReplyGitHubThreadRequest extends $pb.GeneratedMessage {
  factory ReplyGitHubThreadRequest({
    $core.String? host,
    $core.String? thread,
    $core.String? body,
  }) {
    final result = ReplyGitHubThreadRequest._();
    if (host != null) result.host = host;
    if (thread != null) result.thread = thread;
    if (body != null) result.body = body;
    return result;
  }

  ReplyGitHubThreadRequest._();

  factory ReplyGitHubThreadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReplyGitHubThreadRequest()..mergeFromBuffer(data, registry);
  factory ReplyGitHubThreadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReplyGitHubThreadRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplyGitHubThreadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ReplyGitHubThreadRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'thread')
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyGitHubThreadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyGitHubThreadRequest copyWith(
          void Function(ReplyGitHubThreadRequest) updates) =>
      super.copyWith((message) => updates(message as ReplyGitHubThreadRequest))
          as ReplyGitHubThreadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ReplyGitHubThreadRequest() / ReplyGitHubThreadRequest.new instead')
  static ReplyGitHubThreadRequest create() => ReplyGitHubThreadRequest._();
  static $pb.GeneratedMessage $_createMessage() => ReplyGitHubThreadRequest._();
  @$core.override
  ReplyGitHubThreadRequest createEmptyInstance() =>
      ReplyGitHubThreadRequest._();
  @$core.pragma('dart2js:noInline')
  static ReplyGitHubThreadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplyGitHubThreadRequest>(
          ReplyGitHubThreadRequest.$_createMessage);
  static ReplyGitHubThreadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get thread => $_getSZ(1);
  @$pb.TagNumber(2)
  set thread($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasThread() => $_has(1);
  @$pb.TagNumber(2)
  void clearThread() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);
}

class ReplyGitHubThreadResponse extends $pb.GeneratedMessage {
  factory ReplyGitHubThreadResponse({
    GitHubComment? comment,
  }) {
    final result = ReplyGitHubThreadResponse._();
    if (comment != null) result.comment = comment;
    return result;
  }

  ReplyGitHubThreadResponse._();

  factory ReplyGitHubThreadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReplyGitHubThreadResponse()..mergeFromBuffer(data, registry);
  factory ReplyGitHubThreadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ReplyGitHubThreadResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReplyGitHubThreadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ReplyGitHubThreadResponse.$_createMessage)
    ..aOM<GitHubComment>(1, _omitFieldNames ? '' : 'comment',
        subBuilder: GitHubComment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyGitHubThreadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReplyGitHubThreadResponse copyWith(
          void Function(ReplyGitHubThreadResponse) updates) =>
      super.copyWith((message) => updates(message as ReplyGitHubThreadResponse))
          as ReplyGitHubThreadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ReplyGitHubThreadResponse() / ReplyGitHubThreadResponse.new instead')
  static ReplyGitHubThreadResponse create() => ReplyGitHubThreadResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      ReplyGitHubThreadResponse._();
  @$core.override
  ReplyGitHubThreadResponse createEmptyInstance() =>
      ReplyGitHubThreadResponse._();
  @$core.pragma('dart2js:noInline')
  static ReplyGitHubThreadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReplyGitHubThreadResponse>(
          ReplyGitHubThreadResponse.$_createMessage);
  static ReplyGitHubThreadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubComment get comment => $_getN(0);
  @$pb.TagNumber(1)
  set comment(GitHubComment value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasComment() => $_has(0);
  @$pb.TagNumber(1)
  void clearComment() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubComment ensureComment() => $_ensure(0);
}

class ResolveGitHubThreadRequest extends $pb.GeneratedMessage {
  factory ResolveGitHubThreadRequest({
    $core.String? host,
    $core.String? thread,
    $core.bool? resolve,
  }) {
    final result = ResolveGitHubThreadRequest._();
    if (host != null) result.host = host;
    if (thread != null) result.thread = thread;
    if (resolve != null) result.resolve = resolve;
    return result;
  }

  ResolveGitHubThreadRequest._();

  factory ResolveGitHubThreadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveGitHubThreadRequest()..mergeFromBuffer(data, registry);
  factory ResolveGitHubThreadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveGitHubThreadRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveGitHubThreadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ResolveGitHubThreadRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'thread')
    ..aOB(3, _omitFieldNames ? '' : 'resolve')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveGitHubThreadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveGitHubThreadRequest copyWith(
          void Function(ResolveGitHubThreadRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ResolveGitHubThreadRequest))
          as ResolveGitHubThreadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ResolveGitHubThreadRequest() / ResolveGitHubThreadRequest.new instead')
  static ResolveGitHubThreadRequest create() => ResolveGitHubThreadRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      ResolveGitHubThreadRequest._();
  @$core.override
  ResolveGitHubThreadRequest createEmptyInstance() =>
      ResolveGitHubThreadRequest._();
  @$core.pragma('dart2js:noInline')
  static ResolveGitHubThreadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveGitHubThreadRequest>(
          ResolveGitHubThreadRequest.$_createMessage);
  static ResolveGitHubThreadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get thread => $_getSZ(1);
  @$pb.TagNumber(2)
  set thread($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasThread() => $_has(1);
  @$pb.TagNumber(2)
  void clearThread() => $_clearField(2);

  /// False unresolves it.
  @$pb.TagNumber(3)
  $core.bool get resolve => $_getBF(2);
  @$pb.TagNumber(3)
  set resolve($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasResolve() => $_has(2);
  @$pb.TagNumber(3)
  void clearResolve() => $_clearField(3);
}

class ResolveGitHubThreadResponse extends $pb.GeneratedMessage {
  factory ResolveGitHubThreadResponse() => ResolveGitHubThreadResponse._();

  ResolveGitHubThreadResponse._();

  factory ResolveGitHubThreadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveGitHubThreadResponse()..mergeFromBuffer(data, registry);
  factory ResolveGitHubThreadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      ResolveGitHubThreadResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveGitHubThreadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: ResolveGitHubThreadResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveGitHubThreadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveGitHubThreadResponse copyWith(
          void Function(ResolveGitHubThreadResponse) updates) =>
      super.copyWith(
              (message) => updates(message as ResolveGitHubThreadResponse))
          as ResolveGitHubThreadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use ResolveGitHubThreadResponse() / ResolveGitHubThreadResponse.new instead')
  static ResolveGitHubThreadResponse create() =>
      ResolveGitHubThreadResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      ResolveGitHubThreadResponse._();
  @$core.override
  ResolveGitHubThreadResponse createEmptyInstance() =>
      ResolveGitHubThreadResponse._();
  @$core.pragma('dart2js:noInline')
  static ResolveGitHubThreadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveGitHubThreadResponse>(
          ResolveGitHubThreadResponse.$_createMessage);
  static ResolveGitHubThreadResponse? _defaultInstance;
}

class AddGitHubCommentRequest extends $pb.GeneratedMessage {
  factory AddGitHubCommentRequest({
    $core.String? host,
    $core.String? subject,
    $core.String? body,
  }) {
    final result = AddGitHubCommentRequest._();
    if (host != null) result.host = host;
    if (subject != null) result.subject = subject;
    if (body != null) result.body = body;
    return result;
  }

  AddGitHubCommentRequest._();

  factory AddGitHubCommentRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubCommentRequest()..mergeFromBuffer(data, registry);
  factory AddGitHubCommentRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubCommentRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddGitHubCommentRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddGitHubCommentRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'subject')
    ..aOS(3, _omitFieldNames ? '' : 'body')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubCommentRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubCommentRequest copyWith(
          void Function(AddGitHubCommentRequest) updates) =>
      super.copyWith((message) => updates(message as AddGitHubCommentRequest))
          as AddGitHubCommentRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddGitHubCommentRequest() / AddGitHubCommentRequest.new instead')
  static AddGitHubCommentRequest create() => AddGitHubCommentRequest._();
  static $pb.GeneratedMessage $_createMessage() => AddGitHubCommentRequest._();
  @$core.override
  AddGitHubCommentRequest createEmptyInstance() => AddGitHubCommentRequest._();
  @$core.pragma('dart2js:noInline')
  static AddGitHubCommentRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddGitHubCommentRequest>(
          AddGitHubCommentRequest.$_createMessage);
  static AddGitHubCommentRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  /// The pull request's or issue's node id.
  @$pb.TagNumber(2)
  $core.String get subject => $_getSZ(1);
  @$pb.TagNumber(2)
  set subject($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSubject() => $_has(1);
  @$pb.TagNumber(2)
  void clearSubject() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get body => $_getSZ(2);
  @$pb.TagNumber(3)
  set body($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasBody() => $_has(2);
  @$pb.TagNumber(3)
  void clearBody() => $_clearField(3);
}

class AddGitHubCommentResponse extends $pb.GeneratedMessage {
  factory AddGitHubCommentResponse({
    GitHubComment? comment,
  }) {
    final result = AddGitHubCommentResponse._();
    if (comment != null) result.comment = comment;
    return result;
  }

  AddGitHubCommentResponse._();

  factory AddGitHubCommentResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubCommentResponse()..mergeFromBuffer(data, registry);
  factory AddGitHubCommentResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      AddGitHubCommentResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddGitHubCommentResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: AddGitHubCommentResponse.$_createMessage)
    ..aOM<GitHubComment>(1, _omitFieldNames ? '' : 'comment',
        subBuilder: GitHubComment.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubCommentResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddGitHubCommentResponse copyWith(
          void Function(AddGitHubCommentResponse) updates) =>
      super.copyWith((message) => updates(message as AddGitHubCommentResponse))
          as AddGitHubCommentResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use AddGitHubCommentResponse() / AddGitHubCommentResponse.new instead')
  static AddGitHubCommentResponse create() => AddGitHubCommentResponse._();
  static $pb.GeneratedMessage $_createMessage() => AddGitHubCommentResponse._();
  @$core.override
  AddGitHubCommentResponse createEmptyInstance() =>
      AddGitHubCommentResponse._();
  @$core.pragma('dart2js:noInline')
  static AddGitHubCommentResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddGitHubCommentResponse>(
          AddGitHubCommentResponse.$_createMessage);
  static AddGitHubCommentResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubComment get comment => $_getN(0);
  @$pb.TagNumber(1)
  set comment(GitHubComment value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasComment() => $_has(0);
  @$pb.TagNumber(1)
  void clearComment() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubComment ensureComment() => $_ensure(0);
}

/// A comment of a review not yet sent, on line (from start_line, if more
/// than one) of path's side ("left" or "right").
class GitHubDraft extends $pb.GeneratedMessage {
  factory GitHubDraft({
    $core.String? path,
    $core.String? side,
    $core.int? line,
    $core.int? startLine,
    $core.String? body,
  }) {
    final result = GitHubDraft._();
    if (path != null) result.path = path;
    if (side != null) result.side = side;
    if (line != null) result.line = line;
    if (startLine != null) result.startLine = startLine;
    if (body != null) result.body = body;
    return result;
  }

  GitHubDraft._();

  factory GitHubDraft.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubDraft()..mergeFromBuffer(data, registry);
  factory GitHubDraft.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GitHubDraft()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GitHubDraft',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GitHubDraft.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'path')
    ..aOS(2, _omitFieldNames ? '' : 'side')
    ..aI(3, _omitFieldNames ? '' : 'line')
    ..aI(4, _omitFieldNames ? '' : 'startLine')
    ..aOS(5, _omitFieldNames ? '' : 'body')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubDraft clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GitHubDraft copyWith(void Function(GitHubDraft) updates) =>
      super.copyWith((message) => updates(message as GitHubDraft))
          as GitHubDraft;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated('Use GitHubDraft() / GitHubDraft.new instead')
  static GitHubDraft create() => GitHubDraft._();
  static $pb.GeneratedMessage $_createMessage() => GitHubDraft._();
  @$core.override
  GitHubDraft createEmptyInstance() => GitHubDraft._();
  @$core.pragma('dart2js:noInline')
  static GitHubDraft getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GitHubDraft>(
          GitHubDraft.$_createMessage);
  static GitHubDraft? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get path => $_getSZ(0);
  @$pb.TagNumber(1)
  set path($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPath() => $_has(0);
  @$pb.TagNumber(1)
  void clearPath() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get side => $_getSZ(1);
  @$pb.TagNumber(2)
  set side($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSide() => $_has(1);
  @$pb.TagNumber(2)
  void clearSide() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get line => $_getIZ(2);
  @$pb.TagNumber(3)
  set line($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLine() => $_has(2);
  @$pb.TagNumber(3)
  void clearLine() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get startLine => $_getIZ(3);
  @$pb.TagNumber(4)
  set startLine($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStartLine() => $_has(3);
  @$pb.TagNumber(4)
  void clearStartLine() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get body => $_getSZ(4);
  @$pb.TagNumber(5)
  set body($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBody() => $_has(4);
  @$pb.TagNumber(5)
  void clearBody() => $_clearField(5);
}

class SubmitGitHubReviewRequest extends $pb.GeneratedMessage {
  factory SubmitGitHubReviewRequest({
    $core.String? host,
    $core.String? pull,
    $core.String? headOid,
    $core.String? pendingReview,
    $core.String? event,
    $core.String? body,
    $core.Iterable<GitHubDraft>? drafts,
  }) {
    final result = SubmitGitHubReviewRequest._();
    if (host != null) result.host = host;
    if (pull != null) result.pull = pull;
    if (headOid != null) result.headOid = headOid;
    if (pendingReview != null) result.pendingReview = pendingReview;
    if (event != null) result.event = event;
    if (body != null) result.body = body;
    if (drafts != null) result.drafts.addAll(drafts);
    return result;
  }

  SubmitGitHubReviewRequest._();

  factory SubmitGitHubReviewRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubmitGitHubReviewRequest()..mergeFromBuffer(data, registry);
  factory SubmitGitHubReviewRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubmitGitHubReviewRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitGitHubReviewRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SubmitGitHubReviewRequest.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'host')
    ..aOS(2, _omitFieldNames ? '' : 'pull')
    ..aOS(3, _omitFieldNames ? '' : 'headOid')
    ..aOS(4, _omitFieldNames ? '' : 'pendingReview')
    ..aOS(5, _omitFieldNames ? '' : 'event')
    ..aOS(6, _omitFieldNames ? '' : 'body')
    ..pPM<GitHubDraft>(7, _omitFieldNames ? '' : 'drafts',
        subBuilder: GitHubDraft.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitGitHubReviewRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitGitHubReviewRequest copyWith(
          void Function(SubmitGitHubReviewRequest) updates) =>
      super.copyWith((message) => updates(message as SubmitGitHubReviewRequest))
          as SubmitGitHubReviewRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SubmitGitHubReviewRequest() / SubmitGitHubReviewRequest.new instead')
  static SubmitGitHubReviewRequest create() => SubmitGitHubReviewRequest._();
  static $pb.GeneratedMessage $_createMessage() =>
      SubmitGitHubReviewRequest._();
  @$core.override
  SubmitGitHubReviewRequest createEmptyInstance() =>
      SubmitGitHubReviewRequest._();
  @$core.pragma('dart2js:noInline')
  static SubmitGitHubReviewRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitGitHubReviewRequest>(
          SubmitGitHubReviewRequest.$_createMessage);
  static SubmitGitHubReviewRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get host => $_getSZ(0);
  @$pb.TagNumber(1)
  set host($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasHost() => $_has(0);
  @$pb.TagNumber(1)
  void clearHost() => $_clearField(1);

  /// The pull request's node id, and the head the drafts are on.
  @$pb.TagNumber(2)
  $core.String get pull => $_getSZ(1);
  @$pb.TagNumber(2)
  set pull($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPull() => $_has(1);
  @$pb.TagNumber(2)
  void clearPull() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get headOid => $_getSZ(2);
  @$pb.TagNumber(3)
  set headOid($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHeadOid() => $_has(2);
  @$pb.TagNumber(3)
  void clearHeadOid() => $_clearField(3);

  /// My review pending on GitHub, if there is one (GitHubPull's).
  @$pb.TagNumber(4)
  $core.String get pendingReview => $_getSZ(3);
  @$pb.TagNumber(4)
  set pendingReview($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPendingReview() => $_has(3);
  @$pb.TagNumber(4)
  void clearPendingReview() => $_clearField(4);

  /// "comment", "approve" or "request_changes".
  @$pb.TagNumber(5)
  $core.String get event => $_getSZ(4);
  @$pb.TagNumber(5)
  set event($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEvent() => $_has(4);
  @$pb.TagNumber(5)
  void clearEvent() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get body => $_getSZ(5);
  @$pb.TagNumber(6)
  set body($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasBody() => $_has(5);
  @$pb.TagNumber(6)
  void clearBody() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<GitHubDraft> get drafts => $_getList(6);
}

class SubmitGitHubReviewResponse extends $pb.GeneratedMessage {
  factory SubmitGitHubReviewResponse() => SubmitGitHubReviewResponse._();

  SubmitGitHubReviewResponse._();

  factory SubmitGitHubReviewResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubmitGitHubReviewResponse()..mergeFromBuffer(data, registry);
  factory SubmitGitHubReviewResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      SubmitGitHubReviewResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitGitHubReviewResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: SubmitGitHubReviewResponse.$_createMessage)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitGitHubReviewResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitGitHubReviewResponse copyWith(
          void Function(SubmitGitHubReviewResponse) updates) =>
      super.copyWith(
              (message) => updates(message as SubmitGitHubReviewResponse))
          as SubmitGitHubReviewResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use SubmitGitHubReviewResponse() / SubmitGitHubReviewResponse.new instead')
  static SubmitGitHubReviewResponse create() => SubmitGitHubReviewResponse._();
  static $pb.GeneratedMessage $_createMessage() =>
      SubmitGitHubReviewResponse._();
  @$core.override
  SubmitGitHubReviewResponse createEmptyInstance() =>
      SubmitGitHubReviewResponse._();
  @$core.pragma('dart2js:noInline')
  static SubmitGitHubReviewResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitGitHubReviewResponse>(
          SubmitGitHubReviewResponse.$_createMessage);
  static SubmitGitHubReviewResponse? _defaultInstance;
}

class GetGitHubPromptRequest extends $pb.GeneratedMessage {
  factory GetGitHubPromptRequest({
    GitHubRef? ref,
    $core.String? kind,
    $core.Iterable<$core.String>? threads,
  }) {
    final result = GetGitHubPromptRequest._();
    if (ref != null) result.ref = ref;
    if (kind != null) result.kind = kind;
    if (threads != null) result.threads.addAll(threads);
    return result;
  }

  GetGitHubPromptRequest._();

  factory GetGitHubPromptRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPromptRequest()..mergeFromBuffer(data, registry);
  factory GetGitHubPromptRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPromptRequest()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubPromptRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubPromptRequest.$_createMessage)
    ..aOM<GitHubRef>(1, _omitFieldNames ? '' : 'ref',
        subBuilder: GitHubRef.$_createMessage)
    ..aOS(2, _omitFieldNames ? '' : 'kind')
    ..pPS(3, _omitFieldNames ? '' : 'threads')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPromptRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPromptRequest copyWith(
          void Function(GetGitHubPromptRequest) updates) =>
      super.copyWith((message) => updates(message as GetGitHubPromptRequest))
          as GetGitHubPromptRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubPromptRequest() / GetGitHubPromptRequest.new instead')
  static GetGitHubPromptRequest create() => GetGitHubPromptRequest._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubPromptRequest._();
  @$core.override
  GetGitHubPromptRequest createEmptyInstance() => GetGitHubPromptRequest._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubPromptRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubPromptRequest>(
          GetGitHubPromptRequest.$_createMessage);
  static GetGitHubPromptRequest? _defaultInstance;

  @$pb.TagNumber(1)
  GitHubRef get ref => $_getN(0);
  @$pb.TagNumber(1)
  set ref(GitHubRef value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasRef() => $_has(0);
  @$pb.TagNumber(1)
  void clearRef() => $_clearField(1);
  @$pb.TagNumber(1)
  GitHubRef ensureRef() => $_ensure(0);

  /// "fix_checks" or "address_comments".
  @$pb.TagNumber(2)
  $core.String get kind => $_getSZ(1);
  @$pb.TagNumber(2)
  set kind($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasKind() => $_has(1);
  @$pb.TagNumber(2)
  void clearKind() => $_clearField(2);

  /// The threads to address (GitHubThread.id); empty for all not resolved.
  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get threads => $_getList(2);
}

class GetGitHubPromptResponse extends $pb.GeneratedMessage {
  factory GetGitHubPromptResponse({
    $core.String? text,
  }) {
    final result = GetGitHubPromptResponse._();
    if (text != null) result.text = text;
    return result;
  }

  GetGitHubPromptResponse._();

  factory GetGitHubPromptResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPromptResponse()..mergeFromBuffer(data, registry);
  factory GetGitHubPromptResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      GetGitHubPromptResponse()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGitHubPromptResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nushi.v1'),
      createEmptyInstance: GetGitHubPromptResponse.$_createMessage)
    ..aOS(1, _omitFieldNames ? '' : 'text')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPromptResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGitHubPromptResponse copyWith(
          void Function(GetGitHubPromptResponse) updates) =>
      super.copyWith((message) => updates(message as GetGitHubPromptResponse))
          as GetGitHubPromptResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  @$core.Deprecated(
      'Use GetGitHubPromptResponse() / GetGitHubPromptResponse.new instead')
  static GetGitHubPromptResponse create() => GetGitHubPromptResponse._();
  static $pb.GeneratedMessage $_createMessage() => GetGitHubPromptResponse._();
  @$core.override
  GetGitHubPromptResponse createEmptyInstance() => GetGitHubPromptResponse._();
  @$core.pragma('dart2js:noInline')
  static GetGitHubPromptResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGitHubPromptResponse>(
          GetGitHubPromptResponse.$_createMessage);
  static GetGitHubPromptResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get text => $_getSZ(0);
  @$pb.TagNumber(1)
  set text($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasText() => $_has(0);
  @$pb.TagNumber(1)
  void clearText() => $_clearField(1);
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

  /// A chat's items before one of them, a page at a time: for a client that
  /// took only the recent part (GetChatRequest.recent), as it scrolls up.
  $async.Future<GetChatItemsResponse> getChatItems(
          $pb.ClientContext? ctx, GetChatItemsRequest request) =>
      _client.invoke<GetChatItemsResponse>(
          ctx, 'NushiService', 'GetChatItems', request, GetChatItemsResponse());

  /// Starts an agent in a folder and opens a chat with it.
  $async.Future<StartChatResponse> startChat(
          $pb.ClientContext? ctx, StartChatRequest request) =>
      _client.invoke<StartChatResponse>(
          ctx, 'NushiService', 'StartChat', request, StartChatResponse());

  /// Lists the agents chats can run, the default first, each as found on
  /// this Mac now: its CLI on the login shell's PATH and its version. Each
  /// CLI is only asked what it is, with file writes and the network denied.
  $async.Future<ListAgentsResponse> listAgents(
          $pb.ClientContext? ctx, ListAgentsRequest request) =>
      _client.invoke<ListAgentsResponse>(
          ctx, 'NushiService', 'ListAgents', request, ListAgentsResponse());

  /// Sets up an agent's adapter (Agent.adapter): installs it into Nushi's
  /// data folder from the lockfile Nushi pins, or updates it to the pinned
  /// version. The agent's awake chats sleep just before the new one
  /// replaces the old. Returns once it's done (5 minutes at most).
  $async.Future<SetUpAgentResponse> setUpAgent(
          $pb.ClientContext? ctx, SetUpAgentRequest request) =>
      _client.invoke<SetUpAgentResponse>(
          ctx, 'NushiService', 'SetUpAgent', request, SetUpAgentResponse());

  /// Removes an agent's adapter; its awake chats sleep first.
  $async.Future<RemoveAgentResponse> removeAgent(
          $pb.ClientContext? ctx, RemoveAgentRequest request) =>
      _client.invoke<RemoveAgentResponse>(
          ctx, 'NushiService', 'RemoveAgent', request, RemoveAgentResponse());

  /// Lists an agent's sessions in a folder that aren't chats (started in a
  /// terminal, say), newest first, a page at a time. It starts the agent to
  /// ask (ACP session/list).
  $async.Future<ListAgentSessionsResponse> listAgentSessions(
          $pb.ClientContext? ctx, ListAgentSessionsRequest request) =>
      _client.invoke<ListAgentSessionsResponse>(ctx, 'NushiService',
          'ListAgentSessions', request, ListAgentSessionsResponse());

  /// Opens one of them as a chat in the folder: the agent replays it
  /// (session/load); nothing is copied. For a session that is a chat
  /// already, that chat.
  $async.Future<OpenAgentSessionResponse> openAgentSession(
          $pb.ClientContext? ctx, OpenAgentSessionRequest request) =>
      _client.invoke<OpenAgentSessionResponse>(ctx, 'NushiService',
          'OpenAgentSession', request, OpenAgentSessionResponse());

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

  /// Renames the branch of a chat's worktree (git branch -m; its folder
  /// stays), for good: the chat's title no longer names it. Refused during a
  /// turn, for a name git doesn't take or that's taken, and when the branch
  /// is on a remote or another worktree or chat has it. (API 68)
  $async.Future<RenameBranchResponse> renameBranch(
          $pb.ClientContext? ctx, RenameBranchRequest request) =>
      _client.invoke<RenameBranchResponse>(
          ctx, 'NushiService', 'RenameBranch', request, RenameBranchResponse());

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

  /// Says a chat is shown (selected, the app came to the front), or Try
  /// again: a chat whose agent should run but doesn't is reopened, as
  /// GetChat does, and one whose last reopen failed (status.reopen_failed)
  /// tries again, once a call, unless what stopped it still holds (its
  /// folder is gone, its agent isn't ready). A sleeping chat stays asleep.
  $async.Future<ReopenChatResponse> reopenChat(
          $pb.ClientContext? ctx, ReopenChatRequest request) =>
      _client.invoke<ReopenChatResponse>(
          ctx, 'NushiService', 'ReopenChat', request, ReopenChatResponse());

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

  /// Nushi's copies of chats' transcripts (ADR 0047): each one's size and
  /// whose it is, largest first.
  $async.Future<ListTranscriptsResponse> listTranscripts(
          $pb.ClientContext? ctx, ListTranscriptsRequest request) =>
      _client.invoke<ListTranscriptsResponse>(ctx, 'NushiService',
          'ListTranscripts', request, ListTranscriptsResponse());

  /// Deletes copies of transcripts: a chat goes on, its history from its
  /// agent alone; one kept only for its copy (its agent deleted its
  /// session) goes unless its work keeps it.
  $async.Future<ClearTranscriptsResponse> clearTranscripts(
          $pb.ClientContext? ctx, ClearTranscriptsRequest request) =>
      _client.invoke<ClearTranscriptsResponse>(ctx, 'NushiService',
          'ClearTranscripts', request, ClearTranscriptsResponse());

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

  /// Takes chats off ListChatsResponse.removed (the app has said so).
  $async.Future<DismissRemovedChatsResponse> dismissRemovedChats(
          $pb.ClientContext? ctx, DismissRemovedChatsRequest request) =>
      _client.invoke<DismissRemovedChatsResponse>(ctx, 'NushiService',
          'DismissRemovedChats', request, DismissRemovedChatsResponse());

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

  /// Reads one of a folder's files as it is now, as a change that changes
  /// nothing (status "unchanged", the text on both sides): a file a review
  /// names that isn't among the changes. Only a regular file inside the
  /// folder: no "..", no link.
  $async.Future<GetFileResponse> getFile(
          $pb.ClientContext? ctx, GetFileRequest request) =>
      _client.invoke<GetFileResponse>(
          ctx, 'NushiService', 'GetFile', request, GetFileResponse());

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

  /// Turns a server on or off for the folder's project (API 65: by scope).
  /// A project's .mcp.json server: on approves it, off rejects it (Claude's
  /// enabledMcpjsonServers and disabledMcpjsonServers in the project's
  /// .claude/settings.local.json). A user or local server: as /mcp in a
  /// terminal does, which Claude records in ~/.claude.json, asked of Claude
  /// (ADR 0050). Refused for a plugin's server and a claude.ai connector.
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

  /// The skills (and plugins) an agent uses in a folder (API 66, ADR 0051;
  /// every agent's from API 67, ADR 0052): read from the agent's files (and
  /// Claude's `claude plugin list --json`), never run in the folder; shared
  /// skills (.agents/skills) with every agent that loads each. Skills'
  /// descriptions and plugins' text are their authors'.
  $async.Future<ListSkillsResponse> listSkills(
          $pb.ClientContext? ctx, ListSkillsRequest request) =>
      _client.invoke<ListSkillsResponse>(
          ctx, 'NushiService', 'ListSkills', request, ListSkillsResponse());

  /// Turns a skill on or off: yours in your settings, a project's in the
  /// project's local settings (skillOverrides, only that key); "builtin"
  /// turns Claude's built-in skills on or off together, in your settings
  /// (disableBundledSkills). A plugin's skills go with their plugin.
  $async.Future<SetSkillOnResponse> setSkillOn(
          $pb.ClientContext? ctx, SetSkillOnRequest request) =>
      _client.invoke<SetSkillOnResponse>(
          ctx, 'NushiService', 'SetSkillOn', request, SetSkillOnResponse());

  /// Turns an installed plugin on or off where Plugin.switch_scope says:
  /// for you through `claude plugin enable`/`disable` (run in Claude's config
  /// folder, never the project's), for the project by its enabledPlugins
  /// entry in the project's local settings.
  $async.Future<SetPluginOnResponse> setPluginOn(
          $pb.ClientContext? ctx, SetPluginOnRequest request) =>
      _client.invoke<SetPluginOnResponse>(
          ctx, 'NushiService', 'SetPluginOn', request, SetPluginOnResponse());

  /// Uninstalls a plugin installed for you (`claude plugin uninstall`);
  /// refused for one installed for a project.
  $async.Future<UninstallPluginResponse> uninstallPlugin(
          $pb.ClientContext? ctx, UninstallPluginRequest request) =>
      _client.invoke<UninstallPluginResponse>(ctx, 'NushiService',
          'UninstallPlugin', request, UninstallPluginResponse());

  /// Moves a skill's folder (yours or the project's, as listed) to the
  /// Trash.
  $async.Future<TrashSkillResponse> trashSkill(
          $pb.ClientContext? ctx, TrashSkillRequest request) =>
      _client.invoke<TrashSkillResponse>(
          ctx, 'NushiService', 'TrashSkill', request, TrashSkillResponse());

  /// Gives an agent a shared skill it doesn't read by a relative link of
  /// its own (Claude's .claude/skills/<name> → ../../.agents/skills/<name>):
  /// only a shared skill listed for the folder; nothing replaced.
  $async.Future<LinkSkillResponse> linkSkill(
          $pb.ClientContext? ctx, LinkSkillRequest request) =>
      _client.invoke<LinkSkillResponse>(
          ctx, 'NushiService', 'LinkSkill', request, LinkSkillResponse());

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

  /// Web Push (ADR 0054). The daemon's VAPID public key, for a device's
  /// pushManager.subscribe.
  $async.Future<GetPushKeyResponse> getPushKey(
          $pb.ClientContext? ctx, GetPushKeyRequest request) =>
      _client.invoke<GetPushKeyResponse>(
          ctx, 'NushiService', 'GetPushKey', request, GetPushKeyResponse());

  /// A paired device's own push subscription (an empty endpoint: none);
  /// only on a device's channel. The endpoint must be a known push service.
  $async.Future<SetPushSubscriptionResponse> setPushSubscription(
          $pb.ClientContext? ctx, SetPushSubscriptionRequest request) =>
      _client.invoke<SetPushSubscriptionResponse>(ctx, 'NushiService',
          'SetPushSubscription', request, SetPushSubscriptionResponse());

  /// The chat a paired device shows ("" none): no push for that chat goes
  /// to it while it's connected. Only on a device's channel.
  $async.Future<SetDeviceViewResponse> setDeviceView(
          $pb.ClientContext? ctx, SetDeviceViewRequest request) =>
      _client.invoke<SetDeviceViewResponse>(ctx, 'NushiService',
          'SetDeviceView', request, SetDeviceViewResponse());

  /// Sends a test notification to a device (the Mac's).
  $async.Future<SendTestPushResponse> sendTestPush(
          $pb.ClientContext? ctx, SendTestPushRequest request) =>
      _client.invoke<SendTestPushResponse>(
          ctx, 'NushiService', 'SendTestPush', request, SendTestPushResponse());

  /// Unpairs the device that calls (its Forget this Mac), as Revoke would;
  /// only on a device's channel.
  $async.Future<UnpairThisDeviceResponse> unpairThisDevice(
          $pb.ClientContext? ctx, UnpairThisDeviceRequest request) =>
      _client.invoke<UnpairThisDeviceResponse>(ctx, 'NushiService',
          'UnpairThisDevice', request, UnpairThisDeviceResponse());

  /// Writes a line of the app's into the daemon's log (source=app): its
  /// errors with their stacks, and what helps afterwards.
  $async.Future<LogResponse> log($pb.ClientContext? ctx, LogRequest request) =>
      _client.invoke<LogResponse>(
          ctx, 'NushiService', 'Log', request, LogResponse());

  /// Jira (ADR 0042): the sites added, their tokens in the keychain. Every
  /// call that reaches Jira is one the user made; nothing polls or writes on
  /// its own.
  $async.Future<ListJiraSitesResponse> listJiraSites(
          $pb.ClientContext? ctx, ListJiraSitesRequest request) =>
      _client.invoke<ListJiraSitesResponse>(ctx, 'NushiService',
          'ListJiraSites', request, ListJiraSitesResponse());

  /// Checks a token on a site (classic or scoped) and keeps it: the token
  /// in the keychain, the site in the list.
  $async.Future<AddJiraSiteResponse> addJiraSite(
          $pb.ClientContext? ctx, AddJiraSiteRequest request) =>
      _client.invoke<AddJiraSiteResponse>(
          ctx, 'NushiService', 'AddJiraSite', request, AddJiraSiteResponse());

  /// Forgets a site and deletes its token from the keychain.
  $async.Future<RemoveJiraSiteResponse> removeJiraSite(
          $pb.ClientContext? ctx, RemoveJiraSiteRequest request) =>
      _client.invoke<RemoveJiraSiteResponse>(ctx, 'NushiService',
          'RemoveJiraSite', request, RemoveJiraSiteResponse());

  /// Asks Jira who a site's token is, to see it still works.
  $async.Future<CheckJiraSiteResponse> checkJiraSite(
          $pb.ClientContext? ctx, CheckJiraSiteRequest request) =>
      _client.invoke<CheckJiraSiteResponse>(ctx, 'NushiService',
          'CheckJiraSite', request, CheckJiraSiteResponse());

  /// Reads a site's token with macOS's prompt, which asks to let this
  /// build of Nushi read it (JiraSite.needs_ok).
  $async.Future<AllowJiraTokenResponse> allowJiraToken(
          $pb.ClientContext? ctx, AllowJiraTokenRequest request) =>
      _client.invoke<AllowJiraTokenResponse>(ctx, 'NushiService',
          'AllowJiraToken', request, AllowJiraTokenResponse());

  /// The board whose active sprint is the sprint list, and saved searches.
  $async.Future<ListJiraBoardsResponse> listJiraBoards(
          $pb.ClientContext? ctx, ListJiraBoardsRequest request) =>
      _client.invoke<ListJiraBoardsResponse>(ctx, 'NushiService',
          'ListJiraBoards', request, ListJiraBoardsResponse());
  $async.Future<SetJiraBoardResponse> setJiraBoard(
          $pb.ClientContext? ctx, SetJiraBoardRequest request) =>
      _client.invoke<SetJiraBoardResponse>(
          ctx, 'NushiService', 'SetJiraBoard', request, SetJiraBoardResponse());
  $async.Future<SetJiraSearchesResponse> setJiraSearches(
          $pb.ClientContext? ctx, SetJiraSearchesRequest request) =>
      _client.invoke<SetJiraSearchesResponse>(ctx, 'NushiService',
          'SetJiraSearches', request, SetJiraSearchesResponse());

  /// A list's issues: "mine", "sprint", or a JQL search.
  $async.Future<ListJiraIssuesResponse> listJiraIssues(
          $pb.ClientContext? ctx, ListJiraIssuesRequest request) =>
      _client.invoke<ListJiraIssuesResponse>(ctx, 'NushiService',
          'ListJiraIssues', request, ListJiraIssuesResponse());

  /// What the JQL field autocompletes from, and a field's values.
  $async.Future<GetJiraJqlResponse> getJiraJql(
          $pb.ClientContext? ctx, GetJiraJqlRequest request) =>
      _client.invoke<GetJiraJqlResponse>(
          ctx, 'NushiService', 'GetJiraJql', request, GetJiraJqlResponse());
  $async.Future<SuggestJiraJqlResponse> suggestJiraJql(
          $pb.ClientContext? ctx, SuggestJiraJqlRequest request) =>
      _client.invoke<SuggestJiraJqlResponse>(ctx, 'NushiService',
          'SuggestJiraJql', request, SuggestJiraJqlResponse());

  /// An issue whole, text as Markdown.
  $async.Future<GetJiraIssueResponse> getJiraIssue(
          $pb.ClientContext? ctx, GetJiraIssueRequest request) =>
      _client.invoke<GetJiraIssueResponse>(
          ctx, 'NushiService', 'GetJiraIssue', request, GetJiraIssueResponse());
  $async.Future<ListJiraTransitionsResponse> listJiraTransitions(
          $pb.ClientContext? ctx, ListJiraTransitionsRequest request) =>
      _client.invoke<ListJiraTransitionsResponse>(ctx, 'NushiService',
          'ListJiraTransitions', request, ListJiraTransitionsResponse());
  $async.Future<TransitionJiraIssueResponse> transitionJiraIssue(
          $pb.ClientContext? ctx, TransitionJiraIssueRequest request) =>
      _client.invoke<TransitionJiraIssueResponse>(ctx, 'NushiService',
          'TransitionJiraIssue', request, TransitionJiraIssueResponse());

  /// Posts a comment written in Markdown.
  $async.Future<AddJiraCommentResponse> addJiraComment(
          $pb.ClientContext? ctx, AddJiraCommentRequest request) =>
      _client.invoke<AddJiraCommentResponse>(ctx, 'NushiService',
          'AddJiraComment', request, AddJiraCommentResponse());

  /// An issue for a new chat: from its link, its key, or words of it.
  $async.Future<FindJiraIssuesResponse> findJiraIssues(
          $pb.ClientContext? ctx, FindJiraIssuesRequest request) =>
      _client.invoke<FindJiraIssuesResponse>(ctx, 'NushiService',
          'FindJiraIssues', request, FindJiraIssuesResponse());

  /// An attachment's file or thumbnail (20 MB at most).
  $async.Future<GetJiraAttachmentResponse> getJiraAttachment(
          $pb.ClientContext? ctx, GetJiraAttachmentRequest request) =>
      _client.invoke<GetJiraAttachmentResponse>(ctx, 'NushiService',
          'GetJiraAttachment', request, GetJiraAttachmentResponse());

  /// GitHub (ADR 0045): the hosts gh is signed in to (its token read by the
  /// daemon through go-gh) and those given a pasted token (the keychain).
  /// Nothing reaches GitHub on its own: the app asks, and marks the asking
  /// on its timers quiet, which a rate limit running low holds back.
  $async.Future<ListGitHubHostsResponse> listGitHubHosts(
          $pb.ClientContext? ctx, ListGitHubHostsRequest request) =>
      _client.invoke<ListGitHubHostsResponse>(ctx, 'NushiService',
          'ListGitHubHosts', request, ListGitHubHostsResponse());

  /// Checks a pasted token on a host and keeps it in the keychain; it's
  /// used for the host instead of gh's login until removed.
  $async.Future<AddGitHubTokenResponse> addGitHubToken(
          $pb.ClientContext? ctx, AddGitHubTokenRequest request) =>
      _client.invoke<AddGitHubTokenResponse>(ctx, 'NushiService',
          'AddGitHubToken', request, AddGitHubTokenResponse());
  $async.Future<RemoveGitHubTokenResponse> removeGitHubToken(
          $pb.ClientContext? ctx, RemoveGitHubTokenRequest request) =>
      _client.invoke<RemoveGitHubTokenResponse>(ctx, 'NushiService',
          'RemoveGitHubToken', request, RemoveGitHubTokenResponse());

  /// Reads a host's pasted token with macOS's prompt (GitHubHost.needs_ok).
  $async.Future<AllowGitHubTokenResponse> allowGitHubToken(
          $pb.ClientContext? ctx, AllowGitHubTokenRequest request) =>
      _client.invoke<AllowGitHubTokenResponse>(ctx, 'NushiService',
          'AllowGitHubToken', request, AllowGitHubTokenResponse());

  /// The GitHub repositories folders are clones of: the folders asked
  /// about and the chats'.
  $async.Future<ListGitHubReposResponse> listGitHubRepos(
          $pb.ClientContext? ctx, ListGitHubReposRequest request) =>
      _client.invoke<ListGitHubReposResponse>(ctx, 'NushiService',
          'ListGitHubRepos', request, ListGitHubReposResponse());

  /// Review requested of me or my teams, my pull requests, issues assigned
  /// to me: the latest 50 each.
  $async.Future<ListGitHubInboxResponse> listGitHubInbox(
          $pb.ClientContext? ctx, ListGitHubInboxRequest request) =>
      _client.invoke<ListGitHubInboxResponse>(ctx, 'NushiService',
          'ListGitHubInbox', request, ListGitHubInboxResponse());

  /// Items as they are now, by node id (a chat's status chip).
  $async.Future<GetGitHubStatesResponse> getGitHubStates(
          $pb.ClientContext? ctx, GetGitHubStatesRequest request) =>
      _client.invoke<GetGitHubStatesResponse>(ctx, 'NushiService',
          'GetGitHubStates', request, GetGitHubStatesResponse());
  $async.Future<GetGitHubPullResponse> getGitHubPull(
          $pb.ClientContext? ctx, GetGitHubPullRequest request) =>
      _client.invoke<GetGitHubPullResponse>(ctx, 'NushiService',
          'GetGitHubPull', request, GetGitHubPullResponse());
  $async.Future<GetGitHubIssueResponse> getGitHubIssue(
          $pb.ClientContext? ctx, GetGitHubIssueRequest request) =>
      _client.invoke<GetGitHubIssueResponse>(ctx, 'NushiService',
          'GetGitHubIssue', request, GetGitHubIssueResponse());

  /// A pull request's files from its merge base to its head, both sides'
  /// texts, as GetDiff gives them.
  $async.Future<GetGitHubFilesResponse> getGitHubFiles(
          $pb.ClientContext? ctx, GetGitHubFilesRequest request) =>
      _client.invoke<GetGitHubFilesResponse>(ctx, 'NushiService',
          'GetGitHubFiles', request, GetGitHubFilesResponse());

  /// The end of a failed Actions job's log (16 KB).
  $async.Future<GetGitHubJobLogResponse> getGitHubJobLog(
          $pb.ClientContext? ctx, GetGitHubJobLogRequest request) =>
      _client.invoke<GetGitHubJobLogResponse>(ctx, 'NushiService',
          'GetGitHubJobLog', request, GetGitHubJobLogResponse());

  /// A message for a chat's agent, for the box (never sent by Nushi):
  /// "fix_checks" (the failed checks with their logs' ends) or
  /// "address_comments" (the threads named, else all not resolved), GitHub's
  /// text in it marked as data.
  $async.Future<GetGitHubPromptResponse> getGitHubPrompt(
          $pb.ClientContext? ctx, GetGitHubPromptRequest request) =>
      _client.invoke<GetGitHubPromptResponse>(ctx, 'NushiService',
          'GetGitHubPrompt', request, GetGitHubPromptResponse());

  /// The user's writes.
  $async.Future<ReplyGitHubThreadResponse> replyGitHubThread(
          $pb.ClientContext? ctx, ReplyGitHubThreadRequest request) =>
      _client.invoke<ReplyGitHubThreadResponse>(ctx, 'NushiService',
          'ReplyGitHubThread', request, ReplyGitHubThreadResponse());
  $async.Future<ResolveGitHubThreadResponse> resolveGitHubThread(
          $pb.ClientContext? ctx, ResolveGitHubThreadRequest request) =>
      _client.invoke<ResolveGitHubThreadResponse>(ctx, 'NushiService',
          'ResolveGitHubThread', request, ResolveGitHubThreadResponse());
  $async.Future<AddGitHubCommentResponse> addGitHubComment(
          $pb.ClientContext? ctx, AddGitHubCommentRequest request) =>
      _client.invoke<AddGitHubCommentResponse>(ctx, 'NushiService',
          'AddGitHubComment', request, AddGitHubCommentResponse());
  $async.Future<SubmitGitHubReviewResponse> submitGitHubReview(
          $pb.ClientContext? ctx, SubmitGitHubReviewRequest request) =>
      _client.invoke<SubmitGitHubReviewResponse>(ctx, 'NushiService',
          'SubmitGitHubReview', request, SubmitGitHubReviewResponse());

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
