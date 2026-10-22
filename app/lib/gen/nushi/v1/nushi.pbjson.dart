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
  ],
};

/// Descriptor for `ItemKind`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List itemKindDescriptor = $convert.base64Decode(
    'CghJdGVtS2luZBIZChVJVEVNX0tJTkRfVU5TUEVDSUZJRUQQABIaChZJVEVNX0tJTkRfVVNFUl'
    '9NRVNTQUdFEAESGwoXSVRFTV9LSU5EX0FHRU5UX01FU1NBR0UQAg==');

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
  ],
};

/// Descriptor for `StartChatResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List startChatResponseDescriptor = $convert.base64Decode(
    'ChFTdGFydENoYXRSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQ=');

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
  ],
  '8': [
    {'1': 'kind'},
  ],
};

/// Descriptor for `EventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventsResponseDescriptor = $convert.base64Decode(
    'Cg5FdmVudHNSZXNwb25zZRIXCgdjaGF0X2lkGAEgASgJUgZjaGF0SWQSKQoEaXRlbRgCIAEoCz'
    'ITLm51c2hpLnYxLkl0ZW1FdmVudEgAUgRpdGVtEi4KBnN0YXR1cxgDIAEoCzIULm51c2hpLnYx'
    'LkNoYXRTdGF0dXNIAFIGc3RhdHVzQgYKBGtpbmQ=');

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
  ],
};

/// Descriptor for `Item`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List itemDescriptor = $convert.base64Decode(
    'CgRJdGVtEg4KAmlkGAEgASgJUgJpZBImCgRraW5kGAIgASgOMhIubnVzaGkudjEuSXRlbUtpbm'
    'RSBGtpbmQSEgoEdGV4dBgDIAEoCVIEdGV4dA==');

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
  '.nushi.v1.StartChatRequest': StartChatRequest$json,
  '.nushi.v1.StartChatResponse': StartChatResponse$json,
  '.nushi.v1.SendPromptRequest': SendPromptRequest$json,
  '.nushi.v1.SendPromptResponse': SendPromptResponse$json,
  '.nushi.v1.EventsRequest': EventsRequest$json,
  '.nushi.v1.EventsResponse': EventsResponse$json,
  '.nushi.v1.ItemEvent': ItemEvent$json,
  '.nushi.v1.Item': Item$json,
  '.nushi.v1.ChatStatus': ChatStatus$json,
};

/// Descriptor for `NushiService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List nushiServiceDescriptor = $convert.base64Decode(
    'CgxOdXNoaVNlcnZpY2USNQoEUGluZxIVLm51c2hpLnYxLlBpbmdSZXF1ZXN0GhYubnVzaGkudj'
    'EuUGluZ1Jlc3BvbnNlEkQKCVN0YXJ0Q2hhdBIaLm51c2hpLnYxLlN0YXJ0Q2hhdFJlcXVlc3Qa'
    'Gy5udXNoaS52MS5TdGFydENoYXRSZXNwb25zZRJHCgpTZW5kUHJvbXB0EhsubnVzaGkudjEuU2'
    'VuZFByb21wdFJlcXVlc3QaHC5udXNoaS52MS5TZW5kUHJvbXB0UmVzcG9uc2USPQoGRXZlbnRz'
    'EhcubnVzaGkudjEuRXZlbnRzUmVxdWVzdBoYLm51c2hpLnYxLkV2ZW50c1Jlc3BvbnNlMAE=');
