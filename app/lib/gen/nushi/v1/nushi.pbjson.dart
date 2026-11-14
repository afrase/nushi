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

@$core.Deprecated('Use turnEndDescriptor instead')
const TurnEnd$json = {
  '1': 'TurnEnd',
  '2': [
    {'1': 'TURN_END_UNSPECIFIED', '2': 0},
    {'1': 'TURN_END_DONE', '2': 1},
    {'1': 'TURN_END_FAILED', '2': 2},
    {'1': 'TURN_END_STOPPED', '2': 3},
  ],
};

/// Descriptor for `TurnEnd`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List turnEndDescriptor = $convert.base64Decode(
    'CgdUdXJuRW5kEhgKFFRVUk5fRU5EX1VOU1BFQ0lGSUVEEAASEQoNVFVSTl9FTkRfRE9ORRABEh'
    'MKD1RVUk5fRU5EX0ZBSUxFRBACEhQKEFRVUk5fRU5EX1NUT1BQRUQQAw==');

@$core.Deprecated('Use devServerStateDescriptor instead')
const DevServerState$json = {
  '1': 'DevServerState',
  '2': [
    {'1': 'DEV_SERVER_STATE_UNSPECIFIED', '2': 0},
    {'1': 'DEV_SERVER_STATE_STOPPED', '2': 1},
    {'1': 'DEV_SERVER_STATE_STARTING', '2': 2},
    {'1': 'DEV_SERVER_STATE_RUNNING', '2': 3},
    {'1': 'DEV_SERVER_STATE_NOT_ANSWERING', '2': 4},
    {'1': 'DEV_SERVER_STATE_FAILED', '2': 5},
  ],
};

/// Descriptor for `DevServerState`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List devServerStateDescriptor = $convert.base64Decode(
    'Cg5EZXZTZXJ2ZXJTdGF0ZRIgChxERVZfU0VSVkVSX1NUQVRFX1VOU1BFQ0lGSUVEEAASHAoYRE'
    'VWX1NFUlZFUl9TVEFURV9TVE9QUEVEEAESHQoZREVWX1NFUlZFUl9TVEFURV9TVEFSVElORxAC'
    'EhwKGERFVl9TRVJWRVJfU1RBVEVfUlVOTklORxADEiIKHkRFVl9TRVJWRVJfU1RBVEVfTk9UX0'
    'FOU1dFUklORxAEEhsKF0RFVl9TRVJWRVJfU1RBVEVfRkFJTEVEEAU=');

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
    {
      '1': 'update',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.UpdateCheck',
      '10': 'update'
    },
    {'1': 'os', '3': 5, '4': 1, '5': 9, '10': 'os'},
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USHwoLYXBpX3ZlcnNpb24YASABKAVSCmFwaVZlcnNpb24SFAoFYnVpbG'
    'QYAiABKAlSBWJ1aWxkEhgKB3ZlcnNpb24YAyABKAlSB3ZlcnNpb24SLQoGdXBkYXRlGAQgASgL'
    'MhUubnVzaGkudjEuVXBkYXRlQ2hlY2tSBnVwZGF0ZRIOCgJvcxgFIAEoCVICb3M=');

@$core.Deprecated('Use updateCheckDescriptor instead')
const UpdateCheck$json = {
  '1': 'UpdateCheck',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 9, '10': 'version'},
    {'1': 'url', '3': 2, '4': 1, '5': 9, '10': 'url'},
    {'1': 'latest', '3': 4, '4': 1, '5': 9, '10': 'latest'},
    {'1': 'checked_ms', '3': 5, '4': 1, '5': 3, '10': 'checkedMs'},
    {'1': 'installing', '3': 6, '4': 1, '5': 8, '10': 'installing'},
    {'1': 'install_error', '3': 7, '4': 1, '5': 9, '10': 'installError'},
    {'1': 'installed', '3': 8, '4': 1, '5': 9, '10': 'installed'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['published_ms'],
};

/// Descriptor for `UpdateCheck`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateCheckDescriptor = $convert.base64Decode(
    'CgtVcGRhdGVDaGVjaxIYCgd2ZXJzaW9uGAEgASgJUgd2ZXJzaW9uEhAKA3VybBgCIAEoCVIDdX'
    'JsEhYKBmxhdGVzdBgEIAEoCVIGbGF0ZXN0Eh0KCmNoZWNrZWRfbXMYBSABKANSCWNoZWNrZWRN'
    'cxIeCgppbnN0YWxsaW5nGAYgASgIUgppbnN0YWxsaW5nEiMKDWluc3RhbGxfZXJyb3IYByABKA'
    'lSDGluc3RhbGxFcnJvchIcCglpbnN0YWxsZWQYCCABKAlSCWluc3RhbGxlZEoECAMQBFIMcHVi'
    'bGlzaGVkX21z');

@$core.Deprecated('Use checkForUpdatesRequestDescriptor instead')
const CheckForUpdatesRequest$json = {
  '1': 'CheckForUpdatesRequest',
};

/// Descriptor for `CheckForUpdatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkForUpdatesRequestDescriptor =
    $convert.base64Decode('ChZDaGVja0ZvclVwZGF0ZXNSZXF1ZXN0');

@$core.Deprecated('Use installUpdateRequestDescriptor instead')
const InstallUpdateRequest$json = {
  '1': 'InstallUpdateRequest',
};

/// Descriptor for `InstallUpdateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List installUpdateRequestDescriptor =
    $convert.base64Decode('ChRJbnN0YWxsVXBkYXRlUmVxdWVzdA==');

@$core.Deprecated('Use installUpdateResponseDescriptor instead')
const InstallUpdateResponse$json = {
  '1': 'InstallUpdateResponse',
};

/// Descriptor for `InstallUpdateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List installUpdateResponseDescriptor =
    $convert.base64Decode('ChVJbnN0YWxsVXBkYXRlUmVzcG9uc2U=');

@$core.Deprecated('Use checkForUpdatesResponseDescriptor instead')
const CheckForUpdatesResponse$json = {
  '1': 'CheckForUpdatesResponse',
  '2': [
    {
      '1': 'update',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.UpdateCheck',
      '10': 'update'
    },
  ],
};

/// Descriptor for `CheckForUpdatesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkForUpdatesResponseDescriptor =
    $convert.base64Decode(
        'ChdDaGVja0ZvclVwZGF0ZXNSZXNwb25zZRItCgZ1cGRhdGUYASABKAsyFS5udXNoaS52MS5VcG'
        'RhdGVDaGVja1IGdXBkYXRl');

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
  '2': [
    {
      '1': 'holds',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.RestartHold',
      '10': 'holds'
    },
  ],
};

/// Descriptor for `RestartWhenIdleResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartWhenIdleResponseDescriptor =
    $convert.base64Decode(
        'ChdSZXN0YXJ0V2hlbklkbGVSZXNwb25zZRIrCgVob2xkcxgBIAMoCzIVLm51c2hpLnYxLlJlc3'
        'RhcnRIb2xkUgVob2xkcw==');

@$core.Deprecated('Use restartHoldDescriptor instead')
const RestartHold$json = {
  '1': 'RestartHold',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'why', '3': 2, '4': 1, '5': 9, '10': 'why'},
    {'1': 'terminal', '3': 3, '4': 1, '5': 8, '10': 'terminal'},
  ],
};

/// Descriptor for `RestartHold`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restartHoldDescriptor = $convert.base64Decode(
    'CgtSZXN0YXJ0SG9sZBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEAoDd2h5GAIgASgJUgN3aH'
    'kSGgoIdGVybWluYWwYAyABKAhSCHRlcm1pbmFs');

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
  ],
  '9': [
    {'1': 5, '2': 6},
  ],
  '10': ['removed_unix_ms'],
};

/// Descriptor for `RemovedChat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removedChatDescriptor = $convert.base64Decode(
    'CgtSZW1vdmVkQ2hhdBIOCgJpZBgBIAEoCVICaWQSFAoFYWdlbnQYAiABKAlSBWFnZW50EhQKBX'
    'RpdGxlGAMgASgJUgV0aXRsZRIWCgZmb2xkZXIYBCABKAlSBmZvbGRlckoECAUQBlIPcmVtb3Zl'
    'ZF91bml4X21z');

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
    {'1': 'done', '3': 15, '4': 1, '5': 8, '10': 'done'},
    {
      '1': 'pull',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'pull'
    },
    {'1': 'pin', '3': 17, '4': 1, '5': 5, '10': 'pin'},
    {'1': 'color', '3': 18, '4': 1, '5': 9, '10': 'color'},
    {'1': 'pinned_messages', '3': 19, '4': 3, '5': 9, '10': 'pinnedMessages'},
    {'1': 'updated_unix_ms', '3': 20, '4': 1, '5': 3, '10': 'updatedUnixMs'},
    {
      '1': 'message_pins',
      '3': 21,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.MessagePin',
      '10': 'messagePins'
    },
    {
      '1': 'pulls',
      '3': 22,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'pulls'
    },
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
    'ZnaXRodWIYDiABKAsyFC5udXNoaS52MS5HaXRIdWJMaW5rUgZnaXRodWISEgoEZG9uZRgPIAEo'
    'CFIEZG9uZRIoCgRwdWxsGBAgASgLMhQubnVzaGkudjEuR2l0SHViTGlua1IEcHVsbBIQCgNwaW'
    '4YESABKAVSA3BpbhIUCgVjb2xvchgSIAEoCVIFY29sb3ISJwoPcGlubmVkX21lc3NhZ2VzGBMg'
    'AygJUg5waW5uZWRNZXNzYWdlcxImCg91cGRhdGVkX3VuaXhfbXMYFCABKANSDXVwZGF0ZWRVbm'
    'l4TXMSNwoMbWVzc2FnZV9waW5zGBUgAygLMhQubnVzaGkudjEuTWVzc2FnZVBpblILbWVzc2Fn'
    'ZVBpbnMSKgoFcHVsbHMYFiADKAsyFC5udXNoaS52MS5HaXRIdWJMaW5rUgVwdWxscw==');

@$core.Deprecated('Use messagePinDescriptor instead')
const MessagePin$json = {
  '1': 'MessagePin',
  '2': [
    {'1': 'item_id', '3': 1, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
  ],
};

/// Descriptor for `MessagePin`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List messagePinDescriptor = $convert.base64Decode(
    'CgpNZXNzYWdlUGluEhcKB2l0ZW1faWQYASABKAlSBml0ZW1JZBIUCgV0aXRsZRgCIAEoCVIFdG'
    'l0bGU=');

@$core.Deprecated('Use worktreeDescriptor instead')
const Worktree$json = {
  '1': 'Worktree',
  '2': [
    {'1': 'repo', '3': 1, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'base', '3': 4, '4': 1, '5': 9, '10': 'base'},
    {'1': 'base_commit', '3': 5, '4': 1, '5': 9, '10': 'baseCommit'},
    {'1': 'found', '3': 6, '4': 1, '5': 8, '10': 'found'},
  ],
};

/// Descriptor for `Worktree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreeDescriptor = $convert.base64Decode(
    'CghXb3JrdHJlZRISCgRyZXBvGAEgASgJUgRyZXBvEhIKBHBhdGgYAiABKAlSBHBhdGgSFgoGYn'
    'JhbmNoGAMgASgJUgZicmFuY2gSEgoEYmFzZRgEIAEoCVIEYmFzZRIfCgtiYXNlX2NvbW1pdBgF'
    'IAEoCVIKYmFzZUNvbW1pdBIUCgVmb3VuZBgGIAEoCFIFZm91bmQ=');

@$core.Deprecated('Use getChatRequestDescriptor instead')
const GetChatRequest$json = {
  '1': 'GetChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'recent', '3': 2, '4': 1, '5': 5, '10': 'recent'},
    {'1': 'image_refs', '3': 3, '4': 1, '5': 8, '10': 'imageRefs'},
  ],
};

/// Descriptor for `GetChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatRequestDescriptor = $convert.base64Decode(
    'Cg5HZXRDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFgoGcmVjZW50GAIgAS'
    'gFUgZyZWNlbnQSHQoKaW1hZ2VfcmVmcxgDIAEoCFIJaW1hZ2VSZWZz');

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
    {
      '1': 'running',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.Item',
      '10': 'running'
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
    'VzYWdlUgV1c2FnZRIpCgVxdWV1ZRgIIAEoCzITLm51c2hpLnYxLkNoYXRRdWV1ZVIFcXVldWUS'
    'FAoFb2xkZXIYCSABKAVSBW9sZGVyEigKB3J1bm5pbmcYCiADKAsyDi5udXNoaS52MS5JdGVtUg'
    'dydW5uaW5n');

@$core.Deprecated('Use getChatItemsRequestDescriptor instead')
const GetChatItemsRequest$json = {
  '1': 'GetChatItemsRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'before', '3': 2, '4': 1, '5': 9, '10': 'before'},
    {'1': 'limit', '3': 3, '4': 1, '5': 5, '10': 'limit'},
    {'1': 'image_refs', '3': 4, '4': 1, '5': 8, '10': 'imageRefs'},
  ],
};

/// Descriptor for `GetChatItemsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatItemsRequestDescriptor = $convert.base64Decode(
    'ChNHZXRDaGF0SXRlbXNSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIWCgZiZWZvcm'
    'UYAiABKAlSBmJlZm9yZRIUCgVsaW1pdBgDIAEoBVIFbGltaXQSHQoKaW1hZ2VfcmVmcxgEIAEo'
    'CFIJaW1hZ2VSZWZz');

@$core.Deprecated('Use getChatImageRequestDescriptor instead')
const GetChatImageRequest$json = {
  '1': 'GetChatImageRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'sha256', '3': 2, '4': 1, '5': 9, '10': 'sha256'},
  ],
};

/// Descriptor for `GetChatImageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatImageRequestDescriptor = $convert.base64Decode(
    'ChNHZXRDaGF0SW1hZ2VSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIWCgZzaGEyNT'
    'YYAiABKAlSBnNoYTI1Ng==');

@$core.Deprecated('Use getChatImageResponseDescriptor instead')
const GetChatImageResponse$json = {
  '1': 'GetChatImageResponse',
  '2': [
    {'1': 'mime_type', '3': 1, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `GetChatImageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getChatImageResponseDescriptor = $convert.base64Decode(
    'ChRHZXRDaGF0SW1hZ2VSZXNwb25zZRIbCgltaW1lX3R5cGUYASABKAlSCG1pbWVUeXBlEhIKBG'
    'RhdGEYAiABKAxSBGRhdGE=');

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
    {'1': 'mcp_user_only', '3': 15, '4': 1, '5': 8, '10': 'mcpUserOnly'},
  ],
  '9': [
    {'1': 14, '2': 15},
  ],
  '10': ['go_agent'],
};

/// Descriptor for `Agent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List agentDescriptor = $convert.base64Decode(
    'CgVBZ2VudBISCgRuYW1lGAEgASgJUgRuYW1lEhQKBXRpdGxlGAIgASgJUgV0aXRsZRIWCgZyZX'
    'N1bWUYAyABKAlSBnJlc3VtZRIQCgNtY3AYBCABKAhSA21jcBInCg9kZWxldGVfYXJjaGl2ZXMY'
    'BSABKAhSDmRlbGV0ZUFyY2hpdmVzEhIKBHBhdGgYBiABKAlSBHBhdGgSGAoHdmVyc2lvbhgHIA'
    'EoCVIHdmVyc2lvbhISCgRwYWdlGAggASgJUgRwYWdlEhgKB3Byb2JsZW0YCSABKAlSB3Byb2Js'
    'ZW0SGwoJc2lnbmVkX2luGAogASgJUghzaWduZWRJbhIrCgdhZGFwdGVyGAsgASgLMhEubnVzaG'
    'kudjEuQWRhcHRlclIHYWRhcHRlchIUCgVyZWFkeRgMIAEoCFIFcmVhZHkSFAoFYXdha2UYDSAB'
    'KAVSBWF3YWtlEiIKDW1jcF91c2VyX29ubHkYDyABKAhSC21jcFVzZXJPbmx5SgQIDhAPUghnb1'
    '9hZ2VudA==');

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
    {'1': 'head_runs_key', '3': 8, '4': 1, '5': 9, '10': 'headRunsKey'},
  ],
};

/// Descriptor for `StartChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatRequestDescriptor = $convert.base64Decode(
    'ChBTdGFydENoYXRSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBWFnZW50GAMgAS'
    'gJUgVhZ2VudBIaCgh3b3JrdHJlZRgCIAEoCFIId29ya3RyZWUSGwoJamlyYV9zaXRlGAQgASgJ'
    'UghqaXJhU2l0ZRIZCghqaXJhX2tleRgFIAEoCVIHamlyYUtleRIWCgZicmFuY2gYBiABKAlSBm'
    'JyYW5jaBIsCgZnaXRodWIYByABKAsyFC5udXNoaS52MS5HaXRIdWJMaW5rUgZnaXRodWISIgoN'
    'aGVhZF9ydW5zX2tleRgIIAEoCVILaGVhZFJ1bnNLZXk=');

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

@$core.Deprecated('Use searchAgentSessionsRequestDescriptor instead')
const SearchAgentSessionsRequest$json = {
  '1': 'SearchAgentSessionsRequest',
  '2': [
    {'1': 'agent', '3': 1, '4': 1, '5': 9, '10': 'agent'},
    {'1': 'folder', '3': 2, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `SearchAgentSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchAgentSessionsRequestDescriptor =
    $convert.base64Decode(
        'ChpTZWFyY2hBZ2VudFNlc3Npb25zUmVxdWVzdBIUCgVhZ2VudBgBIAEoCVIFYWdlbnQSFgoGZm'
        '9sZGVyGAIgASgJUgZmb2xkZXISEgoEdGV4dBgDIAEoCVIEdGV4dA==');

@$core.Deprecated('Use searchAgentSessionsResponseDescriptor instead')
const SearchAgentSessionsResponse$json = {
  '1': 'SearchAgentSessionsResponse',
  '2': [
    {'1': 'can_search', '3': 1, '4': 1, '5': 8, '10': 'canSearch'},
    {
      '1': 'hits',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.SessionHit',
      '10': 'hits'
    },
    {'1': 'more', '3': 3, '4': 1, '5': 8, '10': 'more'},
    {'1': 'sees_open', '3': 4, '4': 1, '5': 8, '10': 'seesOpen'},
    {'1': 'one_writer', '3': 5, '4': 1, '5': 8, '10': 'oneWriter'},
  ],
};

/// Descriptor for `SearchAgentSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchAgentSessionsResponseDescriptor = $convert.base64Decode(
    'ChtTZWFyY2hBZ2VudFNlc3Npb25zUmVzcG9uc2USHQoKY2FuX3NlYXJjaBgBIAEoCFIJY2FuU2'
    'VhcmNoEigKBGhpdHMYAiADKAsyFC5udXNoaS52MS5TZXNzaW9uSGl0UgRoaXRzEhIKBG1vcmUY'
    'AyABKAhSBG1vcmUSGwoJc2Vlc19vcGVuGAQgASgIUghzZWVzT3BlbhIdCgpvbmVfd3JpdGVyGA'
    'UgASgIUglvbmVXcml0ZXI=');

@$core.Deprecated('Use sessionHitDescriptor instead')
const SessionHit$json = {
  '1': 'SessionHit',
  '2': [
    {
      '1': 'session',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.FoundSession',
      '10': 'session'
    },
    {'1': 'before', '3': 2, '4': 1, '5': 9, '10': 'before'},
    {'1': 'match', '3': 3, '4': 1, '5': 9, '10': 'match'},
    {'1': 'after', '3': 4, '4': 1, '5': 9, '10': 'after'},
    {'1': 'count', '3': 5, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `SessionHit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionHitDescriptor = $convert.base64Decode(
    'CgpTZXNzaW9uSGl0EjAKB3Nlc3Npb24YASABKAsyFi5udXNoaS52MS5Gb3VuZFNlc3Npb25SB3'
    'Nlc3Npb24SFgoGYmVmb3JlGAIgASgJUgZiZWZvcmUSFAoFbWF0Y2gYAyABKAlSBW1hdGNoEhQK'
    'BWFmdGVyGAQgASgJUgVhZnRlchIUCgVjb3VudBgFIAEoBVIFY291bnQ=');

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
    {
      '1': 'head_runs',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FolderRun',
      '10': 'headRuns'
    },
    {'1': 'head_folder', '3': 4, '4': 1, '5': 9, '10': 'headFolder'},
    {'1': 'head_runs_key', '3': 5, '4': 1, '5': 9, '10': 'headRunsKey'},
  ],
};

/// Descriptor for `StartChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatResponseDescriptor = $convert.base64Decode(
    'ChFTdGFydENoYXRSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSLgoGY29uZmlnGA'
    'IgAygLMhYubnVzaGkudjEuQ29uZmlnT3B0aW9uUgZjb25maWcSMAoJaGVhZF9ydW5zGAMgAygL'
    'MhMubnVzaGkudjEuRm9sZGVyUnVuUghoZWFkUnVucxIfCgtoZWFkX2ZvbGRlchgEIAEoCVIKaG'
    'VhZEZvbGRlchIiCg1oZWFkX3J1bnNfa2V5GAUgASgJUgtoZWFkUnVuc0tleQ==');

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
    {
      '1': 'uploads',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FileUpload',
      '10': 'uploads'
    },
  ],
};

/// Descriptor for `SendPromptRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendPromptRequestDescriptor = $convert.base64Decode(
    'ChFTZW5kUHJvbXB0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEgoEdGV4dBgCIA'
    'EoCVIEdGV4dBIUCgVmaWxlcxgDIAMoCVIFZmlsZXMSKwoGaW1hZ2VzGAQgAygLMhMubnVzaGku'
    'djEuSW1hZ2VEYXRhUgZpbWFnZXMSFAoFcXVldWUYBSABKAhSBXF1ZXVlEhAKA25vdxgGIAEoCF'
    'IDbm93Eh8KC3RvX3N1YmFnZW50GAcgASgJUgp0b1N1YmFnZW50Ei4KB3VwbG9hZHMYCCADKAsy'
    'FC5udXNoaS52MS5GaWxlVXBsb2FkUgd1cGxvYWRz');

@$core.Deprecated('Use fileUploadDescriptor instead')
const FileUpload$json = {
  '1': 'FileUpload',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `FileUpload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileUploadDescriptor = $convert.base64Decode(
    'CgpGaWxlVXBsb2FkEhIKBG5hbWUYASABKAlSBG5hbWUSEgoEZGF0YRgCIAEoDFIEZGF0YQ==');

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
    {'1': 'to_subagent_name', '3': 5, '4': 1, '5': 9, '10': 'toSubagentName'},
    {'1': 'to_subagent', '3': 6, '4': 1, '5': 9, '10': 'toSubagent'},
    {'1': 'to_subagent_stop', '3': 7, '4': 1, '5': 8, '10': 'toSubagentStop'},
  ],
};

/// Descriptor for `QueuedMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List queuedMessageDescriptor = $convert.base64Decode(
    'Cg1RdWV1ZWRNZXNzYWdlEg4KAmlkGAEgASgJUgJpZBISCgR0ZXh0GAIgASgJUgR0ZXh0EhQKBW'
    'ZpbGVzGAMgAygJUgVmaWxlcxIrCgZpbWFnZXMYBCADKAsyEy5udXNoaS52MS5JbWFnZURhdGFS'
    'BmltYWdlcxIoChB0b19zdWJhZ2VudF9uYW1lGAUgASgJUg50b1N1YmFnZW50TmFtZRIfCgt0b1'
    '9zdWJhZ2VudBgGIAEoCVIKdG9TdWJhZ2VudBIoChB0b19zdWJhZ2VudF9zdG9wGAcgASgIUg50'
    'b1N1YmFnZW50U3RvcA==');

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
    {'1': 'sha256', '3': 3, '4': 1, '5': 9, '10': 'sha256'},
    {'1': 'size', '3': 4, '4': 1, '5': 3, '10': 'size'},
    {'1': 'width', '3': 5, '4': 1, '5': 5, '10': 'width'},
    {'1': 'height', '3': 6, '4': 1, '5': 5, '10': 'height'},
  ],
};

/// Descriptor for `ImageData`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List imageDataDescriptor = $convert.base64Decode(
    'CglJbWFnZURhdGESGwoJbWltZV90eXBlGAEgASgJUghtaW1lVHlwZRISCgRkYXRhGAIgASgMUg'
    'RkYXRhEhYKBnNoYTI1NhgDIAEoCVIGc2hhMjU2EhIKBHNpemUYBCABKANSBHNpemUSFAoFd2lk'
    'dGgYBSABKAVSBXdpZHRoEhYKBmhlaWdodBgGIAEoBVIGaGVpZ2h0');

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
  '2': [
    {'1': 'ran_command', '3': 1, '4': 1, '5': 8, '10': 'ranCommand'},
  ],
};

/// Descriptor for `SendPromptResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendPromptResponseDescriptor = $convert.base64Decode(
    'ChJTZW5kUHJvbXB0UmVzcG9uc2USHwoLcmFuX2NvbW1hbmQYASABKAhSCnJhbkNvbW1hbmQ=');

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

@$core.Deprecated('Use forkAsChatRequestDescriptor instead')
const ForkAsChatRequest$json = {
  '1': 'ForkAsChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
  ],
};

/// Descriptor for `ForkAsChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forkAsChatRequestDescriptor = $convert.base64Decode(
    'ChFGb3JrQXNDaGF0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFwoHaXRlbV9pZB'
    'gCIAEoCVIGaXRlbUlk');

@$core.Deprecated('Use forkAsChatResponseDescriptor instead')
const ForkAsChatResponse$json = {
  '1': 'ForkAsChatResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ForkAsChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List forkAsChatResponseDescriptor =
    $convert.base64Decode(
        'ChJGb3JrQXNDaGF0UmVzcG9uc2USFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElk');

@$core.Deprecated('Use keepSideChatRequestDescriptor instead')
const KeepSideChatRequest$json = {
  '1': 'KeepSideChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `KeepSideChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keepSideChatRequestDescriptor =
    $convert.base64Decode(
        'ChNLZWVwU2lkZUNoYXRSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use keepSideChatResponseDescriptor instead')
const KeepSideChatResponse$json = {
  '1': 'KeepSideChatResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `KeepSideChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List keepSideChatResponseDescriptor =
    $convert.base64Decode(
        'ChRLZWVwU2lkZUNoYXRSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

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

@$core.Deprecated('Use archiveSideChatRequestDescriptor instead')
const ArchiveSideChatRequest$json = {
  '1': 'ArchiveSideChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ArchiveSideChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveSideChatRequestDescriptor =
    $convert.base64Decode(
        'ChZBcmNoaXZlU2lkZUNoYXRSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use archiveSideChatResponseDescriptor instead')
const ArchiveSideChatResponse$json = {
  '1': 'ArchiveSideChatResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ArchiveSideChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List archiveSideChatResponseDescriptor =
    $convert.base64Decode(
        'ChdBcmNoaXZlU2lkZUNoYXRSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use restoreSideChatRequestDescriptor instead')
const RestoreSideChatRequest$json = {
  '1': 'RestoreSideChatRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `RestoreSideChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreSideChatRequestDescriptor =
    $convert.base64Decode(
        'ChZSZXN0b3JlU2lkZUNoYXRSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use restoreSideChatResponseDescriptor instead')
const RestoreSideChatResponse$json = {
  '1': 'RestoreSideChatResponse',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `RestoreSideChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreSideChatResponseDescriptor =
    $convert.base64Decode(
        'ChdSZXN0b3JlU2lkZUNoYXRSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

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

@$core.Deprecated('Use switchBranchRequestDescriptor instead')
const SwitchBranchRequest$json = {
  '1': 'SwitchBranchRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'new_branch', '3': 3, '4': 1, '5': 8, '10': 'newBranch'},
    {'1': 'with_others', '3': 4, '4': 1, '5': 8, '10': 'withOthers'},
  ],
};

/// Descriptor for `SwitchBranchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List switchBranchRequestDescriptor = $convert.base64Decode(
    'ChNTd2l0Y2hCcmFuY2hSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIWCgZicmFuY2'
    'gYAiABKAlSBmJyYW5jaBIdCgpuZXdfYnJhbmNoGAMgASgIUgluZXdCcmFuY2gSHwoLd2l0aF9v'
    'dGhlcnMYBCABKAhSCndpdGhPdGhlcnM=');

@$core.Deprecated('Use switchBranchResponseDescriptor instead')
const SwitchBranchResponse$json = {
  '1': 'SwitchBranchResponse',
  '2': [
    {'1': 'switched', '3': 1, '4': 1, '5': 8, '10': 'switched'},
    {'1': 'worktree', '3': 2, '4': 1, '5': 9, '10': 'worktree'},
    {'1': 'changed', '3': 3, '4': 1, '5': 5, '10': 'changed'},
    {'1': 'others', '3': 4, '4': 3, '5': 9, '10': 'others'},
  ],
};

/// Descriptor for `SwitchBranchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List switchBranchResponseDescriptor = $convert.base64Decode(
    'ChRTd2l0Y2hCcmFuY2hSZXNwb25zZRIaCghzd2l0Y2hlZBgBIAEoCFIIc3dpdGNoZWQSGgoId2'
    '9ya3RyZWUYAiABKAlSCHdvcmt0cmVlEhgKB2NoYW5nZWQYAyABKAVSB2NoYW5nZWQSFgoGb3Ro'
    'ZXJzGAQgAygJUgZvdGhlcnM=');

@$core.Deprecated('Use pinChatsRequestDescriptor instead')
const PinChatsRequest$json = {
  '1': 'PinChatsRequest',
  '2': [
    {'1': 'chat_ids', '3': 1, '4': 3, '5': 9, '10': 'chatIds'},
  ],
};

/// Descriptor for `PinChatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pinChatsRequestDescriptor = $convert.base64Decode(
    'Cg9QaW5DaGF0c1JlcXVlc3QSGQoIY2hhdF9pZHMYASADKAlSB2NoYXRJZHM=');

@$core.Deprecated('Use pinChatsResponseDescriptor instead')
const PinChatsResponse$json = {
  '1': 'PinChatsResponse',
};

/// Descriptor for `PinChatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pinChatsResponseDescriptor =
    $convert.base64Decode('ChBQaW5DaGF0c1Jlc3BvbnNl');

@$core.Deprecated('Use setChatColorRequestDescriptor instead')
const SetChatColorRequest$json = {
  '1': 'SetChatColorRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'color', '3': 2, '4': 1, '5': 9, '10': 'color'},
  ],
};

/// Descriptor for `SetChatColorRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setChatColorRequestDescriptor = $convert.base64Decode(
    'ChNTZXRDaGF0Q29sb3JSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIUCgVjb2xvch'
    'gCIAEoCVIFY29sb3I=');

@$core.Deprecated('Use setChatColorResponseDescriptor instead')
const SetChatColorResponse$json = {
  '1': 'SetChatColorResponse',
};

/// Descriptor for `SetChatColorResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setChatColorResponseDescriptor =
    $convert.base64Decode('ChRTZXRDaGF0Q29sb3JSZXNwb25zZQ==');

@$core.Deprecated('Use pinMessageRequestDescriptor instead')
const PinMessageRequest$json = {
  '1': 'PinMessageRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
    {'1': 'pinned', '3': 3, '4': 1, '5': 8, '10': 'pinned'},
  ],
};

/// Descriptor for `PinMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pinMessageRequestDescriptor = $convert.base64Decode(
    'ChFQaW5NZXNzYWdlUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFwoHaXRlbV9pZB'
    'gCIAEoCVIGaXRlbUlkEhYKBnBpbm5lZBgDIAEoCFIGcGlubmVk');

@$core.Deprecated('Use pinMessageResponseDescriptor instead')
const PinMessageResponse$json = {
  '1': 'PinMessageResponse',
};

/// Descriptor for `PinMessageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pinMessageResponseDescriptor =
    $convert.base64Decode('ChJQaW5NZXNzYWdlUmVzcG9uc2U=');

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
    {
      '1': 'check_updates',
      '3': 5,
      '4': 1,
      '5': 8,
      '9': 2,
      '10': 'checkUpdates',
      '17': true
    },
  ],
  '8': [
    {'1': '_keep_transcripts'},
    {'1': '_transcript_days'},
    {'1': '_check_updates'},
  ],
  '9': [
    {'1': 6, '2': 7},
  ],
  '10': ['claude_go_agent'],
};

/// Descriptor for `Settings`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List settingsDescriptor = $convert.base64Decode(
    'CghTZXR0aW5ncxIuChNzbGVlcF9hZnRlcl9taW51dGVzGAEgASgFUhFzbGVlcEFmdGVyTWludX'
    'RlcxIbCglkZWJ1Z19sb2cYAiABKAhSCGRlYnVnTG9nEi4KEGtlZXBfdHJhbnNjcmlwdHMYAyAB'
    'KAhIAFIPa2VlcFRyYW5zY3JpcHRziAEBEiwKD3RyYW5zY3JpcHRfZGF5cxgEIAEoBUgBUg50cm'
    'Fuc2NyaXB0RGF5c4gBARIoCg1jaGVja191cGRhdGVzGAUgASgISAJSDGNoZWNrVXBkYXRlc4gB'
    'AUITChFfa2VlcF90cmFuc2NyaXB0c0ISChBfdHJhbnNjcmlwdF9kYXlzQhAKDl9jaGVja191cG'
    'RhdGVzSgQIBhAHUg9jbGF1ZGVfZ29fYWdlbnQ=');

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
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['older_than_days'],
};

/// Descriptor for `ClearTranscriptsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clearTranscriptsRequestDescriptor =
    $convert.base64Decode(
        'ChdDbGVhclRyYW5zY3JpcHRzUmVxdWVzdBIZCghjaGF0X2lkcxgBIAMoCVIHY2hhdElkcxIQCg'
        'NhbGwYAiABKAhSA2FsbEoECAMQBFIPb2xkZXJfdGhhbl9kYXlz');

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
    {'1': 'others', '3': 3, '4': 3, '5': 9, '10': 'others'},
  ],
};

/// Descriptor for `WorktreePlan`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List worktreePlanDescriptor = $convert.base64Decode(
    'CgxXb3JrdHJlZVBsYW4SLgoId29ya3RyZWUYASABKAsyEi5udXNoaS52MS5Xb3JrdHJlZVIId2'
    '9ya3RyZWUSLQoFc3RhdGUYAiABKAsyFy5udXNoaS52MS5Xb3JrdHJlZVN0YXRlUgVzdGF0ZRIW'
    'CgZvdGhlcnMYAyADKAlSBm90aGVycw==');

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
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `ListMcpServersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listMcpServersRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0TWNwU2VydmVyc1JlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISIQoMY2hlY2'
    'tfaGVhbHRoGAIgASgIUgtjaGVja0hlYWx0aBIUCgVhZ2VudBgDIAEoCVIFYWdlbnQ=');

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
    {'1': 'agent', '3': 5, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `AddMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addMcpServerRequestDescriptor = $convert.base64Decode(
    'ChNBZGRNY3BTZXJ2ZXJSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBXNjb3BlGA'
    'IgASgJUgVzY29wZRISCgRuYW1lGAMgASgJUgRuYW1lEh8KC2NvbmZpZ19qc29uGAQgASgJUgpj'
    'b25maWdKc29uEhQKBWFnZW50GAUgASgJUgVhZ2VudA==');

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
    {'1': 'agent', '3': 5, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `EditMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List editMcpServerRequestDescriptor = $convert.base64Decode(
    'ChRFZGl0TWNwU2VydmVyUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchIUCgVzY29wZR'
    'gCIAEoCVIFc2NvcGUSEgoEbmFtZRgDIAEoCVIEbmFtZRIfCgtjb25maWdfanNvbhgEIAEoCVIK'
    'Y29uZmlnSnNvbhIUCgVhZ2VudBgFIAEoCVIFYWdlbnQ=');

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
    {'1': 'agent', '3': 4, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `RemoveMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeMcpServerRequestDescriptor = $convert.base64Decode(
    'ChZSZW1vdmVNY3BTZXJ2ZXJSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhQKBXNjb3'
    'BlGAIgASgJUgVzY29wZRISCgRuYW1lGAMgASgJUgRuYW1lEhQKBWFnZW50GAQgASgJUgVhZ2Vu'
    'dA==');

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
    {'1': 'agent', '3': 5, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `SetMcpServerOnRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setMcpServerOnRequestDescriptor = $convert.base64Decode(
    'ChVTZXRNY3BTZXJ2ZXJPblJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRIOCgJvbhgDIAEoCFICb24SFAoFc2NvcGUYBCABKAlSBXNjb3BlEhQKBWFn'
    'ZW50GAUgASgJUgVhZ2VudA==');

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
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `LoginMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginMcpServerRequestDescriptor = $convert.base64Decode(
    'ChVMb2dpbk1jcFNlcnZlclJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRIUCgVhZ2VudBgDIAEoCVIFYWdlbnQ=');

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
    {'1': 'agent', '3': 3, '4': 1, '5': 9, '10': 'agent'},
  ],
};

/// Descriptor for `LogoutMcpServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logoutMcpServerRequestDescriptor =
    $convert.base64Decode(
        'ChZMb2dvdXRNY3BTZXJ2ZXJSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhIKBG5hbW'
        'UYAiABKAlSBG5hbWUSFAoFYWdlbnQYAyABKAlSBWFnZW50');

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
    {'1': 'has_built_in', '3': 9, '4': 1, '5': 8, '10': 'hasBuiltIn'},
    {'1': 'has_plugins', '3': 10, '4': 1, '5': 8, '10': 'hasPlugins'},
  ],
};

/// Descriptor for `ListSkillsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSkillsResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0U2tpbGxzUmVzcG9uc2USJwoGc2tpbGxzGAEgAygLMg8ubnVzaGkudjEuU2tpbGxSBn'
    'NraWxscxIqCgdwbHVnaW5zGAIgAygLMhAubnVzaGkudjEuUGx1Z2luUgdwbHVnaW5zEiMKDXBs'
    'dWdpbnNfZXJyb3IYAyABKAlSDHBsdWdpbnNFcnJvchIgCgxidWlsdF9pbl9vZmYYBCABKAhSCm'
    'J1aWx0SW5PZmYSJQoPYnVpbHRfaW5fc2V0X2luGAUgASgJUgxidWlsdEluU2V0SW4SGwoJbm9f'
    'c2tpbGxzGAYgASgJUghub1NraWxscxIbCglub19zd2l0Y2gYByABKAlSCG5vU3dpdGNoEiEKDH'
    'JlYWRzX3NoYXJlZBgIIAEoCFILcmVhZHNTaGFyZWQSIAoMaGFzX2J1aWx0X2luGAkgASgIUgpo'
    'YXNCdWlsdEluEh8KC2hhc19wbHVnaW5zGAogASgIUgpoYXNQbHVnaW5z');

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
    {'1': 'one_file', '3': 12, '4': 1, '5': 8, '10': 'oneFile'},
    {'1': 'no_trash', '3': 13, '4': 1, '5': 8, '10': 'noTrash'},
    {'1': 'no_link', '3': 14, '4': 1, '5': 8, '10': 'noLink'},
  ],
};

/// Descriptor for `Skill`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skillDescriptor = $convert.base64Decode(
    'CgVTa2lsbBISCgRuYW1lGAEgASgJUgRuYW1lEiAKC2Rlc2NyaXB0aW9uGAIgASgJUgtkZXNjcm'
    'lwdGlvbhIWCgZzb3VyY2UYAyABKAlSBnNvdXJjZRIWCgZwbHVnaW4YBCABKAlSBnBsdWdpbhIS'
    'CgRwYXRoGAUgASgJUgRwYXRoEhQKBXN0YXRlGAYgASgJUgVzdGF0ZRIVCgZzZXRfaW4YByABKA'
    'lSBXNldEluEhYKBnRva2VucxgIIAEoBVIGdG9rZW5zEhYKBmxpbmtlZBgJIAEoCVIGbGlua2Vk'
    'Eh4KCmV2ZXJ5d2hlcmUYCiABKAhSCmV2ZXJ5d2hlcmUSLAoGYWdlbnRzGAsgAygLMhQubnVzaG'
    'kudjEuU2tpbGxBZ2VudFIGYWdlbnRzEhkKCG9uZV9maWxlGAwgASgIUgdvbmVGaWxlEhkKCG5v'
    'X3RyYXNoGA0gASgIUgdub1RyYXNoEhcKB25vX2xpbmsYDiABKAhSBm5vTGluaw==');

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

@$core.Deprecated('Use getRelatedWorktreesRequestDescriptor instead')
const GetRelatedWorktreesRequest$json = {
  '1': 'GetRelatedWorktreesRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `GetRelatedWorktreesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRelatedWorktreesRequestDescriptor =
    $convert.base64Decode(
        'ChpHZXRSZWxhdGVkV29ya3RyZWVzUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use getRelatedWorktreesResponseDescriptor instead')
const GetRelatedWorktreesResponse$json = {
  '1': 'GetRelatedWorktreesResponse',
  '2': [
    {
      '1': 'worktrees',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.RelatedWorktree',
      '10': 'worktrees'
    },
  ],
};

/// Descriptor for `GetRelatedWorktreesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRelatedWorktreesResponseDescriptor =
    $convert.base64Decode(
        'ChtHZXRSZWxhdGVkV29ya3RyZWVzUmVzcG9uc2USNwoJd29ya3RyZWVzGAEgAygLMhkubnVzaG'
        'kudjEuUmVsYXRlZFdvcmt0cmVlUgl3b3JrdHJlZXM=');

@$core.Deprecated('Use chatRelatedWorktreesDescriptor instead')
const ChatRelatedWorktrees$json = {
  '1': 'ChatRelatedWorktrees',
  '2': [
    {
      '1': 'worktrees',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.RelatedWorktree',
      '10': 'worktrees'
    },
  ],
};

/// Descriptor for `ChatRelatedWorktrees`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatRelatedWorktreesDescriptor = $convert.base64Decode(
    'ChRDaGF0UmVsYXRlZFdvcmt0cmVlcxI3Cgl3b3JrdHJlZXMYASADKAsyGS5udXNoaS52MS5SZW'
    'xhdGVkV29ya3RyZWVSCXdvcmt0cmVlcw==');

@$core.Deprecated('Use relatedWorktreeDescriptor instead')
const RelatedWorktree$json = {
  '1': 'RelatedWorktree',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'base_commit', '3': 3, '4': 1, '5': 9, '10': 'baseCommit'},
    {'1': 'last_head', '3': 4, '4': 1, '5': 9, '10': 'lastHead'},
    {'1': 'call_id', '3': 5, '4': 1, '5': 9, '10': 'callId'},
    {'1': 'state', '3': 6, '4': 1, '5': 9, '10': 'state'},
    {'1': 'merged', '3': 7, '4': 1, '5': 8, '10': 'merged'},
  ],
};

/// Descriptor for `RelatedWorktree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatedWorktreeDescriptor = $convert.base64Decode(
    'Cg9SZWxhdGVkV29ya3RyZWUSEgoEcGF0aBgBIAEoCVIEcGF0aBIWCgZicmFuY2gYAiABKAlSBm'
    'JyYW5jaBIfCgtiYXNlX2NvbW1pdBgDIAEoCVIKYmFzZUNvbW1pdBIbCglsYXN0X2hlYWQYBCAB'
    'KAlSCGxhc3RIZWFkEhcKB2NhbGxfaWQYBSABKAlSBmNhbGxJZBIUCgVzdGF0ZRgGIAEoCVIFc3'
    'RhdGUSFgoGbWVyZ2VkGAcgASgIUgZtZXJnZWQ=');

@$core.Deprecated('Use getRelatedWorktreeStatsRequestDescriptor instead')
const GetRelatedWorktreeStatsRequest$json = {
  '1': 'GetRelatedWorktreeStatsRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'paths', '3': 2, '4': 3, '5': 9, '10': 'paths'},
  ],
};

/// Descriptor for `GetRelatedWorktreeStatsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRelatedWorktreeStatsRequestDescriptor =
    $convert.base64Decode(
        'Ch5HZXRSZWxhdGVkV29ya3RyZWVTdGF0c1JlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdE'
        'lkEhQKBXBhdGhzGAIgAygJUgVwYXRocw==');

@$core.Deprecated('Use getRelatedWorktreeStatsResponseDescriptor instead')
const GetRelatedWorktreeStatsResponse$json = {
  '1': 'GetRelatedWorktreeStatsResponse',
  '2': [
    {
      '1': 'stats',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.RelatedWorktreeStats',
      '10': 'stats'
    },
  ],
};

/// Descriptor for `GetRelatedWorktreeStatsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getRelatedWorktreeStatsResponseDescriptor =
    $convert.base64Decode(
        'Ch9HZXRSZWxhdGVkV29ya3RyZWVTdGF0c1Jlc3BvbnNlEjQKBXN0YXRzGAEgAygLMh4ubnVzaG'
        'kudjEuUmVsYXRlZFdvcmt0cmVlU3RhdHNSBXN0YXRz');

@$core.Deprecated('Use relatedWorktreeStatsDescriptor instead')
const RelatedWorktreeStats$json = {
  '1': 'RelatedWorktreeStats',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'files', '3': 2, '4': 1, '5': 5, '10': 'files'},
    {'1': 'added', '3': 3, '4': 1, '5': 5, '10': 'added'},
    {'1': 'removed', '3': 4, '4': 1, '5': 5, '10': 'removed'},
    {'1': 'ahead', '3': 5, '4': 1, '5': 5, '10': 'ahead'},
    {'1': 'commits_gone', '3': 6, '4': 1, '5': 8, '10': 'commitsGone'},
  ],
};

/// Descriptor for `RelatedWorktreeStats`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List relatedWorktreeStatsDescriptor = $convert.base64Decode(
    'ChRSZWxhdGVkV29ya3RyZWVTdGF0cxISCgRwYXRoGAEgASgJUgRwYXRoEhQKBWZpbGVzGAIgAS'
    'gFUgVmaWxlcxIUCgVhZGRlZBgDIAEoBVIFYWRkZWQSGAoHcmVtb3ZlZBgEIAEoBVIHcmVtb3Zl'
    'ZBIUCgVhaGVhZBgFIAEoBVIFYWhlYWQSIQoMY29tbWl0c19nb25lGAYgASgIUgtjb21taXRzR2'
    '9uZQ==');

@$core.Deprecated('Use getProjectIconRequestDescriptor instead')
const GetProjectIconRequest$json = {
  '1': 'GetProjectIconRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `GetProjectIconRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProjectIconRequestDescriptor =
    $convert.base64Decode(
        'ChVHZXRQcm9qZWN0SWNvblJlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXI=');

@$core.Deprecated('Use getProjectIconResponseDescriptor instead')
const GetProjectIconResponse$json = {
  '1': 'GetProjectIconResponse',
  '2': [
    {'1': 'mime_type', '3': 1, '4': 1, '5': 9, '10': 'mimeType'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
  ],
};

/// Descriptor for `GetProjectIconResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProjectIconResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRQcm9qZWN0SWNvblJlc3BvbnNlEhsKCW1pbWVfdHlwZRgBIAEoCVIIbWltZVR5cGUSEg'
        'oEZGF0YRgCIAEoDFIEZGF0YQ==');

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

@$core.Deprecated('Use listBranchesRequestDescriptor instead')
const ListBranchesRequest$json = {
  '1': 'ListBranchesRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `ListBranchesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBranchesRequestDescriptor =
    $convert.base64Decode(
        'ChNMaXN0QnJhbmNoZXNSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVy');

@$core.Deprecated('Use listBranchesResponseDescriptor instead')
const ListBranchesResponse$json = {
  '1': 'ListBranchesResponse',
  '2': [
    {
      '1': 'branches',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitBranch',
      '10': 'branches'
    },
    {
      '1': 'worktrees',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitWorktree',
      '10': 'worktrees'
    },
  ],
};

/// Descriptor for `ListBranchesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBranchesResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0QnJhbmNoZXNSZXNwb25zZRIvCghicmFuY2hlcxgBIAMoCzITLm51c2hpLnYxLkdpdE'
    'JyYW5jaFIIYnJhbmNoZXMSMwoJd29ya3RyZWVzGAIgAygLMhUubnVzaGkudjEuR2l0V29ya3Ry'
    'ZWVSCXdvcmt0cmVlcw==');

@$core.Deprecated('Use gitBranchDescriptor instead')
const GitBranch$json = {
  '1': 'GitBranch',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'unix_seconds', '3': 2, '4': 1, '5': 3, '10': 'unixSeconds'},
    {'1': 'worktree', '3': 3, '4': 1, '5': 9, '10': 'worktree'},
  ],
};

/// Descriptor for `GitBranch`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitBranchDescriptor = $convert.base64Decode(
    'CglHaXRCcmFuY2gSEgoEbmFtZRgBIAEoCVIEbmFtZRIhCgx1bml4X3NlY29uZHMYAiABKANSC3'
    'VuaXhTZWNvbmRzEhoKCHdvcmt0cmVlGAMgASgJUgh3b3JrdHJlZQ==');

@$core.Deprecated('Use gitWorktreeDescriptor instead')
const GitWorktree$json = {
  '1': 'GitWorktree',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'branch', '3': 2, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'main', '3': 3, '4': 1, '5': 8, '10': 'main'},
    {'1': 'locked', '3': 4, '4': 1, '5': 8, '10': 'locked'},
    {'1': 'current', '3': 5, '4': 1, '5': 8, '10': 'current'},
  ],
};

/// Descriptor for `GitWorktree`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitWorktreeDescriptor = $convert.base64Decode(
    'CgtHaXRXb3JrdHJlZRISCgRwYXRoGAEgASgJUgRwYXRoEhYKBmJyYW5jaBgCIAEoCVIGYnJhbm'
    'NoEhIKBG1haW4YAyABKAhSBG1haW4SFgoGbG9ja2VkGAQgASgIUgZsb2NrZWQSGAoHY3VycmVu'
    'dBgFIAEoCFIHY3VycmVudA==');

@$core.Deprecated('Use getDiffRequestDescriptor instead')
const GetDiffRequest$json = {
  '1': 'GetDiffRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'base', '3': 2, '4': 1, '5': 9, '10': 'base'},
    {'1': 'commit', '3': 3, '4': 1, '5': 9, '10': 'commit'},
    {'1': 'since', '3': 4, '4': 1, '5': 9, '10': 'since'},
    {'1': 'after', '3': 5, '4': 1, '5': 9, '10': 'after'},
  ],
};

/// Descriptor for `GetDiffRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDiffRequestDescriptor = $convert.base64Decode(
    'Cg5HZXREaWZmUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchISCgRiYXNlGAIgASgJUg'
    'RiYXNlEhYKBmNvbW1pdBgDIAEoCVIGY29tbWl0EhQKBXNpbmNlGAQgASgJUgVzaW5jZRIUCgVh'
    'ZnRlchgFIAEoCVIFYWZ0ZXI=');

@$core.Deprecated('Use stageFilesRequestDescriptor instead')
const StageFilesRequest$json = {
  '1': 'StageFilesRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'paths', '3': 2, '4': 3, '5': 9, '10': 'paths'},
    {'1': 'staged', '3': 3, '4': 1, '5': 8, '10': 'staged'},
  ],
};

/// Descriptor for `StageFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stageFilesRequestDescriptor = $convert.base64Decode(
    'ChFTdGFnZUZpbGVzUmVxdWVzdBIWCgZmb2xkZXIYASABKAlSBmZvbGRlchIUCgVwYXRocxgCIA'
    'MoCVIFcGF0aHMSFgoGc3RhZ2VkGAMgASgIUgZzdGFnZWQ=');

@$core.Deprecated('Use stageFilesResponseDescriptor instead')
const StageFilesResponse$json = {
  '1': 'StageFilesResponse',
};

/// Descriptor for `StageFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stageFilesResponseDescriptor =
    $convert.base64Decode('ChJTdGFnZUZpbGVzUmVzcG9uc2U=');

@$core.Deprecated('Use writeCommitMessageRequestDescriptor instead')
const WriteCommitMessageRequest$json = {
  '1': 'WriteCommitMessageRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `WriteCommitMessageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeCommitMessageRequestDescriptor =
    $convert.base64Decode(
        'ChlXcml0ZUNvbW1pdE1lc3NhZ2VSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZA==');

@$core.Deprecated('Use writeCommitMessageResponseDescriptor instead')
const WriteCommitMessageResponse$json = {
  '1': 'WriteCommitMessageResponse',
  '2': [
    {'1': 'message', '3': 1, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `WriteCommitMessageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeCommitMessageResponseDescriptor =
    $convert.base64Decode(
        'ChpXcml0ZUNvbW1pdE1lc3NhZ2VSZXNwb25zZRIYCgdtZXNzYWdlGAEgASgJUgdtZXNzYWdl');

@$core.Deprecated('Use commitStagedRequestDescriptor instead')
const CommitStagedRequest$json = {
  '1': 'CommitStagedRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'index', '3': 3, '4': 1, '5': 9, '10': 'index'},
  ],
};

/// Descriptor for `CommitStagedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitStagedRequestDescriptor = $convert.base64Decode(
    'ChNDb21taXRTdGFnZWRSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEhgKB21lc3NhZ2'
    'UYAiABKAlSB21lc3NhZ2USFAoFaW5kZXgYAyABKAlSBWluZGV4');

@$core.Deprecated('Use commitStagedResponseDescriptor instead')
const CommitStagedResponse$json = {
  '1': 'CommitStagedResponse',
  '2': [
    {'1': 'short', '3': 1, '4': 1, '5': 9, '10': 'short'},
  ],
};

/// Descriptor for `CommitStagedResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitStagedResponseDescriptor =
    $convert.base64Decode(
        'ChRDb21taXRTdGFnZWRSZXNwb25zZRIUCgVzaG9ydBgBIAEoCVIFc2hvcnQ=');

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

@$core.Deprecated('Use findChatFilesRequestDescriptor instead')
const FindChatFilesRequest$json = {
  '1': 'FindChatFilesRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'paths', '3': 2, '4': 3, '5': 9, '10': 'paths'},
  ],
};

/// Descriptor for `FindChatFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findChatFilesRequestDescriptor = $convert.base64Decode(
    'ChRGaW5kQ2hhdEZpbGVzUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFAoFcGF0aH'
    'MYAiADKAlSBXBhdGhz');

@$core.Deprecated('Use findChatFilesResponseDescriptor instead')
const FindChatFilesResponse$json = {
  '1': 'FindChatFilesResponse',
  '2': [
    {'1': 'found', '3': 1, '4': 3, '5': 9, '10': 'found'},
  ],
};

/// Descriptor for `FindChatFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findChatFilesResponseDescriptor =
    $convert.base64Decode(
        'ChVGaW5kQ2hhdEZpbGVzUmVzcG9uc2USFAoFZm91bmQYASADKAlSBWZvdW5k');

@$core.Deprecated('Use watchChatFolderRequestDescriptor instead')
const WatchChatFolderRequest$json = {
  '1': 'WatchChatFolderRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'depth', '3': 3, '4': 1, '5': 5, '10': 'depth'},
    {'1': 'ignored', '3': 4, '4': 1, '5': 8, '10': 'ignored'},
    {'1': 'limit', '3': 5, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `WatchChatFolderRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchChatFolderRequestDescriptor = $convert.base64Decode(
    'ChZXYXRjaENoYXRGb2xkZXJSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBISCgRwYX'
    'RoGAIgASgJUgRwYXRoEhQKBWRlcHRoGAMgASgFUgVkZXB0aBIYCgdpZ25vcmVkGAQgASgIUgdp'
    'Z25vcmVkEhQKBWxpbWl0GAUgASgFUgVsaW1pdA==');

@$core.Deprecated('Use watchChatFolderResponseDescriptor instead')
const WatchChatFolderResponse$json = {
  '1': 'WatchChatFolderResponse',
  '2': [
    {
      '1': 'folders',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FolderListing',
      '10': 'folders'
    },
  ],
};

/// Descriptor for `WatchChatFolderResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchChatFolderResponseDescriptor =
    $convert.base64Decode(
        'ChdXYXRjaENoYXRGb2xkZXJSZXNwb25zZRIxCgdmb2xkZXJzGAEgAygLMhcubnVzaGkudjEuRm'
        '9sZGVyTGlzdGluZ1IHZm9sZGVycw==');

@$core.Deprecated('Use folderListingDescriptor instead')
const FolderListing$json = {
  '1': 'FolderListing',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {
      '1': 'entries',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.FolderEntry',
      '10': 'entries'
    },
    {'1': 'more', '3': 3, '4': 1, '5': 5, '10': 'more'},
    {'1': 'missing', '3': 4, '4': 1, '5': 8, '10': 'missing'},
  ],
};

/// Descriptor for `FolderListing`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List folderListingDescriptor = $convert.base64Decode(
    'Cg1Gb2xkZXJMaXN0aW5nEhIKBHBhdGgYASABKAlSBHBhdGgSLwoHZW50cmllcxgCIAMoCzIVLm'
    '51c2hpLnYxLkZvbGRlckVudHJ5UgdlbnRyaWVzEhIKBG1vcmUYAyABKAVSBG1vcmUSGAoHbWlz'
    'c2luZxgEIAEoCFIHbWlzc2luZw==');

@$core.Deprecated('Use folderEntryDescriptor instead')
const FolderEntry$json = {
  '1': 'FolderEntry',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {'1': 'modified_ms', '3': 4, '4': 1, '5': 3, '10': 'modifiedMs'},
    {'1': 'ignored', '3': 5, '4': 1, '5': 8, '10': 'ignored'},
    {'1': 'linked', '3': 6, '4': 1, '5': 8, '10': 'linked'},
  ],
};

/// Descriptor for `FolderEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List folderEntryDescriptor = $convert.base64Decode(
    'CgtGb2xkZXJFbnRyeRISCgRuYW1lGAEgASgJUgRuYW1lEhIKBGtpbmQYAiABKAlSBGtpbmQSEg'
    'oEc2l6ZRgDIAEoA1IEc2l6ZRIfCgttb2RpZmllZF9tcxgEIAEoA1IKbW9kaWZpZWRNcxIYCgdp'
    'Z25vcmVkGAUgASgIUgdpZ25vcmVkEhYKBmxpbmtlZBgGIAEoCFIGbGlua2Vk');

@$core.Deprecated('Use watchChatFileResponseDescriptor instead')
const WatchChatFileResponse$json = {
  '1': 'WatchChatFileResponse',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'size', '3': 3, '4': 1, '5': 3, '10': 'size'},
    {'1': 'too_large', '3': 4, '4': 1, '5': 8, '10': 'tooLarge'},
    {'1': 'missing', '3': 5, '4': 1, '5': 8, '10': 'missing'},
    {'1': 'sha256', '3': 6, '4': 1, '5': 9, '10': 'sha256'},
    {'1': 'editable', '3': 7, '4': 1, '5': 8, '10': 'editable'},
    {'1': 'read_only', '3': 8, '4': 1, '5': 8, '10': 'readOnly'},
  ],
};

/// Descriptor for `WatchChatFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchChatFileResponseDescriptor = $convert.base64Decode(
    'ChVXYXRjaENoYXRGaWxlUmVzcG9uc2USEgoEcGF0aBgBIAEoCVIEcGF0aBISCgRkYXRhGAIgAS'
    'gMUgRkYXRhEhIKBHNpemUYAyABKANSBHNpemUSGwoJdG9vX2xhcmdlGAQgASgIUgh0b29MYXJn'
    'ZRIYCgdtaXNzaW5nGAUgASgIUgdtaXNzaW5nEhYKBnNoYTI1NhgGIAEoCVIGc2hhMjU2EhoKCG'
    'VkaXRhYmxlGAcgASgIUghlZGl0YWJsZRIbCglyZWFkX29ubHkYCCABKAhSCHJlYWRPbmx5');

@$core.Deprecated('Use writeChatFileRequestDescriptor instead')
const WriteChatFileRequest$json = {
  '1': 'WriteChatFileRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'path', '3': 2, '4': 1, '5': 9, '10': 'path'},
    {'1': 'data', '3': 3, '4': 1, '5': 12, '10': 'data'},
    {'1': 'base_sha256', '3': 4, '4': 1, '5': 9, '10': 'baseSha256'},
    {'1': 'must_not_exist', '3': 5, '4': 1, '5': 8, '10': 'mustNotExist'},
  ],
};

/// Descriptor for `WriteChatFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeChatFileRequestDescriptor = $convert.base64Decode(
    'ChRXcml0ZUNoYXRGaWxlUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEgoEcGF0aB'
    'gCIAEoCVIEcGF0aBISCgRkYXRhGAMgASgMUgRkYXRhEh8KC2Jhc2Vfc2hhMjU2GAQgASgJUgpi'
    'YXNlU2hhMjU2EiQKDm11c3Rfbm90X2V4aXN0GAUgASgIUgxtdXN0Tm90RXhpc3Q=');

@$core.Deprecated('Use writeChatFileResponseDescriptor instead')
const WriteChatFileResponse$json = {
  '1': 'WriteChatFileResponse',
  '2': [
    {
      '1': 'saved',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.WriteChatFileResponse.Saved',
      '9': 0,
      '10': 'saved'
    },
    {
      '1': 'stale',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.WriteChatFileResponse.Stale',
      '9': 0,
      '10': 'stale'
    },
  ],
  '3': [WriteChatFileResponse_Saved$json, WriteChatFileResponse_Stale$json],
  '8': [
    {'1': 'result'},
  ],
};

@$core.Deprecated('Use writeChatFileResponseDescriptor instead')
const WriteChatFileResponse_Saved$json = {
  '1': 'Saved',
  '2': [
    {'1': 'sha256', '3': 1, '4': 1, '5': 9, '10': 'sha256'},
  ],
};

@$core.Deprecated('Use writeChatFileResponseDescriptor instead')
const WriteChatFileResponse_Stale$json = {
  '1': 'Stale',
  '2': [
    {'1': 'sha256', '3': 1, '4': 1, '5': 9, '10': 'sha256'},
    {'1': 'data', '3': 2, '4': 1, '5': 12, '10': 'data'},
    {'1': 'missing', '3': 3, '4': 1, '5': 8, '10': 'missing'},
  ],
};

/// Descriptor for `WriteChatFileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List writeChatFileResponseDescriptor = $convert.base64Decode(
    'ChVXcml0ZUNoYXRGaWxlUmVzcG9uc2USPQoFc2F2ZWQYASABKAsyJS5udXNoaS52MS5Xcml0ZU'
    'NoYXRGaWxlUmVzcG9uc2UuU2F2ZWRIAFIFc2F2ZWQSPQoFc3RhbGUYAiABKAsyJS5udXNoaS52'
    'MS5Xcml0ZUNoYXRGaWxlUmVzcG9uc2UuU3RhbGVIAFIFc3RhbGUaHwoFU2F2ZWQSFgoGc2hhMj'
    'U2GAEgASgJUgZzaGEyNTYaTQoFU3RhbGUSFgoGc2hhMjU2GAEgASgJUgZzaGEyNTYSEgoEZGF0'
    'YRgCIAEoDFIEZGF0YRIYCgdtaXNzaW5nGAMgASgIUgdtaXNzaW5nQggKBnJlc3VsdA==');

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
    {'1': 'index', '3': 2, '4': 1, '5': 9, '10': 'index'},
  ],
};

/// Descriptor for `GetDiffResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDiffResponseDescriptor = $convert.base64Decode(
    'Cg9HZXREaWZmUmVzcG9uc2USKgoFZmlsZXMYASADKAsyFC5udXNoaS52MS5GaWxlQ2hhbmdlUg'
    'VmaWxlcxIUCgVpbmRleBgCIAEoCVIFaW5kZXg=');

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
    {'1': 'staged', '3': 9, '4': 1, '5': 9, '10': 'staged'},
  ],
};

/// Descriptor for `FileChange`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fileChangeDescriptor = $convert.base64Decode(
    'CgpGaWxlQ2hhbmdlEhIKBHBhdGgYASABKAlSBHBhdGgSFgoGc3RhdHVzGAIgASgJUgZzdGF0dX'
    'MSGQoIb2xkX3RleHQYAyABKAlSB29sZFRleHQSGQoIbmV3X3RleHQYBCABKAlSB25ld1RleHQS'
    'GAoHc2tpcHBlZBgFIAEoCVIHc2tpcHBlZBIZCghvbGRfcGF0aBgGIAEoCVIHb2xkUGF0aBIUCg'
    'VhZGRlZBgHIAEoBVIFYWRkZWQSGAoHcmVtb3ZlZBgIIAEoBVIHcmVtb3ZlZBIWCgZzdGFnZWQY'
    'CSABKAlSBnN0YWdlZA==');

@$core.Deprecated('Use listCommitsRequestDescriptor instead')
const ListCommitsRequest$json = {
  '1': 'ListCommitsRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {'1': 'base', '3': 2, '4': 1, '5': 9, '10': 'base'},
    {'1': 'head', '3': 3, '4': 1, '5': 9, '10': 'head'},
  ],
};

/// Descriptor for `ListCommitsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCommitsRequestDescriptor = $convert.base64Decode(
    'ChJMaXN0Q29tbWl0c1JlcXVlc3QSFgoGZm9sZGVyGAEgASgJUgZmb2xkZXISEgoEYmFzZRgCIA'
    'EoCVIEYmFzZRISCgRoZWFkGAMgASgJUgRoZWFk');

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
  '2': [
    {'1': 'image_refs', '3': 1, '4': 1, '5': 8, '10': 'imageRefs'},
  ],
};

/// Descriptor for `EventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventsRequestDescriptor = $convert.base64Decode(
    'Cg1FdmVudHNSZXF1ZXN0Eh0KCmltYWdlX3JlZnMYASABKAhSCWltYWdlUmVmcw==');

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
    {
      '1': 'update',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.UpdateCheck',
      '9': 0,
      '10': 'update'
    },
    {'1': 'show', '3': 17, '4': 1, '5': 9, '9': 0, '10': 'show'},
    {
      '1': 'related_worktrees',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.ChatRelatedWorktrees',
      '9': 0,
      '10': 'relatedWorktrees'
    },
    {
      '1': 'servers_changed',
      '3': 19,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'serversChanged'
    },
    {'1': 'show_url', '3': 20, '4': 1, '5': 9, '9': 0, '10': 'showUrl'},
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
    'RDaGF0cxIvCgZ1cGRhdGUYECABKAsyFS5udXNoaS52MS5VcGRhdGVDaGVja0gAUgZ1cGRhdGUS'
    'FAoEc2hvdxgRIAEoCUgAUgRzaG93Ek0KEXJlbGF0ZWRfd29ya3RyZWVzGBIgASgLMh4ubnVzaG'
    'kudjEuQ2hhdFJlbGF0ZWRXb3JrdHJlZXNIAFIQcmVsYXRlZFdvcmt0cmVlcxIpCg9zZXJ2ZXJz'
    'X2NoYW5nZWQYEyABKAlIAFIOc2VydmVyc0NoYW5nZWQSGwoIc2hvd191cmwYFCABKAlIAFIHc2'
    'hvd1VybEIGCgRraW5k');

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
      '1': 'background_command',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.BackgroundCommand',
      '10': 'backgroundCommand'
    },
    {'1': 'agent_id', '3': 26, '4': 1, '5': 9, '10': 'agentId'},
    {'1': 'to_subagent_name', '3': 27, '4': 1, '5': 9, '10': 'toSubagentName'},
    {'1': 'to_subagent', '3': 28, '4': 1, '5': 9, '10': 'toSubagent'},
    {
      '1': 'to_subagent_state',
      '3': 29,
      '4': 1,
      '5': 9,
      '10': 'toSubagentState'
    },
    {
      '1': 'findings',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.Findings',
      '10': 'findings'
    },
    {'1': 'to_subagent_stop', '3': 32, '4': 1, '5': 8, '10': 'toSubagentStop'},
    {'1': 'sent', '3': 33, '4': 1, '5': 3, '10': 'sent'},
    {'1': 'input', '3': 34, '4': 1, '5': 9, '10': 'input'},
    {'1': 'raw_output', '3': 35, '4': 1, '5': 9, '10': 'rawOutput'},
    {'1': 'forkable', '3': 36, '4': 1, '5': 8, '10': 'forkable'},
    {'1': 'steered', '3': 37, '4': 1, '5': 8, '10': 'steered'},
    {'1': 'files', '3': 38, '4': 3, '5': 9, '10': 'files'},
    {'1': 'server_command', '3': 39, '4': 1, '5': 9, '10': 'serverCommand'},
  ],
  '9': [
    {'1': 17, '2': 18},
    {'1': 30, '2': 31},
  ],
  '10': ['fork_at', 'passed_on_by'],
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
    'CgVhZ2VudBgPIAEoCVIFYWdlbnQSEgoEdG9vbBgQIAEoCVIEdG9vbBIeCgpyZXdpbmRhYmxlGB'
    'IgASgIUgpyZXdpbmRhYmxlEi4KCHN1YmFnZW50GBMgASgLMhIubnVzaGkudjEuU3ViYWdlbnRS'
    'CHN1YmFnZW50EhYKBnJlcG9ydBgUIAEoCFIGcmVwb3J0EhYKBnByb21wdBgVIAEoCVIGcHJvbX'
    'B0EhQKBW1vZGVsGBYgASgJUgVtb2RlbBIWCgZlZmZvcnQYFyABKAlSBmVmZm9ydBIbCglyYW5f'
    'bW9kZWwYGCABKAlSCHJhbk1vZGVsEkoKEmJhY2tncm91bmRfY29tbWFuZBgZIAEoCzIbLm51c2'
    'hpLnYxLkJhY2tncm91bmRDb21tYW5kUhFiYWNrZ3JvdW5kQ29tbWFuZBIZCghhZ2VudF9pZBga'
    'IAEoCVIHYWdlbnRJZBIoChB0b19zdWJhZ2VudF9uYW1lGBsgASgJUg50b1N1YmFnZW50TmFtZR'
    'IfCgt0b19zdWJhZ2VudBgcIAEoCVIKdG9TdWJhZ2VudBIqChF0b19zdWJhZ2VudF9zdGF0ZRgd'
    'IAEoCVIPdG9TdWJhZ2VudFN0YXRlEi4KCGZpbmRpbmdzGB8gASgLMhIubnVzaGkudjEuRmluZG'
    'luZ3NSCGZpbmRpbmdzEigKEHRvX3N1YmFnZW50X3N0b3AYICABKAhSDnRvU3ViYWdlbnRTdG9w'
    'EhIKBHNlbnQYISABKANSBHNlbnQSFAoFaW5wdXQYIiABKAlSBWlucHV0Eh0KCnJhd19vdXRwdX'
    'QYIyABKAlSCXJhd091dHB1dBIaCghmb3JrYWJsZRgkIAEoCFIIZm9ya2FibGUSGAoHc3RlZXJl'
    'ZBglIAEoCFIHc3RlZXJlZBIUCgVmaWxlcxgmIAMoCVIFZmlsZXMSJQoOc2VydmVyX2NvbW1hbm'
    'QYJyABKAlSDXNlcnZlckNvbW1hbmRKBAgREBJKBAgeEB9SB2ZvcmtfYXRSDHBhc3NlZF9vbl9i'
    'eQ==');

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

@$core.Deprecated('Use backgroundCommandDescriptor instead')
const BackgroundCommand$json = {
  '1': 'BackgroundCommand',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'state', '3': 2, '4': 1, '5': 9, '10': 'state'},
    {'1': 'started', '3': 3, '4': 1, '5': 3, '10': 'started'},
    {'1': 'ended', '3': 4, '4': 1, '5': 3, '10': 'ended'},
    {'1': 'output', '3': 5, '4': 1, '5': 9, '10': 'output'},
    {'1': 'end', '3': 6, '4': 1, '5': 9, '10': 'end'},
  ],
};

/// Descriptor for `BackgroundCommand`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backgroundCommandDescriptor = $convert.base64Decode(
    'ChFCYWNrZ3JvdW5kQ29tbWFuZBIOCgJpZBgBIAEoCVICaWQSFAoFc3RhdGUYAiABKAlSBXN0YX'
    'RlEhgKB3N0YXJ0ZWQYAyABKANSB3N0YXJ0ZWQSFAoFZW5kZWQYBCABKANSBWVuZGVkEhYKBm91'
    'dHB1dBgFIAEoCVIGb3V0cHV0EhAKA2VuZBgGIAEoCVIDZW5k');

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
    {'1': 'can_write_commit', '3': 15, '4': 1, '5': 8, '10': 'canWriteCommit'},
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
    {'1': 'background', '3': 14, '4': 1, '5': 5, '10': 'background'},
    {
      '1': 'ended',
      '3': 16,
      '4': 1,
      '5': 14,
      '6': '.nushi.v1.TurnEnd',
      '10': 'ended'
    },
    {'1': 'failure', '3': 17, '4': 1, '5': 9, '10': 'failure'},
  ],
  '9': [
    {'1': 2, '2': 3},
  ],
  '10': ['error'],
};

/// Descriptor for `ChatStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatStatusDescriptor = $convert.base64Decode(
    'CgpDaGF0U3RhdHVzEigKEGNhbl93cml0ZV9jb21taXQYDyABKAhSDmNhbldyaXRlQ29tbWl0Eh'
    'IKBGJ1c3kYASABKAhSBGJ1c3kSGAoHc3RhcnRlZBgDIAEoA1IHc3RhcnRlZBIYCgd3YWl0aW5n'
    'GAQgASgIUgd3YWl0aW5nEhkKCGNhbl9mb3JrGAUgASgIUgdjYW5Gb3JrEhYKBmltYWdlcxgGIA'
    'EoCFIGaW1hZ2VzEh0KCmNhbl9yZXdpbmQYByABKAhSCWNhblJld2luZBIfCgttY3BfY2hhbmdl'
    'ZBgIIAEoCFIKbWNwQ2hhbmdlZBImCg9jYW5fYXNrX2NvbnRleHQYCSABKAhSDWNhbkFza0Nvbn'
    'RleHQSFgoGYXNsZWVwGAogASgIUgZhc2xlZXASGwoJY2FuX3NsZWVwGAsgASgIUghjYW5TbGVl'
    'cBIjCg1yZW9wZW5fZmFpbGVkGAwgASgIUgxyZW9wZW5GYWlsZWQSIQoMc2Vzc2lvbl9nb25lGA'
    '0gASgIUgtzZXNzaW9uR29uZRIeCgpiYWNrZ3JvdW5kGA4gASgFUgpiYWNrZ3JvdW5kEicKBWVu'
    'ZGVkGBAgASgOMhEubnVzaGkudjEuVHVybkVuZFIFZW5kZWQSGAoHZmFpbHVyZRgRIAEoCVIHZm'
    'FpbHVyZUoECAIQA1IFZXJyb3I=');

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

@$core.Deprecated('Use listServersRequestDescriptor instead')
const ListServersRequest$json = {
  '1': 'ListServersRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `ListServersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listServersRequestDescriptor =
    $convert.base64Decode(
        'ChJMaXN0U2VydmVyc1JlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElk');

@$core.Deprecated('Use listServersResponseDescriptor instead')
const ListServersResponse$json = {
  '1': 'ListServersResponse',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
    {
      '1': 'servers',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.DevServer',
      '10': 'servers'
    },
    {
      '1': 'files',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.LaunchFile',
      '10': 'files'
    },
  ],
};

/// Descriptor for `ListServersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listServersResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0U2VydmVyc1Jlc3BvbnNlEhYKBmZvbGRlchgBIAEoCVIGZm9sZGVyEi0KB3NlcnZlcn'
    'MYAiADKAsyEy5udXNoaS52MS5EZXZTZXJ2ZXJSB3NlcnZlcnMSKgoFZmlsZXMYAyADKAsyFC5u'
    'dXNoaS52MS5MYXVuY2hGaWxlUgVmaWxlcw==');

@$core.Deprecated('Use launchFileDescriptor instead')
const LaunchFile$json = {
  '1': 'LaunchFile',
  '2': [
    {'1': 'path', '3': 1, '4': 1, '5': 9, '10': 'path'},
    {'1': 'from_main', '3': 2, '4': 1, '5': 8, '10': 'fromMain'},
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `LaunchFile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List launchFileDescriptor = $convert.base64Decode(
    'CgpMYXVuY2hGaWxlEhIKBHBhdGgYASABKAlSBHBhdGgSGwoJZnJvbV9tYWluGAIgASgIUghmcm'
    '9tTWFpbhIUCgVlcnJvchgDIAEoCVIFZXJyb3I=');

@$core.Deprecated('Use devServerDescriptor instead')
const DevServer$json = {
  '1': 'DevServer',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'name_ok', '3': 2, '4': 1, '5': 8, '10': 'nameOk'},
    {'1': 'index', '3': 3, '4': 1, '5': 5, '10': 'index'},
    {'1': 'source', '3': 4, '4': 1, '5': 9, '10': 'source'},
    {'1': 'from_main', '3': 5, '4': 1, '5': 8, '10': 'fromMain'},
    {'1': 'command', '3': 6, '4': 1, '5': 9, '10': 'command'},
    {'1': 'program', '3': 7, '4': 1, '5': 9, '10': 'program'},
    {'1': 'args', '3': 8, '4': 3, '5': 9, '10': 'args'},
    {'1': 'cwd', '3': 9, '4': 1, '5': 9, '10': 'cwd'},
    {
      '1': 'env',
      '3': 10,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.DevServer.EnvEntry',
      '10': 'env'
    },
    {'1': 'flagged_env', '3': 11, '4': 3, '5': 9, '10': 'flaggedEnv'},
    {'1': 'url', '3': 12, '4': 1, '5': 9, '10': 'url'},
    {'1': 'port', '3': 13, '4': 1, '5': 5, '10': 'port'},
    {'1': 'attach', '3': 14, '4': 1, '5': 8, '10': 'attach'},
    {'1': 'problem', '3': 15, '4': 1, '5': 9, '10': 'problem'},
    {
      '1': 'state',
      '3': 16,
      '4': 1,
      '5': 14,
      '6': '.nushi.v1.DevServerState',
      '10': 'state'
    },
    {'1': 'error', '3': 17, '4': 1, '5': 9, '10': 'error'},
    {'1': 'output', '3': 18, '4': 1, '5': 9, '10': 'output'},
    {'1': 'server_id', '3': 19, '4': 1, '5': 9, '10': 'serverId'},
    {'1': 'changed', '3': 20, '4': 1, '5': 8, '10': 'changed'},
    {'1': 'hash', '3': 21, '4': 1, '5': 9, '10': 'hash'},
    {'1': 'log_id', '3': 22, '4': 1, '5': 9, '10': 'logId'},
  ],
  '3': [DevServer_EnvEntry$json],
};

@$core.Deprecated('Use devServerDescriptor instead')
const DevServer_EnvEntry$json = {
  '1': 'EnvEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DevServer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List devServerDescriptor = $convert.base64Decode(
    'CglEZXZTZXJ2ZXISEgoEbmFtZRgBIAEoCVIEbmFtZRIXCgduYW1lX29rGAIgASgIUgZuYW1lT2'
    'sSFAoFaW5kZXgYAyABKAVSBWluZGV4EhYKBnNvdXJjZRgEIAEoCVIGc291cmNlEhsKCWZyb21f'
    'bWFpbhgFIAEoCFIIZnJvbU1haW4SGAoHY29tbWFuZBgGIAEoCVIHY29tbWFuZBIYCgdwcm9ncm'
    'FtGAcgASgJUgdwcm9ncmFtEhIKBGFyZ3MYCCADKAlSBGFyZ3MSEAoDY3dkGAkgASgJUgNjd2QS'
    'LgoDZW52GAogAygLMhwubnVzaGkudjEuRGV2U2VydmVyLkVudkVudHJ5UgNlbnYSHwoLZmxhZ2'
    'dlZF9lbnYYCyADKAlSCmZsYWdnZWRFbnYSEAoDdXJsGAwgASgJUgN1cmwSEgoEcG9ydBgNIAEo'
    'BVIEcG9ydBIWCgZhdHRhY2gYDiABKAhSBmF0dGFjaBIYCgdwcm9ibGVtGA8gASgJUgdwcm9ibG'
    'VtEi4KBXN0YXRlGBAgASgOMhgubnVzaGkudjEuRGV2U2VydmVyU3RhdGVSBXN0YXRlEhQKBWVy'
    'cm9yGBEgASgJUgVlcnJvchIWCgZvdXRwdXQYEiABKAlSBm91dHB1dBIbCglzZXJ2ZXJfaWQYEy'
    'ABKAlSCHNlcnZlcklkEhgKB2NoYW5nZWQYFCABKAhSB2NoYW5nZWQSEgoEaGFzaBgVIAEoCVIE'
    'aGFzaBIVCgZsb2dfaWQYFiABKAlSBWxvZ0lkGjYKCEVudkVudHJ5EhAKA2tleRgBIAEoCVIDa2'
    'V5EhQKBXZhbHVlGAIgASgJUgV2YWx1ZToCOAE=');

@$core.Deprecated('Use startServerRequestDescriptor instead')
const StartServerRequest$json = {
  '1': 'StartServerRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name'},
    {'1': 'index', '3': 3, '4': 1, '5': 5, '9': 0, '10': 'index'},
    {'1': 'hash', '3': 4, '4': 1, '5': 9, '10': 'hash'},
  ],
  '8': [
    {'1': 'entry'},
  ],
};

/// Descriptor for `StartServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startServerRequestDescriptor = $convert.base64Decode(
    'ChJTdGFydFNlcnZlclJlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElkEhQKBG5hbWUYAi'
    'ABKAlIAFIEbmFtZRIWCgVpbmRleBgDIAEoBUgAUgVpbmRleBISCgRoYXNoGAQgASgJUgRoYXNo'
    'QgcKBWVudHJ5');

@$core.Deprecated('Use startServerResponseDescriptor instead')
const StartServerResponse$json = {
  '1': 'StartServerResponse',
  '2': [
    {
      '1': 'server',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.DevServer',
      '10': 'server'
    },
  ],
};

/// Descriptor for `StartServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startServerResponseDescriptor = $convert.base64Decode(
    'ChNTdGFydFNlcnZlclJlc3BvbnNlEisKBnNlcnZlchgBIAEoCzITLm51c2hpLnYxLkRldlNlcn'
    'ZlclIGc2VydmVy');

@$core.Deprecated('Use stopServerRequestDescriptor instead')
const StopServerRequest$json = {
  '1': 'StopServerRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'server_id', '3': 2, '4': 1, '5': 9, '10': 'serverId'},
  ],
};

/// Descriptor for `StopServerRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopServerRequestDescriptor = $convert.base64Decode(
    'ChFTdG9wU2VydmVyUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSGwoJc2VydmVyX2'
    'lkGAIgASgJUghzZXJ2ZXJJZA==');

@$core.Deprecated('Use stopServerResponseDescriptor instead')
const StopServerResponse$json = {
  '1': 'StopServerResponse',
};

/// Descriptor for `StopServerResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopServerResponseDescriptor =
    $convert.base64Decode('ChJTdG9wU2VydmVyUmVzcG9uc2U=');

@$core.Deprecated('Use stopAllServersRequestDescriptor instead')
const StopAllServersRequest$json = {
  '1': 'StopAllServersRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `StopAllServersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopAllServersRequestDescriptor =
    $convert.base64Decode(
        'ChVTdG9wQWxsU2VydmVyc1JlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElk');

@$core.Deprecated('Use stopAllServersResponseDescriptor instead')
const StopAllServersResponse$json = {
  '1': 'StopAllServersResponse',
};

/// Descriptor for `StopAllServersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List stopAllServersResponseDescriptor =
    $convert.base64Decode('ChZTdG9wQWxsU2VydmVyc1Jlc3BvbnNl');

@$core.Deprecated('Use watchServerLogRequestDescriptor instead')
const WatchServerLogRequest$json = {
  '1': 'WatchServerLogRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'server_id', '3': 2, '4': 1, '5': 9, '10': 'serverId'},
  ],
};

/// Descriptor for `WatchServerLogRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchServerLogRequestDescriptor = $convert.base64Decode(
    'ChVXYXRjaFNlcnZlckxvZ1JlcXVlc3QSFwoHY2hhdF9pZBgBIAEoCVIGY2hhdElkEhsKCXNlcn'
    'Zlcl9pZBgCIAEoCVIIc2VydmVySWQ=');

@$core.Deprecated('Use watchServerLogResponseDescriptor instead')
const WatchServerLogResponse$json = {
  '1': 'WatchServerLogResponse',
  '2': [
    {'1': 'data', '3': 1, '4': 1, '5': 12, '10': 'data'},
    {'1': 'ended', '3': 2, '4': 1, '5': 8, '10': 'ended'},
  ],
};

/// Descriptor for `WatchServerLogResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List watchServerLogResponseDescriptor =
    $convert.base64Decode(
        'ChZXYXRjaFNlcnZlckxvZ1Jlc3BvbnNlEhIKBGRhdGEYASABKAxSBGRhdGESFAoFZW5kZWQYAi'
        'ABKAhSBWVuZGVk');

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
    {'1': 'id', '3': 9, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `Remote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List remoteDescriptor = $convert.base64Decode(
    'CgZSZW1vdGUSDgoCb24YASABKAhSAm9uEhQKBXJlbGF5GAIgASgJUgVyZWxheRIUCgVzdGF0ZR'
    'gDIAEoCVIFc3RhdGUSFAoFZXJyb3IYBCABKAlSBWVycm9yEioKB2RldmljZXMYBSADKAsyEC5u'
    'dXNoaS52MS5EZXZpY2VSB2RldmljZXMSKwoHcGFpcmluZxgGIAEoCzIRLm51c2hpLnYxLlBhaX'
    'JpbmdSB3BhaXJpbmcSHgoKcmVuZGV6dm91cxgHIAEoCVIKcmVuZGV6dm91cxIQCgNrZXkYCCAB'
    'KAxSA2tleRIOCgJpZBgJIAEoCVICaWQ=');

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
    {
      '1': 'fields',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.JiraField',
      '10': 'fields'
    },
  ],
  '9': [
    {'1': 4, '2': 5},
  ],
  '10': ['to_category'],
};

/// Descriptor for `JiraTransition`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List jiraTransitionDescriptor = $convert.base64Decode(
    'Cg5KaXJhVHJhbnNpdGlvbhIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIOCg'
    'J0bxgDIAEoCVICdG8SKwoGZmllbGRzGAUgAygLMhMubnVzaGkudjEuSmlyYUZpZWxkUgZmaWVs'
    'ZHNKBAgEEAVSC3RvX2NhdGVnb3J5');

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
    {'1': 'additions', '3': 14, '4': 1, '5': 5, '10': 'additions'},
    {'1': 'deletions', '3': 15, '4': 1, '5': 5, '10': 'deletions'},
    {'1': 'changed_files', '3': 16, '4': 1, '5': 5, '10': 'changedFiles'},
    {'1': 'created_ms', '3': 17, '4': 1, '5': 3, '10': 'createdMs'},
    {
      '1': 'check_counts',
      '3': 18,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubCheckCounts',
      '10': 'checkCounts'
    },
    {'1': 'merge_state', '3': 19, '4': 1, '5': 9, '10': 'mergeState'},
    {'1': 'state_reason', '3': 20, '4': 1, '5': 9, '10': 'stateReason'},
    {'1': 'base', '3': 21, '4': 1, '5': 9, '10': 'base'},
    {'1': 'head', '3': 22, '4': 1, '5': 9, '10': 'head'},
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
    'cxIcCglhZGRpdGlvbnMYDiABKAVSCWFkZGl0aW9ucxIcCglkZWxldGlvbnMYDyABKAVSCWRlbG'
    'V0aW9ucxIjCg1jaGFuZ2VkX2ZpbGVzGBAgASgFUgxjaGFuZ2VkRmlsZXMSHQoKY3JlYXRlZF9t'
    'cxgRIAEoA1IJY3JlYXRlZE1zEj4KDGNoZWNrX2NvdW50cxgSIAEoCzIbLm51c2hpLnYxLkdpdE'
    'h1YkNoZWNrQ291bnRzUgtjaGVja0NvdW50cxIfCgttZXJnZV9zdGF0ZRgTIAEoCVIKbWVyZ2VT'
    'dGF0ZRIhCgxzdGF0ZV9yZWFzb24YFCABKAlSC3N0YXRlUmVhc29uEhIKBGJhc2UYFSABKAlSBG'
    'Jhc2USEgoEaGVhZBgWIAEoCVIEaGVhZA==');

@$core.Deprecated('Use gitHubCheckCountsDescriptor instead')
const GitHubCheckCounts$json = {
  '1': 'GitHubCheckCounts',
  '2': [
    {'1': 'passed', '3': 1, '4': 1, '5': 5, '10': 'passed'},
    {'1': 'failed', '3': 2, '4': 1, '5': 5, '10': 'failed'},
    {'1': 'running', '3': 3, '4': 1, '5': 5, '10': 'running'},
    {'1': 'skipped', '3': 4, '4': 1, '5': 5, '10': 'skipped'},
  ],
};

/// Descriptor for `GitHubCheckCounts`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubCheckCountsDescriptor = $convert.base64Decode(
    'ChFHaXRIdWJDaGVja0NvdW50cxIWCgZwYXNzZWQYASABKAVSBnBhc3NlZBIWCgZmYWlsZWQYAi'
    'ABKAVSBmZhaWxlZBIYCgdydW5uaW5nGAMgASgFUgdydW5uaW5nEhgKB3NraXBwZWQYBCABKAVS'
    'B3NraXBwZWQ=');

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

@$core.Deprecated('Use findChatPullRequestDescriptor instead')
const FindChatPullRequest$json = {
  '1': 'FindChatPullRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'quiet', '3': 2, '4': 1, '5': 8, '10': 'quiet'},
  ],
};

/// Descriptor for `FindChatPullRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findChatPullRequestDescriptor = $convert.base64Decode(
    'ChNGaW5kQ2hhdFB1bGxSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIUCgVxdWlldB'
    'gCIAEoCFIFcXVpZXQ=');

@$core.Deprecated('Use findChatPullResponseDescriptor instead')
const FindChatPullResponse$json = {
  '1': 'FindChatPullResponse',
  '2': [
    {'1': 'host', '3': 1, '4': 1, '5': 9, '10': 'host'},
    {'1': 'repo', '3': 2, '4': 1, '5': 9, '10': 'repo'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'default_branch', '3': 4, '4': 1, '5': 8, '10': 'defaultBranch'},
    {
      '1': 'pull',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'pull'
    },
    {'1': 'error', '3': 6, '4': 1, '5': 9, '10': 'error'},
    {
      '1': 'pulls',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'pulls'
    },
  ],
};

/// Descriptor for `FindChatPullResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findChatPullResponseDescriptor = $convert.base64Decode(
    'ChRGaW5kQ2hhdFB1bGxSZXNwb25zZRISCgRob3N0GAEgASgJUgRob3N0EhIKBHJlcG8YAiABKA'
    'lSBHJlcG8SFgoGYnJhbmNoGAMgASgJUgZicmFuY2gSJQoOZGVmYXVsdF9icmFuY2gYBCABKAhS'
    'DWRlZmF1bHRCcmFuY2gSKAoEcHVsbBgFIAEoCzIULm51c2hpLnYxLkdpdEh1YkxpbmtSBHB1bG'
    'wSFAoFZXJyb3IYBiABKAlSBWVycm9yEioKBXB1bGxzGAcgAygLMhQubnVzaGkudjEuR2l0SHVi'
    'TGlua1IFcHVsbHM=');

@$core.Deprecated('Use linkChatPullRequestDescriptor instead')
const LinkChatPullRequest$json = {
  '1': 'LinkChatPullRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {
      '1': 'pull',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'pull'
    },
    {'1': 'add', '3': 3, '4': 1, '5': 8, '10': 'add'},
    {
      '1': 'unlink',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubLink',
      '10': 'unlink'
    },
  ],
};

/// Descriptor for `LinkChatPullRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkChatPullRequestDescriptor = $convert.base64Decode(
    'ChNMaW5rQ2hhdFB1bGxSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIoCgRwdWxsGA'
    'IgASgLMhQubnVzaGkudjEuR2l0SHViTGlua1IEcHVsbBIQCgNhZGQYAyABKAhSA2FkZBIsCgZ1'
    'bmxpbmsYBCABKAsyFC5udXNoaS52MS5HaXRIdWJMaW5rUgZ1bmxpbms=');

@$core.Deprecated('Use linkChatPullResponseDescriptor instead')
const LinkChatPullResponse$json = {
  '1': 'LinkChatPullResponse',
};

/// Descriptor for `LinkChatPullResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List linkChatPullResponseDescriptor =
    $convert.base64Decode('ChRMaW5rQ2hhdFB1bGxSZXNwb25zZQ==');

@$core.Deprecated('Use getGitHubItemsRequestDescriptor instead')
const GetGitHubItemsRequest$json = {
  '1': 'GetGitHubItemsRequest',
  '2': [
    {
      '1': 'refs',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'refs'
    },
    {'1': 'quiet', '3': 2, '4': 1, '5': 8, '10': 'quiet'},
  ],
};

/// Descriptor for `GetGitHubItemsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubItemsRequestDescriptor = $convert.base64Decode(
    'ChVHZXRHaXRIdWJJdGVtc1JlcXVlc3QSJwoEcmVmcxgBIAMoCzITLm51c2hpLnYxLkdpdEh1Yl'
    'JlZlIEcmVmcxIUCgVxdWlldBgCIAEoCFIFcXVpZXQ=');

@$core.Deprecated('Use getGitHubItemsResponseDescriptor instead')
const GetGitHubItemsResponse$json = {
  '1': 'GetGitHubItemsResponse',
  '2': [
    {
      '1': 'items',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubItem',
      '10': 'items'
    },
    {
      '1': 'unseen',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'unseen'
    },
    {'1': 'error', '3': 3, '4': 1, '5': 9, '10': 'error'},
    {'1': 'sign_in', '3': 4, '4': 1, '5': 8, '10': 'signIn'},
  ],
};

/// Descriptor for `GetGitHubItemsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubItemsResponseDescriptor = $convert.base64Decode(
    'ChZHZXRHaXRIdWJJdGVtc1Jlc3BvbnNlEioKBWl0ZW1zGAEgAygLMhQubnVzaGkudjEuR2l0SH'
    'ViSXRlbVIFaXRlbXMSKwoGdW5zZWVuGAIgAygLMhMubnVzaGkudjEuR2l0SHViUmVmUgZ1bnNl'
    'ZW4SFAoFZXJyb3IYAyABKAlSBWVycm9yEhcKB3NpZ25faW4YBCABKAhSBnNpZ25Jbg==');

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
    {'1': 'outside', '3': 4, '4': 1, '5': 8, '10': 'outside'},
    {'1': 'bot', '3': 5, '4': 1, '5': 8, '10': 'bot'},
    {'1': 'body', '3': 6, '4': 1, '5': 9, '10': 'body'},
    {'1': 'url', '3': 7, '4': 1, '5': 9, '10': 'url'},
    {'1': 'created_ms', '3': 8, '4': 1, '5': 3, '10': 'createdMs'},
    {'1': 'review', '3': 9, '4': 1, '5': 9, '10': 'review'},
    {'1': 'commit', '3': 10, '4': 1, '5': 9, '10': 'commit'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['association'],
};

/// Descriptor for `GitHubComment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubCommentDescriptor = $convert.base64Decode(
    'Cg1HaXRIdWJDb21tZW50Eg4KAmlkGAEgASgJUgJpZBIWCgZhdXRob3IYAiABKAlSBmF1dGhvch'
    'IYCgdvdXRzaWRlGAQgASgIUgdvdXRzaWRlEhAKA2JvdBgFIAEoCFIDYm90EhIKBGJvZHkYBiAB'
    'KAlSBGJvZHkSEAoDdXJsGAcgASgJUgN1cmwSHQoKY3JlYXRlZF9tcxgIIAEoA1IJY3JlYXRlZE'
    '1zEhYKBnJldmlldxgJIAEoCVIGcmV2aWV3EhYKBmNvbW1pdBgKIAEoCVIGY29tbWl0SgQIAxAE'
    'Ugthc3NvY2lhdGlvbg==');

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
  ],
  '9': [
    {'1': 6, '2': 7},
  ],
  '10': ['end_line'],
};

/// Descriptor for `GitHubAnnotation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubAnnotationDescriptor = $convert.base64Decode(
    'ChBHaXRIdWJBbm5vdGF0aW9uEhIKBHBhdGgYASABKAlSBHBhdGgSFAoFbGV2ZWwYAiABKAlSBW'
    'xldmVsEhQKBXRpdGxlGAMgASgJUgV0aXRsZRIYCgdtZXNzYWdlGAQgASgJUgdtZXNzYWdlEhIK'
    'BGxpbmUYBSABKAVSBGxpbmVKBAgGEAdSCGVuZF9saW5l');

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
    {'1': 'code_owner', '3': 4, '4': 1, '5': 8, '10': 'codeOwner'},
  ],
};

/// Descriptor for `GitHubReviewer`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubReviewerDescriptor = $convert.base64Decode(
    'Cg5HaXRIdWJSZXZpZXdlchIUCgVsb2dpbhgBIAEoCVIFbG9naW4SFAoFc3RhdGUYAiABKAlSBX'
    'N0YXRlEhIKBHRlYW0YAyABKAhSBHRlYW0SHQoKY29kZV9vd25lchgEIAEoCFIJY29kZU93bmVy');

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
    {'1': 'commits', '3': 22, '4': 1, '5': 5, '10': 'commits'},
    {
      '1': 'merge',
      '3': 23,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubMerge',
      '10': 'merge'
    },
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['association'],
};

/// Descriptor for `GitHubPull`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubPullDescriptor = $convert.base64Decode(
    'CgpHaXRIdWJQdWxsEigKBGl0ZW0YASABKAsyFC5udXNoaS52MS5HaXRIdWJJdGVtUgRpdGVtEh'
    'IKBGJvZHkYAiABKAlSBGJvZHkSGAoHb3V0c2lkZRgEIAEoCFIHb3V0c2lkZRISCgRiYXNlGAUg'
    'ASgJUgRiYXNlEhIKBGhlYWQYBiABKAlSBGhlYWQSGwoJaGVhZF9yZXBvGAcgASgJUghoZWFkUm'
    'VwbxIdCgpjcm9zc19yZXBvGAggASgIUgljcm9zc1JlcG8SGQoIYmFzZV9vaWQYCSABKAlSB2Jh'
    'c2VPaWQSGQoIaGVhZF9vaWQYCiABKAlSB2hlYWRPaWQSHAoJbWVyZ2VhYmxlGAsgASgJUgltZX'
    'JnZWFibGUSHwoLbWVyZ2Vfc3RhdGUYDCABKAlSCm1lcmdlU3RhdGUSHAoJYWRkaXRpb25zGA0g'
    'ASgFUglhZGRpdGlvbnMSHAoJZGVsZXRpb25zGA4gASgFUglkZWxldGlvbnMSIwoNY2hhbmdlZF'
    '9maWxlcxgPIAEoBVIMY2hhbmdlZEZpbGVzEjYKCXJldmlld2VycxgQIAMoCzIYLm51c2hpLnYx'
    'LkdpdEh1YlJldmlld2VyUglyZXZpZXdlcnMSOwoMY29udmVyc2F0aW9uGBEgAygLMhcubnVzaG'
    'kudjEuR2l0SHViQ29tbWVudFIMY29udmVyc2F0aW9uEjAKB3RocmVhZHMYEiADKAsyFi5udXNo'
    'aS52MS5HaXRIdWJUaHJlYWRSB3RocmVhZHMSLQoGY2hlY2tzGBMgAygLMhUubnVzaGkudjEuR2'
    'l0SHViQ2hlY2tSBmNoZWNrcxIlCg5wZW5kaW5nX3JldmlldxgUIAEoCVINcGVuZGluZ1Jldmll'
    'dxIpChBwZW5kaW5nX2NvbW1lbnRzGBUgASgFUg9wZW5kaW5nQ29tbWVudHMSGAoHY29tbWl0cx'
    'gWIAEoBVIHY29tbWl0cxIrCgVtZXJnZRgXIAEoCzIVLm51c2hpLnYxLkdpdEh1Yk1lcmdlUgVt'
    'ZXJnZUoECAMQBFILYXNzb2NpYXRpb24=');

@$core.Deprecated('Use gitHubMergeDescriptor instead')
const GitHubMerge$json = {
  '1': 'GitHubMerge',
  '2': [
    {'1': 'methods', '3': 1, '4': 3, '5': 9, '10': 'methods'},
    {'1': 'default_method', '3': 2, '4': 1, '5': 9, '10': 'defaultMethod'},
    {'1': 'can_merge', '3': 3, '4': 1, '5': 8, '10': 'canMerge'},
    {'1': 'can_rebase', '3': 4, '4': 1, '5': 8, '10': 'canRebase'},
    {'1': 'blocks', '3': 5, '4': 3, '5': 9, '10': 'blocks'},
    {'1': 'auto_allowed', '3': 6, '4': 1, '5': 8, '10': 'autoAllowed'},
    {'1': 'can_enable_auto', '3': 7, '4': 1, '5': 8, '10': 'canEnableAuto'},
    {'1': 'can_disable_auto', '3': 8, '4': 1, '5': 8, '10': 'canDisableAuto'},
    {
      '1': 'auto',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubAutoMerge',
      '10': 'auto'
    },
    {'1': 'queue', '3': 10, '4': 1, '5': 8, '10': 'queue'},
    {'1': 'queue_method', '3': 11, '4': 1, '5': 9, '10': 'queueMethod'},
    {
      '1': 'entry',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubQueueEntry',
      '10': 'entry'
    },
    {'1': 'delete_branch', '3': 13, '4': 1, '5': 8, '10': 'deleteBranch'},
  ],
};

/// Descriptor for `GitHubMerge`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubMergeDescriptor = $convert.base64Decode(
    'CgtHaXRIdWJNZXJnZRIYCgdtZXRob2RzGAEgAygJUgdtZXRob2RzEiUKDmRlZmF1bHRfbWV0aG'
    '9kGAIgASgJUg1kZWZhdWx0TWV0aG9kEhsKCWNhbl9tZXJnZRgDIAEoCFIIY2FuTWVyZ2USHQoK'
    'Y2FuX3JlYmFzZRgEIAEoCFIJY2FuUmViYXNlEhYKBmJsb2NrcxgFIAMoCVIGYmxvY2tzEiEKDG'
    'F1dG9fYWxsb3dlZBgGIAEoCFILYXV0b0FsbG93ZWQSJgoPY2FuX2VuYWJsZV9hdXRvGAcgASgI'
    'Ug1jYW5FbmFibGVBdXRvEigKEGNhbl9kaXNhYmxlX2F1dG8YCCABKAhSDmNhbkRpc2FibGVBdX'
    'RvEi0KBGF1dG8YCSABKAsyGS5udXNoaS52MS5HaXRIdWJBdXRvTWVyZ2VSBGF1dG8SFAoFcXVl'
    'dWUYCiABKAhSBXF1ZXVlEiEKDHF1ZXVlX21ldGhvZBgLIAEoCVILcXVldWVNZXRob2QSMAoFZW'
    '50cnkYDCABKAsyGi5udXNoaS52MS5HaXRIdWJRdWV1ZUVudHJ5UgVlbnRyeRIjCg1kZWxldGVf'
    'YnJhbmNoGA0gASgIUgxkZWxldGVCcmFuY2g=');

@$core.Deprecated('Use gitHubAutoMergeDescriptor instead')
const GitHubAutoMerge$json = {
  '1': 'GitHubAutoMerge',
  '2': [
    {'1': 'by', '3': 1, '4': 1, '5': 9, '10': 'by'},
    {'1': 'method', '3': 2, '4': 1, '5': 9, '10': 'method'},
  ],
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['enabled_ms'],
};

/// Descriptor for `GitHubAutoMerge`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubAutoMergeDescriptor = $convert.base64Decode(
    'Cg9HaXRIdWJBdXRvTWVyZ2USDgoCYnkYASABKAlSAmJ5EhYKBm1ldGhvZBgCIAEoCVIGbWV0aG'
    '9kSgQIAxAEUgplbmFibGVkX21z');

@$core.Deprecated('Use gitHubQueueEntryDescriptor instead')
const GitHubQueueEntry$json = {
  '1': 'GitHubQueueEntry',
  '2': [
    {'1': 'position', '3': 1, '4': 1, '5': 5, '10': 'position'},
    {'1': 'state', '3': 2, '4': 1, '5': 9, '10': 'state'},
    {'1': 'by', '3': 3, '4': 1, '5': 9, '10': 'by'},
    {'1': 'eta_seconds', '3': 4, '4': 1, '5': 5, '10': 'etaSeconds'},
  ],
};

/// Descriptor for `GitHubQueueEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubQueueEntryDescriptor = $convert.base64Decode(
    'ChBHaXRIdWJRdWV1ZUVudHJ5EhoKCHBvc2l0aW9uGAEgASgFUghwb3NpdGlvbhIUCgVzdGF0ZR'
    'gCIAEoCVIFc3RhdGUSDgoCYnkYAyABKAlSAmJ5Eh8KC2V0YV9zZWNvbmRzGAQgASgFUgpldGFT'
    'ZWNvbmRz');

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
  '9': [
    {'1': 3, '2': 4},
  ],
  '10': ['association'],
};

/// Descriptor for `GitHubIssue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List gitHubIssueDescriptor = $convert.base64Decode(
    'CgtHaXRIdWJJc3N1ZRIoCgRpdGVtGAEgASgLMhQubnVzaGkudjEuR2l0SHViSXRlbVIEaXRlbR'
    'ISCgRib2R5GAIgASgJUgRib2R5EhgKB291dHNpZGUYBCABKAhSB291dHNpZGUSFgoGbGFiZWxz'
    'GAUgAygJUgZsYWJlbHMSHAoJYXNzaWduZWVzGAYgAygJUglhc3NpZ25lZXMSOwoMY29udmVyc2'
    'F0aW9uGAcgAygLMhcubnVzaGkudjEuR2l0SHViQ29tbWVudFIMY29udmVyc2F0aW9uSgQIAxAE'
    'Ugthc3NvY2lhdGlvbg==');

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

@$core.Deprecated('Use rerunGitHubChecksRequestDescriptor instead')
const RerunGitHubChecksRequest$json = {
  '1': 'RerunGitHubChecksRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'jobs', '3': 2, '4': 3, '5': 3, '10': 'jobs'},
  ],
};

/// Descriptor for `RerunGitHubChecksRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rerunGitHubChecksRequestDescriptor =
    $convert.base64Decode(
        'ChhSZXJ1bkdpdEh1YkNoZWNrc1JlcXVlc3QSJQoDcmVmGAEgASgLMhMubnVzaGkudjEuR2l0SH'
        'ViUmVmUgNyZWYSEgoEam9icxgCIAMoA1IEam9icw==');

@$core.Deprecated('Use getGitHubMergeTextRequestDescriptor instead')
const GetGitHubMergeTextRequest$json = {
  '1': 'GetGitHubMergeTextRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
  ],
};

/// Descriptor for `GetGitHubMergeTextRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubMergeTextRequestDescriptor =
    $convert.base64Decode(
        'ChlHZXRHaXRIdWJNZXJnZVRleHRSZXF1ZXN0EiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLkdpdE'
        'h1YlJlZlIDcmVm');

@$core.Deprecated('Use getGitHubMergeTextResponseDescriptor instead')
const GetGitHubMergeTextResponse$json = {
  '1': 'GetGitHubMergeTextResponse',
  '2': [
    {'1': 'merge_title', '3': 1, '4': 1, '5': 9, '10': 'mergeTitle'},
    {'1': 'merge_body', '3': 2, '4': 1, '5': 9, '10': 'mergeBody'},
    {'1': 'squash_title', '3': 3, '4': 1, '5': 9, '10': 'squashTitle'},
    {'1': 'squash_body', '3': 4, '4': 1, '5': 9, '10': 'squashBody'},
  ],
};

/// Descriptor for `GetGitHubMergeTextResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGitHubMergeTextResponseDescriptor =
    $convert.base64Decode(
        'ChpHZXRHaXRIdWJNZXJnZVRleHRSZXNwb25zZRIfCgttZXJnZV90aXRsZRgBIAEoCVIKbWVyZ2'
        'VUaXRsZRIdCgptZXJnZV9ib2R5GAIgASgJUgltZXJnZUJvZHkSIQoMc3F1YXNoX3RpdGxlGAMg'
        'ASgJUgtzcXVhc2hUaXRsZRIfCgtzcXVhc2hfYm9keRgEIAEoCVIKc3F1YXNoQm9keQ==');

@$core.Deprecated('Use mergeGitHubPullRequestDescriptor instead')
const MergeGitHubPullRequest$json = {
  '1': 'MergeGitHubPullRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'head_oid', '3': 2, '4': 1, '5': 9, '10': 'headOid'},
    {'1': 'method', '3': 3, '4': 1, '5': 9, '10': 'method'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'body', '3': 5, '4': 1, '5': 9, '10': 'body'},
    {'1': 'base', '3': 6, '4': 1, '5': 9, '10': 'base'},
  ],
};

/// Descriptor for `MergeGitHubPullRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeGitHubPullRequestDescriptor = $convert.base64Decode(
    'ChZNZXJnZUdpdEh1YlB1bGxSZXF1ZXN0EiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLkdpdEh1Yl'
    'JlZlIDcmVmEhkKCGhlYWRfb2lkGAIgASgJUgdoZWFkT2lkEhYKBm1ldGhvZBgDIAEoCVIGbWV0'
    'aG9kEhQKBXRpdGxlGAQgASgJUgV0aXRsZRISCgRib2R5GAUgASgJUgRib2R5EhIKBGJhc2UYBi'
    'ABKAlSBGJhc2U=');

@$core.Deprecated('Use mergeGitHubPullResponseDescriptor instead')
const MergeGitHubPullResponse$json = {
  '1': 'MergeGitHubPullResponse',
};

/// Descriptor for `MergeGitHubPullResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List mergeGitHubPullResponseDescriptor =
    $convert.base64Decode('ChdNZXJnZUdpdEh1YlB1bGxSZXNwb25zZQ==');

@$core.Deprecated('Use enableGitHubAutoMergeRequestDescriptor instead')
const EnableGitHubAutoMergeRequest$json = {
  '1': 'EnableGitHubAutoMergeRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'head_oid', '3': 2, '4': 1, '5': 9, '10': 'headOid'},
    {'1': 'method', '3': 3, '4': 1, '5': 9, '10': 'method'},
    {'1': 'title', '3': 4, '4': 1, '5': 9, '10': 'title'},
    {'1': 'body', '3': 5, '4': 1, '5': 9, '10': 'body'},
    {'1': 'base', '3': 6, '4': 1, '5': 9, '10': 'base'},
  ],
};

/// Descriptor for `EnableGitHubAutoMergeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enableGitHubAutoMergeRequestDescriptor = $convert.base64Decode(
    'ChxFbmFibGVHaXRIdWJBdXRvTWVyZ2VSZXF1ZXN0EiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLk'
    'dpdEh1YlJlZlIDcmVmEhkKCGhlYWRfb2lkGAIgASgJUgdoZWFkT2lkEhYKBm1ldGhvZBgDIAEo'
    'CVIGbWV0aG9kEhQKBXRpdGxlGAQgASgJUgV0aXRsZRISCgRib2R5GAUgASgJUgRib2R5EhIKBG'
    'Jhc2UYBiABKAlSBGJhc2U=');

@$core.Deprecated('Use enableGitHubAutoMergeResponseDescriptor instead')
const EnableGitHubAutoMergeResponse$json = {
  '1': 'EnableGitHubAutoMergeResponse',
};

/// Descriptor for `EnableGitHubAutoMergeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enableGitHubAutoMergeResponseDescriptor =
    $convert.base64Decode('Ch1FbmFibGVHaXRIdWJBdXRvTWVyZ2VSZXNwb25zZQ==');

@$core.Deprecated('Use disableGitHubAutoMergeRequestDescriptor instead')
const DisableGitHubAutoMergeRequest$json = {
  '1': 'DisableGitHubAutoMergeRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
  ],
};

/// Descriptor for `DisableGitHubAutoMergeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List disableGitHubAutoMergeRequestDescriptor =
    $convert.base64Decode(
        'Ch1EaXNhYmxlR2l0SHViQXV0b01lcmdlUmVxdWVzdBIlCgNyZWYYASABKAsyEy5udXNoaS52MS'
        '5HaXRIdWJSZWZSA3JlZg==');

@$core.Deprecated('Use disableGitHubAutoMergeResponseDescriptor instead')
const DisableGitHubAutoMergeResponse$json = {
  '1': 'DisableGitHubAutoMergeResponse',
};

/// Descriptor for `DisableGitHubAutoMergeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List disableGitHubAutoMergeResponseDescriptor =
    $convert.base64Decode('Ch5EaXNhYmxlR2l0SHViQXV0b01lcmdlUmVzcG9uc2U=');

@$core.Deprecated('Use enqueueGitHubPullRequestDescriptor instead')
const EnqueueGitHubPullRequest$json = {
  '1': 'EnqueueGitHubPullRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
    {'1': 'head_oid', '3': 2, '4': 1, '5': 9, '10': 'headOid'},
    {'1': 'base', '3': 3, '4': 1, '5': 9, '10': 'base'},
  ],
};

/// Descriptor for `EnqueueGitHubPullRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enqueueGitHubPullRequestDescriptor = $convert.base64Decode(
    'ChhFbnF1ZXVlR2l0SHViUHVsbFJlcXVlc3QSJQoDcmVmGAEgASgLMhMubnVzaGkudjEuR2l0SH'
    'ViUmVmUgNyZWYSGQoIaGVhZF9vaWQYAiABKAlSB2hlYWRPaWQSEgoEYmFzZRgDIAEoCVIEYmFz'
    'ZQ==');

@$core.Deprecated('Use enqueueGitHubPullResponseDescriptor instead')
const EnqueueGitHubPullResponse$json = {
  '1': 'EnqueueGitHubPullResponse',
};

/// Descriptor for `EnqueueGitHubPullResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List enqueueGitHubPullResponseDescriptor =
    $convert.base64Decode('ChlFbnF1ZXVlR2l0SHViUHVsbFJlc3BvbnNl');

@$core.Deprecated('Use dequeueGitHubPullRequestDescriptor instead')
const DequeueGitHubPullRequest$json = {
  '1': 'DequeueGitHubPullRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
  ],
};

/// Descriptor for `DequeueGitHubPullRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dequeueGitHubPullRequestDescriptor =
    $convert.base64Decode(
        'ChhEZXF1ZXVlR2l0SHViUHVsbFJlcXVlc3QSJQoDcmVmGAEgASgLMhMubnVzaGkudjEuR2l0SH'
        'ViUmVmUgNyZWY=');

@$core.Deprecated('Use dequeueGitHubPullResponseDescriptor instead')
const DequeueGitHubPullResponse$json = {
  '1': 'DequeueGitHubPullResponse',
};

/// Descriptor for `DequeueGitHubPullResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dequeueGitHubPullResponseDescriptor =
    $convert.base64Decode('ChlEZXF1ZXVlR2l0SHViUHVsbFJlc3BvbnNl');

@$core.Deprecated('Use getCleanUpRequestDescriptor instead')
const GetCleanUpRequest$json = {
  '1': 'GetCleanUpRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
  ],
};

/// Descriptor for `GetCleanUpRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCleanUpRequestDescriptor = $convert.base64Decode(
    'ChFHZXRDbGVhblVwUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

@$core.Deprecated('Use getCleanUpResponseDescriptor instead')
const GetCleanUpResponse$json = {
  '1': 'GetCleanUpResponse',
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
    {'1': 'changes', '3': 3, '4': 3, '5': 9, '10': 'changes'},
    {'1': 'branch_elsewhere', '3': 4, '4': 1, '5': 8, '10': 'branchElsewhere'},
    {'1': 'others', '3': 5, '4': 3, '5': 9, '10': 'others'},
  ],
};

/// Descriptor for `GetCleanUpResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getCleanUpResponseDescriptor = $convert.base64Decode(
    'ChJHZXRDbGVhblVwUmVzcG9uc2USLgoId29ya3RyZWUYASABKAsyEi5udXNoaS52MS5Xb3JrdH'
    'JlZVIId29ya3RyZWUSLQoFc3RhdGUYAiABKAsyFy5udXNoaS52MS5Xb3JrdHJlZVN0YXRlUgVz'
    'dGF0ZRIYCgdjaGFuZ2VzGAMgAygJUgdjaGFuZ2VzEikKEGJyYW5jaF9lbHNld2hlcmUYBCABKA'
    'hSD2JyYW5jaEVsc2V3aGVyZRIWCgZvdGhlcnMYBSADKAlSBm90aGVycw==');

@$core.Deprecated('Use removeChatWorktreeRequestDescriptor instead')
const RemoveChatWorktreeRequest$json = {
  '1': 'RemoveChatWorktreeRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'force', '3': 2, '4': 1, '5': 8, '10': 'force'},
  ],
};

/// Descriptor for `RemoveChatWorktreeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeChatWorktreeRequestDescriptor =
    $convert.base64Decode(
        'ChlSZW1vdmVDaGF0V29ya3RyZWVSZXF1ZXN0EhcKB2NoYXRfaWQYASABKAlSBmNoYXRJZBIUCg'
        'Vmb3JjZRgCIAEoCFIFZm9yY2U=');

@$core.Deprecated('Use removeChatWorktreeResponseDescriptor instead')
const RemoveChatWorktreeResponse$json = {
  '1': 'RemoveChatWorktreeResponse',
};

/// Descriptor for `RemoveChatWorktreeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeChatWorktreeResponseDescriptor =
    $convert.base64Decode('ChpSZW1vdmVDaGF0V29ya3RyZWVSZXNwb25zZQ==');

@$core.Deprecated('Use deleteChatBranchRequestDescriptor instead')
const DeleteChatBranchRequest$json = {
  '1': 'DeleteChatBranchRequest',
  '2': [
    {'1': 'chat_id', '3': 1, '4': 1, '5': 9, '10': 'chatId'},
    {'1': 'force', '3': 2, '4': 1, '5': 8, '10': 'force'},
  ],
};

/// Descriptor for `DeleteChatBranchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteChatBranchRequestDescriptor =
    $convert.base64Decode(
        'ChdEZWxldGVDaGF0QnJhbmNoUmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSFAoFZm'
        '9yY2UYAiABKAhSBWZvcmNl');

@$core.Deprecated('Use deleteChatBranchResponseDescriptor instead')
const DeleteChatBranchResponse$json = {
  '1': 'DeleteChatBranchResponse',
};

/// Descriptor for `DeleteChatBranchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteChatBranchResponseDescriptor =
    $convert.base64Decode('ChhEZWxldGVDaGF0QnJhbmNoUmVzcG9uc2U=');

@$core.Deprecated('Use deleteGitHubBranchRequestDescriptor instead')
const DeleteGitHubBranchRequest$json = {
  '1': 'DeleteGitHubBranchRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
  ],
};

/// Descriptor for `DeleteGitHubBranchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteGitHubBranchRequestDescriptor =
    $convert.base64Decode(
        'ChlEZWxldGVHaXRIdWJCcmFuY2hSZXF1ZXN0EiUKA3JlZhgBIAEoCzITLm51c2hpLnYxLkdpdE'
        'h1YlJlZlIDcmVm');

@$core.Deprecated('Use deleteGitHubBranchResponseDescriptor instead')
const DeleteGitHubBranchResponse$json = {
  '1': 'DeleteGitHubBranchResponse',
  '2': [
    {'1': 'deleted', '3': 1, '4': 1, '5': 8, '10': 'deleted'},
  ],
};

/// Descriptor for `DeleteGitHubBranchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteGitHubBranchResponseDescriptor =
    $convert.base64Decode(
        'ChpEZWxldGVHaXRIdWJCcmFuY2hSZXNwb25zZRIYCgdkZWxldGVkGAEgASgIUgdkZWxldGVk');

@$core.Deprecated('Use restoreGitHubBranchRequestDescriptor instead')
const RestoreGitHubBranchRequest$json = {
  '1': 'RestoreGitHubBranchRequest',
  '2': [
    {
      '1': 'ref',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.nushi.v1.GitHubRef',
      '10': 'ref'
    },
  ],
};

/// Descriptor for `RestoreGitHubBranchRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreGitHubBranchRequestDescriptor =
    $convert.base64Decode(
        'ChpSZXN0b3JlR2l0SHViQnJhbmNoUmVxdWVzdBIlCgNyZWYYASABKAsyEy5udXNoaS52MS5HaX'
        'RIdWJSZWZSA3JlZg==');

@$core.Deprecated('Use restoreGitHubBranchResponseDescriptor instead')
const RestoreGitHubBranchResponse$json = {
  '1': 'RestoreGitHubBranchResponse',
};

/// Descriptor for `RestoreGitHubBranchResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreGitHubBranchResponseDescriptor =
    $convert.base64Decode('ChtSZXN0b3JlR2l0SHViQnJhbmNoUmVzcG9uc2U=');

@$core.Deprecated('Use rerunGitHubChecksResponseDescriptor instead')
const RerunGitHubChecksResponse$json = {
  '1': 'RerunGitHubChecksResponse',
  '2': [
    {'1': 'runs', '3': 1, '4': 1, '5': 5, '10': 'runs'},
  ],
};

/// Descriptor for `RerunGitHubChecksResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rerunGitHubChecksResponseDescriptor =
    $convert.base64Decode(
        'ChlSZXJ1bkdpdEh1YkNoZWNrc1Jlc3BvbnNlEhIKBHJ1bnMYASABKAVSBHJ1bnM=');

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
      '1': 'CheckForUpdates',
      '2': '.nushi.v1.CheckForUpdatesRequest',
      '3': '.nushi.v1.CheckForUpdatesResponse'
    },
    {
      '1': 'InstallUpdate',
      '2': '.nushi.v1.InstallUpdateRequest',
      '3': '.nushi.v1.InstallUpdateResponse'
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
      '1': 'GetChatImage',
      '2': '.nushi.v1.GetChatImageRequest',
      '3': '.nushi.v1.GetChatImageResponse'
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
      '1': 'SearchAgentSessions',
      '2': '.nushi.v1.SearchAgentSessionsRequest',
      '3': '.nushi.v1.SearchAgentSessionsResponse'
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
      '1': 'ForkAsChat',
      '2': '.nushi.v1.ForkAsChatRequest',
      '3': '.nushi.v1.ForkAsChatResponse'
    },
    {
      '1': 'KeepSideChat',
      '2': '.nushi.v1.KeepSideChatRequest',
      '3': '.nushi.v1.KeepSideChatResponse'
    },
    {
      '1': 'ArchiveSideChat',
      '2': '.nushi.v1.ArchiveSideChatRequest',
      '3': '.nushi.v1.ArchiveSideChatResponse'
    },
    {
      '1': 'RestoreSideChat',
      '2': '.nushi.v1.RestoreSideChatRequest',
      '3': '.nushi.v1.RestoreSideChatResponse'
    },
    {
      '1': 'RenameChat',
      '2': '.nushi.v1.RenameChatRequest',
      '3': '.nushi.v1.RenameChatResponse'
    },
    {
      '1': 'PinChats',
      '2': '.nushi.v1.PinChatsRequest',
      '3': '.nushi.v1.PinChatsResponse'
    },
    {
      '1': 'SetChatColor',
      '2': '.nushi.v1.SetChatColorRequest',
      '3': '.nushi.v1.SetChatColorResponse'
    },
    {
      '1': 'PinMessage',
      '2': '.nushi.v1.PinMessageRequest',
      '3': '.nushi.v1.PinMessageResponse'
    },
    {
      '1': 'RenameBranch',
      '2': '.nushi.v1.RenameBranchRequest',
      '3': '.nushi.v1.RenameBranchResponse'
    },
    {
      '1': 'SwitchBranch',
      '2': '.nushi.v1.SwitchBranchRequest',
      '3': '.nushi.v1.SwitchBranchResponse'
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
      '1': 'StageFiles',
      '2': '.nushi.v1.StageFilesRequest',
      '3': '.nushi.v1.StageFilesResponse'
    },
    {
      '1': 'WriteCommitMessage',
      '2': '.nushi.v1.WriteCommitMessageRequest',
      '3': '.nushi.v1.WriteCommitMessageResponse'
    },
    {
      '1': 'CommitStaged',
      '2': '.nushi.v1.CommitStagedRequest',
      '3': '.nushi.v1.CommitStagedResponse'
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
      '1': 'FindChatFiles',
      '2': '.nushi.v1.FindChatFilesRequest',
      '3': '.nushi.v1.FindChatFilesResponse'
    },
    {
      '1': 'WriteChatFile',
      '2': '.nushi.v1.WriteChatFileRequest',
      '3': '.nushi.v1.WriteChatFileResponse'
    },
    {
      '1': 'WatchChatFolder',
      '2': '.nushi.v1.WatchChatFolderRequest',
      '3': '.nushi.v1.WatchChatFolderResponse',
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
      '1': 'GetProjectIcon',
      '2': '.nushi.v1.GetProjectIconRequest',
      '3': '.nushi.v1.GetProjectIconResponse'
    },
    {
      '1': 'GetRelatedWorktrees',
      '2': '.nushi.v1.GetRelatedWorktreesRequest',
      '3': '.nushi.v1.GetRelatedWorktreesResponse'
    },
    {
      '1': 'GetRelatedWorktreeStats',
      '2': '.nushi.v1.GetRelatedWorktreeStatsRequest',
      '3': '.nushi.v1.GetRelatedWorktreeStatsResponse'
    },
    {
      '1': 'ListBranches',
      '2': '.nushi.v1.ListBranchesRequest',
      '3': '.nushi.v1.ListBranchesResponse'
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
      '1': 'ListServers',
      '2': '.nushi.v1.ListServersRequest',
      '3': '.nushi.v1.ListServersResponse'
    },
    {
      '1': 'StartServer',
      '2': '.nushi.v1.StartServerRequest',
      '3': '.nushi.v1.StartServerResponse'
    },
    {
      '1': 'StopServer',
      '2': '.nushi.v1.StopServerRequest',
      '3': '.nushi.v1.StopServerResponse'
    },
    {
      '1': 'StopAllServers',
      '2': '.nushi.v1.StopAllServersRequest',
      '3': '.nushi.v1.StopAllServersResponse'
    },
    {
      '1': 'WatchServerLog',
      '2': '.nushi.v1.WatchServerLogRequest',
      '3': '.nushi.v1.WatchServerLogResponse',
      '6': true
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
      '1': 'GetGitHubItems',
      '2': '.nushi.v1.GetGitHubItemsRequest',
      '3': '.nushi.v1.GetGitHubItemsResponse'
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
      '1': 'RerunGitHubChecks',
      '2': '.nushi.v1.RerunGitHubChecksRequest',
      '3': '.nushi.v1.RerunGitHubChecksResponse'
    },
    {
      '1': 'GetGitHubMergeText',
      '2': '.nushi.v1.GetGitHubMergeTextRequest',
      '3': '.nushi.v1.GetGitHubMergeTextResponse'
    },
    {
      '1': 'MergeGitHubPull',
      '2': '.nushi.v1.MergeGitHubPullRequest',
      '3': '.nushi.v1.MergeGitHubPullResponse'
    },
    {
      '1': 'EnableGitHubAutoMerge',
      '2': '.nushi.v1.EnableGitHubAutoMergeRequest',
      '3': '.nushi.v1.EnableGitHubAutoMergeResponse'
    },
    {
      '1': 'DisableGitHubAutoMerge',
      '2': '.nushi.v1.DisableGitHubAutoMergeRequest',
      '3': '.nushi.v1.DisableGitHubAutoMergeResponse'
    },
    {
      '1': 'EnqueueGitHubPull',
      '2': '.nushi.v1.EnqueueGitHubPullRequest',
      '3': '.nushi.v1.EnqueueGitHubPullResponse'
    },
    {
      '1': 'DequeueGitHubPull',
      '2': '.nushi.v1.DequeueGitHubPullRequest',
      '3': '.nushi.v1.DequeueGitHubPullResponse'
    },
    {
      '1': 'GetCleanUp',
      '2': '.nushi.v1.GetCleanUpRequest',
      '3': '.nushi.v1.GetCleanUpResponse'
    },
    {
      '1': 'RemoveChatWorktree',
      '2': '.nushi.v1.RemoveChatWorktreeRequest',
      '3': '.nushi.v1.RemoveChatWorktreeResponse'
    },
    {
      '1': 'DeleteChatBranch',
      '2': '.nushi.v1.DeleteChatBranchRequest',
      '3': '.nushi.v1.DeleteChatBranchResponse'
    },
    {
      '1': 'DeleteGitHubBranch',
      '2': '.nushi.v1.DeleteGitHubBranchRequest',
      '3': '.nushi.v1.DeleteGitHubBranchResponse'
    },
    {
      '1': 'RestoreGitHubBranch',
      '2': '.nushi.v1.RestoreGitHubBranchRequest',
      '3': '.nushi.v1.RestoreGitHubBranchResponse'
    },
    {
      '1': 'FindChatPull',
      '2': '.nushi.v1.FindChatPullRequest',
      '3': '.nushi.v1.FindChatPullResponse'
    },
    {
      '1': 'LinkChatPull',
      '2': '.nushi.v1.LinkChatPullRequest',
      '3': '.nushi.v1.LinkChatPullResponse'
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
  '.nushi.v1.UpdateCheck': UpdateCheck$json,
  '.nushi.v1.RestartWhenIdleRequest': RestartWhenIdleRequest$json,
  '.nushi.v1.RestartWhenIdleResponse': RestartWhenIdleResponse$json,
  '.nushi.v1.RestartHold': RestartHold$json,
  '.nushi.v1.CheckForUpdatesRequest': CheckForUpdatesRequest$json,
  '.nushi.v1.CheckForUpdatesResponse': CheckForUpdatesResponse$json,
  '.nushi.v1.InstallUpdateRequest': InstallUpdateRequest$json,
  '.nushi.v1.InstallUpdateResponse': InstallUpdateResponse$json,
  '.nushi.v1.ListChatsRequest': ListChatsRequest$json,
  '.nushi.v1.ListChatsResponse': ListChatsResponse$json,
  '.nushi.v1.Chat': Chat$json,
  '.nushi.v1.ChatStatus': ChatStatus$json,
  '.nushi.v1.Worktree': Worktree$json,
  '.nushi.v1.GitHubLink': GitHubLink$json,
  '.nushi.v1.MessagePin': MessagePin$json,
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
  '.nushi.v1.BackgroundCommand': BackgroundCommand$json,
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
  '.nushi.v1.GetChatImageRequest': GetChatImageRequest$json,
  '.nushi.v1.GetChatImageResponse': GetChatImageResponse$json,
  '.nushi.v1.StartChatRequest': StartChatRequest$json,
  '.nushi.v1.StartChatResponse': StartChatResponse$json,
  '.nushi.v1.FolderRun': FolderRun$json,
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
  '.nushi.v1.SearchAgentSessionsRequest': SearchAgentSessionsRequest$json,
  '.nushi.v1.SearchAgentSessionsResponse': SearchAgentSessionsResponse$json,
  '.nushi.v1.SessionHit': SessionHit$json,
  '.nushi.v1.MoveChatRequest': MoveChatRequest$json,
  '.nushi.v1.MoveChatResponse': MoveChatResponse$json,
  '.nushi.v1.SendPromptRequest': SendPromptRequest$json,
  '.nushi.v1.FileUpload': FileUpload$json,
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
  '.nushi.v1.ForkAsChatRequest': ForkAsChatRequest$json,
  '.nushi.v1.ForkAsChatResponse': ForkAsChatResponse$json,
  '.nushi.v1.KeepSideChatRequest': KeepSideChatRequest$json,
  '.nushi.v1.KeepSideChatResponse': KeepSideChatResponse$json,
  '.nushi.v1.ArchiveSideChatRequest': ArchiveSideChatRequest$json,
  '.nushi.v1.ArchiveSideChatResponse': ArchiveSideChatResponse$json,
  '.nushi.v1.RestoreSideChatRequest': RestoreSideChatRequest$json,
  '.nushi.v1.RestoreSideChatResponse': RestoreSideChatResponse$json,
  '.nushi.v1.RenameChatRequest': RenameChatRequest$json,
  '.nushi.v1.RenameChatResponse': RenameChatResponse$json,
  '.nushi.v1.PinChatsRequest': PinChatsRequest$json,
  '.nushi.v1.PinChatsResponse': PinChatsResponse$json,
  '.nushi.v1.SetChatColorRequest': SetChatColorRequest$json,
  '.nushi.v1.SetChatColorResponse': SetChatColorResponse$json,
  '.nushi.v1.PinMessageRequest': PinMessageRequest$json,
  '.nushi.v1.PinMessageResponse': PinMessageResponse$json,
  '.nushi.v1.RenameBranchRequest': RenameBranchRequest$json,
  '.nushi.v1.RenameBranchResponse': RenameBranchResponse$json,
  '.nushi.v1.SwitchBranchRequest': SwitchBranchRequest$json,
  '.nushi.v1.SwitchBranchResponse': SwitchBranchResponse$json,
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
  '.nushi.v1.StageFilesRequest': StageFilesRequest$json,
  '.nushi.v1.StageFilesResponse': StageFilesResponse$json,
  '.nushi.v1.WriteCommitMessageRequest': WriteCommitMessageRequest$json,
  '.nushi.v1.WriteCommitMessageResponse': WriteCommitMessageResponse$json,
  '.nushi.v1.CommitStagedRequest': CommitStagedRequest$json,
  '.nushi.v1.CommitStagedResponse': CommitStagedResponse$json,
  '.nushi.v1.GetFileRequest': GetFileRequest$json,
  '.nushi.v1.GetFileResponse': GetFileResponse$json,
  '.nushi.v1.WatchChatFileRequest': WatchChatFileRequest$json,
  '.nushi.v1.WatchChatFileResponse': WatchChatFileResponse$json,
  '.nushi.v1.FindChatFilesRequest': FindChatFilesRequest$json,
  '.nushi.v1.FindChatFilesResponse': FindChatFilesResponse$json,
  '.nushi.v1.WriteChatFileRequest': WriteChatFileRequest$json,
  '.nushi.v1.WriteChatFileResponse': WriteChatFileResponse$json,
  '.nushi.v1.WriteChatFileResponse.Saved': WriteChatFileResponse_Saved$json,
  '.nushi.v1.WriteChatFileResponse.Stale': WriteChatFileResponse_Stale$json,
  '.nushi.v1.WatchChatFolderRequest': WatchChatFolderRequest$json,
  '.nushi.v1.WatchChatFolderResponse': WatchChatFolderResponse$json,
  '.nushi.v1.FolderListing': FolderListing$json,
  '.nushi.v1.FolderEntry': FolderEntry$json,
  '.nushi.v1.ListCommitsRequest': ListCommitsRequest$json,
  '.nushi.v1.ListCommitsResponse': ListCommitsResponse$json,
  '.nushi.v1.Commit': Commit$json,
  '.nushi.v1.GetFolderStatusRequest': GetFolderStatusRequest$json,
  '.nushi.v1.GetFolderStatusResponse': GetFolderStatusResponse$json,
  '.nushi.v1.GetProjectIconRequest': GetProjectIconRequest$json,
  '.nushi.v1.GetProjectIconResponse': GetProjectIconResponse$json,
  '.nushi.v1.GetRelatedWorktreesRequest': GetRelatedWorktreesRequest$json,
  '.nushi.v1.GetRelatedWorktreesResponse': GetRelatedWorktreesResponse$json,
  '.nushi.v1.RelatedWorktree': RelatedWorktree$json,
  '.nushi.v1.GetRelatedWorktreeStatsRequest':
      GetRelatedWorktreeStatsRequest$json,
  '.nushi.v1.GetRelatedWorktreeStatsResponse':
      GetRelatedWorktreeStatsResponse$json,
  '.nushi.v1.RelatedWorktreeStats': RelatedWorktreeStats$json,
  '.nushi.v1.ListBranchesRequest': ListBranchesRequest$json,
  '.nushi.v1.ListBranchesResponse': ListBranchesResponse$json,
  '.nushi.v1.GitBranch': GitBranch$json,
  '.nushi.v1.GitWorktree': GitWorktree$json,
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
  '.nushi.v1.ListServersRequest': ListServersRequest$json,
  '.nushi.v1.ListServersResponse': ListServersResponse$json,
  '.nushi.v1.DevServer': DevServer$json,
  '.nushi.v1.DevServer.EnvEntry': DevServer_EnvEntry$json,
  '.nushi.v1.LaunchFile': LaunchFile$json,
  '.nushi.v1.StartServerRequest': StartServerRequest$json,
  '.nushi.v1.StartServerResponse': StartServerResponse$json,
  '.nushi.v1.StopServerRequest': StopServerRequest$json,
  '.nushi.v1.StopServerResponse': StopServerResponse$json,
  '.nushi.v1.StopAllServersRequest': StopAllServersRequest$json,
  '.nushi.v1.StopAllServersResponse': StopAllServersResponse$json,
  '.nushi.v1.WatchServerLogRequest': WatchServerLogRequest$json,
  '.nushi.v1.WatchServerLogResponse': WatchServerLogResponse$json,
  '.nushi.v1.CheckFolderRequest': CheckFolderRequest$json,
  '.nushi.v1.CheckFolderResponse': CheckFolderResponse$json,
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
  '.nushi.v1.GitHubCheckCounts': GitHubCheckCounts$json,
  '.nushi.v1.GetGitHubStatesRequest': GetGitHubStatesRequest$json,
  '.nushi.v1.GetGitHubStatesResponse': GetGitHubStatesResponse$json,
  '.nushi.v1.GetGitHubItemsRequest': GetGitHubItemsRequest$json,
  '.nushi.v1.GetGitHubItemsResponse': GetGitHubItemsResponse$json,
  '.nushi.v1.GetGitHubPullRequest': GetGitHubPullRequest$json,
  '.nushi.v1.GetGitHubPullResponse': GetGitHubPullResponse$json,
  '.nushi.v1.GitHubPull': GitHubPull$json,
  '.nushi.v1.GitHubReviewer': GitHubReviewer$json,
  '.nushi.v1.GitHubComment': GitHubComment$json,
  '.nushi.v1.GitHubThread': GitHubThread$json,
  '.nushi.v1.GitHubCheck': GitHubCheck$json,
  '.nushi.v1.GitHubAnnotation': GitHubAnnotation$json,
  '.nushi.v1.GitHubMerge': GitHubMerge$json,
  '.nushi.v1.GitHubAutoMerge': GitHubAutoMerge$json,
  '.nushi.v1.GitHubQueueEntry': GitHubQueueEntry$json,
  '.nushi.v1.GetGitHubIssueRequest': GetGitHubIssueRequest$json,
  '.nushi.v1.GetGitHubIssueResponse': GetGitHubIssueResponse$json,
  '.nushi.v1.GitHubIssue': GitHubIssue$json,
  '.nushi.v1.GetGitHubFilesRequest': GetGitHubFilesRequest$json,
  '.nushi.v1.GetGitHubFilesResponse': GetGitHubFilesResponse$json,
  '.nushi.v1.GetGitHubJobLogRequest': GetGitHubJobLogRequest$json,
  '.nushi.v1.GetGitHubJobLogResponse': GetGitHubJobLogResponse$json,
  '.nushi.v1.ReplyGitHubThreadRequest': ReplyGitHubThreadRequest$json,
  '.nushi.v1.ReplyGitHubThreadResponse': ReplyGitHubThreadResponse$json,
  '.nushi.v1.ResolveGitHubThreadRequest': ResolveGitHubThreadRequest$json,
  '.nushi.v1.ResolveGitHubThreadResponse': ResolveGitHubThreadResponse$json,
  '.nushi.v1.AddGitHubCommentRequest': AddGitHubCommentRequest$json,
  '.nushi.v1.AddGitHubCommentResponse': AddGitHubCommentResponse$json,
  '.nushi.v1.SubmitGitHubReviewRequest': SubmitGitHubReviewRequest$json,
  '.nushi.v1.GitHubDraft': GitHubDraft$json,
  '.nushi.v1.SubmitGitHubReviewResponse': SubmitGitHubReviewResponse$json,
  '.nushi.v1.RerunGitHubChecksRequest': RerunGitHubChecksRequest$json,
  '.nushi.v1.RerunGitHubChecksResponse': RerunGitHubChecksResponse$json,
  '.nushi.v1.GetGitHubMergeTextRequest': GetGitHubMergeTextRequest$json,
  '.nushi.v1.GetGitHubMergeTextResponse': GetGitHubMergeTextResponse$json,
  '.nushi.v1.MergeGitHubPullRequest': MergeGitHubPullRequest$json,
  '.nushi.v1.MergeGitHubPullResponse': MergeGitHubPullResponse$json,
  '.nushi.v1.EnableGitHubAutoMergeRequest': EnableGitHubAutoMergeRequest$json,
  '.nushi.v1.EnableGitHubAutoMergeResponse': EnableGitHubAutoMergeResponse$json,
  '.nushi.v1.DisableGitHubAutoMergeRequest': DisableGitHubAutoMergeRequest$json,
  '.nushi.v1.DisableGitHubAutoMergeResponse':
      DisableGitHubAutoMergeResponse$json,
  '.nushi.v1.EnqueueGitHubPullRequest': EnqueueGitHubPullRequest$json,
  '.nushi.v1.EnqueueGitHubPullResponse': EnqueueGitHubPullResponse$json,
  '.nushi.v1.DequeueGitHubPullRequest': DequeueGitHubPullRequest$json,
  '.nushi.v1.DequeueGitHubPullResponse': DequeueGitHubPullResponse$json,
  '.nushi.v1.GetCleanUpRequest': GetCleanUpRequest$json,
  '.nushi.v1.GetCleanUpResponse': GetCleanUpResponse$json,
  '.nushi.v1.RemoveChatWorktreeRequest': RemoveChatWorktreeRequest$json,
  '.nushi.v1.RemoveChatWorktreeResponse': RemoveChatWorktreeResponse$json,
  '.nushi.v1.DeleteChatBranchRequest': DeleteChatBranchRequest$json,
  '.nushi.v1.DeleteChatBranchResponse': DeleteChatBranchResponse$json,
  '.nushi.v1.DeleteGitHubBranchRequest': DeleteGitHubBranchRequest$json,
  '.nushi.v1.DeleteGitHubBranchResponse': DeleteGitHubBranchResponse$json,
  '.nushi.v1.RestoreGitHubBranchRequest': RestoreGitHubBranchRequest$json,
  '.nushi.v1.RestoreGitHubBranchResponse': RestoreGitHubBranchResponse$json,
  '.nushi.v1.FindChatPullRequest': FindChatPullRequest$json,
  '.nushi.v1.FindChatPullResponse': FindChatPullResponse$json,
  '.nushi.v1.LinkChatPullRequest': LinkChatPullRequest$json,
  '.nushi.v1.LinkChatPullResponse': LinkChatPullResponse$json,
  '.nushi.v1.EventsRequest': EventsRequest$json,
  '.nushi.v1.EventsResponse': EventsResponse$json,
  '.nushi.v1.ItemEvent': ItemEvent$json,
  '.nushi.v1.ChatConfig': ChatConfig$json,
  '.nushi.v1.ChatCommands': ChatCommands$json,
  '.nushi.v1.ChatTerminals': ChatTerminals$json,
  '.nushi.v1.RemovedChats': RemovedChats$json,
  '.nushi.v1.ChatRelatedWorktrees': ChatRelatedWorktrees$json,
};

/// Descriptor for `NushiService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List nushiServiceDescriptor = $convert.base64Decode(
    'CgxOdXNoaVNlcnZpY2USNQoEUGluZxIVLm51c2hpLnYxLlBpbmdSZXF1ZXN0GhYubnVzaGkudj'
    'EuUGluZ1Jlc3BvbnNlElYKD1Jlc3RhcnRXaGVuSWRsZRIgLm51c2hpLnYxLlJlc3RhcnRXaGVu'
    'SWRsZVJlcXVlc3QaIS5udXNoaS52MS5SZXN0YXJ0V2hlbklkbGVSZXNwb25zZRJWCg9DaGVja0'
    'ZvclVwZGF0ZXMSIC5udXNoaS52MS5DaGVja0ZvclVwZGF0ZXNSZXF1ZXN0GiEubnVzaGkudjEu'
    'Q2hlY2tGb3JVcGRhdGVzUmVzcG9uc2USUAoNSW5zdGFsbFVwZGF0ZRIeLm51c2hpLnYxLkluc3'
    'RhbGxVcGRhdGVSZXF1ZXN0Gh8ubnVzaGkudjEuSW5zdGFsbFVwZGF0ZVJlc3BvbnNlEkQKCUxp'
    'c3RDaGF0cxIaLm51c2hpLnYxLkxpc3RDaGF0c1JlcXVlc3QaGy5udXNoaS52MS5MaXN0Q2hhdH'
    'NSZXNwb25zZRI+CgdHZXRDaGF0EhgubnVzaGkudjEuR2V0Q2hhdFJlcXVlc3QaGS5udXNoaS52'
    'MS5HZXRDaGF0UmVzcG9uc2USTQoMR2V0Q2hhdEl0ZW1zEh0ubnVzaGkudjEuR2V0Q2hhdEl0ZW'
    '1zUmVxdWVzdBoeLm51c2hpLnYxLkdldENoYXRJdGVtc1Jlc3BvbnNlEk0KDEdldENoYXRJbWFn'
    'ZRIdLm51c2hpLnYxLkdldENoYXRJbWFnZVJlcXVlc3QaHi5udXNoaS52MS5HZXRDaGF0SW1hZ2'
    'VSZXNwb25zZRJECglTdGFydENoYXQSGi5udXNoaS52MS5TdGFydENoYXRSZXF1ZXN0GhsubnVz'
    'aGkudjEuU3RhcnRDaGF0UmVzcG9uc2USRwoKTGlzdEFnZW50cxIbLm51c2hpLnYxLkxpc3RBZ2'
    'VudHNSZXF1ZXN0GhwubnVzaGkudjEuTGlzdEFnZW50c1Jlc3BvbnNlEkcKClNldFVwQWdlbnQS'
    'Gy5udXNoaS52MS5TZXRVcEFnZW50UmVxdWVzdBocLm51c2hpLnYxLlNldFVwQWdlbnRSZXNwb2'
    '5zZRJKCgtSZW1vdmVBZ2VudBIcLm51c2hpLnYxLlJlbW92ZUFnZW50UmVxdWVzdBodLm51c2hp'
    'LnYxLlJlbW92ZUFnZW50UmVzcG9uc2USXAoRTGlzdEFnZW50U2Vzc2lvbnMSIi5udXNoaS52MS'
    '5MaXN0QWdlbnRTZXNzaW9uc1JlcXVlc3QaIy5udXNoaS52MS5MaXN0QWdlbnRTZXNzaW9uc1Jl'
    'c3BvbnNlElkKEE9wZW5BZ2VudFNlc3Npb24SIS5udXNoaS52MS5PcGVuQWdlbnRTZXNzaW9uUm'
    'VxdWVzdBoiLm51c2hpLnYxLk9wZW5BZ2VudFNlc3Npb25SZXNwb25zZRJiChNTZWFyY2hBZ2Vu'
    'dFNlc3Npb25zEiQubnVzaGkudjEuU2VhcmNoQWdlbnRTZXNzaW9uc1JlcXVlc3QaJS5udXNoaS'
    '52MS5TZWFyY2hBZ2VudFNlc3Npb25zUmVzcG9uc2USQQoITW92ZUNoYXQSGS5udXNoaS52MS5N'
    'b3ZlQ2hhdFJlcXVlc3QaGi5udXNoaS52MS5Nb3ZlQ2hhdFJlc3BvbnNlEkcKClNlbmRQcm9tcH'
    'QSGy5udXNoaS52MS5TZW5kUHJvbXB0UmVxdWVzdBocLm51c2hpLnYxLlNlbmRQcm9tcHRSZXNw'
    'b25zZRJHCgpSZXdpbmRDaGF0EhsubnVzaGkudjEuUmV3aW5kQ2hhdFJlcXVlc3QaHC5udXNoaS'
    '52MS5SZXdpbmRDaGF0UmVzcG9uc2USPgoHVW5xdWV1ZRIYLm51c2hpLnYxLlVucXVldWVSZXF1'
    'ZXN0GhkubnVzaGkudjEuVW5xdWV1ZVJlc3BvbnNlEkcKCkNhbmNlbFR1cm4SGy5udXNoaS52MS'
    '5DYW5jZWxUdXJuUmVxdWVzdBocLm51c2hpLnYxLkNhbmNlbFR1cm5SZXNwb25zZRJBCghTdG9w'
    'VGFzaxIZLm51c2hpLnYxLlN0b3BUYXNrUmVxdWVzdBoaLm51c2hpLnYxLlN0b3BUYXNrUmVzcG'
    '9uc2USQQoIRm9ya0NoYXQSGS5udXNoaS52MS5Gb3JrQ2hhdFJlcXVlc3QaGi5udXNoaS52MS5G'
    'b3JrQ2hhdFJlc3BvbnNlElAKDUNsb3NlU2lkZUNoYXQSHi5udXNoaS52MS5DbG9zZVNpZGVDaG'
    'F0UmVxdWVzdBofLm51c2hpLnYxLkNsb3NlU2lkZUNoYXRSZXNwb25zZRJHCgpGb3JrQXNDaGF0'
    'EhsubnVzaGkudjEuRm9ya0FzQ2hhdFJlcXVlc3QaHC5udXNoaS52MS5Gb3JrQXNDaGF0UmVzcG'
    '9uc2USTQoMS2VlcFNpZGVDaGF0Eh0ubnVzaGkudjEuS2VlcFNpZGVDaGF0UmVxdWVzdBoeLm51'
    'c2hpLnYxLktlZXBTaWRlQ2hhdFJlc3BvbnNlElYKD0FyY2hpdmVTaWRlQ2hhdBIgLm51c2hpLn'
    'YxLkFyY2hpdmVTaWRlQ2hhdFJlcXVlc3QaIS5udXNoaS52MS5BcmNoaXZlU2lkZUNoYXRSZXNw'
    'b25zZRJWCg9SZXN0b3JlU2lkZUNoYXQSIC5udXNoaS52MS5SZXN0b3JlU2lkZUNoYXRSZXF1ZX'
    'N0GiEubnVzaGkudjEuUmVzdG9yZVNpZGVDaGF0UmVzcG9uc2USRwoKUmVuYW1lQ2hhdBIbLm51'
    'c2hpLnYxLlJlbmFtZUNoYXRSZXF1ZXN0GhwubnVzaGkudjEuUmVuYW1lQ2hhdFJlc3BvbnNlEk'
    'EKCFBpbkNoYXRzEhkubnVzaGkudjEuUGluQ2hhdHNSZXF1ZXN0GhoubnVzaGkudjEuUGluQ2hh'
    'dHNSZXNwb25zZRJNCgxTZXRDaGF0Q29sb3ISHS5udXNoaS52MS5TZXRDaGF0Q29sb3JSZXF1ZX'
    'N0Gh4ubnVzaGkudjEuU2V0Q2hhdENvbG9yUmVzcG9uc2USRwoKUGluTWVzc2FnZRIbLm51c2hp'
    'LnYxLlBpbk1lc3NhZ2VSZXF1ZXN0GhwubnVzaGkudjEuUGluTWVzc2FnZVJlc3BvbnNlEk0KDF'
    'JlbmFtZUJyYW5jaBIdLm51c2hpLnYxLlJlbmFtZUJyYW5jaFJlcXVlc3QaHi5udXNoaS52MS5S'
    'ZW5hbWVCcmFuY2hSZXNwb25zZRJNCgxTd2l0Y2hCcmFuY2gSHS5udXNoaS52MS5Td2l0Y2hCcm'
    'FuY2hSZXF1ZXN0Gh4ubnVzaGkudjEuU3dpdGNoQnJhbmNoUmVzcG9uc2USSgoLQXJjaGl2ZUNo'
    'YXQSHC5udXNoaS52MS5BcmNoaXZlQ2hhdFJlcXVlc3QaHS5udXNoaS52MS5BcmNoaXZlQ2hhdF'
    'Jlc3BvbnNlEkQKCVNsZWVwQ2hhdBIaLm51c2hpLnYxLlNsZWVwQ2hhdFJlcXVlc3QaGy5udXNo'
    'aS52MS5TbGVlcENoYXRSZXNwb25zZRJHCgpSZW9wZW5DaGF0EhsubnVzaGkudjEuUmVvcGVuQ2'
    'hhdFJlcXVlc3QaHC5udXNoaS52MS5SZW9wZW5DaGF0UmVzcG9uc2USRAoJR2V0TWVtb3J5Ehou'
    'bnVzaGkudjEuR2V0TWVtb3J5UmVxdWVzdBobLm51c2hpLnYxLkdldE1lbW9yeVJlc3BvbnNlEk'
    'oKC0dldFNldHRpbmdzEhwubnVzaGkudjEuR2V0U2V0dGluZ3NSZXF1ZXN0Gh0ubnVzaGkudjEu'
    'R2V0U2V0dGluZ3NSZXNwb25zZRJKCgtTZXRTZXR0aW5ncxIcLm51c2hpLnYxLlNldFNldHRpbm'
    'dzUmVxdWVzdBodLm51c2hpLnYxLlNldFNldHRpbmdzUmVzcG9uc2USVgoPTGlzdFRyYW5zY3Jp'
    'cHRzEiAubnVzaGkudjEuTGlzdFRyYW5zY3JpcHRzUmVxdWVzdBohLm51c2hpLnYxLkxpc3RUcm'
    'Fuc2NyaXB0c1Jlc3BvbnNlElkKEENsZWFyVHJhbnNjcmlwdHMSIS5udXNoaS52MS5DbGVhclRy'
    'YW5zY3JpcHRzUmVxdWVzdBoiLm51c2hpLnYxLkNsZWFyVHJhbnNjcmlwdHNSZXNwb25zZRJTCg'
    '5QbGFuRGVsZXRlQ2hhdBIfLm51c2hpLnYxLlBsYW5EZWxldGVDaGF0UmVxdWVzdBogLm51c2hp'
    'LnYxLlBsYW5EZWxldGVDaGF0UmVzcG9uc2USRwoKRGVsZXRlQ2hhdBIbLm51c2hpLnYxLkRlbG'
    'V0ZUNoYXRSZXF1ZXN0GhwubnVzaGkudjEuRGVsZXRlQ2hhdFJlc3BvbnNlEmIKE0Rpc21pc3NS'
    'ZW1vdmVkQ2hhdHMSJC5udXNoaS52MS5EaXNtaXNzUmVtb3ZlZENoYXRzUmVxdWVzdBolLm51c2'
    'hpLnYxLkRpc21pc3NSZW1vdmVkQ2hhdHNSZXNwb25zZRJZChBBbnN3ZXJQZXJtaXNzaW9uEiEu'
    'bnVzaGkudjEuQW5zd2VyUGVybWlzc2lvblJlcXVlc3QaIi5udXNoaS52MS5BbnN3ZXJQZXJtaX'
    'NzaW9uUmVzcG9uc2USUwoOQW5zd2VyUXVlc3Rpb24SHy5udXNoaS52MS5BbnN3ZXJRdWVzdGlv'
    'blJlcXVlc3QaIC5udXNoaS52MS5BbnN3ZXJRdWVzdGlvblJlc3BvbnNlElYKD1NldENvbmZpZ0'
    '9wdGlvbhIgLm51c2hpLnYxLlNldENvbmZpZ09wdGlvblJlcXVlc3QaIS5udXNoaS52MS5TZXRD'
    'b25maWdPcHRpb25SZXNwb25zZRI+CgdHZXREaWZmEhgubnVzaGkudjEuR2V0RGlmZlJlcXVlc3'
    'QaGS5udXNoaS52MS5HZXREaWZmUmVzcG9uc2USRwoKU3RhZ2VGaWxlcxIbLm51c2hpLnYxLlN0'
    'YWdlRmlsZXNSZXF1ZXN0GhwubnVzaGkudjEuU3RhZ2VGaWxlc1Jlc3BvbnNlEl8KEldyaXRlQ2'
    '9tbWl0TWVzc2FnZRIjLm51c2hpLnYxLldyaXRlQ29tbWl0TWVzc2FnZVJlcXVlc3QaJC5udXNo'
    'aS52MS5Xcml0ZUNvbW1pdE1lc3NhZ2VSZXNwb25zZRJNCgxDb21taXRTdGFnZWQSHS5udXNoaS'
    '52MS5Db21taXRTdGFnZWRSZXF1ZXN0Gh4ubnVzaGkudjEuQ29tbWl0U3RhZ2VkUmVzcG9uc2US'
    'PgoHR2V0RmlsZRIYLm51c2hpLnYxLkdldEZpbGVSZXF1ZXN0GhkubnVzaGkudjEuR2V0RmlsZV'
    'Jlc3BvbnNlElIKDVdhdGNoQ2hhdEZpbGUSHi5udXNoaS52MS5XYXRjaENoYXRGaWxlUmVxdWVz'
    'dBofLm51c2hpLnYxLldhdGNoQ2hhdEZpbGVSZXNwb25zZTABElAKDUZpbmRDaGF0RmlsZXMSHi'
    '5udXNoaS52MS5GaW5kQ2hhdEZpbGVzUmVxdWVzdBofLm51c2hpLnYxLkZpbmRDaGF0RmlsZXNS'
    'ZXNwb25zZRJQCg1Xcml0ZUNoYXRGaWxlEh4ubnVzaGkudjEuV3JpdGVDaGF0RmlsZVJlcXVlc3'
    'QaHy5udXNoaS52MS5Xcml0ZUNoYXRGaWxlUmVzcG9uc2USWAoPV2F0Y2hDaGF0Rm9sZGVyEiAu'
    'bnVzaGkudjEuV2F0Y2hDaGF0Rm9sZGVyUmVxdWVzdBohLm51c2hpLnYxLldhdGNoQ2hhdEZvbG'
    'RlclJlc3BvbnNlMAESSgoLTGlzdENvbW1pdHMSHC5udXNoaS52MS5MaXN0Q29tbWl0c1JlcXVl'
    'c3QaHS5udXNoaS52MS5MaXN0Q29tbWl0c1Jlc3BvbnNlElYKD0dldEZvbGRlclN0YXR1cxIgLm'
    '51c2hpLnYxLkdldEZvbGRlclN0YXR1c1JlcXVlc3QaIS5udXNoaS52MS5HZXRGb2xkZXJTdGF0'
    'dXNSZXNwb25zZRJTCg5HZXRQcm9qZWN0SWNvbhIfLm51c2hpLnYxLkdldFByb2plY3RJY29uUm'
    'VxdWVzdBogLm51c2hpLnYxLkdldFByb2plY3RJY29uUmVzcG9uc2USYgoTR2V0UmVsYXRlZFdv'
    'cmt0cmVlcxIkLm51c2hpLnYxLkdldFJlbGF0ZWRXb3JrdHJlZXNSZXF1ZXN0GiUubnVzaGkudj'
    'EuR2V0UmVsYXRlZFdvcmt0cmVlc1Jlc3BvbnNlEm4KF0dldFJlbGF0ZWRXb3JrdHJlZVN0YXRz'
    'EigubnVzaGkudjEuR2V0UmVsYXRlZFdvcmt0cmVlU3RhdHNSZXF1ZXN0GikubnVzaGkudjEuR2'
    'V0UmVsYXRlZFdvcmt0cmVlU3RhdHNSZXNwb25zZRJNCgxMaXN0QnJhbmNoZXMSHS5udXNoaS52'
    'MS5MaXN0QnJhbmNoZXNSZXF1ZXN0Gh4ubnVzaGkudjEuTGlzdEJyYW5jaGVzUmVzcG9uc2USRA'
    'oJTGlzdEZpbGVzEhoubnVzaGkudjEuTGlzdEZpbGVzUmVxdWVzdBobLm51c2hpLnYxLkxpc3RG'
    'aWxlc1Jlc3BvbnNlElYKD0dldENvbnRleHRVc2FnZRIgLm51c2hpLnYxLkdldENvbnRleHRVc2'
    'FnZVJlcXVlc3QaIS5udXNoaS52MS5HZXRDb250ZXh0VXNhZ2VSZXNwb25zZRJTCg5MaXN0TWNw'
    'U2VydmVycxIfLm51c2hpLnYxLkxpc3RNY3BTZXJ2ZXJzUmVxdWVzdBogLm51c2hpLnYxLkxpc3'
    'RNY3BTZXJ2ZXJzUmVzcG9uc2USTQoMQWRkTWNwU2VydmVyEh0ubnVzaGkudjEuQWRkTWNwU2Vy'
    'dmVyUmVxdWVzdBoeLm51c2hpLnYxLkFkZE1jcFNlcnZlclJlc3BvbnNlElAKDUVkaXRNY3BTZX'
    'J2ZXISHi5udXNoaS52MS5FZGl0TWNwU2VydmVyUmVxdWVzdBofLm51c2hpLnYxLkVkaXRNY3BT'
    'ZXJ2ZXJSZXNwb25zZRJWCg9SZW1vdmVNY3BTZXJ2ZXISIC5udXNoaS52MS5SZW1vdmVNY3BTZX'
    'J2ZXJSZXF1ZXN0GiEubnVzaGkudjEuUmVtb3ZlTWNwU2VydmVyUmVzcG9uc2USUwoOU2V0TWNw'
    'U2VydmVyT24SHy5udXNoaS52MS5TZXRNY3BTZXJ2ZXJPblJlcXVlc3QaIC5udXNoaS52MS5TZX'
    'RNY3BTZXJ2ZXJPblJlc3BvbnNlElMKDkxvZ2luTWNwU2VydmVyEh8ubnVzaGkudjEuTG9naW5N'
    'Y3BTZXJ2ZXJSZXF1ZXN0GiAubnVzaGkudjEuTG9naW5NY3BTZXJ2ZXJSZXNwb25zZRJWCg9Mb2'
    'dvdXRNY3BTZXJ2ZXISIC5udXNoaS52MS5Mb2dvdXRNY3BTZXJ2ZXJSZXF1ZXN0GiEubnVzaGku'
    'djEuTG9nb3V0TWNwU2VydmVyUmVzcG9uc2USRwoKTGlzdFNraWxscxIbLm51c2hpLnYxLkxpc3'
    'RTa2lsbHNSZXF1ZXN0GhwubnVzaGkudjEuTGlzdFNraWxsc1Jlc3BvbnNlEkcKClNldFNraWxs'
    'T24SGy5udXNoaS52MS5TZXRTa2lsbE9uUmVxdWVzdBocLm51c2hpLnYxLlNldFNraWxsT25SZX'
    'Nwb25zZRJKCgtTZXRQbHVnaW5PbhIcLm51c2hpLnYxLlNldFBsdWdpbk9uUmVxdWVzdBodLm51'
    'c2hpLnYxLlNldFBsdWdpbk9uUmVzcG9uc2USVgoPVW5pbnN0YWxsUGx1Z2luEiAubnVzaGkudj'
    'EuVW5pbnN0YWxsUGx1Z2luUmVxdWVzdBohLm51c2hpLnYxLlVuaW5zdGFsbFBsdWdpblJlc3Bv'
    'bnNlEkcKClRyYXNoU2tpbGwSGy5udXNoaS52MS5UcmFzaFNraWxsUmVxdWVzdBocLm51c2hpLn'
    'YxLlRyYXNoU2tpbGxSZXNwb25zZRJECglMaW5rU2tpbGwSGi5udXNoaS52MS5MaW5rU2tpbGxS'
    'ZXF1ZXN0GhsubnVzaGkudjEuTGlua1NraWxsUmVzcG9uc2USRwoKUmVsb2FkQ2hhdBIbLm51c2'
    'hpLnYxLlJlbG9hZENoYXRSZXF1ZXN0GhwubnVzaGkudjEuUmVsb2FkQ2hhdFJlc3BvbnNlEk0K'
    'DE9wZW5UZXJtaW5hbBIdLm51c2hpLnYxLk9wZW5UZXJtaW5hbFJlcXVlc3QaHi5udXNoaS52MS'
    '5PcGVuVGVybWluYWxSZXNwb25zZRJQCg1MaXN0VGVybWluYWxzEh4ubnVzaGkudjEuTGlzdFRl'
    'cm1pbmFsc1JlcXVlc3QaHy5udXNoaS52MS5MaXN0VGVybWluYWxzUmVzcG9uc2USVQoOQXR0YW'
    'NoVGVybWluYWwSHy5udXNoaS52MS5BdHRhY2hUZXJtaW5hbFJlcXVlc3QaIC5udXNoaS52MS5B'
    'dHRhY2hUZXJtaW5hbFJlc3BvbnNlMAESUAoNV3JpdGVUZXJtaW5hbBIeLm51c2hpLnYxLldyaX'
    'RlVGVybWluYWxSZXF1ZXN0Gh8ubnVzaGkudjEuV3JpdGVUZXJtaW5hbFJlc3BvbnNlElMKDlJl'
    'c2l6ZVRlcm1pbmFsEh8ubnVzaGkudjEuUmVzaXplVGVybWluYWxSZXF1ZXN0GiAubnVzaGkudj'
    'EuUmVzaXplVGVybWluYWxSZXNwb25zZRJTCg5SZW5hbWVUZXJtaW5hbBIfLm51c2hpLnYxLlJl'
    'bmFtZVRlcm1pbmFsUmVxdWVzdBogLm51c2hpLnYxLlJlbmFtZVRlcm1pbmFsUmVzcG9uc2USWQ'
    'oQQXJyYW5nZVRlcm1pbmFscxIhLm51c2hpLnYxLkFycmFuZ2VUZXJtaW5hbHNSZXF1ZXN0GiIu'
    'bnVzaGkudjEuQXJyYW5nZVRlcm1pbmFsc1Jlc3BvbnNlElYKD1Jlc3RhcnRUZXJtaW5hbBIgLm'
    '51c2hpLnYxLlJlc3RhcnRUZXJtaW5hbFJlcXVlc3QaIS5udXNoaS52MS5SZXN0YXJ0VGVybWlu'
    'YWxSZXNwb25zZRJQCg1DbG9zZVRlcm1pbmFsEh4ubnVzaGkudjEuQ2xvc2VUZXJtaW5hbFJlcX'
    'Vlc3QaHy5udXNoaS52MS5DbG9zZVRlcm1pbmFsUmVzcG9uc2USSgoLTGlzdFNlcnZlcnMSHC5u'
    'dXNoaS52MS5MaXN0U2VydmVyc1JlcXVlc3QaHS5udXNoaS52MS5MaXN0U2VydmVyc1Jlc3Bvbn'
    'NlEkoKC1N0YXJ0U2VydmVyEhwubnVzaGkudjEuU3RhcnRTZXJ2ZXJSZXF1ZXN0Gh0ubnVzaGku'
    'djEuU3RhcnRTZXJ2ZXJSZXNwb25zZRJHCgpTdG9wU2VydmVyEhsubnVzaGkudjEuU3RvcFNlcn'
    'ZlclJlcXVlc3QaHC5udXNoaS52MS5TdG9wU2VydmVyUmVzcG9uc2USUwoOU3RvcEFsbFNlcnZl'
    'cnMSHy5udXNoaS52MS5TdG9wQWxsU2VydmVyc1JlcXVlc3QaIC5udXNoaS52MS5TdG9wQWxsU2'
    'VydmVyc1Jlc3BvbnNlElUKDldhdGNoU2VydmVyTG9nEh8ubnVzaGkudjEuV2F0Y2hTZXJ2ZXJM'
    'b2dSZXF1ZXN0GiAubnVzaGkudjEuV2F0Y2hTZXJ2ZXJMb2dSZXNwb25zZTABEkoKC0NoZWNrRm'
    '9sZGVyEhwubnVzaGkudjEuQ2hlY2tGb2xkZXJSZXF1ZXN0Gh0ubnVzaGkudjEuQ2hlY2tGb2xk'
    'ZXJSZXNwb25zZRJKCgtUcnVzdEZvbGRlchIcLm51c2hpLnYxLlRydXN0Rm9sZGVyUmVxdWVzdB'
    'odLm51c2hpLnYxLlRydXN0Rm9sZGVyUmVzcG9uc2USRAoJR2V0UmVtb3RlEhoubnVzaGkudjEu'
    'R2V0UmVtb3RlUmVxdWVzdBobLm51c2hpLnYxLkdldFJlbW90ZVJlc3BvbnNlEkQKCVNldFJlbW'
    '90ZRIaLm51c2hpLnYxLlNldFJlbW90ZVJlcXVlc3QaGy5udXNoaS52MS5TZXRSZW1vdGVSZXNw'
    'b25zZRJNCgxTdGFydFBhaXJpbmcSHS5udXNoaS52MS5TdGFydFBhaXJpbmdSZXF1ZXN0Gh4ubn'
    'VzaGkudjEuU3RhcnRQYWlyaW5nUmVzcG9uc2USUwoOQ29uZmlybVBhaXJpbmcSHy5udXNoaS52'
    'MS5Db25maXJtUGFpcmluZ1JlcXVlc3QaIC5udXNoaS52MS5Db25maXJtUGFpcmluZ1Jlc3Bvbn'
    'NlEk0KDFJldm9rZURldmljZRIdLm51c2hpLnYxLlJldm9rZURldmljZVJlcXVlc3QaHi5udXNo'
    'aS52MS5SZXZva2VEZXZpY2VSZXNwb25zZRJHCgpHZXRQdXNoS2V5EhsubnVzaGkudjEuR2V0UH'
    'VzaEtleVJlcXVlc3QaHC5udXNoaS52MS5HZXRQdXNoS2V5UmVzcG9uc2USYgoTU2V0UHVzaFN1'
    'YnNjcmlwdGlvbhIkLm51c2hpLnYxLlNldFB1c2hTdWJzY3JpcHRpb25SZXF1ZXN0GiUubnVzaG'
    'kudjEuU2V0UHVzaFN1YnNjcmlwdGlvblJlc3BvbnNlElAKDVNldERldmljZVZpZXcSHi5udXNo'
    'aS52MS5TZXREZXZpY2VWaWV3UmVxdWVzdBofLm51c2hpLnYxLlNldERldmljZVZpZXdSZXNwb2'
    '5zZRJNCgxTZW5kVGVzdFB1c2gSHS5udXNoaS52MS5TZW5kVGVzdFB1c2hSZXF1ZXN0Gh4ubnVz'
    'aGkudjEuU2VuZFRlc3RQdXNoUmVzcG9uc2USWQoQVW5wYWlyVGhpc0RldmljZRIhLm51c2hpLn'
    'YxLlVucGFpclRoaXNEZXZpY2VSZXF1ZXN0GiIubnVzaGkudjEuVW5wYWlyVGhpc0RldmljZVJl'
    'c3BvbnNlEjIKA0xvZxIULm51c2hpLnYxLkxvZ1JlcXVlc3QaFS5udXNoaS52MS5Mb2dSZXNwb2'
    '5zZRJQCg1MaXN0SmlyYVNpdGVzEh4ubnVzaGkudjEuTGlzdEppcmFTaXRlc1JlcXVlc3QaHy5u'
    'dXNoaS52MS5MaXN0SmlyYVNpdGVzUmVzcG9uc2USSgoLQWRkSmlyYVNpdGUSHC5udXNoaS52MS'
    '5BZGRKaXJhU2l0ZVJlcXVlc3QaHS5udXNoaS52MS5BZGRKaXJhU2l0ZVJlc3BvbnNlElMKDlJl'
    'bW92ZUppcmFTaXRlEh8ubnVzaGkudjEuUmVtb3ZlSmlyYVNpdGVSZXF1ZXN0GiAubnVzaGkudj'
    'EuUmVtb3ZlSmlyYVNpdGVSZXNwb25zZRJQCg1DaGVja0ppcmFTaXRlEh4ubnVzaGkudjEuQ2hl'
    'Y2tKaXJhU2l0ZVJlcXVlc3QaHy5udXNoaS52MS5DaGVja0ppcmFTaXRlUmVzcG9uc2USUwoOQW'
    'xsb3dKaXJhVG9rZW4SHy5udXNoaS52MS5BbGxvd0ppcmFUb2tlblJlcXVlc3QaIC5udXNoaS52'
    'MS5BbGxvd0ppcmFUb2tlblJlc3BvbnNlElMKDkxpc3RKaXJhQm9hcmRzEh8ubnVzaGkudjEuTG'
    'lzdEppcmFCb2FyZHNSZXF1ZXN0GiAubnVzaGkudjEuTGlzdEppcmFCb2FyZHNSZXNwb25zZRJN'
    'CgxTZXRKaXJhQm9hcmQSHS5udXNoaS52MS5TZXRKaXJhQm9hcmRSZXF1ZXN0Gh4ubnVzaGkudj'
    'EuU2V0SmlyYUJvYXJkUmVzcG9uc2USVgoPU2V0SmlyYVNlYXJjaGVzEiAubnVzaGkudjEuU2V0'
    'SmlyYVNlYXJjaGVzUmVxdWVzdBohLm51c2hpLnYxLlNldEppcmFTZWFyY2hlc1Jlc3BvbnNlEl'
    'MKDkxpc3RKaXJhSXNzdWVzEh8ubnVzaGkudjEuTGlzdEppcmFJc3N1ZXNSZXF1ZXN0GiAubnVz'
    'aGkudjEuTGlzdEppcmFJc3N1ZXNSZXNwb25zZRJHCgpHZXRKaXJhSnFsEhsubnVzaGkudjEuR2'
    'V0SmlyYUpxbFJlcXVlc3QaHC5udXNoaS52MS5HZXRKaXJhSnFsUmVzcG9uc2USUwoOU3VnZ2Vz'
    'dEppcmFKcWwSHy5udXNoaS52MS5TdWdnZXN0SmlyYUpxbFJlcXVlc3QaIC5udXNoaS52MS5TdW'
    'dnZXN0SmlyYUpxbFJlc3BvbnNlEk0KDEdldEppcmFJc3N1ZRIdLm51c2hpLnYxLkdldEppcmFJ'
    'c3N1ZVJlcXVlc3QaHi5udXNoaS52MS5HZXRKaXJhSXNzdWVSZXNwb25zZRJiChNMaXN0SmlyYV'
    'RyYW5zaXRpb25zEiQubnVzaGkudjEuTGlzdEppcmFUcmFuc2l0aW9uc1JlcXVlc3QaJS5udXNo'
    'aS52MS5MaXN0SmlyYVRyYW5zaXRpb25zUmVzcG9uc2USYgoTVHJhbnNpdGlvbkppcmFJc3N1ZR'
    'IkLm51c2hpLnYxLlRyYW5zaXRpb25KaXJhSXNzdWVSZXF1ZXN0GiUubnVzaGkudjEuVHJhbnNp'
    'dGlvbkppcmFJc3N1ZVJlc3BvbnNlElMKDkFkZEppcmFDb21tZW50Eh8ubnVzaGkudjEuQWRkSm'
    'lyYUNvbW1lbnRSZXF1ZXN0GiAubnVzaGkudjEuQWRkSmlyYUNvbW1lbnRSZXNwb25zZRJTCg5G'
    'aW5kSmlyYUlzc3VlcxIfLm51c2hpLnYxLkZpbmRKaXJhSXNzdWVzUmVxdWVzdBogLm51c2hpLn'
    'YxLkZpbmRKaXJhSXNzdWVzUmVzcG9uc2USXAoRR2V0SmlyYUF0dGFjaG1lbnQSIi5udXNoaS52'
    'MS5HZXRKaXJhQXR0YWNobWVudFJlcXVlc3QaIy5udXNoaS52MS5HZXRKaXJhQXR0YWNobWVudF'
    'Jlc3BvbnNlElYKD0xpc3RHaXRIdWJIb3N0cxIgLm51c2hpLnYxLkxpc3RHaXRIdWJIb3N0c1Jl'
    'cXVlc3QaIS5udXNoaS52MS5MaXN0R2l0SHViSG9zdHNSZXNwb25zZRJTCg5BZGRHaXRIdWJUb2'
    'tlbhIfLm51c2hpLnYxLkFkZEdpdEh1YlRva2VuUmVxdWVzdBogLm51c2hpLnYxLkFkZEdpdEh1'
    'YlRva2VuUmVzcG9uc2USXAoRUmVtb3ZlR2l0SHViVG9rZW4SIi5udXNoaS52MS5SZW1vdmVHaX'
    'RIdWJUb2tlblJlcXVlc3QaIy5udXNoaS52MS5SZW1vdmVHaXRIdWJUb2tlblJlc3BvbnNlElkK'
    'EEFsbG93R2l0SHViVG9rZW4SIS5udXNoaS52MS5BbGxvd0dpdEh1YlRva2VuUmVxdWVzdBoiLm'
    '51c2hpLnYxLkFsbG93R2l0SHViVG9rZW5SZXNwb25zZRJWCg9MaXN0R2l0SHViUmVwb3MSIC5u'
    'dXNoaS52MS5MaXN0R2l0SHViUmVwb3NSZXF1ZXN0GiEubnVzaGkudjEuTGlzdEdpdEh1YlJlcG'
    '9zUmVzcG9uc2USVgoPTGlzdEdpdEh1YkluYm94EiAubnVzaGkudjEuTGlzdEdpdEh1YkluYm94'
    'UmVxdWVzdBohLm51c2hpLnYxLkxpc3RHaXRIdWJJbmJveFJlc3BvbnNlElYKD0dldEdpdEh1Yl'
    'N0YXRlcxIgLm51c2hpLnYxLkdldEdpdEh1YlN0YXRlc1JlcXVlc3QaIS5udXNoaS52MS5HZXRH'
    'aXRIdWJTdGF0ZXNSZXNwb25zZRJTCg5HZXRHaXRIdWJJdGVtcxIfLm51c2hpLnYxLkdldEdpdE'
    'h1Ykl0ZW1zUmVxdWVzdBogLm51c2hpLnYxLkdldEdpdEh1Ykl0ZW1zUmVzcG9uc2USUAoNR2V0'
    'R2l0SHViUHVsbBIeLm51c2hpLnYxLkdldEdpdEh1YlB1bGxSZXF1ZXN0Gh8ubnVzaGkudjEuR2'
    'V0R2l0SHViUHVsbFJlc3BvbnNlElMKDkdldEdpdEh1Yklzc3VlEh8ubnVzaGkudjEuR2V0R2l0'
    'SHViSXNzdWVSZXF1ZXN0GiAubnVzaGkudjEuR2V0R2l0SHViSXNzdWVSZXNwb25zZRJTCg5HZX'
    'RHaXRIdWJGaWxlcxIfLm51c2hpLnYxLkdldEdpdEh1YkZpbGVzUmVxdWVzdBogLm51c2hpLnYx'
    'LkdldEdpdEh1YkZpbGVzUmVzcG9uc2USVgoPR2V0R2l0SHViSm9iTG9nEiAubnVzaGkudjEuR2'
    'V0R2l0SHViSm9iTG9nUmVxdWVzdBohLm51c2hpLnYxLkdldEdpdEh1YkpvYkxvZ1Jlc3BvbnNl'
    'ElwKEVJlcGx5R2l0SHViVGhyZWFkEiIubnVzaGkudjEuUmVwbHlHaXRIdWJUaHJlYWRSZXF1ZX'
    'N0GiMubnVzaGkudjEuUmVwbHlHaXRIdWJUaHJlYWRSZXNwb25zZRJiChNSZXNvbHZlR2l0SHVi'
    'VGhyZWFkEiQubnVzaGkudjEuUmVzb2x2ZUdpdEh1YlRocmVhZFJlcXVlc3QaJS5udXNoaS52MS'
    '5SZXNvbHZlR2l0SHViVGhyZWFkUmVzcG9uc2USWQoQQWRkR2l0SHViQ29tbWVudBIhLm51c2hp'
    'LnYxLkFkZEdpdEh1YkNvbW1lbnRSZXF1ZXN0GiIubnVzaGkudjEuQWRkR2l0SHViQ29tbWVudF'
    'Jlc3BvbnNlEl8KElN1Ym1pdEdpdEh1YlJldmlldxIjLm51c2hpLnYxLlN1Ym1pdEdpdEh1YlJl'
    'dmlld1JlcXVlc3QaJC5udXNoaS52MS5TdWJtaXRHaXRIdWJSZXZpZXdSZXNwb25zZRJcChFSZX'
    'J1bkdpdEh1YkNoZWNrcxIiLm51c2hpLnYxLlJlcnVuR2l0SHViQ2hlY2tzUmVxdWVzdBojLm51'
    'c2hpLnYxLlJlcnVuR2l0SHViQ2hlY2tzUmVzcG9uc2USXwoSR2V0R2l0SHViTWVyZ2VUZXh0Ei'
    'MubnVzaGkudjEuR2V0R2l0SHViTWVyZ2VUZXh0UmVxdWVzdBokLm51c2hpLnYxLkdldEdpdEh1'
    'Yk1lcmdlVGV4dFJlc3BvbnNlElYKD01lcmdlR2l0SHViUHVsbBIgLm51c2hpLnYxLk1lcmdlR2'
    'l0SHViUHVsbFJlcXVlc3QaIS5udXNoaS52MS5NZXJnZUdpdEh1YlB1bGxSZXNwb25zZRJoChVF'
    'bmFibGVHaXRIdWJBdXRvTWVyZ2USJi5udXNoaS52MS5FbmFibGVHaXRIdWJBdXRvTWVyZ2VSZX'
    'F1ZXN0GicubnVzaGkudjEuRW5hYmxlR2l0SHViQXV0b01lcmdlUmVzcG9uc2USawoWRGlzYWJs'
    'ZUdpdEh1YkF1dG9NZXJnZRInLm51c2hpLnYxLkRpc2FibGVHaXRIdWJBdXRvTWVyZ2VSZXF1ZX'
    'N0GigubnVzaGkudjEuRGlzYWJsZUdpdEh1YkF1dG9NZXJnZVJlc3BvbnNlElwKEUVucXVldWVH'
    'aXRIdWJQdWxsEiIubnVzaGkudjEuRW5xdWV1ZUdpdEh1YlB1bGxSZXF1ZXN0GiMubnVzaGkudj'
    'EuRW5xdWV1ZUdpdEh1YlB1bGxSZXNwb25zZRJcChFEZXF1ZXVlR2l0SHViUHVsbBIiLm51c2hp'
    'LnYxLkRlcXVldWVHaXRIdWJQdWxsUmVxdWVzdBojLm51c2hpLnYxLkRlcXVldWVHaXRIdWJQdW'
    'xsUmVzcG9uc2USRwoKR2V0Q2xlYW5VcBIbLm51c2hpLnYxLkdldENsZWFuVXBSZXF1ZXN0Ghwu'
    'bnVzaGkudjEuR2V0Q2xlYW5VcFJlc3BvbnNlEl8KElJlbW92ZUNoYXRXb3JrdHJlZRIjLm51c2'
    'hpLnYxLlJlbW92ZUNoYXRXb3JrdHJlZVJlcXVlc3QaJC5udXNoaS52MS5SZW1vdmVDaGF0V29y'
    'a3RyZWVSZXNwb25zZRJZChBEZWxldGVDaGF0QnJhbmNoEiEubnVzaGkudjEuRGVsZXRlQ2hhdE'
    'JyYW5jaFJlcXVlc3QaIi5udXNoaS52MS5EZWxldGVDaGF0QnJhbmNoUmVzcG9uc2USXwoSRGVs'
    'ZXRlR2l0SHViQnJhbmNoEiMubnVzaGkudjEuRGVsZXRlR2l0SHViQnJhbmNoUmVxdWVzdBokLm'
    '51c2hpLnYxLkRlbGV0ZUdpdEh1YkJyYW5jaFJlc3BvbnNlEmIKE1Jlc3RvcmVHaXRIdWJCcmFu'
    'Y2gSJC5udXNoaS52MS5SZXN0b3JlR2l0SHViQnJhbmNoUmVxdWVzdBolLm51c2hpLnYxLlJlc3'
    'RvcmVHaXRIdWJCcmFuY2hSZXNwb25zZRJNCgxGaW5kQ2hhdFB1bGwSHS5udXNoaS52MS5GaW5k'
    'Q2hhdFB1bGxSZXF1ZXN0Gh4ubnVzaGkudjEuRmluZENoYXRQdWxsUmVzcG9uc2USTQoMTGlua0'
    'NoYXRQdWxsEh0ubnVzaGkudjEuTGlua0NoYXRQdWxsUmVxdWVzdBoeLm51c2hpLnYxLkxpbmtD'
    'aGF0UHVsbFJlc3BvbnNlEj0KBkV2ZW50cxIXLm51c2hpLnYxLkV2ZW50c1JlcXVlc3QaGC5udX'
    'NoaS52MS5FdmVudHNSZXNwb25zZTAB');
