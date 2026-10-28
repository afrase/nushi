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
    {'1': 'version', '3': 3, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USHwoLYXBpX3ZlcnNpb24YASABKAVSCmFwaVZlcnNpb24SFAoFYnVpbG'
    'QYAiABKAlSBWJ1aWxkEhgKB3ZlcnNpb24YAyABKAlSB3ZlcnNpb24=');

@$core.Deprecated('Use restartWhenIdleRequestDescriptor instead')
const RestartWhenIdleRequest$json = {
  '1': 'RestartWhenIdleRequest',
};

/// Descriptor for `RestartWhenIdleRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartWhenIdleRequestDescriptor =
    $convert.base64Decode('ChZSZXN0YXJ0V2hlbklkbGVSZXF1ZXN0');

@$core.Deprecated('Use restartWhenIdleResponseDescriptor instead')
const RestartWhenIdleResponse$json = {
  '1': 'RestartWhenIdleResponse',
};

/// Descriptor for `RestartWhenIdleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartWhenIdleResponseDescriptor =
    $convert.base64Decode('ChdSZXN0YXJ0V2hlbklkbGVSZXNwb25zZQ==');

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
    {
      '1': 'removed',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.RemovedChat',
      '10': 'removed'
    },
  ],
};

/// Descriptor for `ListChatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listChatsResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0Q2hhdHNSZXNwb25zZRIkCgVjaGF0cxgBIAMoCzIOLm51c2hpLnYxLkNoYXRSBWNoYX'
    'RzEi8KB3JlbW92ZWQYAiADKAsyFS5udXNoaS52MS5SZW1vdmVkQ2hhdFIHcmVtb3ZlZA==');

@$core.Deprecated('Use removedChatDescriptor instead')
const RemovedChat$json = {
  '1': 'RemovedChat',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'agent', '3': 2, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'folder', '3': 4, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'removed_unix_ms', '3': 5, '4': 1, '5': 3, '10': 'removedUnixMs'},
  ],
};

/// Descriptor for `RemovedChat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removedChatDescriptor = $convert.base64Decode(
    'CgtSZW1vdmVkQ2hhdBIOCgJpZBgBIAEoCVICaWQSFAoFYWdlbnQYAiABKAlSBWFnZW50EhQKBX'
    'RpdGxlGAMgASgJUgV0aXRsZRIWCgZmb2xkZXIYBCABKAlSBmZvbGRlchImCg9yZW1vdmVkX3Vu'
    'aXhfbXMYBSABKANSDXJlbW92ZWRVbml4TXM=');

@$core.Deprecated('Use removedChatsDescriptor instead')
const RemovedChats$json = {
  '1': 'RemovedChats',
  '2': [
    {
      '1': 'chats',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.RemovedChat',
      '10': 'chats'
    },
  ],
};

/// Descriptor for `RemovedChats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removedChatsDescriptor = $convert.base64Decode(
    'CgxSZW1vdmVkQ2hhdHMSKwoFY2hhdHMYASADKAsyFS5udXNoaS52MS5SZW1vdmVkQ2hhdFIFY2'
    'hhdHM=');

@$core.Deprecated('Use dismissRemovedChatsRequestDescriptor instead')
const DismissRemovedChatsRequest$json = {
  '1': 'DismissRemovedChatsRequest',
  '2': [
    {'1': 'ids', '3': 1, '4': 3, '5': 9, '10': 'ids'},
  ],
};

/// Descriptor for `DismissRemovedChatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dismissRemovedChatsRequestDescriptor =
    $convert.base64Decode(
        'ChpEaXNtaXNzUmVtb3ZlZENoYXRzUmVxdWVzdBIQCgNpZHMYASADKAlSA2lkcw==');

@$core.Deprecated('Use dismissRemovedChatsResponseDescriptor instead')
const DismissRemovedChatsResponse$json = {
  '1': 'DismissRemovedChatsResponse',
};

/// Descriptor for `DismissRemovedChatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dismissRemovedChatsResponseDescriptor =
    $convert.base64Decode('ChtEaXNtaXNzUmVtb3ZlZENoYXRzUmVzcG9uc2U=');

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
    {
      '1': 'github',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'github'
    },
    {'1': 'unseen', '3': 15, '4': 1, '5': 8, '10': 'unseen'},
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
    'amlyYV9zaXRlGAwgASgJUghqaXJhU2l0ZRIZCghqaXJhX2tleRgNIAEoCVIHamlyYUtleRIsCg'
    'ZnaXRodWIYDiABKAsyFC5udXNoaS52MS5HaXRIdWJMaW5rUgZnaXRodWISFgoGdW5zZWVuGA8g'
    'ASgIUgZ1bnNlZW4=');

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
    {'1': 'recent', '3': 2, '4': 1, '5': 5, '10': 'recent'},
  ],
};

/// Descriptor for `GetChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatRequestDescriptor = $convert.base64Decode(
    'Cg5HZXRDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFgoGcmVjZW50GAIgAS'
    'gFUgZyZWNlbnQ=');

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
    {'1': 'older', '3': 9, '4': 1, '5': 5, '10': 'older'},
  ],
};

/// Descriptor for `GetChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRDaGF0UmVzcG9uc2USIgoEY2hhdBgBIAEoCzIOLm51c2hpLnYxLkNoYXRSBGNoYXQSJA'
    'oFaXRlbXMYAiADKAsyDi5udXNoaS52MS5JdGVtUgVpdGVtcxIuCgZjb25maWcYAyADKAsyFi5u'
    'dXNoaS52MS5Db25maWdPcHRpb25SBmNvbmZpZxIsCgZzdGF0dXMYBCABKAsyFC5udXNoaS52MS'
    '5DaGF0U3RhdHVzUgZzdGF0dXMSEAoDc2VxGAUgASgDUgNzZXESLQoIY29tbWFuZHMYBiADKAsy'
    'ES5udXNoaS52MS5Db21tYW5kUghjb21tYW5kcxIlCgV1c2FnZRgHIAEoCzIPLm51c2hpLnYxLl'
    'VzYWdlUgV1c2FnZRIpCgVxdWV1ZRgIIAEoCzITLm51c2hpLnYxLkNoYXRRdWV1ZVIFcXVldWUS'
    'FAoFb2xkZXIYCSABKAVSBW9sZGVy');

@$core.Deprecated('Use getChatItemsRequestDescriptor instead')
const GetChatItemsRequest$json = {
  '1': 'GetChatItemsRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'before', '3': 2, '4': 1, '5': 9, '10': 'before'},
    {'1': 'limit', '3': 3, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `GetChatItemsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatItemsRequestDescriptor = $convert.base64Decode(
    'ChNHZXRDaGF0SXRlbXNSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIWCgZiZWZvcm'
    'UYAiABKAlSBmJlZm9yZRIUCgVsaW1pdBgDIAEoBVIFbGltaXQ=');

@$core.Deprecated('Use getChatItemsResponseDescriptor instead')
const GetChatItemsResponse$json = {
  '1': 'GetChatItemsResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Item',
      '10': 'items'
    },
    {'1': 'older', '3': 2, '4': 1, '5': 5, '10': 'older'},
  ],
};

/// Descriptor for `GetChatItemsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatItemsResponseDescriptor = $convert.base64Decode(
    'ChRHZXRDaGF0SXRlbXNSZXNwb25zZRIkCgVpdGVtcxgBIAMoCzIOLm51c2hpLnYxLkl0ZW1SBW'
    'l0ZW1zEhQKBW9sZGVyGAIgASgFUgVvbGRlcg==');

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
  '2': [
    {
      '1': 'refresh_environment',
      '3': 1,
      '4': 1,
      '5': 8,
      '10': 'refreshEnvironment'
    },
    {
      '1': 'reload_environment',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'reloadEnvironment'
    },
  ],
};

/// Descriptor for `ListAgentsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAgentsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0QWdlbnRzUmVxdWVzdBIvChNyZWZyZXNoX2Vudmlyb25tZW50GAEgASgIUhJyZWZyZX'
    'NoRW52aXJvbm1lbnQSLQoScmVsb2FkX2Vudmlyb25tZW50GAIgASgIUhFyZWxvYWRFbnZpcm9u'
    'bWVudA==');

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
    {
      '1': 'environment',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ShellEnvironment',
      '10': 'environment'
    },
  ],
};

/// Descriptor for `ListAgentsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAgentsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0QWdlbnRzUmVzcG9uc2USJwoGYWdlbnRzGAEgAygLMg8ubnVzaGkudjEuQWdlbnRSBm'
    'FnZW50cxI8CgtlbnZpcm9ubWVudBgCIAEoCzIaLm51c2hpLnYxLlNoZWxsRW52aXJvbm1lbnRS'
    'C2Vudmlyb25tZW50');

@$core.Deprecated('Use shellEnvironmentDescriptor instead')
const ShellEnvironment$json = {
  '1': 'ShellEnvironment',
  '2': [
    {'1': 'shell', '3': 1, '4': 1, '5': 9, '10': 'shell'},
    {'1': 'read_unix_ms', '3': 2, '4': 1, '5': 3, '10': 'readUnixMs'},
    {'1': 'problem', '3': 3, '4': 1, '5': 9, '10': 'problem'},
  ],
};

/// Descriptor for `ShellEnvironment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shellEnvironmentDescriptor = $convert.base64Decode(
    'ChBTaGVsbEVudmlyb25tZW50EhQKBXNoZWxsGAEgASgJUgVzaGVsbBIgCgxyZWFkX3VuaXhfbX'
    'MYAiABKANSCnJlYWRVbml4TXMSGAoHcHJvYmxlbRgDIAEoCVIHcHJvYmxlbQ==');

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
    {
      '1': 'github',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'github'
    },
  ],
};

/// Descriptor for `StartChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatRequestDescriptor = $convert.base64Decode(
    'ChBTdGFydENoYXRSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBWFnZW50GAMgAS'
    'gJUgVhZ2VudBIaCgh3b3JrdHJlZRgCIAEoCFIId29ya3RyZWUSGwoJamlyYV9zaXRlGAQgASgJ'
    'UghqaXJhU2l0ZRIZCghqaXJhX2tleRgFIAEoCVIHamlyYUtleRIWCgZicmFuY2gYBiABKAlSBm'
    'JyYW5jaBIsCgZnaXRodWIYByABKAsyFC5udXNoaS52MS5HaXRIdWJMaW5rUgZnaXRodWI=');

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
    {'1': 'relay_stop', '3': 7, '4': 1, '5': 8, '10': 'relayStop'},
  ],
};

/// Descriptor for `QueuedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queuedMessageDescriptor = $convert.base64Decode(
    'Cg1RdWV1ZWRNZXNzYWdlEg4KAmlkGAEgASgJUgJpZBISCgR0ZXh0GAIgASgJUgR0ZXh0EhQKBW'
    'ZpbGVzGAMgAygJUgVmaWxlcxIrCgZpbWFnZXMYBCADKAsyEy5udXNoaS52MS5JbWFnZURhdGFS'
    'BmltYWdlcxIZCghyZWxheV90bxgFIAEoCVIHcmVsYXlUbxIfCgt0b19zdWJhZ2VudBgGIAEoCV'
    'IKdG9TdWJhZ2VudBIdCgpyZWxheV9zdG9wGAcgASgIUglyZWxheVN0b3A=');

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

@$core.Deprecated('Use stopTaskRequestDescriptor instead')
const StopTaskRequest$json = {
  '1': 'StopTaskRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'call_id', '3': 2, '4': 1, '5': 9, '10': 'callId'},
  ],
};

/// Descriptor for `StopTaskRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopTaskRequestDescriptor = $convert.base64Decode(
    'Cg9TdG9wVGFza1JlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElkEhcKB2NhbGxfaWQYAi'
    'ABKAlSBmNhbGxJZA==');

@$core.Deprecated('Use stopTaskResponseDescriptor instead')
const StopTaskResponse$json = {
  '1': 'StopTaskResponse',
};

/// Descriptor for `StopTaskResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopTaskResponseDescriptor =
    $convert.base64Decode('ChBTdG9wVGFza1Jlc3BvbnNl');

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

@$core.Deprecated('Use renameBranchRequestDescriptor instead')
const RenameBranchRequest$json = {
  '1': 'RenameBranchRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
  ],
};

/// Descriptor for `RenameBranchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameBranchRequestDescriptor = $convert.base64Decode(
    'ChNSZW5hbWVCcmFuY2hSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIWCgZicmFuY2'
    'gYAiABKAlSBmJyYW5jaA==');

@$core.Deprecated('Use renameBranchResponseDescriptor instead')
const RenameBranchResponse$json = {
  '1': 'RenameBranchResponse',
};

/// Descriptor for `RenameBranchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List renameBranchResponseDescriptor =
    $convert.base64Decode('ChRSZW5hbWVCcmFuY2hSZXNwb25zZQ==');

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

@$core.Deprecated('Use reopenChatRequestDescriptor instead')
const ReopenChatRequest$json = {
  '1': 'ReopenChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ReopenChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reopenChatRequestDescriptor = $convert.base64Decode(
    'ChFSZW9wZW5DaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use reopenChatResponseDescriptor instead')
const ReopenChatResponse$json = {
  '1': 'ReopenChatResponse',
};

/// Descriptor for `ReopenChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reopenChatResponseDescriptor =
    $convert.base64Decode('ChJSZW9wZW5DaGF0UmVzcG9uc2U=');

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
    {
      '1': 'keep_transcripts',
      '3': 3,
      '4': 1,
      '5': 8,
      '9': 0,
      '10': 'keepTranscripts',
      '17': true
    },
    {
      '1': 'transcript_days',
      '3': 4,
      '4': 1,
      '5': 5,
      '9': 1,
      '10': 'transcriptDays',
      '17': true
    },
  ],
  '8': [
    {'1': '_keep_transcripts'},
    {'1': '_transcript_days'},
  ],
};

/// Descriptor for `Settings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsDescriptor = $convert.base64Decode(
    'CghTZXR0aW5ncxIuChNzbGVlcF9hZnRlcl9taW51dGVzGAEgASgFUhFzbGVlcEFmdGVyTWludX'
    'RlcxIbCglkZWJ1Z19sb2cYAiABKAhSCGRlYnVnTG9nEi4KEGtlZXBfdHJhbnNjcmlwdHMYAyAB'
    'KAhIAFIPa2VlcFRyYW5zY3JpcHRziAEBEiwKD3RyYW5zY3JpcHRfZGF5cxgEIAEoBUgBUg50cm'
    'Fuc2NyaXB0RGF5c4gBAUITChFfa2VlcF90cmFuc2NyaXB0c0ISChBfdHJhbnNjcmlwdF9kYXlz');

@$core.Deprecated('Use listTranscriptsRequestDescriptor instead')
const ListTranscriptsRequest$json = {
  '1': 'ListTranscriptsRequest',
};

/// Descriptor for `ListTranscriptsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTranscriptsRequestDescriptor =
    $convert.base64Decode('ChZMaXN0VHJhbnNjcmlwdHNSZXF1ZXN0');

@$core.Deprecated('Use listTranscriptsResponseDescriptor instead')
const ListTranscriptsResponse$json = {
  '1': 'ListTranscriptsResponse',
  '2': [
    {'1': 'total_bytes', '3': 1, '4': 1, '5': 3, '10': 'totalBytes'},
    {
      '1': 'copies',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.TranscriptCopy',
      '10': 'copies'
    },
  ],
};

/// Descriptor for `ListTranscriptsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTranscriptsResponseDescriptor = $convert.base64Decode(
    'ChdMaXN0VHJhbnNjcmlwdHNSZXNwb25zZRIfCgt0b3RhbF9ieXRlcxgBIAEoA1IKdG90YWxCeX'
    'RlcxIwCgZjb3BpZXMYAiADKAsyGC5udXNoaS52MS5UcmFuc2NyaXB0Q29weVIGY29waWVz');

@$core.Deprecated('Use transcriptCopyDescriptor instead')
const TranscriptCopy$json = {
  '1': 'TranscriptCopy',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'bytes', '3': 4, '4': 1, '5': 3, '10': 'bytes'},
    {'1': 'last_written_ms', '3': 5, '4': 1, '5': 3, '10': 'lastWrittenMs'},
  ],
};

/// Descriptor for `TranscriptCopy`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transcriptCopyDescriptor = $convert.base64Decode(
    'Cg5UcmFuc2NyaXB0Q29weRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFAoFdGl0bGUYAiABKA'
    'lSBXRpdGxlEhQKBWFnZW50GAMgASgJUgVhZ2VudBIUCgVieXRlcxgEIAEoA1IFYnl0ZXMSJgoP'
    'bGFzdF93cml0dGVuX21zGAUgASgDUg1sYXN0V3JpdHRlbk1z');

@$core.Deprecated('Use clearTranscriptsRequestDescriptor instead')
const ClearTranscriptsRequest$json = {
  '1': 'ClearTranscriptsRequest',
  '2': [
    {'1': 'chat_ids', '3': 1, '4': 3, '5': 9, '10': 'chatIds'},
    {'1': 'all', '3': 2, '4': 1, '5': 8, '10': 'all'},
    {'1': 'older_than_days', '3': 3, '4': 1, '5': 5, '10': 'olderThanDays'},
  ],
};

/// Descriptor for `ClearTranscriptsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearTranscriptsRequestDescriptor = $convert.base64Decode(
    'ChdDbGVhclRyYW5zY3JpcHRzUmVxdWVzdBIZCghjaGF0X2lkcxgBIAMoCVIHY2hhdElkcxIQCg'
    'NhbGwYAiABKAhSA2FsbBImCg9vbGRlcl90aGFuX2RheXMYAyABKAVSDW9sZGVyVGhhbkRheXM=');

@$core.Deprecated('Use clearTranscriptsResponseDescriptor instead')
const ClearTranscriptsResponse$json = {
  '1': 'ClearTranscriptsResponse',
  '2': [
    {'1': 'cleared', '3': 1, '4': 1, '5': 5, '10': 'cleared'},
    {'1': 'bytes', '3': 2, '4': 1, '5': 3, '10': 'bytes'},
  ],
};

/// Descriptor for `ClearTranscriptsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearTranscriptsResponseDescriptor =
    $convert.base64Decode(
        'ChhDbGVhclRyYW5zY3JpcHRzUmVzcG9uc2USGAoHY2xlYXJlZBgBIAEoBVIHY2xlYXJlZBIUCg'
        'VieXRlcxgCIAEoA1IFYnl0ZXM=');

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
    {'1': 'scope', '3': 4, '4': 1, '5': 9, '10': 'scope'},
  ],
};

/// Descriptor for `SetMcpServerOnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMcpServerOnRequestDescriptor = $convert.base64Decode(
    'ChVTZXRNY3BTZXJ2ZXJPblJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRIOCgJvbhgDIAEoCFICb24SFAoFc2NvcGUYBCABKAlSBXNjb3Bl');

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

@$core.Deprecated('Use listSkillsRequestDescriptor instead')
const ListSkillsRequest$json = {
  '1': 'ListSkillsRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'agent', '3': 2, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `ListSkillsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSkillsRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0U2tpbGxzUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchIUCgVhZ2VudBgCIA'
    'EoCVIFYWdlbnQ=');

@$core.Deprecated('Use listSkillsResponseDescriptor instead')
const ListSkillsResponse$json = {
  '1': 'ListSkillsResponse',
  '2': [
    {
      '1': 'skills',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Skill',
      '10': 'skills'
    },
    {
      '1': 'plugins',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Plugin',
      '10': 'plugins'
    },
    {'1': 'plugins_error', '3': 3, '4': 1, '5': 9, '10': 'pluginsError'},
    {'1': 'built_in_off', '3': 4, '4': 1, '5': 8, '10': 'builtInOff'},
    {'1': 'built_in_set_in', '3': 5, '4': 1, '5': 9, '10': 'builtInSetIn'},
    {'1': 'no_skills', '3': 6, '4': 1, '5': 9, '10': 'noSkills'},
    {'1': 'no_switch', '3': 7, '4': 1, '5': 9, '10': 'noSwitch'},
    {'1': 'reads_shared', '3': 8, '4': 1, '5': 8, '10': 'readsShared'},
  ],
};

/// Descriptor for `ListSkillsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSkillsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0U2tpbGxzUmVzcG9uc2USJwoGc2tpbGxzGAEgAygLMg8ubnVzaGkudjEuU2tpbGxSBn'
    'NraWxscxIqCgdwbHVnaW5zGAIgAygLMhAubnVzaGkudjEuUGx1Z2luUgdwbHVnaW5zEiMKDXBs'
    'dWdpbnNfZXJyb3IYAyABKAlSDHBsdWdpbnNFcnJvchIgCgxidWlsdF9pbl9vZmYYBCABKAhSCm'
    'J1aWx0SW5PZmYSJQoPYnVpbHRfaW5fc2V0X2luGAUgASgJUgxidWlsdEluU2V0SW4SGwoJbm9f'
    'c2tpbGxzGAYgASgJUghub1NraWxscxIbCglub19zd2l0Y2gYByABKAlSCG5vU3dpdGNoEiEKDH'
    'JlYWRzX3NoYXJlZBgIIAEoCFILcmVhZHNTaGFyZWQ=');

@$core.Deprecated('Use skillDescriptor instead')
const Skill$json = {
  '1': 'Skill',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'source', '3': 3, '4': 1, '5': 9, '10': 'source'},
    {'1': 'plugin', '3': 4, '4': 1, '5': 9, '10': 'plugin'},
    {'1': 'path', '3': 5, '4': 1, '5': 9, '10': 'path'},
    {'1': 'state', '3': 6, '4': 1, '5': 9, '10': 'state'},
    {'1': 'set_in', '3': 7, '4': 1, '5': 9, '10': 'setIn'},
    {'1': 'tokens', '3': 8, '4': 1, '5': 5, '10': 'tokens'},
    {'1': 'linked', '3': 9, '4': 1, '5': 9, '10': 'linked'},
    {'1': 'everywhere', '3': 10, '4': 1, '5': 8, '10': 'everywhere'},
    {
      '1': 'agents',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.SkillAgent',
      '10': 'agents'
    },
  ],
};

/// Descriptor for `Skill`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skillDescriptor = $convert.base64Decode(
    'CgVTa2lsbBISCgRuYW1lGAEgASgJUgRuYW1lEiAKC2Rlc2NyaXB0aW9uGAIgASgJUgtkZXNjcm'
    'lwdGlvbhIWCgZzb3VyY2UYAyABKAlSBnNvdXJjZRIWCgZwbHVnaW4YBCABKAlSBnBsdWdpbhIS'
    'CgRwYXRoGAUgASgJUgRwYXRoEhQKBXN0YXRlGAYgASgJUgVzdGF0ZRIVCgZzZXRfaW4YByABKA'
    'lSBXNldEluEhYKBnRva2VucxgIIAEoBVIGdG9rZW5zEhYKBmxpbmtlZBgJIAEoCVIGbGlua2Vk'
    'Eh4KCmV2ZXJ5d2hlcmUYCiABKAhSCmV2ZXJ5d2hlcmUSLAoGYWdlbnRzGAsgAygLMhQubnVzaG'
    'kudjEuU2tpbGxBZ2VudFIGYWdlbnRz');

@$core.Deprecated('Use skillAgentDescriptor instead')
const SkillAgent$json = {
  '1': 'SkillAgent',
  '2': [
    {'1': 'agent', '3': 1, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'state', '3': 2, '4': 1, '5': 9, '10': 'state'},
    {'1': 'set_in', '3': 3, '4': 1, '5': 9, '10': 'setIn'},
    {'1': 'via', '3': 4, '4': 1, '5': 9, '10': 'via'},
  ],
};

/// Descriptor for `SkillAgent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skillAgentDescriptor = $convert.base64Decode(
    'CgpTa2lsbEFnZW50EhQKBWFnZW50GAEgASgJUgVhZ2VudBIUCgVzdGF0ZRgCIAEoCVIFc3RhdG'
    'USFQoGc2V0X2luGAMgASgJUgVzZXRJbhIQCgN2aWEYBCABKAlSA3ZpYQ==');

@$core.Deprecated('Use pluginDescriptor instead')
const Plugin$json = {
  '1': 'Plugin',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'version', '3': 3, '4': 1, '5': 9, '10': 'version'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
    {'1': 'scope', '3': 5, '4': 1, '5': 9, '10': 'scope'},
    {'1': 'path', '3': 6, '4': 1, '5': 9, '10': 'path'},
    {'1': 'enabled', '3': 7, '4': 1, '5': 8, '10': 'enabled'},
    {'1': 'skills', '3': 8, '4': 1, '5': 5, '10': 'skills'},
    {'1': 'commands', '3': 9, '4': 1, '5': 5, '10': 'commands'},
    {'1': 'agents', '3': 10, '4': 1, '5': 5, '10': 'agents'},
    {'1': 'mcp_servers', '3': 11, '4': 1, '5': 5, '10': 'mcpServers'},
    {'1': 'switch_scope', '3': 12, '4': 1, '5': 9, '10': 'switchScope'},
  ],
};

/// Descriptor for `Plugin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pluginDescriptor = $convert.base64Decode(
    'CgZQbHVnaW4SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSGAoHdmVyc2lvbh'
    'gDIAEoCVIHdmVyc2lvbhIgCgtkZXNjcmlwdGlvbhgEIAEoCVILZGVzY3JpcHRpb24SFAoFc2Nv'
    'cGUYBSABKAlSBXNjb3BlEhIKBHBhdGgYBiABKAlSBHBhdGgSGAoHZW5hYmxlZBgHIAEoCFIHZW'
    '5hYmxlZBIWCgZza2lsbHMYCCABKAVSBnNraWxscxIaCghjb21tYW5kcxgJIAEoBVIIY29tbWFu'
    'ZHMSFgoGYWdlbnRzGAogASgFUgZhZ2VudHMSHwoLbWNwX3NlcnZlcnMYCyABKAVSCm1jcFNlcn'
    'ZlcnMSIQoMc3dpdGNoX3Njb3BlGAwgASgJUgtzd2l0Y2hTY29wZQ==');

@$core.Deprecated('Use setSkillOnRequestDescriptor instead')
const SetSkillOnRequest$json = {
  '1': 'SetSkillOnRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'source', '3': 2, '4': 1, '5': 9, '10': 'source'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'on', '3': 4, '4': 1, '5': 8, '10': 'on'},
    {'1': 'agent', '3': 5, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `SetSkillOnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setSkillOnRequestDescriptor = $convert.base64Decode(
    'ChFTZXRTa2lsbE9uUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchIWCgZzb3VyY2UYAi'
    'ABKAlSBnNvdXJjZRISCgRuYW1lGAMgASgJUgRuYW1lEg4KAm9uGAQgASgIUgJvbhIUCgVhZ2Vu'
    'dBgFIAEoCVIFYWdlbnQ=');

@$core.Deprecated('Use setSkillOnResponseDescriptor instead')
const SetSkillOnResponse$json = {
  '1': 'SetSkillOnResponse',
};

/// Descriptor for `SetSkillOnResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setSkillOnResponseDescriptor =
    $convert.base64Decode('ChJTZXRTa2lsbE9uUmVzcG9uc2U=');

@$core.Deprecated('Use setPluginOnRequestDescriptor instead')
const SetPluginOnRequest$json = {
  '1': 'SetPluginOnRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'on', '3': 3, '4': 1, '5': 8, '10': 'on'},
    {'1': 'agent', '3': 4, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `SetPluginOnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPluginOnRequestDescriptor = $convert.base64Decode(
    'ChJTZXRQbHVnaW5PblJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISDgoCaWQYAiABKA'
    'lSAmlkEg4KAm9uGAMgASgIUgJvbhIUCgVhZ2VudBgEIAEoCVIFYWdlbnQ=');

@$core.Deprecated('Use setPluginOnResponseDescriptor instead')
const SetPluginOnResponse$json = {
  '1': 'SetPluginOnResponse',
};

/// Descriptor for `SetPluginOnResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPluginOnResponseDescriptor =
    $convert.base64Decode('ChNTZXRQbHVnaW5PblJlc3BvbnNl');

@$core.Deprecated('Use uninstallPluginRequestDescriptor instead')
const UninstallPluginRequest$json = {
  '1': 'UninstallPluginRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `UninstallPluginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uninstallPluginRequestDescriptor =
    $convert.base64Decode(
        'ChZVbmluc3RhbGxQbHVnaW5SZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEg4KAmlkGA'
        'IgASgJUgJpZBIUCgVhZ2VudBgDIAEoCVIFYWdlbnQ=');

@$core.Deprecated('Use uninstallPluginResponseDescriptor instead')
const UninstallPluginResponse$json = {
  '1': 'UninstallPluginResponse',
};

/// Descriptor for `UninstallPluginResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uninstallPluginResponseDescriptor =
    $convert.base64Decode('ChdVbmluc3RhbGxQbHVnaW5SZXNwb25zZQ==');

@$core.Deprecated('Use trashSkillRequestDescriptor instead')
const TrashSkillRequest$json = {
  '1': 'TrashSkillRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `TrashSkillRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trashSkillRequestDescriptor = $convert.base64Decode(
    'ChFUcmFzaFNraWxsUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchISCgRwYXRoGAIgAS'
    'gJUgRwYXRoEhQKBWFnZW50GAMgASgJUgVhZ2VudA==');

@$core.Deprecated('Use trashSkillResponseDescriptor instead')
const TrashSkillResponse$json = {
  '1': 'TrashSkillResponse',
};

/// Descriptor for `TrashSkillResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trashSkillResponseDescriptor =
    $convert.base64Decode('ChJUcmFzaFNraWxsUmVzcG9uc2U=');

@$core.Deprecated('Use linkSkillRequestDescriptor instead')
const LinkSkillRequest$json = {
  '1': 'LinkSkillRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'agent', '3': 2, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'path', '3': 3, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `LinkSkillRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkSkillRequestDescriptor = $convert.base64Decode(
    'ChBMaW5rU2tpbGxSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBWFnZW50GAIgAS'
    'gJUgVhZ2VudBISCgRwYXRoGAMgASgJUgRwYXRo');

@$core.Deprecated('Use linkSkillResponseDescriptor instead')
const LinkSkillResponse$json = {
  '1': 'LinkSkillResponse',
};

/// Descriptor for `LinkSkillResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkSkillResponseDescriptor =
    $convert.base64Decode('ChFMaW5rU2tpbGxSZXNwb25zZQ==');

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

@$core.Deprecated('Use getFileRequestDescriptor instead')
const GetFileRequest$json = {
  '1': 'GetFileRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `GetFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFileRequestDescriptor = $convert.base64Decode(
    'Cg5HZXRGaWxlUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchISCgRwYXRoGAIgASgJUg'
    'RwYXRo');

@$core.Deprecated('Use watchChatFileRequestDescriptor instead')
const WatchChatFileRequest$json = {
  '1': 'WatchChatFileRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
  ],
};

/// Descriptor for `WatchChatFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchChatFileRequestDescriptor = $convert.base64Decode(
    'ChRXYXRjaENoYXRGaWxlUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEgoEcGF0aB'
    'gCIAEoCVIEcGF0aA==');

@$core.Deprecated('Use watchChatFileResponseDescriptor instead')
const WatchChatFileResponse$json = {
  '1': 'WatchChatFileResponse',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {'1': 'too_large', '3': 4, '4': 1, '5': 8, '10': 'tooLarge'},
    {'1': 'missing', '3': 5, '4': 1, '5': 8, '10': 'missing'},
  ],
};

/// Descriptor for `WatchChatFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchChatFileResponseDescriptor = $convert.base64Decode(
    'ChVXYXRjaENoYXRGaWxlUmVzcG9uc2USEgoEcGF0aBgBIAEoCVIEcGF0aBISCgRkYXRhGAIgAS'
    'gMUgRkYXRhEhIKBHNpemUYAyABKANSBHNpemUSGwoJdG9vX2xhcmdlGAQgASgIUgh0b29MYXJn'
    'ZRIYCgdtaXNzaW5nGAUgASgIUgdtaXNzaW5n');

@$core.Deprecated('Use getFileResponseDescriptor instead')
const GetFileResponse$json = {
  '1': 'GetFileResponse',
  '2': [
    {
      '1': 'file',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.FileChange',
      '10': 'file'
    },
  ],
};

/// Descriptor for `GetFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getFileResponseDescriptor = $convert.base64Decode(
    'Cg9HZXRGaWxlUmVzcG9uc2USKAoEZmlsZRgBIAEoCzIULm51c2hpLnYxLkZpbGVDaGFuZ2VSBG'
    'ZpbGU=');

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
    {
      '1': 'removed_chats',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.RemovedChats',
      '9': 0,
      '10': 'removedChats'
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
    'BSB2Ryb3BwZWQSKgoGcmVtb3RlGA4gASgLMhAubnVzaGkudjEuUmVtb3RlSABSBnJlbW90ZRI9'
    'Cg1yZW1vdmVkX2NoYXRzGA8gASgLMhYubnVzaGkudjEuUmVtb3ZlZENoYXRzSABSDHJlbW92ZW'
    'RDaGF0c0IGCgRraW5k');

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
    {'1': 'relay_call', '3': 28, '4': 1, '5': 9, '10': 'relayCall'},
    {'1': 'relay_state', '3': 29, '4': 1, '5': 9, '10': 'relayState'},
    {'1': 'relayed_by', '3': 30, '4': 1, '5': 9, '10': 'relayedBy'},
    {
      '1': 'findings',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Findings',
      '10': 'findings'
    },
    {'1': 'relay_stop', '3': 32, '4': 1, '5': 8, '10': 'relayStop'},
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
    'ZBIZCghyZWxheV90bxgbIAEoCVIHcmVsYXlUbxIdCgpyZWxheV9jYWxsGBwgASgJUglyZWxheU'
    'NhbGwSHwoLcmVsYXlfc3RhdGUYHSABKAlSCnJlbGF5U3RhdGUSHQoKcmVsYXllZF9ieRgeIAEo'
    'CVIJcmVsYXllZEJ5Ei4KCGZpbmRpbmdzGB8gASgLMhIubnVzaGkudjEuRmluZGluZ3NSCGZpbm'
    'RpbmdzEh0KCnJlbGF5X3N0b3AYICABKAhSCXJlbGF5U3RvcA==');

@$core.Deprecated('Use findingsDescriptor instead')
const Findings$json = {
  '1': 'Findings',
  '2': [
    {'1': 'level', '3': 1, '4': 1, '5': 9, '10': 'level'},
    {
      '1': 'items',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Finding',
      '10': 'items'
    },
  ],
};

/// Descriptor for `Findings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findingsDescriptor = $convert.base64Decode(
    'CghGaW5kaW5ncxIUCgVsZXZlbBgBIAEoCVIFbGV2ZWwSJwoFaXRlbXMYAiADKAsyES5udXNoaS'
    '52MS5GaW5kaW5nUgVpdGVtcw==');

@$core.Deprecated('Use findingDescriptor instead')
const Finding$json = {
  '1': 'Finding',
  '2': [
    {'1': 'file', '3': 1, '4': 1, '5': 9, '10': 'file'},
    {'1': 'line', '3': 2, '4': 1, '5': 5, '10': 'line'},
    {'1': 'summary', '3': 3, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'short_summary', '3': 4, '4': 1, '5': 9, '10': 'shortSummary'},
    {'1': 'failure_scenario', '3': 5, '4': 1, '5': 9, '10': 'failureScenario'},
    {'1': 'category', '3': 6, '4': 1, '5': 9, '10': 'category'},
    {'1': 'verdict', '3': 7, '4': 1, '5': 9, '10': 'verdict'},
    {'1': 'outcome', '3': 8, '4': 1, '5': 9, '10': 'outcome'},
  ],
};

/// Descriptor for `Finding`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findingDescriptor = $convert.base64Decode(
    'CgdGaW5kaW5nEhIKBGZpbGUYASABKAlSBGZpbGUSEgoEbGluZRgCIAEoBVIEbGluZRIYCgdzdW'
    '1tYXJ5GAMgASgJUgdzdW1tYXJ5EiMKDXNob3J0X3N1bW1hcnkYBCABKAlSDHNob3J0U3VtbWFy'
    'eRIpChBmYWlsdXJlX3NjZW5hcmlvGAUgASgJUg9mYWlsdXJlU2NlbmFyaW8SGgoIY2F0ZWdvcn'
    'kYBiABKAlSCGNhdGVnb3J5EhgKB3ZlcmRpY3QYByABKAlSB3ZlcmRpY3QSGAoHb3V0Y29tZRgI'
    'IAEoCVIHb3V0Y29tZQ==');

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
    {'1': 'session', '3': 5, '4': 1, '5': 9, '10': 'session'},
  ],
};

/// Descriptor for `Subagent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subagentDescriptor = $convert.base64Decode(
    'CghTdWJhZ2VudBIUCgVzdGF0ZRgBIAEoCVIFc3RhdGUSGAoHc3RhcnRlZBgCIAEoA1IHc3Rhcn'
    'RlZBIUCgVlbmRlZBgDIAEoA1IFZW5kZWQSFgoGcmVzdWx0GAQgASgJUgZyZXN1bHQSGAoHc2Vz'
    'c2lvbhgFIAEoCVIHc2Vzc2lvbg==');

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
    {'1': 'index', '3': 3, '4': 1, '5': 5, '10': 'index'},
  ],
};

/// Descriptor for `ItemEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List itemEventDescriptor = $convert.base64Decode(
    'CglJdGVtRXZlbnQSIgoEaXRlbRgBIAEoCzIOLm51c2hpLnYxLkl0ZW1SBGl0ZW0SFgoGYXBwZW'
    '5kGAIgASgIUgZhcHBlbmQSFAoFaW5kZXgYAyABKAVSBWluZGV4');

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
    {'1': 'reopen_failed', '3': 12, '4': 1, '5': 8, '10': 'reopenFailed'},
    {'1': 'session_gone', '3': 13, '4': 1, '5': 8, '10': 'sessionGone'},
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
    'sgASgIUghjYW5TbGVlcBIjCg1yZW9wZW5fZmFpbGVkGAwgASgIUgxyZW9wZW5GYWlsZWQSIQoM'
    'c2Vzc2lvbl9nb25lGA0gASgIUgtzZXNzaW9uR29uZUoECAIQA1IFZXJyb3I=');

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
    {'1': 'key', '3': 8, '4': 1, '5': 12, '10': 'key'},
  ],
};

/// Descriptor for `Remote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteDescriptor = $convert.base64Decode(
    'CgZSZW1vdGUSDgoCb24YASABKAhSAm9uEhQKBXJlbGF5GAIgASgJUgVyZWxheRIUCgVzdGF0ZR'
    'gDIAEoCVIFc3RhdGUSFAoFZXJyb3IYBCABKAlSBWVycm9yEioKB2RldmljZXMYBSADKAsyEC5u'
    'dXNoaS52MS5EZXZpY2VSB2RldmljZXMSKwoHcGFpcmluZxgGIAEoCzIRLm51c2hpLnYxLlBhaX'
    'JpbmdSB3BhaXJpbmcSHgoKcmVuZGV6dm91cxgHIAEoCVIKcmVuZGV6dm91cxIQCgNrZXkYCCAB'
    'KAxSA2tleQ==');

@$core.Deprecated('Use deviceDescriptor instead')
const Device$json = {
  '1': 'Device',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'paired', '3': 3, '4': 1, '5': 3, '10': 'paired'},
    {'1': 'last_seen', '3': 4, '4': 1, '5': 3, '10': 'lastSeen'},
    {'1': 'connected', '3': 5, '4': 1, '5': 8, '10': 'connected'},
    {'1': 'kind', '3': 6, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'push', '3': 7, '4': 1, '5': 8, '10': 'push'},
  ],
};

/// Descriptor for `Device`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deviceDescriptor = $convert.base64Decode(
    'CgZEZXZpY2USDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFgoGcGFpcmVkGA'
    'MgASgDUgZwYWlyZWQSGwoJbGFzdF9zZWVuGAQgASgDUghsYXN0U2VlbhIcCgljb25uZWN0ZWQY'
    'BSABKAhSCWNvbm5lY3RlZBISCgRraW5kGAYgASgJUgRraW5kEhIKBHB1c2gYByABKAhSBHB1c2'
    'g=');

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

@$core.Deprecated('Use getPushKeyRequestDescriptor instead')
const GetPushKeyRequest$json = {
  '1': 'GetPushKeyRequest',
};

/// Descriptor for `GetPushKeyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPushKeyRequestDescriptor =
    $convert.base64Decode('ChFHZXRQdXNoS2V5UmVxdWVzdA==');

@$core.Deprecated('Use getPushKeyResponseDescriptor instead')
const GetPushKeyResponse$json = {
  '1': 'GetPushKeyResponse',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
  ],
};

/// Descriptor for `GetPushKeyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPushKeyResponseDescriptor = $convert
    .base64Decode('ChJHZXRQdXNoS2V5UmVzcG9uc2USEAoDa2V5GAEgASgJUgNrZXk=');

@$core.Deprecated('Use setPushSubscriptionRequestDescriptor instead')
const SetPushSubscriptionRequest$json = {
  '1': 'SetPushSubscriptionRequest',
  '2': [
    {'1': 'endpoint', '3': 1, '4': 1, '5': 9, '10': 'endpoint'},
    {'1': 'p256dh', '3': 2, '4': 1, '5': 12, '10': 'p256dh'},
    {'1': 'auth', '3': 3, '4': 1, '5': 12, '10': 'auth'},
  ],
};

/// Descriptor for `SetPushSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPushSubscriptionRequestDescriptor =
    $convert.base64Decode(
        'ChpTZXRQdXNoU3Vic2NyaXB0aW9uUmVxdWVzdBIaCghlbmRwb2ludBgBIAEoCVIIZW5kcG9pbn'
        'QSFgoGcDI1NmRoGAIgASgMUgZwMjU2ZGgSEgoEYXV0aBgDIAEoDFIEYXV0aA==');

@$core.Deprecated('Use setPushSubscriptionResponseDescriptor instead')
const SetPushSubscriptionResponse$json = {
  '1': 'SetPushSubscriptionResponse',
};

/// Descriptor for `SetPushSubscriptionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPushSubscriptionResponseDescriptor =
    $convert.base64Decode('ChtTZXRQdXNoU3Vic2NyaXB0aW9uUmVzcG9uc2U=');

@$core.Deprecated('Use setDeviceViewRequestDescriptor instead')
const SetDeviceViewRequest$json = {
  '1': 'SetDeviceViewRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `SetDeviceViewRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDeviceViewRequestDescriptor =
    $convert.base64Decode(
        'ChRTZXREZXZpY2VWaWV3UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use setDeviceViewResponseDescriptor instead')
const SetDeviceViewResponse$json = {
  '1': 'SetDeviceViewResponse',
};

/// Descriptor for `SetDeviceViewResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setDeviceViewResponseDescriptor =
    $convert.base64Decode('ChVTZXREZXZpY2VWaWV3UmVzcG9uc2U=');

@$core.Deprecated('Use sendTestPushRequestDescriptor instead')
const SendTestPushRequest$json = {
  '1': 'SendTestPushRequest',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
  ],
};

/// Descriptor for `SendTestPushRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendTestPushRequestDescriptor =
    $convert.base64Decode(
        'ChNTZW5kVGVzdFB1c2hSZXF1ZXN0EhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQ=');

@$core.Deprecated('Use sendTestPushResponseDescriptor instead')
const SendTestPushResponse$json = {
  '1': 'SendTestPushResponse',
};

/// Descriptor for `SendTestPushResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendTestPushResponseDescriptor =
    $convert.base64Decode('ChRTZW5kVGVzdFB1c2hSZXNwb25zZQ==');

@$core.Deprecated('Use unpairThisDeviceRequestDescriptor instead')
const UnpairThisDeviceRequest$json = {
  '1': 'UnpairThisDeviceRequest',
};

/// Descriptor for `UnpairThisDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unpairThisDeviceRequestDescriptor =
    $convert.base64Decode('ChdVbnBhaXJUaGlzRGV2aWNlUmVxdWVzdA==');

@$core.Deprecated('Use unpairThisDeviceResponseDescriptor instead')
const UnpairThisDeviceResponse$json = {
  '1': 'UnpairThisDeviceResponse',
};

/// Descriptor for `UnpairThisDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unpairThisDeviceResponseDescriptor =
    $convert.base64Decode('ChhVbnBhaXJUaGlzRGV2aWNlUmVzcG9uc2U=');

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
    {'1': 'needs_restart', '3': 13, '4': 1, '5': 8, '10': 'needsRestart'},
  ],
};

/// Descriptor for `JiraSite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraSiteDescriptor = $convert.base64Decode(
    'CghKaXJhU2l0ZRIOCgJpZBgBIAEoCVICaWQSEAoDdXJsGAIgASgJUgN1cmwSFAoFZW1haWwYAy'
    'ABKAlSBWVtYWlsEhIKBG5hbWUYBCABKAlSBG5hbWUSHQoKYWNjb3VudF9pZBgFIAEoCVIJYWNj'
    'b3VudElkEhYKBnNjb3BlZBgGIAEoCFIGc2NvcGVkEhgKB2V4cGlyZXMYByABKANSB2V4cGlyZX'
    'MSFAoFYm9hcmQYCCABKANSBWJvYXJkEh0KCmJvYXJkX25hbWUYCSABKAlSCWJvYXJkTmFtZRIw'
    'CghzZWFyY2hlcxgKIAMoCzIULm51c2hpLnYxLkppcmFTZWFyY2hSCHNlYXJjaGVzEhgKB3Byb2'
    'JsZW0YCyABKAlSB3Byb2JsZW0SGQoIbmVlZHNfb2sYDCABKAhSB25lZWRzT2sSIwoNbmVlZHNf'
    'cmVzdGFydBgNIAEoCFIMbmVlZHNSZXN0YXJ0');

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
    {'1': 'assignee_id', '3': 21, '4': 1, '5': 9, '10': 'assigneeId'},
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
    'LnYxLkppcmFSZW1vdGVMaW5rUgtyZW1vdGVMaW5rcxIQCgN1cmwYFCABKAlSA3VybBIfCgthc3'
    'NpZ25lZV9pZBgVIAEoCVIKYXNzaWduZWVJZA==');

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
    {'1': 'cached', '3': 4, '4': 1, '5': 8, '10': 'cached'},
  ],
};

/// Descriptor for `ListJiraIssuesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraIssuesRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0SmlyYUlzc3Vlc1JlcXVlc3QSEgoEc2l0ZRgBIAEoCVIEc2l0ZRISCgRsaXN0GAIgAS'
    'gJUgRsaXN0EhAKA2pxbBgDIAEoCVIDanFsEhYKBmNhY2hlZBgEIAEoCFIGY2FjaGVk');

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
    {'1': 'at_ms', '3': 3, '4': 1, '5': 3, '10': 'atMs'},
  ],
};

/// Descriptor for `ListJiraIssuesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listJiraIssuesResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0SmlyYUlzc3Vlc1Jlc3BvbnNlEisKBmlzc3VlcxgBIAMoCzITLm51c2hpLnYxLkppcm'
    'FJc3N1ZVIGaXNzdWVzEhYKBnNwcmludBgCIAEoCVIGc3ByaW50EhMKBWF0X21zGAMgASgDUgRh'
    'dE1z');

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
    {'1': 'cached', '3': 3, '4': 1, '5': 8, '10': 'cached'},
  ],
};

/// Descriptor for `GetJiraIssueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraIssueRequestDescriptor = $convert.base64Decode(
    'ChNHZXRKaXJhSXNzdWVSZXF1ZXN0EhIKBHNpdGUYASABKAlSBHNpdGUSEAoDa2V5GAIgASgJUg'
    'NrZXkSFgoGY2FjaGVkGAMgASgIUgZjYWNoZWQ=');

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
    {
      '1': 'agent_writes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraWrite',
      '10': 'agentWrites'
    },
    {'1': 'at_ms', '3': 3, '4': 1, '5': 3, '10': 'atMs'},
  ],
};

/// Descriptor for `GetJiraIssueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getJiraIssueResponseDescriptor = $convert.base64Decode(
    'ChRHZXRKaXJhSXNzdWVSZXNwb25zZRIpCgVpc3N1ZRgBIAEoCzITLm51c2hpLnYxLkppcmFJc3'
    'N1ZVIFaXNzdWUSNgoMYWdlbnRfd3JpdGVzGAIgAygLMhMubnVzaGkudjEuSmlyYVdyaXRlUgth'
    'Z2VudFdyaXRlcxITCgVhdF9tcxgDIAEoA1IEYXRNcw==');

@$core.Deprecated('Use jiraWriteDescriptor instead')
const JiraWrite$json = {
  '1': 'JiraWrite',
  '2': [
    {'1': 'kind', '3': 1, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'comment', '3': 2, '4': 1, '5': 9, '10': 'comment'},
    {'1': 'to', '3': 3, '4': 1, '5': 9, '10': 'to'},
    {'1': 'chat', '3': 4, '4': 1, '5': 9, '10': 'chat'},
    {'1': 'agent', '3': 5, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'at', '3': 6, '4': 1, '5': 3, '10': 'at'},
  ],
};

/// Descriptor for `JiraWrite`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraWriteDescriptor = $convert.base64Decode(
    'CglKaXJhV3JpdGUSEgoEa2luZBgBIAEoCVIEa2luZBIYCgdjb21tZW50GAIgASgJUgdjb21tZW'
    '50Eg4KAnRvGAMgASgJUgJ0bxISCgRjaGF0GAQgASgJUgRjaGF0EhQKBWFnZW50GAUgASgJUgVh'
    'Z2VudBIOCgJhdBgGIAEoA1ICYXQ=');

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

@$core.Deprecated('Use findJiraIssuesRequestDescriptor instead')
const FindJiraIssuesRequest$json = {
  '1': 'FindJiraIssuesRequest',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
    {'1': 'site', '3': 2, '4': 1, '5': 9, '10': 'site'},
  ],
};

/// Descriptor for `FindJiraIssuesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findJiraIssuesRequestDescriptor = $convert.base64Decode(
    'ChVGaW5kSmlyYUlzc3Vlc1JlcXVlc3QSEgoEdGV4dBgBIAEoCVIEdGV4dBISCgRzaXRlGAIgAS'
    'gJUgRzaXRl');

@$core.Deprecated('Use findJiraIssuesResponseDescriptor instead')
const FindJiraIssuesResponse$json = {
  '1': 'FindJiraIssuesResponse',
  '2': [
    {
      '1': 'issues',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FoundJiraIssue',
      '10': 'issues'
    },
    {'1': 'unknown_site', '3': 2, '4': 1, '5': 9, '10': 'unknownSite'},
  ],
};

/// Descriptor for `FindJiraIssuesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findJiraIssuesResponseDescriptor = $convert.base64Decode(
    'ChZGaW5kSmlyYUlzc3Vlc1Jlc3BvbnNlEjAKBmlzc3VlcxgBIAMoCzIYLm51c2hpLnYxLkZvdW'
    '5kSmlyYUlzc3VlUgZpc3N1ZXMSIQoMdW5rbm93bl9zaXRlGAIgASgJUgt1bmtub3duU2l0ZQ==');

@$core.Deprecated('Use foundJiraIssueDescriptor instead')
const FoundJiraIssue$json = {
  '1': 'FoundJiraIssue',
  '2': [
    {'1': 'site', '3': 1, '4': 1, '5': 9, '10': 'site'},
    {
      '1': 'issue',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.JiraIssue',
      '10': 'issue'
    },
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
  ],
};

/// Descriptor for `FoundJiraIssue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List foundJiraIssueDescriptor = $convert.base64Decode(
    'Cg5Gb3VuZEppcmFJc3N1ZRISCgRzaXRlGAEgASgJUgRzaXRlEikKBWlzc3VlGAIgASgLMhMubn'
    'VzaGkudjEuSmlyYUlzc3VlUgVpc3N1ZRIWCgZicmFuY2gYAyABKAlSBmJyYW5jaA==');

@$core.Deprecated('Use gitHubBucketDescriptor instead')
const GitHubBucket$json = {
  '1': 'GitHubBucket',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'remaining', '3': 3, '4': 1, '5': 5, '10': 'remaining'},
    {'1': 'reset_ms', '3': 4, '4': 1, '5': 3, '10': 'resetMs'},
  ],
};

/// Descriptor for `GitHubBucket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubBucketDescriptor = $convert.base64Decode(
    'CgxHaXRIdWJCdWNrZXQSEgoEbmFtZRgBIAEoCVIEbmFtZRIUCgVsaW1pdBgCIAEoBVIFbGltaX'
    'QSHAoJcmVtYWluaW5nGAMgASgFUglyZW1haW5pbmcSGQoIcmVzZXRfbXMYBCABKANSB3Jlc2V0'
    'TXM=');

@$core.Deprecated('Use gitHubHostDescriptor instead')
const GitHubHost$json = {
  '1': 'GitHubHost',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'login', '3': 2, '4': 1, '5': 9, '10': 'login'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'source', '3': 4, '4': 1, '5': 9, '10': 'source'},
    {'1': 'kind', '3': 5, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'scopes', '3': 6, '4': 3, '5': 9, '10': 'scopes'},
    {
      '1': 'budget',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubBucket',
      '10': 'budget'
    },
    {'1': 'problem', '3': 8, '4': 1, '5': 9, '10': 'problem'},
    {'1': 'needs_ok', '3': 9, '4': 1, '5': 8, '10': 'needsOk'},
    {'1': 'pasted', '3': 10, '4': 1, '5': 8, '10': 'pasted'},
    {'1': 'needs_restart', '3': 11, '4': 1, '5': 8, '10': 'needsRestart'},
  ],
};

/// Descriptor for `GitHubHost`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubHostDescriptor = $convert.base64Decode(
    'CgpHaXRIdWJIb3N0EhIKBGhvc3QYASABKAlSBGhvc3QSFAoFbG9naW4YAiABKAlSBWxvZ2luEh'
    'IKBG5hbWUYAyABKAlSBG5hbWUSFgoGc291cmNlGAQgASgJUgZzb3VyY2USEgoEa2luZBgFIAEo'
    'CVIEa2luZBIWCgZzY29wZXMYBiADKAlSBnNjb3BlcxIuCgZidWRnZXQYByADKAsyFi5udXNoaS'
    '52MS5HaXRIdWJCdWNrZXRSBmJ1ZGdldBIYCgdwcm9ibGVtGAggASgJUgdwcm9ibGVtEhkKCG5l'
    'ZWRzX29rGAkgASgIUgduZWVkc09rEhYKBnBhc3RlZBgKIAEoCFIGcGFzdGVkEiMKDW5lZWRzX3'
    'Jlc3RhcnQYCyABKAhSDG5lZWRzUmVzdGFydA==');

@$core.Deprecated('Use listGitHubHostsRequestDescriptor instead')
const ListGitHubHostsRequest$json = {
  '1': 'ListGitHubHostsRequest',
};

/// Descriptor for `ListGitHubHostsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGitHubHostsRequestDescriptor =
    $convert.base64Decode('ChZMaXN0R2l0SHViSG9zdHNSZXF1ZXN0');

@$core.Deprecated('Use listGitHubHostsResponseDescriptor instead')
const ListGitHubHostsResponse$json = {
  '1': 'ListGitHubHostsResponse',
  '2': [
    {
      '1': 'hosts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubHost',
      '10': 'hosts'
    },
  ],
};

/// Descriptor for `ListGitHubHostsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGitHubHostsResponseDescriptor =
    $convert.base64Decode(
        'ChdMaXN0R2l0SHViSG9zdHNSZXNwb25zZRIqCgVob3N0cxgBIAMoCzIULm51c2hpLnYxLkdpdE'
        'h1Ykhvc3RSBWhvc3Rz');

@$core.Deprecated('Use addGitHubTokenRequestDescriptor instead')
const AddGitHubTokenRequest$json = {
  '1': 'AddGitHubTokenRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'token', '3': 2, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `AddGitHubTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addGitHubTokenRequestDescriptor = $convert.base64Decode(
    'ChVBZGRHaXRIdWJUb2tlblJlcXVlc3QSEgoEaG9zdBgBIAEoCVIEaG9zdBIUCgV0b2tlbhgCIA'
    'EoCVIFdG9rZW4=');

@$core.Deprecated('Use addGitHubTokenResponseDescriptor instead')
const AddGitHubTokenResponse$json = {
  '1': 'AddGitHubTokenResponse',
  '2': [
    {'1': 'login', '3': 1, '4': 1, '5': 9, '10': 'login'},
  ],
};

/// Descriptor for `AddGitHubTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addGitHubTokenResponseDescriptor =
    $convert.base64Decode(
        'ChZBZGRHaXRIdWJUb2tlblJlc3BvbnNlEhQKBWxvZ2luGAEgASgJUgVsb2dpbg==');

@$core.Deprecated('Use removeGitHubTokenRequestDescriptor instead')
const RemoveGitHubTokenRequest$json = {
  '1': 'RemoveGitHubTokenRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
  ],
};

/// Descriptor for `RemoveGitHubTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeGitHubTokenRequestDescriptor =
    $convert.base64Decode(
        'ChhSZW1vdmVHaXRIdWJUb2tlblJlcXVlc3QSEgoEaG9zdBgBIAEoCVIEaG9zdA==');

@$core.Deprecated('Use removeGitHubTokenResponseDescriptor instead')
const RemoveGitHubTokenResponse$json = {
  '1': 'RemoveGitHubTokenResponse',
};

/// Descriptor for `RemoveGitHubTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeGitHubTokenResponseDescriptor =
    $convert.base64Decode('ChlSZW1vdmVHaXRIdWJUb2tlblJlc3BvbnNl');

@$core.Deprecated('Use allowGitHubTokenRequestDescriptor instead')
const AllowGitHubTokenRequest$json = {
  '1': 'AllowGitHubTokenRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
  ],
};

/// Descriptor for `AllowGitHubTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List allowGitHubTokenRequestDescriptor =
    $convert.base64Decode(
        'ChdBbGxvd0dpdEh1YlRva2VuUmVxdWVzdBISCgRob3N0GAEgASgJUgRob3N0');

@$core.Deprecated('Use allowGitHubTokenResponseDescriptor instead')
const AllowGitHubTokenResponse$json = {
  '1': 'AllowGitHubTokenResponse',
};

/// Descriptor for `AllowGitHubTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List allowGitHubTokenResponseDescriptor =
    $convert.base64Decode('ChhBbGxvd0dpdEh1YlRva2VuUmVzcG9uc2U=');

@$core.Deprecated('Use gitHubRepoDescriptor instead')
const GitHubRepo$json = {
  '1': 'GitHubRepo',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'repo', '3': 2, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'folders', '3': 3, '4': 3, '5': 9, '10': 'folders'},
  ],
};

/// Descriptor for `GitHubRepo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubRepoDescriptor = $convert.base64Decode(
    'CgpHaXRIdWJSZXBvEhIKBGhvc3QYASABKAlSBGhvc3QSEgoEcmVwbxgCIAEoCVIEcmVwbxIYCg'
    'dmb2xkZXJzGAMgAygJUgdmb2xkZXJz');

@$core.Deprecated('Use listGitHubReposRequestDescriptor instead')
const ListGitHubReposRequest$json = {
  '1': 'ListGitHubReposRequest',
  '2': [
    {'1': 'folders', '3': 1, '4': 3, '5': 9, '10': 'folders'},
  ],
};

/// Descriptor for `ListGitHubReposRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGitHubReposRequestDescriptor =
    $convert.base64Decode(
        'ChZMaXN0R2l0SHViUmVwb3NSZXF1ZXN0EhgKB2ZvbGRlcnMYASADKAlSB2ZvbGRlcnM=');

@$core.Deprecated('Use listGitHubReposResponseDescriptor instead')
const ListGitHubReposResponse$json = {
  '1': 'ListGitHubReposResponse',
  '2': [
    {
      '1': 'repos',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubRepo',
      '10': 'repos'
    },
  ],
};

/// Descriptor for `ListGitHubReposResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGitHubReposResponseDescriptor =
    $convert.base64Decode(
        'ChdMaXN0R2l0SHViUmVwb3NSZXNwb25zZRIqCgVyZXBvcxgBIAMoCzIULm51c2hpLnYxLkdpdE'
        'h1YlJlcG9SBXJlcG9z');

@$core.Deprecated('Use gitHubRefDescriptor instead')
const GitHubRef$json = {
  '1': 'GitHubRef',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'repo', '3': 2, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'number', '3': 3, '4': 1, '5': 5, '10': 'number'},
  ],
};

/// Descriptor for `GitHubRef`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubRefDescriptor = $convert.base64Decode(
    'CglHaXRIdWJSZWYSEgoEaG9zdBgBIAEoCVIEaG9zdBISCgRyZXBvGAIgASgJUgRyZXBvEhYKBm'
    '51bWJlchgDIAEoBVIGbnVtYmVy');

@$core.Deprecated('Use gitHubItemDescriptor instead')
const GitHubItem$json = {
  '1': 'GitHubItem',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'pull', '3': 3, '4': 1, '5': 8, '10': 'pull'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'url', '3': 5, '4': 1, '5': 9, '10': 'url'},
    {'1': 'state', '3': 6, '4': 1, '5': 9, '10': 'state'},
    {'1': 'draft', '3': 7, '4': 1, '5': 8, '10': 'draft'},
    {'1': 'author', '3': 8, '4': 1, '5': 9, '10': 'author'},
    {'1': 'updated_ms', '3': 9, '4': 1, '5': 3, '10': 'updatedMs'},
    {'1': 'checks', '3': 10, '4': 1, '5': 9, '10': 'checks'},
    {'1': 'review', '3': 11, '4': 1, '5': 9, '10': 'review'},
    {'1': 'unresolved', '3': 12, '4': 1, '5': 5, '10': 'unresolved'},
    {'1': 'comments', '3': 13, '4': 1, '5': 5, '10': 'comments'},
  ],
};

/// Descriptor for `GitHubItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubItemDescriptor = $convert.base64Decode(
    'CgpHaXRIdWJJdGVtEiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLkdpdEh1YlJlZlIDcmVmEg4KAm'
    'lkGAIgASgJUgJpZBISCgRwdWxsGAMgASgIUgRwdWxsEhQKBXRpdGxlGAQgASgJUgV0aXRsZRIQ'
    'CgN1cmwYBSABKAlSA3VybBIUCgVzdGF0ZRgGIAEoCVIFc3RhdGUSFAoFZHJhZnQYByABKAhSBW'
    'RyYWZ0EhYKBmF1dGhvchgIIAEoCVIGYXV0aG9yEh0KCnVwZGF0ZWRfbXMYCSABKANSCXVwZGF0'
    'ZWRNcxIWCgZjaGVja3MYCiABKAlSBmNoZWNrcxIWCgZyZXZpZXcYCyABKAlSBnJldmlldxIeCg'
    'p1bnJlc29sdmVkGAwgASgFUgp1bnJlc29sdmVkEhoKCGNvbW1lbnRzGA0gASgFUghjb21tZW50'
    'cw==');

@$core.Deprecated('Use listGitHubInboxRequestDescriptor instead')
const ListGitHubInboxRequest$json = {
  '1': 'ListGitHubInboxRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'repos', '3': 2, '4': 3, '5': 9, '10': 'repos'},
    {'1': 'quiet', '3': 3, '4': 1, '5': 8, '10': 'quiet'},
    {'1': 'teams', '3': 4, '4': 1, '5': 8, '10': 'teams'},
    {'1': 'cached', '3': 5, '4': 1, '5': 8, '10': 'cached'},
    {'1': 'updated_days', '3': 6, '4': 1, '5': 5, '10': 'updatedDays'},
    {'1': 'wide', '3': 7, '4': 3, '5': 9, '10': 'wide'},
    {'1': 'hide', '3': 8, '4': 3, '5': 9, '10': 'hide'},
    {'1': 'owners', '3': 9, '4': 3, '5': 9, '10': 'owners'},
  ],
};

/// Descriptor for `ListGitHubInboxRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGitHubInboxRequestDescriptor = $convert.base64Decode(
    'ChZMaXN0R2l0SHViSW5ib3hSZXF1ZXN0EhIKBGhvc3QYASABKAlSBGhvc3QSFAoFcmVwb3MYAi'
    'ADKAlSBXJlcG9zEhQKBXF1aWV0GAMgASgIUgVxdWlldBIUCgV0ZWFtcxgEIAEoCFIFdGVhbXMS'
    'FgoGY2FjaGVkGAUgASgIUgZjYWNoZWQSIQoMdXBkYXRlZF9kYXlzGAYgASgFUgt1cGRhdGVkRG'
    'F5cxISCgR3aWRlGAcgAygJUgR3aWRlEhIKBGhpZGUYCCADKAlSBGhpZGUSFgoGb3duZXJzGAkg'
    'AygJUgZvd25lcnM=');

@$core.Deprecated('Use listGitHubInboxResponseDescriptor instead')
const ListGitHubInboxResponse$json = {
  '1': 'ListGitHubInboxResponse',
  '2': [
    {
      '1': 'review',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'review'
    },
    {
      '1': 'mine',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'mine'
    },
    {
      '1': 'assigned',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'assigned'
    },
    {'1': 'review_total', '3': 4, '4': 1, '5': 5, '10': 'reviewTotal'},
    {'1': 'mine_total', '3': 5, '4': 1, '5': 5, '10': 'mineTotal'},
    {'1': 'assigned_total', '3': 6, '4': 1, '5': 5, '10': 'assignedTotal'},
    {'1': 'at_ms', '3': 7, '4': 1, '5': 3, '10': 'atMs'},
    {'1': 'stale', '3': 8, '4': 1, '5': 9, '10': 'stale'},
    {'1': 'review_older', '3': 9, '4': 1, '5': 5, '10': 'reviewOlder'},
    {'1': 'mine_older', '3': 10, '4': 1, '5': 5, '10': 'mineOlder'},
    {'1': 'assigned_older', '3': 11, '4': 1, '5': 5, '10': 'assignedOlder'},
  ],
};

/// Descriptor for `ListGitHubInboxResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGitHubInboxResponseDescriptor = $convert.base64Decode(
    'ChdMaXN0R2l0SHViSW5ib3hSZXNwb25zZRIsCgZyZXZpZXcYASADKAsyFC5udXNoaS52MS5HaX'
    'RIdWJJdGVtUgZyZXZpZXcSKAoEbWluZRgCIAMoCzIULm51c2hpLnYxLkdpdEh1Ykl0ZW1SBG1p'
    'bmUSMAoIYXNzaWduZWQYAyADKAsyFC5udXNoaS52MS5HaXRIdWJJdGVtUghhc3NpZ25lZBIhCg'
    'xyZXZpZXdfdG90YWwYBCABKAVSC3Jldmlld1RvdGFsEh0KCm1pbmVfdG90YWwYBSABKAVSCW1p'
    'bmVUb3RhbBIlCg5hc3NpZ25lZF90b3RhbBgGIAEoBVINYXNzaWduZWRUb3RhbBITCgVhdF9tcx'
    'gHIAEoA1IEYXRNcxIUCgVzdGFsZRgIIAEoCVIFc3RhbGUSIQoMcmV2aWV3X29sZGVyGAkgASgF'
    'UgtyZXZpZXdPbGRlchIdCgptaW5lX29sZGVyGAogASgFUgltaW5lT2xkZXISJQoOYXNzaWduZW'
    'Rfb2xkZXIYCyABKAVSDWFzc2lnbmVkT2xkZXI=');

@$core.Deprecated('Use gitHubLinkDescriptor instead')
const GitHubLink$json = {
  '1': 'GitHubLink',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'id', '3': 2, '4': 1, '5': 9, '10': 'id'},
    {'1': 'repo', '3': 3, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'number', '3': 4, '4': 1, '5': 5, '10': 'number'},
    {'1': 'pull', '3': 5, '4': 1, '5': 8, '10': 'pull'},
  ],
};

/// Descriptor for `GitHubLink`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubLinkDescriptor = $convert.base64Decode(
    'CgpHaXRIdWJMaW5rEhIKBGhvc3QYASABKAlSBGhvc3QSDgoCaWQYAiABKAlSAmlkEhIKBHJlcG'
    '8YAyABKAlSBHJlcG8SFgoGbnVtYmVyGAQgASgFUgZudW1iZXISEgoEcHVsbBgFIAEoCFIEcHVs'
    'bA==');

@$core.Deprecated('Use getGitHubStatesRequestDescriptor instead')
const GetGitHubStatesRequest$json = {
  '1': 'GetGitHubStatesRequest',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'items'
    },
    {'1': 'quiet', '3': 2, '4': 1, '5': 8, '10': 'quiet'},
  ],
};

/// Descriptor for `GetGitHubStatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubStatesRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRHaXRIdWJTdGF0ZXNSZXF1ZXN0EioKBWl0ZW1zGAEgAygLMhQubnVzaGkudjEuR2l0SH'
        'ViTGlua1IFaXRlbXMSFAoFcXVpZXQYAiABKAhSBXF1aWV0');

@$core.Deprecated('Use getGitHubStatesResponseDescriptor instead')
const GetGitHubStatesResponse$json = {
  '1': 'GetGitHubStatesResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'items'
    },
  ],
};

/// Descriptor for `GetGitHubStatesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubStatesResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRHaXRIdWJTdGF0ZXNSZXNwb25zZRIqCgVpdGVtcxgBIAMoCzIULm51c2hpLnYxLkdpdE'
        'h1Ykl0ZW1SBWl0ZW1z');

@$core.Deprecated('Use gitHubCommentDescriptor instead')
const GitHubComment$json = {
  '1': 'GitHubComment',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'author', '3': 2, '4': 1, '5': 9, '10': 'author'},
    {'1': 'association', '3': 3, '4': 1, '5': 9, '10': 'association'},
    {'1': 'outside', '3': 4, '4': 1, '5': 8, '10': 'outside'},
    {'1': 'bot', '3': 5, '4': 1, '5': 8, '10': 'bot'},
    {'1': 'body', '3': 6, '4': 1, '5': 9, '10': 'body'},
    {'1': 'url', '3': 7, '4': 1, '5': 9, '10': 'url'},
    {'1': 'created_ms', '3': 8, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'review', '3': 9, '4': 1, '5': 9, '10': 'review'},
  ],
};

/// Descriptor for `GitHubComment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubCommentDescriptor = $convert.base64Decode(
    'Cg1HaXRIdWJDb21tZW50Eg4KAmlkGAEgASgJUgJpZBIWCgZhdXRob3IYAiABKAlSBmF1dGhvch'
    'IgCgthc3NvY2lhdGlvbhgDIAEoCVILYXNzb2NpYXRpb24SGAoHb3V0c2lkZRgEIAEoCFIHb3V0'
    'c2lkZRIQCgNib3QYBSABKAhSA2JvdBISCgRib2R5GAYgASgJUgRib2R5EhAKA3VybBgHIAEoCV'
    'IDdXJsEh0KCmNyZWF0ZWRfbXMYCCABKANSCWNyZWF0ZWRNcxIWCgZyZXZpZXcYCSABKAlSBnJl'
    'dmlldw==');

@$core.Deprecated('Use gitHubThreadDescriptor instead')
const GitHubThread$json = {
  '1': 'GitHubThread',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'side', '3': 3, '4': 1, '5': 9, '10': 'side'},
    {'1': 'line', '3': 4, '4': 1, '5': 5, '10': 'line'},
    {'1': 'start_line', '3': 5, '4': 1, '5': 5, '10': 'startLine'},
    {'1': 'original_line', '3': 6, '4': 1, '5': 5, '10': 'originalLine'},
    {
      '1': 'original_start_line',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'originalStartLine'
    },
    {'1': 'on_file', '3': 8, '4': 1, '5': 8, '10': 'onFile'},
    {'1': 'outdated', '3': 9, '4': 1, '5': 8, '10': 'outdated'},
    {'1': 'resolved', '3': 10, '4': 1, '5': 8, '10': 'resolved'},
    {'1': 'can_reply', '3': 11, '4': 1, '5': 8, '10': 'canReply'},
    {'1': 'can_resolve', '3': 12, '4': 1, '5': 8, '10': 'canResolve'},
    {'1': 'can_unresolve', '3': 13, '4': 1, '5': 8, '10': 'canUnresolve'},
    {
      '1': 'comments',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubComment',
      '10': 'comments'
    },
  ],
};

/// Descriptor for `GitHubThread`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubThreadDescriptor = $convert.base64Decode(
    'CgxHaXRIdWJUaHJlYWQSDgoCaWQYASABKAlSAmlkEhIKBHBhdGgYAiABKAlSBHBhdGgSEgoEc2'
    'lkZRgDIAEoCVIEc2lkZRISCgRsaW5lGAQgASgFUgRsaW5lEh0KCnN0YXJ0X2xpbmUYBSABKAVS'
    'CXN0YXJ0TGluZRIjCg1vcmlnaW5hbF9saW5lGAYgASgFUgxvcmlnaW5hbExpbmUSLgoTb3JpZ2'
    'luYWxfc3RhcnRfbGluZRgHIAEoBVIRb3JpZ2luYWxTdGFydExpbmUSFwoHb25fZmlsZRgIIAEo'
    'CFIGb25GaWxlEhoKCG91dGRhdGVkGAkgASgIUghvdXRkYXRlZBIaCghyZXNvbHZlZBgKIAEoCF'
    'IIcmVzb2x2ZWQSGwoJY2FuX3JlcGx5GAsgASgIUghjYW5SZXBseRIfCgtjYW5fcmVzb2x2ZRgM'
    'IAEoCFIKY2FuUmVzb2x2ZRIjCg1jYW5fdW5yZXNvbHZlGA0gASgIUgxjYW5VbnJlc29sdmUSMw'
    'oIY29tbWVudHMYDiADKAsyFy5udXNoaS52MS5HaXRIdWJDb21tZW50Ughjb21tZW50cw==');

@$core.Deprecated('Use gitHubAnnotationDescriptor instead')
const GitHubAnnotation$json = {
  '1': 'GitHubAnnotation',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'level', '3': 2, '4': 1, '5': 9, '10': 'level'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'message', '3': 4, '4': 1, '5': 9, '10': 'message'},
    {'1': 'line', '3': 5, '4': 1, '5': 5, '10': 'line'},
    {'1': 'end_line', '3': 6, '4': 1, '5': 5, '10': 'endLine'},
  ],
};

/// Descriptor for `GitHubAnnotation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubAnnotationDescriptor = $convert.base64Decode(
    'ChBHaXRIdWJBbm5vdGF0aW9uEhIKBHBhdGgYASABKAlSBHBhdGgSFAoFbGV2ZWwYAiABKAlSBW'
    'xldmVsEhQKBXRpdGxlGAMgASgJUgV0aXRsZRIYCgdtZXNzYWdlGAQgASgJUgdtZXNzYWdlEhIK'
    'BGxpbmUYBSABKAVSBGxpbmUSGQoIZW5kX2xpbmUYBiABKAVSB2VuZExpbmU=');

@$core.Deprecated('Use gitHubCheckDescriptor instead')
const GitHubCheck$json = {
  '1': 'GitHubCheck',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'workflow', '3': 3, '4': 1, '5': 9, '10': 'workflow'},
    {'1': 'app', '3': 4, '4': 1, '5': 9, '10': 'app'},
    {'1': 'state', '3': 5, '4': 1, '5': 9, '10': 'state'},
    {'1': 'failed', '3': 6, '4': 1, '5': 8, '10': 'failed'},
    {'1': 'url', '3': 7, '4': 1, '5': 9, '10': 'url'},
    {'1': 'title', '3': 8, '4': 1, '5': 9, '10': 'title'},
    {'1': 'summary', '3': 9, '4': 1, '5': 9, '10': 'summary'},
    {'1': 'required', '3': 10, '4': 1, '5': 8, '10': 'required'},
    {
      '1': 'annotations',
      '3': 11,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubAnnotation',
      '10': 'annotations'
    },
    {'1': 'started_ms', '3': 12, '4': 1, '5': 3, '10': 'startedMs'},
    {'1': 'completed_ms', '3': 13, '4': 1, '5': 3, '10': 'completedMs'},
  ],
};

/// Descriptor for `GitHubCheck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubCheckDescriptor = $convert.base64Decode(
    'CgtHaXRIdWJDaGVjaxIOCgJpZBgBIAEoA1ICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIaCgh3b3'
    'JrZmxvdxgDIAEoCVIId29ya2Zsb3cSEAoDYXBwGAQgASgJUgNhcHASFAoFc3RhdGUYBSABKAlS'
    'BXN0YXRlEhYKBmZhaWxlZBgGIAEoCFIGZmFpbGVkEhAKA3VybBgHIAEoCVIDdXJsEhQKBXRpdG'
    'xlGAggASgJUgV0aXRsZRIYCgdzdW1tYXJ5GAkgASgJUgdzdW1tYXJ5EhoKCHJlcXVpcmVkGAog'
    'ASgIUghyZXF1aXJlZBI8Cgthbm5vdGF0aW9ucxgLIAMoCzIaLm51c2hpLnYxLkdpdEh1YkFubm'
    '90YXRpb25SC2Fubm90YXRpb25zEh0KCnN0YXJ0ZWRfbXMYDCABKANSCXN0YXJ0ZWRNcxIhCgxj'
    'b21wbGV0ZWRfbXMYDSABKANSC2NvbXBsZXRlZE1z');

@$core.Deprecated('Use gitHubReviewerDescriptor instead')
const GitHubReviewer$json = {
  '1': 'GitHubReviewer',
  '2': [
    {'1': 'login', '3': 1, '4': 1, '5': 9, '10': 'login'},
    {'1': 'state', '3': 2, '4': 1, '5': 9, '10': 'state'},
    {'1': 'team', '3': 3, '4': 1, '5': 8, '10': 'team'},
  ],
};

/// Descriptor for `GitHubReviewer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubReviewerDescriptor = $convert.base64Decode(
    'Cg5HaXRIdWJSZXZpZXdlchIUCgVsb2dpbhgBIAEoCVIFbG9naW4SFAoFc3RhdGUYAiABKAlSBX'
    'N0YXRlEhIKBHRlYW0YAyABKAhSBHRlYW0=');

@$core.Deprecated('Use gitHubPullDescriptor instead')
const GitHubPull$json = {
  '1': 'GitHubPull',
  '2': [
    {
      '1': 'item',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'item'
    },
    {'1': 'body', '3': 2, '4': 1, '5': 9, '10': 'body'},
    {'1': 'association', '3': 3, '4': 1, '5': 9, '10': 'association'},
    {'1': 'outside', '3': 4, '4': 1, '5': 8, '10': 'outside'},
    {'1': 'base', '3': 5, '4': 1, '5': 9, '10': 'base'},
    {'1': 'head', '3': 6, '4': 1, '5': 9, '10': 'head'},
    {'1': 'head_repo', '3': 7, '4': 1, '5': 9, '10': 'headRepo'},
    {'1': 'cross_repo', '3': 8, '4': 1, '5': 8, '10': 'crossRepo'},
    {'1': 'base_oid', '3': 9, '4': 1, '5': 9, '10': 'baseOid'},
    {'1': 'head_oid', '3': 10, '4': 1, '5': 9, '10': 'headOid'},
    {'1': 'mergeable', '3': 11, '4': 1, '5': 9, '10': 'mergeable'},
    {'1': 'merge_state', '3': 12, '4': 1, '5': 9, '10': 'mergeState'},
    {'1': 'additions', '3': 13, '4': 1, '5': 5, '10': 'additions'},
    {'1': 'deletions', '3': 14, '4': 1, '5': 5, '10': 'deletions'},
    {'1': 'changed_files', '3': 15, '4': 1, '5': 5, '10': 'changedFiles'},
    {
      '1': 'reviewers',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubReviewer',
      '10': 'reviewers'
    },
    {
      '1': 'conversation',
      '3': 17,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubComment',
      '10': 'conversation'
    },
    {
      '1': 'threads',
      '3': 18,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubThread',
      '10': 'threads'
    },
    {
      '1': 'checks',
      '3': 19,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubCheck',
      '10': 'checks'
    },
    {'1': 'pending_review', '3': 20, '4': 1, '5': 9, '10': 'pendingReview'},
    {'1': 'pending_comments', '3': 21, '4': 1, '5': 5, '10': 'pendingComments'},
  ],
};

/// Descriptor for `GitHubPull`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubPullDescriptor = $convert.base64Decode(
    'CgpHaXRIdWJQdWxsEigKBGl0ZW0YASABKAsyFC5udXNoaS52MS5HaXRIdWJJdGVtUgRpdGVtEh'
    'IKBGJvZHkYAiABKAlSBGJvZHkSIAoLYXNzb2NpYXRpb24YAyABKAlSC2Fzc29jaWF0aW9uEhgK'
    'B291dHNpZGUYBCABKAhSB291dHNpZGUSEgoEYmFzZRgFIAEoCVIEYmFzZRISCgRoZWFkGAYgAS'
    'gJUgRoZWFkEhsKCWhlYWRfcmVwbxgHIAEoCVIIaGVhZFJlcG8SHQoKY3Jvc3NfcmVwbxgIIAEo'
    'CFIJY3Jvc3NSZXBvEhkKCGJhc2Vfb2lkGAkgASgJUgdiYXNlT2lkEhkKCGhlYWRfb2lkGAogAS'
    'gJUgdoZWFkT2lkEhwKCW1lcmdlYWJsZRgLIAEoCVIJbWVyZ2VhYmxlEh8KC21lcmdlX3N0YXRl'
    'GAwgASgJUgptZXJnZVN0YXRlEhwKCWFkZGl0aW9ucxgNIAEoBVIJYWRkaXRpb25zEhwKCWRlbG'
    'V0aW9ucxgOIAEoBVIJZGVsZXRpb25zEiMKDWNoYW5nZWRfZmlsZXMYDyABKAVSDGNoYW5nZWRG'
    'aWxlcxI2CglyZXZpZXdlcnMYECADKAsyGC5udXNoaS52MS5HaXRIdWJSZXZpZXdlclIJcmV2aW'
    'V3ZXJzEjsKDGNvbnZlcnNhdGlvbhgRIAMoCzIXLm51c2hpLnYxLkdpdEh1YkNvbW1lbnRSDGNv'
    'bnZlcnNhdGlvbhIwCgd0aHJlYWRzGBIgAygLMhYubnVzaGkudjEuR2l0SHViVGhyZWFkUgd0aH'
    'JlYWRzEi0KBmNoZWNrcxgTIAMoCzIVLm51c2hpLnYxLkdpdEh1YkNoZWNrUgZjaGVja3MSJQoO'
    'cGVuZGluZ19yZXZpZXcYFCABKAlSDXBlbmRpbmdSZXZpZXcSKQoQcGVuZGluZ19jb21tZW50cx'
    'gVIAEoBVIPcGVuZGluZ0NvbW1lbnRz');

@$core.Deprecated('Use getGitHubPullRequestDescriptor instead')
const GetGitHubPullRequest$json = {
  '1': 'GetGitHubPullRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'quiet', '3': 2, '4': 1, '5': 8, '10': 'quiet'},
  ],
};

/// Descriptor for `GetGitHubPullRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubPullRequestDescriptor = $convert.base64Decode(
    'ChRHZXRHaXRIdWJQdWxsUmVxdWVzdBIlCgNyZWYYASABKAsyEy5udXNoaS52MS5HaXRIdWJSZW'
    'ZSA3JlZhIUCgVxdWlldBgCIAEoCFIFcXVpZXQ=');

@$core.Deprecated('Use getGitHubPullResponseDescriptor instead')
const GetGitHubPullResponse$json = {
  '1': 'GetGitHubPullResponse',
  '2': [
    {
      '1': 'pull',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubPull',
      '10': 'pull'
    },
  ],
};

/// Descriptor for `GetGitHubPullResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubPullResponseDescriptor = $convert.base64Decode(
    'ChVHZXRHaXRIdWJQdWxsUmVzcG9uc2USKAoEcHVsbBgBIAEoCzIULm51c2hpLnYxLkdpdEh1Yl'
    'B1bGxSBHB1bGw=');

@$core.Deprecated('Use gitHubIssueDescriptor instead')
const GitHubIssue$json = {
  '1': 'GitHubIssue',
  '2': [
    {
      '1': 'item',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'item'
    },
    {'1': 'body', '3': 2, '4': 1, '5': 9, '10': 'body'},
    {'1': 'association', '3': 3, '4': 1, '5': 9, '10': 'association'},
    {'1': 'outside', '3': 4, '4': 1, '5': 8, '10': 'outside'},
    {'1': 'labels', '3': 5, '4': 3, '5': 9, '10': 'labels'},
    {'1': 'assignees', '3': 6, '4': 3, '5': 9, '10': 'assignees'},
    {
      '1': 'conversation',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubComment',
      '10': 'conversation'
    },
  ],
};

/// Descriptor for `GitHubIssue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubIssueDescriptor = $convert.base64Decode(
    'CgtHaXRIdWJJc3N1ZRIoCgRpdGVtGAEgASgLMhQubnVzaGkudjEuR2l0SHViSXRlbVIEaXRlbR'
    'ISCgRib2R5GAIgASgJUgRib2R5EiAKC2Fzc29jaWF0aW9uGAMgASgJUgthc3NvY2lhdGlvbhIY'
    'CgdvdXRzaWRlGAQgASgIUgdvdXRzaWRlEhYKBmxhYmVscxgFIAMoCVIGbGFiZWxzEhwKCWFzc2'
    'lnbmVlcxgGIAMoCVIJYXNzaWduZWVzEjsKDGNvbnZlcnNhdGlvbhgHIAMoCzIXLm51c2hpLnYx'
    'LkdpdEh1YkNvbW1lbnRSDGNvbnZlcnNhdGlvbg==');

@$core.Deprecated('Use getGitHubIssueRequestDescriptor instead')
const GetGitHubIssueRequest$json = {
  '1': 'GetGitHubIssueRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'quiet', '3': 2, '4': 1, '5': 8, '10': 'quiet'},
  ],
};

/// Descriptor for `GetGitHubIssueRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubIssueRequestDescriptor = $convert.base64Decode(
    'ChVHZXRHaXRIdWJJc3N1ZVJlcXVlc3QSJQoDcmVmGAEgASgLMhMubnVzaGkudjEuR2l0SHViUm'
    'VmUgNyZWYSFAoFcXVpZXQYAiABKAhSBXF1aWV0');

@$core.Deprecated('Use getGitHubIssueResponseDescriptor instead')
const GetGitHubIssueResponse$json = {
  '1': 'GetGitHubIssueResponse',
  '2': [
    {
      '1': 'issue',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubIssue',
      '10': 'issue'
    },
  ],
};

/// Descriptor for `GetGitHubIssueResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubIssueResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRHaXRIdWJJc3N1ZVJlc3BvbnNlEisKBWlzc3VlGAEgASgLMhUubnVzaGkudjEuR2l0SH'
        'ViSXNzdWVSBWlzc3Vl');

@$core.Deprecated('Use getGitHubFilesRequestDescriptor instead')
const GetGitHubFilesRequest$json = {
  '1': 'GetGitHubFilesRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'base_oid', '3': 2, '4': 1, '5': 9, '10': 'baseOid'},
    {'1': 'head_oid', '3': 3, '4': 1, '5': 9, '10': 'headOid'},
  ],
};

/// Descriptor for `GetGitHubFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubFilesRequestDescriptor = $convert.base64Decode(
    'ChVHZXRHaXRIdWJGaWxlc1JlcXVlc3QSJQoDcmVmGAEgASgLMhMubnVzaGkudjEuR2l0SHViUm'
    'VmUgNyZWYSGQoIYmFzZV9vaWQYAiABKAlSB2Jhc2VPaWQSGQoIaGVhZF9vaWQYAyABKAlSB2hl'
    'YWRPaWQ=');

@$core.Deprecated('Use getGitHubFilesResponseDescriptor instead')
const GetGitHubFilesResponse$json = {
  '1': 'GetGitHubFilesResponse',
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

/// Descriptor for `GetGitHubFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubFilesResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRHaXRIdWJGaWxlc1Jlc3BvbnNlEioKBWZpbGVzGAEgAygLMhQubnVzaGkudjEuRmlsZU'
        'NoYW5nZVIFZmlsZXM=');

@$core.Deprecated('Use getGitHubJobLogRequestDescriptor instead')
const GetGitHubJobLogRequest$json = {
  '1': 'GetGitHubJobLogRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'job', '3': 2, '4': 1, '5': 3, '10': 'job'},
  ],
};

/// Descriptor for `GetGitHubJobLogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubJobLogRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRHaXRIdWJKb2JMb2dSZXF1ZXN0EiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLkdpdEh1Yl'
        'JlZlIDcmVmEhAKA2pvYhgCIAEoA1IDam9i');

@$core.Deprecated('Use getGitHubJobLogResponseDescriptor instead')
const GetGitHubJobLogResponse$json = {
  '1': 'GetGitHubJobLogResponse',
  '2': [
    {'1': 'tail', '3': 1, '4': 1, '5': 9, '10': 'tail'},
  ],
};

/// Descriptor for `GetGitHubJobLogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubJobLogResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRHaXRIdWJKb2JMb2dSZXNwb25zZRISCgR0YWlsGAEgASgJUgR0YWls');

@$core.Deprecated('Use replyGitHubThreadRequestDescriptor instead')
const ReplyGitHubThreadRequest$json = {
  '1': 'ReplyGitHubThreadRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'thread', '3': 2, '4': 1, '5': 9, '10': 'thread'},
    {'1': 'body', '3': 3, '4': 1, '5': 9, '10': 'body'},
  ],
};

/// Descriptor for `ReplyGitHubThreadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replyGitHubThreadRequestDescriptor =
    $convert.base64Decode(
        'ChhSZXBseUdpdEh1YlRocmVhZFJlcXVlc3QSEgoEaG9zdBgBIAEoCVIEaG9zdBIWCgZ0aHJlYW'
        'QYAiABKAlSBnRocmVhZBISCgRib2R5GAMgASgJUgRib2R5');

@$core.Deprecated('Use replyGitHubThreadResponseDescriptor instead')
const ReplyGitHubThreadResponse$json = {
  '1': 'ReplyGitHubThreadResponse',
  '2': [
    {
      '1': 'comment',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubComment',
      '10': 'comment'
    },
  ],
};

/// Descriptor for `ReplyGitHubThreadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List replyGitHubThreadResponseDescriptor =
    $convert.base64Decode(
        'ChlSZXBseUdpdEh1YlRocmVhZFJlc3BvbnNlEjEKB2NvbW1lbnQYASABKAsyFy5udXNoaS52MS'
        '5HaXRIdWJDb21tZW50Ugdjb21tZW50');

@$core.Deprecated('Use resolveGitHubThreadRequestDescriptor instead')
const ResolveGitHubThreadRequest$json = {
  '1': 'ResolveGitHubThreadRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'thread', '3': 2, '4': 1, '5': 9, '10': 'thread'},
    {'1': 'resolve', '3': 3, '4': 1, '5': 8, '10': 'resolve'},
  ],
};

/// Descriptor for `ResolveGitHubThreadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolveGitHubThreadRequestDescriptor =
    $convert.base64Decode(
        'ChpSZXNvbHZlR2l0SHViVGhyZWFkUmVxdWVzdBISCgRob3N0GAEgASgJUgRob3N0EhYKBnRocm'
        'VhZBgCIAEoCVIGdGhyZWFkEhgKB3Jlc29sdmUYAyABKAhSB3Jlc29sdmU=');

@$core.Deprecated('Use resolveGitHubThreadResponseDescriptor instead')
const ResolveGitHubThreadResponse$json = {
  '1': 'ResolveGitHubThreadResponse',
};

/// Descriptor for `ResolveGitHubThreadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolveGitHubThreadResponseDescriptor =
    $convert.base64Decode('ChtSZXNvbHZlR2l0SHViVGhyZWFkUmVzcG9uc2U=');

@$core.Deprecated('Use addGitHubCommentRequestDescriptor instead')
const AddGitHubCommentRequest$json = {
  '1': 'AddGitHubCommentRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'subject', '3': 2, '4': 1, '5': 9, '10': 'subject'},
    {'1': 'body', '3': 3, '4': 1, '5': 9, '10': 'body'},
  ],
};

/// Descriptor for `AddGitHubCommentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addGitHubCommentRequestDescriptor =
    $convert.base64Decode(
        'ChdBZGRHaXRIdWJDb21tZW50UmVxdWVzdBISCgRob3N0GAEgASgJUgRob3N0EhgKB3N1YmplY3'
        'QYAiABKAlSB3N1YmplY3QSEgoEYm9keRgDIAEoCVIEYm9keQ==');

@$core.Deprecated('Use addGitHubCommentResponseDescriptor instead')
const AddGitHubCommentResponse$json = {
  '1': 'AddGitHubCommentResponse',
  '2': [
    {
      '1': 'comment',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubComment',
      '10': 'comment'
    },
  ],
};

/// Descriptor for `AddGitHubCommentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addGitHubCommentResponseDescriptor =
    $convert.base64Decode(
        'ChhBZGRHaXRIdWJDb21tZW50UmVzcG9uc2USMQoHY29tbWVudBgBIAEoCzIXLm51c2hpLnYxLk'
        'dpdEh1YkNvbW1lbnRSB2NvbW1lbnQ=');

@$core.Deprecated('Use gitHubDraftDescriptor instead')
const GitHubDraft$json = {
  '1': 'GitHubDraft',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'side', '3': 2, '4': 1, '5': 9, '10': 'side'},
    {'1': 'line', '3': 3, '4': 1, '5': 5, '10': 'line'},
    {'1': 'start_line', '3': 4, '4': 1, '5': 5, '10': 'startLine'},
    {'1': 'body', '3': 5, '4': 1, '5': 9, '10': 'body'},
  ],
};

/// Descriptor for `GitHubDraft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubDraftDescriptor = $convert.base64Decode(
    'CgtHaXRIdWJEcmFmdBISCgRwYXRoGAEgASgJUgRwYXRoEhIKBHNpZGUYAiABKAlSBHNpZGUSEg'
    'oEbGluZRgDIAEoBVIEbGluZRIdCgpzdGFydF9saW5lGAQgASgFUglzdGFydExpbmUSEgoEYm9k'
    'eRgFIAEoCVIEYm9keQ==');

@$core.Deprecated('Use submitGitHubReviewRequestDescriptor instead')
const SubmitGitHubReviewRequest$json = {
  '1': 'SubmitGitHubReviewRequest',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'pull', '3': 2, '4': 1, '5': 9, '10': 'pull'},
    {'1': 'head_oid', '3': 3, '4': 1, '5': 9, '10': 'headOid'},
    {'1': 'pending_review', '3': 4, '4': 1, '5': 9, '10': 'pendingReview'},
    {'1': 'event', '3': 5, '4': 1, '5': 9, '10': 'event'},
    {'1': 'body', '3': 6, '4': 1, '5': 9, '10': 'body'},
    {
      '1': 'drafts',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubDraft',
      '10': 'drafts'
    },
  ],
};

/// Descriptor for `SubmitGitHubReviewRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitGitHubReviewRequestDescriptor = $convert.base64Decode(
    'ChlTdWJtaXRHaXRIdWJSZXZpZXdSZXF1ZXN0EhIKBGhvc3QYASABKAlSBGhvc3QSEgoEcHVsbB'
    'gCIAEoCVIEcHVsbBIZCghoZWFkX29pZBgDIAEoCVIHaGVhZE9pZBIlCg5wZW5kaW5nX3Jldmll'
    'dxgEIAEoCVINcGVuZGluZ1JldmlldxIUCgVldmVudBgFIAEoCVIFZXZlbnQSEgoEYm9keRgGIA'
    'EoCVIEYm9keRItCgZkcmFmdHMYByADKAsyFS5udXNoaS52MS5HaXRIdWJEcmFmdFIGZHJhZnRz');

@$core.Deprecated('Use submitGitHubReviewResponseDescriptor instead')
const SubmitGitHubReviewResponse$json = {
  '1': 'SubmitGitHubReviewResponse',
};

/// Descriptor for `SubmitGitHubReviewResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitGitHubReviewResponseDescriptor =
    $convert.base64Decode('ChpTdWJtaXRHaXRIdWJSZXZpZXdSZXNwb25zZQ==');

@$core.Deprecated('Use getGitHubPromptRequestDescriptor instead')
const GetGitHubPromptRequest$json = {
  '1': 'GetGitHubPromptRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'threads', '3': 3, '4': 3, '5': 9, '10': 'threads'},
  ],
};

/// Descriptor for `GetGitHubPromptRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubPromptRequestDescriptor = $convert.base64Decode(
    'ChZHZXRHaXRIdWJQcm9tcHRSZXF1ZXN0EiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLkdpdEh1Yl'
    'JlZlIDcmVmEhIKBGtpbmQYAiABKAlSBGtpbmQSGAoHdGhyZWFkcxgDIAMoCVIHdGhyZWFkcw==');

@$core.Deprecated('Use getGitHubPromptResponseDescriptor instead')
const GetGitHubPromptResponse$json = {
  '1': 'GetGitHubPromptResponse',
  '2': [
    {'1': 'text', '3': 1, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `GetGitHubPromptResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubPromptResponseDescriptor =
    $convert.base64Decode(
        'ChdHZXRHaXRIdWJQcm9tcHRSZXNwb25zZRISCgR0ZXh0GAEgASgJUgR0ZXh0');

const $core.Map<$core.String, $core.dynamic> NushiServiceBase$json = {
  '1': 'NushiService',
  '2': [
    {'1': 'Ping', '2': '.nushi.v1.PingRequest', '3': '.nushi.v1.PingResponse'},
    {
      '1': 'RestartWhenIdle',
      '2': '.nushi.v1.RestartWhenIdleRequest',
      '3': '.nushi.v1.RestartWhenIdleResponse'
    },
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
      '1': 'GetChatItems',
      '2': '.nushi.v1.GetChatItemsRequest',
      '3': '.nushi.v1.GetChatItemsResponse'
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
      '1': 'StopTask',
      '2': '.nushi.v1.StopTaskRequest',
      '3': '.nushi.v1.StopTaskResponse'
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
      '1': 'RenameBranch',
      '2': '.nushi.v1.RenameBranchRequest',
      '3': '.nushi.v1.RenameBranchResponse'
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
      '1': 'ReopenChat',
      '2': '.nushi.v1.ReopenChatRequest',
      '3': '.nushi.v1.ReopenChatResponse'
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
      '1': 'ListTranscripts',
      '2': '.nushi.v1.ListTranscriptsRequest',
      '3': '.nushi.v1.ListTranscriptsResponse'
    },
    {
      '1': 'ClearTranscripts',
      '2': '.nushi.v1.ClearTranscriptsRequest',
      '3': '.nushi.v1.ClearTranscriptsResponse'
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
      '1': 'DismissRemovedChats',
      '2': '.nushi.v1.DismissRemovedChatsRequest',
      '3': '.nushi.v1.DismissRemovedChatsResponse'
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
      '1': 'GetFile',
      '2': '.nushi.v1.GetFileRequest',
      '3': '.nushi.v1.GetFileResponse'
    },
    {
      '1': 'WatchChatFile',
      '2': '.nushi.v1.WatchChatFileRequest',
      '3': '.nushi.v1.WatchChatFileResponse',
      '6': true
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
      '1': 'ListSkills',
      '2': '.nushi.v1.ListSkillsRequest',
      '3': '.nushi.v1.ListSkillsResponse'
    },
    {
      '1': 'SetSkillOn',
      '2': '.nushi.v1.SetSkillOnRequest',
      '3': '.nushi.v1.SetSkillOnResponse'
    },
    {
      '1': 'SetPluginOn',
      '2': '.nushi.v1.SetPluginOnRequest',
      '3': '.nushi.v1.SetPluginOnResponse'
    },
    {
      '1': 'UninstallPlugin',
      '2': '.nushi.v1.UninstallPluginRequest',
      '3': '.nushi.v1.UninstallPluginResponse'
    },
    {
      '1': 'TrashSkill',
      '2': '.nushi.v1.TrashSkillRequest',
      '3': '.nushi.v1.TrashSkillResponse'
    },
    {
      '1': 'LinkSkill',
      '2': '.nushi.v1.LinkSkillRequest',
      '3': '.nushi.v1.LinkSkillResponse'
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
    {
      '1': 'GetPushKey',
      '2': '.nushi.v1.GetPushKeyRequest',
      '3': '.nushi.v1.GetPushKeyResponse'
    },
    {
      '1': 'SetPushSubscription',
      '2': '.nushi.v1.SetPushSubscriptionRequest',
      '3': '.nushi.v1.SetPushSubscriptionResponse'
    },
    {
      '1': 'SetDeviceView',
      '2': '.nushi.v1.SetDeviceViewRequest',
      '3': '.nushi.v1.SetDeviceViewResponse'
    },
    {
      '1': 'SendTestPush',
      '2': '.nushi.v1.SendTestPushRequest',
      '3': '.nushi.v1.SendTestPushResponse'
    },
    {
      '1': 'UnpairThisDevice',
      '2': '.nushi.v1.UnpairThisDeviceRequest',
      '3': '.nushi.v1.UnpairThisDeviceResponse'
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
      '1': 'FindJiraIssues',
      '2': '.nushi.v1.FindJiraIssuesRequest',
      '3': '.nushi.v1.FindJiraIssuesResponse'
    },
    {
      '1': 'GetJiraAttachment',
      '2': '.nushi.v1.GetJiraAttachmentRequest',
      '3': '.nushi.v1.GetJiraAttachmentResponse'
    },
    {
      '1': 'ListGitHubHosts',
      '2': '.nushi.v1.ListGitHubHostsRequest',
      '3': '.nushi.v1.ListGitHubHostsResponse'
    },
    {
      '1': 'AddGitHubToken',
      '2': '.nushi.v1.AddGitHubTokenRequest',
      '3': '.nushi.v1.AddGitHubTokenResponse'
    },
    {
      '1': 'RemoveGitHubToken',
      '2': '.nushi.v1.RemoveGitHubTokenRequest',
      '3': '.nushi.v1.RemoveGitHubTokenResponse'
    },
    {
      '1': 'AllowGitHubToken',
      '2': '.nushi.v1.AllowGitHubTokenRequest',
      '3': '.nushi.v1.AllowGitHubTokenResponse'
    },
    {
      '1': 'ListGitHubRepos',
      '2': '.nushi.v1.ListGitHubReposRequest',
      '3': '.nushi.v1.ListGitHubReposResponse'
    },
    {
      '1': 'ListGitHubInbox',
      '2': '.nushi.v1.ListGitHubInboxRequest',
      '3': '.nushi.v1.ListGitHubInboxResponse'
    },
    {
      '1': 'GetGitHubStates',
      '2': '.nushi.v1.GetGitHubStatesRequest',
      '3': '.nushi.v1.GetGitHubStatesResponse'
    },
    {
      '1': 'GetGitHubPull',
      '2': '.nushi.v1.GetGitHubPullRequest',
      '3': '.nushi.v1.GetGitHubPullResponse'
    },
    {
      '1': 'GetGitHubIssue',
      '2': '.nushi.v1.GetGitHubIssueRequest',
      '3': '.nushi.v1.GetGitHubIssueResponse'
    },
    {
      '1': 'GetGitHubFiles',
      '2': '.nushi.v1.GetGitHubFilesRequest',
      '3': '.nushi.v1.GetGitHubFilesResponse'
    },
    {
      '1': 'GetGitHubJobLog',
      '2': '.nushi.v1.GetGitHubJobLogRequest',
      '3': '.nushi.v1.GetGitHubJobLogResponse'
    },
    {
      '1': 'GetGitHubPrompt',
      '2': '.nushi.v1.GetGitHubPromptRequest',
      '3': '.nushi.v1.GetGitHubPromptResponse'
    },
    {
      '1': 'ReplyGitHubThread',
      '2': '.nushi.v1.ReplyGitHubThreadRequest',
      '3': '.nushi.v1.ReplyGitHubThreadResponse'
    },
    {
      '1': 'ResolveGitHubThread',
      '2': '.nushi.v1.ResolveGitHubThreadRequest',
      '3': '.nushi.v1.ResolveGitHubThreadResponse'
    },
    {
      '1': 'AddGitHubComment',
      '2': '.nushi.v1.AddGitHubCommentRequest',
      '3': '.nushi.v1.AddGitHubCommentResponse'
    },
    {
      '1': 'SubmitGitHubReview',
      '2': '.nushi.v1.SubmitGitHubReviewRequest',
      '3': '.nushi.v1.SubmitGitHubReviewResponse'
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
  '.nushi.v1.RestartWhenIdleRequest': RestartWhenIdleRequest$json,
  '.nushi.v1.RestartWhenIdleResponse': RestartWhenIdleResponse$json,
  '.nushi.v1.ListChatsRequest': ListChatsRequest$json,
  '.nushi.v1.ListChatsResponse': ListChatsResponse$json,
  '.nushi.v1.Chat': Chat$json,
  '.nushi.v1.ChatStatus': ChatStatus$json,
  '.nushi.v1.Worktree': Worktree$json,
  '.nushi.v1.GitHubLink': GitHubLink$json,
  '.nushi.v1.RemovedChat': RemovedChat$json,
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
  '.nushi.v1.Findings': Findings$json,
  '.nushi.v1.Finding': Finding$json,
  '.nushi.v1.ConfigOption': ConfigOption$json,
  '.nushi.v1.ConfigValue': ConfigValue$json,
  '.nushi.v1.Command': Command$json,
  '.nushi.v1.Usage': Usage$json,
  '.nushi.v1.ChatQueue': ChatQueue$json,
  '.nushi.v1.QueuedMessage': QueuedMessage$json,
  '.nushi.v1.GetChatItemsRequest': GetChatItemsRequest$json,
  '.nushi.v1.GetChatItemsResponse': GetChatItemsResponse$json,
  '.nushi.v1.StartChatRequest': StartChatRequest$json,
  '.nushi.v1.StartChatResponse': StartChatResponse$json,
  '.nushi.v1.ListAgentsRequest': ListAgentsRequest$json,
  '.nushi.v1.ListAgentsResponse': ListAgentsResponse$json,
  '.nushi.v1.Agent': Agent$json,
  '.nushi.v1.Adapter': Adapter$json,
  '.nushi.v1.ShellEnvironment': ShellEnvironment$json,
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
  '.nushi.v1.StopTaskRequest': StopTaskRequest$json,
  '.nushi.v1.StopTaskResponse': StopTaskResponse$json,
  '.nushi.v1.ForkChatRequest': ForkChatRequest$json,
  '.nushi.v1.ForkChatResponse': ForkChatResponse$json,
  '.nushi.v1.CloseSideChatRequest': CloseSideChatRequest$json,
  '.nushi.v1.CloseSideChatResponse': CloseSideChatResponse$json,
  '.nushi.v1.RenameChatRequest': RenameChatRequest$json,
  '.nushi.v1.RenameChatResponse': RenameChatResponse$json,
  '.nushi.v1.RenameBranchRequest': RenameBranchRequest$json,
  '.nushi.v1.RenameBranchResponse': RenameBranchResponse$json,
  '.nushi.v1.ArchiveChatRequest': ArchiveChatRequest$json,
  '.nushi.v1.ArchiveChatResponse': ArchiveChatResponse$json,
  '.nushi.v1.SleepChatRequest': SleepChatRequest$json,
  '.nushi.v1.SleepChatResponse': SleepChatResponse$json,
  '.nushi.v1.ReopenChatRequest': ReopenChatRequest$json,
  '.nushi.v1.ReopenChatResponse': ReopenChatResponse$json,
  '.nushi.v1.GetMemoryRequest': GetMemoryRequest$json,
  '.nushi.v1.GetMemoryResponse': GetMemoryResponse$json,
  '.nushi.v1.GetMemoryResponse.ChatsEntry': GetMemoryResponse_ChatsEntry$json,
  '.nushi.v1.GetSettingsRequest': GetSettingsRequest$json,
  '.nushi.v1.GetSettingsResponse': GetSettingsResponse$json,
  '.nushi.v1.Settings': Settings$json,
  '.nushi.v1.SetSettingsRequest': SetSettingsRequest$json,
  '.nushi.v1.SetSettingsResponse': SetSettingsResponse$json,
  '.nushi.v1.ListTranscriptsRequest': ListTranscriptsRequest$json,
  '.nushi.v1.ListTranscriptsResponse': ListTranscriptsResponse$json,
  '.nushi.v1.TranscriptCopy': TranscriptCopy$json,
  '.nushi.v1.ClearTranscriptsRequest': ClearTranscriptsRequest$json,
  '.nushi.v1.ClearTranscriptsResponse': ClearTranscriptsResponse$json,
  '.nushi.v1.PlanDeleteChatRequest': PlanDeleteChatRequest$json,
  '.nushi.v1.PlanDeleteChatResponse': PlanDeleteChatResponse$json,
  '.nushi.v1.AgentSession': AgentSession$json,
  '.nushi.v1.WorktreePlan': WorktreePlan$json,
  '.nushi.v1.WorktreeState': WorktreeState$json,
  '.nushi.v1.Terminal': Terminal$json,
  '.nushi.v1.DeleteChatRequest': DeleteChatRequest$json,
  '.nushi.v1.WorktreeChoice': WorktreeChoice$json,
  '.nushi.v1.DeleteChatResponse': DeleteChatResponse$json,
  '.nushi.v1.DismissRemovedChatsRequest': DismissRemovedChatsRequest$json,
  '.nushi.v1.DismissRemovedChatsResponse': DismissRemovedChatsResponse$json,
  '.nushi.v1.AnswerPermissionRequest': AnswerPermissionRequest$json,
  '.nushi.v1.AnswerPermissionResponse': AnswerPermissionResponse$json,
  '.nushi.v1.AnswerQuestionRequest': AnswerQuestionRequest$json,
  '.nushi.v1.FieldAnswer': FieldAnswer$json,
  '.nushi.v1.AnswerQuestionResponse': AnswerQuestionResponse$json,
  '.nushi.v1.SetConfigOptionRequest': SetConfigOptionRequest$json,
  '.nushi.v1.SetConfigOptionResponse': SetConfigOptionResponse$json,
  '.nushi.v1.GetDiffRequest': GetDiffRequest$json,
  '.nushi.v1.GetDiffResponse': GetDiffResponse$json,
  '.nushi.v1.GetFileRequest': GetFileRequest$json,
  '.nushi.v1.GetFileResponse': GetFileResponse$json,
  '.nushi.v1.WatchChatFileRequest': WatchChatFileRequest$json,
  '.nushi.v1.WatchChatFileResponse': WatchChatFileResponse$json,
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
  '.nushi.v1.ListSkillsRequest': ListSkillsRequest$json,
  '.nushi.v1.ListSkillsResponse': ListSkillsResponse$json,
  '.nushi.v1.Skill': Skill$json,
  '.nushi.v1.SkillAgent': SkillAgent$json,
  '.nushi.v1.Plugin': Plugin$json,
  '.nushi.v1.SetSkillOnRequest': SetSkillOnRequest$json,
  '.nushi.v1.SetSkillOnResponse': SetSkillOnResponse$json,
  '.nushi.v1.SetPluginOnRequest': SetPluginOnRequest$json,
  '.nushi.v1.SetPluginOnResponse': SetPluginOnResponse$json,
  '.nushi.v1.UninstallPluginRequest': UninstallPluginRequest$json,
  '.nushi.v1.UninstallPluginResponse': UninstallPluginResponse$json,
  '.nushi.v1.TrashSkillRequest': TrashSkillRequest$json,
  '.nushi.v1.TrashSkillResponse': TrashSkillResponse$json,
  '.nushi.v1.LinkSkillRequest': LinkSkillRequest$json,
  '.nushi.v1.LinkSkillResponse': LinkSkillResponse$json,
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
  '.nushi.v1.GetPushKeyRequest': GetPushKeyRequest$json,
  '.nushi.v1.GetPushKeyResponse': GetPushKeyResponse$json,
  '.nushi.v1.SetPushSubscriptionRequest': SetPushSubscriptionRequest$json,
  '.nushi.v1.SetPushSubscriptionResponse': SetPushSubscriptionResponse$json,
  '.nushi.v1.SetDeviceViewRequest': SetDeviceViewRequest$json,
  '.nushi.v1.SetDeviceViewResponse': SetDeviceViewResponse$json,
  '.nushi.v1.SendTestPushRequest': SendTestPushRequest$json,
  '.nushi.v1.SendTestPushResponse': SendTestPushResponse$json,
  '.nushi.v1.UnpairThisDeviceRequest': UnpairThisDeviceRequest$json,
  '.nushi.v1.UnpairThisDeviceResponse': UnpairThisDeviceResponse$json,
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
  '.nushi.v1.JiraWrite': JiraWrite$json,
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
  '.nushi.v1.FindJiraIssuesRequest': FindJiraIssuesRequest$json,
  '.nushi.v1.FindJiraIssuesResponse': FindJiraIssuesResponse$json,
  '.nushi.v1.FoundJiraIssue': FoundJiraIssue$json,
  '.nushi.v1.GetJiraAttachmentRequest': GetJiraAttachmentRequest$json,
  '.nushi.v1.GetJiraAttachmentResponse': GetJiraAttachmentResponse$json,
  '.nushi.v1.ListGitHubHostsRequest': ListGitHubHostsRequest$json,
  '.nushi.v1.ListGitHubHostsResponse': ListGitHubHostsResponse$json,
  '.nushi.v1.GitHubHost': GitHubHost$json,
  '.nushi.v1.GitHubBucket': GitHubBucket$json,
  '.nushi.v1.AddGitHubTokenRequest': AddGitHubTokenRequest$json,
  '.nushi.v1.AddGitHubTokenResponse': AddGitHubTokenResponse$json,
  '.nushi.v1.RemoveGitHubTokenRequest': RemoveGitHubTokenRequest$json,
  '.nushi.v1.RemoveGitHubTokenResponse': RemoveGitHubTokenResponse$json,
  '.nushi.v1.AllowGitHubTokenRequest': AllowGitHubTokenRequest$json,
  '.nushi.v1.AllowGitHubTokenResponse': AllowGitHubTokenResponse$json,
  '.nushi.v1.ListGitHubReposRequest': ListGitHubReposRequest$json,
  '.nushi.v1.ListGitHubReposResponse': ListGitHubReposResponse$json,
  '.nushi.v1.GitHubRepo': GitHubRepo$json,
  '.nushi.v1.ListGitHubInboxRequest': ListGitHubInboxRequest$json,
  '.nushi.v1.ListGitHubInboxResponse': ListGitHubInboxResponse$json,
  '.nushi.v1.GitHubItem': GitHubItem$json,
  '.nushi.v1.GitHubRef': GitHubRef$json,
  '.nushi.v1.GetGitHubStatesRequest': GetGitHubStatesRequest$json,
  '.nushi.v1.GetGitHubStatesResponse': GetGitHubStatesResponse$json,
  '.nushi.v1.GetGitHubPullRequest': GetGitHubPullRequest$json,
  '.nushi.v1.GetGitHubPullResponse': GetGitHubPullResponse$json,
  '.nushi.v1.GitHubPull': GitHubPull$json,
  '.nushi.v1.GitHubReviewer': GitHubReviewer$json,
  '.nushi.v1.GitHubComment': GitHubComment$json,
  '.nushi.v1.GitHubThread': GitHubThread$json,
  '.nushi.v1.GitHubCheck': GitHubCheck$json,
  '.nushi.v1.GitHubAnnotation': GitHubAnnotation$json,
  '.nushi.v1.GetGitHubIssueRequest': GetGitHubIssueRequest$json,
  '.nushi.v1.GetGitHubIssueResponse': GetGitHubIssueResponse$json,
  '.nushi.v1.GitHubIssue': GitHubIssue$json,
  '.nushi.v1.GetGitHubFilesRequest': GetGitHubFilesRequest$json,
  '.nushi.v1.GetGitHubFilesResponse': GetGitHubFilesResponse$json,
  '.nushi.v1.GetGitHubJobLogRequest': GetGitHubJobLogRequest$json,
  '.nushi.v1.GetGitHubJobLogResponse': GetGitHubJobLogResponse$json,
  '.nushi.v1.GetGitHubPromptRequest': GetGitHubPromptRequest$json,
  '.nushi.v1.GetGitHubPromptResponse': GetGitHubPromptResponse$json,
  '.nushi.v1.ReplyGitHubThreadRequest': ReplyGitHubThreadRequest$json,
  '.nushi.v1.ReplyGitHubThreadResponse': ReplyGitHubThreadResponse$json,
  '.nushi.v1.ResolveGitHubThreadRequest': ResolveGitHubThreadRequest$json,
  '.nushi.v1.ResolveGitHubThreadResponse': ResolveGitHubThreadResponse$json,
  '.nushi.v1.AddGitHubCommentRequest': AddGitHubCommentRequest$json,
  '.nushi.v1.AddGitHubCommentResponse': AddGitHubCommentResponse$json,
  '.nushi.v1.SubmitGitHubReviewRequest': SubmitGitHubReviewRequest$json,
  '.nushi.v1.GitHubDraft': GitHubDraft$json,
  '.nushi.v1.SubmitGitHubReviewResponse': SubmitGitHubReviewResponse$json,
  '.nushi.v1.EventsRequest': EventsRequest$json,
  '.nushi.v1.EventsResponse': EventsResponse$json,
  '.nushi.v1.ItemEvent': ItemEvent$json,
  '.nushi.v1.ChatConfig': ChatConfig$json,
  '.nushi.v1.ChatCommands': ChatCommands$json,
  '.nushi.v1.ChatTerminals': ChatTerminals$json,
  '.nushi.v1.RemovedChats': RemovedChats$json,
};

/// Descriptor for `NushiService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List nushiServiceDescriptor = $convert.base64Decode(
    'CgxOdXNoaVNlcnZpY2USNQoEUGluZxIVLm51c2hpLnYxLlBpbmdSZXF1ZXN0GhYubnVzaGkudj'
    'EuUGluZ1Jlc3BvbnNlElYKD1Jlc3RhcnRXaGVuSWRsZRIgLm51c2hpLnYxLlJlc3RhcnRXaGVu'
    'SWRsZVJlcXVlc3QaIS5udXNoaS52MS5SZXN0YXJ0V2hlbklkbGVSZXNwb25zZRJECglMaXN0Q2'
    'hhdHMSGi5udXNoaS52MS5MaXN0Q2hhdHNSZXF1ZXN0GhsubnVzaGkudjEuTGlzdENoYXRzUmVz'
    'cG9uc2USPgoHR2V0Q2hhdBIYLm51c2hpLnYxLkdldENoYXRSZXF1ZXN0GhkubnVzaGkudjEuR2'
    'V0Q2hhdFJlc3BvbnNlEk0KDEdldENoYXRJdGVtcxIdLm51c2hpLnYxLkdldENoYXRJdGVtc1Jl'
    'cXVlc3QaHi5udXNoaS52MS5HZXRDaGF0SXRlbXNSZXNwb25zZRJECglTdGFydENoYXQSGi5udX'
    'NoaS52MS5TdGFydENoYXRSZXF1ZXN0GhsubnVzaGkudjEuU3RhcnRDaGF0UmVzcG9uc2USRwoK'
    'TGlzdEFnZW50cxIbLm51c2hpLnYxLkxpc3RBZ2VudHNSZXF1ZXN0GhwubnVzaGkudjEuTGlzdE'
    'FnZW50c1Jlc3BvbnNlEkcKClNldFVwQWdlbnQSGy5udXNoaS52MS5TZXRVcEFnZW50UmVxdWVz'
    'dBocLm51c2hpLnYxLlNldFVwQWdlbnRSZXNwb25zZRJKCgtSZW1vdmVBZ2VudBIcLm51c2hpLn'
    'YxLlJlbW92ZUFnZW50UmVxdWVzdBodLm51c2hpLnYxLlJlbW92ZUFnZW50UmVzcG9uc2USXAoR'
    'TGlzdEFnZW50U2Vzc2lvbnMSIi5udXNoaS52MS5MaXN0QWdlbnRTZXNzaW9uc1JlcXVlc3QaIy'
    '5udXNoaS52MS5MaXN0QWdlbnRTZXNzaW9uc1Jlc3BvbnNlElkKEE9wZW5BZ2VudFNlc3Npb24S'
    'IS5udXNoaS52MS5PcGVuQWdlbnRTZXNzaW9uUmVxdWVzdBoiLm51c2hpLnYxLk9wZW5BZ2VudF'
    'Nlc3Npb25SZXNwb25zZRJBCghNb3ZlQ2hhdBIZLm51c2hpLnYxLk1vdmVDaGF0UmVxdWVzdBoa'
    'Lm51c2hpLnYxLk1vdmVDaGF0UmVzcG9uc2USRwoKU2VuZFByb21wdBIbLm51c2hpLnYxLlNlbm'
    'RQcm9tcHRSZXF1ZXN0GhwubnVzaGkudjEuU2VuZFByb21wdFJlc3BvbnNlEkcKClJld2luZENo'
    'YXQSGy5udXNoaS52MS5SZXdpbmRDaGF0UmVxdWVzdBocLm51c2hpLnYxLlJld2luZENoYXRSZX'
    'Nwb25zZRI+CgdVbnF1ZXVlEhgubnVzaGkudjEuVW5xdWV1ZVJlcXVlc3QaGS5udXNoaS52MS5V'
    'bnF1ZXVlUmVzcG9uc2USRwoKQ2FuY2VsVHVybhIbLm51c2hpLnYxLkNhbmNlbFR1cm5SZXF1ZX'
    'N0GhwubnVzaGkudjEuQ2FuY2VsVHVyblJlc3BvbnNlEkEKCFN0b3BUYXNrEhkubnVzaGkudjEu'
    'U3RvcFRhc2tSZXF1ZXN0GhoubnVzaGkudjEuU3RvcFRhc2tSZXNwb25zZRJBCghGb3JrQ2hhdB'
    'IZLm51c2hpLnYxLkZvcmtDaGF0UmVxdWVzdBoaLm51c2hpLnYxLkZvcmtDaGF0UmVzcG9uc2US'
    'UAoNQ2xvc2VTaWRlQ2hhdBIeLm51c2hpLnYxLkNsb3NlU2lkZUNoYXRSZXF1ZXN0Gh8ubnVzaG'
    'kudjEuQ2xvc2VTaWRlQ2hhdFJlc3BvbnNlEkcKClJlbmFtZUNoYXQSGy5udXNoaS52MS5SZW5h'
    'bWVDaGF0UmVxdWVzdBocLm51c2hpLnYxLlJlbmFtZUNoYXRSZXNwb25zZRJNCgxSZW5hbWVCcm'
    'FuY2gSHS5udXNoaS52MS5SZW5hbWVCcmFuY2hSZXF1ZXN0Gh4ubnVzaGkudjEuUmVuYW1lQnJh'
    'bmNoUmVzcG9uc2USSgoLQXJjaGl2ZUNoYXQSHC5udXNoaS52MS5BcmNoaXZlQ2hhdFJlcXVlc3'
    'QaHS5udXNoaS52MS5BcmNoaXZlQ2hhdFJlc3BvbnNlEkQKCVNsZWVwQ2hhdBIaLm51c2hpLnYx'
    'LlNsZWVwQ2hhdFJlcXVlc3QaGy5udXNoaS52MS5TbGVlcENoYXRSZXNwb25zZRJHCgpSZW9wZW'
    '5DaGF0EhsubnVzaGkudjEuUmVvcGVuQ2hhdFJlcXVlc3QaHC5udXNoaS52MS5SZW9wZW5DaGF0'
    'UmVzcG9uc2USRAoJR2V0TWVtb3J5EhoubnVzaGkudjEuR2V0TWVtb3J5UmVxdWVzdBobLm51c2'
    'hpLnYxLkdldE1lbW9yeVJlc3BvbnNlEkoKC0dldFNldHRpbmdzEhwubnVzaGkudjEuR2V0U2V0'
    'dGluZ3NSZXF1ZXN0Gh0ubnVzaGkudjEuR2V0U2V0dGluZ3NSZXNwb25zZRJKCgtTZXRTZXR0aW'
    '5ncxIcLm51c2hpLnYxLlNldFNldHRpbmdzUmVxdWVzdBodLm51c2hpLnYxLlNldFNldHRpbmdz'
    'UmVzcG9uc2USVgoPTGlzdFRyYW5zY3JpcHRzEiAubnVzaGkudjEuTGlzdFRyYW5zY3JpcHRzUm'
    'VxdWVzdBohLm51c2hpLnYxLkxpc3RUcmFuc2NyaXB0c1Jlc3BvbnNlElkKEENsZWFyVHJhbnNj'
    'cmlwdHMSIS5udXNoaS52MS5DbGVhclRyYW5zY3JpcHRzUmVxdWVzdBoiLm51c2hpLnYxLkNsZW'
    'FyVHJhbnNjcmlwdHNSZXNwb25zZRJTCg5QbGFuRGVsZXRlQ2hhdBIfLm51c2hpLnYxLlBsYW5E'
    'ZWxldGVDaGF0UmVxdWVzdBogLm51c2hpLnYxLlBsYW5EZWxldGVDaGF0UmVzcG9uc2USRwoKRG'
    'VsZXRlQ2hhdBIbLm51c2hpLnYxLkRlbGV0ZUNoYXRSZXF1ZXN0GhwubnVzaGkudjEuRGVsZXRl'
    'Q2hhdFJlc3BvbnNlEmIKE0Rpc21pc3NSZW1vdmVkQ2hhdHMSJC5udXNoaS52MS5EaXNtaXNzUm'
    'Vtb3ZlZENoYXRzUmVxdWVzdBolLm51c2hpLnYxLkRpc21pc3NSZW1vdmVkQ2hhdHNSZXNwb25z'
    'ZRJZChBBbnN3ZXJQZXJtaXNzaW9uEiEubnVzaGkudjEuQW5zd2VyUGVybWlzc2lvblJlcXVlc3'
    'QaIi5udXNoaS52MS5BbnN3ZXJQZXJtaXNzaW9uUmVzcG9uc2USUwoOQW5zd2VyUXVlc3Rpb24S'
    'Hy5udXNoaS52MS5BbnN3ZXJRdWVzdGlvblJlcXVlc3QaIC5udXNoaS52MS5BbnN3ZXJRdWVzdG'
    'lvblJlc3BvbnNlElYKD1NldENvbmZpZ09wdGlvbhIgLm51c2hpLnYxLlNldENvbmZpZ09wdGlv'
    'blJlcXVlc3QaIS5udXNoaS52MS5TZXRDb25maWdPcHRpb25SZXNwb25zZRI+CgdHZXREaWZmEh'
    'gubnVzaGkudjEuR2V0RGlmZlJlcXVlc3QaGS5udXNoaS52MS5HZXREaWZmUmVzcG9uc2USPgoH'
    'R2V0RmlsZRIYLm51c2hpLnYxLkdldEZpbGVSZXF1ZXN0GhkubnVzaGkudjEuR2V0RmlsZVJlc3'
    'BvbnNlElIKDVdhdGNoQ2hhdEZpbGUSHi5udXNoaS52MS5XYXRjaENoYXRGaWxlUmVxdWVzdBof'
    'Lm51c2hpLnYxLldhdGNoQ2hhdEZpbGVSZXNwb25zZTABEkoKC0xpc3RDb21taXRzEhwubnVzaG'
    'kudjEuTGlzdENvbW1pdHNSZXF1ZXN0Gh0ubnVzaGkudjEuTGlzdENvbW1pdHNSZXNwb25zZRJW'
    'Cg9HZXRGb2xkZXJTdGF0dXMSIC5udXNoaS52MS5HZXRGb2xkZXJTdGF0dXNSZXF1ZXN0GiEubn'
    'VzaGkudjEuR2V0Rm9sZGVyU3RhdHVzUmVzcG9uc2USRAoJTGlzdEZpbGVzEhoubnVzaGkudjEu'
    'TGlzdEZpbGVzUmVxdWVzdBobLm51c2hpLnYxLkxpc3RGaWxlc1Jlc3BvbnNlElYKD0dldENvbn'
    'RleHRVc2FnZRIgLm51c2hpLnYxLkdldENvbnRleHRVc2FnZVJlcXVlc3QaIS5udXNoaS52MS5H'
    'ZXRDb250ZXh0VXNhZ2VSZXNwb25zZRJTCg5MaXN0TWNwU2VydmVycxIfLm51c2hpLnYxLkxpc3'
    'RNY3BTZXJ2ZXJzUmVxdWVzdBogLm51c2hpLnYxLkxpc3RNY3BTZXJ2ZXJzUmVzcG9uc2USTQoM'
    'QWRkTWNwU2VydmVyEh0ubnVzaGkudjEuQWRkTWNwU2VydmVyUmVxdWVzdBoeLm51c2hpLnYxLk'
    'FkZE1jcFNlcnZlclJlc3BvbnNlElAKDUVkaXRNY3BTZXJ2ZXISHi5udXNoaS52MS5FZGl0TWNw'
    'U2VydmVyUmVxdWVzdBofLm51c2hpLnYxLkVkaXRNY3BTZXJ2ZXJSZXNwb25zZRJWCg9SZW1vdm'
    'VNY3BTZXJ2ZXISIC5udXNoaS52MS5SZW1vdmVNY3BTZXJ2ZXJSZXF1ZXN0GiEubnVzaGkudjEu'
    'UmVtb3ZlTWNwU2VydmVyUmVzcG9uc2USUwoOU2V0TWNwU2VydmVyT24SHy5udXNoaS52MS5TZX'
    'RNY3BTZXJ2ZXJPblJlcXVlc3QaIC5udXNoaS52MS5TZXRNY3BTZXJ2ZXJPblJlc3BvbnNlElMK'
    'DkxvZ2luTWNwU2VydmVyEh8ubnVzaGkudjEuTG9naW5NY3BTZXJ2ZXJSZXF1ZXN0GiAubnVzaG'
    'kudjEuTG9naW5NY3BTZXJ2ZXJSZXNwb25zZRJWCg9Mb2dvdXRNY3BTZXJ2ZXISIC5udXNoaS52'
    'MS5Mb2dvdXRNY3BTZXJ2ZXJSZXF1ZXN0GiEubnVzaGkudjEuTG9nb3V0TWNwU2VydmVyUmVzcG'
    '9uc2USRwoKTGlzdFNraWxscxIbLm51c2hpLnYxLkxpc3RTa2lsbHNSZXF1ZXN0GhwubnVzaGku'
    'djEuTGlzdFNraWxsc1Jlc3BvbnNlEkcKClNldFNraWxsT24SGy5udXNoaS52MS5TZXRTa2lsbE'
    '9uUmVxdWVzdBocLm51c2hpLnYxLlNldFNraWxsT25SZXNwb25zZRJKCgtTZXRQbHVnaW5PbhIc'
    'Lm51c2hpLnYxLlNldFBsdWdpbk9uUmVxdWVzdBodLm51c2hpLnYxLlNldFBsdWdpbk9uUmVzcG'
    '9uc2USVgoPVW5pbnN0YWxsUGx1Z2luEiAubnVzaGkudjEuVW5pbnN0YWxsUGx1Z2luUmVxdWVz'
    'dBohLm51c2hpLnYxLlVuaW5zdGFsbFBsdWdpblJlc3BvbnNlEkcKClRyYXNoU2tpbGwSGy5udX'
    'NoaS52MS5UcmFzaFNraWxsUmVxdWVzdBocLm51c2hpLnYxLlRyYXNoU2tpbGxSZXNwb25zZRJE'
    'CglMaW5rU2tpbGwSGi5udXNoaS52MS5MaW5rU2tpbGxSZXF1ZXN0GhsubnVzaGkudjEuTGlua1'
    'NraWxsUmVzcG9uc2USRwoKUmVsb2FkQ2hhdBIbLm51c2hpLnYxLlJlbG9hZENoYXRSZXF1ZXN0'
    'GhwubnVzaGkudjEuUmVsb2FkQ2hhdFJlc3BvbnNlEk0KDE9wZW5UZXJtaW5hbBIdLm51c2hpLn'
    'YxLk9wZW5UZXJtaW5hbFJlcXVlc3QaHi5udXNoaS52MS5PcGVuVGVybWluYWxSZXNwb25zZRJQ'
    'Cg1MaXN0VGVybWluYWxzEh4ubnVzaGkudjEuTGlzdFRlcm1pbmFsc1JlcXVlc3QaHy5udXNoaS'
    '52MS5MaXN0VGVybWluYWxzUmVzcG9uc2USVQoOQXR0YWNoVGVybWluYWwSHy5udXNoaS52MS5B'
    'dHRhY2hUZXJtaW5hbFJlcXVlc3QaIC5udXNoaS52MS5BdHRhY2hUZXJtaW5hbFJlc3BvbnNlMA'
    'ESUAoNV3JpdGVUZXJtaW5hbBIeLm51c2hpLnYxLldyaXRlVGVybWluYWxSZXF1ZXN0Gh8ubnVz'
    'aGkudjEuV3JpdGVUZXJtaW5hbFJlc3BvbnNlElMKDlJlc2l6ZVRlcm1pbmFsEh8ubnVzaGkudj'
    'EuUmVzaXplVGVybWluYWxSZXF1ZXN0GiAubnVzaGkudjEuUmVzaXplVGVybWluYWxSZXNwb25z'
    'ZRJTCg5SZW5hbWVUZXJtaW5hbBIfLm51c2hpLnYxLlJlbmFtZVRlcm1pbmFsUmVxdWVzdBogLm'
    '51c2hpLnYxLlJlbmFtZVRlcm1pbmFsUmVzcG9uc2USWQoQQXJyYW5nZVRlcm1pbmFscxIhLm51'
    'c2hpLnYxLkFycmFuZ2VUZXJtaW5hbHNSZXF1ZXN0GiIubnVzaGkudjEuQXJyYW5nZVRlcm1pbm'
    'Fsc1Jlc3BvbnNlElYKD1Jlc3RhcnRUZXJtaW5hbBIgLm51c2hpLnYxLlJlc3RhcnRUZXJtaW5h'
    'bFJlcXVlc3QaIS5udXNoaS52MS5SZXN0YXJ0VGVybWluYWxSZXNwb25zZRJQCg1DbG9zZVRlcm'
    '1pbmFsEh4ubnVzaGkudjEuQ2xvc2VUZXJtaW5hbFJlcXVlc3QaHy5udXNoaS52MS5DbG9zZVRl'
    'cm1pbmFsUmVzcG9uc2USSgoLQ2hlY2tGb2xkZXISHC5udXNoaS52MS5DaGVja0ZvbGRlclJlcX'
    'Vlc3QaHS5udXNoaS52MS5DaGVja0ZvbGRlclJlc3BvbnNlEkoKC1RydXN0Rm9sZGVyEhwubnVz'
    'aGkudjEuVHJ1c3RGb2xkZXJSZXF1ZXN0Gh0ubnVzaGkudjEuVHJ1c3RGb2xkZXJSZXNwb25zZR'
    'JECglHZXRSZW1vdGUSGi5udXNoaS52MS5HZXRSZW1vdGVSZXF1ZXN0GhsubnVzaGkudjEuR2V0'
    'UmVtb3RlUmVzcG9uc2USRAoJU2V0UmVtb3RlEhoubnVzaGkudjEuU2V0UmVtb3RlUmVxdWVzdB'
    'obLm51c2hpLnYxLlNldFJlbW90ZVJlc3BvbnNlEk0KDFN0YXJ0UGFpcmluZxIdLm51c2hpLnYx'
    'LlN0YXJ0UGFpcmluZ1JlcXVlc3QaHi5udXNoaS52MS5TdGFydFBhaXJpbmdSZXNwb25zZRJTCg'
    '5Db25maXJtUGFpcmluZxIfLm51c2hpLnYxLkNvbmZpcm1QYWlyaW5nUmVxdWVzdBogLm51c2hp'
    'LnYxLkNvbmZpcm1QYWlyaW5nUmVzcG9uc2USTQoMUmV2b2tlRGV2aWNlEh0ubnVzaGkudjEuUm'
    'V2b2tlRGV2aWNlUmVxdWVzdBoeLm51c2hpLnYxLlJldm9rZURldmljZVJlc3BvbnNlEkcKCkdl'
    'dFB1c2hLZXkSGy5udXNoaS52MS5HZXRQdXNoS2V5UmVxdWVzdBocLm51c2hpLnYxLkdldFB1c2'
    'hLZXlSZXNwb25zZRJiChNTZXRQdXNoU3Vic2NyaXB0aW9uEiQubnVzaGkudjEuU2V0UHVzaFN1'
    'YnNjcmlwdGlvblJlcXVlc3QaJS5udXNoaS52MS5TZXRQdXNoU3Vic2NyaXB0aW9uUmVzcG9uc2'
    'USUAoNU2V0RGV2aWNlVmlldxIeLm51c2hpLnYxLlNldERldmljZVZpZXdSZXF1ZXN0Gh8ubnVz'
    'aGkudjEuU2V0RGV2aWNlVmlld1Jlc3BvbnNlEk0KDFNlbmRUZXN0UHVzaBIdLm51c2hpLnYxLl'
    'NlbmRUZXN0UHVzaFJlcXVlc3QaHi5udXNoaS52MS5TZW5kVGVzdFB1c2hSZXNwb25zZRJZChBV'
    'bnBhaXJUaGlzRGV2aWNlEiEubnVzaGkudjEuVW5wYWlyVGhpc0RldmljZVJlcXVlc3QaIi5udX'
    'NoaS52MS5VbnBhaXJUaGlzRGV2aWNlUmVzcG9uc2USMgoDTG9nEhQubnVzaGkudjEuTG9nUmVx'
    'dWVzdBoVLm51c2hpLnYxLkxvZ1Jlc3BvbnNlElAKDUxpc3RKaXJhU2l0ZXMSHi5udXNoaS52MS'
    '5MaXN0SmlyYVNpdGVzUmVxdWVzdBofLm51c2hpLnYxLkxpc3RKaXJhU2l0ZXNSZXNwb25zZRJK'
    'CgtBZGRKaXJhU2l0ZRIcLm51c2hpLnYxLkFkZEppcmFTaXRlUmVxdWVzdBodLm51c2hpLnYxLk'
    'FkZEppcmFTaXRlUmVzcG9uc2USUwoOUmVtb3ZlSmlyYVNpdGUSHy5udXNoaS52MS5SZW1vdmVK'
    'aXJhU2l0ZVJlcXVlc3QaIC5udXNoaS52MS5SZW1vdmVKaXJhU2l0ZVJlc3BvbnNlElAKDUNoZW'
    'NrSmlyYVNpdGUSHi5udXNoaS52MS5DaGVja0ppcmFTaXRlUmVxdWVzdBofLm51c2hpLnYxLkNo'
    'ZWNrSmlyYVNpdGVSZXNwb25zZRJTCg5BbGxvd0ppcmFUb2tlbhIfLm51c2hpLnYxLkFsbG93Sm'
    'lyYVRva2VuUmVxdWVzdBogLm51c2hpLnYxLkFsbG93SmlyYVRva2VuUmVzcG9uc2USUwoOTGlz'
    'dEppcmFCb2FyZHMSHy5udXNoaS52MS5MaXN0SmlyYUJvYXJkc1JlcXVlc3QaIC5udXNoaS52MS'
    '5MaXN0SmlyYUJvYXJkc1Jlc3BvbnNlEk0KDFNldEppcmFCb2FyZBIdLm51c2hpLnYxLlNldEpp'
    'cmFCb2FyZFJlcXVlc3QaHi5udXNoaS52MS5TZXRKaXJhQm9hcmRSZXNwb25zZRJWCg9TZXRKaX'
    'JhU2VhcmNoZXMSIC5udXNoaS52MS5TZXRKaXJhU2VhcmNoZXNSZXF1ZXN0GiEubnVzaGkudjEu'
    'U2V0SmlyYVNlYXJjaGVzUmVzcG9uc2USUwoOTGlzdEppcmFJc3N1ZXMSHy5udXNoaS52MS5MaX'
    'N0SmlyYUlzc3Vlc1JlcXVlc3QaIC5udXNoaS52MS5MaXN0SmlyYUlzc3Vlc1Jlc3BvbnNlEkcK'
    'CkdldEppcmFKcWwSGy5udXNoaS52MS5HZXRKaXJhSnFsUmVxdWVzdBocLm51c2hpLnYxLkdldE'
    'ppcmFKcWxSZXNwb25zZRJTCg5TdWdnZXN0SmlyYUpxbBIfLm51c2hpLnYxLlN1Z2dlc3RKaXJh'
    'SnFsUmVxdWVzdBogLm51c2hpLnYxLlN1Z2dlc3RKaXJhSnFsUmVzcG9uc2USTQoMR2V0SmlyYU'
    'lzc3VlEh0ubnVzaGkudjEuR2V0SmlyYUlzc3VlUmVxdWVzdBoeLm51c2hpLnYxLkdldEppcmFJ'
    'c3N1ZVJlc3BvbnNlEmIKE0xpc3RKaXJhVHJhbnNpdGlvbnMSJC5udXNoaS52MS5MaXN0SmlyYV'
    'RyYW5zaXRpb25zUmVxdWVzdBolLm51c2hpLnYxLkxpc3RKaXJhVHJhbnNpdGlvbnNSZXNwb25z'
    'ZRJiChNUcmFuc2l0aW9uSmlyYUlzc3VlEiQubnVzaGkudjEuVHJhbnNpdGlvbkppcmFJc3N1ZV'
    'JlcXVlc3QaJS5udXNoaS52MS5UcmFuc2l0aW9uSmlyYUlzc3VlUmVzcG9uc2USUwoOQWRkSmly'
    'YUNvbW1lbnQSHy5udXNoaS52MS5BZGRKaXJhQ29tbWVudFJlcXVlc3QaIC5udXNoaS52MS5BZG'
    'RKaXJhQ29tbWVudFJlc3BvbnNlElMKDkZpbmRKaXJhSXNzdWVzEh8ubnVzaGkudjEuRmluZEpp'
    'cmFJc3N1ZXNSZXF1ZXN0GiAubnVzaGkudjEuRmluZEppcmFJc3N1ZXNSZXNwb25zZRJcChFHZX'
    'RKaXJhQXR0YWNobWVudBIiLm51c2hpLnYxLkdldEppcmFBdHRhY2htZW50UmVxdWVzdBojLm51'
    'c2hpLnYxLkdldEppcmFBdHRhY2htZW50UmVzcG9uc2USVgoPTGlzdEdpdEh1Ykhvc3RzEiAubn'
    'VzaGkudjEuTGlzdEdpdEh1Ykhvc3RzUmVxdWVzdBohLm51c2hpLnYxLkxpc3RHaXRIdWJIb3N0'
    'c1Jlc3BvbnNlElMKDkFkZEdpdEh1YlRva2VuEh8ubnVzaGkudjEuQWRkR2l0SHViVG9rZW5SZX'
    'F1ZXN0GiAubnVzaGkudjEuQWRkR2l0SHViVG9rZW5SZXNwb25zZRJcChFSZW1vdmVHaXRIdWJU'
    'b2tlbhIiLm51c2hpLnYxLlJlbW92ZUdpdEh1YlRva2VuUmVxdWVzdBojLm51c2hpLnYxLlJlbW'
    '92ZUdpdEh1YlRva2VuUmVzcG9uc2USWQoQQWxsb3dHaXRIdWJUb2tlbhIhLm51c2hpLnYxLkFs'
    'bG93R2l0SHViVG9rZW5SZXF1ZXN0GiIubnVzaGkudjEuQWxsb3dHaXRIdWJUb2tlblJlc3Bvbn'
    'NlElYKD0xpc3RHaXRIdWJSZXBvcxIgLm51c2hpLnYxLkxpc3RHaXRIdWJSZXBvc1JlcXVlc3Qa'
    'IS5udXNoaS52MS5MaXN0R2l0SHViUmVwb3NSZXNwb25zZRJWCg9MaXN0R2l0SHViSW5ib3gSIC'
    '5udXNoaS52MS5MaXN0R2l0SHViSW5ib3hSZXF1ZXN0GiEubnVzaGkudjEuTGlzdEdpdEh1Yklu'
    'Ym94UmVzcG9uc2USVgoPR2V0R2l0SHViU3RhdGVzEiAubnVzaGkudjEuR2V0R2l0SHViU3RhdG'
    'VzUmVxdWVzdBohLm51c2hpLnYxLkdldEdpdEh1YlN0YXRlc1Jlc3BvbnNlElAKDUdldEdpdEh1'
    'YlB1bGwSHi5udXNoaS52MS5HZXRHaXRIdWJQdWxsUmVxdWVzdBofLm51c2hpLnYxLkdldEdpdE'
    'h1YlB1bGxSZXNwb25zZRJTCg5HZXRHaXRIdWJJc3N1ZRIfLm51c2hpLnYxLkdldEdpdEh1Yklz'
    'c3VlUmVxdWVzdBogLm51c2hpLnYxLkdldEdpdEh1Yklzc3VlUmVzcG9uc2USUwoOR2V0R2l0SH'
    'ViRmlsZXMSHy5udXNoaS52MS5HZXRHaXRIdWJGaWxlc1JlcXVlc3QaIC5udXNoaS52MS5HZXRH'
    'aXRIdWJGaWxlc1Jlc3BvbnNlElYKD0dldEdpdEh1YkpvYkxvZxIgLm51c2hpLnYxLkdldEdpdE'
    'h1YkpvYkxvZ1JlcXVlc3QaIS5udXNoaS52MS5HZXRHaXRIdWJKb2JMb2dSZXNwb25zZRJWCg9H'
    'ZXRHaXRIdWJQcm9tcHQSIC5udXNoaS52MS5HZXRHaXRIdWJQcm9tcHRSZXF1ZXN0GiEubnVzaG'
    'kudjEuR2V0R2l0SHViUHJvbXB0UmVzcG9uc2USXAoRUmVwbHlHaXRIdWJUaHJlYWQSIi5udXNo'
    'aS52MS5SZXBseUdpdEh1YlRocmVhZFJlcXVlc3QaIy5udXNoaS52MS5SZXBseUdpdEh1YlRocm'
    'VhZFJlc3BvbnNlEmIKE1Jlc29sdmVHaXRIdWJUaHJlYWQSJC5udXNoaS52MS5SZXNvbHZlR2l0'
    'SHViVGhyZWFkUmVxdWVzdBolLm51c2hpLnYxLlJlc29sdmVHaXRIdWJUaHJlYWRSZXNwb25zZR'
    'JZChBBZGRHaXRIdWJDb21tZW50EiEubnVzaGkudjEuQWRkR2l0SHViQ29tbWVudFJlcXVlc3Qa'
    'Ii5udXNoaS52MS5BZGRHaXRIdWJDb21tZW50UmVzcG9uc2USXwoSU3VibWl0R2l0SHViUmV2aW'
    'V3EiMubnVzaGkudjEuU3VibWl0R2l0SHViUmV2aWV3UmVxdWVzdBokLm51c2hpLnYxLlN1Ym1p'
    'dEdpdEh1YlJldmlld1Jlc3BvbnNlEj0KBkV2ZW50cxIXLm51c2hpLnYxLkV2ZW50c1JlcXVlc3'
    'QaGC5udXNoaS52MS5FdmVudHNSZXNwb25zZTAB');
