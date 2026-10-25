// This is a generated file - do not edit.
//
// Generated from nushi/v1/nushi.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use itemKindDescriptor instead')
const ItemKind$json = {
  '1': 'ItemKind',
  '2': [
    {'1': 'ITEM_KIND_UNSPECIFIED', '2': 0},
    {'1': 'ITEM_KIND_USER_MESSAGE', '2': 1},
    {'1': 'ITEM_KIND_AGENT_MESSAGE', '2': 2},
    {'1': 'ITEM_KIND_TOOL_CALL', '2': 3},
    {'1': 'ITEM_KIND_PERMISSION', '2': 4},
    {'1': 'ITEM_KIND_QUESTION', '2': 5},
    {'1': 'ITEM_KIND_THOUGHT', '2': 6},
    {'1': 'ITEM_KIND_PLAN', '2': 7},
    {'1': 'ITEM_KIND_NOTICE', '2': 8},
  ],
};

/// Descriptor for `ItemKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List itemKindDescriptor = $convert.base64Decode(
    'CghJdGVtS2luZBIZChVJVEVNX0tJTkRfVU5TUEVDSUZJRUQQABIaChZJVEVNX0tJTkRfVVNFUl'
    '9NRVNTQUdFEAESGwoXSVRFTV9LSU5EX0FHRU5UX01FU1NBR0UQAhIXChNJVEVNX0tJTkRfVE9P'
    'TF9DQUxMEAMSGAoUSVRFTV9LSU5EX1BFUk1JU1NJT04QBBIWChJJVEVNX0tJTkRfUVVFU1RJT0'
    '4QBRIVChFJVEVNX0tJTkRfVEhPVUdIVBAGEhIKDklURU1fS0lORF9QTEFOEAcSFAoQSVRFTV9L'
    'SU5EX05PVElDRRAI');

@$core.Deprecated('Use fieldTypeDescriptor instead')
const FieldType$json = {
  '1': 'FieldType',
  '2': [
    {'1': 'FIELD_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'FIELD_TYPE_TEXT', '2': 1},
    {'1': 'FIELD_TYPE_CHOICE', '2': 2},
    {'1': 'FIELD_TYPE_CHOICES', '2': 3},
    {'1': 'FIELD_TYPE_NUMBER', '2': 4},
    {'1': 'FIELD_TYPE_INTEGER', '2': 5},
    {'1': 'FIELD_TYPE_BOOLEAN', '2': 6},
  ],
};

/// Descriptor for `FieldType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List fieldTypeDescriptor = $convert.base64Decode(
    'CglGaWVsZFR5cGUSGgoWRklFTERfVFlQRV9VTlNQRUNJRklFRBAAEhMKD0ZJRUxEX1RZUEVfVE'
    'VYVBABEhUKEUZJRUxEX1RZUEVfQ0hPSUNFEAISFgoSRklFTERfVFlQRV9DSE9JQ0VTEAMSFQoR'
    'RklFTERfVFlQRV9OVU1CRVIQBBIWChJGSUVMRF9UWVBFX0lOVEVHRVIQBRIWChJGSUVMRF9UWV'
    'BFX0JPT0xFQU4QBg==');

@$core.Deprecated('Use pingRequestDescriptor instead')
const PingRequest$json = {
  '1': 'PingRequest',
};

/// Descriptor for `PingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingRequestDescriptor =
    $convert.base64Decode('CgtQaW5nUmVxdWVzdA==');

@$core.Deprecated('Use pingResponseDescriptor instead')
const PingResponse$json = {
  '1': 'PingResponse',
  '2': [
    {'1': 'api_version', '3': 1, '4': 1, '5': 5, '10': 'apiVersion'},
    {'1': 'build', '3': 2, '4': 1, '5': 9, '10': 'build'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USHwoLYXBpX3ZlcnNpb24YASABKAVSCmFwaVZlcnNpb24SFAoFYnVpbG'
    'QYAiABKAlSBWJ1aWxk');

@$core.Deprecated('Use listChatsRequestDescriptor instead')
const ListChatsRequest$json = {
  '1': 'ListChatsRequest',
};

/// Descriptor for `ListChatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChatsRequestDescriptor =
    $convert.base64Decode('ChBMaXN0Q2hhdHNSZXF1ZXN0');

@$core.Deprecated('Use listChatsResponseDescriptor instead')
const ListChatsResponse$json = {
  '1': 'ListChatsResponse',
  '2': [
    {
      '1': 'chats',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Chat',
      '10': 'chats'
    },
  ],
};

/// Descriptor for `ListChatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChatsResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0Q2hhdHNSZXNwb25zZRIkCgVjaGF0cxgBIAMoCzIOLm51c2hpLnYxLkNoYXRSBWNoYX'
    'Rz');

@$core.Deprecated('Use chatDescriptor instead')
const Chat$json = {
  '1': 'Chat',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'agent', '3': 2, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'folder', '3': 3, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'mode', '3': 5, '4': 1, '5': 9, '10': 'mode'},
    {'1': 'created_unix_ms', '3': 6, '4': 1, '5': 3, '10': 'createdUnixMs'},
    {
      '1': 'status',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatStatus',
      '10': 'status'
    },
    {'1': 'archived', '3': 8, '4': 1, '5': 8, '10': 'archived'},
    {'1': 'session_id', '3': 9, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'worktree',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Worktree',
      '10': 'worktree'
    },
    {'1': 'scratch', '3': 11, '4': 1, '5': 8, '10': 'scratch'},
    {'1': 'jira_site', '3': 12, '4': 1, '5': 9, '10': 'jiraSite'},
    {'1': 'jira_key', '3': 13, '4': 1, '5': 9, '10': 'jiraKey'},
  ],
};

/// Descriptor for `Chat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatDescriptor = $convert.base64Decode(
    'CgRDaGF0Eg4KAmlkGAEgASgJUgJpZBIUCgVhZ2VudBgCIAEoCVIFYWdlbnQSFgoGZm9sZGVyGA'
    'MgASgJUgZmb2xkZXISFAoFdGl0bGUYBCABKAlSBXRpdGxlEhIKBG1vZGUYBSABKAlSBG1vZGUS'
    'JgoPY3JlYXRlZF91bml4X21zGAYgASgDUg1jcmVhdGVkVW5peE1zEiwKBnN0YXR1cxgHIAEoCz'
    'IULm51c2hpLnYxLkNoYXRTdGF0dXNSBnN0YXR1cxIaCghhcmNoaXZlZBgIIAEoCFIIYXJjaGl2'
    'ZWQSHQoKc2Vzc2lvbl9pZBgJIAEoCVIJc2Vzc2lvbklkEi4KCHdvcmt0cmVlGAogASgLMhIubn'
    'VzaGkudjEuV29ya3RyZWVSCHdvcmt0cmVlEhgKB3NjcmF0Y2gYCyABKAhSB3NjcmF0Y2gSGwoJ'
    'amlyYV9zaXRlGAwgASgJUghqaXJhU2l0ZRIZCghqaXJhX2tleRgNIAEoCVIHamlyYUtleQ==');

@$core.Deprecated('Use worktreeDescriptor instead')
const Worktree$json = {
  '1': 'Worktree',
  '2': [
    {'1': 'repo', '3': 1, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'base', '3': 4, '4': 1, '5': 9, '10': 'base'},
    {'1': 'base_commit', '3': 5, '4': 1, '5': 9, '10': 'baseCommit'},
  ],
};

/// Descriptor for `Worktree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeDescriptor = $convert.base64Decode(
    'CghXb3JrdHJlZRISCgRyZXBvGAEgASgJUgRyZXBvEhIKBHBhdGgYAiABKAlSBHBhdGgSFgoGYn'
    'JhbmNoGAMgASgJUgZicmFuY2gSEgoEYmFzZRgEIAEoCVIEYmFzZRIfCgtiYXNlX2NvbW1pdBgF'
    'IAEoCVIKYmFzZUNvbW1pdA==');

@$core.Deprecated('Use getChatRequestDescriptor instead')
const GetChatRequest$json = {
  '1': 'GetChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `GetChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatRequestDescriptor = $convert
    .base64Decode('Cg5HZXRDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use getChatResponseDescriptor instead')
const GetChatResponse$json = {
  '1': 'GetChatResponse',
  '2': [
    {'1': 'chat', '3': 1, '4': 1, '5': 11, '6': '.nushi.v1.Chat', '10': 'chat'},
    {
      '1': 'items',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Item',
      '10': 'items'
    },
    {
      '1': 'config',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ConfigOption',
      '10': 'config'
    },
    {
      '1': 'status',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatStatus',
      '10': 'status'
    },
    {'1': 'seq', '3': 5, '4': 1, '5': 3, '10': 'seq'},
    {
      '1': 'commands',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Command',
      '10': 'commands'
    },
    {
      '1': 'usage',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Usage',
      '10': 'usage'
    },
    {
      '1': 'queue',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatQueue',
      '10': 'queue'
    },
  ],
};

/// Descriptor for `GetChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRDaGF0UmVzcG9uc2USIgoEY2hhdBgBIAEoCzIOLm51c2hpLnYxLkNoYXRSBGNoYXQSJA'
    'oFaXRlbXMYAiADKAsyDi5udXNoaS52MS5JdGVtUgVpdGVtcxIuCgZjb25maWcYAyADKAsyFi5u'
    'dXNoaS52MS5Db25maWdPcHRpb25SBmNvbmZpZxIsCgZzdGF0dXMYBCABKAsyFC5udXNoaS52MS'
    '5DaGF0U3RhdHVzUgZzdGF0dXMSEAoDc2VxGAUgASgDUgNzZXESLQoIY29tbWFuZHMYBiADKAsy'
    'ES5udXNoaS52MS5Db21tYW5kUghjb21tYW5kcxIlCgV1c2FnZRgHIAEoCzIPLm51c2hpLnYxLl'
    'VzYWdlUgV1c2FnZRIpCgVxdWV1ZRgIIAEoCzITLm51c2hpLnYxLkNoYXRRdWV1ZVIFcXVldWU=');

@$core.Deprecated('Use usageDescriptor instead')
const Usage$json = {
  '1': 'Usage',
  '2': [
    {'1': 'context_used', '3': 1, '4': 1, '5': 3, '10': 'contextUsed'},
    {'1': 'context_size', '3': 2, '4': 1, '5': 3, '10': 'contextSize'},
    {'1': 'cost', '3': 3, '4': 1, '5': 1, '10': 'cost'},
    {'1': 'currency', '3': 4, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'input_tokens', '3': 5, '4': 1, '5': 3, '10': 'inputTokens'},
    {'1': 'output_tokens', '3': 6, '4': 1, '5': 3, '10': 'outputTokens'},
    {
      '1': 'cached_read_tokens',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'cachedReadTokens'
    },
    {
      '1': 'cached_write_tokens',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'cachedWriteTokens'
    },
  ],
};

/// Descriptor for `Usage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usageDescriptor = $convert.base64Decode(
    'CgVVc2FnZRIhCgxjb250ZXh0X3VzZWQYASABKANSC2NvbnRleHRVc2VkEiEKDGNvbnRleHRfc2'
    'l6ZRgCIAEoA1ILY29udGV4dFNpemUSEgoEY29zdBgDIAEoAVIEY29zdBIaCghjdXJyZW5jeRgE'
    'IAEoCVIIY3VycmVuY3kSIQoMaW5wdXRfdG9rZW5zGAUgASgDUgtpbnB1dFRva2VucxIjCg1vdX'
    'RwdXRfdG9rZW5zGAYgASgDUgxvdXRwdXRUb2tlbnMSLAoSY2FjaGVkX3JlYWRfdG9rZW5zGAcg'
    'ASgDUhBjYWNoZWRSZWFkVG9rZW5zEi4KE2NhY2hlZF93cml0ZV90b2tlbnMYCCABKANSEWNhY2'
    'hlZFdyaXRlVG9rZW5z');

@$core.Deprecated('Use commandDescriptor instead')
const Command$json = {
  '1': 'Command',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'hint', '3': 3, '4': 1, '5': 9, '10': 'hint'},
  ],
};

/// Descriptor for `Command`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commandDescriptor = $convert.base64Decode(
    'CgdDb21tYW5kEhIKBG5hbWUYASABKAlSBG5hbWUSIAoLZGVzY3JpcHRpb24YAiABKAlSC2Rlc2'
    'NyaXB0aW9uEhIKBGhpbnQYAyABKAlSBGhpbnQ=');

@$core.Deprecated('Use chatCommandsDescriptor instead')
const ChatCommands$json = {
  '1': 'ChatCommands',
  '2': [
    {
      '1': 'commands',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Command',
      '10': 'commands'
    },
  ],
};

/// Descriptor for `ChatCommands`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatCommandsDescriptor = $convert.base64Decode(
    'CgxDaGF0Q29tbWFuZHMSLQoIY29tbWFuZHMYASADKAsyES5udXNoaS52MS5Db21tYW5kUghjb2'
    '1tYW5kcw==');

@$core.Deprecated('Use listAgentsRequestDescriptor instead')
const ListAgentsRequest$json = {
  '1': 'ListAgentsRequest',
};

/// Descriptor for `ListAgentsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAgentsRequestDescriptor =
    $convert.base64Decode('ChFMaXN0QWdlbnRzUmVxdWVzdA==');

@$core.Deprecated('Use listAgentsResponseDescriptor instead')
const ListAgentsResponse$json = {
  '1': 'ListAgentsResponse',
  '2': [
    {
      '1': 'agents',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Agent',
      '10': 'agents'
    },
  ],
};

/// Descriptor for `ListAgentsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAgentsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0QWdlbnRzUmVzcG9uc2USJwoGYWdlbnRzGAEgAygLMg8ubnVzaGkudjEuQWdlbnRSBm'
    'FnZW50cw==');

@$core.Deprecated('Use agentDescriptor instead')
const Agent$json = {
  '1': 'Agent',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'resume', '3': 3, '4': 1, '5': 9, '10': 'resume'},
    {'1': 'mcp', '3': 4, '4': 1, '5': 8, '10': 'mcp'},
    {'1': 'delete_archives', '3': 5, '4': 1, '5': 8, '10': 'deleteArchives'},
    {'1': 'path', '3': 6, '4': 1, '5': 9, '10': 'path'},
    {'1': 'version', '3': 7, '4': 1, '5': 9, '10': 'version'},
    {'1': 'page', '3': 8, '4': 1, '5': 9, '10': 'page'},
    {'1': 'problem', '3': 9, '4': 1, '5': 9, '10': 'problem'},
    {'1': 'signed_in', '3': 10, '4': 1, '5': 9, '10': 'signedIn'},
    {
      '1': 'adapter',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Adapter',
      '10': 'adapter'
    },
    {'1': 'ready', '3': 12, '4': 1, '5': 8, '10': 'ready'},
    {'1': 'awake', '3': 13, '4': 1, '5': 5, '10': 'awake'},
  ],
};

/// Descriptor for `Agent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentDescriptor = $convert.base64Decode(
    'CgVBZ2VudBISCgRuYW1lGAEgASgJUgRuYW1lEhQKBXRpdGxlGAIgASgJUgV0aXRsZRIWCgZyZX'
    'N1bWUYAyABKAlSBnJlc3VtZRIQCgNtY3AYBCABKAhSA21jcBInCg9kZWxldGVfYXJjaGl2ZXMY'
    'BSABKAhSDmRlbGV0ZUFyY2hpdmVzEhIKBHBhdGgYBiABKAlSBHBhdGgSGAoHdmVyc2lvbhgHIA'
    'EoCVIHdmVyc2lvbhISCgRwYWdlGAggASgJUgRwYWdlEhgKB3Byb2JsZW0YCSABKAlSB3Byb2Js'
    'ZW0SGwoJc2lnbmVkX2luGAogASgJUghzaWduZWRJbhIrCgdhZGFwdGVyGAsgASgLMhEubnVzaG'
    'kudjEuQWRhcHRlclIHYWRhcHRlchIUCgVyZWFkeRgMIAEoCFIFcmVhZHkSFAoFYXdha2UYDSAB'
    'KAVSBWF3YWtl');

@$core.Deprecated('Use adapterDescriptor instead')
const Adapter$json = {
  '1': 'Adapter',
  '2': [
    {'1': 'package', '3': 1, '4': 1, '5': 9, '10': 'package'},
    {'1': 'pinned', '3': 2, '4': 1, '5': 9, '10': 'pinned'},
    {'1': 'installed', '3': 3, '4': 1, '5': 9, '10': 'installed'},
    {'1': 'packages', '3': 4, '4': 1, '5': 5, '10': 'packages'},
    {'1': 'download_bytes', '3': 5, '4': 1, '5': 3, '10': 'downloadBytes'},
    {'1': 'disk_bytes', '3': 6, '4': 1, '5': 3, '10': 'diskBytes'},
    {'1': 'folder', '3': 7, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `Adapter`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adapterDescriptor = $convert.base64Decode(
    'CgdBZGFwdGVyEhgKB3BhY2thZ2UYASABKAlSB3BhY2thZ2USFgoGcGlubmVkGAIgASgJUgZwaW'
    '5uZWQSHAoJaW5zdGFsbGVkGAMgASgJUglpbnN0YWxsZWQSGgoIcGFja2FnZXMYBCABKAVSCHBh'
    'Y2thZ2VzEiUKDmRvd25sb2FkX2J5dGVzGAUgASgDUg1kb3dubG9hZEJ5dGVzEh0KCmRpc2tfYn'
    'l0ZXMYBiABKANSCWRpc2tCeXRlcxIWCgZmb2xkZXIYByABKAlSBmZvbGRlcg==');

@$core.Deprecated('Use setUpAgentRequestDescriptor instead')
const SetUpAgentRequest$json = {
  '1': 'SetUpAgentRequest',
  '2': [
    {'1': 'agent', '3': 1, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `SetUpAgentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setUpAgentRequestDescriptor = $convert
    .base64Decode('ChFTZXRVcEFnZW50UmVxdWVzdBIUCgVhZ2VudBgBIAEoCVIFYWdlbnQ=');

@$core.Deprecated('Use setUpAgentResponseDescriptor instead')
const SetUpAgentResponse$json = {
  '1': 'SetUpAgentResponse',
};

/// Descriptor for `SetUpAgentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setUpAgentResponseDescriptor =
    $convert.base64Decode('ChJTZXRVcEFnZW50UmVzcG9uc2U=');

@$core.Deprecated('Use removeAgentRequestDescriptor instead')
const RemoveAgentRequest$json = {
  '1': 'RemoveAgentRequest',
  '2': [
    {'1': 'agent', '3': 1, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `RemoveAgentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeAgentRequestDescriptor = $convert
    .base64Decode('ChJSZW1vdmVBZ2VudFJlcXVlc3QSFAoFYWdlbnQYASABKAlSBWFnZW50');

@$core.Deprecated('Use removeAgentResponseDescriptor instead')
const RemoveAgentResponse$json = {
  '1': 'RemoveAgentResponse',
};

/// Descriptor for `RemoveAgentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeAgentResponseDescriptor =
    $convert.base64Decode('ChNSZW1vdmVBZ2VudFJlc3BvbnNl');

@$core.Deprecated('Use startChatRequestDescriptor instead')
const StartChatRequest$json = {
  '1': 'StartChatRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'worktree', '3': 2, '4': 1, '5': 8, '10': 'worktree'},
    {'1': 'jira_site', '3': 4, '4': 1, '5': 9, '10': 'jiraSite'},
    {'1': 'jira_key', '3': 5, '4': 1, '5': 9, '10': 'jiraKey'},
    {'1': 'branch', '3': 6, '4': 1, '5': 9, '10': 'branch'},
  ],
};

/// Descriptor for `StartChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatRequestDescriptor = $convert.base64Decode(
    'ChBTdGFydENoYXRSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBWFnZW50GAMgAS'
    'gJUgVhZ2VudBIaCgh3b3JrdHJlZRgCIAEoCFIId29ya3RyZWUSGwoJamlyYV9zaXRlGAQgASgJ'
    'UghqaXJhU2l0ZRIZCghqaXJhX2tleRgFIAEoCVIHamlyYUtleRIWCgZicmFuY2gYBiABKAlSBm'
    'JyYW5jaA==');

@$core.Deprecated('Use listAgentSessionsRequestDescriptor instead')
const ListAgentSessionsRequest$json = {
  '1': 'ListAgentSessionsRequest',
  '2': [
    {'1': 'agent', '3': 1, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'folder', '3': 2, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'cursor', '3': 3, '4': 1, '5': 9, '10': 'cursor'},
  ],
};

/// Descriptor for `ListAgentSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAgentSessionsRequestDescriptor =
    $convert.base64Decode(
        'ChhMaXN0QWdlbnRTZXNzaW9uc1JlcXVlc3QSFAoFYWdlbnQYASABKAlSBWFnZW50EhYKBmZvbG'
        'RlchgCIAEoCVIGZm9sZGVyEhYKBmN1cnNvchgDIAEoCVIGY3Vyc29y');

@$core.Deprecated('Use listAgentSessionsResponseDescriptor instead')
const ListAgentSessionsResponse$json = {
  '1': 'ListAgentSessionsResponse',
  '2': [
    {'1': 'can_list', '3': 1, '4': 1, '5': 8, '10': 'canList'},
    {
      '1': 'sessions',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FoundSession',
      '10': 'sessions'
    },
    {'1': 'next_cursor', '3': 3, '4': 1, '5': 9, '10': 'nextCursor'},
    {'1': 'sees_open', '3': 4, '4': 1, '5': 8, '10': 'seesOpen'},
    {'1': 'one_writer', '3': 5, '4': 1, '5': 8, '10': 'oneWriter'},
  ],
};

/// Descriptor for `ListAgentSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAgentSessionsResponseDescriptor = $convert.base64Decode(
    'ChlMaXN0QWdlbnRTZXNzaW9uc1Jlc3BvbnNlEhkKCGNhbl9saXN0GAEgASgIUgdjYW5MaXN0Ej'
    'IKCHNlc3Npb25zGAIgAygLMhYubnVzaGkudjEuRm91bmRTZXNzaW9uUghzZXNzaW9ucxIfCgtu'
    'ZXh0X2N1cnNvchgDIAEoCVIKbmV4dEN1cnNvchIbCglzZWVzX29wZW4YBCABKAhSCHNlZXNPcG'
    'VuEh0KCm9uZV93cml0ZXIYBSABKAhSCW9uZVdyaXRlcg==');

@$core.Deprecated('Use foundSessionDescriptor instead')
const FoundSession$json = {
  '1': 'FoundSession',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'folder', '3': 3, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'updated_unix_ms', '3': 4, '4': 1, '5': 3, '10': 'updatedUnixMs'},
    {'1': 'messages', '3': 5, '4': 1, '5': 5, '10': 'messages'},
    {'1': 'open_in', '3': 6, '4': 1, '5': 9, '10': 'openIn'},
    {'1': 'folder_gone', '3': 7, '4': 1, '5': 8, '10': 'folderGone'},
  ],
};

/// Descriptor for `FoundSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List foundSessionDescriptor = $convert.base64Decode(
    'CgxGb3VuZFNlc3Npb24SHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhQKBXRpdGxlGA'
    'IgASgJUgV0aXRsZRIWCgZmb2xkZXIYAyABKAlSBmZvbGRlchImCg91cGRhdGVkX3VuaXhfbXMY'
    'BCABKANSDXVwZGF0ZWRVbml4TXMSGgoIbWVzc2FnZXMYBSABKAVSCG1lc3NhZ2VzEhcKB29wZW'
    '5faW4YBiABKAlSBm9wZW5JbhIfCgtmb2xkZXJfZ29uZRgHIAEoCFIKZm9sZGVyR29uZQ==');

@$core.Deprecated('Use openAgentSessionRequestDescriptor instead')
const OpenAgentSessionRequest$json = {
  '1': 'OpenAgentSessionRequest',
  '2': [
    {'1': 'agent', '3': 1, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'folder', '3': 2, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'session_id', '3': 3, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
  ],
};

/// Descriptor for `OpenAgentSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openAgentSessionRequestDescriptor = $convert.base64Decode(
    'ChdPcGVuQWdlbnRTZXNzaW9uUmVxdWVzdBIUCgVhZ2VudBgBIAEoCVIFYWdlbnQSFgoGZm9sZG'
    'VyGAIgASgJUgZmb2xkZXISHQoKc2Vzc2lvbl9pZBgDIAEoCVIJc2Vzc2lvbklkEhQKBXRpdGxl'
    'GAQgASgJUgV0aXRsZQ==');

@$core.Deprecated('Use openAgentSessionResponseDescriptor instead')
const OpenAgentSessionResponse$json = {
  '1': 'OpenAgentSessionResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `OpenAgentSessionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openAgentSessionResponseDescriptor =
    $convert.base64Decode(
        'ChhPcGVuQWdlbnRTZXNzaW9uUmVzcG9uc2USFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElk');

@$core.Deprecated('Use moveChatRequestDescriptor instead')
const MoveChatRequest$json = {
  '1': 'MoveChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'folder', '3': 2, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'worktree', '3': 3, '4': 1, '5': 8, '10': 'worktree'},
  ],
};

/// Descriptor for `MoveChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveChatRequestDescriptor = $convert.base64Decode(
    'Cg9Nb3ZlQ2hhdFJlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElkEhYKBmZvbGRlchgCIA'
    'EoCVIGZm9sZGVyEhoKCHdvcmt0cmVlGAMgASgIUgh3b3JrdHJlZQ==');

@$core.Deprecated('Use moveChatResponseDescriptor instead')
const MoveChatResponse$json = {
  '1': 'MoveChatResponse',
};

/// Descriptor for `MoveChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List moveChatResponseDescriptor =
    $convert.base64Decode('ChBNb3ZlQ2hhdFJlc3BvbnNl');

@$core.Deprecated('Use startChatResponseDescriptor instead')
const StartChatResponse$json = {
  '1': 'StartChatResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {
      '1': 'config',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ConfigOption',
      '10': 'config'
    },
  ],
};

/// Descriptor for `StartChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatResponseDescriptor = $convert.base64Decode(
    'ChFTdGFydENoYXRSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSLgoGY29uZmlnGA'
    'IgAygLMhYubnVzaGkudjEuQ29uZmlnT3B0aW9uUgZjb25maWc=');

@$core.Deprecated('Use sendPromptRequestDescriptor instead')
const SendPromptRequest$json = {
  '1': 'SendPromptRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'files', '3': 3, '4': 3, '5': 9, '10': 'files'},
    {
      '1': 'images',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ImageData',
      '10': 'images'
    },
    {'1': 'queue', '3': 5, '4': 1, '5': 8, '10': 'queue'},
    {'1': 'now', '3': 6, '4': 1, '5': 8, '10': 'now'},
    {'1': 'to_subagent', '3': 7, '4': 1, '5': 9, '10': 'toSubagent'},
  ],
};

/// Descriptor for `SendPromptRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendPromptRequestDescriptor = $convert.base64Decode(
    'ChFTZW5kUHJvbXB0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEgoEdGV4dBgCIA'
    'EoCVIEdGV4dBIUCgVmaWxlcxgDIAMoCVIFZmlsZXMSKwoGaW1hZ2VzGAQgAygLMhMubnVzaGku'
    'djEuSW1hZ2VEYXRhUgZpbWFnZXMSFAoFcXVldWUYBSABKAhSBXF1ZXVlEhAKA25vdxgGIAEoCF'
    'IDbm93Eh8KC3RvX3N1YmFnZW50GAcgASgJUgp0b1N1YmFnZW50');

@$core.Deprecated('Use queuedMessageDescriptor instead')
const QueuedMessage$json = {
  '1': 'QueuedMessage',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'text', '3': 2, '4': 1, '5': 9, '10': 'text'},
    {'1': 'files', '3': 3, '4': 3, '5': 9, '10': 'files'},
    {
      '1': 'images',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ImageData',
      '10': 'images'
    },
    {'1': 'relay_to', '3': 5, '4': 1, '5': 9, '10': 'relayTo'},
    {'1': 'to_subagent', '3': 6, '4': 1, '5': 9, '10': 'toSubagent'},
  ],
};

/// Descriptor for `QueuedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queuedMessageDescriptor = $convert.base64Decode(
    'Cg1RdWV1ZWRNZXNzYWdlEg4KAmlkGAEgASgJUgJpZBISCgR0ZXh0GAIgASgJUgR0ZXh0EhQKBW'
    'ZpbGVzGAMgAygJUgVmaWxlcxIrCgZpbWFnZXMYBCADKAsyEy5udXNoaS52MS5JbWFnZURhdGFS'
    'BmltYWdlcxIZCghyZWxheV90bxgFIAEoCVIHcmVsYXlUbxIfCgt0b19zdWJhZ2VudBgGIAEoCV'
    'IKdG9TdWJhZ2VudA==');

@$core.Deprecated('Use chatQueueDescriptor instead')
const ChatQueue$json = {
  '1': 'ChatQueue',
  '2': [
    {
      '1': 'messages',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.QueuedMessage',
      '10': 'messages'
    },
  ],
};

/// Descriptor for `ChatQueue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatQueueDescriptor = $convert.base64Decode(
    'CglDaGF0UXVldWUSMwoIbWVzc2FnZXMYASADKAsyFy5udXNoaS52MS5RdWV1ZWRNZXNzYWdlUg'
    'htZXNzYWdlcw==');

@$core.Deprecated('Use rewindChatRequestDescriptor instead')
const RewindChatRequest$json = {
  '1': 'RewindChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
  ],
};

/// Descriptor for `RewindChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rewindChatRequestDescriptor = $convert.base64Decode(
    'ChFSZXdpbmRDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFwoHaXRlbV9pZB'
    'gCIAEoCVIGaXRlbUlk');

@$core.Deprecated('Use rewindChatResponseDescriptor instead')
const RewindChatResponse$json = {
  '1': 'RewindChatResponse',
  '2': [
    {
      '1': 'message',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.QueuedMessage',
      '10': 'message'
    },
  ],
};

/// Descriptor for `RewindChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rewindChatResponseDescriptor = $convert.base64Decode(
    'ChJSZXdpbmRDaGF0UmVzcG9uc2USMQoHbWVzc2FnZRgBIAEoCzIXLm51c2hpLnYxLlF1ZXVlZE'
    '1lc3NhZ2VSB21lc3NhZ2U=');

@$core.Deprecated('Use unqueueRequestDescriptor instead')
const UnqueueRequest$json = {
  '1': 'UnqueueRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `UnqueueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unqueueRequestDescriptor = $convert.base64Decode(
    'Cg5VbnF1ZXVlUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSDgoCaWQYAiABKAlSAm'
    'lk');

@$core.Deprecated('Use unqueueResponseDescriptor instead')
const UnqueueResponse$json = {
  '1': 'UnqueueResponse',
  '2': [
    {
      '1': 'message',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.QueuedMessage',
      '10': 'message'
    },
  ],
};

/// Descriptor for `UnqueueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unqueueResponseDescriptor = $convert.base64Decode(
    'Cg9VbnF1ZXVlUmVzcG9uc2USMQoHbWVzc2FnZRgBIAEoCzIXLm51c2hpLnYxLlF1ZXVlZE1lc3'
    'NhZ2VSB21lc3NhZ2U=');

@$core.Deprecated('Use imageDataDescriptor instead')
const ImageData$json = {
  '1': 'ImageData',
  '2': [
    {'1': 'mime_type', '3': 1, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `ImageData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageDataDescriptor = $convert.base64Decode(
    'CglJbWFnZURhdGESGwoJbWltZV90eXBlGAEgASgJUghtaW1lVHlwZRISCgRkYXRhGAIgASgMUg'
    'RkYXRh');

@$core.Deprecated('Use listFilesRequestDescriptor instead')
const ListFilesRequest$json = {
  '1': 'ListFilesRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `ListFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listFilesRequestDescriptor = $convert
    .base64Decode('ChBMaXN0RmlsZXNSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVy');

@$core.Deprecated('Use listFilesResponseDescriptor instead')
const ListFilesResponse$json = {
  '1': 'ListFilesResponse',
  '2': [
    {'1': 'paths', '3': 1, '4': 3, '5': 9, '10': 'paths'},
  ],
};

/// Descriptor for `ListFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listFilesResponseDescriptor = $convert
    .base64Decode('ChFMaXN0RmlsZXNSZXNwb25zZRIUCgVwYXRocxgBIAMoCVIFcGF0aHM=');

@$core.Deprecated('Use sendPromptResponseDescriptor instead')
const SendPromptResponse$json = {
  '1': 'SendPromptResponse',
};

/// Descriptor for `SendPromptResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendPromptResponseDescriptor =
    $convert.base64Decode('ChJTZW5kUHJvbXB0UmVzcG9uc2U=');

@$core.Deprecated('Use cancelTurnRequestDescriptor instead')
const CancelTurnRequest$json = {
  '1': 'CancelTurnRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'take_back', '3': 2, '4': 1, '5': 8, '10': 'takeBack'},
  ],
};

/// Descriptor for `CancelTurnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelTurnRequestDescriptor = $convert.base64Decode(
    'ChFDYW5jZWxUdXJuUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSGwoJdGFrZV9iYW'
    'NrGAIgASgIUgh0YWtlQmFjaw==');

@$core.Deprecated('Use cancelTurnResponseDescriptor instead')
const CancelTurnResponse$json = {
  '1': 'CancelTurnResponse',
  '2': [
    {
      '1': 'message',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.QueuedMessage',
      '10': 'message'
    },
  ],
};

/// Descriptor for `CancelTurnResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelTurnResponseDescriptor = $convert.base64Decode(
    'ChJDYW5jZWxUdXJuUmVzcG9uc2USMQoHbWVzc2FnZRgBIAEoCzIXLm51c2hpLnYxLlF1ZXVlZE'
    '1lc3NhZ2VSB21lc3NhZ2U=');

@$core.Deprecated('Use forkChatRequestDescriptor instead')
const ForkChatRequest$json = {
  '1': 'ForkChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ForkChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forkChatRequestDescriptor = $convert
    .base64Decode('Cg9Gb3JrQ2hhdFJlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElk');

@$core.Deprecated('Use forkChatResponseDescriptor instead')
const ForkChatResponse$json = {
  '1': 'ForkChatResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ForkChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forkChatResponseDescriptor = $convert.base64Decode(
    'ChBGb3JrQ2hhdFJlc3BvbnNlEhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use closeSideChatRequestDescriptor instead')
const CloseSideChatRequest$json = {
  '1': 'CloseSideChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `CloseSideChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeSideChatRequestDescriptor =
    $convert.base64Decode(
        'ChRDbG9zZVNpZGVDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use closeSideChatResponseDescriptor instead')
const CloseSideChatResponse$json = {
  '1': 'CloseSideChatResponse',
};

/// Descriptor for `CloseSideChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeSideChatResponseDescriptor =
    $convert.base64Decode('ChVDbG9zZVNpZGVDaGF0UmVzcG9uc2U=');

@$core.Deprecated('Use renameChatRequestDescriptor instead')
const RenameChatRequest$json = {
  '1': 'RenameChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
  ],
};

/// Descriptor for `RenameChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameChatRequestDescriptor = $convert.base64Decode(
    'ChFSZW5hbWVDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFAoFdGl0bGUYAi'
    'ABKAlSBXRpdGxl');

@$core.Deprecated('Use renameChatResponseDescriptor instead')
const RenameChatResponse$json = {
  '1': 'RenameChatResponse',
};

/// Descriptor for `RenameChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameChatResponseDescriptor =
    $convert.base64Decode('ChJSZW5hbWVDaGF0UmVzcG9uc2U=');

@$core.Deprecated('Use archiveChatRequestDescriptor instead')
const ArchiveChatRequest$json = {
  '1': 'ArchiveChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'archived', '3': 2, '4': 1, '5': 8, '10': 'archived'},
  ],
};

/// Descriptor for `ArchiveChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveChatRequestDescriptor = $convert.base64Decode(
    'ChJBcmNoaXZlQ2hhdFJlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElkEhoKCGFyY2hpdm'
    'VkGAIgASgIUghhcmNoaXZlZA==');

@$core.Deprecated('Use archiveChatResponseDescriptor instead')
const ArchiveChatResponse$json = {
  '1': 'ArchiveChatResponse',
};

/// Descriptor for `ArchiveChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveChatResponseDescriptor =
    $convert.base64Decode('ChNBcmNoaXZlQ2hhdFJlc3BvbnNl');

@$core.Deprecated('Use sleepChatRequestDescriptor instead')
const SleepChatRequest$json = {
  '1': 'SleepChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `SleepChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sleepChatRequestDescriptor = $convert.base64Decode(
    'ChBTbGVlcENoYXRSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use sleepChatResponseDescriptor instead')
const SleepChatResponse$json = {
  '1': 'SleepChatResponse',
};

/// Descriptor for `SleepChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sleepChatResponseDescriptor =
    $convert.base64Decode('ChFTbGVlcENoYXRSZXNwb25zZQ==');

@$core.Deprecated('Use getMemoryRequestDescriptor instead')
const GetMemoryRequest$json = {
  '1': 'GetMemoryRequest',
  '2': [
    {'1': 'app_pid', '3': 1, '4': 1, '5': 5, '10': 'appPid'},
  ],
};

/// Descriptor for `GetMemoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMemoryRequestDescriptor = $convert.base64Decode(
    'ChBHZXRNZW1vcnlSZXF1ZXN0EhcKB2FwcF9waWQYASABKAVSBmFwcFBpZA==');

@$core.Deprecated('Use getMemoryResponseDescriptor instead')
const GetMemoryResponse$json = {
  '1': 'GetMemoryResponse',
  '2': [
    {'1': 'daemon', '3': 1, '4': 1, '5': 3, '10': 'daemon'},
    {'1': 'app', '3': 2, '4': 1, '5': 3, '10': 'app'},
    {'1': 'other', '3': 3, '4': 1, '5': 3, '10': 'other'},
    {
      '1': 'chats',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GetMemoryResponse.ChatsEntry',
      '10': 'chats'
    },
  ],
  '3': [GetMemoryResponse_ChatsEntry$json],
};

@$core.Deprecated('Use getMemoryResponseDescriptor instead')
const GetMemoryResponse_ChatsEntry$json = {
  '1': 'ChatsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 3, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `GetMemoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getMemoryResponseDescriptor = $convert.base64Decode(
    'ChFHZXRNZW1vcnlSZXNwb25zZRIWCgZkYWVtb24YASABKANSBmRhZW1vbhIQCgNhcHAYAiABKA'
    'NSA2FwcBIUCgVvdGhlchgDIAEoA1IFb3RoZXISPAoFY2hhdHMYBCADKAsyJi5udXNoaS52MS5H'
    'ZXRNZW1vcnlSZXNwb25zZS5DaGF0c0VudHJ5UgVjaGF0cxo4CgpDaGF0c0VudHJ5EhAKA2tleR'
    'gBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgDUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use getSettingsRequestDescriptor instead')
const GetSettingsRequest$json = {
  '1': 'GetSettingsRequest',
};

/// Descriptor for `GetSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSettingsRequestDescriptor =
    $convert.base64Decode('ChJHZXRTZXR0aW5nc1JlcXVlc3Q=');

@$core.Deprecated('Use settingsDescriptor instead')
const Settings$json = {
  '1': 'Settings',
  '2': [
    {
      '1': 'sleep_after_minutes',
      '3': 1,
      '4': 1,
      '5': 5,
      '10': 'sleepAfterMinutes'
    },
    {'1': 'debug_log', '3': 2, '4': 1, '5': 8, '10': 'debugLog'},
  ],
};

/// Descriptor for `Settings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsDescriptor = $convert.base64Decode(
    'CghTZXR0aW5ncxIuChNzbGVlcF9hZnRlcl9taW51dGVzGAEgASgFUhFzbGVlcEFmdGVyTWludX'
    'RlcxIbCglkZWJ1Z19sb2cYAiABKAhSCGRlYnVnTG9n');

@$core.Deprecated('Use getSettingsResponseDescriptor instead')
const GetSettingsResponse$json = {
  '1': 'GetSettingsResponse',
  '2': [
    {
      '1': 'settings',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Settings',
      '10': 'settings'
    },
  ],
};

/// Descriptor for `GetSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSettingsResponseDescriptor = $convert.base64Decode(
    'ChNHZXRTZXR0aW5nc1Jlc3BvbnNlEi4KCHNldHRpbmdzGAEgASgLMhIubnVzaGkudjEuU2V0dG'
    'luZ3NSCHNldHRpbmdz');

@$core.Deprecated('Use setSettingsRequestDescriptor instead')
const SetSettingsRequest$json = {
  '1': 'SetSettingsRequest',
  '2': [
    {
      '1': 'settings',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Settings',
      '10': 'settings'
    },
  ],
};

/// Descriptor for `SetSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setSettingsRequestDescriptor = $convert.base64Decode(
    'ChJTZXRTZXR0aW5nc1JlcXVlc3QSLgoIc2V0dGluZ3MYASABKAsyEi5udXNoaS52MS5TZXR0aW'
    '5nc1IIc2V0dGluZ3M=');

@$core.Deprecated('Use setSettingsResponseDescriptor instead')
const SetSettingsResponse$json = {
  '1': 'SetSettingsResponse',
};

/// Descriptor for `SetSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setSettingsResponseDescriptor =
    $convert.base64Decode('ChNTZXRTZXR0aW5nc1Jlc3BvbnNl');

@$core.Deprecated('Use planDeleteChatRequestDescriptor instead')
const PlanDeleteChatRequest$json = {
  '1': 'PlanDeleteChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `PlanDeleteChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planDeleteChatRequestDescriptor =
    $convert.base64Decode(
        'ChVQbGFuRGVsZXRlQ2hhdFJlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElk');

@$core.Deprecated('Use planDeleteChatResponseDescriptor instead')
const PlanDeleteChatResponse$json = {
  '1': 'PlanDeleteChatResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.AgentSession',
      '10': 'sessions'
    },
    {'1': 'deletes_history', '3': 2, '4': 1, '5': 8, '10': 'deletesHistory'},
    {'1': 'scratch_folder', '3': 3, '4': 1, '5': 9, '10': 'scratchFolder'},
    {
      '1': 'worktrees',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.WorktreePlan',
      '10': 'worktrees'
    },
    {
      '1': 'terminals',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Terminal',
      '10': 'terminals'
    },
  ],
  '9': [
    {'1': 4, '2': 5},
    {'1': 5, '2': 6},
  ],
  '10': ['worktree', 'worktree_state'],
};

/// Descriptor for `PlanDeleteChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planDeleteChatResponseDescriptor = $convert.base64Decode(
    'ChZQbGFuRGVsZXRlQ2hhdFJlc3BvbnNlEjIKCHNlc3Npb25zGAEgAygLMhYubnVzaGkudjEuQW'
    'dlbnRTZXNzaW9uUghzZXNzaW9ucxInCg9kZWxldGVzX2hpc3RvcnkYAiABKAhSDmRlbGV0ZXNI'
    'aXN0b3J5EiUKDnNjcmF0Y2hfZm9sZGVyGAMgASgJUg1zY3JhdGNoRm9sZGVyEjQKCXdvcmt0cm'
    'VlcxgGIAMoCzIWLm51c2hpLnYxLldvcmt0cmVlUGxhblIJd29ya3RyZWVzEjAKCXRlcm1pbmFs'
    'cxgHIAMoCzISLm51c2hpLnYxLlRlcm1pbmFsUgl0ZXJtaW5hbHNKBAgEEAVKBAgFEAZSCHdvcm'
    't0cmVlUg53b3JrdHJlZV9zdGF0ZQ==');

@$core.Deprecated('Use worktreePlanDescriptor instead')
const WorktreePlan$json = {
  '1': 'WorktreePlan',
  '2': [
    {
      '1': 'worktree',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Worktree',
      '10': 'worktree'
    },
    {
      '1': 'state',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.WorktreeState',
      '10': 'state'
    },
  ],
};

/// Descriptor for `WorktreePlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreePlanDescriptor = $convert.base64Decode(
    'CgxXb3JrdHJlZVBsYW4SLgoId29ya3RyZWUYASABKAsyEi5udXNoaS52MS5Xb3JrdHJlZVIId2'
    '9ya3RyZWUSLQoFc3RhdGUYAiABKAsyFy5udXNoaS52MS5Xb3JrdHJlZVN0YXRlUgVzdGF0ZQ==');

@$core.Deprecated('Use worktreeStateDescriptor instead')
const WorktreeState$json = {
  '1': 'WorktreeState',
  '2': [
    {'1': 'gone', '3': 1, '4': 1, '5': 8, '10': 'gone'},
    {'1': 'changed', '3': 2, '4': 1, '5': 5, '10': 'changed'},
    {'1': 'commits', '3': 3, '4': 1, '5': 5, '10': 'commits'},
    {'1': 'branch_gone', '3': 4, '4': 1, '5': 8, '10': 'branchGone'},
    {'1': 'error', '3': 5, '4': 1, '5': 9, '10': 'error'},
    {'1': 'ignored', '3': 6, '4': 1, '5': 5, '10': 'ignored'},
  ],
};

/// Descriptor for `WorktreeState`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeStateDescriptor = $convert.base64Decode(
    'Cg1Xb3JrdHJlZVN0YXRlEhIKBGdvbmUYASABKAhSBGdvbmUSGAoHY2hhbmdlZBgCIAEoBVIHY2'
    'hhbmdlZBIYCgdjb21taXRzGAMgASgFUgdjb21taXRzEh8KC2JyYW5jaF9nb25lGAQgASgIUgpi'
    'cmFuY2hHb25lEhQKBWVycm9yGAUgASgJUgVlcnJvchIYCgdpZ25vcmVkGAYgASgFUgdpZ25vcm'
    'Vk');

@$core.Deprecated('Use agentSessionDescriptor instead')
const AgentSession$json = {
  '1': 'AgentSession',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'folder', '3': 2, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `AgentSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentSessionDescriptor = $convert.base64Decode(
    'CgxBZ2VudFNlc3Npb24SHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEhYKBmZvbGRlch'
    'gCIAEoCVIGZm9sZGVy');

@$core.Deprecated('Use deleteChatRequestDescriptor instead')
const DeleteChatRequest$json = {
  '1': 'DeleteChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {
      '1': 'worktrees',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.WorktreeChoice',
      '10': 'worktrees'
    },
  ],
  '9': [
    {'1': 2, '2': 6},
  ],
  '10': ['remove_worktree', 'force_worktree', 'delete_branch', 'force_branch'],
};

/// Descriptor for `DeleteChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteChatRequestDescriptor = $convert.base64Decode(
    'ChFEZWxldGVDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSNgoJd29ya3RyZW'
    'VzGAYgAygLMhgubnVzaGkudjEuV29ya3RyZWVDaG9pY2VSCXdvcmt0cmVlc0oECAIQBlIPcmVt'
    'b3ZlX3dvcmt0cmVlUg5mb3JjZV93b3JrdHJlZVINZGVsZXRlX2JyYW5jaFIMZm9yY2VfYnJhbm'
    'No');

@$core.Deprecated('Use worktreeChoiceDescriptor instead')
const WorktreeChoice$json = {
  '1': 'WorktreeChoice',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'remove_worktree', '3': 2, '4': 1, '5': 8, '10': 'removeWorktree'},
    {'1': 'force_worktree', '3': 3, '4': 1, '5': 8, '10': 'forceWorktree'},
    {'1': 'delete_branch', '3': 4, '4': 1, '5': 8, '10': 'deleteBranch'},
    {'1': 'force_branch', '3': 5, '4': 1, '5': 8, '10': 'forceBranch'},
  ],
};

/// Descriptor for `WorktreeChoice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeChoiceDescriptor = $convert.base64Decode(
    'Cg5Xb3JrdHJlZUNob2ljZRISCgRwYXRoGAEgASgJUgRwYXRoEicKD3JlbW92ZV93b3JrdHJlZR'
    'gCIAEoCFIOcmVtb3ZlV29ya3RyZWUSJQoOZm9yY2Vfd29ya3RyZWUYAyABKAhSDWZvcmNlV29y'
    'a3RyZWUSIwoNZGVsZXRlX2JyYW5jaBgEIAEoCFIMZGVsZXRlQnJhbmNoEiEKDGZvcmNlX2JyYW'
    '5jaBgFIAEoCFILZm9yY2VCcmFuY2g=');

@$core.Deprecated('Use deleteChatResponseDescriptor instead')
const DeleteChatResponse$json = {
  '1': 'DeleteChatResponse',
};

/// Descriptor for `DeleteChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteChatResponseDescriptor =
    $convert.base64Decode('ChJEZWxldGVDaGF0UmVzcG9uc2U=');

@$core.Deprecated('Use answerPermissionRequestDescriptor instead')
const AnswerPermissionRequest$json = {
  '1': 'AnswerPermissionRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'option_id', '3': 3, '4': 1, '5': 9, '10': 'optionId'},
  ],
};

/// Descriptor for `AnswerPermissionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerPermissionRequestDescriptor =
    $convert.base64Decode(
        'ChdBbnN3ZXJQZXJtaXNzaW9uUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFwoHaX'
        'RlbV9pZBgCIAEoCVIGaXRlbUlkEhsKCW9wdGlvbl9pZBgDIAEoCVIIb3B0aW9uSWQ=');

@$core.Deprecated('Use answerPermissionResponseDescriptor instead')
const AnswerPermissionResponse$json = {
  '1': 'AnswerPermissionResponse',
};

/// Descriptor for `AnswerPermissionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerPermissionResponseDescriptor =
    $convert.base64Decode('ChhBbnN3ZXJQZXJtaXNzaW9uUmVzcG9uc2U=');

@$core.Deprecated('Use answerQuestionRequestDescriptor instead')
const AnswerQuestionRequest$json = {
  '1': 'AnswerQuestionRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
    {
      '1': 'answers',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FieldAnswer',
      '10': 'answers'
    },
    {'1': 'decline', '3': 4, '4': 1, '5': 8, '10': 'decline'},
  ],
};

/// Descriptor for `AnswerQuestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerQuestionRequestDescriptor = $convert.base64Decode(
    'ChVBbnN3ZXJRdWVzdGlvblJlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElkEhcKB2l0ZW'
    '1faWQYAiABKAlSBml0ZW1JZBIvCgdhbnN3ZXJzGAMgAygLMhUubnVzaGkudjEuRmllbGRBbnN3'
    'ZXJSB2Fuc3dlcnMSGAoHZGVjbGluZRgEIAEoCFIHZGVjbGluZQ==');

@$core.Deprecated('Use fieldAnswerDescriptor instead')
const FieldAnswer$json = {
  '1': 'FieldAnswer',
  '2': [
    {'1': 'field_id', '3': 1, '4': 1, '5': 9, '10': 'fieldId'},
    {'1': 'values', '3': 2, '4': 3, '5': 9, '10': 'values'},
  ],
};

/// Descriptor for `FieldAnswer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fieldAnswerDescriptor = $convert.base64Decode(
    'CgtGaWVsZEFuc3dlchIZCghmaWVsZF9pZBgBIAEoCVIHZmllbGRJZBIWCgZ2YWx1ZXMYAiADKA'
    'lSBnZhbHVlcw==');

@$core.Deprecated('Use answerQuestionResponseDescriptor instead')
const AnswerQuestionResponse$json = {
  '1': 'AnswerQuestionResponse',
};

/// Descriptor for `AnswerQuestionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List answerQuestionResponseDescriptor =
    $convert.base64Decode('ChZBbnN3ZXJRdWVzdGlvblJlc3BvbnNl');

@$core.Deprecated('Use setConfigOptionRequestDescriptor instead')
const SetConfigOptionRequest$json = {
  '1': 'SetConfigOptionRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'config_id', '3': 2, '4': 1, '5': 9, '10': 'configId'},
    {'1': 'value', '3': 3, '4': 1, '5': 9, '10': 'value'},
  ],
};

/// Descriptor for `SetConfigOptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setConfigOptionRequestDescriptor =
    $convert.base64Decode(
        'ChZTZXRDb25maWdPcHRpb25SZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIbCgljb2'
        '5maWdfaWQYAiABKAlSCGNvbmZpZ0lkEhQKBXZhbHVlGAMgASgJUgV2YWx1ZQ==');

@$core.Deprecated('Use setConfigOptionResponseDescriptor instead')
const SetConfigOptionResponse$json = {
  '1': 'SetConfigOptionResponse',
};

/// Descriptor for `SetConfigOptionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setConfigOptionResponseDescriptor =
    $convert.base64Decode('ChdTZXRDb25maWdPcHRpb25SZXNwb25zZQ==');

@$core.Deprecated('Use getContextUsageRequestDescriptor instead')
const GetContextUsageRequest$json = {
  '1': 'GetContextUsageRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `GetContextUsageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getContextUsageRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRDb250ZXh0VXNhZ2VSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use getContextUsageResponseDescriptor instead')
const GetContextUsageResponse$json = {
  '1': 'GetContextUsageResponse',
  '2': [
    {
      '1': 'categories',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ContextCategory',
      '10': 'categories'
    },
    {'1': 'markdown', '3': 2, '4': 1, '5': 9, '10': 'markdown'},
  ],
};

/// Descriptor for `GetContextUsageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getContextUsageResponseDescriptor = $convert.base64Decode(
    'ChdHZXRDb250ZXh0VXNhZ2VSZXNwb25zZRI5CgpjYXRlZ29yaWVzGAEgAygLMhkubnVzaGkudj'
    'EuQ29udGV4dENhdGVnb3J5UgpjYXRlZ29yaWVzEhoKCG1hcmtkb3duGAIgASgJUghtYXJrZG93'
    'bg==');

@$core.Deprecated('Use listMcpServersRequestDescriptor instead')
const ListMcpServersRequest$json = {
  '1': 'ListMcpServersRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'check_health', '3': 2, '4': 1, '5': 8, '10': 'checkHealth'},
  ],
};

/// Descriptor for `ListMcpServersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMcpServersRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0TWNwU2VydmVyc1JlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISIQoMY2hlY2'
    'tfaGVhbHRoGAIgASgIUgtjaGVja0hlYWx0aA==');

@$core.Deprecated('Use listMcpServersResponseDescriptor instead')
const ListMcpServersResponse$json = {
  '1': 'ListMcpServersResponse',
  '2': [
    {
      '1': 'servers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.McpServer',
      '10': 'servers'
    },
    {'1': 'check_error', '3': 2, '4': 1, '5': 9, '10': 'checkError'},
  ],
};

/// Descriptor for `ListMcpServersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMcpServersResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0TWNwU2VydmVyc1Jlc3BvbnNlEi0KB3NlcnZlcnMYASADKAsyEy5udXNoaS52MS5NY3'
        'BTZXJ2ZXJSB3NlcnZlcnMSHwoLY2hlY2tfZXJyb3IYAiABKAlSCmNoZWNrRXJyb3I=');

@$core.Deprecated('Use mcpServerDescriptor instead')
const McpServer$json = {
  '1': 'McpServer',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'scope', '3': 2, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'source', '3': 3, '4': 1, '5': 9, '10': 'source'},
    {'1': 'config_json', '3': 4, '4': 1, '5': 9, '10': 'configJson'},
    {'1': 'state', '3': 5, '4': 1, '5': 9, '10': 'state'},
    {'1': 'detail', '3': 6, '4': 1, '5': 9, '10': 'detail'},
    {'1': 'shadowed', '3': 7, '4': 1, '5': 8, '10': 'shadowed'},
    {'1': 'off', '3': 8, '4': 1, '5': 8, '10': 'off'},
    {'1': 'off_by', '3': 9, '4': 1, '5': 9, '10': 'offBy'},
    {'1': 'approved', '3': 10, '4': 1, '5': 8, '10': 'approved'},
  ],
};

/// Descriptor for `McpServer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mcpServerDescriptor = $convert.base64Decode(
    'CglNY3BTZXJ2ZXISEgoEbmFtZRgBIAEoCVIEbmFtZRIUCgVzY29wZRgCIAEoCVIFc2NvcGUSFg'
    'oGc291cmNlGAMgASgJUgZzb3VyY2USHwoLY29uZmlnX2pzb24YBCABKAlSCmNvbmZpZ0pzb24S'
    'FAoFc3RhdGUYBSABKAlSBXN0YXRlEhYKBmRldGFpbBgGIAEoCVIGZGV0YWlsEhoKCHNoYWRvd2'
    'VkGAcgASgIUghzaGFkb3dlZBIQCgNvZmYYCCABKAhSA29mZhIVCgZvZmZfYnkYCSABKAlSBW9m'
    'ZkJ5EhoKCGFwcHJvdmVkGAogASgIUghhcHByb3ZlZA==');

@$core.Deprecated('Use addMcpServerRequestDescriptor instead')
const AddMcpServerRequest$json = {
  '1': 'AddMcpServerRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'scope', '3': 2, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'config_json', '3': 4, '4': 1, '5': 9, '10': 'configJson'},
  ],
};

/// Descriptor for `AddMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addMcpServerRequestDescriptor = $convert.base64Decode(
    'ChNBZGRNY3BTZXJ2ZXJSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBXNjb3BlGA'
    'IgASgJUgVzY29wZRISCgRuYW1lGAMgASgJUgRuYW1lEh8KC2NvbmZpZ19qc29uGAQgASgJUgpj'
    'b25maWdKc29u');

@$core.Deprecated('Use addMcpServerResponseDescriptor instead')
const AddMcpServerResponse$json = {
  '1': 'AddMcpServerResponse',
};

/// Descriptor for `AddMcpServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addMcpServerResponseDescriptor =
    $convert.base64Decode('ChRBZGRNY3BTZXJ2ZXJSZXNwb25zZQ==');

@$core.Deprecated('Use editMcpServerRequestDescriptor instead')
const EditMcpServerRequest$json = {
  '1': 'EditMcpServerRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'scope', '3': 2, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'config_json', '3': 4, '4': 1, '5': 9, '10': 'configJson'},
  ],
};

/// Descriptor for `EditMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editMcpServerRequestDescriptor = $convert.base64Decode(
    'ChRFZGl0TWNwU2VydmVyUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchIUCgVzY29wZR'
    'gCIAEoCVIFc2NvcGUSEgoEbmFtZRgDIAEoCVIEbmFtZRIfCgtjb25maWdfanNvbhgEIAEoCVIK'
    'Y29uZmlnSnNvbg==');

@$core.Deprecated('Use editMcpServerResponseDescriptor instead')
const EditMcpServerResponse$json = {
  '1': 'EditMcpServerResponse',
};

/// Descriptor for `EditMcpServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editMcpServerResponseDescriptor =
    $convert.base64Decode('ChVFZGl0TWNwU2VydmVyUmVzcG9uc2U=');

@$core.Deprecated('Use removeMcpServerRequestDescriptor instead')
const RemoveMcpServerRequest$json = {
  '1': 'RemoveMcpServerRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'scope', '3': 2, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `RemoveMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeMcpServerRequestDescriptor =
    $convert.base64Decode(
        'ChZSZW1vdmVNY3BTZXJ2ZXJSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBXNjb3'
        'BlGAIgASgJUgVzY29wZRISCgRuYW1lGAMgASgJUgRuYW1l');

@$core.Deprecated('Use removeMcpServerResponseDescriptor instead')
const RemoveMcpServerResponse$json = {
  '1': 'RemoveMcpServerResponse',
};

/// Descriptor for `RemoveMcpServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeMcpServerResponseDescriptor =
    $convert.base64Decode('ChdSZW1vdmVNY3BTZXJ2ZXJSZXNwb25zZQ==');

@$core.Deprecated('Use setMcpServerOnRequestDescriptor instead')
const SetMcpServerOnRequest$json = {
  '1': 'SetMcpServerOnRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'on', '3': 3, '4': 1, '5': 8, '10': 'on'},
  ],
};

/// Descriptor for `SetMcpServerOnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMcpServerOnRequestDescriptor = $convert.base64Decode(
    'ChVTZXRNY3BTZXJ2ZXJPblJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRIOCgJvbhgDIAEoCFICb24=');

@$core.Deprecated('Use setMcpServerOnResponseDescriptor instead')
const SetMcpServerOnResponse$json = {
  '1': 'SetMcpServerOnResponse',
};

/// Descriptor for `SetMcpServerOnResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMcpServerOnResponseDescriptor =
    $convert.base64Decode('ChZTZXRNY3BTZXJ2ZXJPblJlc3BvbnNl');

@$core.Deprecated('Use loginMcpServerRequestDescriptor instead')
const LoginMcpServerRequest$json = {
  '1': 'LoginMcpServerRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `LoginMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginMcpServerRequestDescriptor = $convert.base64Decode(
    'ChVMb2dpbk1jcFNlcnZlclJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEbmFtZR'
    'gCIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use loginMcpServerResponseDescriptor instead')
const LoginMcpServerResponse$json = {
  '1': 'LoginMcpServerResponse',
};

/// Descriptor for `LoginMcpServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginMcpServerResponseDescriptor =
    $convert.base64Decode('ChZMb2dpbk1jcFNlcnZlclJlc3BvbnNl');

@$core.Deprecated('Use logoutMcpServerRequestDescriptor instead')
const LogoutMcpServerRequest$json = {
  '1': 'LogoutMcpServerRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `LogoutMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutMcpServerRequestDescriptor =
    $convert.base64Decode(
        'ChZMb2dvdXRNY3BTZXJ2ZXJSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhIKBG5hbW'
        'UYAiABKAlSBG5hbWU=');

@$core.Deprecated('Use logoutMcpServerResponseDescriptor instead')
const LogoutMcpServerResponse$json = {
  '1': 'LogoutMcpServerResponse',
};

/// Descriptor for `LogoutMcpServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutMcpServerResponseDescriptor =
    $convert.base64Decode('ChdMb2dvdXRNY3BTZXJ2ZXJSZXNwb25zZQ==');

@$core.Deprecated('Use reloadChatRequestDescriptor instead')
const ReloadChatRequest$json = {
  '1': 'ReloadChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ReloadChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reloadChatRequestDescriptor = $convert.base64Decode(
    'ChFSZWxvYWRDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use reloadChatResponseDescriptor instead')
const ReloadChatResponse$json = {
  '1': 'ReloadChatResponse',
};

/// Descriptor for `ReloadChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reloadChatResponseDescriptor =
    $convert.base64Decode('ChJSZWxvYWRDaGF0UmVzcG9uc2U=');

@$core.Deprecated('Use contextCategoryDescriptor instead')
const ContextCategory$json = {
  '1': 'ContextCategory',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'tokens', '3': 2, '4': 1, '5': 3, '10': 'tokens'},
    {'1': 'percent', '3': 3, '4': 1, '5': 1, '10': 'percent'},
    {'1': 'kind', '3': 4, '4': 1, '5': 9, '10': 'kind'},
  ],
};

/// Descriptor for `ContextCategory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List contextCategoryDescriptor = $convert.base64Decode(
    'Cg9Db250ZXh0Q2F0ZWdvcnkSEgoEbmFtZRgBIAEoCVIEbmFtZRIWCgZ0b2tlbnMYAiABKANSBn'
    'Rva2VucxIYCgdwZXJjZW50GAMgASgBUgdwZXJjZW50EhIKBGtpbmQYBCABKAlSBGtpbmQ=');

@$core.Deprecated('Use getFolderStatusRequestDescriptor instead')
const GetFolderStatusRequest$json = {
  '1': 'GetFolderStatusRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'base', '3': 2, '4': 1, '5': 9, '10': 'base'},
  ],
};

/// Descriptor for `GetFolderStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFolderStatusRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRGb2xkZXJTdGF0dXNSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhIKBGJhc2'
        'UYAiABKAlSBGJhc2U=');

@$core.Deprecated('Use getFolderStatusResponseDescriptor instead')
const GetFolderStatusResponse$json = {
  '1': 'GetFolderStatusResponse',
  '2': [
    {'1': 'git', '3': 1, '4': 1, '5': 8, '10': 'git'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'files', '3': 3, '4': 1, '5': 5, '10': 'files'},
    {'1': 'added', '3': 4, '4': 1, '5': 5, '10': 'added'},
    {'1': 'removed', '3': 5, '4': 1, '5': 5, '10': 'removed'},
    {'1': 'gone', '3': 6, '4': 1, '5': 8, '10': 'gone'},
    {'1': 'default_base', '3': 7, '4': 1, '5': 9, '10': 'defaultBase'},
    {'1': 'ahead', '3': 8, '4': 1, '5': 5, '10': 'ahead'},
  ],
};

/// Descriptor for `GetFolderStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFolderStatusResponseDescriptor = $convert.base64Decode(
    'ChdHZXRGb2xkZXJTdGF0dXNSZXNwb25zZRIQCgNnaXQYASABKAhSA2dpdBIWCgZicmFuY2gYAi'
    'ABKAlSBmJyYW5jaBIUCgVmaWxlcxgDIAEoBVIFZmlsZXMSFAoFYWRkZWQYBCABKAVSBWFkZGVk'
    'EhgKB3JlbW92ZWQYBSABKAVSB3JlbW92ZWQSEgoEZ29uZRgGIAEoCFIEZ29uZRIhCgxkZWZhdW'
    'x0X2Jhc2UYByABKAlSC2RlZmF1bHRCYXNlEhQKBWFoZWFkGAggASgFUgVhaGVhZA==');

@$core.Deprecated('Use getDiffRequestDescriptor instead')
const GetDiffRequest$json = {
  '1': 'GetDiffRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'base', '3': 2, '4': 1, '5': 9, '10': 'base'},
    {'1': 'commit', '3': 3, '4': 1, '5': 9, '10': 'commit'},
    {'1': 'since', '3': 4, '4': 1, '5': 9, '10': 'since'},
  ],
};

/// Descriptor for `GetDiffRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDiffRequestDescriptor = $convert.base64Decode(
    'Cg5HZXREaWZmUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchISCgRiYXNlGAIgASgJUg'
    'RiYXNlEhYKBmNvbW1pdBgDIAEoCVIGY29tbWl0EhQKBXNpbmNlGAQgASgJUgVzaW5jZQ==');

@$core.Deprecated('Use getDiffResponseDescriptor instead')
const GetDiffResponse$json = {
  '1': 'GetDiffResponse',
  '2': [
    {
      '1': 'files',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FileChange',
      '10': 'files'
    },
  ],
};

/// Descriptor for `GetDiffResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDiffResponseDescriptor = $convert.base64Decode(
    'Cg9HZXREaWZmUmVzcG9uc2USKgoFZmlsZXMYASADKAsyFC5udXNoaS52MS5GaWxlQ2hhbmdlUg'
    'VmaWxlcw==');

@$core.Deprecated('Use fileChangeDescriptor instead')
const FileChange$json = {
  '1': 'FileChange',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'status', '3': 2, '4': 1, '5': 9, '10': 'status'},
    {'1': 'old_text', '3': 3, '4': 1, '5': 9, '10': 'oldText'},
    {'1': 'new_text', '3': 4, '4': 1, '5': 9, '10': 'newText'},
    {'1': 'skipped', '3': 5, '4': 1, '5': 9, '10': 'skipped'},
    {'1': 'old_path', '3': 6, '4': 1, '5': 9, '10': 'oldPath'},
    {'1': 'added', '3': 7, '4': 1, '5': 5, '10': 'added'},
    {'1': 'removed', '3': 8, '4': 1, '5': 5, '10': 'removed'},
  ],
};

/// Descriptor for `FileChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileChangeDescriptor = $convert.base64Decode(
    'CgpGaWxlQ2hhbmdlEhIKBHBhdGgYASABKAlSBHBhdGgSFgoGc3RhdHVzGAIgASgJUgZzdGF0dX'
    'MSGQoIb2xkX3RleHQYAyABKAlSB29sZFRleHQSGQoIbmV3X3RleHQYBCABKAlSB25ld1RleHQS'
    'GAoHc2tpcHBlZBgFIAEoCVIHc2tpcHBlZBIZCghvbGRfcGF0aBgGIAEoCVIHb2xkUGF0aBIUCg'
    'VhZGRlZBgHIAEoBVIFYWRkZWQSGAoHcmVtb3ZlZBgIIAEoBVIHcmVtb3ZlZA==');

@$core.Deprecated('Use listCommitsRequestDescriptor instead')
const ListCommitsRequest$json = {
  '1': 'ListCommitsRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'base', '3': 2, '4': 1, '5': 9, '10': 'base'},
  ],
};

/// Descriptor for `ListCommitsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCommitsRequestDescriptor = $convert.base64Decode(
    'ChJMaXN0Q29tbWl0c1JlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEYmFzZRgCIA'
    'EoCVIEYmFzZQ==');

@$core.Deprecated('Use listCommitsResponseDescriptor instead')
const ListCommitsResponse$json = {
  '1': 'ListCommitsResponse',
  '2': [
    {
      '1': 'commits',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Commit',
      '10': 'commits'
    },
  ],
};

/// Descriptor for `ListCommitsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCommitsResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0Q29tbWl0c1Jlc3BvbnNlEioKB2NvbW1pdHMYASADKAsyEC5udXNoaS52MS5Db21taX'
    'RSB2NvbW1pdHM=');

@$core.Deprecated('Use commitDescriptor instead')
const Commit$json = {
  '1': 'Commit',
  '2': [
    {'1': 'hash', '3': 1, '4': 1, '5': 9, '10': 'hash'},
    {'1': 'short', '3': 2, '4': 1, '5': 9, '10': 'short'},
    {'1': 'subject', '3': 3, '4': 1, '5': 9, '10': 'subject'},
    {'1': 'unix_seconds', '3': 4, '4': 1, '5': 3, '10': 'unixSeconds'},
    {'1': 'added', '3': 5, '4': 1, '5': 5, '10': 'added'},
    {'1': 'removed', '3': 6, '4': 1, '5': 5, '10': 'removed'},
  ],
};

/// Descriptor for `Commit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitDescriptor = $convert.base64Decode(
    'CgZDb21taXQSEgoEaGFzaBgBIAEoCVIEaGFzaBIUCgVzaG9ydBgCIAEoCVIFc2hvcnQSGAoHc3'
    'ViamVjdBgDIAEoCVIHc3ViamVjdBIhCgx1bml4X3NlY29uZHMYBCABKANSC3VuaXhTZWNvbmRz'
    'EhQKBWFkZGVkGAUgASgFUgVhZGRlZBIYCgdyZW1vdmVkGAYgASgFUgdyZW1vdmVk');

@$core.Deprecated('Use eventsRequestDescriptor instead')
const EventsRequest$json = {
  '1': 'EventsRequest',
};

/// Descriptor for `EventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventsRequestDescriptor =
    $convert.base64Decode('Cg1FdmVudHNSZXF1ZXN0');

@$core.Deprecated('Use eventsResponseDescriptor instead')
const EventsResponse$json = {
  '1': 'EventsResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'seq', '3': 6, '4': 1, '5': 3, '10': 'seq'},
    {
      '1': 'item',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ItemEvent',
      '9': 0,
      '10': 'item'
    },
    {
      '1': 'status',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatStatus',
      '9': 0,
      '10': 'status'
    },
    {
      '1': 'config',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatConfig',
      '9': 0,
      '10': 'config'
    },
    {
      '1': 'chat',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Chat',
      '9': 0,
      '10': 'chat'
    },
    {
      '1': 'commands',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatCommands',
      '9': 0,
      '10': 'commands'
    },
    {'1': 'removed', '3': 8, '4': 1, '5': 8, '9': 0, '10': 'removed'},
    {
      '1': 'usage',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Usage',
      '9': 0,
      '10': 'usage'
    },
    {
      '1': 'queue',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatQueue',
      '9': 0,
      '10': 'queue'
    },
    {'1': 'cut', '3': 11, '4': 1, '5': 9, '9': 0, '10': 'cut'},
    {
      '1': 'terminals',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatTerminals',
      '9': 0,
      '10': 'terminals'
    },
    {'1': 'dropped', '3': 13, '4': 1, '5': 9, '9': 0, '10': 'dropped'},
    {
      '1': 'remote',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Remote',
      '9': 0,
      '10': 'remote'
    },
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `EventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventsResponseDescriptor = $convert.base64Decode(
    'Cg5FdmVudHNSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEAoDc2VxGAYgASgDUg'
    'NzZXESKQoEaXRlbRgCIAEoCzITLm51c2hpLnYxLkl0ZW1FdmVudEgAUgRpdGVtEi4KBnN0YXR1'
    'cxgDIAEoCzIULm51c2hpLnYxLkNoYXRTdGF0dXNIAFIGc3RhdHVzEi4KBmNvbmZpZxgEIAEoCz'
    'IULm51c2hpLnYxLkNoYXRDb25maWdIAFIGY29uZmlnEiQKBGNoYXQYBSABKAsyDi5udXNoaS52'
    'MS5DaGF0SABSBGNoYXQSNAoIY29tbWFuZHMYByABKAsyFi5udXNoaS52MS5DaGF0Q29tbWFuZH'
    'NIAFIIY29tbWFuZHMSGgoHcmVtb3ZlZBgIIAEoCEgAUgdyZW1vdmVkEicKBXVzYWdlGAkgASgL'
    'Mg8ubnVzaGkudjEuVXNhZ2VIAFIFdXNhZ2USKwoFcXVldWUYCiABKAsyEy5udXNoaS52MS5DaG'
    'F0UXVldWVIAFIFcXVldWUSEgoDY3V0GAsgASgJSABSA2N1dBI3Cgl0ZXJtaW5hbHMYDCABKAsy'
    'Fy5udXNoaS52MS5DaGF0VGVybWluYWxzSABSCXRlcm1pbmFscxIaCgdkcm9wcGVkGA0gASgJSA'
    'BSB2Ryb3BwZWQSKgoGcmVtb3RlGA4gASgLMhAubnVzaGkudjEuUmVtb3RlSABSBnJlbW90ZUIG'
    'CgRraW5k');

@$core.Deprecated('Use chatConfigDescriptor instead')
const ChatConfig$json = {
  '1': 'ChatConfig',
  '2': [
    {
      '1': 'options',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ConfigOption',
      '10': 'options'
    },
  ],
};

/// Descriptor for `ChatConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatConfigDescriptor = $convert.base64Decode(
    'CgpDaGF0Q29uZmlnEjAKB29wdGlvbnMYASADKAsyFi5udXNoaS52MS5Db25maWdPcHRpb25SB2'
    '9wdGlvbnM=');

@$core.Deprecated('Use configOptionDescriptor instead')
const ConfigOption$json = {
  '1': 'ConfigOption',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'category', '3': 4, '4': 1, '5': 9, '10': 'category'},
    {'1': 'type', '3': 5, '4': 1, '5': 9, '10': 'type'},
    {'1': 'current', '3': 6, '4': 1, '5': 9, '10': 'current'},
    {
      '1': 'values',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ConfigValue',
      '10': 'values'
    },
  ],
};

/// Descriptor for `ConfigOption`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configOptionDescriptor = $convert.base64Decode(
    'CgxDb25maWdPcHRpb24SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSIAoLZG'
    'VzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEhoKCGNhdGVnb3J5GAQgASgJUghjYXRlZ29y'
    'eRISCgR0eXBlGAUgASgJUgR0eXBlEhgKB2N1cnJlbnQYBiABKAlSB2N1cnJlbnQSLQoGdmFsdW'
    'VzGAcgAygLMhUubnVzaGkudjEuQ29uZmlnVmFsdWVSBnZhbHVlcw==');

@$core.Deprecated('Use configValueDescriptor instead')
const ConfigValue$json = {
  '1': 'ConfigValue',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 9, '10': 'value'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'group', '3': 4, '4': 1, '5': 9, '10': 'group'},
    {'1': 'is_default', '3': 5, '4': 1, '5': 8, '10': 'isDefault'},
  ],
};

/// Descriptor for `ConfigValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configValueDescriptor = $convert.base64Decode(
    'CgtDb25maWdWYWx1ZRIUCgV2YWx1ZRgBIAEoCVIFdmFsdWUSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SFAoFZ3JvdXAYBCABKAlSBWdyb3Vw'
    'Eh0KCmlzX2RlZmF1bHQYBSABKAhSCWlzRGVmYXVsdA==');

@$core.Deprecated('Use itemDescriptor instead')
const Item$json = {
  '1': 'Item',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'kind',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.nushi.v1.ItemKind',
      '10': 'kind'
    },
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'tool_kind', '3': 5, '4': 1, '5': 9, '10': 'toolKind'},
    {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'options',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Option',
      '10': 'options'
    },
    {'1': 'answer', '3': 8, '4': 1, '5': 9, '10': 'answer'},
    {
      '1': 'fields',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Field',
      '10': 'fields'
    },
    {'1': 'paths', '3': 10, '4': 3, '5': 9, '10': 'paths'},
    {
      '1': 'diffs',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FileChange',
      '10': 'diffs'
    },
    {
      '1': 'plan',
      '3': 12,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.PlanEntry',
      '10': 'plan'
    },
    {
      '1': 'images',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.ImageData',
      '10': 'images'
    },
    {'1': 'parent', '3': 14, '4': 1, '5': 9, '10': 'parent'},
    {'1': 'agent', '3': 15, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'tool', '3': 16, '4': 1, '5': 9, '10': 'tool'},
    {'1': 'fork_at', '3': 17, '4': 1, '5': 9, '10': 'forkAt'},
    {'1': 'rewindable', '3': 18, '4': 1, '5': 8, '10': 'rewindable'},
    {
      '1': 'subagent',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Subagent',
      '10': 'subagent'
    },
    {'1': 'report', '3': 20, '4': 1, '5': 8, '10': 'report'},
    {'1': 'prompt', '3': 21, '4': 1, '5': 9, '10': 'prompt'},
    {'1': 'model', '3': 22, '4': 1, '5': 9, '10': 'model'},
    {'1': 'effort', '3': 23, '4': 1, '5': 9, '10': 'effort'},
    {'1': 'ran_model', '3': 24, '4': 1, '5': 9, '10': 'ranModel'},
    {
      '1': 'shell',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Shell',
      '10': 'shell'
    },
    {'1': 'agent_id', '3': 26, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'relay_to', '3': 27, '4': 1, '5': 9, '10': 'relayTo'},
  ],
};

/// Descriptor for `Item`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List itemDescriptor = $convert.base64Decode(
    'CgRJdGVtEg4KAmlkGAEgASgJUgJpZBImCgRraW5kGAIgASgOMhIubnVzaGkudjEuSXRlbUtpbm'
    'RSBGtpbmQSEgoEdGV4dBgDIAEoCVIEdGV4dBIUCgV0aXRsZRgEIAEoCVIFdGl0bGUSGwoJdG9v'
    'bF9raW5kGAUgASgJUgh0b29sS2luZBIWCgZzdGF0dXMYBiABKAlSBnN0YXR1cxIqCgdvcHRpb2'
    '5zGAcgAygLMhAubnVzaGkudjEuT3B0aW9uUgdvcHRpb25zEhYKBmFuc3dlchgIIAEoCVIGYW5z'
    'd2VyEicKBmZpZWxkcxgJIAMoCzIPLm51c2hpLnYxLkZpZWxkUgZmaWVsZHMSFAoFcGF0aHMYCi'
    'ADKAlSBXBhdGhzEioKBWRpZmZzGAsgAygLMhQubnVzaGkudjEuRmlsZUNoYW5nZVIFZGlmZnMS'
    'JwoEcGxhbhgMIAMoCzITLm51c2hpLnYxLlBsYW5FbnRyeVIEcGxhbhIrCgZpbWFnZXMYDSADKA'
    'syEy5udXNoaS52MS5JbWFnZURhdGFSBmltYWdlcxIWCgZwYXJlbnQYDiABKAlSBnBhcmVudBIU'
    'CgVhZ2VudBgPIAEoCVIFYWdlbnQSEgoEdG9vbBgQIAEoCVIEdG9vbBIXCgdmb3JrX2F0GBEgAS'
    'gJUgZmb3JrQXQSHgoKcmV3aW5kYWJsZRgSIAEoCFIKcmV3aW5kYWJsZRIuCghzdWJhZ2VudBgT'
    'IAEoCzISLm51c2hpLnYxLlN1YmFnZW50UghzdWJhZ2VudBIWCgZyZXBvcnQYFCABKAhSBnJlcG'
    '9ydBIWCgZwcm9tcHQYFSABKAlSBnByb21wdBIUCgVtb2RlbBgWIAEoCVIFbW9kZWwSFgoGZWZm'
    'b3J0GBcgASgJUgZlZmZvcnQSGwoJcmFuX21vZGVsGBggASgJUghyYW5Nb2RlbBIlCgVzaGVsbB'
    'gZIAEoCzIPLm51c2hpLnYxLlNoZWxsUgVzaGVsbBIZCghhZ2VudF9pZBgaIAEoCVIHYWdlbnRJ'
    'ZBIZCghyZWxheV90bxgbIAEoCVIHcmVsYXlUbw==');

@$core.Deprecated('Use shellDescriptor instead')
const Shell$json = {
  '1': 'Shell',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'state', '3': 2, '4': 1, '5': 9, '10': 'state'},
    {'1': 'started', '3': 3, '4': 1, '5': 3, '10': 'started'},
    {'1': 'ended', '3': 4, '4': 1, '5': 3, '10': 'ended'},
    {'1': 'output', '3': 5, '4': 1, '5': 9, '10': 'output'},
    {'1': 'end', '3': 6, '4': 1, '5': 9, '10': 'end'},
  ],
};

/// Descriptor for `Shell`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shellDescriptor = $convert.base64Decode(
    'CgVTaGVsbBIOCgJpZBgBIAEoCVICaWQSFAoFc3RhdGUYAiABKAlSBXN0YXRlEhgKB3N0YXJ0ZW'
    'QYAyABKANSB3N0YXJ0ZWQSFAoFZW5kZWQYBCABKANSBWVuZGVkEhYKBm91dHB1dBgFIAEoCVIG'
    'b3V0cHV0EhAKA2VuZBgGIAEoCVIDZW5k');

@$core.Deprecated('Use subagentDescriptor instead')
const Subagent$json = {
  '1': 'Subagent',
  '2': [
    {'1': 'state', '3': 1, '4': 1, '5': 9, '10': 'state'},
    {'1': 'started', '3': 2, '4': 1, '5': 3, '10': 'started'},
    {'1': 'ended', '3': 3, '4': 1, '5': 3, '10': 'ended'},
    {'1': 'result', '3': 4, '4': 1, '5': 9, '10': 'result'},
  ],
};

/// Descriptor for `Subagent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subagentDescriptor = $convert.base64Decode(
    'CghTdWJhZ2VudBIUCgVzdGF0ZRgBIAEoCVIFc3RhdGUSGAoHc3RhcnRlZBgCIAEoA1IHc3Rhcn'
    'RlZBIUCgVlbmRlZBgDIAEoA1IFZW5kZWQSFgoGcmVzdWx0GAQgASgJUgZyZXN1bHQ=');

@$core.Deprecated('Use planEntryDescriptor instead')
const PlanEntry$json = {
  '1': 'PlanEntry',
  '2': [
    {'1': 'content', '3': 1, '4': 1, '5': 9, '10': 'content'},
    {'1': 'status', '3': 2, '4': 1, '5': 9, '10': 'status'},
  ],
};

/// Descriptor for `PlanEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planEntryDescriptor = $convert.base64Decode(
    'CglQbGFuRW50cnkSGAoHY29udGVudBgBIAEoCVIHY29udGVudBIWCgZzdGF0dXMYAiABKAlSBn'
    'N0YXR1cw==');

@$core.Deprecated('Use optionDescriptor instead')
const Option$json = {
  '1': 'Option',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'kind', '3': 3, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
  ],
};

/// Descriptor for `Option`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List optionDescriptor = $convert.base64Decode(
    'CgZPcHRpb24SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSEgoEa2luZBgDIA'
    'EoCVIEa2luZBIgCgtkZXNjcmlwdGlvbhgEIAEoCVILZGVzY3JpcHRpb24=');

@$core.Deprecated('Use fieldDescriptor instead')
const Field$json = {
  '1': 'Field',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.nushi.v1.FieldType',
      '10': 'type'
    },
    {
      '1': 'options',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Option',
      '10': 'options'
    },
    {'1': 'required', '3': 6, '4': 1, '5': 8, '10': 'required'},
    {'1': 'values', '3': 7, '4': 3, '5': 9, '10': 'values'},
    {'1': 'other_for', '3': 8, '4': 1, '5': 9, '10': 'otherFor'},
  ],
};

/// Descriptor for `Field`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fieldDescriptor = $convert.base64Decode(
    'CgVGaWVsZBIOCgJpZBgBIAEoCVICaWQSFAoFdGl0bGUYAiABKAlSBXRpdGxlEiAKC2Rlc2NyaX'
    'B0aW9uGAMgASgJUgtkZXNjcmlwdGlvbhInCgR0eXBlGAQgASgOMhMubnVzaGkudjEuRmllbGRU'
    'eXBlUgR0eXBlEioKB29wdGlvbnMYBSADKAsyEC5udXNoaS52MS5PcHRpb25SB29wdGlvbnMSGg'
    'oIcmVxdWlyZWQYBiABKAhSCHJlcXVpcmVkEhYKBnZhbHVlcxgHIAMoCVIGdmFsdWVzEhsKCW90'
    'aGVyX2ZvchgIIAEoCVIIb3RoZXJGb3I=');

@$core.Deprecated('Use itemEventDescriptor instead')
const ItemEvent$json = {
  '1': 'ItemEvent',
  '2': [
    {'1': 'item', '3': 1, '4': 1, '5': 11, '6': '.nushi.v1.Item', '10': 'item'},
    {'1': 'append', '3': 2, '4': 1, '5': 8, '10': 'append'},
  ],
};

/// Descriptor for `ItemEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List itemEventDescriptor = $convert.base64Decode(
    'CglJdGVtRXZlbnQSIgoEaXRlbRgBIAEoCzIOLm51c2hpLnYxLkl0ZW1SBGl0ZW0SFgoGYXBwZW'
    '5kGAIgASgIUgZhcHBlbmQ=');

@$core.Deprecated('Use chatStatusDescriptor instead')
const ChatStatus$json = {
  '1': 'ChatStatus',
  '2': [
    {'1': 'busy', '3': 1, '4': 1, '5': 8, '10': 'busy'},
    {'1': 'started', '3': 3, '4': 1, '5': 3, '10': 'started'},
    {'1': 'waiting', '3': 4, '4': 1, '5': 8, '10': 'waiting'},
    {'1': 'can_fork', '3': 5, '4': 1, '5': 8, '10': 'canFork'},
    {'1': 'images', '3': 6, '4': 1, '5': 8, '10': 'images'},
    {'1': 'can_rewind', '3': 7, '4': 1, '5': 8, '10': 'canRewind'},
    {'1': 'mcp_changed', '3': 8, '4': 1, '5': 8, '10': 'mcpChanged'},
    {'1': 'can_ask_context', '3': 9, '4': 1, '5': 8, '10': 'canAskContext'},
    {'1': 'asleep', '3': 10, '4': 1, '5': 8, '10': 'asleep'},
    {'1': 'can_sleep', '3': 11, '4': 1, '5': 8, '10': 'canSleep'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['error'],
};

/// Descriptor for `ChatStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatStatusDescriptor = $convert.base64Decode(
    'CgpDaGF0U3RhdHVzEhIKBGJ1c3kYASABKAhSBGJ1c3kSGAoHc3RhcnRlZBgDIAEoA1IHc3Rhcn'
    'RlZBIYCgd3YWl0aW5nGAQgASgIUgd3YWl0aW5nEhkKCGNhbl9mb3JrGAUgASgIUgdjYW5Gb3Jr'
    'EhYKBmltYWdlcxgGIAEoCFIGaW1hZ2VzEh0KCmNhbl9yZXdpbmQYByABKAhSCWNhblJld2luZB'
    'IfCgttY3BfY2hhbmdlZBgIIAEoCFIKbWNwQ2hhbmdlZBImCg9jYW5fYXNrX2NvbnRleHQYCSAB'
    'KAhSDWNhbkFza0NvbnRleHQSFgoGYXNsZWVwGAogASgIUgZhc2xlZXASGwoJY2FuX3NsZWVwGA'
    'sgASgIUghjYW5TbGVlcEoECAIQA1IFZXJyb3I=');

@$core.Deprecated('Use terminalDescriptor instead')
const Terminal$json = {
  '1': 'Terminal',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'chat_id', '3': 2, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'folder', '3': 3, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'shell', '3': 5, '4': 1, '5': 9, '10': 'shell'},
    {'1': 'program', '3': 6, '4': 1, '5': 9, '10': 'program'},
    {'1': 'exited', '3': 7, '4': 1, '5': 8, '10': 'exited'},
    {'1': 'exit_code', '3': 8, '4': 1, '5': 5, '10': 'exitCode'},
    {'1': 'name', '3': 9, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `Terminal`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List terminalDescriptor = $convert.base64Decode(
    'CghUZXJtaW5hbBIOCgJpZBgBIAEoCVICaWQSFwoHY2hhdF9pZBgCIAEoCVIGY2hhdElkEhYKBm'
    'ZvbGRlchgDIAEoCVIGZm9sZGVyEhQKBXNoZWxsGAUgASgJUgVzaGVsbBIYCgdwcm9ncmFtGAYg'
    'ASgJUgdwcm9ncmFtEhYKBmV4aXRlZBgHIAEoCFIGZXhpdGVkEhsKCWV4aXRfY29kZRgIIAEoBV'
    'IIZXhpdENvZGUSEgoEbmFtZRgJIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use chatTerminalsDescriptor instead')
const ChatTerminals$json = {
  '1': 'ChatTerminals',
  '2': [
    {
      '1': 'terminals',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Terminal',
      '10': 'terminals'
    },
  ],
};

/// Descriptor for `ChatTerminals`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatTerminalsDescriptor = $convert.base64Decode(
    'Cg1DaGF0VGVybWluYWxzEjAKCXRlcm1pbmFscxgBIAMoCzISLm51c2hpLnYxLlRlcm1pbmFsUg'
    'l0ZXJtaW5hbHM=');

@$core.Deprecated('Use openTerminalRequestDescriptor instead')
const OpenTerminalRequest$json = {
  '1': 'OpenTerminalRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'folder', '3': 2, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'cols', '3': 3, '4': 1, '5': 5, '10': 'cols'},
    {'1': 'rows', '3': 4, '4': 1, '5': 5, '10': 'rows'},
  ],
};

/// Descriptor for `OpenTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openTerminalRequestDescriptor = $convert.base64Decode(
    'ChNPcGVuVGVybWluYWxSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIWCgZmb2xkZX'
    'IYAiABKAlSBmZvbGRlchISCgRjb2xzGAMgASgFUgRjb2xzEhIKBHJvd3MYBCABKAVSBHJvd3M=');

@$core.Deprecated('Use openTerminalResponseDescriptor instead')
const OpenTerminalResponse$json = {
  '1': 'OpenTerminalResponse',
  '2': [
    {
      '1': 'terminal',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Terminal',
      '10': 'terminal'
    },
  ],
};

/// Descriptor for `OpenTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List openTerminalResponseDescriptor = $convert.base64Decode(
    'ChRPcGVuVGVybWluYWxSZXNwb25zZRIuCgh0ZXJtaW5hbBgBIAEoCzISLm51c2hpLnYxLlRlcm'
    '1pbmFsUgh0ZXJtaW5hbA==');

@$core.Deprecated('Use listTerminalsRequestDescriptor instead')
const ListTerminalsRequest$json = {
  '1': 'ListTerminalsRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ListTerminalsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTerminalsRequestDescriptor =
    $convert.base64Decode(
        'ChRMaXN0VGVybWluYWxzUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use listTerminalsResponseDescriptor instead')
const ListTerminalsResponse$json = {
  '1': 'ListTerminalsResponse',
  '2': [
    {
      '1': 'terminals',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Terminal',
      '10': 'terminals'
    },
  ],
};

/// Descriptor for `ListTerminalsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTerminalsResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0VGVybWluYWxzUmVzcG9uc2USMAoJdGVybWluYWxzGAEgAygLMhIubnVzaGkudjEuVG'
    'VybWluYWxSCXRlcm1pbmFscw==');

@$core.Deprecated('Use attachTerminalRequestDescriptor instead')
const AttachTerminalRequest$json = {
  '1': 'AttachTerminalRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
  ],
};

/// Descriptor for `AttachTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachTerminalRequestDescriptor = $convert.base64Decode(
    'ChVBdHRhY2hUZXJtaW5hbFJlcXVlc3QSHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSW'
    'Q=');

@$core.Deprecated('Use attachTerminalResponseDescriptor instead')
const AttachTerminalResponse$json = {
  '1': 'AttachTerminalResponse',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'exited', '3': 2, '4': 1, '5': 8, '10': 'exited'},
    {'1': 'exit_code', '3': 3, '4': 1, '5': 5, '10': 'exitCode'},
  ],
};

/// Descriptor for `AttachTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attachTerminalResponseDescriptor =
    $convert.base64Decode(
        'ChZBdHRhY2hUZXJtaW5hbFJlc3BvbnNlEhIKBGRhdGEYASABKAxSBGRhdGESFgoGZXhpdGVkGA'
        'IgASgIUgZleGl0ZWQSGwoJZXhpdF9jb2RlGAMgASgFUghleGl0Q29kZQ==');

@$core.Deprecated('Use writeTerminalRequestDescriptor instead')
const WriteTerminalRequest$json = {
  '1': 'WriteTerminalRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `WriteTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeTerminalRequestDescriptor = $convert.base64Decode(
    'ChRXcml0ZVRlcm1pbmFsUmVxdWVzdBIfCgt0ZXJtaW5hbF9pZBgBIAEoCVIKdGVybWluYWxJZB'
    'ISCgRkYXRhGAIgASgMUgRkYXRh');

@$core.Deprecated('Use writeTerminalResponseDescriptor instead')
const WriteTerminalResponse$json = {
  '1': 'WriteTerminalResponse',
};

/// Descriptor for `WriteTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeTerminalResponseDescriptor =
    $convert.base64Decode('ChVXcml0ZVRlcm1pbmFsUmVzcG9uc2U=');

@$core.Deprecated('Use resizeTerminalRequestDescriptor instead')
const ResizeTerminalRequest$json = {
  '1': 'ResizeTerminalRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
    {'1': 'cols', '3': 2, '4': 1, '5': 5, '10': 'cols'},
    {'1': 'rows', '3': 3, '4': 1, '5': 5, '10': 'rows'},
  ],
};

/// Descriptor for `ResizeTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeTerminalRequestDescriptor = $convert.base64Decode(
    'ChVSZXNpemVUZXJtaW5hbFJlcXVlc3QSHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSW'
    'QSEgoEY29scxgCIAEoBVIEY29scxISCgRyb3dzGAMgASgFUgRyb3dz');

@$core.Deprecated('Use resizeTerminalResponseDescriptor instead')
const ResizeTerminalResponse$json = {
  '1': 'ResizeTerminalResponse',
};

/// Descriptor for `ResizeTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resizeTerminalResponseDescriptor =
    $convert.base64Decode('ChZSZXNpemVUZXJtaW5hbFJlc3BvbnNl');

@$core.Deprecated('Use renameTerminalRequestDescriptor instead')
const RenameTerminalRequest$json = {
  '1': 'RenameTerminalRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `RenameTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameTerminalRequestDescriptor = $convert.base64Decode(
    'ChVSZW5hbWVUZXJtaW5hbFJlcXVlc3QSHwoLdGVybWluYWxfaWQYASABKAlSCnRlcm1pbmFsSW'
    'QSEgoEbmFtZRgCIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use renameTerminalResponseDescriptor instead')
const RenameTerminalResponse$json = {
  '1': 'RenameTerminalResponse',
};

/// Descriptor for `RenameTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameTerminalResponseDescriptor =
    $convert.base64Decode('ChZSZW5hbWVUZXJtaW5hbFJlc3BvbnNl');

@$core.Deprecated('Use arrangeTerminalsRequestDescriptor instead')
const ArrangeTerminalsRequest$json = {
  '1': 'ArrangeTerminalsRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'terminal_ids', '3': 2, '4': 3, '5': 9, '10': 'terminalIds'},
  ],
};

/// Descriptor for `ArrangeTerminalsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arrangeTerminalsRequestDescriptor =
    $convert.base64Decode(
        'ChdBcnJhbmdlVGVybWluYWxzUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSIQoMdG'
        'VybWluYWxfaWRzGAIgAygJUgt0ZXJtaW5hbElkcw==');

@$core.Deprecated('Use arrangeTerminalsResponseDescriptor instead')
const ArrangeTerminalsResponse$json = {
  '1': 'ArrangeTerminalsResponse',
};

/// Descriptor for `ArrangeTerminalsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List arrangeTerminalsResponseDescriptor =
    $convert.base64Decode('ChhBcnJhbmdlVGVybWluYWxzUmVzcG9uc2U=');

@$core.Deprecated('Use restartTerminalRequestDescriptor instead')
const RestartTerminalRequest$json = {
  '1': 'RestartTerminalRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
    {'1': 'cols', '3': 2, '4': 1, '5': 5, '10': 'cols'},
    {'1': 'rows', '3': 3, '4': 1, '5': 5, '10': 'rows'},
  ],
};

/// Descriptor for `RestartTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartTerminalRequestDescriptor =
    $convert.base64Decode(
        'ChZSZXN0YXJ0VGVybWluYWxSZXF1ZXN0Eh8KC3Rlcm1pbmFsX2lkGAEgASgJUgp0ZXJtaW5hbE'
        'lkEhIKBGNvbHMYAiABKAVSBGNvbHMSEgoEcm93cxgDIAEoBVIEcm93cw==');

@$core.Deprecated('Use restartTerminalResponseDescriptor instead')
const RestartTerminalResponse$json = {
  '1': 'RestartTerminalResponse',
};

/// Descriptor for `RestartTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartTerminalResponseDescriptor =
    $convert.base64Decode('ChdSZXN0YXJ0VGVybWluYWxSZXNwb25zZQ==');

@$core.Deprecated('Use closeTerminalRequestDescriptor instead')
const CloseTerminalRequest$json = {
  '1': 'CloseTerminalRequest',
  '2': [
    {'1': 'terminal_id', '3': 1, '4': 1, '5': 9, '10': 'terminalId'},
  ],
};

/// Descriptor for `CloseTerminalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeTerminalRequestDescriptor = $convert.base64Decode(
    'ChRDbG9zZVRlcm1pbmFsUmVxdWVzdBIfCgt0ZXJtaW5hbF9pZBgBIAEoCVIKdGVybWluYWxJZA'
    '==');

@$core.Deprecated('Use closeTerminalResponseDescriptor instead')
const CloseTerminalResponse$json = {
  '1': 'CloseTerminalResponse',
};

/// Descriptor for `CloseTerminalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List closeTerminalResponseDescriptor =
    $convert.base64Decode('ChVDbG9zZVRlcm1pbmFsUmVzcG9uc2U=');

@$core.Deprecated('Use checkFolderRequestDescriptor instead')
const CheckFolderRequest$json = {
  '1': 'CheckFolderRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'agent', '3': 2, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `CheckFolderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkFolderRequestDescriptor = $convert.base64Decode(
    'ChJDaGVja0ZvbGRlclJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISFAoFYWdlbnQYAi'
    'ABKAlSBWFnZW50');

@$core.Deprecated('Use checkFolderResponseDescriptor instead')
const CheckFolderResponse$json = {
  '1': 'CheckFolderResponse',
  '2': [
    {
      '1': 'runs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FolderRun',
      '10': 'runs'
    },
    {'1': 'key', '3': 2, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `CheckFolderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkFolderResponseDescriptor = $convert.base64Decode(
    'ChNDaGVja0ZvbGRlclJlc3BvbnNlEicKBHJ1bnMYASADKAsyEy5udXNoaS52MS5Gb2xkZXJSdW'
    '5SBHJ1bnMSEAoDa2V5GAIgASgJUgNrZXk=');

@$core.Deprecated('Use folderRunDescriptor instead')
const FolderRun$json = {
  '1': 'FolderRun',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 9, '10': 'file'},
    {'1': 'what', '3': 2, '4': 1, '5': 9, '10': 'what'},
    {'1': 'command', '3': 3, '4': 1, '5': 9, '10': 'command'},
  ],
};

/// Descriptor for `FolderRun`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List folderRunDescriptor = $convert.base64Decode(
    'CglGb2xkZXJSdW4SEgoEZmlsZRgBIAEoCVIEZmlsZRISCgR3aGF0GAIgASgJUgR3aGF0EhgKB2'
    'NvbW1hbmQYAyABKAlSB2NvbW1hbmQ=');

@$core.Deprecated('Use trustFolderRequestDescriptor instead')
const TrustFolderRequest$json = {
  '1': 'TrustFolderRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'agent', '3': 2, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'key', '3': 3, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `TrustFolderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trustFolderRequestDescriptor = $convert.base64Decode(
    'ChJUcnVzdEZvbGRlclJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISFAoFYWdlbnQYAi'
    'ABKAlSBWFnZW50EhAKA2tleRgDIAEoCVIDa2V5');

@$core.Deprecated('Use trustFolderResponseDescriptor instead')
const TrustFolderResponse$json = {
  '1': 'TrustFolderResponse',
};

/// Descriptor for `TrustFolderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trustFolderResponseDescriptor =
    $convert.base64Decode('ChNUcnVzdEZvbGRlclJlc3BvbnNl');

@$core.Deprecated('Use remoteDescriptor instead')
const Remote$json = {
  '1': 'Remote',
  '2': [
    {'1': 'on', '3': 1, '4': 1, '5': 8, '10': 'on'},
    {'1': 'relay', '3': 2, '4': 1, '5': 9, '10': 'relay'},
    {'1': 'state', '3': 3, '4': 1, '5': 9, '10': 'state'},
    {'1': 'error', '3': 4, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'devices',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Device',
      '10': 'devices'
    },
    {
      '1': 'pairing',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Pairing',
      '10': 'pairing'
    },
    {'1': 'rendezvous', '3': 7, '4': 1, '5': 9, '10': 'rendezvous'},
  ],
};

/// Descriptor for `Remote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteDescriptor = $convert.base64Decode(
    'CgZSZW1vdGUSDgoCb24YASABKAhSAm9uEhQKBXJlbGF5GAIgASgJUgVyZWxheRIUCgVzdGF0ZR'
    'gDIAEoCVIFc3RhdGUSFAoFZXJyb3IYBCABKAlSBWVycm9yEioKB2RldmljZXMYBSADKAsyEC5u'
    'dXNoaS52MS5EZXZpY2VSB2RldmljZXMSKwoHcGFpcmluZxgGIAEoCzIRLm51c2hpLnYxLlBhaX'
    'JpbmdSB3BhaXJpbmcSHgoKcmVuZGV6dm91cxgHIAEoCVIKcmVuZGV6dm91cw==');

@$core.Deprecated('Use deviceDescriptor instead')
const Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'paired', '3': 3, '4': 1, '5': 3, '10': 'paired'},
    {'1': 'last_seen', '3': 4, '4': 1, '5': 3, '10': 'lastSeen'},
    {'1': 'connected', '3': 5, '4': 1, '5': 8, '10': 'connected'},
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFgoGcGFpcmVkGA'
    'MgASgDUgZwYWlyZWQSGwoJbGFzdF9zZWVuGAQgASgDUghsYXN0U2VlbhIcCgljb25uZWN0ZWQY'
    'BSABKAhSCWNvbm5lY3RlZA==');

@$core.Deprecated('Use pairingDescriptor instead')
const Pairing$json = {
  '1': 'Pairing',
  '2': [
    {'1': 'expires', '3': 1, '4': 1, '5': 3, '10': 'expires'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'code', '3': 3, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `Pairing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pairingDescriptor = $convert.base64Decode(
    'CgdQYWlyaW5nEhgKB2V4cGlyZXMYASABKANSB2V4cGlyZXMSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'ISCgRjb2RlGAMgASgJUgRjb2Rl');

@$core.Deprecated('Use getRemoteRequestDescriptor instead')
const GetRemoteRequest$json = {
  '1': 'GetRemoteRequest',
};

/// Descriptor for `GetRemoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRemoteRequestDescriptor =
    $convert.base64Decode('ChBHZXRSZW1vdGVSZXF1ZXN0');

@$core.Deprecated('Use getRemoteResponseDescriptor instead')
const GetRemoteResponse$json = {
  '1': 'GetRemoteResponse',
  '2': [
    {
      '1': 'remote',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Remote',
      '10': 'remote'
    },
  ],
};

/// Descriptor for `GetRemoteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRemoteResponseDescriptor = $convert.base64Decode(
    'ChFHZXRSZW1vdGVSZXNwb25zZRIoCgZyZW1vdGUYASABKAsyEC5udXNoaS52MS5SZW1vdGVSBn'
    'JlbW90ZQ==');

@$core.Deprecated('Use setRemoteRequestDescriptor instead')
const SetRemoteRequest$json = {
  '1': 'SetRemoteRequest',
  '2': [
    {'1': 'on', '3': 1, '4': 1, '5': 8, '10': 'on'},
    {'1': 'relay', '3': 2, '4': 1, '5': 9, '10': 'relay'},
  ],
};

/// Descriptor for `SetRemoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRemoteRequestDescriptor = $convert.base64Decode(
    'ChBTZXRSZW1vdGVSZXF1ZXN0Eg4KAm9uGAEgASgIUgJvbhIUCgVyZWxheRgCIAEoCVIFcmVsYX'
    'k=');

@$core.Deprecated('Use setRemoteResponseDescriptor instead')
const SetRemoteResponse$json = {
  '1': 'SetRemoteResponse',
};

/// Descriptor for `SetRemoteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setRemoteResponseDescriptor =
    $convert.base64Decode('ChFTZXRSZW1vdGVSZXNwb25zZQ==');

@$core.Deprecated('Use startPairingRequestDescriptor instead')
const StartPairingRequest$json = {
  '1': 'StartPairingRequest',
};

/// Descriptor for `StartPairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startPairingRequestDescriptor =
    $convert.base64Decode('ChNTdGFydFBhaXJpbmdSZXF1ZXN0');

@$core.Deprecated('Use startPairingResponseDescriptor instead')
const StartPairingResponse$json = {
  '1': 'StartPairingResponse',
  '2': [
    {'1': 'qr', '3': 1, '4': 1, '5': 9, '10': 'qr'},
    {'1': 'expires', '3': 2, '4': 1, '5': 3, '10': 'expires'},
  ],
};

/// Descriptor for `StartPairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startPairingResponseDescriptor = $convert.base64Decode(
    'ChRTdGFydFBhaXJpbmdSZXNwb25zZRIOCgJxchgBIAEoCVICcXISGAoHZXhwaXJlcxgCIAEoA1'
    'IHZXhwaXJlcw==');

@$core.Deprecated('Use confirmPairingRequestDescriptor instead')
const ConfirmPairingRequest$json = {
  '1': 'ConfirmPairingRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'allow', '3': 2, '4': 1, '5': 8, '10': 'allow'},
  ],
};

/// Descriptor for `ConfirmPairingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmPairingRequestDescriptor = $convert.base64Decode(
    'ChVDb25maXJtUGFpcmluZ1JlcXVlc3QSEgoEY29kZRgBIAEoCVIEY29kZRIUCgVhbGxvdxgCIA'
    'EoCFIFYWxsb3c=');

@$core.Deprecated('Use confirmPairingResponseDescriptor instead')
const ConfirmPairingResponse$json = {
  '1': 'ConfirmPairingResponse',
};

/// Descriptor for `ConfirmPairingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List confirmPairingResponseDescriptor =
    $convert.base64Decode('ChZDb25maXJtUGFpcmluZ1Jlc3BvbnNl');

@$core.Deprecated('Use revokeDeviceRequestDescriptor instead')
const RevokeDeviceRequest$json = {
  '1': 'RevokeDeviceRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `RevokeDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeDeviceRequestDescriptor = $convert
    .base64Decode('ChNSZXZva2VEZXZpY2VSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use revokeDeviceResponseDescriptor instead')
const RevokeDeviceResponse$json = {
  '1': 'RevokeDeviceResponse',
};

/// Descriptor for `RevokeDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revokeDeviceResponseDescriptor =
    $convert.base64Decode('ChRSZXZva2VEZXZpY2VSZXNwb25zZQ==');

@$core.Deprecated('Use logRequestDescriptor instead')
const LogRequest$json = {
  '1': 'LogRequest',
  '2': [
    {'1': 'level', '3': 1, '4': 1, '5': 9, '10': 'level'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'stack', '3': 3, '4': 1, '5': 9, '10': 'stack'},
    {
      '1': 'attrs',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.LogRequest.AttrsEntry',
      '10': 'attrs'
    },
  ],
  '3': [LogRequest_AttrsEntry$json],
};

@$core.Deprecated('Use logRequestDescriptor instead')
const LogRequest_AttrsEntry$json = {
  '1': 'AttrsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `LogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logRequestDescriptor = $convert.base64Decode(
    'CgpMb2dSZXF1ZXN0EhQKBWxldmVsGAEgASgJUgVsZXZlbBIYCgdtZXNzYWdlGAIgASgJUgdtZX'
    'NzYWdlEhQKBXN0YWNrGAMgASgJUgVzdGFjaxI1CgVhdHRycxgEIAMoCzIfLm51c2hpLnYxLkxv'
    'Z1JlcXVlc3QuQXR0cnNFbnRyeVIFYXR0cnMaOAoKQXR0cnNFbnRyeRIQCgNrZXkYASABKAlSA2'
    'tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use logResponseDescriptor instead')
const LogResponse$json = {
  '1': 'LogResponse',
};

/// Descriptor for `LogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logResponseDescriptor =
    $convert.base64Decode('CgtMb2dSZXNwb25zZQ==');

@$core.Deprecated('Use jiraSiteDescriptor instead')
const JiraSite$json = {
  '1': 'JiraSite',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '10': 'email'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'account_id', '3': 5, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'scoped', '3': 6, '4': 1, '5': 8, '10': 'scoped'},
    {'1': 'expires', '3': 7, '4': 1, '5': 3, '10': 'expires'},
    {'1': 'board', '3': 8, '4': 1, '5': 3, '10': 'board'},
    {'1': 'board_name', '3': 9, '4': 1, '5': 9, '10': 'boardName'},
    {
      '1': 'searches',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraSearch',
      '10': 'searches'
    },
    {'1': 'problem', '3': 11, '4': 1, '5': 9, '10': 'problem'},
    {'1': 'needs_ok', '3': 12, '4': 1, '5': 8, '10': 'needsOk'},
  ],
};

/// Descriptor for `JiraSite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraSiteDescriptor = $convert.base64Decode(
    'CghKaXJhU2l0ZRIOCgJpZBgBIAEoCVICaWQSEAoDdXJsGAIgASgJUgN1cmwSFAoFZW1haWwYAy'
    'ABKAlSBWVtYWlsEhIKBG5hbWUYBCABKAlSBG5hbWUSHQoKYWNjb3VudF9pZBgFIAEoCVIJYWNj'
    'b3VudElkEhYKBnNjb3BlZBgGIAEoCFIGc2NvcGVkEhgKB2V4cGlyZXMYByABKANSB2V4cGlyZX'
    'MSFAoFYm9hcmQYCCABKANSBWJvYXJkEh0KCmJvYXJkX25hbWUYCSABKAlSCWJvYXJkTmFtZRIw'
    'CghzZWFyY2hlcxgKIAMoCzIULm51c2hpLnYxLkppcmFTZWFyY2hSCHNlYXJjaGVzEhgKB3Byb2'
    'JsZW0YCyABKAlSB3Byb2JsZW0SGQoIbmVlZHNfb2sYDCABKAhSB25lZWRzT2s=');

@$core.Deprecated('Use jiraSearchDescriptor instead')
const JiraSearch$json = {
  '1': 'JiraSearch',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'jql', '3': 2, '4': 1, '5': 9, '10': 'jql'},
  ],
};

/// Descriptor for `JiraSearch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraSearchDescriptor = $convert.base64Decode(
    'CgpKaXJhU2VhcmNoEhIKBG5hbWUYASABKAlSBG5hbWUSEAoDanFsGAIgASgJUgNqcWw=');

@$core.Deprecated('Use jiraIssueRefDescriptor instead')
const JiraIssueRef$json = {
  '1': 'JiraIssueRef',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'summary', '3': 2, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
    {'1': 'status_category', '3': 5, '4': 1, '5': 9, '10': 'statusCategory'},
  ],
};

/// Descriptor for `JiraIssueRef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraIssueRefDescriptor = $convert.base64Decode(
    'CgxKaXJhSXNzdWVSZWYSEAoDa2V5GAEgASgJUgNrZXkSGAoHc3VtbWFyeRgCIAEoCVIHc3VtbW'
    'FyeRISCgR0eXBlGAMgASgJUgR0eXBlEhYKBnN0YXR1cxgEIAEoCVIGc3RhdHVzEicKD3N0YXR1'
    'c19jYXRlZ29yeRgFIAEoCVIOc3RhdHVzQ2F0ZWdvcnk=');

@$core.Deprecated('Use jiraIssueDescriptor instead')
const JiraIssue$json = {
  '1': 'JiraIssue',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'summary', '3': 2, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
    {'1': 'status_category', '3': 5, '4': 1, '5': 9, '10': 'statusCategory'},
    {'1': 'priority', '3': 6, '4': 1, '5': 9, '10': 'priority'},
    {'1': 'assignee', '3': 7, '4': 1, '5': 9, '10': 'assignee'},
    {'1': 'updated', '3': 8, '4': 1, '5': 3, '10': 'updated'},
    {'1': 'reporter', '3': 9, '4': 1, '5': 9, '10': 'reporter'},
    {'1': 'created', '3': 10, '4': 1, '5': 3, '10': 'created'},
    {'1': 'labels', '3': 11, '4': 3, '5': 9, '10': 'labels'},
    {'1': 'description', '3': 12, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'acceptance_criteria',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'acceptanceCriteria'
    },
    {
      '1': 'parent',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraIssueRef',
      '10': 'parent'
    },
    {
      '1': 'subtasks',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraIssueRef',
      '10': 'subtasks'
    },
    {
      '1': 'links',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraLink',
      '10': 'links'
    },
    {
      '1': 'attachments',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraAttachment',
      '10': 'attachments'
    },
    {
      '1': 'comments',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraComment',
      '10': 'comments'
    },
    {
      '1': 'remote_links',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraRemoteLink',
      '10': 'remoteLinks'
    },
    {'1': 'url', '3': 20, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `JiraIssue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraIssueDescriptor = $convert.base64Decode(
    'CglKaXJhSXNzdWUSEAoDa2V5GAEgASgJUgNrZXkSGAoHc3VtbWFyeRgCIAEoCVIHc3VtbWFyeR'
    'ISCgR0eXBlGAMgASgJUgR0eXBlEhYKBnN0YXR1cxgEIAEoCVIGc3RhdHVzEicKD3N0YXR1c19j'
    'YXRlZ29yeRgFIAEoCVIOc3RhdHVzQ2F0ZWdvcnkSGgoIcHJpb3JpdHkYBiABKAlSCHByaW9yaX'
    'R5EhoKCGFzc2lnbmVlGAcgASgJUghhc3NpZ25lZRIYCgd1cGRhdGVkGAggASgDUgd1cGRhdGVk'
    'EhoKCHJlcG9ydGVyGAkgASgJUghyZXBvcnRlchIYCgdjcmVhdGVkGAogASgDUgdjcmVhdGVkEh'
    'YKBmxhYmVscxgLIAMoCVIGbGFiZWxzEiAKC2Rlc2NyaXB0aW9uGAwgASgJUgtkZXNjcmlwdGlv'
    'bhIvChNhY2NlcHRhbmNlX2NyaXRlcmlhGA0gASgJUhJhY2NlcHRhbmNlQ3JpdGVyaWESLgoGcG'
    'FyZW50GA4gASgLMhYubnVzaGkudjEuSmlyYUlzc3VlUmVmUgZwYXJlbnQSMgoIc3VidGFza3MY'
    'DyADKAsyFi5udXNoaS52MS5KaXJhSXNzdWVSZWZSCHN1YnRhc2tzEigKBWxpbmtzGBAgAygLMh'
    'IubnVzaGkudjEuSmlyYUxpbmtSBWxpbmtzEjoKC2F0dGFjaG1lbnRzGBEgAygLMhgubnVzaGku'
    'djEuSmlyYUF0dGFjaG1lbnRSC2F0dGFjaG1lbnRzEjEKCGNvbW1lbnRzGBIgAygLMhUubnVzaG'
    'kudjEuSmlyYUNvbW1lbnRSCGNvbW1lbnRzEjsKDHJlbW90ZV9saW5rcxgTIAMoCzIYLm51c2hp'
    'LnYxLkppcmFSZW1vdGVMaW5rUgtyZW1vdGVMaW5rcxIQCgN1cmwYFCABKAlSA3VybA==');

@$core.Deprecated('Use jiraLinkDescriptor instead')
const JiraLink$json = {
  '1': 'JiraLink',
  '2': [
    {'1': 'relation', '3': 1, '4': 1, '5': 9, '10': 'relation'},
    {
      '1': 'issue',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraIssueRef',
      '10': 'issue'
    },
  ],
};

/// Descriptor for `JiraLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraLinkDescriptor = $convert.base64Decode(
    'CghKaXJhTGluaxIaCghyZWxhdGlvbhgBIAEoCVIIcmVsYXRpb24SLAoFaXNzdWUYAiABKAsyFi'
    '5udXNoaS52MS5KaXJhSXNzdWVSZWZSBWlzc3Vl');

@$core.Deprecated('Use jiraAttachmentDescriptor instead')
const JiraAttachment$json = {
  '1': 'JiraAttachment',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'mime_type', '3': 3, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
  ],
};

/// Descriptor for `JiraAttachment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraAttachmentDescriptor = $convert.base64Decode(
    'Cg5KaXJhQXR0YWNobWVudBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIbCg'
    'ltaW1lX3R5cGUYAyABKAlSCG1pbWVUeXBlEhIKBHNpemUYBCABKANSBHNpemU=');

@$core.Deprecated('Use jiraCommentDescriptor instead')
const JiraComment$json = {
  '1': 'JiraComment',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'author', '3': 2, '4': 1, '5': 9, '10': 'author'},
    {'1': 'body', '3': 3, '4': 1, '5': 9, '10': 'body'},
    {'1': 'created', '3': 4, '4': 1, '5': 3, '10': 'created'},
    {'1': 'updated', '3': 5, '4': 1, '5': 3, '10': 'updated'},
  ],
};

/// Descriptor for `JiraComment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraCommentDescriptor = $convert.base64Decode(
    'CgtKaXJhQ29tbWVudBIOCgJpZBgBIAEoCVICaWQSFgoGYXV0aG9yGAIgASgJUgZhdXRob3ISEg'
    'oEYm9keRgDIAEoCVIEYm9keRIYCgdjcmVhdGVkGAQgASgDUgdjcmVhdGVkEhgKB3VwZGF0ZWQY'
    'BSABKANSB3VwZGF0ZWQ=');

@$core.Deprecated('Use jiraRemoteLinkDescriptor instead')
const JiraRemoteLink$json = {
  '1': 'JiraRemoteLink',
  '2': [
    {'1': 'title', '3': 1, '4': 1, '5': 9, '10': 'title'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
  ],
};

/// Descriptor for `JiraRemoteLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraRemoteLinkDescriptor = $convert.base64Decode(
    'Cg5KaXJhUmVtb3RlTGluaxIUCgV0aXRsZRgBIAEoCVIFdGl0bGUSEAoDdXJsGAIgASgJUgN1cm'
    'w=');

@$core.Deprecated('Use jiraTransitionDescriptor instead')
const JiraTransition$json = {
  '1': 'JiraTransition',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'to', '3': 3, '4': 1, '5': 9, '10': 'to'},
    {'1': 'to_category', '3': 4, '4': 1, '5': 9, '10': 'toCategory'},
    {
      '1': 'fields',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraField',
      '10': 'fields'
    },
  ],
};

/// Descriptor for `JiraTransition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraTransitionDescriptor = $convert.base64Decode(
    'Cg5KaXJhVHJhbnNpdGlvbhIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIOCg'
    'J0bxgDIAEoCVICdG8SHwoLdG9fY2F0ZWdvcnkYBCABKAlSCnRvQ2F0ZWdvcnkSKwoGZmllbGRz'
    'GAUgAygLMhMubnVzaGkudjEuSmlyYUZpZWxkUgZmaWVsZHM=');

@$core.Deprecated('Use jiraFieldDescriptor instead')
const JiraField$json = {
  '1': 'JiraField',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'type', '3': 3, '4': 1, '5': 9, '10': 'type'},
    {'1': 'required', '3': 4, '4': 1, '5': 8, '10': 'required'},
    {
      '1': 'options',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraOption',
      '10': 'options'
    },
  ],
};

/// Descriptor for `JiraField`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraFieldDescriptor = $convert.base64Decode(
    'CglKaXJhRmllbGQSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSEgoEdHlwZR'
    'gDIAEoCVIEdHlwZRIaCghyZXF1aXJlZBgEIAEoCFIIcmVxdWlyZWQSLgoHb3B0aW9ucxgFIAMo'
    'CzIULm51c2hpLnYxLkppcmFPcHRpb25SB29wdGlvbnM=');

@$core.Deprecated('Use jiraOptionDescriptor instead')
const JiraOption$json = {
  '1': 'JiraOption',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `JiraOption`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraOptionDescriptor = $convert.base64Decode(
    'CgpKaXJhT3B0aW9uEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1l');

@$core.Deprecated('Use jiraBoardDescriptor instead')
const JiraBoard$json = {
  '1': 'JiraBoard',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'project', '3': 3, '4': 1, '5': 9, '10': 'project'},
  ],
};

/// Descriptor for `JiraBoard`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraBoardDescriptor = $convert.base64Decode(
    'CglKaXJhQm9hcmQSDgoCaWQYASABKANSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSGAoHcHJvam'
    'VjdBgDIAEoCVIHcHJvamVjdA==');

@$core.Deprecated('Use listJiraSitesRequestDescriptor instead')
const ListJiraSitesRequest$json = {
  '1': 'ListJiraSitesRequest',
};

/// Descriptor for `ListJiraSitesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraSitesRequestDescriptor =
    $convert.base64Decode('ChRMaXN0SmlyYVNpdGVzUmVxdWVzdA==');

@$core.Deprecated('Use listJiraSitesResponseDescriptor instead')
const ListJiraSitesResponse$json = {
  '1': 'ListJiraSitesResponse',
  '2': [
    {
      '1': 'sites',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraSite',
      '10': 'sites'
    },
  ],
};

/// Descriptor for `ListJiraSitesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraSitesResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0SmlyYVNpdGVzUmVzcG9uc2USKAoFc2l0ZXMYASADKAsyEi5udXNoaS52MS5KaXJhU2'
    'l0ZVIFc2l0ZXM=');

@$core.Deprecated('Use addJiraSiteRequestDescriptor instead')
const AddJiraSiteRequest$json = {
  '1': 'AddJiraSiteRequest',
  '2': [
    {'1': 'url', '3': 1, '4': 1, '5': 9, '10': 'url'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
    {'1': 'token', '3': 3, '4': 1, '5': 9, '10': 'token'},
    {'1': 'expires', '3': 4, '4': 1, '5': 3, '10': 'expires'},
  ],
};

/// Descriptor for `AddJiraSiteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addJiraSiteRequestDescriptor = $convert.base64Decode(
    'ChJBZGRKaXJhU2l0ZVJlcXVlc3QSEAoDdXJsGAEgASgJUgN1cmwSFAoFZW1haWwYAiABKAlSBW'
    'VtYWlsEhQKBXRva2VuGAMgASgJUgV0b2tlbhIYCgdleHBpcmVzGAQgASgDUgdleHBpcmVz');

@$core.Deprecated('Use addJiraSiteResponseDescriptor instead')
const AddJiraSiteResponse$json = {
  '1': 'AddJiraSiteResponse',
  '2': [
    {
      '1': 'site',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraSite',
      '10': 'site'
    },
  ],
};

/// Descriptor for `AddJiraSiteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addJiraSiteResponseDescriptor = $convert.base64Decode(
    'ChNBZGRKaXJhU2l0ZVJlc3BvbnNlEiYKBHNpdGUYASABKAsyEi5udXNoaS52MS5KaXJhU2l0ZV'
    'IEc2l0ZQ==');

@$core.Deprecated('Use removeJiraSiteRequestDescriptor instead')
const RemoveJiraSiteRequest$json = {
  '1': 'RemoveJiraSiteRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
  ],
};

/// Descriptor for `RemoveJiraSiteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeJiraSiteRequestDescriptor =
    $convert.base64Decode(
        'ChVSZW1vdmVKaXJhU2l0ZVJlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZQ==');

@$core.Deprecated('Use removeJiraSiteResponseDescriptor instead')
const RemoveJiraSiteResponse$json = {
  '1': 'RemoveJiraSiteResponse',
};

/// Descriptor for `RemoveJiraSiteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeJiraSiteResponseDescriptor =
    $convert.base64Decode('ChZSZW1vdmVKaXJhU2l0ZVJlc3BvbnNl');

@$core.Deprecated('Use checkJiraSiteRequestDescriptor instead')
const CheckJiraSiteRequest$json = {
  '1': 'CheckJiraSiteRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
  ],
};

/// Descriptor for `CheckJiraSiteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkJiraSiteRequestDescriptor = $convert
    .base64Decode('ChRDaGVja0ppcmFTaXRlUmVxdWVzdBISCgRzaXRlGAEgASgJUgRzaXRl');

@$core.Deprecated('Use checkJiraSiteResponseDescriptor instead')
const CheckJiraSiteResponse$json = {
  '1': 'CheckJiraSiteResponse',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CheckJiraSiteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkJiraSiteResponseDescriptor =
    $convert.base64Decode(
        'ChVDaGVja0ppcmFTaXRlUmVzcG9uc2USEgoEbmFtZRgBIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use allowJiraTokenRequestDescriptor instead')
const AllowJiraTokenRequest$json = {
  '1': 'AllowJiraTokenRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
  ],
};

/// Descriptor for `AllowJiraTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List allowJiraTokenRequestDescriptor =
    $convert.base64Decode(
        'ChVBbGxvd0ppcmFUb2tlblJlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZQ==');

@$core.Deprecated('Use allowJiraTokenResponseDescriptor instead')
const AllowJiraTokenResponse$json = {
  '1': 'AllowJiraTokenResponse',
};

/// Descriptor for `AllowJiraTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List allowJiraTokenResponseDescriptor =
    $convert.base64Decode('ChZBbGxvd0ppcmFUb2tlblJlc3BvbnNl');

@$core.Deprecated('Use listJiraBoardsRequestDescriptor instead')
const ListJiraBoardsRequest$json = {
  '1': 'ListJiraBoardsRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
  ],
};

/// Descriptor for `ListJiraBoardsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraBoardsRequestDescriptor =
    $convert.base64Decode(
        'ChVMaXN0SmlyYUJvYXJkc1JlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZQ==');

@$core.Deprecated('Use listJiraBoardsResponseDescriptor instead')
const ListJiraBoardsResponse$json = {
  '1': 'ListJiraBoardsResponse',
  '2': [
    {
      '1': 'boards',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraBoard',
      '10': 'boards'
    },
  ],
};

/// Descriptor for `ListJiraBoardsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraBoardsResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0SmlyYUJvYXJkc1Jlc3BvbnNlEisKBmJvYXJkcxgBIAMoCzITLm51c2hpLnYxLkppcm'
        'FCb2FyZFIGYm9hcmRz');

@$core.Deprecated('Use setJiraBoardRequestDescriptor instead')
const SetJiraBoardRequest$json = {
  '1': 'SetJiraBoardRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {
      '1': 'board',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraBoard',
      '10': 'board'
    },
  ],
};

/// Descriptor for `SetJiraBoardRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setJiraBoardRequestDescriptor = $convert.base64Decode(
    'ChNTZXRKaXJhQm9hcmRSZXF1ZXN0EhIKBHNpdGUYASABKAlSBHNpdGUSKQoFYm9hcmQYAiABKA'
    'syEy5udXNoaS52MS5KaXJhQm9hcmRSBWJvYXJk');

@$core.Deprecated('Use setJiraBoardResponseDescriptor instead')
const SetJiraBoardResponse$json = {
  '1': 'SetJiraBoardResponse',
};

/// Descriptor for `SetJiraBoardResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setJiraBoardResponseDescriptor =
    $convert.base64Decode('ChRTZXRKaXJhQm9hcmRSZXNwb25zZQ==');

@$core.Deprecated('Use setJiraSearchesRequestDescriptor instead')
const SetJiraSearchesRequest$json = {
  '1': 'SetJiraSearchesRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {
      '1': 'searches',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraSearch',
      '10': 'searches'
    },
  ],
};

/// Descriptor for `SetJiraSearchesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setJiraSearchesRequestDescriptor =
    $convert.base64Decode(
        'ChZTZXRKaXJhU2VhcmNoZXNSZXF1ZXN0EhIKBHNpdGUYASABKAlSBHNpdGUSMAoIc2VhcmNoZX'
        'MYAiADKAsyFC5udXNoaS52MS5KaXJhU2VhcmNoUghzZWFyY2hlcw==');

@$core.Deprecated('Use setJiraSearchesResponseDescriptor instead')
const SetJiraSearchesResponse$json = {
  '1': 'SetJiraSearchesResponse',
};

/// Descriptor for `SetJiraSearchesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setJiraSearchesResponseDescriptor =
    $convert.base64Decode('ChdTZXRKaXJhU2VhcmNoZXNSZXNwb25zZQ==');

@$core.Deprecated('Use listJiraIssuesRequestDescriptor instead')
const ListJiraIssuesRequest$json = {
  '1': 'ListJiraIssuesRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'list', '3': 2, '4': 1, '5': 9, '10': 'list'},
    {'1': 'jql', '3': 3, '4': 1, '5': 9, '10': 'jql'},
  ],
};

/// Descriptor for `ListJiraIssuesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraIssuesRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0SmlyYUlzc3Vlc1JlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZRISCgRsaXN0GAIgAS'
    'gJUgRsaXN0EhAKA2pxbBgDIAEoCVIDanFs');

@$core.Deprecated('Use listJiraIssuesResponseDescriptor instead')
const ListJiraIssuesResponse$json = {
  '1': 'ListJiraIssuesResponse',
  '2': [
    {
      '1': 'issues',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraIssue',
      '10': 'issues'
    },
    {'1': 'sprint', '3': 2, '4': 1, '5': 9, '10': 'sprint'},
  ],
};

/// Descriptor for `ListJiraIssuesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraIssuesResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0SmlyYUlzc3Vlc1Jlc3BvbnNlEisKBmlzc3VlcxgBIAMoCzITLm51c2hpLnYxLkppcm'
        'FJc3N1ZVIGaXNzdWVzEhYKBnNwcmludBgCIAEoCVIGc3ByaW50');

@$core.Deprecated('Use getJiraJqlRequestDescriptor instead')
const GetJiraJqlRequest$json = {
  '1': 'GetJiraJqlRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
  ],
};

/// Descriptor for `GetJiraJqlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraJqlRequestDescriptor = $convert
    .base64Decode('ChFHZXRKaXJhSnFsUmVxdWVzdBISCgRzaXRlGAEgASgJUgRzaXRl');

@$core.Deprecated('Use getJiraJqlResponseDescriptor instead')
const GetJiraJqlResponse$json = {
  '1': 'GetJiraJqlResponse',
  '2': [
    {
      '1': 'fields',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraJqlField',
      '10': 'fields'
    },
    {'1': 'functions', '3': 2, '4': 3, '5': 9, '10': 'functions'},
    {'1': 'words', '3': 3, '4': 3, '5': 9, '10': 'words'},
  ],
};

/// Descriptor for `GetJiraJqlResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraJqlResponseDescriptor = $convert.base64Decode(
    'ChJHZXRKaXJhSnFsUmVzcG9uc2USLgoGZmllbGRzGAEgAygLMhYubnVzaGkudjEuSmlyYUpxbE'
    'ZpZWxkUgZmaWVsZHMSHAoJZnVuY3Rpb25zGAIgAygJUglmdW5jdGlvbnMSFAoFd29yZHMYAyAD'
    'KAlSBXdvcmRz');

@$core.Deprecated('Use jiraJqlFieldDescriptor instead')
const JiraJqlField$json = {
  '1': 'JiraJqlField',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'display', '3': 2, '4': 1, '5': 9, '10': 'display'},
    {'1': 'operators', '3': 3, '4': 3, '5': 9, '10': 'operators'},
  ],
};

/// Descriptor for `JiraJqlField`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraJqlFieldDescriptor = $convert.base64Decode(
    'CgxKaXJhSnFsRmllbGQSEgoEbmFtZRgBIAEoCVIEbmFtZRIYCgdkaXNwbGF5GAIgASgJUgdkaX'
    'NwbGF5EhwKCW9wZXJhdG9ycxgDIAMoCVIJb3BlcmF0b3Jz');

@$core.Deprecated('Use suggestJiraJqlRequestDescriptor instead')
const SuggestJiraJqlRequest$json = {
  '1': 'SuggestJiraJqlRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'field_name', '3': 2, '4': 1, '5': 9, '10': 'fieldName'},
    {'1': 'prefix', '3': 3, '4': 1, '5': 9, '10': 'prefix'},
  ],
};

/// Descriptor for `SuggestJiraJqlRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List suggestJiraJqlRequestDescriptor = $convert.base64Decode(
    'ChVTdWdnZXN0SmlyYUpxbFJlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZRIdCgpmaWVsZF9uYW'
    '1lGAIgASgJUglmaWVsZE5hbWUSFgoGcHJlZml4GAMgASgJUgZwcmVmaXg=');

@$core.Deprecated('Use suggestJiraJqlResponseDescriptor instead')
const SuggestJiraJqlResponse$json = {
  '1': 'SuggestJiraJqlResponse',
  '2': [
    {
      '1': 'values',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraOption',
      '10': 'values'
    },
  ],
};

/// Descriptor for `SuggestJiraJqlResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List suggestJiraJqlResponseDescriptor =
    $convert.base64Decode(
        'ChZTdWdnZXN0SmlyYUpxbFJlc3BvbnNlEiwKBnZhbHVlcxgBIAMoCzIULm51c2hpLnYxLkppcm'
        'FPcHRpb25SBnZhbHVlcw==');

@$core.Deprecated('Use getJiraIssueRequestDescriptor instead')
const GetJiraIssueRequest$json = {
  '1': 'GetJiraIssueRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'key', '3': 2, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `GetJiraIssueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraIssueRequestDescriptor = $convert.base64Decode(
    'ChNHZXRKaXJhSXNzdWVSZXF1ZXN0EhIKBHNpdGUYASABKAlSBHNpdGUSEAoDa2V5GAIgASgJUg'
    'NrZXk=');

@$core.Deprecated('Use getJiraIssueResponseDescriptor instead')
const GetJiraIssueResponse$json = {
  '1': 'GetJiraIssueResponse',
  '2': [
    {
      '1': 'issue',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraIssue',
      '10': 'issue'
    },
  ],
};

/// Descriptor for `GetJiraIssueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraIssueResponseDescriptor = $convert.base64Decode(
    'ChRHZXRKaXJhSXNzdWVSZXNwb25zZRIpCgVpc3N1ZRgBIAEoCzITLm51c2hpLnYxLkppcmFJc3'
    'N1ZVIFaXNzdWU=');

@$core.Deprecated('Use listJiraTransitionsRequestDescriptor instead')
const ListJiraTransitionsRequest$json = {
  '1': 'ListJiraTransitionsRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'key', '3': 2, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `ListJiraTransitionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraTransitionsRequestDescriptor =
    $convert.base64Decode(
        'ChpMaXN0SmlyYVRyYW5zaXRpb25zUmVxdWVzdBISCgRzaXRlGAEgASgJUgRzaXRlEhAKA2tleR'
        'gCIAEoCVIDa2V5');

@$core.Deprecated('Use listJiraTransitionsResponseDescriptor instead')
const ListJiraTransitionsResponse$json = {
  '1': 'ListJiraTransitionsResponse',
  '2': [
    {
      '1': 'transitions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraTransition',
      '10': 'transitions'
    },
  ],
};

/// Descriptor for `ListJiraTransitionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraTransitionsResponseDescriptor =
    $convert.base64Decode(
        'ChtMaXN0SmlyYVRyYW5zaXRpb25zUmVzcG9uc2USOgoLdHJhbnNpdGlvbnMYASADKAsyGC5udX'
        'NoaS52MS5KaXJhVHJhbnNpdGlvblILdHJhbnNpdGlvbnM=');

@$core.Deprecated('Use transitionJiraIssueRequestDescriptor instead')
const TransitionJiraIssueRequest$json = {
  '1': 'TransitionJiraIssueRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'key', '3': 2, '4': 1, '5': 9, '10': 'key'},
    {'1': 'transition', '3': 3, '4': 1, '5': 9, '10': 'transition'},
    {
      '1': 'values',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.TransitionJiraIssueRequest.ValuesEntry',
      '10': 'values'
    },
  ],
  '3': [TransitionJiraIssueRequest_ValuesEntry$json],
};

@$core.Deprecated('Use transitionJiraIssueRequestDescriptor instead')
const TransitionJiraIssueRequest_ValuesEntry$json = {
  '1': 'ValuesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TransitionJiraIssueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transitionJiraIssueRequestDescriptor = $convert.base64Decode(
    'ChpUcmFuc2l0aW9uSmlyYUlzc3VlUmVxdWVzdBISCgRzaXRlGAEgASgJUgRzaXRlEhAKA2tleR'
    'gCIAEoCVIDa2V5Eh4KCnRyYW5zaXRpb24YAyABKAlSCnRyYW5zaXRpb24SSAoGdmFsdWVzGAQg'
    'AygLMjAubnVzaGkudjEuVHJhbnNpdGlvbkppcmFJc3N1ZVJlcXVlc3QuVmFsdWVzRW50cnlSBn'
    'ZhbHVlcxo5CgtWYWx1ZXNFbnRyeRIQCgNrZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIF'
    'dmFsdWU6AjgB');

@$core.Deprecated('Use transitionJiraIssueResponseDescriptor instead')
const TransitionJiraIssueResponse$json = {
  '1': 'TransitionJiraIssueResponse',
};

/// Descriptor for `TransitionJiraIssueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transitionJiraIssueResponseDescriptor =
    $convert.base64Decode('ChtUcmFuc2l0aW9uSmlyYUlzc3VlUmVzcG9uc2U=');

@$core.Deprecated('Use addJiraCommentRequestDescriptor instead')
const AddJiraCommentRequest$json = {
  '1': 'AddJiraCommentRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'key', '3': 2, '4': 1, '5': 9, '10': 'key'},
    {'1': 'markdown', '3': 3, '4': 1, '5': 9, '10': 'markdown'},
  ],
};

/// Descriptor for `AddJiraCommentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addJiraCommentRequestDescriptor = $convert.base64Decode(
    'ChVBZGRKaXJhQ29tbWVudFJlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZRIQCgNrZXkYAiABKA'
    'lSA2tleRIaCghtYXJrZG93bhgDIAEoCVIIbWFya2Rvd24=');

@$core.Deprecated('Use addJiraCommentResponseDescriptor instead')
const AddJiraCommentResponse$json = {
  '1': 'AddJiraCommentResponse',
  '2': [
    {
      '1': 'comment',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraComment',
      '10': 'comment'
    },
  ],
};

/// Descriptor for `AddJiraCommentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addJiraCommentResponseDescriptor =
    $convert.base64Decode(
        'ChZBZGRKaXJhQ29tbWVudFJlc3BvbnNlEi8KB2NvbW1lbnQYASABKAsyFS5udXNoaS52MS5KaX'
        'JhQ29tbWVudFIHY29tbWVudA==');

@$core.Deprecated('Use getJiraAttachmentRequestDescriptor instead')
const GetJiraAttachmentRequest$json = {
  '1': 'GetJiraAttachmentRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'thumbnail', '3': 3, '4': 1, '5': 8, '10': 'thumbnail'},
  ],
};

/// Descriptor for `GetJiraAttachmentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraAttachmentRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRKaXJhQXR0YWNobWVudFJlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZRIOCgJpZBgCIA'
        'EoCVICaWQSHAoJdGh1bWJuYWlsGAMgASgIUgl0aHVtYm5haWw=');

@$core.Deprecated('Use getJiraAttachmentResponseDescriptor instead')
const GetJiraAttachmentResponse$json = {
  '1': 'GetJiraAttachmentResponse',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'mime_type', '3': 2, '4': 1, '5': 9, '10': 'mimeType'},
  ],
};

/// Descriptor for `GetJiraAttachmentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraAttachmentResponseDescriptor =
    $convert.base64Decode(
        'ChlHZXRKaXJhQXR0YWNobWVudFJlc3BvbnNlEhIKBGRhdGEYASABKAxSBGRhdGESGwoJbWltZV'
        '90eXBlGAIgASgJUghtaW1lVHlwZQ==');

@$core.Deprecated('Use getJiraContextRequestDescriptor instead')
const GetJiraContextRequest$json = {
  '1': 'GetJiraContextRequest',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {'1': 'key', '3': 2, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `GetJiraContextRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraContextRequestDescriptor = $convert.base64Decode(
    'ChVHZXRKaXJhQ29udGV4dFJlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZRIQCgNrZXkYAiABKA'
    'lSA2tleQ==');

@$core.Deprecated('Use getJiraContextResponseDescriptor instead')
const GetJiraContextResponse$json = {
  '1': 'GetJiraContextResponse',
  '2': [
    {'1': 'markdown', '3': 1, '4': 1, '5': 9, '10': 'markdown'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
  ],
};

/// Descriptor for `GetJiraContextResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraContextResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRKaXJhQ29udGV4dFJlc3BvbnNlEhoKCG1hcmtkb3duGAEgASgJUghtYXJrZG93bhIWCg'
        'ZicmFuY2gYAiABKAlSBmJyYW5jaA==');

const $core.Map<$core.String, $core.dynamic> NushiServiceBase$json = {
  '1': 'NushiService',
  '2': [
    {'1': 'Ping', '2': '.nushi.v1.PingRequest', '3': '.nushi.v1.PingResponse'},
    {
      '1': 'ListChats',
      '2': '.nushi.v1.ListChatsRequest',
      '3': '.nushi.v1.ListChatsResponse'
    },
    {
      '1': 'GetChat',
      '2': '.nushi.v1.GetChatRequest',
      '3': '.nushi.v1.GetChatResponse'
    },
    {
      '1': 'StartChat',
      '2': '.nushi.v1.StartChatRequest',
      '3': '.nushi.v1.StartChatResponse'
    },
    {
      '1': 'ListAgents',
      '2': '.nushi.v1.ListAgentsRequest',
      '3': '.nushi.v1.ListAgentsResponse'
    },
    {
      '1': 'SetUpAgent',
      '2': '.nushi.v1.SetUpAgentRequest',
      '3': '.nushi.v1.SetUpAgentResponse'
    },
    {
      '1': 'RemoveAgent',
      '2': '.nushi.v1.RemoveAgentRequest',
      '3': '.nushi.v1.RemoveAgentResponse'
    },
    {
      '1': 'ListAgentSessions',
      '2': '.nushi.v1.ListAgentSessionsRequest',
      '3': '.nushi.v1.ListAgentSessionsResponse'
    },
    {
      '1': 'OpenAgentSession',
      '2': '.nushi.v1.OpenAgentSessionRequest',
      '3': '.nushi.v1.OpenAgentSessionResponse'
    },
    {
      '1': 'MoveChat',
      '2': '.nushi.v1.MoveChatRequest',
      '3': '.nushi.v1.MoveChatResponse'
    },
    {
      '1': 'SendPrompt',
      '2': '.nushi.v1.SendPromptRequest',
      '3': '.nushi.v1.SendPromptResponse'
    },
    {
      '1': 'RewindChat',
      '2': '.nushi.v1.RewindChatRequest',
      '3': '.nushi.v1.RewindChatResponse'
    },
    {
      '1': 'Unqueue',
      '2': '.nushi.v1.UnqueueRequest',
      '3': '.nushi.v1.UnqueueResponse'
    },
    {
      '1': 'CancelTurn',
      '2': '.nushi.v1.CancelTurnRequest',
      '3': '.nushi.v1.CancelTurnResponse'
    },
    {
      '1': 'ForkChat',
      '2': '.nushi.v1.ForkChatRequest',
      '3': '.nushi.v1.ForkChatResponse'
    },
    {
      '1': 'CloseSideChat',
      '2': '.nushi.v1.CloseSideChatRequest',
      '3': '.nushi.v1.CloseSideChatResponse'
    },
    {
      '1': 'RenameChat',
      '2': '.nushi.v1.RenameChatRequest',
      '3': '.nushi.v1.RenameChatResponse'
    },
    {
      '1': 'ArchiveChat',
      '2': '.nushi.v1.ArchiveChatRequest',
      '3': '.nushi.v1.ArchiveChatResponse'
    },
    {
      '1': 'SleepChat',
      '2': '.nushi.v1.SleepChatRequest',
      '3': '.nushi.v1.SleepChatResponse'
    },
    {
      '1': 'GetMemory',
      '2': '.nushi.v1.GetMemoryRequest',
      '3': '.nushi.v1.GetMemoryResponse'
    },
    {
      '1': 'GetSettings',
      '2': '.nushi.v1.GetSettingsRequest',
      '3': '.nushi.v1.GetSettingsResponse'
    },
    {
      '1': 'SetSettings',
      '2': '.nushi.v1.SetSettingsRequest',
      '3': '.nushi.v1.SetSettingsResponse'
    },
    {
      '1': 'PlanDeleteChat',
      '2': '.nushi.v1.PlanDeleteChatRequest',
      '3': '.nushi.v1.PlanDeleteChatResponse'
    },
    {
      '1': 'DeleteChat',
      '2': '.nushi.v1.DeleteChatRequest',
      '3': '.nushi.v1.DeleteChatResponse'
    },
    {
      '1': 'AnswerPermission',
      '2': '.nushi.v1.AnswerPermissionRequest',
      '3': '.nushi.v1.AnswerPermissionResponse'
    },
    {
      '1': 'AnswerQuestion',
      '2': '.nushi.v1.AnswerQuestionRequest',
      '3': '.nushi.v1.AnswerQuestionResponse'
    },
    {
      '1': 'SetConfigOption',
      '2': '.nushi.v1.SetConfigOptionRequest',
      '3': '.nushi.v1.SetConfigOptionResponse'
    },
    {
      '1': 'GetDiff',
      '2': '.nushi.v1.GetDiffRequest',
      '3': '.nushi.v1.GetDiffResponse'
    },
    {
      '1': 'ListCommits',
      '2': '.nushi.v1.ListCommitsRequest',
      '3': '.nushi.v1.ListCommitsResponse'
    },
    {
      '1': 'GetFolderStatus',
      '2': '.nushi.v1.GetFolderStatusRequest',
      '3': '.nushi.v1.GetFolderStatusResponse'
    },
    {
      '1': 'ListFiles',
      '2': '.nushi.v1.ListFilesRequest',
      '3': '.nushi.v1.ListFilesResponse'
    },
    {
      '1': 'GetContextUsage',
      '2': '.nushi.v1.GetContextUsageRequest',
      '3': '.nushi.v1.GetContextUsageResponse'
    },
    {
      '1': 'ListMcpServers',
      '2': '.nushi.v1.ListMcpServersRequest',
      '3': '.nushi.v1.ListMcpServersResponse'
    },
    {
      '1': 'AddMcpServer',
      '2': '.nushi.v1.AddMcpServerRequest',
      '3': '.nushi.v1.AddMcpServerResponse'
    },
    {
      '1': 'EditMcpServer',
      '2': '.nushi.v1.EditMcpServerRequest',
      '3': '.nushi.v1.EditMcpServerResponse'
    },
    {
      '1': 'RemoveMcpServer',
      '2': '.nushi.v1.RemoveMcpServerRequest',
      '3': '.nushi.v1.RemoveMcpServerResponse'
    },
    {
      '1': 'SetMcpServerOn',
      '2': '.nushi.v1.SetMcpServerOnRequest',
      '3': '.nushi.v1.SetMcpServerOnResponse'
    },
    {
      '1': 'LoginMcpServer',
      '2': '.nushi.v1.LoginMcpServerRequest',
      '3': '.nushi.v1.LoginMcpServerResponse'
    },
    {
      '1': 'LogoutMcpServer',
      '2': '.nushi.v1.LogoutMcpServerRequest',
      '3': '.nushi.v1.LogoutMcpServerResponse'
    },
    {
      '1': 'ReloadChat',
      '2': '.nushi.v1.ReloadChatRequest',
      '3': '.nushi.v1.ReloadChatResponse'
    },
    {
      '1': 'OpenTerminal',
      '2': '.nushi.v1.OpenTerminalRequest',
      '3': '.nushi.v1.OpenTerminalResponse'
    },
    {
      '1': 'ListTerminals',
      '2': '.nushi.v1.ListTerminalsRequest',
      '3': '.nushi.v1.ListTerminalsResponse'
    },
    {
      '1': 'AttachTerminal',
      '2': '.nushi.v1.AttachTerminalRequest',
      '3': '.nushi.v1.AttachTerminalResponse',
      '6': true
    },
    {
      '1': 'WriteTerminal',
      '2': '.nushi.v1.WriteTerminalRequest',
      '3': '.nushi.v1.WriteTerminalResponse'
    },
    {
      '1': 'ResizeTerminal',
      '2': '.nushi.v1.ResizeTerminalRequest',
      '3': '.nushi.v1.ResizeTerminalResponse'
    },
    {
      '1': 'RenameTerminal',
      '2': '.nushi.v1.RenameTerminalRequest',
      '3': '.nushi.v1.RenameTerminalResponse'
    },
    {
      '1': 'ArrangeTerminals',
      '2': '.nushi.v1.ArrangeTerminalsRequest',
      '3': '.nushi.v1.ArrangeTerminalsResponse'
    },
    {
      '1': 'RestartTerminal',
      '2': '.nushi.v1.RestartTerminalRequest',
      '3': '.nushi.v1.RestartTerminalResponse'
    },
    {
      '1': 'CloseTerminal',
      '2': '.nushi.v1.CloseTerminalRequest',
      '3': '.nushi.v1.CloseTerminalResponse'
    },
    {
      '1': 'CheckFolder',
      '2': '.nushi.v1.CheckFolderRequest',
      '3': '.nushi.v1.CheckFolderResponse'
    },
    {
      '1': 'TrustFolder',
      '2': '.nushi.v1.TrustFolderRequest',
      '3': '.nushi.v1.TrustFolderResponse'
    },
    {
      '1': 'GetRemote',
      '2': '.nushi.v1.GetRemoteRequest',
      '3': '.nushi.v1.GetRemoteResponse'
    },
    {
      '1': 'SetRemote',
      '2': '.nushi.v1.SetRemoteRequest',
      '3': '.nushi.v1.SetRemoteResponse'
    },
    {
      '1': 'StartPairing',
      '2': '.nushi.v1.StartPairingRequest',
      '3': '.nushi.v1.StartPairingResponse'
    },
    {
      '1': 'ConfirmPairing',
      '2': '.nushi.v1.ConfirmPairingRequest',
      '3': '.nushi.v1.ConfirmPairingResponse'
    },
    {
      '1': 'RevokeDevice',
      '2': '.nushi.v1.RevokeDeviceRequest',
      '3': '.nushi.v1.RevokeDeviceResponse'
    },
    {'1': 'Log', '2': '.nushi.v1.LogRequest', '3': '.nushi.v1.LogResponse'},
    {
      '1': 'ListJiraSites',
      '2': '.nushi.v1.ListJiraSitesRequest',
      '3': '.nushi.v1.ListJiraSitesResponse'
    },
    {
      '1': 'AddJiraSite',
      '2': '.nushi.v1.AddJiraSiteRequest',
      '3': '.nushi.v1.AddJiraSiteResponse'
    },
    {
      '1': 'RemoveJiraSite',
      '2': '.nushi.v1.RemoveJiraSiteRequest',
      '3': '.nushi.v1.RemoveJiraSiteResponse'
    },
    {
      '1': 'CheckJiraSite',
      '2': '.nushi.v1.CheckJiraSiteRequest',
      '3': '.nushi.v1.CheckJiraSiteResponse'
    },
    {
      '1': 'AllowJiraToken',
      '2': '.nushi.v1.AllowJiraTokenRequest',
      '3': '.nushi.v1.AllowJiraTokenResponse'
    },
    {
      '1': 'ListJiraBoards',
      '2': '.nushi.v1.ListJiraBoardsRequest',
      '3': '.nushi.v1.ListJiraBoardsResponse'
    },
    {
      '1': 'SetJiraBoard',
      '2': '.nushi.v1.SetJiraBoardRequest',
      '3': '.nushi.v1.SetJiraBoardResponse'
    },
    {
      '1': 'SetJiraSearches',
      '2': '.nushi.v1.SetJiraSearchesRequest',
      '3': '.nushi.v1.SetJiraSearchesResponse'
    },
    {
      '1': 'ListJiraIssues',
      '2': '.nushi.v1.ListJiraIssuesRequest',
      '3': '.nushi.v1.ListJiraIssuesResponse'
    },
    {
      '1': 'GetJiraJql',
      '2': '.nushi.v1.GetJiraJqlRequest',
      '3': '.nushi.v1.GetJiraJqlResponse'
    },
    {
      '1': 'SuggestJiraJql',
      '2': '.nushi.v1.SuggestJiraJqlRequest',
      '3': '.nushi.v1.SuggestJiraJqlResponse'
    },
    {
      '1': 'GetJiraIssue',
      '2': '.nushi.v1.GetJiraIssueRequest',
      '3': '.nushi.v1.GetJiraIssueResponse'
    },
    {
      '1': 'ListJiraTransitions',
      '2': '.nushi.v1.ListJiraTransitionsRequest',
      '3': '.nushi.v1.ListJiraTransitionsResponse'
    },
    {
      '1': 'TransitionJiraIssue',
      '2': '.nushi.v1.TransitionJiraIssueRequest',
      '3': '.nushi.v1.TransitionJiraIssueResponse'
    },
    {
      '1': 'AddJiraComment',
      '2': '.nushi.v1.AddJiraCommentRequest',
      '3': '.nushi.v1.AddJiraCommentResponse'
    },
    {
      '1': 'GetJiraContext',
      '2': '.nushi.v1.GetJiraContextRequest',
      '3': '.nushi.v1.GetJiraContextResponse'
    },
    {
      '1': 'GetJiraAttachment',
      '2': '.nushi.v1.GetJiraAttachmentRequest',
      '3': '.nushi.v1.GetJiraAttachmentResponse'
    },
    {
      '1': 'Events',
      '2': '.nushi.v1.EventsRequest',
      '3': '.nushi.v1.EventsResponse',
      '6': true
    },
  ],
};

@$core.Deprecated('Use nushiServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    NushiServiceBase$messageJson = {
  '.nushi.v1.PingRequest': PingRequest$json,
  '.nushi.v1.PingResponse': PingResponse$json,
  '.nushi.v1.ListChatsRequest': ListChatsRequest$json,
  '.nushi.v1.ListChatsResponse': ListChatsResponse$json,
  '.nushi.v1.Chat': Chat$json,
  '.nushi.v1.ChatStatus': ChatStatus$json,
  '.nushi.v1.Worktree': Worktree$json,
  '.nushi.v1.GetChatRequest': GetChatRequest$json,
  '.nushi.v1.GetChatResponse': GetChatResponse$json,
  '.nushi.v1.Item': Item$json,
  '.nushi.v1.Option': Option$json,
  '.nushi.v1.Field': Field$json,
  '.nushi.v1.FileChange': FileChange$json,
  '.nushi.v1.PlanEntry': PlanEntry$json,
  '.nushi.v1.ImageData': ImageData$json,
  '.nushi.v1.Subagent': Subagent$json,
  '.nushi.v1.Shell': Shell$json,
  '.nushi.v1.ConfigOption': ConfigOption$json,
  '.nushi.v1.ConfigValue': ConfigValue$json,
  '.nushi.v1.Command': Command$json,
  '.nushi.v1.Usage': Usage$json,
  '.nushi.v1.ChatQueue': ChatQueue$json,
  '.nushi.v1.QueuedMessage': QueuedMessage$json,
  '.nushi.v1.StartChatRequest': StartChatRequest$json,
  '.nushi.v1.StartChatResponse': StartChatResponse$json,
  '.nushi.v1.ListAgentsRequest': ListAgentsRequest$json,
  '.nushi.v1.ListAgentsResponse': ListAgentsResponse$json,
  '.nushi.v1.Agent': Agent$json,
  '.nushi.v1.Adapter': Adapter$json,
  '.nushi.v1.SetUpAgentRequest': SetUpAgentRequest$json,
  '.nushi.v1.SetUpAgentResponse': SetUpAgentResponse$json,
  '.nushi.v1.RemoveAgentRequest': RemoveAgentRequest$json,
  '.nushi.v1.RemoveAgentResponse': RemoveAgentResponse$json,
  '.nushi.v1.ListAgentSessionsRequest': ListAgentSessionsRequest$json,
  '.nushi.v1.ListAgentSessionsResponse': ListAgentSessionsResponse$json,
  '.nushi.v1.FoundSession': FoundSession$json,
  '.nushi.v1.OpenAgentSessionRequest': OpenAgentSessionRequest$json,
  '.nushi.v1.OpenAgentSessionResponse': OpenAgentSessionResponse$json,
  '.nushi.v1.MoveChatRequest': MoveChatRequest$json,
  '.nushi.v1.MoveChatResponse': MoveChatResponse$json,
  '.nushi.v1.SendPromptRequest': SendPromptRequest$json,
  '.nushi.v1.SendPromptResponse': SendPromptResponse$json,
  '.nushi.v1.RewindChatRequest': RewindChatRequest$json,
  '.nushi.v1.RewindChatResponse': RewindChatResponse$json,
  '.nushi.v1.UnqueueRequest': UnqueueRequest$json,
  '.nushi.v1.UnqueueResponse': UnqueueResponse$json,
  '.nushi.v1.CancelTurnRequest': CancelTurnRequest$json,
  '.nushi.v1.CancelTurnResponse': CancelTurnResponse$json,
  '.nushi.v1.ForkChatRequest': ForkChatRequest$json,
  '.nushi.v1.ForkChatResponse': ForkChatResponse$json,
  '.nushi.v1.CloseSideChatRequest': CloseSideChatRequest$json,
  '.nushi.v1.CloseSideChatResponse': CloseSideChatResponse$json,
  '.nushi.v1.RenameChatRequest': RenameChatRequest$json,
  '.nushi.v1.RenameChatResponse': RenameChatResponse$json,
  '.nushi.v1.ArchiveChatRequest': ArchiveChatRequest$json,
  '.nushi.v1.ArchiveChatResponse': ArchiveChatResponse$json,
  '.nushi.v1.SleepChatRequest': SleepChatRequest$json,
  '.nushi.v1.SleepChatResponse': SleepChatResponse$json,
  '.nushi.v1.GetMemoryRequest': GetMemoryRequest$json,
  '.nushi.v1.GetMemoryResponse': GetMemoryResponse$json,
  '.nushi.v1.GetMemoryResponse.ChatsEntry': GetMemoryResponse_ChatsEntry$json,
  '.nushi.v1.GetSettingsRequest': GetSettingsRequest$json,
  '.nushi.v1.GetSettingsResponse': GetSettingsResponse$json,
  '.nushi.v1.Settings': Settings$json,
  '.nushi.v1.SetSettingsRequest': SetSettingsRequest$json,
  '.nushi.v1.SetSettingsResponse': SetSettingsResponse$json,
  '.nushi.v1.PlanDeleteChatRequest': PlanDeleteChatRequest$json,
  '.nushi.v1.PlanDeleteChatResponse': PlanDeleteChatResponse$json,
  '.nushi.v1.AgentSession': AgentSession$json,
  '.nushi.v1.WorktreePlan': WorktreePlan$json,
  '.nushi.v1.WorktreeState': WorktreeState$json,
  '.nushi.v1.Terminal': Terminal$json,
  '.nushi.v1.DeleteChatRequest': DeleteChatRequest$json,
  '.nushi.v1.WorktreeChoice': WorktreeChoice$json,
  '.nushi.v1.DeleteChatResponse': DeleteChatResponse$json,
  '.nushi.v1.AnswerPermissionRequest': AnswerPermissionRequest$json,
  '.nushi.v1.AnswerPermissionResponse': AnswerPermissionResponse$json,
  '.nushi.v1.AnswerQuestionRequest': AnswerQuestionRequest$json,
  '.nushi.v1.FieldAnswer': FieldAnswer$json,
  '.nushi.v1.AnswerQuestionResponse': AnswerQuestionResponse$json,
  '.nushi.v1.SetConfigOptionRequest': SetConfigOptionRequest$json,
  '.nushi.v1.SetConfigOptionResponse': SetConfigOptionResponse$json,
  '.nushi.v1.GetDiffRequest': GetDiffRequest$json,
  '.nushi.v1.GetDiffResponse': GetDiffResponse$json,
  '.nushi.v1.ListCommitsRequest': ListCommitsRequest$json,
  '.nushi.v1.ListCommitsResponse': ListCommitsResponse$json,
  '.nushi.v1.Commit': Commit$json,
  '.nushi.v1.GetFolderStatusRequest': GetFolderStatusRequest$json,
  '.nushi.v1.GetFolderStatusResponse': GetFolderStatusResponse$json,
  '.nushi.v1.ListFilesRequest': ListFilesRequest$json,
  '.nushi.v1.ListFilesResponse': ListFilesResponse$json,
  '.nushi.v1.GetContextUsageRequest': GetContextUsageRequest$json,
  '.nushi.v1.GetContextUsageResponse': GetContextUsageResponse$json,
  '.nushi.v1.ContextCategory': ContextCategory$json,
  '.nushi.v1.ListMcpServersRequest': ListMcpServersRequest$json,
  '.nushi.v1.ListMcpServersResponse': ListMcpServersResponse$json,
  '.nushi.v1.McpServer': McpServer$json,
  '.nushi.v1.AddMcpServerRequest': AddMcpServerRequest$json,
  '.nushi.v1.AddMcpServerResponse': AddMcpServerResponse$json,
  '.nushi.v1.EditMcpServerRequest': EditMcpServerRequest$json,
  '.nushi.v1.EditMcpServerResponse': EditMcpServerResponse$json,
  '.nushi.v1.RemoveMcpServerRequest': RemoveMcpServerRequest$json,
  '.nushi.v1.RemoveMcpServerResponse': RemoveMcpServerResponse$json,
  '.nushi.v1.SetMcpServerOnRequest': SetMcpServerOnRequest$json,
  '.nushi.v1.SetMcpServerOnResponse': SetMcpServerOnResponse$json,
  '.nushi.v1.LoginMcpServerRequest': LoginMcpServerRequest$json,
  '.nushi.v1.LoginMcpServerResponse': LoginMcpServerResponse$json,
  '.nushi.v1.LogoutMcpServerRequest': LogoutMcpServerRequest$json,
  '.nushi.v1.LogoutMcpServerResponse': LogoutMcpServerResponse$json,
  '.nushi.v1.ReloadChatRequest': ReloadChatRequest$json,
  '.nushi.v1.ReloadChatResponse': ReloadChatResponse$json,
  '.nushi.v1.OpenTerminalRequest': OpenTerminalRequest$json,
  '.nushi.v1.OpenTerminalResponse': OpenTerminalResponse$json,
  '.nushi.v1.ListTerminalsRequest': ListTerminalsRequest$json,
  '.nushi.v1.ListTerminalsResponse': ListTerminalsResponse$json,
  '.nushi.v1.AttachTerminalRequest': AttachTerminalRequest$json,
  '.nushi.v1.AttachTerminalResponse': AttachTerminalResponse$json,
  '.nushi.v1.WriteTerminalRequest': WriteTerminalRequest$json,
  '.nushi.v1.WriteTerminalResponse': WriteTerminalResponse$json,
  '.nushi.v1.ResizeTerminalRequest': ResizeTerminalRequest$json,
  '.nushi.v1.ResizeTerminalResponse': ResizeTerminalResponse$json,
  '.nushi.v1.RenameTerminalRequest': RenameTerminalRequest$json,
  '.nushi.v1.RenameTerminalResponse': RenameTerminalResponse$json,
  '.nushi.v1.ArrangeTerminalsRequest': ArrangeTerminalsRequest$json,
  '.nushi.v1.ArrangeTerminalsResponse': ArrangeTerminalsResponse$json,
  '.nushi.v1.RestartTerminalRequest': RestartTerminalRequest$json,
  '.nushi.v1.RestartTerminalResponse': RestartTerminalResponse$json,
  '.nushi.v1.CloseTerminalRequest': CloseTerminalRequest$json,
  '.nushi.v1.CloseTerminalResponse': CloseTerminalResponse$json,
  '.nushi.v1.CheckFolderRequest': CheckFolderRequest$json,
  '.nushi.v1.CheckFolderResponse': CheckFolderResponse$json,
  '.nushi.v1.FolderRun': FolderRun$json,
  '.nushi.v1.TrustFolderRequest': TrustFolderRequest$json,
  '.nushi.v1.TrustFolderResponse': TrustFolderResponse$json,
  '.nushi.v1.GetRemoteRequest': GetRemoteRequest$json,
  '.nushi.v1.GetRemoteResponse': GetRemoteResponse$json,
  '.nushi.v1.Remote': Remote$json,
  '.nushi.v1.Device': Device$json,
  '.nushi.v1.Pairing': Pairing$json,
  '.nushi.v1.SetRemoteRequest': SetRemoteRequest$json,
  '.nushi.v1.SetRemoteResponse': SetRemoteResponse$json,
  '.nushi.v1.StartPairingRequest': StartPairingRequest$json,
  '.nushi.v1.StartPairingResponse': StartPairingResponse$json,
  '.nushi.v1.ConfirmPairingRequest': ConfirmPairingRequest$json,
  '.nushi.v1.ConfirmPairingResponse': ConfirmPairingResponse$json,
  '.nushi.v1.RevokeDeviceRequest': RevokeDeviceRequest$json,
  '.nushi.v1.RevokeDeviceResponse': RevokeDeviceResponse$json,
  '.nushi.v1.LogRequest': LogRequest$json,
  '.nushi.v1.LogRequest.AttrsEntry': LogRequest_AttrsEntry$json,
  '.nushi.v1.LogResponse': LogResponse$json,
  '.nushi.v1.ListJiraSitesRequest': ListJiraSitesRequest$json,
  '.nushi.v1.ListJiraSitesResponse': ListJiraSitesResponse$json,
  '.nushi.v1.JiraSite': JiraSite$json,
  '.nushi.v1.JiraSearch': JiraSearch$json,
  '.nushi.v1.AddJiraSiteRequest': AddJiraSiteRequest$json,
  '.nushi.v1.AddJiraSiteResponse': AddJiraSiteResponse$json,
  '.nushi.v1.RemoveJiraSiteRequest': RemoveJiraSiteRequest$json,
  '.nushi.v1.RemoveJiraSiteResponse': RemoveJiraSiteResponse$json,
  '.nushi.v1.CheckJiraSiteRequest': CheckJiraSiteRequest$json,
  '.nushi.v1.CheckJiraSiteResponse': CheckJiraSiteResponse$json,
  '.nushi.v1.AllowJiraTokenRequest': AllowJiraTokenRequest$json,
  '.nushi.v1.AllowJiraTokenResponse': AllowJiraTokenResponse$json,
  '.nushi.v1.ListJiraBoardsRequest': ListJiraBoardsRequest$json,
  '.nushi.v1.ListJiraBoardsResponse': ListJiraBoardsResponse$json,
  '.nushi.v1.JiraBoard': JiraBoard$json,
  '.nushi.v1.SetJiraBoardRequest': SetJiraBoardRequest$json,
  '.nushi.v1.SetJiraBoardResponse': SetJiraBoardResponse$json,
  '.nushi.v1.SetJiraSearchesRequest': SetJiraSearchesRequest$json,
  '.nushi.v1.SetJiraSearchesResponse': SetJiraSearchesResponse$json,
  '.nushi.v1.ListJiraIssuesRequest': ListJiraIssuesRequest$json,
  '.nushi.v1.ListJiraIssuesResponse': ListJiraIssuesResponse$json,
  '.nushi.v1.JiraIssue': JiraIssue$json,
  '.nushi.v1.JiraIssueRef': JiraIssueRef$json,
  '.nushi.v1.JiraLink': JiraLink$json,
  '.nushi.v1.JiraAttachment': JiraAttachment$json,
  '.nushi.v1.JiraComment': JiraComment$json,
  '.nushi.v1.JiraRemoteLink': JiraRemoteLink$json,
  '.nushi.v1.GetJiraJqlRequest': GetJiraJqlRequest$json,
  '.nushi.v1.GetJiraJqlResponse': GetJiraJqlResponse$json,
  '.nushi.v1.JiraJqlField': JiraJqlField$json,
  '.nushi.v1.SuggestJiraJqlRequest': SuggestJiraJqlRequest$json,
  '.nushi.v1.SuggestJiraJqlResponse': SuggestJiraJqlResponse$json,
  '.nushi.v1.JiraOption': JiraOption$json,
  '.nushi.v1.GetJiraIssueRequest': GetJiraIssueRequest$json,
  '.nushi.v1.GetJiraIssueResponse': GetJiraIssueResponse$json,
  '.nushi.v1.ListJiraTransitionsRequest': ListJiraTransitionsRequest$json,
  '.nushi.v1.ListJiraTransitionsResponse': ListJiraTransitionsResponse$json,
  '.nushi.v1.JiraTransition': JiraTransition$json,
  '.nushi.v1.JiraField': JiraField$json,
  '.nushi.v1.TransitionJiraIssueRequest': TransitionJiraIssueRequest$json,
  '.nushi.v1.TransitionJiraIssueRequest.ValuesEntry':
      TransitionJiraIssueRequest_ValuesEntry$json,
  '.nushi.v1.TransitionJiraIssueResponse': TransitionJiraIssueResponse$json,
  '.nushi.v1.AddJiraCommentRequest': AddJiraCommentRequest$json,
  '.nushi.v1.AddJiraCommentResponse': AddJiraCommentResponse$json,
  '.nushi.v1.GetJiraContextRequest': GetJiraContextRequest$json,
  '.nushi.v1.GetJiraContextResponse': GetJiraContextResponse$json,
  '.nushi.v1.GetJiraAttachmentRequest': GetJiraAttachmentRequest$json,
  '.nushi.v1.GetJiraAttachmentResponse': GetJiraAttachmentResponse$json,
  '.nushi.v1.EventsRequest': EventsRequest$json,
  '.nushi.v1.EventsResponse': EventsResponse$json,
  '.nushi.v1.ItemEvent': ItemEvent$json,
  '.nushi.v1.ChatConfig': ChatConfig$json,
  '.nushi.v1.ChatCommands': ChatCommands$json,
  '.nushi.v1.ChatTerminals': ChatTerminals$json,
};

/// Descriptor for `NushiService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List nushiServiceDescriptor = $convert.base64Decode(
    'CgxOdXNoaVNlcnZpY2USNQoEUGluZxIVLm51c2hpLnYxLlBpbmdSZXF1ZXN0GhYubnVzaGkudj'
    'EuUGluZ1Jlc3BvbnNlEkQKCUxpc3RDaGF0cxIaLm51c2hpLnYxLkxpc3RDaGF0c1JlcXVlc3Qa'
    'Gy5udXNoaS52MS5MaXN0Q2hhdHNSZXNwb25zZRI+CgdHZXRDaGF0EhgubnVzaGkudjEuR2V0Q2'
    'hhdFJlcXVlc3QaGS5udXNoaS52MS5HZXRDaGF0UmVzcG9uc2USRAoJU3RhcnRDaGF0EhoubnVz'
    'aGkudjEuU3RhcnRDaGF0UmVxdWVzdBobLm51c2hpLnYxLlN0YXJ0Q2hhdFJlc3BvbnNlEkcKCk'
    'xpc3RBZ2VudHMSGy5udXNoaS52MS5MaXN0QWdlbnRzUmVxdWVzdBocLm51c2hpLnYxLkxpc3RB'
    'Z2VudHNSZXNwb25zZRJHCgpTZXRVcEFnZW50EhsubnVzaGkudjEuU2V0VXBBZ2VudFJlcXVlc3'
    'QaHC5udXNoaS52MS5TZXRVcEFnZW50UmVzcG9uc2USSgoLUmVtb3ZlQWdlbnQSHC5udXNoaS52'
    'MS5SZW1vdmVBZ2VudFJlcXVlc3QaHS5udXNoaS52MS5SZW1vdmVBZ2VudFJlc3BvbnNlElwKEU'
    'xpc3RBZ2VudFNlc3Npb25zEiIubnVzaGkudjEuTGlzdEFnZW50U2Vzc2lvbnNSZXF1ZXN0GiMu'
    'bnVzaGkudjEuTGlzdEFnZW50U2Vzc2lvbnNSZXNwb25zZRJZChBPcGVuQWdlbnRTZXNzaW9uEi'
    'EubnVzaGkudjEuT3BlbkFnZW50U2Vzc2lvblJlcXVlc3QaIi5udXNoaS52MS5PcGVuQWdlbnRT'
    'ZXNzaW9uUmVzcG9uc2USQQoITW92ZUNoYXQSGS5udXNoaS52MS5Nb3ZlQ2hhdFJlcXVlc3QaGi'
    '5udXNoaS52MS5Nb3ZlQ2hhdFJlc3BvbnNlEkcKClNlbmRQcm9tcHQSGy5udXNoaS52MS5TZW5k'
    'UHJvbXB0UmVxdWVzdBocLm51c2hpLnYxLlNlbmRQcm9tcHRSZXNwb25zZRJHCgpSZXdpbmRDaG'
    'F0EhsubnVzaGkudjEuUmV3aW5kQ2hhdFJlcXVlc3QaHC5udXNoaS52MS5SZXdpbmRDaGF0UmVz'
    'cG9uc2USPgoHVW5xdWV1ZRIYLm51c2hpLnYxLlVucXVldWVSZXF1ZXN0GhkubnVzaGkudjEuVW'
    '5xdWV1ZVJlc3BvbnNlEkcKCkNhbmNlbFR1cm4SGy5udXNoaS52MS5DYW5jZWxUdXJuUmVxdWVz'
    'dBocLm51c2hpLnYxLkNhbmNlbFR1cm5SZXNwb25zZRJBCghGb3JrQ2hhdBIZLm51c2hpLnYxLk'
    'ZvcmtDaGF0UmVxdWVzdBoaLm51c2hpLnYxLkZvcmtDaGF0UmVzcG9uc2USUAoNQ2xvc2VTaWRl'
    'Q2hhdBIeLm51c2hpLnYxLkNsb3NlU2lkZUNoYXRSZXF1ZXN0Gh8ubnVzaGkudjEuQ2xvc2VTaW'
    'RlQ2hhdFJlc3BvbnNlEkcKClJlbmFtZUNoYXQSGy5udXNoaS52MS5SZW5hbWVDaGF0UmVxdWVz'
    'dBocLm51c2hpLnYxLlJlbmFtZUNoYXRSZXNwb25zZRJKCgtBcmNoaXZlQ2hhdBIcLm51c2hpLn'
    'YxLkFyY2hpdmVDaGF0UmVxdWVzdBodLm51c2hpLnYxLkFyY2hpdmVDaGF0UmVzcG9uc2USRAoJ'
    'U2xlZXBDaGF0EhoubnVzaGkudjEuU2xlZXBDaGF0UmVxdWVzdBobLm51c2hpLnYxLlNsZWVwQ2'
    'hhdFJlc3BvbnNlEkQKCUdldE1lbW9yeRIaLm51c2hpLnYxLkdldE1lbW9yeVJlcXVlc3QaGy5u'
    'dXNoaS52MS5HZXRNZW1vcnlSZXNwb25zZRJKCgtHZXRTZXR0aW5ncxIcLm51c2hpLnYxLkdldF'
    'NldHRpbmdzUmVxdWVzdBodLm51c2hpLnYxLkdldFNldHRpbmdzUmVzcG9uc2USSgoLU2V0U2V0'
    'dGluZ3MSHC5udXNoaS52MS5TZXRTZXR0aW5nc1JlcXVlc3QaHS5udXNoaS52MS5TZXRTZXR0aW'
    '5nc1Jlc3BvbnNlElMKDlBsYW5EZWxldGVDaGF0Eh8ubnVzaGkudjEuUGxhbkRlbGV0ZUNoYXRS'
    'ZXF1ZXN0GiAubnVzaGkudjEuUGxhbkRlbGV0ZUNoYXRSZXNwb25zZRJHCgpEZWxldGVDaGF0Eh'
    'subnVzaGkudjEuRGVsZXRlQ2hhdFJlcXVlc3QaHC5udXNoaS52MS5EZWxldGVDaGF0UmVzcG9u'
    'c2USWQoQQW5zd2VyUGVybWlzc2lvbhIhLm51c2hpLnYxLkFuc3dlclBlcm1pc3Npb25SZXF1ZX'
    'N0GiIubnVzaGkudjEuQW5zd2VyUGVybWlzc2lvblJlc3BvbnNlElMKDkFuc3dlclF1ZXN0aW9u'
    'Eh8ubnVzaGkudjEuQW5zd2VyUXVlc3Rpb25SZXF1ZXN0GiAubnVzaGkudjEuQW5zd2VyUXVlc3'
    'Rpb25SZXNwb25zZRJWCg9TZXRDb25maWdPcHRpb24SIC5udXNoaS52MS5TZXRDb25maWdPcHRp'
    'b25SZXF1ZXN0GiEubnVzaGkudjEuU2V0Q29uZmlnT3B0aW9uUmVzcG9uc2USPgoHR2V0RGlmZh'
    'IYLm51c2hpLnYxLkdldERpZmZSZXF1ZXN0GhkubnVzaGkudjEuR2V0RGlmZlJlc3BvbnNlEkoK'
    'C0xpc3RDb21taXRzEhwubnVzaGkudjEuTGlzdENvbW1pdHNSZXF1ZXN0Gh0ubnVzaGkudjEuTG'
    'lzdENvbW1pdHNSZXNwb25zZRJWCg9HZXRGb2xkZXJTdGF0dXMSIC5udXNoaS52MS5HZXRGb2xk'
    'ZXJTdGF0dXNSZXF1ZXN0GiEubnVzaGkudjEuR2V0Rm9sZGVyU3RhdHVzUmVzcG9uc2USRAoJTG'
    'lzdEZpbGVzEhoubnVzaGkudjEuTGlzdEZpbGVzUmVxdWVzdBobLm51c2hpLnYxLkxpc3RGaWxl'
    'c1Jlc3BvbnNlElYKD0dldENvbnRleHRVc2FnZRIgLm51c2hpLnYxLkdldENvbnRleHRVc2FnZV'
    'JlcXVlc3QaIS5udXNoaS52MS5HZXRDb250ZXh0VXNhZ2VSZXNwb25zZRJTCg5MaXN0TWNwU2Vy'
    'dmVycxIfLm51c2hpLnYxLkxpc3RNY3BTZXJ2ZXJzUmVxdWVzdBogLm51c2hpLnYxLkxpc3RNY3'
    'BTZXJ2ZXJzUmVzcG9uc2USTQoMQWRkTWNwU2VydmVyEh0ubnVzaGkudjEuQWRkTWNwU2VydmVy'
    'UmVxdWVzdBoeLm51c2hpLnYxLkFkZE1jcFNlcnZlclJlc3BvbnNlElAKDUVkaXRNY3BTZXJ2ZX'
    'ISHi5udXNoaS52MS5FZGl0TWNwU2VydmVyUmVxdWVzdBofLm51c2hpLnYxLkVkaXRNY3BTZXJ2'
    'ZXJSZXNwb25zZRJWCg9SZW1vdmVNY3BTZXJ2ZXISIC5udXNoaS52MS5SZW1vdmVNY3BTZXJ2ZX'
    'JSZXF1ZXN0GiEubnVzaGkudjEuUmVtb3ZlTWNwU2VydmVyUmVzcG9uc2USUwoOU2V0TWNwU2Vy'
    'dmVyT24SHy5udXNoaS52MS5TZXRNY3BTZXJ2ZXJPblJlcXVlc3QaIC5udXNoaS52MS5TZXRNY3'
    'BTZXJ2ZXJPblJlc3BvbnNlElMKDkxvZ2luTWNwU2VydmVyEh8ubnVzaGkudjEuTG9naW5NY3BT'
    'ZXJ2ZXJSZXF1ZXN0GiAubnVzaGkudjEuTG9naW5NY3BTZXJ2ZXJSZXNwb25zZRJWCg9Mb2dvdX'
    'RNY3BTZXJ2ZXISIC5udXNoaS52MS5Mb2dvdXRNY3BTZXJ2ZXJSZXF1ZXN0GiEubnVzaGkudjEu'
    'TG9nb3V0TWNwU2VydmVyUmVzcG9uc2USRwoKUmVsb2FkQ2hhdBIbLm51c2hpLnYxLlJlbG9hZE'
    'NoYXRSZXF1ZXN0GhwubnVzaGkudjEuUmVsb2FkQ2hhdFJlc3BvbnNlEk0KDE9wZW5UZXJtaW5h'
    'bBIdLm51c2hpLnYxLk9wZW5UZXJtaW5hbFJlcXVlc3QaHi5udXNoaS52MS5PcGVuVGVybWluYW'
    'xSZXNwb25zZRJQCg1MaXN0VGVybWluYWxzEh4ubnVzaGkudjEuTGlzdFRlcm1pbmFsc1JlcXVl'
    'c3QaHy5udXNoaS52MS5MaXN0VGVybWluYWxzUmVzcG9uc2USVQoOQXR0YWNoVGVybWluYWwSHy'
    '5udXNoaS52MS5BdHRhY2hUZXJtaW5hbFJlcXVlc3QaIC5udXNoaS52MS5BdHRhY2hUZXJtaW5h'
    'bFJlc3BvbnNlMAESUAoNV3JpdGVUZXJtaW5hbBIeLm51c2hpLnYxLldyaXRlVGVybWluYWxSZX'
    'F1ZXN0Gh8ubnVzaGkudjEuV3JpdGVUZXJtaW5hbFJlc3BvbnNlElMKDlJlc2l6ZVRlcm1pbmFs'
    'Eh8ubnVzaGkudjEuUmVzaXplVGVybWluYWxSZXF1ZXN0GiAubnVzaGkudjEuUmVzaXplVGVybW'
    'luYWxSZXNwb25zZRJTCg5SZW5hbWVUZXJtaW5hbBIfLm51c2hpLnYxLlJlbmFtZVRlcm1pbmFs'
    'UmVxdWVzdBogLm51c2hpLnYxLlJlbmFtZVRlcm1pbmFsUmVzcG9uc2USWQoQQXJyYW5nZVRlcm'
    '1pbmFscxIhLm51c2hpLnYxLkFycmFuZ2VUZXJtaW5hbHNSZXF1ZXN0GiIubnVzaGkudjEuQXJy'
    'YW5nZVRlcm1pbmFsc1Jlc3BvbnNlElYKD1Jlc3RhcnRUZXJtaW5hbBIgLm51c2hpLnYxLlJlc3'
    'RhcnRUZXJtaW5hbFJlcXVlc3QaIS5udXNoaS52MS5SZXN0YXJ0VGVybWluYWxSZXNwb25zZRJQ'
    'Cg1DbG9zZVRlcm1pbmFsEh4ubnVzaGkudjEuQ2xvc2VUZXJtaW5hbFJlcXVlc3QaHy5udXNoaS'
    '52MS5DbG9zZVRlcm1pbmFsUmVzcG9uc2USSgoLQ2hlY2tGb2xkZXISHC5udXNoaS52MS5DaGVj'
    'a0ZvbGRlclJlcXVlc3QaHS5udXNoaS52MS5DaGVja0ZvbGRlclJlc3BvbnNlEkoKC1RydXN0Rm'
    '9sZGVyEhwubnVzaGkudjEuVHJ1c3RGb2xkZXJSZXF1ZXN0Gh0ubnVzaGkudjEuVHJ1c3RGb2xk'
    'ZXJSZXNwb25zZRJECglHZXRSZW1vdGUSGi5udXNoaS52MS5HZXRSZW1vdGVSZXF1ZXN0Ghsubn'
    'VzaGkudjEuR2V0UmVtb3RlUmVzcG9uc2USRAoJU2V0UmVtb3RlEhoubnVzaGkudjEuU2V0UmVt'
    'b3RlUmVxdWVzdBobLm51c2hpLnYxLlNldFJlbW90ZVJlc3BvbnNlEk0KDFN0YXJ0UGFpcmluZx'
    'IdLm51c2hpLnYxLlN0YXJ0UGFpcmluZ1JlcXVlc3QaHi5udXNoaS52MS5TdGFydFBhaXJpbmdS'
    'ZXNwb25zZRJTCg5Db25maXJtUGFpcmluZxIfLm51c2hpLnYxLkNvbmZpcm1QYWlyaW5nUmVxdW'
    'VzdBogLm51c2hpLnYxLkNvbmZpcm1QYWlyaW5nUmVzcG9uc2USTQoMUmV2b2tlRGV2aWNlEh0u'
    'bnVzaGkudjEuUmV2b2tlRGV2aWNlUmVxdWVzdBoeLm51c2hpLnYxLlJldm9rZURldmljZVJlc3'
    'BvbnNlEjIKA0xvZxIULm51c2hpLnYxLkxvZ1JlcXVlc3QaFS5udXNoaS52MS5Mb2dSZXNwb25z'
    'ZRJQCg1MaXN0SmlyYVNpdGVzEh4ubnVzaGkudjEuTGlzdEppcmFTaXRlc1JlcXVlc3QaHy5udX'
    'NoaS52MS5MaXN0SmlyYVNpdGVzUmVzcG9uc2USSgoLQWRkSmlyYVNpdGUSHC5udXNoaS52MS5B'
    'ZGRKaXJhU2l0ZVJlcXVlc3QaHS5udXNoaS52MS5BZGRKaXJhU2l0ZVJlc3BvbnNlElMKDlJlbW'
    '92ZUppcmFTaXRlEh8ubnVzaGkudjEuUmVtb3ZlSmlyYVNpdGVSZXF1ZXN0GiAubnVzaGkudjEu'
    'UmVtb3ZlSmlyYVNpdGVSZXNwb25zZRJQCg1DaGVja0ppcmFTaXRlEh4ubnVzaGkudjEuQ2hlY2'
    'tKaXJhU2l0ZVJlcXVlc3QaHy5udXNoaS52MS5DaGVja0ppcmFTaXRlUmVzcG9uc2USUwoOQWxs'
    'b3dKaXJhVG9rZW4SHy5udXNoaS52MS5BbGxvd0ppcmFUb2tlblJlcXVlc3QaIC5udXNoaS52MS'
    '5BbGxvd0ppcmFUb2tlblJlc3BvbnNlElMKDkxpc3RKaXJhQm9hcmRzEh8ubnVzaGkudjEuTGlz'
    'dEppcmFCb2FyZHNSZXF1ZXN0GiAubnVzaGkudjEuTGlzdEppcmFCb2FyZHNSZXNwb25zZRJNCg'
    'xTZXRKaXJhQm9hcmQSHS5udXNoaS52MS5TZXRKaXJhQm9hcmRSZXF1ZXN0Gh4ubnVzaGkudjEu'
    'U2V0SmlyYUJvYXJkUmVzcG9uc2USVgoPU2V0SmlyYVNlYXJjaGVzEiAubnVzaGkudjEuU2V0Sm'
    'lyYVNlYXJjaGVzUmVxdWVzdBohLm51c2hpLnYxLlNldEppcmFTZWFyY2hlc1Jlc3BvbnNlElMK'
    'Dkxpc3RKaXJhSXNzdWVzEh8ubnVzaGkudjEuTGlzdEppcmFJc3N1ZXNSZXF1ZXN0GiAubnVzaG'
    'kudjEuTGlzdEppcmFJc3N1ZXNSZXNwb25zZRJHCgpHZXRKaXJhSnFsEhsubnVzaGkudjEuR2V0'
    'SmlyYUpxbFJlcXVlc3QaHC5udXNoaS52MS5HZXRKaXJhSnFsUmVzcG9uc2USUwoOU3VnZ2VzdE'
    'ppcmFKcWwSHy5udXNoaS52MS5TdWdnZXN0SmlyYUpxbFJlcXVlc3QaIC5udXNoaS52MS5TdWdn'
    'ZXN0SmlyYUpxbFJlc3BvbnNlEk0KDEdldEppcmFJc3N1ZRIdLm51c2hpLnYxLkdldEppcmFJc3'
    'N1ZVJlcXVlc3QaHi5udXNoaS52MS5HZXRKaXJhSXNzdWVSZXNwb25zZRJiChNMaXN0SmlyYVRy'
    'YW5zaXRpb25zEiQubnVzaGkudjEuTGlzdEppcmFUcmFuc2l0aW9uc1JlcXVlc3QaJS5udXNoaS'
    '52MS5MaXN0SmlyYVRyYW5zaXRpb25zUmVzcG9uc2USYgoTVHJhbnNpdGlvbkppcmFJc3N1ZRIk'
    'Lm51c2hpLnYxLlRyYW5zaXRpb25KaXJhSXNzdWVSZXF1ZXN0GiUubnVzaGkudjEuVHJhbnNpdG'
    'lvbkppcmFJc3N1ZVJlc3BvbnNlElMKDkFkZEppcmFDb21tZW50Eh8ubnVzaGkudjEuQWRkSmly'
    'YUNvbW1lbnRSZXF1ZXN0GiAubnVzaGkudjEuQWRkSmlyYUNvbW1lbnRSZXNwb25zZRJTCg5HZX'
    'RKaXJhQ29udGV4dBIfLm51c2hpLnYxLkdldEppcmFDb250ZXh0UmVxdWVzdBogLm51c2hpLnYx'
    'LkdldEppcmFDb250ZXh0UmVzcG9uc2USXAoRR2V0SmlyYUF0dGFjaG1lbnQSIi5udXNoaS52MS'
    '5HZXRKaXJhQXR0YWNobWVudFJlcXVlc3QaIy5udXNoaS52MS5HZXRKaXJhQXR0YWNobWVudFJl'
    'c3BvbnNlEj0KBkV2ZW50cxIXLm51c2hpLnYxLkV2ZW50c1JlcXVlc3QaGC5udXNoaS52MS5Fdm'
    'VudHNSZXNwb25zZTAB');
