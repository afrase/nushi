// This is a generated file - do not edit.
//
// Generated from nushi/v1/nushi.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ItemKind extends $pb.ProtobufEnum {
  static const ItemKind ITEM_KIND_UNSPECIFIED =
      ItemKind._(0, _omitEnumNames ? '' : 'ITEM_KIND_UNSPECIFIED');
  static const ItemKind ITEM_KIND_USER_MESSAGE =
      ItemKind._(1, _omitEnumNames ? '' : 'ITEM_KIND_USER_MESSAGE');
  static const ItemKind ITEM_KIND_AGENT_MESSAGE =
      ItemKind._(2, _omitEnumNames ? '' : 'ITEM_KIND_AGENT_MESSAGE');
  static const ItemKind ITEM_KIND_TOOL_CALL =
      ItemKind._(3, _omitEnumNames ? '' : 'ITEM_KIND_TOOL_CALL');

  /// The agent asks to run a tool call. Status is "pending" until it is
  /// answered ("answered") or the agent stops waiting ("cancelled").
  static const ItemKind ITEM_KIND_PERMISSION =
      ItemKind._(4, _omitEnumNames ? '' : 'ITEM_KIND_PERMISSION');

  /// A form the agent asks the user to fill in (Claude's AskUserQuestion);
  /// text is its message. Status is "pending" until it is "answered",
  /// "declined" or "cancelled".
  static const ItemKind ITEM_KIND_QUESTION =
      ItemKind._(5, _omitEnumNames ? '' : 'ITEM_KIND_QUESTION');

  /// The agent's thinking, streamed like a message.
  static const ItemKind ITEM_KIND_THOUGHT =
      ItemKind._(6, _omitEnumNames ? '' : 'ITEM_KIND_THOUGHT');

  /// The agent's plan as a checklist (plan), replaced as it changes.
  static const ItemKind ITEM_KIND_PLAN =
      ItemKind._(7, _omitEnumNames ? '' : 'ITEM_KIND_PLAN');

  static const $core.List<ItemKind> values = <ItemKind>[
    ITEM_KIND_UNSPECIFIED,
    ITEM_KIND_USER_MESSAGE,
    ITEM_KIND_AGENT_MESSAGE,
    ITEM_KIND_TOOL_CALL,
    ITEM_KIND_PERMISSION,
    ITEM_KIND_QUESTION,
    ITEM_KIND_THOUGHT,
    ITEM_KIND_PLAN,
  ];

  static final $core.List<ItemKind?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static ItemKind? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const ItemKind._(super.value, super.name);
}

class FieldType extends $pb.ProtobufEnum {
  static const FieldType FIELD_TYPE_UNSPECIFIED =
      FieldType._(0, _omitEnumNames ? '' : 'FIELD_TYPE_UNSPECIFIED');
  static const FieldType FIELD_TYPE_TEXT =
      FieldType._(1, _omitEnumNames ? '' : 'FIELD_TYPE_TEXT');

  /// One of the options.
  static const FieldType FIELD_TYPE_CHOICE =
      FieldType._(2, _omitEnumNames ? '' : 'FIELD_TYPE_CHOICE');

  /// Any of the options.
  static const FieldType FIELD_TYPE_CHOICES =
      FieldType._(3, _omitEnumNames ? '' : 'FIELD_TYPE_CHOICES');
  static const FieldType FIELD_TYPE_NUMBER =
      FieldType._(4, _omitEnumNames ? '' : 'FIELD_TYPE_NUMBER');
  static const FieldType FIELD_TYPE_INTEGER =
      FieldType._(5, _omitEnumNames ? '' : 'FIELD_TYPE_INTEGER');
  static const FieldType FIELD_TYPE_BOOLEAN =
      FieldType._(6, _omitEnumNames ? '' : 'FIELD_TYPE_BOOLEAN');

  static const $core.List<FieldType> values = <FieldType>[
    FIELD_TYPE_UNSPECIFIED,
    FIELD_TYPE_TEXT,
    FIELD_TYPE_CHOICE,
    FIELD_TYPE_CHOICES,
    FIELD_TYPE_NUMBER,
    FIELD_TYPE_INTEGER,
    FIELD_TYPE_BOOLEAN,
  ];

  static final $core.List<FieldType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 6);
  static FieldType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FieldType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
