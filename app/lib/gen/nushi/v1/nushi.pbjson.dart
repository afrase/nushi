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
  ],
};

/// Descriptor for `ItemKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List itemKindDescriptor = $convert.base64Decode(
    'CghJdGVtS2luZBIZChVJVEVNX0tJTkRfVU5TUEVDSUZJRUQQABIaChZJVEVNX0tJTkRfVVNFUl'
    '9NRVNTQUdFEAESGwoXSVRFTV9LSU5EX0FHRU5UX01FU1NBR0UQAhIXChNJVEVNX0tJTkRfVE9P'
    'TF9DQUxMEAMSGAoUSVRFTV9LSU5EX1BFUk1JU1NJT04QBBIWChJJVEVNX0tJTkRfUVVFU1RJT0'
    '4QBQ==');

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
  ],
};

/// Descriptor for `PingResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pingResponseDescriptor = $convert.base64Decode(
    'CgxQaW5nUmVzcG9uc2USHwoLYXBpX3ZlcnNpb24YASABKAVSCmFwaVZlcnNpb24=');

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
  ],
};

/// Descriptor for `Chat`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatDescriptor = $convert.base64Decode(
    'CgRDaGF0Eg4KAmlkGAEgASgJUgJpZBIUCgVhZ2VudBgCIAEoCVIFYWdlbnQSFgoGZm9sZGVyGA'
    'MgASgJUgZmb2xkZXISFAoFdGl0bGUYBCABKAlSBXRpdGxlEhIKBG1vZGUYBSABKAlSBG1vZGUS'
    'JgoPY3JlYXRlZF91bml4X21zGAYgASgDUg1jcmVhdGVkVW5peE1z');

@$core.Deprecated('Use startChatRequestDescriptor instead')
const StartChatRequest$json = {
  '1': 'StartChatRequest',
  '2': [
    {'1': 'folder', '3': 1, '4': 1, '5': 9, '10': 'folder'},
  ],
};

/// Descriptor for `StartChatRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatRequestDescriptor = $convert
    .base64Decode('ChBTdGFydENoYXRSZXF1ZXN0EhYKBmZvbGRlchgBIAEoCVIGZm9sZGVy');

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
  ],
};

/// Descriptor for `SendPromptRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendPromptRequestDescriptor = $convert.base64Decode(
    'ChFTZW5kUHJvbXB0UmVxdWVzdBIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSEgoEdGV4dBgCIA'
    'EoCVIEdGV4dA==');

@$core.Deprecated('Use sendPromptResponseDescriptor instead')
const SendPromptResponse$json = {
  '1': 'SendPromptResponse',
};

/// Descriptor for `SendPromptResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendPromptResponseDescriptor =
    $convert.base64Decode('ChJTZW5kUHJvbXB0UmVzcG9uc2U=');

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
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `EventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventsResponseDescriptor = $convert.base64Decode(
    'Cg5FdmVudHNSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSKQoEaXRlbRgCIAEoCz'
    'ITLm51c2hpLnYxLkl0ZW1FdmVudEgAUgRpdGVtEi4KBnN0YXR1cxgDIAEoCzIULm51c2hpLnYx'
    'LkNoYXRTdGF0dXNIAFIGc3RhdHVzEi4KBmNvbmZpZxgEIAEoCzIULm51c2hpLnYxLkNoYXRDb2'
    '5maWdIAFIGY29uZmlnEiQKBGNoYXQYBSABKAsyDi5udXNoaS52MS5DaGF0SABSBGNoYXRCBgoE'
    'a2luZA==');

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
  ],
};

/// Descriptor for `ConfigValue`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List configValueDescriptor = $convert.base64Decode(
    'CgtDb25maWdWYWx1ZRIUCgV2YWx1ZRgBIAEoCVIFdmFsdWUSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SFAoFZ3JvdXAYBCABKAlSBWdyb3Vw');

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
  ],
};

/// Descriptor for `Item`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List itemDescriptor = $convert.base64Decode(
    'CgRJdGVtEg4KAmlkGAEgASgJUgJpZBImCgRraW5kGAIgASgOMhIubnVzaGkudjEuSXRlbUtpbm'
    'RSBGtpbmQSEgoEdGV4dBgDIAEoCVIEdGV4dBIUCgV0aXRsZRgEIAEoCVIFdGl0bGUSGwoJdG9v'
    'bF9raW5kGAUgASgJUgh0b29sS2luZBIWCgZzdGF0dXMYBiABKAlSBnN0YXR1cxIqCgdvcHRpb2'
    '5zGAcgAygLMhAubnVzaGkudjEuT3B0aW9uUgdvcHRpb25zEhYKBmFuc3dlchgIIAEoCVIGYW5z'
    'd2VyEicKBmZpZWxkcxgJIAMoCzIPLm51c2hpLnYxLkZpZWxkUgZmaWVsZHM=');

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
  ],
};

/// Descriptor for `Field`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fieldDescriptor = $convert.base64Decode(
    'CgVGaWVsZBIOCgJpZBgBIAEoCVICaWQSFAoFdGl0bGUYAiABKAlSBXRpdGxlEiAKC2Rlc2NyaX'
    'B0aW9uGAMgASgJUgtkZXNjcmlwdGlvbhInCgR0eXBlGAQgASgOMhMubnVzaGkudjEuRmllbGRU'
    'eXBlUgR0eXBlEioKB29wdGlvbnMYBSADKAsyEC5udXNoaS52MS5PcHRpb25SB29wdGlvbnMSGg'
    'oIcmVxdWlyZWQYBiABKAhSCHJlcXVpcmVkEhYKBnZhbHVlcxgHIAMoCVIGdmFsdWVz');

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
    {'1': 'error', '3': 2, '4': 1, '5': 9, '10': 'error'},
  ],
};

/// Descriptor for `ChatStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List chatStatusDescriptor = $convert.base64Decode(
    'CgpDaGF0U3RhdHVzEhIKBGJ1c3kYASABKAhSBGJ1c3kSFAoFZXJyb3IYAiABKAlSBWVycm9y');

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
      '1': 'StartChat',
      '2': '.nushi.v1.StartChatRequest',
      '3': '.nushi.v1.StartChatResponse'
    },
    {
      '1': 'SendPrompt',
      '2': '.nushi.v1.SendPromptRequest',
      '3': '.nushi.v1.SendPromptResponse'
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
  '.nushi.v1.StartChatRequest': StartChatRequest$json,
  '.nushi.v1.StartChatResponse': StartChatResponse$json,
  '.nushi.v1.ConfigOption': ConfigOption$json,
  '.nushi.v1.ConfigValue': ConfigValue$json,
  '.nushi.v1.SendPromptRequest': SendPromptRequest$json,
  '.nushi.v1.SendPromptResponse': SendPromptResponse$json,
  '.nushi.v1.AnswerPermissionRequest': AnswerPermissionRequest$json,
  '.nushi.v1.AnswerPermissionResponse': AnswerPermissionResponse$json,
  '.nushi.v1.AnswerQuestionRequest': AnswerQuestionRequest$json,
  '.nushi.v1.FieldAnswer': FieldAnswer$json,
  '.nushi.v1.AnswerQuestionResponse': AnswerQuestionResponse$json,
  '.nushi.v1.SetConfigOptionRequest': SetConfigOptionRequest$json,
  '.nushi.v1.SetConfigOptionResponse': SetConfigOptionResponse$json,
  '.nushi.v1.EventsRequest': EventsRequest$json,
  '.nushi.v1.EventsResponse': EventsResponse$json,
  '.nushi.v1.ItemEvent': ItemEvent$json,
  '.nushi.v1.Item': Item$json,
  '.nushi.v1.Option': Option$json,
  '.nushi.v1.Field': Field$json,
  '.nushi.v1.ChatStatus': ChatStatus$json,
  '.nushi.v1.ChatConfig': ChatConfig$json,
};

/// Descriptor for `NushiService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List nushiServiceDescriptor = $convert.base64Decode(
    'CgxOdXNoaVNlcnZpY2USNQoEUGluZxIVLm51c2hpLnYxLlBpbmdSZXF1ZXN0GhYubnVzaGkudj'
    'EuUGluZ1Jlc3BvbnNlEkQKCUxpc3RDaGF0cxIaLm51c2hpLnYxLkxpc3RDaGF0c1JlcXVlc3Qa'
    'Gy5udXNoaS52MS5MaXN0Q2hhdHNSZXNwb25zZRJECglTdGFydENoYXQSGi5udXNoaS52MS5TdG'
    'FydENoYXRSZXF1ZXN0GhsubnVzaGkudjEuU3RhcnRDaGF0UmVzcG9uc2USRwoKU2VuZFByb21w'
    'dBIbLm51c2hpLnYxLlNlbmRQcm9tcHRSZXF1ZXN0GhwubnVzaGkudjEuU2VuZFByb21wdFJlc3'
    'BvbnNlElkKEEFuc3dlclBlcm1pc3Npb24SIS5udXNoaS52MS5BbnN3ZXJQZXJtaXNzaW9uUmVx'
    'dWVzdBoiLm51c2hpLnYxLkFuc3dlclBlcm1pc3Npb25SZXNwb25zZRJTCg5BbnN3ZXJRdWVzdG'
    'lvbhIfLm51c2hpLnYxLkFuc3dlclF1ZXN0aW9uUmVxdWVzdBogLm51c2hpLnYxLkFuc3dlclF1'
    'ZXN0aW9uUmVzcG9uc2USVgoPU2V0Q29uZmlnT3B0aW9uEiAubnVzaGkudjEuU2V0Q29uZmlnT3'
    'B0aW9uUmVxdWVzdBohLm51c2hpLnYxLlNldENvbmZpZ09wdGlvblJlc3BvbnNlEj0KBkV2ZW50'
    'cxIXLm51c2hpLnYxLkV2ZW50c1JlcXVlc3QaGC5udXNoaS52MS5FdmVudHNSZXNwb25zZTAB');
